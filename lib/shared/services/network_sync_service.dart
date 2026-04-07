// shared/services/network_sync_service.dart — Central network coordinator
// Manages both LAN (direct TCP) and Internet (Vercel relay) channels.
// Priority: LAN > Internet. Falls back automatically.

import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;

import 'package:kova/shared/models/network_alert.dart';
import 'package:kova/shared/services/lan_discovery_service.dart';
import 'package:kova/shared/services/lan_data_service.dart';
import 'package:kova/shared/services/local_storage.dart';

class NetworkSyncService {
  static final NetworkSyncService _instance = NetworkSyncService._();
  factory NetworkSyncService() => _instance;
  NetworkSyncService._();

  // Vercel relay base URL — update after deployment
  static const String _relayBaseUrl = 'https://kova-relay.vercel.app';

  final _lanDiscovery = LanDiscoveryService();
  final _lanData = LanDataService();

  Timer? _pollTimer;
  StreamSubscription? _connectivitySub;
  StreamSubscription? _deviceFoundSub;

  NetworkConnectionState _connectionState = NetworkConnectionState.none;
  String _role = 'child'; // 'parent' or 'child'
  String _pairToken = '';
  String _deviceId = '';

  // Streams for UI
  final _connectionStateController =
      StreamController<NetworkConnectionState>.broadcast();
  final _alertReceivedController =
      StreamController<NetworkAlertSummary>.broadcast();

  Stream<NetworkConnectionState> get onConnectionStateChanged =>
      _connectionStateController.stream;
  Stream<NetworkAlertSummary> get onAlertReceived =>
      _alertReceivedController.stream;

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

    if (_pairToken.isEmpty) {
      print('⚠️ No pair token — network sync disabled');
      return;
    }

    // Listen for connectivity changes
    _connectivitySub = Connectivity()
        .onConnectivityChanged
        .listen(_handleConnectivityChange);

    // Start LAN discovery
    await _lanDiscovery.start(role: role);

    // Listen for LAN device discovery
    _deviceFoundSub = _lanDiscovery.onDeviceFound.listen(_handleDeviceFound);

    // If child, start LAN server
    if (role == 'child') {
      await _lanData.startServer(_pairToken);
    }

    // If parent, start polling Vercel relay
    if (role == 'parent') {
      _startPolling();
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

  /// Register a pairing code with the Vercel relay (child side)
  Future<bool> registerPairingCode(String code) async {
    try {
      final response = await http.post(
        Uri.parse('$_relayBaseUrl/api/pair/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'code': code,
          'childDeviceId': _deviceId,
        }),
      );

      if (response.statusCode == 201) {
        print('📱 Code $code registered with relay');
        return true;
      } else {
        print('❌ Register failed: ${response.body}');
        return false;
      }
    } catch (e) {
      print('❌ Register error: $e');
      return false;
    }
  }

  /// Verify a pairing code and get pair token (parent side)
  Future<String?> verifyPairingCode(String code) async {
    try {
      final response = await http.post(
        Uri.parse('$_relayBaseUrl/api/pair/verify'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'code': code,
          'parentDeviceId': _deviceId,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final token = data['pairToken'] as String;

        // Store the pair token
        await LocalStorage.setString('pair_token', token);
        _pairToken = token;

        print('🔗 Pairing verified via relay');
        return token;
      } else {
        print('❌ Verify failed: ${response.body}');
        return null;
      }
    } catch (e) {
      print('❌ Verify error: $e');
      return null;
    }
  }

  // ─────────────────────────────────────────────
  // Alert Pushing (child side)
  // ─────────────────────────────────────────────

  /// Push an alert — uses LAN if available, falls back to Vercel relay
  Future<void> pushAlert(NetworkAlertFull alert) async {
    // Try LAN first (full data)
    if (_lanData.isConnected) {
      _lanData.sendAlert(alert);
      print('📤 Alert sent via LAN (full data)');
      return;
    }

    // Fallback to Vercel relay (summary only)
    await _pushAlertToRelay(alert);
  }

  /// Push alert summary to Vercel relay
  Future<void> _pushAlertToRelay(NetworkAlertSummary alert) async {
    if (_pairToken.isEmpty) return;

    try {
      final response = await http.post(
        Uri.parse('$_relayBaseUrl/api/alert/push'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_pairToken',
        },
        body: jsonEncode(alert.toJson()),
      );

      if (response.statusCode == 201) {
        print('📤 Alert pushed to relay (summary)');
      } else {
        print('❌ Alert push failed: ${response.body}');
      }
    } catch (e) {
      print('❌ Alert push error: $e');
    }
  }

  // ─────────────────────────────────────────────
  // Alert Polling (parent side)
  // ─────────────────────────────────────────────

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) => _pollAlerts());
    // Immediate first poll
    _pollAlerts();
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

        for (final alertJson in alerts) {
          final alert = NetworkAlertSummary.fromJson(
            alertJson as Map<String, dynamic>,
          );
          _alertReceivedController.add(alert);
        }

        if (alerts.isNotEmpty) {
          print('📥 Received ${alerts.length} alerts from relay');
        }
      }
    } catch (e) {
      // Network error — will retry on next poll
    }
  }

  // ─────────────────────────────────────────────
  // Connection Management
  // ─────────────────────────────────────────────

  void _handleConnectivityChange(ConnectivityResult result) {
    final hasWifi = result == ConnectivityResult.wifi;
    final hasMobile = result == ConnectivityResult.mobile;
    final hasEthernet = result == ConnectivityResult.ethernet;
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

  void dispose() {
    stop();
    _connectionStateController.close();
    _alertReceivedController.close();
  }
}
