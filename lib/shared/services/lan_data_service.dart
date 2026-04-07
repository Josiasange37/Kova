// shared/services/lan_data_service.dart — TCP server/client for full data transfer
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:kova/shared/models/network_alert.dart';

/// TCP-based direct data transfer between paired devices on LAN.
/// Child runs the server, parent connects as client.
class LanDataService {
  static final LanDataService _instance = LanDataService._();
  factory LanDataService() => _instance;
  LanDataService._();

  static const int _port = 18757;

  ServerSocket? _server;
  Socket? _clientSocket;
  Socket? _activeConnection;
  String _pairToken = '';

  bool _isServerRunning = false;
  bool _isClientConnected = false;

  final _alertReceivedController = StreamController<NetworkAlertFull>.broadcast();
  final _connectionStateController = StreamController<bool>.broadcast();

  Stream<NetworkAlertFull> get onAlertReceived => _alertReceivedController.stream;
  Stream<bool> get onConnectionChanged => _connectionStateController.stream;

  bool get isConnected => _isClientConnected || _activeConnection != null;

  // ─────────────────────────────────────────────
  // Server side (runs on CHILD device)
  // ─────────────────────────────────────────────

  /// Start TCP server to accept parent connections
  Future<void> startServer(String pairToken) async {
    if (_isServerRunning) return;
    _pairToken = pairToken;

    try {
      _server = await ServerSocket.bind(InternetAddress.anyIPv4, _port);
      _isServerRunning = true;
      print('🖥️ LAN Data server started on port $_port');

      _server!.listen(
        (socket) => _handleIncomingConnection(socket),
        onError: (e) => print('LAN Server error: $e'),
      );
    } catch (e) {
      print('❌ LAN Server start failed: $e');
    }
  }

  void _handleIncomingConnection(Socket socket) {
    print('🔌 Parent connected from ${socket.remoteAddress.address}');

    // Buffer for incomplete messages
    String buffer = '';

    socket.listen(
      (data) {
        buffer += utf8.decode(data);

        // Process complete JSON lines
        while (buffer.contains('\n')) {
          final idx = buffer.indexOf('\n');
          final line = buffer.substring(0, idx).trim();
          buffer = buffer.substring(idx + 1);

          if (line.isNotEmpty) {
            _handleIncomingMessage(line, socket);
          }
        }
      },
      onDone: () {
        print('🔌 Parent disconnected');
        _activeConnection = null;
        _connectionStateController.add(false);
      },
      onError: (e) {
        print('LAN connection error: $e');
        _activeConnection = null;
        _connectionStateController.add(false);
      },
    );

    // Verify pair token via handshake
    _activeConnection = socket;
    _connectionStateController.add(true);
  }

  void _handleIncomingMessage(String line, Socket socket) {
    try {
      final json = jsonDecode(line) as Map<String, dynamic>;
      final type = json['type'] as String?;

      switch (type) {
        case 'handshake':
          // Verify pair token
          if (json['pairToken'] == _pairToken) {
            _sendToSocket(socket, {'type': 'handshake_ok'});
            print('✅ Parent authenticated via LAN');
          } else {
            _sendToSocket(socket, {'type': 'handshake_fail', 'reason': 'Invalid token'});
            socket.close();
          }
          break;

        case 'alert':
          // Received alert from child (parent side)
          final alert = NetworkAlertFull.fromJson(json['data'] as Map<String, dynamic>);
          _alertReceivedController.add(alert);
          break;

        case 'ack':
          // Alert acknowledged
          break;

        default:
          print('Unknown LAN message type: $type');
      }
    } catch (e) {
      print('LAN message parse error: $e');
    }
  }

  // ─────────────────────────────────────────────
  // Client side (runs on PARENT device)
  // ─────────────────────────────────────────────

  /// Connect to child device's TCP server
  Future<bool> connectToDevice(LanDeviceInfo device, String pairToken) async {
    _pairToken = pairToken;

    try {
      _clientSocket = await Socket.connect(
        device.ipAddress,
        device.port,
        timeout: const Duration(seconds: 5),
      );

      _isClientConnected = true;
      _connectionStateController.add(true);
      print('🔌 Connected to child at ${device.ipAddress}:${device.port}');

      // Buffer for incomplete messages
      String buffer = '';

      _clientSocket!.listen(
        (data) {
          buffer += utf8.decode(data);

          while (buffer.contains('\n')) {
            final idx = buffer.indexOf('\n');
            final line = buffer.substring(0, idx).trim();
            buffer = buffer.substring(idx + 1);

            if (line.isNotEmpty) {
              _handleIncomingMessage(line, _clientSocket!);
            }
          }
        },
        onDone: () {
          print('🔌 Disconnected from child');
          _isClientConnected = false;
          _clientSocket = null;
          _connectionStateController.add(false);
        },
        onError: (e) {
          print('LAN Client error: $e');
          _isClientConnected = false;
          _clientSocket = null;
          _connectionStateController.add(false);
        },
      );

      // Send handshake
      _sendToSocket(_clientSocket!, {
        'type': 'handshake',
        'pairToken': pairToken,
      });

      return true;
    } catch (e) {
      print('❌ LAN connect failed: $e');
      _isClientConnected = false;
      return false;
    }
  }

  // ─────────────────────────────────────────────
  // Shared — send data
  // ─────────────────────────────────────────────

  /// Send a full alert over LAN (child → parent)
  void sendAlert(NetworkAlertFull alert) {
    final target = _activeConnection ?? _clientSocket;
    if (target == null) return;

    _sendToSocket(target, {
      'type': 'alert',
      'data': alert.toJson(),
    });
  }

  void _sendToSocket(Socket socket, Map<String, dynamic> data) {
    try {
      final line = '${jsonEncode(data)}\n';
      socket.add(utf8.encode(line));
    } catch (e) {
      print('LAN send error: $e');
    }
  }

  // ─────────────────────────────────────────────
  // Lifecycle
  // ─────────────────────────────────────────────

  void stopServer() {
    _server?.close();
    _server = null;
    _activeConnection?.close();
    _activeConnection = null;
    _isServerRunning = false;
    print('🖥️ LAN Data server stopped');
  }

  void disconnectClient() {
    _clientSocket?.close();
    _clientSocket = null;
    _isClientConnected = false;
    _connectionStateController.add(false);
  }

  void dispose() {
    stopServer();
    disconnectClient();
    _alertReceivedController.close();
    _connectionStateController.close();
  }
}
