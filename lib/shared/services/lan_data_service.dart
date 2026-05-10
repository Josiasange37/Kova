// shared/services/lan_data_service.dart — TCP server/client for full data transfer
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:kova/shared/models/network_alert.dart';
import 'package:kova/shared/services/security_service.dart';

// Native channel for Wi-Fi power management
const _setupChannel = MethodChannel('com.kova.child/setup');

/// Data about a child profile received over LAN (used by parent)
class LanChildProfile {
  final String childId;
  final String name;
  final int age;
  LanChildProfile({required this.childId, required this.name, required this.age});
  factory LanChildProfile.fromJson(Map<String, dynamic> j) => LanChildProfile(
    childId: j['childId'] as String? ?? '',
    name: j['name'] as String? ?? 'Child',
    age: j['age'] as int? ?? 10,
  );
}

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
  final SecurityService _securityService = SecurityService();

  bool _isServerRunning = false;
  bool _isClientConnected = false;

  Timer? _heartbeatTimer;
  String? _lastPeerIp;
  int? _lastPeerPort;
  String? _lastPairToken;
  Completer<bool>? _handshakeCompleter;

  final _alertReceivedController = StreamController<NetworkAlertFull>.broadcast();
  final _connectionStateController = StreamController<bool>.broadcast();
  final _childProfileReceivedController = StreamController<LanChildProfile>.broadcast();

  Stream<NetworkAlertFull> get onAlertReceived => _alertReceivedController.stream;
  Stream<bool> get onConnectionChanged => _connectionStateController.stream;
  /// Fires when the parent receives a CHILD_PROFILE message from the child device.
  Stream<LanChildProfile> get onChildProfileReceived => _childProfileReceivedController.stream;

  bool get isConnected => _isClientConnected || _activeConnection != null;

  /// Verify the socket is truly healthy (not just "connected" in our state)
  bool get isSocketHealthy {
    final target = _activeConnection ?? _clientSocket;
    if (target == null) return false;
    // Check if the socket's remote address is still reachable
    // If the socket was closed, accessing remoteAddress throws
    try {
      target.remoteAddress;
      return true;
    } catch (_) {
      // Socket is dead — clean up our state
      if (_activeConnection != null) {
        _activeConnection = null;
        _connectionStateController.add(false);
      }
      if (_isClientConnected) {
        _isClientConnected = false;
        _clientSocket = null;
        _connectionStateController.add(false);
      }
      return false;
    }
  }

  // ─────────────────────────────────────────────
  // Server side (runs on CHILD device)
  // ─────────────────────────────────────────────

  void setPairToken(String token) {
    _pairToken = token;
  }

  /// Start TCP server to accept parent connections
  Future<void> startServer([String pairToken = '']) async {
    if (_isServerRunning) return;
    if (pairToken.isNotEmpty) {
      _pairToken = pairToken;
    }
    _securityService.init();

    try {
      _server = await ServerSocket.bind(InternetAddress.anyIPv4, _port, shared: true);
      _isServerRunning = true;
      debugPrint('✅ [LAN] Parent TCP server listening on port $_port');

      _server!.listen(
        (socket) {
           debugPrint('✅ [LAN SERVER] Client connected: ${socket.remoteAddress}');
           _handleIncomingConnection(socket);
        },
        onError: (e) => print('❌ LAN Server error: $e'),
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

    // Start keepalive heartbeat from server side too.
    // Without this, the child has no way to detect a broken connection
    // and will queue alerts into a dead socket silently.
    startHeartbeat();

    // Acquire WifiLock so radio stays in high-perf mode for the data socket.
    // This prevents 200-400ms latency spikes between TCP packets.
    _acquireWifiLock();
  }

  void _handleIncomingMessage(String line, Socket socket) {
    debugPrint('📩 [LAN INCOMING] Received message: ${line.length > 50 ? line.substring(0, 50) + '...' : line}');
    try {
      final json = jsonDecode(line) as Map<String, dynamic>;
      final type = json['type'] as String?;

      switch (type) {
        case 'handshake':
          // Verify pair token
          if (_pairToken.isEmpty || json['pairToken'] == _pairToken) {
            if (_pairToken.isEmpty) {
              _pairToken = json['pairToken'] as String;
            }
            if (json['publicKey'] != null) {
              _securityService.setPeerPublicKey(json['publicKey'] as String);
            }
            final myPublicKey = _securityService.generateKeyPair()['public'];
            _sendToSocket(socket, {'type': 'handshake_ok', 'publicKey': myPublicKey});
            print('✅ Client authenticated via LAN');
          } else {
            _sendToSocket(socket, {'type': 'handshake_fail', 'reason': 'Invalid token'});
            socket.close();
          }
          break;
          
        case 'handshake_ok':
          if (json['publicKey'] != null) {
            _securityService.setPeerPublicKey(json['publicKey'] as String);
            print('✅ Handshake OK: Stored peer public key');
            if (_handshakeCompleter != null && !_handshakeCompleter!.isCompleted) {
              _handshakeCompleter!.complete(true);
            }
          }
          break;

        case 'child_profile':
          // Parent receives child's name/age immediately after LAN pairing
          final profile = LanChildProfile.fromJson(json['data'] as Map<String, dynamic>? ?? {});
          print('👶 Received child profile over LAN: ${profile.name} (id=${profile.childId})');
          _childProfileReceivedController.add(profile);
          break;

        case 'alert':
          // Legacy unencrypted alert format (for backwards compatibility if needed, but we shouldn't really use this now)
          final alert = NetworkAlertFull.fromJson(json['data'] as Map<String, dynamic>);
          _alertReceivedController.add(alert);
          break;

        case 'encrypted_alert':
          debugPrint('📥 [LAN DATA] Received encrypted_alert, attempting RSA decryption...');
          // Decrypt with RSA
          final encryptedData = json['data'] as String? ?? '';
          final decryptedStr = _securityService.decryptPayload(encryptedData);
          
          if (decryptedStr.isNotEmpty && !decryptedStr.startsWith('DECRYPTION_ERROR')) {
            try {
              final alertJson = jsonDecode(decryptedStr) as Map<String, dynamic>;
              final alert = NetworkAlertFull.fromJson(alertJson);
              debugPrint('✅ [LAN DATA] Decrypted alert successfully: ${alert.app} -> ${alert.alertType}');
              _alertReceivedController.add(alert);
            } catch(e) {
              print('❌ JSON parse error after RSA decryption: $e');
            }
          } else {
            print('❌ Failed to decrypt RSA LAN alert: $decryptedStr');
          }
          break;

        case 'ack':
          // Alert acknowledged
          break;

        case 'ping':
          // Heartbeat ping — silently ignore (keeps connection alive)
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
    return await connectToParent(device.ipAddress, device.port, pairToken);
  }

  Future<bool> connectToParent(String ip, int port, String token) async {
    debugPrint('🔌 [LAN] Connecting to parent at $ip:$port...');
    _lastPeerIp = ip;
    _lastPeerPort = port;
    _lastPairToken = token;
    _pairToken = token;
    _securityService.init();

    int attempts = 0;
    while (attempts < 5) {
      try {
        _clientSocket?.destroy();
        _clientSocket = await Socket.connect(
          ip,
          port,
          timeout: const Duration(seconds: 5),
        );
        _isClientConnected = true;
        _connectionStateController.add(true);
        startHeartbeat();
        debugPrint('✅ [LAN] TCP socket connected to $ip:$port, waiting for handshake...');

        _handshakeCompleter = Completer<bool>();

        // Hold WifiLock for the duration of this TCP connection
        _acquireWifiLock();

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
            print('🔌 Disconnected from parent');
            _isClientConnected = false;
            _clientSocket = null;
            _connectionStateController.add(false);
            _releaseWifiLock();
          },
          onError: (e) {
            print('LAN Client error: $e');
            _isClientConnected = false;
            _clientSocket = null;
            _connectionStateController.add(false);
            _releaseWifiLock();
          },
        );

        // Send handshake
        final myPublicKey = _securityService.generateKeyPair()['public'];
        _sendToSocket(_clientSocket!, {
          'type': 'handshake',
          'pairToken': token,
          'publicKey': myPublicKey,
        });

        // Wait for handshake_ok
        try {
          await _handshakeCompleter!.future.timeout(const Duration(seconds: 3));
          debugPrint('✅ [LAN] Handshake complete, keys exchanged.');
          return true;
        } catch (e) {
          debugPrint('❌ [LAN] Handshake timed out: $e');
          _clientSocket?.destroy();
          throw Exception('Handshake timeout');
        }
      } catch (e) {
        attempts++;
        debugPrint('⚠️ [LAN] Connect attempt $attempts failed: $e');
        await Future.delayed(Duration(milliseconds: 500 * attempts));
      }
    }
    debugPrint('❌ [LAN] Failed to connect after 5 attempts');
    _isClientConnected = false;
    return false;
  }

  Future<void> attemptReconnect() async {
    if (_lastPeerIp == null) {
      debugPrint('⚠️ [LAN] Cannot reconnect — no previous peer info');
      return;
    }
    debugPrint('🔁 [LAN] Attempting reconnect to $_lastPeerIp...');
    try {
      final success = await connectToParent(_lastPeerIp!, _lastPeerPort ?? 18757, _lastPairToken ?? '');
      if (success) {
        debugPrint('✅ [LAN] Reconnected successfully');
      } else {
        debugPrint('❌ [LAN] Reconnect failed');
        _isClientConnected = false;
      }
    } catch (e) {
      debugPrint('❌ [LAN] Reconnect error: $e');
      _isClientConnected = false;
    }
  }

  void startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      final target = _activeConnection ?? _clientSocket;
      if (target != null) {
        try {
          // Send lightweight ping — just a newline the other side ignores
          target.writeln('{"type":"ping"}');
          debugPrint('💓 [LAN] Heartbeat sent');
        } catch (e) {
          debugPrint('⚠️ [LAN] Heartbeat failed — socket dead: $e');
          _isClientConnected = false;
          attemptReconnect();
        }
      }
    });
  }

  void stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  // ─── Wi-Fi Power Management ────────────────────────────────────────
  // Keep the Wi-Fi radio in HIGH_PERF mode for the life of the TCP connection.
  // Same pattern used by KDE Connect to eliminate inter-packet latency.

  Future<void> _acquireWifiLock() async {
    try {
      if (Platform.isAndroid) {
        await _setupChannel.invokeMethod('acquireWifiLock');
        debugPrint('📡 [LAN] WifiLock acquired — radio in HIGH_PERF mode');
      }
    } catch (e) {
      debugPrint('⚠️ [LAN] Failed to acquire WifiLock: $e');
    }
  }

  Future<void> _releaseWifiLock() async {
    try {
      if (Platform.isAndroid) {
        await _setupChannel.invokeMethod('releaseWifiLock');
        debugPrint('📡 [LAN] WifiLock released');
      }
    } catch (e) {
      debugPrint('⚠️ [LAN] Failed to release WifiLock: $e');
    }
  }

  // ─────────────────────────────────────────────
  // Shared — send data
  // ─────────────────────────────────────────────

  /// Send child profile to parent immediately after LAN pairing (child → parent)
  void sendChildProfile({required String childId, required String name, required int age}) {
    final target = _activeConnection ?? _clientSocket;
    if (target == null) {
      print('⚠️ sendChildProfile: no socket available yet, will retry in 500ms...');
      // Retry once after 500ms in case TCP connection is still establishing
      Future.delayed(const Duration(milliseconds: 500), () {
        final t2 = _activeConnection ?? _clientSocket;
        if (t2 != null) {
          _sendToSocket(t2, {
            'type': 'child_profile',
            'data': {'childId': childId, 'name': name, 'age': age},
          });
          print('📤 Child profile sent via LAN (delayed): $name');
        }
      });
      return;
    }
    _sendToSocket(target, {
      'type': 'child_profile',
      'data': {'childId': childId, 'name': name, 'age': age},
    });
    print('📤 Child profile sent via LAN: $name (id=$childId)');
  }

  /// Send a full alert over LAN (child → parent)
  void sendAlert(NetworkAlertFull alert) {
    final target = _activeConnection ?? _clientSocket;
    if (target == null) return;

    final alertJsonStr = jsonEncode(alert.toJson());
    final encryptedAlert = _securityService.encryptPayload(alertJsonStr);

    _sendToSocket(target, {
      'type': 'encrypted_alert',
      'data': encryptedAlert,
    });
  }

  /// Safe version of sendAlert that returns true only if the socket write succeeded.
  /// Used by NetworkSyncService to decide whether to delete from the pending queue.
  bool sendAlertSafe(NetworkAlertFull alert) {
    debugPrint('📤 [LAN DATA] sendAlertSafe triggered for ${alert.app}');
    final target = _activeConnection ?? _clientSocket;
    if (target == null) {
      debugPrint('❌ [LAN DATA] sendAlertSafe failed: No socket available');
      return false;
    }

    try {
      // Verify socket is still alive before writing
      target.remoteAddress; // throws if socket is closed

      debugPrint('🔒 [LAN DATA] Encrypting alert payload...');
      final alertJsonStr = jsonEncode(alert.toJson());
      final encryptedAlert = _securityService.encryptPayload(alertJsonStr);
      
      if (encryptedAlert.startsWith('ERROR') || encryptedAlert.isEmpty) {
        debugPrint('❌ [LAN DATA] RSA Encryption failed (missing peer key?)');
        return false;
      }

      final line = '${jsonEncode({
        'type': 'encrypted_alert',
        'data': encryptedAlert,
      })}\n';
      target.add(utf8.encode(line));
      debugPrint('✅ [LAN DATA] Alert payload pushed to TCP socket');
      return true;
    } catch (e) {
      print('❌ [LAN DATA] LAN sendAlertSafe FAILED (socket dead): $e');
      // Clean up dead socket state
      if (target == _activeConnection) {
        _activeConnection = null;
      }
      if (target == _clientSocket) {
        _isClientConnected = false;
        _clientSocket = null;
      }
      _connectionStateController.add(false);
      return false;
    }
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
    stopHeartbeat();
    _clientSocket?.close();
    _clientSocket = null;
    _isClientConnected = false;
    _connectionStateController.add(false);
  }

  void dispose() {
    stopHeartbeat();
    stopServer();
    disconnectClient();
    _alertReceivedController.close();
    _connectionStateController.close();
    _childProfileReceivedController.close();
  }
}
