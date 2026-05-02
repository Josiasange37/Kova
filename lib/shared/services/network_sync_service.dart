// shared/services/network_sync_service.dart — Central network coordinator
// Manages both LAN (direct TCP) and Internet (Vercel relay) channels.
// Priority: LAN > Internet. Falls back automatically.

import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
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

  // Vercel relay base URL — update after deployment
  static const String _relayBaseUrl = 'https://kova-relay.vercel.app';

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

  // Streams for UI
  final _connectionStateController =
      StreamController<NetworkConnectionState>.broadcast();
  final _alertReceivedController =
      StreamController<NetworkAlertSummary>.broadcast();
  final _historyReceivedController =
      StreamController<WebHistory>.broadcast();

  // ─── Pairing Complete Stream ──────────────────────────────────────────────
  // Fires immediately when pairing succeeds (LAN or Vercel). Both parent and
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

    // If child, start LAN server
    if (role == 'child') {
      await _lanData.startServer(_pairToken);
    }

    // If parent, start polling Vercel relay
    if (role == 'parent') {
      _startPolling();
      // Try to reconnect to last known child on LAN
      if (_pairToken.isNotEmpty) {
        final lastChildInfo = LocalStorage.getLastChildPeer();
        if (lastChildInfo != null) {
          try {
            final device = LanDeviceInfo.fromJson(lastChildInfo, lastChildInfo['ip'] ?? '');
            await _lanData.connectToDevice(device, _pairToken);
            print('🔁 LAN reconnected after reboot');
          } catch (e) {
            print('⚠️ LAN reconnect failed, will use Vercel: $e');
          }
        }
      }
    } else {
      _startSyncLoop();
    }

    // Listen for LAN alerts (both roles)
    _lanData.onAlertReceived.listen((alert) {
      _alertReceivedController.add(alert);
    });

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
  // Pairing (Vercel-based)
  // ─────────────────────────────────────────────

  /// Register a pairing code with the Vercel relay (parent side)
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

    // 2. Try local LAN discovery first
    if (!_lanDiscovery.isRunning) {
      // Start in pairing mode — no pair token required
      await _lanDiscovery.start(role: 'child', pairingMode: true);
    }
    
    // ─── Reactive LAN Discovery (replaces polling loop) ──────────────────────
    // Instead of polling every 500ms, we use a Completer that fires immediately
    // when the peer is discovered via UDP broadcast. This reduces latency
    // from up to 4 seconds to <100ms when both devices are on the same WiFi.
    LanDeviceInfo? localPeer;
    try {
      localPeer = await _lanDiscovery.waitForPeerWithCode(
        code,
        const Duration(seconds: 3), // 3s timeout, then fall through to Vercel
      );
    } catch (e) {
      print('⚠️ LAN discovery error: $e');
    }

    if (localPeer != null) {
      // Offline fallback: Generate our own pair token
      _pairToken = const Uuid().v4();
      await LocalStorage.setPairToken(_pairToken);
      _cryptoService = CryptoService(_pairToken);
      
      // Re-init discovery with the new pairToken (no longer in pairing mode)
      _lanDiscovery.stop();
      _lanData.stopServer();
      
      _lanDiscovery.setActivePairCode(code);
      await _lanDiscovery.start(role: 'child');
      
      // Child starts the TCP server
      await _lanData.startServer(_pairToken);
      _updateState(NetworkConnectionState.lan);
      
      _startSyncLoop();
      
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

    // 3. Fallback to Vercel relay with cold-start mitigation
    try {
      // ─── Pre-warm Vercel to avoid cold start ────────────────────────────────
      // Send a lightweight GET ping 1 second before the real POST to wake up
      // the serverless function. This reduces latency from 5-10s to <500ms.
      unawaited(Future.delayed(const Duration(seconds: 1), () async {
        try {
          await http.get(Uri.parse('$_relayBaseUrl/api/pair/ping'))
              .timeout(const Duration(seconds: 3));
          print('🔥 Vercel pre-warmed');
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
          'method': 'vercel',
          'pairToken': token,
          'role': 'child',
        });

        print('🔗 Pairing claimed via Vercel relay!');
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

      // Parent connects to the child's TCP server
      await _lanData.connectToDevice(childPeer, _pairToken);
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
            'method': 'vercel',
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

  /// Push an alert — uses LAN if available, falls back to Vercel relay
  Future<void> pushAlert(NetworkAlertFull alert, [String? itemId]) async {
    print('📤 [ALERT PIPELINE] NetworkSyncService.pushAlert() START');
    print('📤 [ALERT PIPELINE] _lanData.isConnected = ${_lanData.isConnected}');
    print('📤 [ALERT PIPELINE] _connectionState = $_connectionState');
    print('📤 [ALERT PIPELINE] _pairToken empty = ${_pairToken.isEmpty}');

    // Try LAN first (full data)
    if (_lanData.isConnected) {
      print('📤 [ALERT PIPELINE] Taking LAN path...');
      _lanData.sendAlert(alert);
      print('📤 Alert sent via LAN (full data)');
      if (itemId != null) {
        await _pendingSyncRepo.deleteList([itemId]);
      }
      print('✅ [ALERT PIPELINE] LAN path complete');
      return;
    }

    // Fallback to Vercel relay (summary only)
    print('📤 [ALERT PIPELINE] LAN not connected, falling back to Vercel relay...');
    await _pushAlertToRelay(alert, itemId);
    print('📤 [ALERT PIPELINE] Vercel relay path complete');
  }

  /// Push alert summary to Vercel relay
  Future<void> _pushAlertToRelay(NetworkAlertSummary alert, [String? itemId]) async {
    print('📤 [ALERT PIPELINE] _pushAlertToRelay() START');
    if (_pairToken.isEmpty) {
      print('❌ [ALERT PIPELINE] _pushAlertToRelay: _pairToken is EMPTY - aborting');
      return;
    }
    _cryptoService ??= CryptoService(_pairToken);

    try {
      // Explicitly construct a Summary object so that we don't accidentally serialize
      // a NetworkAlertFull object due to Dart's dynamic method dispatch on overridden toJson()
      final summary = NetworkAlertSummary(
        severity: alert.severity,
        app: alert.app,
        alertType: alert.alertType,
        childName: alert.childName,
        timestamp: alert.timestamp,
      );

      final jsonStr = jsonEncode(summary.toJson());
      final encrypted = _cryptoService!.encryptPayload(jsonStr);
      print('📤 [ALERT PIPELINE] Encrypting alert for relay: ${summary.app} - ${summary.alertType}');

      print('📤 [ALERT PIPELINE] POST to $_relayBaseUrl/api/alert/push...');
      final response = await http.post(
        Uri.parse('$_relayBaseUrl/api/alert/push'),
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

      print('📤 [ALERT PIPELINE] HTTP response: ${response.statusCode}');
      if (response.statusCode == 201) {
        print('✅ [ALERT PIPELINE] Alert pushed to relay (summary) - HTTP 201');
      } else {
        print('❌ [ALERT PIPELINE] Alert push failed: HTTP ${response.statusCode} - ${response.body}');
      }
    } catch (e, stackTrace) {
      print('❌ [ALERT PIPELINE] _pushAlertToRelay ERROR: $e');
      print('❌ [ALERT PIPELINE] Stack trace: $stackTrace');
    }
    print('📤 [ALERT PIPELINE] _pushAlertToRelay() END');
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
    // We only push history to Vercel Relay for MVP, 
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
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _pollAlerts();
      _pollHistory();
    });
    // Immediate first poll
    _pollAlerts();
    _pollHistory();
  }

  void _startSyncLoop() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(seconds: 15), (_) {
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

  Future<void> _syncLoop() async {
    if (_role != 'child' || _pairToken.isEmpty) return;
    if (_isSyncing) return;
    _isSyncing = true;

    try {
      final items = await _pendingSyncRepo.getAll();
      if (items.isEmpty) return;

      for (var item in items) {
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
      }
    } catch (e) {
      print('❌ Sync loop error: $e');
    } finally {
      _isSyncing = false;
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

    // Skip polling if LAN is connected (data comes directly)
    if (_connectionState == NetworkConnectionState.lan) return;

    try {
      final response = await http.get(
        Uri.parse('$_relayBaseUrl/api/alert/poll'),
        headers: {
          'Authorization': 'Bearer $_pairToken',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final alerts = data['alerts'] as List<dynamic>? ?? [];

        _cryptoService ??= CryptoService(_pairToken);

        for (final alertJson in alerts) {
          final map = alertJson as Map<String, dynamic>;
          final encryptedData = map['encryptedData'] as String? ?? '';
          final iv = map['iv'] as String? ?? '';

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
              print('❌ Failed to parse decrypted Vercel alert: $e');
            }
          }
        }

        if (alerts.isNotEmpty) {
          print('📥 Received ${alerts.length} alerts from relay');
        }
        
        _consecutiveFailures = 0;
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
  }

  void _handleDeviceFound(LanDeviceInfo device) {
    print('🔍 Paired device found on LAN: ${device.ipAddress}');

    // If parent, connect to child's TCP server
    if (_role == 'parent') {
      _lanData.connectToDevice(device, _pairToken).then((connected) {
        if (connected) {
          _updateState(NetworkConnectionState.lan);
        }
      });
    }

    _updateState(NetworkConnectionState.lan);
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

  void dispose() {
    stop();
    _connectionStateController.close();
    _alertReceivedController.close();
    _historyReceivedController.close();
  }
}
