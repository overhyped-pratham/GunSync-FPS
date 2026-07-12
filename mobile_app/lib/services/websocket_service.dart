// GunSync FPS — WebSocket Service
// Manages connection to FastAPI relay server and message routing.

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as ws_status;

import 'dart:io';
import 'package:web_socket_channel/io.dart';

import '../models/input_packet.dart';
import '../models/recoil_event.dart';

enum ConnectionState {
  disconnected,
  connecting,
  connected,
  error,
}

class WebSocketService extends ChangeNotifier {
  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  Timer? _heartbeatTimer;

  ConnectionState _state = ConnectionState.disconnected;
  String _lastError = '';
  String _serverUrl = '';

  // ── Outbound stream controllers
  final _recoilController = StreamController<RecoilEvent>.broadcast();
  final _hitController = StreamController<HitEvent>.broadcast();
  final _statusController = StreamController<StatusEvent>.broadcast();
  final _ammoController = StreamController<AmmoEvent>.broadcast();

  // ── Exposed streams
  Stream<RecoilEvent> get onRecoil => _recoilController.stream;
  Stream<HitEvent> get onHit => _hitController.stream;
  Stream<StatusEvent> get onStatus => _statusController.stream;
  Stream<AmmoEvent> get onAmmo => _ammoController.stream;

  // ── Getters
  ConnectionState get state => _state;
  String get lastError => _lastError;
  String get serverUrl => _serverUrl;
  bool get isConnected => _state == ConnectionState.connected;

  /// Connect to the FastAPI /ws/phone endpoint.
  Future<bool> connect(String baseUrl) async {
    if (_state == ConnectionState.connecting ||
        _state == ConnectionState.connected) {
      await disconnect();
    }

    _serverUrl = baseUrl;
    _setState(ConnectionState.connecting);

    // Build WSS/WS URL — baseUrl may be ngrok (wss://) or local (ws://)
    final wsUrl = _buildPhoneUrl(baseUrl);
    debugPrint('[WS] Connecting to $wsUrl');

    try {
      // Connect using Dart's native WebSocket to pass ngrok-skip-browser-warning header
      final ws = await WebSocket.connect(
        wsUrl,
        headers: {
          'ngrok-skip-browser-warning': 'true',
        },
      ).timeout(const Duration(seconds: 8));

      _channel = IOWebSocketChannel(ws);
      _setState(ConnectionState.connected);
      _startListening();
      _startHeartbeat();
      debugPrint('[WS] Connected ✅');
      return true;
    } catch (e) {
      _lastError = e.toString();
      _setState(ConnectionState.error);
      debugPrint('[WS] Connection failed: $e');
      return false;
    }
  }

  /// Send an input packet to the server.
  void sendInput(InputPacket packet) {
    if (!isConnected) return;
    try {
      _channel!.sink.add(jsonEncode(packet.toJson()));
    } catch (e) {
      debugPrint('[WS] Send error: $e');
    }
  }

  /// Disconnect and clean up.
  Future<void> disconnect() async {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    await _sub?.cancel();
    _sub = null;
    await _channel?.sink.close(ws_status.normalClosure);
    _channel = null;
    _setState(ConnectionState.disconnected);
  }

  // ── Private

  String _buildPhoneUrl(String base) {
    // Strip trailing slash
    base = base.trimRight().replaceAll(RegExp(r'/+$'), '');

    // Append /ws/phone endpoint
    if (!base.endsWith('/ws/phone')) {
      base = '$base/ws/phone';
    }

    // ngrok TCP tunnels come as tcp:// — convert to ws://
    base = base.replaceFirst('tcp://', 'ws://');

    return base;
  }

  void _startListening() {
    _sub = _channel!.stream.listen(
      (raw) {
        if (raw is String) {
          _handleMessage(raw);
        }
      },
      onError: (e) {
        debugPrint('[WS] Stream error: $e');
        _lastError = e.toString();
        _setState(ConnectionState.error);
      },
      onDone: () {
        debugPrint('[WS] Stream closed');
        if (_state != ConnectionState.disconnected) {
          _setState(ConnectionState.disconnected);
        }
      },
    );
  }

  void _handleMessage(String raw) {
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final type = data['type'] as String? ?? '';

      switch (type) {
        case 'recoil':
          _recoilController.add(RecoilEvent.fromJson(data));
          break;
        case 'hit':
          _hitController.add(HitEvent.fromJson(data));
          break;
        case 'status':
          _statusController.add(StatusEvent.fromJson(data));
          break;
        case 'ammo':
          _ammoController.add(AmmoEvent.fromJson(data));
          break;
        default:
          debugPrint('[WS] Unknown event type: $type');
      }
    } catch (e) {
      debugPrint('[WS] Parse error: $e — raw: $raw');
    }
  }

  /// Send a keep-alive ping every 15 seconds.
  void _startHeartbeat() {
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (isConnected) {
        try {
          _channel!.sink.add('{"type":"ping"}');
        } catch (_) {}
      }
    });
  }

  void _setState(ConnectionState s) {
    _state = s;
    notifyListeners();
  }

  @override
  void dispose() {
    disconnect();
    _recoilController.close();
    _hitController.close();
    _statusController.close();
    _ammoController.close();
    super.dispose();
  }
}
