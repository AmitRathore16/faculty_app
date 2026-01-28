import 'chat_user_model.dart';
import 'message_model.dart';

class ChatConversation {
  final String id;
  final String conversationType;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? lastMessageAt;
  final ChatMessage? lastMessage;
  final List<ChatUser> participants;
  final int unreadCount;

  ChatConversation({
    required this.id,
    required this.conversationType,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    required this.lastMessageAt,
    required this.lastMessage,
    required this.participants,
    required this.unreadCount,
  });

  factory ChatConversation.fromJson(Map<String, dynamic> json) {
    final parts = (json["participants"] as List?) ?? [];

    return ChatConversation(
      id: (json["_id"] ?? json["id"] ?? "").toString(),
      conversationType: (json["conversationType"] ?? "").toString(),
      isActive: json["isActive"] == true,
      createdAt: json["createdAt"] != null
          ? DateTime.tryParse(json["createdAt"].toString())
          : null,
      updatedAt: json["updatedAt"] != null
          ? DateTime.tryParse(json["updatedAt"].toString())
          : null,
      lastMessageAt: json["lastMessageAt"] != null
          ? DateTime.tryParse(json["lastMessageAt"].toString())
          : null,
      lastMessage: json["lastMessage"] is Map
          ? ChatMessage.fromJson(Map<String, dynamic>.from(json["lastMessage"]))
          : null,
      participants: parts
          .map((e) => ChatUser.fromParticipantJson(Map<String, dynamic>.from(e)))
          .toList(),
      unreadCount: int.tryParse("${json["unreadCount"] ?? 0}") ?? 0,
    );
  }

  /// return other user in conversation (for UI title/photo)
  ChatUser? otherUser({required String currentUserId}) {
    for (final p in participants) {
      if (p.id.isNotEmpty && p.id != currentUserId) return p;
    }
    return null;
  }
}
