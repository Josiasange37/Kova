// shared/services/lan_discovery_service.dart — KDE Connect-style UDP discovery
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:kova/shared/models/network_alert.dart';
import 'package:kova/shared/services/local_storage.dart';
import 'package:kova/shared/services/crypto_service.dart';

/// UDP-based LAN discovery for finding paired devices on same WiFi network.
/// Broadcasts presence on port 18756, listens for paired device announcements.
class LanDiscoveryService {
  static final LanDiscoveryService _instance = LanDiscoveryService._();
  factory LanDiscoveryService() => _instance;
  LanDiscoveryService._();

  static const int _discoveryPort = 18756;
  static const int _dataPort = 18757;
  static const Duration _broadcastInterval = Duration(seconds: 5);
  static const Duration _deviceTimeout = Duration(seconds: 15);

  RawDatagramSocket? _socket;
  Timer? _broadcastTimer;
  Timer? _cleanupTimer;

  final _discoveredDevices = <String, LanDeviceInfo>{};
  final _deviceFoundController = StreamController<LanDeviceInfo>.broadcast();
  final _deviceLostController = StreamController<String>.broadcast();

  // ─── Reactive Pairing Callback ─────────────────────────────────────────
  // When in pairing mode and a peer with matching pairCode is discovered,
  // this callback fires immediately instead of requiring polling.
  void Function(LanDeviceInfo)? _onPeerFoundCallback;

  bool _isRunning = false;
  bool _pairingMode = false; // True during initial pairing (no token yet)
  String _role = 'child'; // 'parent' or 'child'
  String _deviceId = '';
  String _pairToken = '';
  String? _activePairCode;

  void setActivePairCode(String code) {
    _activePairCode = code;
    if (_isRunning) {
      _broadcast();
    }
  }

  Stream<LanDeviceInfo> get onDeviceFound => _deviceFoundController.stream;
  Stream<String> get onDeviceLost => _deviceLostController.stream;

  bool get isRunning => _isRunning;
  Map<String, LanDeviceInfo> get discoveredDevices => Map.unmodifiable(_discoveredDevices);

  /// Get the paired peer device (if discovered on LAN)
  LanDeviceInfo? get pairedPeer {
    final expectedRole = _role == 'parent' ? 'child' : 'parent';
    for (final device in _discoveredDevices.values) {
      if (device.role == expectedRole) {
        return device;
      }
    }
    return null;
  }

  /// Get a peer device by its pairing code (used by child during initial pairing)
  LanDeviceInfo? findPeerByCode(String code) {
    for (final device in _discoveredDevices.values) {
      if (device.role == 'parent' && device.pairCode == code) {
        return device;
      }
    }
    return null;
  }

  /// Register a one-shot callback for when a specific peer is found.
  /// Used by claimPairingCode() for reactive discovery (replaces polling loop).
  void setOnPeerFoundCallback(void Function(LanDeviceInfo)? callback) {
    _onPeerFoundCallback = callback;
  }

  /// Wait for a peer with specific pair code using Completer (reactive, non-blocking).
  /// Returns the peer device or null if timeout occurs.
  Future<LanDeviceInfo?> waitForPeerWithCode(String code, Duration timeout) async {
    // Check if already discovered
    final existing = findPeerByCode(code);
    if (existing != null) return existing;

    // Set up reactive callback
    final completer = Completer<LanDeviceInfo?>();
    Timer? timeoutTimer;

    _onPeerFoundCallback = (device) {
      if (device.pairCode == code && !completer.isCompleted) {
        timeoutTimer?.cancel();
        completer.complete(device);
      }
    };

    // Set timeout
    timeoutTimer = Timer(timeout, () {
      if (!completer.isCompleted) {
        _onPeerFoundCallback = null; // Clean up
        completer.complete(null);
      }
    });

    return completer.future;
  }

  /// Get a child device by the pairing code it claimed (used by parent during initial pairing)
  LanDeviceInfo? findChildByCode(String code) {
    for (final device in _discoveredDevices.values) {
      if (device.role == 'child' && device.pairCode == code) {
        return device;
      }
    }
    return null;
  }

  /// Start discovery — broadcasts presence and listens for peers
  /// Set [pairingMode] to true during initial pairing when no pair token exists yet.
  Future<void> start({required String role, bool pairingMode = false}) async {
    if (_isRunning) return;

    _role = role;
    _pairingMode = pairingMode;
    _deviceId = LocalStorage.getString('device_id');
    _pairToken = LocalStorage.getString('pair_token');

    if (_deviceId.isEmpty) {
      return; // Can't discover without device ID
    }

    // In normal mode, we need a pair token. In pairing mode, we don't.
    if (!_pairingMode && _pairToken.isEmpty) {
      return;
    }

    try {
      _socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        _discoveryPort,
        reuseAddress: true,
        reusePort: Platform.isAndroid,
      );

      _socket!.broadcastEnabled = true;
      _isRunning = true;

      // Listen for incoming announcements
      _socket!.listen(
        (event) {
          if (event == RawSocketEvent.read) {
            final datagram = _socket!.receive();
            if (datagram != null) {
              _handlePacket(datagram);
            }
          }
        },
        onError: (e) {
          print('LAN Discovery error: $e');
        },
      );

      // Start broadcasting our presence
      _broadcastTimer = Timer.periodic(_broadcastInterval, (_) => _broadcast());
      _broadcast(); // Immediate first broadcast

      // Cleanup stale devices
      _cleanupTimer = Timer.periodic(
        const Duration(seconds: 10),
        (_) => _cleanupStale(),
      );

      print('📡 LAN Discovery started as $_role on port $_discoveryPort');
    } catch (e) {
      print('❌ LAN Discovery start failed: $e');
      _isRunning = false;
    }
  }

  /// Stop discovery
  void stop() {
    _broadcastTimer?.cancel();
    _cleanupTimer?.cancel();
    _socket?.close();
    _socket = null;
    _isRunning = false;
    _discoveredDevices.clear();
    print('📡 LAN Discovery stopped');
  }

  /// Broadcast our presence via UDP
  void _broadcast() {
    if (_socket == null) return;

    final Map<String, String>? encryptedTokenMap = _activePairCode != null && _activePairCode!.isNotEmpty && _pairToken.isNotEmpty
        ? CryptoService(_activePairCode!).encryptPayload(_pairToken)
        : null;

    final packet = jsonEncode({
      'type': 'kova_discovery',
      'version': 1,
      'deviceId': _deviceId,
      'role': _role,
      'port': _dataPort,
      'encryptedPairToken': encryptedTokenMap?['data'] ?? '',
      'encryptedTokenIv': encryptedTokenMap?['iv'] ?? '',
      'pairCode': _activePairCode,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });

    final data = utf8.encode(packet);

    // Broadcast to subnet
    try {
      _socket!.send(
        data,
        InternetAddress('255.255.255.255'),
        _discoveryPort,
      );
    } catch (e) {
      // Broadcast may fail on some networks, that's OK
    }
  }

  /// Handle incoming UDP packet
  void _handlePacket(Datagram datagram) {
    try {
      final data = utf8.decode(datagram.data);
      final json = jsonDecode(data) as Map<String, dynamic>;

      if (json['type'] != 'kova_discovery') return;
      if (json['deviceId'] == _deviceId) return; // Ignore our own broadcasts

      final device = LanDeviceInfo.fromJson(json, datagram.address.address);

      // In pairing mode, accept any device of the opposite role that has a pairCode.
      // In normal mode, also just check the role since TCP connection will do token handshake.
      final expectedRole = _role == 'parent' ? 'child' : 'parent';
      if (device.role != expectedRole) return;

      final isNew = !_discoveredDevices.containsKey(device.deviceId);
      _discoveredDevices[device.deviceId] = device;

      if (isNew) {
        print('🔍 Discovered ${device.role} device at ${device.ipAddress}');
        _deviceFoundController.add(device);

        // ─── Reactive pairing: fire callback immediately if pairCode matches
        if (_pairingMode && _onPeerFoundCallback != null) {
          if (device.role == expectedRole && device.pairCode != null) {
            _onPeerFoundCallback!(device);
            _onPeerFoundCallback = null; // One-shot callback
          }
        }
      }
    } catch (e) {
      // Ignore malformed packets
    }
  }

  /// Remove devices that haven't been seen recently
  void _cleanupStale() {
    final now = DateTime.now();
    final stale = <String>[];

    for (final entry in _discoveredDevices.entries) {
      if (now.difference(entry.value.discoveredAt) > _deviceTimeout) {
        stale.add(entry.key);
      }
    }

    for (final id in stale) {
      _discoveredDevices.remove(id);
      _deviceLostController.add(id);
      print('📡 Device $id lost (timeout)');
    }
  }

  void dispose() {
    stop();
    _deviceFoundController.close();
    _deviceLostController.close();
  }
}
