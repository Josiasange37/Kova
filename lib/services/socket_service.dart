import 'dart:async';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:kova/models/alert.dart';

class SocketService {
  static const String serverUrl = 'http://localhost:3000';
  final _storage = const FlutterSecureStorage();
  
  IO.Socket? _socket;
  
  // Streams for real-time events
  final _alertStreamController = StreamController<Alert>.broadcast();
  final _childStatusStreamController = StreamController<Map<String, dynamic>>.broadcast();
  final _appBlockedStreamController = StreamController<Map<String, dynamic>>.broadcast();
  final _screenTimeStreamController = StreamController<Map<String, dynamic>>.broadcast();

  // Public stream getters
  Stream<Alert> get onNewAlert => _alertStreamController.stream;
  Stream<Map<String, dynamic>> get onChildStatus => _childStatusStreamController.stream;
  Stream<Map<String, dynamic>> get onAppBlocked => _appBlockedStreamController.stream;
  Stream<Map<String, dynamic>> get onScreenTimeUpdate => _screenTimeStreamController.stream;

  // Singleton pattern
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  Future<void> connect() async {
    if (_socket != null && _socket!.connected) return;

    final token = await _storage.read(key: 'jwt_token');
    if (token == null) return;

    _socket = IO.io(serverUrl, IO.OptionBuilder()
        .setTransports(['websocket'])
        .setAuth({'token': token})
        .disableAutoConnect()
        .build());

    _setupListeners();
    _socket!.connect();
  }

  void _setupListeners() {
    _socket?.onConnect((_) {
      print('Socket connected');
    });

    _socket?.onDisconnect((_) {
      print('Socket disconnected');
    });

    _socket?.onConnectError((err) {
      print('Socket connect error: $err');
    });

    // Listen for new alerts
    _socket?.on('alert:new', (data) {
      print('Received new alert: $data');
      if (data != null) {
        try {
          final alert = Alert.fromJson(data);
          _alertStreamController.add(alert);
        } catch (e) {
          print('Error parsing alert socket data: $e');
        }
      }
    });

    // Listen for child online/offline status
    _socket?.on('child:status', (data) {
      print('Received child status update: $data');
      if (data != null) {
        _childStatusStreamController.add(data);
      }
    });

    // Listen for app blocks
    _socket?.on('app:blocked', (data) {
      print('Received app blocked event: $data');
      if (data != null) {
        _appBlockedStreamController.add(data);
      }
    });

    // Listen for screen time updates
    _socket?.on('child:screentime', (data) {
      print('Received screen time update: $data');
      if (data != null) {
        _screenTimeStreamController.add(data);
      }
    });
  }

  void disconnect() {
    _socket?.disconnect();
    _socket = null;
  }

  void dispose() {
    disconnect();
    _alertStreamController.close();
    _childStatusStreamController.close();
    _appBlockedStreamController.close();
    _screenTimeStreamController.close();
  }
}
