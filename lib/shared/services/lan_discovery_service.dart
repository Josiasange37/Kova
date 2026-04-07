// shared/services/lan_discovery_service.dart — KDE Connect-style UDP discovery
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:kova/shared/models/network_alert.dart';
import 'package:kova/shared/services/local_storage.dart';

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

  bool _isRunning = false;
  String _role = 'child'; // 'parent' or 'child'
  String _deviceId = '';
  String _pairToken = '';

  Stream<LanDeviceInfo> get onDeviceFound => _deviceFoundController.stream;
  Stream<String> get onDeviceLost => _deviceLostController.stream;

  bool get isRunning => _isRunning;
  Map<String, LanDeviceInfo> get discoveredDevices => Map.unmodifiable(_discoveredDevices);

  /// Get the paired peer device (if discovered on LAN)
  LanDeviceInfo? get pairedPeer {
    final expectedRole = _role == 'parent' ? 'child' : 'parent';
    for (final device in _discoveredDevices.values) {
      if (device.role == expectedRole && device.pairToken == _pairToken) {
        return device;
      }
    }
    return null;
  }

  /// Start discovery — broadcasts presence and listens for peers
  Future<void> start({required String role}) async {
    if (_isRunning) return;

    _role = role;
    _deviceId = LocalStorage.getString('device_id');
    _pairToken = LocalStorage.getString('pair_token');

    if (_deviceId.isEmpty || _pairToken.isEmpty) {
      return; // Can't discover without device ID and pair token
    }

    try {
      _socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        _discoveryPort,
        reuseAddress: true,
        reusePort: true,
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

    final packet = jsonEncode({
      'type': 'kova_discovery',
      'version': 1,
      'deviceId': _deviceId,
      'role': _role,
      'port': _dataPort,
      'pairToken': _pairToken,
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

      // Only accept paired devices (same pairToken)
      if (device.pairToken != _pairToken) return;

      // Only accept the opposite role
      final expectedRole = _role == 'parent' ? 'child' : 'parent';
      if (device.role != expectedRole) return;

      final isNew = !_discoveredDevices.containsKey(device.deviceId);
      _discoveredDevices[device.deviceId] = device;

      if (isNew) {
        print('🔍 Discovered ${device.role} device at ${device.ipAddress}');
        _deviceFoundController.add(device);
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
