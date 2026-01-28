import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';

import '../../../core/config/app_config.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/storage_service.dart';
import '../../../shared/models/conversation_model.dart';
import '../../../shared/models/message_model.dart';

class ChatApiService {
  final ApiService _api;
  ChatApiService(this._api);

  // ================= Helpers =================
  String? _getStudentId() {
    final userDataJson = StorageService.getString(AppConfig.userDataKey);
    if (userDataJson == null || userDataJson.isEmpty) return null;

    final map = jsonDecode(userDataJson);
    return (map["_id"] ?? map["id"])?.toString();
  }

  // ================= API Calls =================

  Future<List<ChatConversation>> getConversations() async {
    final res = await _api.get("/api/chat/conversations");

    dynamic data = res.data;
    if (data is String) data = jsonDecode(data);

    final list = (data["data"]?["conversations"] ?? data["conversations"]) as List? ?? [];

    return list
        .map((e) => ChatConversation.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<int> getUnreadCount() async {
    final res = await _api.get("/api/chat/unread-count");

    dynamic data = res.data;
    if (data is String) data = jsonDecode(data);

    final unread = data?["data"]?["unreadCount"] ?? data?["unreadCount"] ?? 0;
    return int.tryParse(unread.toString()) ?? 0;
  }

  Future<ChatConversation> createStudentEducatorConversation({
    required String educatorId,
  }) async {
    final res = await _api.post(
      "/api/chat/conversations",
      data: {"otherUserId": educatorId},
    );

    dynamic data = res.data;
    if (data is String) data = jsonDecode(data);

    final convJson = data?["data"]?["conversation"] ?? data?["conversation"];
    if (convJson == null) {
      throw Exception("Conversation not returned from backend");
    }

    return ChatConversation.fromJson(Map<String, dynamic>.from(convJson));
  }

  Future<List<ChatMessage>> getMessages({
    required String conversationId,
    int page = 1,
    int limit = 50,
  }) async {
    final res = await _api.get(
      "/api/chat/conversations/$conversationId/messages",
      queryParameters: {"page": page, "limit": limit},
    );

    dynamic data = res.data;
    if (data is String) data = jsonDecode(data);

    final list = (data["data"]?["messages"] ?? data["messages"]) as List? ?? [];

    return list
        .map((e) => ChatMessage.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> markConversationRead({required String conversationId}) async {
    try {
      await _api.put("/api/chat/conversations/$conversationId/read");
    } catch (_) {}
  }

  Future<ChatMessage> sendMessage({
    required String conversationId,
    required String receiverId,
    required String receiverType,
    required String content,
    String messageType = "text",
    List<Map<String, dynamic>> attachments = const [],
  }) async {
    final res = await _api.post("/api/chat/messages", data: {
      "conversationId": conversationId,
      "receiverId": receiverId,
      "receiverType": receiverType,
      "content": content,
      "messageType": messageType,
      "attachments": attachments,
    });

    dynamic data = res.data;
    if (data is String) data = jsonDecode(data);

    final msgJson = data?["data"]?["message"] ?? data?["message"];
    if (msgJson == null) {
      throw Exception("Message not returned from backend");
    }

    return ChatMessage.fromJson(Map<String, dynamic>.from(msgJson));
  }

  // ================= Upload Chat Image =================

  Future<Map<String, dynamic>> uploadChatImage(File imageFile) async {
    final formData = FormData.fromMap({
      "image": await MultipartFile.fromFile(imageFile.path),
    });

    final res = await _api.post(
      "/api/chat/upload/image",
      data: formData,
      options: Options(contentType: "multipart/form-data"),
    );

    dynamic data = res.data;
    if (data is String) data = jsonDecode(data);

    final attachment = data?["data"]?["attachment"];
    if (attachment == null) {
      throw Exception("Image upload failed");
    }

    return Map<String, dynamic>.from(attachment);
  }
  Future<void> markMessageRead({required String messageId}) async {
    await _api.put("/api/chat/messages/$messageId/read");
  }

}
