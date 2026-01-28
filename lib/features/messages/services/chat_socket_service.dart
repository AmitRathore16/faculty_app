import 'dart:async';
import 'dart:convert';

import 'package:socket_io_client/socket_io_client.dart' as io;

import '../../../core/config/app_config.dart';
import '../../../core/services/storage_service.dart';

class ChatSocketService {
  ChatSocketService._();
  static final ChatSocketService instance = ChatSocketService._();

  io.Socket? _socket;

  bool get isConnected => _socket?.connected == true;

  // Streams for UI/providers
  final _newMessageCtrl = StreamController<Map<String, dynamic>>.broadcast();
  final _messageReadCtrl = StreamController<Map<String, dynamic>>.broadcast();
  final _typingCtrl = StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get onNewMessage => _newMessageCtrl.stream;
  Stream<Map<String, dynamic>> get onMessageRead => _messageReadCtrl.stream;
  Stream<Map<String, dynamic>> get onTyping => _typingCtrl.stream;

  Future<String?> _getToken() async {
    // ✅ adjust this key if your token stored with different key
    //return StorageService.getString(AppConfig.authTokenKey); //change
    return await StorageService.getSecure(AppConfig.authTokenKey);

  }

  String? _getUserId() {
    final userDataJson = StorageService.getString(AppConfig.userDataKey);
    if (userDataJson == null || userDataJson.isEmpty) return null;

    final map = jsonDecode(userDataJson);
    return (map["_id"] ?? map["id"])?.toString();
  }

  String? _getUserType() {
    // middleware expects: student/educator/admin
    // Student app -> "student"
    return "student";
  }

  /// ✅ Connect socket
  Future<void> connect() async {
    if (_socket != null && _socket!.connected) return;

    final baseUrl = AppConfig.baseUrl; // must be like: http://localhost:5000
    final token = await _getToken();

    if (token == null || token.isEmpty) {
      // no auth -> can't connect
      return;
    }

    // Connect to main server (namespace handled in backend)
    _socket = io.io(
      baseUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .enableReconnection()
          .setReconnectionAttempts(9999)
          .setReconnectionDelay(800)
          .setTimeout(6000)
          .setExtraHeaders({
        "Authorization": "Bearer $token",
      })
          .build(),
    );

    _socket!.onConnect((_) {
      // register socket mapping on server (you likely do this in your chat.socket.js)
      _socket!.emit("user_online", {
        "userId": _getUserId(),
        "userType": _getUserType(),
      });
    });

    _socket!.onDisconnect((_) {});

    // ✅ realtime events from backend
    _socket!.on("new_message", (data) {
      if (data is Map) {
        _newMessageCtrl.add(Map<String, dynamic>.from(data));
      }
    });

    _socket!.on("message_read", (data) {
      if (data is Map) {
        _messageReadCtrl.add(Map<String, dynamic>.from(data));
      }
    });

    _socket!.on("typing", (data) {
      if (data is Map) {
        _typingCtrl.add(Map<String, dynamic>.from(data));
      }
    });

    _socket!.connect();
  }

  void disconnect() {
    try {
      _socket?.disconnect();
      _socket?.dispose();
    } catch (_) {}
    _socket = null;
  }

  /// ✅ Emit typing event
  void emitTyping({
    required String receiverId,
    required String conversationId,
    required bool isTyping,
  }) {
    if (!isConnected) return;

    final senderId = _getUserId();
    if (senderId == null) return;

    _socket?.emit("typing", {
      "conversationId": conversationId,
      "userId": senderId,
      "receiverId": receiverId,
      "isTyping": isTyping,
    });
  }

  void dispose() {
    disconnect();
    _newMessageCtrl.close();
    _messageReadCtrl.close();
    _typingCtrl.close();
  }
}
