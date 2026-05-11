// shared/services/network_sync_service.dart — Central network coordinator
// Manages both LAN (direct TCP) and Internet (Railway relay) channels.
// Priority: LAN > Internet. Falls back automatically.

import 'dart:async';
import 'dart:convert';
import 'dart:math' show min;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import 'package:kova/shared/models/network_alert.dart';
import 'package:kova/shared/models/web_history.dart';
import 'package:kova/shared/models/pending_sync.dart';
import 'package:kova/shared/services/lan_discovery_service.dart';
import 'package:kova/shared/services/lan_data_service.dart';
import 'package:kova/shared/services/local_storage.dart';
import 'package:kova/shared/services/crypto_service.dart';
import 'package:kova/local_backend/repositories/pending_sync_repository.dart';
import 'package:kova/local_backend/repositories/child_repository.dart';

class NetworkSyncService {
  static final NetworkSyncService _instance = NetworkSyncService._();
  static NetworkSyncService get instance => _instance;
  factory NetworkSyncService() => _instance;
  NetworkSyncService._();

  // ── Configurable relay URL ─────────────────────────────────────────────────
  // Default: Railway deployment. Can be overridden to local server for demo.
  // Set via: LocalStorage.setString('relay_url', 'http://192.168.x.x:3000')
  static const String _defaultRelayUrl = 'https://kova-production-3f1f.up.railway.app';
  
  /// Get the current relay base URL (configurable via settings)
  String get _relayBaseUrl {
    final custom = LocalStorage.getString('relay_url');
    return custom.isNotEmpty ? custom : _defaultRelayUrl;
  }

  /// Set a custom relay URL (e.g., local server for demo)
  static Future<void> setRelayUrl(String url) async {
    await LocalStorage.setString('relay_url', url);
    debugPrint('🌐 Relay URL set to: $url');
  }

  /// Get the current relay URL
  static String getRelayUrl() {
    final custom = LocalStorage.getString('relay_url');
    return custom.isNotEmpty ? custom : _defaultRelayUrl;
  }
  
  /// Reset relay URL to default
  static Future<void> resetRelayUrl() async {
    await LocalStorage.remove('relay_url');
    debugPrint('🌐 Relay URL reset to default');
  }

  final _lanDiscovery = LanDiscoveryService();
  final _lanData = LanDataService();
  final _pendingSyncRepo = PendingSyncRepository();

  Timer? _pollTimer;
  Timer? _syncTimer;
  StreamSubscription? _connectivitySub;
  StreamSubscription? _deviceFoundSub;

  NetworkConnectionState _connectionState = NetworkConnectionState.none;
  String _role = 'child'; // 'parent' or 'child'
  String _pairToken = '';
  String _deviceId = '';
  CryptoService? _cryptoService;
  bool _isSyncing = false;
  int _consecutiveFailures = 0;

  // Reconnect cooldown: prevents stampede when multiple alerts fire while LAN is down
  DateTime? _lastReconnectAttempt;
  Completer<bool>? _activeReconnect;
  static const _reconnectCooldown = Duration(seconds: 15);

  // ── Bug Fix: Relay circuit breaker ─────────────────────────────────────────
  // After N consecutive 404 (DEPLOYMENT_NOT_FOUND) responses, stop hitting the
  // relay for _relayCircuitCooldown to avoid log spam and battery drain.
  int _relayConsecutive404s = 0;
  DateTime? _relayCircuitOpenedAt;
  static const _relayCircuitThreshold = 3;
  // REDUCED for demo: was 5 minutes, now 30 seconds to recover faster
  static const _relayCircuitCooldown = Duration(seconds: 30);

  // ── Bug Fix: Alert deduplication ───────────────────────────────────────────
  // Prevents the same (app+alertType) from being pushed multiple times within
  // a 10-second window. Key = "app:alertType", value = last push timestamp.
  final Map<String, DateTime> _alertDedupCache = {};
  static const _alertDedupWindow = Duration(seconds: 10);

  // ── Bug Fix: Stale LAN IP detection ───────────────────────────────────────
  int _lanConsecutiveRefusals = 0;
  static const _lanStaleIpThreshold = 3;

  // Streams for UI
  final _connectionStateController =
      StreamController<NetworkConnectionState>.broadcast();
  final _alertReceivedController =
      StreamController<NetworkAlertSummary>.broadcast();
  final _historyReceivedController =
      StreamController<WebHistory>.broadcast();

  // ─── Pairing Complete Stream ──────────────────────────────────────────────
  // Fires immediately when pairing succeeds (LAN or Railway). Both parent and
  // child subscribe to this to navigate simultaneously instead of polling.
  final _pairingCompleteController = StreamController<Map<String, dynamic>>.broadcast();

  Stream<NetworkConnectionState> get onConnectionStateChanged =>
      _connectionStateController.stream;
  Stream<NetworkAlertSummary> get onAlertReceived =>
      _alertReceivedController.stream;
  Stream<WebHistory> get onHistoryReceived =>
      _historyReceivedController.stream;
  Stream<Map<String, dynamic>> get onPairingComplete =>
      _pairingCompleteController.stream;

  NetworkConnectionState get connectionState => _connectionState;
  bool get isConnected => _connectionState != NetworkConnectionState.none;
  bool get isLanConnected => _connectionState == NetworkConnectionState.lan;

  // ─────────────────────────────────────────────
  // Initialization
  // ─────────────────────────────────────────────

  /// Start the network sync service
  Future<void> start({required String role}) async {
    _role = role;
    _pairToken = LocalStorage.getString('pair_token');
    _deviceId = LocalStorage.getString('device_id');
    if (_pairToken.isNotEmpty) {
      _cryptoService = CryptoService(_pairToken);
    }

    // Always attach the LAN alert listener FIRST — before any early return —
    // so that after pairing completes and the pair token is written, alerts
    // flowing in via LAN are immediately bridged to onAlertReceived.
    _lanData.onAlertReceived.listen((alert) {
      _alertReceivedController.add(alert);
    });

    // Allow starting without a pair token during initial pairing.
    // LAN discovery will run in pairingMode, and relay calls are skipped.
    if (_pairToken.isEmpty) {
      print('⚠️ No pair token — running in pairing-only mode (LAN discovery active)');
      // Start LAN discovery in pairing mode so devices can find each other
      await _lanDiscovery.start(role: role, pairingMode: true);
      return;
    }

    // Listen for connectivity changes
    _connectivitySub = Connectivity()
        .onConnectivityChanged
        .listen(_handleConnectivityChange);

    // Start LAN discovery if not already running
    if (!_lanDiscovery.isRunning) {
      await _lanDiscovery.start(role: role);
    }

    // Listen for LAN device discovery
    _deviceFoundSub = _lanDiscovery.onDeviceFound.listen(_handleDeviceFound);

    // If parent, start LAN server immediately and poll Railway relay
    if (role == 'parent') {
      final serverStarted = await _lanData.startServer(_pairToken);
      if (serverStarted) {
        debugPrint('✅ [NETWORK SYNC] Parent LAN server started successfully');
      } else {
        debugPrint('❌ [NETWORK SYNC] Parent LAN server failed to start - alerts will use Railway only');
      }
      _startPolling();
    } else {
      _startSyncLoop();
      // If child, try to reconnect to last known parent on LAN
      if (_pairToken.isNotEmpty) {
        final lastParentInfo = LocalStorage.getLastChildPeer(); // We'll just use what we have
        if (lastParentInfo != null) {
          try {
            debugPrint('🔄 [NETWORK SYNC] Found last parent info in storage, attempting LAN connect...');
            final device = LanDeviceInfo.fromJson(lastParentInfo, lastParentInfo['ip'] ?? '');
            final connected = await _lanData.connectToParent(device.ipAddress, device.port, _pairToken);
            if (connected) {
              debugPrint('✅ [NETWORK SYNC] Reconnected to parent via LAN');
              _updateState(NetworkConnectionState.lan);
            } else {
              debugPrint('⚠️ [NETWORK SYNC] Failed to reconnect to parent via LAN on startup');
            }
          } catch (e) {
            print('⚠️ LAN reconnect failed, will use Railway: $e');
          }
        }
      }
    }

    // NOTE: LAN alert listener is already attached above (before early-return block)

    // ── Parent: Receive child profile over LAN and persist it ─────────────────
    // When the child sends its name/age over LAN after pairing, the parent
    // saves it to SQLite so the dashboard shows the correct child name.
    if (role == 'parent') {
      _lanData.onChildProfileReceived.listen((profile) async {
        try {
          // Save/update the child record in the local database
          final childRepo = ChildRepository();
          final existing = await childRepo.getAll();
          if (existing.isEmpty) {
            // First time — create the child record
            await childRepo.create(profile.name, age: profile.age);
            print('👶 Child profile CREATED in DB: ${profile.name}');
          } else {
            // Already exists — update name/age
            await childRepo.updateName(existing.first.id, profile.name);
            await childRepo.updateAge(existing.first.id, profile.age);
            print('👶 Child profile UPDATED in DB: ${profile.name}');
          }
          // Also cache in LocalStorage for fast access
          await LocalStorage.setString('child_name', profile.name);
          if (profile.childId.isNotEmpty) {
            await LocalStorage.setChildId(profile.childId);
          }
          // Fire pairingCompleteController so the UI refreshes
          _pairingCompleteController.add({
            'method': 'lan_profile',
            'childName': profile.name,
            'childId': profile.childId,
          });
        } catch (e) {
          print('❌ Failed to persist child profile from LAN: $e');
        }
      });
    }

    // Check initial connectivity
    final result = await Connectivity().checkConnectivity();
    _handleConnectivityChange(result);

    print('🌐 Network sync started as $_role');
  }

  /// Stop the network sync service
  void stop() {
    _pollTimer?.cancel();
    _syncTimer?.cancel();
    _connectivitySub?.cancel();
    _deviceFoundSub?.cancel();
    _lanDiscovery.stop();
    _lanData.stopServer();
    _lanData.disconnectClient();
    _updateState(NetworkConnectionState.none);
    print('🌐 Network sync stopped');
  }

  // ─────────────────────────────────────────────
  // Pairing (Railway-based)
  // ─────────────────────────────────────────────

  /// Register a pairing code with the Railway relay (parent side)
  Future<bool> registerPairingCode(String code) async {
    _lanDiscovery.setActivePairCode(code); // For offline LAN discovery

    // Ensure LAN discovery is running in pairing mode
    if (!_lanDiscovery.isRunning) {
      if (_deviceId.isEmpty) {
        _deviceId = LocalStorage.getString('device_id');
        if (_deviceId.isEmpty) {
          _deviceId = const Uuid().v4();
          await LocalStorage.setString('device_id', _deviceId);
        }
      }
      await _lanDiscovery.start(role: 'parent', pairingMode: true);
    }

    try {
      final response = await http.post(
        Uri.parse('$_relayBaseUrl/api/pair/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'code': code,
          'parentDeviceId': _deviceId,
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 201) {
        print('📱 Code $code registered with relay by parent');
        return true;
      } else {
        print('❌ Register failed: ${response.body}');
        return true; // Allow offline pairing fallback
      }
    } catch (e) {
      print('❌ Register error (relay unavailable, LAN pairing active): $e');
      return true; // Allow offline pairing fallback
    }
  }

  /// Claim a pairing code and get pair token (child side)
  Future<String?> claimPairingCode(String code) async {
    // 1. Ensure we have a device ID
    if (_deviceId.isEmpty) {
      _deviceId = LocalStorage.getString('device_id');
      if (_deviceId.isEmpty) {
        _deviceId = const Uuid().v4();
        await LocalStorage.setString('device_id', _deviceId);
      }
    }

    // 2. Try local LAN discovery first (with retry for timing issues)
    if (!_lanDiscovery.isRunning) {
      // Start in pairing mode — no pair token required
      await _lanDiscovery.start(role: 'child', pairingMode: true);
    }

    // ─── Reactive LAN Discovery with Retry ───────────────────────────────────
    // Child waits 1.5s before first attempt so the parent's UDP socket is
    // fully bound and ready to receive broadcasts. Then retries up to 3x.
    // This eliminates the "needs 2 attempts" bug.
    LanDeviceInfo? localPeer;
    const maxAttempts = 10;
    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        // Wait before each attempt: 500ms first try, 800ms subsequent
        final delayMs = attempt == 1 ? 500 : 800;
        print('📡 LAN discovery attempt $attempt/$maxAttempts (delay: ${delayMs}ms)...');
        await Future.delayed(Duration(milliseconds: delayMs));

        // Broadcast our presence immediately before listening
        if (_lanDiscovery.isRunning) {
          _lanDiscovery.setActivePairCode(code);
        }

        localPeer = await _lanDiscovery.waitForPeerWithCode(
          code,
          const Duration(seconds: 3),
        );
        if (localPeer != null) {
          print('📡 LAN peer found on attempt $attempt');
          break;
        }
        print('⚠️ LAN attempt $attempt: no peer found, retrying...');
      } catch (e) {
        print('⚠️ LAN discovery attempt $attempt error: $e');
      }
    }

    if (localPeer != null) {
      // Offline fallback: Generate our own pair token
      _pairToken = const Uuid().v4();
      await LocalStorage.setPairToken(_pairToken);
      _cryptoService = CryptoService(_pairToken);
      
      // Save parent peer info so we can reconnect on restart!
      await LocalStorage.setLastChildPeer(localPeer.toJson());
      
      // After pairing via UDP discovery, establish TCP data channel IMMEDIATELY
      final connected = await _lanData.connectToParent(localPeer.ipAddress, 18757, _pairToken);
      if (connected) {
        debugPrint('✅ [LAN] TCP data channel established');
        _updateState(NetworkConnectionState.lan);
      } else {
        debugPrint('❌ [LAN] TCP connect failed — alerts will use Railway');
        _updateState(NetworkConnectionState.internet);
      }

      // Re-init discovery with the new pairToken (no longer in pairing mode)
      _lanDiscovery.stop();
      _lanData.stopServer();
      
      _lanDiscovery.setActivePairCode(code);
      _lanDiscovery.start(role: 'child'); // run without await
      
      _startSyncLoop();

      // ─── Send child profile over LAN so parent gets the name immediately ─
      // This fixes the "parent doesn't see child name after pairing" bug.
      final childName = LocalStorage.getString('child_name', 'Child');
      final childId = LocalStorage.getString('child_id', _deviceId);
      final childAge = LocalStorage.getInt('child_age', 10);
      _lanData.sendChildProfile(
        childId: childId,
        name: childName,
        age: childAge,
      );
      print('📤 Child profile sent to parent via LAN: $childName');

      // ─── Notify both screens simultaneously ───────────────────────────────
      _pairingCompleteController.add({
        'method': 'lan',
        'pairToken': _pairToken,
        'peerIp': localPeer.ipAddress,
        'role': 'child',
      });

      print('🔗 Pairing claimed via LAN!');
      return _pairToken;
    }

    // 3. Fallback to Railway relay with cold-start mitigation
    try {
      // ─── Pre-warm Railway to avoid cold start ────────────────────────────────
      // Send a lightweight GET ping 1 second before the real POST to wake up
      // the serverless function. This reduces latency from 5-10s to <500ms.
      unawaited(Future.delayed(const Duration(seconds: 1), () async {
        try {
          await http.get(Uri.parse('$_relayBaseUrl/api/pair/ping'))
              .timeout(const Duration(seconds: 3));
          print('🔥 Railway pre-warmed');
        } catch (e) {
          // Ignore errors — pre-warming is best-effort
        }
      }));

      final response = await http.post(
        Uri.parse('$_relayBaseUrl/api/pair/claim'),
        headers: {
          'Content-Type': 'application/json',
          'Connection': 'keep-alive', // Keep connection open for faster response
        },
        body: jsonEncode({
          'code': code,
          'childDeviceId': _deviceId,
        }),
      ).timeout(const Duration(seconds: 8)); // Reduced from 15s to 8s

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final token = data['pairToken'] as String;

        // Store the pair token
        await LocalStorage.setPairToken(token);
        _pairToken = token;
        _cryptoService = CryptoService(token);

        _updateState(NetworkConnectionState.internet);
        _startSyncLoop();

        // ─── Notify both screens simultaneously ───────────────────────────────
        _pairingCompleteController.add({
          'method': 'railway',
          'pairToken': token,
          'role': 'child',
        });

        print('🔗 Pairing claimed via Railway relay!');
        return token;
      } else {
        print('❌ Claim failed: ${response.body}');
        return null;
      }
    } catch (e) {
      print('❌ Claim error (relay unavailable): $e');
      return null;
    }
  }

  /// Check pairing status manually (parent side polling)
  Future<String?> checkPairingStatus(String code) async {
    // Check if child has claimed the code via LAN!
    if (_connectionState == NetworkConnectionState.lan || _lanDiscovery.pairedPeer != null) {
      return _pairToken;
    }

    final childPeer = _lanDiscovery.findChildByCode(code);
    if (childPeer != null && childPeer.encryptedPairToken.isNotEmpty) {
      // The child generated a pairToken for us!
      _pairToken = CryptoService(code).decryptPayload(childPeer.encryptedPairToken, childPeer.encryptedTokenIv);
      await LocalStorage.setPairToken(_pairToken);
      _cryptoService = CryptoService(_pairToken);
      
      await LocalStorage.setLastChildPeer(childPeer.toJson());

      // Parent is already running the TCP server, child will connect to us
      _lanData.setPairToken(_pairToken);
      _updateState(NetworkConnectionState.lan);
      if (_role == 'parent') {
        _startPolling();
      } else {
        _startSyncLoop();
      }

      // ─── Notify both screens immediately ─────────────────────────────────
      _pairingCompleteController.add({
        'method': 'lan',
        'pairToken': _pairToken,
        'peerIp': childPeer.ipAddress,
        'role': 'parent',
      });

      print('🔗 Child connected via LAN, pairing complete');
      return _pairToken;
    }

    try {
      final response = await http.get(
        Uri.parse('$_relayBaseUrl/api/pair/status?code=$code'),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['paired'] == true) {
          final token = data['pairToken'] as String;
          await LocalStorage.setPairToken(token);
          _pairToken = token;
          _cryptoService = CryptoService(token);

          if (_role == 'parent') {
            _startPolling();
          } else {
            _startSyncLoop();
          }

          // ─── Notify both screens immediately ─────────────────────────────────
          _pairingCompleteController.add({
            'method': 'railway',
            'pairToken': token,
            'role': 'parent',
          });

          print('🔗 Child connected, pairing complete');
          return token;
        }
      }
      return null;
    } catch (e) {
      print('❌ Status check error: $e');
      return null;
    }
  }

  // ─────────────────────────────────────────────
  // Alert Pushing (child side)
  // ─────────────────────────────────────────────

  Future<void> pushAlert(NetworkAlertFull alert, [String? itemId]) async {
    // ── Bug Fix #4: Alert deduplication ──────────────────────────────────────
    // Skip if the same (app+alertType) was already pushed within 10 seconds.
    // This prevents the 4x-in-1-second flood seen in MIUI logs.
    if (itemId == null) {
      final dedupKey = '${alert.app}:${alert.alertType}';
      final now = DateTime.now();
      final lastPush = _alertDedupCache[dedupKey];
      if (lastPush != null && now.difference(lastPush) < _alertDedupWindow) {
        debugPrint('🔇 [PUSH ALERT] Dedup: skipping duplicate $dedupKey (${now.difference(lastPush).inMilliseconds}ms ago)');
        return;
      }
      _alertDedupCache[dedupKey] = now;
      // Prune old entries to prevent memory leak
      _alertDedupCache.removeWhere((_, ts) => now.difference(ts) > const Duration(minutes: 2));
    }

    debugPrint('📤 [PUSH ALERT] severity=${alert.severity}');

    bool delivered = false;

    // ── Debounced reconnect: share a single attempt across concurrent alerts ──
    if (!_lanData.isConnected || !_lanData.isSocketHealthy) {
      final now = DateTime.now();
      final cooldownExpired = _lastReconnectAttempt == null ||
          now.difference(_lastReconnectAttempt!) > _reconnectCooldown;

      if (cooldownExpired) {
        // Only one reconnect at a time — others wait on the same Completer
        if (_activeReconnect == null || _activeReconnect!.isCompleted) {
          _activeReconnect = Completer<bool>();
          _lastReconnectAttempt = now;
          debugPrint('🔁 [PUSH ALERT] LAN down — starting reconnect...');
          try {
            // First, try to rediscover parent via LAN discovery
            final discoveredParent = _lanDiscovery.pairedPeer;
            if (discoveredParent != null) {
              debugPrint('🔍 [PUSH ALERT] Found parent via discovery: ${discoveredParent.ipAddress}:${discoveredParent.port}');
              final connected = await _lanData.connectToParent(
                discoveredParent.ipAddress, 
                discoveredParent.port, 
                _pairToken
              );
              if (connected) {
                debugPrint('✅ [PUSH ALERT] Connected to discovered parent');
                _lanConsecutiveRefusals = 0;
                _activeReconnect!.complete(true);
                return;
              }
            }
            
            // Fallback: try last known IP
            await _lanData.attemptReconnect();
            await Future.delayed(const Duration(milliseconds: 300));
            if (_lanData.isConnected) {
              _lanConsecutiveRefusals = 0; // Reset on success
              debugPrint('✅ [PUSH ALERT] Reconnected via last known IP');
            } else {
              _lanConsecutiveRefusals++;
              // Bug Fix #3: Clear stale IP after N consecutive failures
              if (_lanConsecutiveRefusals >= _lanStaleIpThreshold) {
                debugPrint('🗑️ [PUSH ALERT] Stale LAN IP detected ($_lanConsecutiveRefusals failures) — clearing peer info');
                await LocalStorage.clearLastChildPeer();
                _lanConsecutiveRefusals = 0;
                // After clearing, wait for discovery to find parent again
                debugPrint('⏳ [PUSH ALERT] Waiting for LAN discovery to find parent...');
                await Future.delayed(const Duration(seconds: 2));
                // Try discovery one more time
                final newParent = _lanDiscovery.pairedPeer;
                if (newParent != null) {
                  debugPrint('🔍 [PUSH ALERT] Found new parent after discovery: ${newParent.ipAddress}');
                  final connected = await _lanData.connectToParent(
                    newParent.ipAddress,
                    newParent.port,
                    _pairToken
                  );
                  if (connected) {
                    debugPrint('✅ [PUSH ALERT] Connected to newly discovered parent');
                    _activeReconnect!.complete(true);
                    return;
                  }
                }
              }
            }
            _activeReconnect!.complete(_lanData.isConnected);
          } catch (e) {
            _lanConsecutiveRefusals++;
            debugPrint('⚠️ [PUSH ALERT] Reconnect failed: $e');
            _activeReconnect!.complete(false);
          }
        } else {
          debugPrint('🔁 [PUSH ALERT] Waiting on existing reconnect...');
          await _activeReconnect!.future;
        }
      } else {
        debugPrint('⏳ [PUSH ALERT] Reconnect cooldown active, skipping...');
      }
    }

    // Try LAN
    if (_lanData.isConnected && _lanData.isSocketHealthy) {
      debugPrint('📡 [PUSH ALERT] Sending via LAN...');
      try {
        final success = _lanData.sendAlertSafe(alert);
        debugPrint(success
            ? '✅ [PUSH ALERT] LAN SUCCESS'
            : '❌ [PUSH ALERT] LAN returned false');
        delivered = success;
      } catch (e) {
        debugPrint('❌ [PUSH ALERT] LAN exception: $e');
      }
    } else {
      debugPrint('❌ [PUSH ALERT] LAN unavailable');
    }

    if (delivered && itemId != null) {
      await _pendingSyncRepo.deleteList([itemId]);
      return;
    }

    // ── Railway relay fallback ──────────────────────────────
    if (!delivered) {
      debugPrint('🌐 [PUSH ALERT] Trying Railway relay...');
      try {
        delivered = await _pushAlertToRelay(alert, itemId);
        debugPrint(delivered
            ? '✅ [PUSH ALERT] Railway delivery SUCCESS'
            : '❌ [PUSH ALERT] Railway delivery FAILED');
      } catch (e) {
        debugPrint('❌ [PUSH ALERT] Railway exception: $e');
      }
    }

    if (!delivered) {
      debugPrint('💾 [PUSH ALERT] Saving to local queue for LAN retry...');
      try {
        await _pendingSyncRepo.insert(
          PendingSync(
            id: const Uuid().v4(),
            type: 'alert',
            payload: jsonEncode(alert.toJson()),
          ),
        );
        debugPrint('✅ [PUSH ALERT] Queued for retry when parent reconnects');
      } catch (e) {
        debugPrint('❌ [PUSH ALERT] Queue failed: $e');
      }
    }

    if (delivered && itemId != null) {
      await _pendingSyncRepo.deleteList([itemId]);
      debugPrint('🗑️ [PUSH ALERT] Pending sync item removed');
    }
  }

  /// Push alert summary to Railway relay
  /// Returns true if the relay accepted the alert (HTTP 201)
  Future<bool> _pushAlertToRelay(NetworkAlertSummary alert, [String? itemId]) async {
    // ── Bug Fix #2: Relay circuit breaker ────────────────────────────────────
    // If we've seen N consecutive 404 (DEPLOYMENT_NOT_FOUND) responses, stop
    // hitting the relay for cooldown period to avoid log spam and battery drain.
    if (_relayCircuitOpenedAt != null) {
      final elapsed = DateTime.now().difference(_relayCircuitOpenedAt!);
      if (elapsed < _relayCircuitCooldown) {
        final remainingSecs = _relayCircuitCooldown.inSeconds - elapsed.inSeconds;
        debugPrint('🔌 [RELAY] Circuit breaker OPEN — skipping relay (${remainingSecs}s remaining)');
        return false;
      } else {
        // Cooldown expired, try again
        debugPrint('🔌 [RELAY] Circuit breaker CLOSED — retrying relay');
        _relayCircuitOpenedAt = null;
        _relayConsecutive404s = 0;
      }
    }

    debugPrint('📤 [ALERT PIPELINE] _pushAlertToRelay() START');
    if (_pairToken.isEmpty) {
      debugPrint('❌ [ALERT PIPELINE] _pushAlertToRelay: _pairToken is EMPTY - aborting');
      return false;
    }
    _cryptoService ??= CryptoService(_pairToken);

    try {
      final summary = NetworkAlertSummary(
        severity: alert.severity,
        app: alert.app,
        alertType: alert.alertType,
        childName: alert.childName,
        timestamp: alert.timestamp,
      );

      final jsonStr = jsonEncode(summary.toJson());
      final encrypted = _cryptoService!.encryptPayload(jsonStr);
      debugPrint('📤 [ALERT PIPELINE] Encrypting alert for relay: ${summary.app} - ${summary.alertType}');

      final url = Uri.parse('$_relayBaseUrl/api/alert/push');
      debugPrint('🌐 [RELAY] POST $url');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_pairToken',
        },
        body: jsonEncode({
          'encryptedData': encrypted['data'],
          'iv': encrypted['iv'],
          'id': itemId
        }),
      ).timeout(const Duration(seconds: 10));

      debugPrint('🌐 [RELAY] Response: ${response.statusCode}');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        debugPrint('✅ [RELAY] Alert delivered successfully');
        _relayConsecutive404s = 0; // Reset on success
        return true;
      } else if (response.statusCode == 404) {
        // 404 = Server is up but endpoint not found OR Railway deployment not found
        _relayConsecutive404s++;
        final bodyPreview = response.body.length > 100 ? '${response.body.substring(0, 100)}...' : response.body;
        debugPrint('⚠️ [RELAY] 404 Not Found ($_relayConsecutive404s/$_relayCircuitThreshold)');
        debugPrint('   └─ Response: $bodyPreview');
        debugPrint('   └─ URL: $_relayBaseUrl/api/alert/push');
        if (_relayConsecutive404s >= _relayCircuitThreshold) {
          _relayCircuitOpenedAt = DateTime.now();
          debugPrint('🔌 [RELAY] Circuit breaker OPENED — server may be down or not deployed');
        }
        return false;
      } else {
        debugPrint('❌ [RELAY] Server error: ${response.statusCode}');
        debugPrint('   └─ Response: ${response.body.substring(0, min(100, response.body.length))}');
        return false;
      }
    } on TimeoutException {
      debugPrint('❌ [RELAY] Timeout — Railway not responding');
      return false;
    } catch (e) {
      debugPrint('❌ [RELAY] Exception: $e');
      return false;
    }
  }

  Future<void> _pollHistory() async {
    if (_pairToken.isEmpty) return;
    if (_connectionState == NetworkConnectionState.lan) return; // Wait, we might want LAN later

    try {
      final response = await http.get(
        Uri.parse('$_relayBaseUrl/api/history/poll'),
        headers: {
          'Authorization': 'Bearer $_pairToken',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final historyList = data['history'] as List<dynamic>? ?? [];

        _cryptoService ??= CryptoService(_pairToken);

        for (final item in historyList) {
          final map = item as Map<String, dynamic>;
          final encryptedData = map['encryptedData'] as String? ?? '';
          final iv = map['iv'] as String? ?? '';

          final decryptedStr = _cryptoService!.decryptPayload(encryptedData, iv);
          if (decryptedStr.isNotEmpty) {
            try {
              final historyJson = jsonDecode(decryptedStr) as Map<String, dynamic>;
              final webHistory = WebHistory.fromJson(historyJson);
              _historyReceivedController.add(webHistory);
              print('📥 Received web history via relay: ${webHistory.url}');
              
              if (map['id'] != null) {
                _pushAcks([map['id'] as String]);
              }
            } catch (e) {
              print('❌ Failed to parse decrypted history: $e');
            }
          }
        }
      }
    } catch (e) {
      print('❌ History poll error: $e');
    }
  }

  // ─────────────────────────────────────────────
  // Web History Pushing (child side)
  // ─────────────────────────────────────────────

  Future<void> pushHistory(WebHistory history, [String? itemId]) async {
    // We only push history to Railway Relay for MVP, 
    // unless LAN data allows it. LAN is skipped for history right now, 
    // but could be added later.
    if (_pairToken.isEmpty) return;
    _cryptoService ??= CryptoService(_pairToken);

    try {
      final jsonStr = jsonEncode(history.toJson());
      final encrypted = _cryptoService!.encryptPayload(jsonStr);

      final response = await http.post(
        Uri.parse('$_relayBaseUrl/api/history/push'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_pairToken',
        },
        body: jsonEncode({
          'encryptedData': encrypted['data'],
          'iv': encrypted['iv'],
          'id': itemId
        }),
      );

      if (response.statusCode == 201) {
        print('📤 History pushed to relay');
      } else {
        print('❌ History push failed: ${response.body}');
      }
    } catch (e) {
      print('❌ History push error: $e');
    }
  }

  // ─────────────────────────────────────────────
  // Alert Polling (parent side)
  // ─────────────────────────────────────────────

  void _startPolling() {
    _pollTimer?.cancel();
    // Poll every 10 seconds instead of 30 — critical for timely parent alerts
    _pollTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _pollAlerts();
      _pollHistory();
    });
    // Immediate first poll
    _pollAlerts();
    _pollHistory();
  }

  void _startSyncLoop() {
    _syncTimer?.cancel();
    // Sync every 8 seconds for faster alert delivery
    _syncTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      _syncLoop();
      _pollAcks();
      _syncChildProfileIfNeeded(); // Retry profile sync periodically (DIRECTIVE 5)
    });
    _syncLoop();
    _pollAcks();
  }

  /// Periodic check to sync child profile if not yet available (DIRECTIVE 5)
  Future<void> _syncChildProfileIfNeeded() async {
    if (_role != 'child' || _pairToken.isEmpty) return;

    // Check if we already have a profile
    final childId = LocalStorage.getChildId();
    if (childId == null) return;

    final childRepo = ChildRepository();
    final existing = await childRepo.getById(childId);
    if (existing != null) return; // Already have profile

    // Try to sync profile from relay
    print('🔄 Periodic child profile sync attempt...');
    await syncChildProfile();
  }

  void triggerSyncLoop() {
    if (_role == 'child') {
      _syncLoop();
    }
  }

  DateTime? _syncStartedAt;

  Future<void> _syncLoop() async {
    if (_role != 'child' || _pairToken.isEmpty) return;

    // Safety: if _isSyncing has been stuck for more than 30 seconds, force-reset it
    if (_isSyncing && _syncStartedAt != null) {
      final elapsed = DateTime.now().difference(_syncStartedAt!).inSeconds;
      if (elapsed > 30) {
        print('⚠️ [SYNC] _isSyncing stuck for ${elapsed}s — force-resetting');
        _isSyncing = false;
      } else {
        return;
      }
    }
    if (_isSyncing) return;
    _isSyncing = true;
    _syncStartedAt = DateTime.now();

    try {
      final items = await _pendingSyncRepo.getAll();
      if (items.isEmpty) {
        _isSyncing = false;
        _syncStartedAt = null;
        return;
      }

      // Process at most 10 items per cycle to avoid blocking the pipeline
      final batch = items.take(10).toList();

      for (var item in batch) {
        try {
          if (item.type == 'alert') {
            final alert = NetworkAlertFull.fromJson(jsonDecode(item.payload));
            await pushAlert(alert, item.id);
          } else if (item.type == 'history') {
            final history = WebHistory.fromJson(jsonDecode(item.payload));
            await pushHistory(history, item.id);
          } else if (item.type == 'child_profile') {
            // Retry pushing child profile
            final data = jsonDecode(item.payload);
            await pushChildProfile(
              childId: data['childId'],
              name: data['name'],
              age: data['age'] ?? 10,
              avatarPath: data['avatarPath'],
              settings: data['settings'],
            );
          }
        } catch (e) {
          print('❌ Sync item ${item.id} error: $e');
          // Continue processing other items — don't let one failure block all
        }
      }
    } catch (e) {
      print('❌ Sync loop error: $e');
    } finally {
      _isSyncing = false;
      _syncStartedAt = null;
    }
  }

  Future<void> _pollAcks() async {
    if (_role != 'child' || _pairToken.isEmpty) return;

    try {
      final response = await http.get(
        Uri.parse('$_relayBaseUrl/api/ack/poll'),
        headers: {
          'Authorization': 'Bearer $_pairToken',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final acks = List<String>.from(data['acks'] ?? []);
        
        if (acks.isNotEmpty) {
          print('✅ Polled ACKs for ${acks.length} items. Deleting from queue.');
          await _pendingSyncRepo.deleteList(acks);
        }
      }
    } catch (e) {
      // Ignored
    }
  }

  Future<void> _pushAcks(List<String> ids) async {
    if (_role != 'parent' || _pairToken.isEmpty || ids.isEmpty) return;

    try {
      await http.post(
        Uri.parse('$_relayBaseUrl/api/ack/push'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_pairToken',
        },
        body: jsonEncode({
          'ids': ids,
        }),
      );
    } catch (e) {
      // Ignored
    }
  }

  Future<void> _pollAlerts() async {
    if (_pairToken.isEmpty) return;

    // Circuit breaker: skip polling if relay is known dead
    if (_relayCircuitOpenedAt != null) {
      final elapsed = DateTime.now().difference(_relayCircuitOpenedAt!);
      if (elapsed < _relayCircuitCooldown) return;
      _relayCircuitOpenedAt = null;
      _relayConsecutive404s = 0;
    }

    try {
      final response = await http.get(
        Uri.parse('$_relayBaseUrl/api/alert/poll'),
        headers: {
          'Authorization': 'Bearer $_pairToken',
        },
      );

      if (response.statusCode == 200) {
        _relayConsecutive404s = 0; // Reset on success
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final alerts = data['alerts'] as List<dynamic>? ?? [];

        _cryptoService ??= CryptoService(_pairToken);

        for (final alertJson in alerts) {
          final map = alertJson as Map<String, dynamic>;
          
          // ── Handle BOTH encrypted and unencrypted (test) alerts ──
          final isTestAlert = map['isTestAlert'] == true;
          final encryptedData = map['encryptedData'] as String? ?? '';
          final iv = map['iv'] as String? ?? '';

          if (isTestAlert || (encryptedData.isEmpty && map['app'] != null)) {
            // Unencrypted test alert — parse directly
            try {
              final alert = NetworkAlertSummary(
                severity: map['severity'] as String? ?? 'high',
                app: map['app'] as String? ?? 'Test',
                alertType: map['alertType'] as String? ?? 'test_alert',
                childName: map['childName'] as String? ?? 'Child',
                timestamp: map['timestamp'] != null
                    ? DateTime.tryParse(map['timestamp'] as String) ?? DateTime.now()
                    : DateTime.now(),
              );
              _alertReceivedController.add(alert);
              debugPrint('🧪 [POLL] Test alert received: ${alert.app} - ${alert.severity}');
            } catch (e) {
              print('❌ Failed to parse test alert: $e');
            }
          } else if (encryptedData.isNotEmpty) {
            // Encrypted real alert — decrypt first
            final decryptedStr = _cryptoService!.decryptPayload(encryptedData, iv);
            if (decryptedStr.isNotEmpty) {
              try {
                final summaryJson = jsonDecode(decryptedStr) as Map<String, dynamic>;
                final alert = NetworkAlertSummary.fromJson(summaryJson);
                _alertReceivedController.add(alert);
                
                if (map['id'] != null) {
                  _pushAcks([map['id'] as String]);
                }
              } catch (e) {
                print('❌ Failed to parse decrypted relay alert: $e');
              }
            }
          }
        }

        if (alerts.isNotEmpty) {
          print('📥 Received ${alerts.length} alerts from relay');
        }
        
        _consecutiveFailures = 0;
      } else if (response.statusCode == 404 && response.body.contains('DEPLOYMENT_NOT_FOUND')) {
        // Specific Railway deployment error — trip circuit breaker
        _relayConsecutive404s++;
        debugPrint('⚠️ [RELAY] POLL DEPLOYMENT_NOT_FOUND ($_relayConsecutive404s/$_relayCircuitThreshold)');
        if (_relayConsecutive404s >= _relayCircuitThreshold) {
          _relayCircuitOpenedAt = DateTime.now();
          debugPrint('🔌 [RELAY] Circuit breaker OPENED — pausing polling for ${_relayCircuitCooldown.inMinutes} minutes');
        }
      }
    } catch (e) {
      _consecutiveFailures++;
      print('⚠️ Poll failed ($_consecutiveFailures): $e');

      if (_consecutiveFailures >= 5) {
        _updateState(NetworkConnectionState.error);
        print('❌ Relay unreachable — switching to error state');
      }
    }
  }

  // ─────────────────────────────────────────────
  // Connection Management
  // ─────────────────────────────────────────────

  void _handleConnectivityChange(List<ConnectivityResult> results) {
    if (results.isEmpty) {
      _updateState(NetworkConnectionState.none);
      return;
    }
    final hasWifi = results.contains(ConnectivityResult.wifi);
    final hasMobile = results.contains(ConnectivityResult.mobile);
    final hasEthernet = results.contains(ConnectivityResult.ethernet);
    final hasInternet = hasWifi || hasMobile || hasEthernet;

    if (hasWifi && _lanDiscovery.pairedPeer != null) {
      _updateState(NetworkConnectionState.lan);
    } else if (hasInternet) {
      _updateState(NetworkConnectionState.internet);
    } else {
      _updateState(NetworkConnectionState.none);
    }

    // ── Bug Fix: Parent server lifecycle ───────────────────────────────────────
    // If we're parent and WiFi just came back, ensure server is running
    if (_role == 'parent' && hasWifi) {
      // Fire-and-forget is intentional here — don't block connectivity updates
      _ensureParentServerRunning().catchError((e) {
        debugPrint('⚠️ [PARENT] Server health check error: $e');
      });
    }
  }

  /// Ensure parent LAN server is running (restarts if needed)
  Future<void> _ensureParentServerRunning() async {
    if (_role != 'parent') return;
    
    try {
      // Check if server is actually accepting connections
      final isHealthy = await _lanData.isServerHealthy();
      if (!isHealthy) {
        debugPrint('🔌 [PARENT] Server unhealthy, restarting...');
        await _lanData.stopServer();
        await Future.delayed(const Duration(milliseconds: 500));
        await _lanData.startServer(_pairToken);
        debugPrint('✅ [PARENT] Server restarted successfully');
      }
    } catch (e) {
      debugPrint('⚠️ [PARENT] Server health check failed: $e');
      // Force restart
      try {
        await _lanData.stopServer();
        await Future.delayed(const Duration(milliseconds: 500));
        await _lanData.startServer(_pairToken);
      } catch (e2) {
        debugPrint('❌ [PARENT] Server restart failed: $e2');
      }
    }
  }

  void _handleDeviceFound(LanDeviceInfo device) {
    print('🔍 Paired device found on LAN: ${device.ipAddress}');

    // If child, connect to parent's TCP server — only set state AFTER TCP connects
    if (_role == 'child') {
      _lanData.connectToParent(device.ipAddress, device.port, _pairToken).then((connected) {
        if (connected) {
          // ── Bug Fix: Reset circuit breaker on successful LAN connect ────────
          // If we got LAN working, we don't need the relay - close the circuit breaker
          if (_relayCircuitOpenedAt != null) {
            debugPrint('🔌 [RELAY] LAN connected — closing circuit breaker early');
            _relayCircuitOpenedAt = null;
            _relayConsecutive404s = 0;
          }
          // Reset stale IP counter on successful connection
          _lanConsecutiveRefusals = 0;
          _updateState(NetworkConnectionState.lan);
        } else {
          debugPrint('⚠️ [DEVICE FOUND] TCP handshake failed to ${device.ipAddress} — staying on current state');
        }
      });
      // DON'T set state to LAN here — wait for TCP to actually connect
    } else {
      // Parent side: we're running the TCP server, so discovery = ready
      _updateState(NetworkConnectionState.lan);
    }
  }

  void _updateState(NetworkConnectionState newState) {
    if (_connectionState != newState) {
      _connectionState = newState;
      _connectionStateController.add(newState);
      print('🌐 Connection state: ${newState.name}');
    }
  }

  // ─────────────────────────────────────────────
  // Child Profile Sync (DIRECTIVE 1 & 2)
  // ─────────────────────────────────────────────

  /// Push child profile to relay immediately after creation (parent side)
  /// Called by ChildProfileService after saving to local SQLite
  Future<bool> pushChildProfile({
    required String childId,
    required String name,
    int age = 10,
    String? avatarPath,
    Map<String, dynamic>? settings,
  }) async {
    if (_pairToken.isEmpty) {
      print('❌ Cannot push child profile: no pair token');
      return false;
    }

    _cryptoService ??= CryptoService(_pairToken);

    // Encrypt profile data
    final profileData = jsonEncode({
      'childId': childId,
      'name': name,
      'age': age,
      'avatarPath': avatarPath,
      'settings': settings ?? {},
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
    final encrypted = _cryptoService!.encryptPayload(profileData);

    try {
      final response = await http.post(
        Uri.parse('$_relayBaseUrl/api/child/register'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_pairToken',
          'Connection': 'keep-alive',
        },
        body: jsonEncode({
          'childId': childId,
          'name': name,
          'age': age,
          'avatarUrl': avatarPath,
          'settings': settings ?? {},
          'encryptedData': encrypted['data'],
          'iv': encrypted['iv'],
        }),
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        print('👤 Child profile pushed to relay: $name ($childId)');
        return true;
      } else {
        print('❌ Child profile push failed: ${response.statusCode} ${response.body}');
        // Add to pending sync for retry
        await _pendingSyncRepo.insert(
          PendingSync(
            id: const Uuid().v4(),
            type: 'child_profile',
            payload: jsonEncode(profileData),
          ),
        );
        return false;
      }
    } catch (e) {
      print('❌ Child profile push error: $e');
      // Add to pending sync for retry
      await _pendingSyncRepo.insert(
        PendingSync(
          id: const Uuid().v4(),
          type: 'child_profile',
          payload: jsonEncode(profileData),
        ),
      );
      return false;
    }
  }

  /// Sync child profile from relay to local SQLite (child side)
  /// Called on boot and periodically until profile is received
  Future<bool> syncChildProfile() async {
    if (_pairToken.isEmpty) {
      print('❌ Cannot sync child profile: no pair token');
      return false;
    }

    try {
      final response = await http.get(
        Uri.parse('$_relayBaseUrl/api/child/profile'),
        headers: {
          'Authorization': 'Bearer $_pairToken',
          'Connection': 'keep-alive',
        },
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final profile = data['profile'] as Map<String, dynamic>;

        // Decrypt if encrypted data present
        String? decryptedPayload;
        if (profile['encryptedData'] != null && profile['iv'] != null) {
          _cryptoService ??= CryptoService(_pairToken);
          decryptedPayload = _cryptoService!.decryptPayload(
            profile['encryptedData'],
            profile['iv'],
          );
        }

        final Map<String, dynamic> childData;
        if (decryptedPayload != null) {
          childData = jsonDecode(decryptedPayload);
        } else {
          // Use unencrypted fields as fallback
          childData = {
            'childId': profile['childId'],
            'name': profile['name'],
            'age': profile['age'],
            'avatarPath': profile['avatarUrl'],
            'settings': profile['settings'],
          };
        }

        // Save to local SQLite via ChildRepository
        final childRepo = ChildRepository();
        final existing = await childRepo.getById(childData['childId']);

        if (existing == null) {
          // Create new child profile
          await childRepo.create(
            childData['name'],
            age: childData['age'] ?? 10,
            avatarPath: childData['avatarPath'],
          );
          print('👤 Child profile saved to SQLite: ${childData['name']}');
        } else {
          // Update existing profile
          await childRepo.updateName(existing.id, childData['name']);
          if (childData['age'] != null) {
            await childRepo.updateAge(existing.id, childData['age']);
          }
          print('👤 Child profile updated: ${childData['name']}');
        }

        return true;
      } else if (response.statusCode == 404) {
        print('⏳ Child profile not available yet (parent may not have registered)');
        return false;
      } else {
        print('❌ Child profile sync failed: ${response.statusCode} ${response.body}');
        return false;
      }
    } catch (e) {
      print('❌ Child profile sync error: $e');
      return false;
    }
  }

  // ─────────────────────────────────────────────
  // Test Alert (for presentation / demo)
  // ─────────────────────────────────────────────

  /// Send a test alert via the relay server (no encryption needed).
  /// Works from BOTH child and parent side — useful for demo videos.
  Future<bool> sendTestAlert({
    String app = 'WhatsApp',
    String severity = 'high',
    String alertType = 'suspicious_content',
    String? childName,
  }) async {
    if (_pairToken.isEmpty) {
      debugPrint('❌ [TEST ALERT] No pair token — cannot send test alert');
      return false;
    }

    final name = childName ?? LocalStorage.getString('child_name', 'Child');

    try {
      final response = await http.post(
        Uri.parse('$_relayBaseUrl/api/alert/test'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_pairToken',
        },
        body: jsonEncode({
          'app': app,
          'severity': severity,
          'alertType': alertType,
          'childName': name,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 201) {
        debugPrint('🧪 [TEST ALERT] Sent: $app - $severity via relay');
        return true;
      } else {
        debugPrint('❌ [TEST ALERT] Server returned: ${response.statusCode} ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ [TEST ALERT] Error: $e');
      return false;
    }
  }

  /// Check server health (useful for settings screen)
  Future<Map<String, dynamic>?> checkServerHealth() async {
    try {
      final response = await http.get(
        Uri.parse('$_relayBaseUrl/api/health'),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('❌ Server health check failed: $e');
    }
    return null;
  }

  void dispose() {
    stop();
    _connectionStateController.close();
    _alertReceivedController.close();
    _historyReceivedController.close();
  }
}
