import 'package:faculty_pedia/features/auth/providers/auth_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/chat_api_services.dart';
import '../../../shared/models/conversation_model.dart';
import '../../../shared/models/message_model.dart';

// ================= Service Provider =================

final chatApiProvider = Provider<ChatApiService>((ref) {
  final api = ref.watch(apiServiceProvider);
  return ChatApiService(api);
});

// ================= Conversations =================

final chatConversationsProvider =
FutureProvider.autoDispose<List<ChatConversation>>((ref) async {
  final chatApi = ref.watch(chatApiProvider);
  return chatApi.getConversations();
});

// ================= Unread Count =================

final chatUnreadCountProvider = FutureProvider.autoDispose<int>((ref) async {
  final chatApi = ref.watch(chatApiProvider);
  return chatApi.getUnreadCount();
});

// ================= Messages =================

final chatMessagesProvider =
FutureProvider.autoDispose.family<List<ChatMessage>, String>(
        (ref, conversationId) async {
      final chatApi = ref.watch(chatApiProvider);

      // mark conversation read when opened
      await chatApi.markConversationRead(conversationId: conversationId);

      return chatApi.getMessages(conversationId: conversationId);
    });

// ================= Create conversation =================

final createConversationProvider =
FutureProvider.autoDispose.family<ChatConversation, String>(
        (ref, educatorId) async {
      final chatApi = ref.watch(chatApiProvider);
      return chatApi.createStudentEducatorConversation(educatorId: educatorId);
    });

// ================= Send Message Controller =================

class SendMessagePayload {
  final String conversationId;
  final String receiverId;
  final String receiverType; // Educator
  final String content;
  final String messageType;
  final List<Map<String, dynamic>> attachments;

  SendMessagePayload({
    required this.conversationId,
    required this.receiverId,
    required this.receiverType,
    required this.content,
    this.messageType = "text",
    this.attachments = const [],
  });
}

final sendMessageProvider =
FutureProvider.autoDispose.family<ChatMessage, SendMessagePayload>(
        (ref, payload) async {
      final chatApi = ref.watch(chatApiProvider);

      final message = await chatApi.sendMessage(
        conversationId: payload.conversationId,
        receiverId: payload.receiverId,
        receiverType: payload.receiverType,
        content: payload.content,
        messageType: payload.messageType,
        attachments: payload.attachments,
      );

      // Refresh
      ref.invalidate(chatMessagesProvider(payload.conversationId));
      ref.invalidate(chatConversationsProvider);
      ref.invalidate(chatUnreadCountProvider);

      return message;
    });
