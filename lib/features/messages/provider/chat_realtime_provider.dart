import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/message_model.dart';
import '../provider/chat_providers.dart';
import '../provider/chat_spcket_provider.dart';
import '../services/chat_socket_service.dart';

/// ============================
/// Args
/// ============================

class ChatRealtimeArgs {
  final String conversationId;
  final String receiverId;

  const ChatRealtimeArgs({
    required this.conversationId,
    required this.receiverId,
  });

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is ChatRealtimeArgs &&
            other.conversationId == conversationId &&
            other.receiverId == receiverId);
  }

  @override
  int get hashCode => Object.hash(conversationId, receiverId);
}


/// ============================
/// State
/// ============================

class ChatRealtimeState {
  final bool isLoading;
  final List<ChatMessage> messages;
  final bool otherTyping;

  const ChatRealtimeState({
    this.isLoading = false,
    this.messages = const [],
    this.otherTyping = false,
  });

  ChatRealtimeState copyWith({
    bool? isLoading,
    List<ChatMessage>? messages,
    bool? otherTyping,
  }) {
    return ChatRealtimeState(
      isLoading: isLoading ?? this.isLoading,
      messages: messages ?? this.messages,
      otherTyping: otherTyping ?? this.otherTyping,
    );
  }
}

/// ============================
/// Controller
/// ============================

class ChatRealtimeController extends StateNotifier<ChatRealtimeState> {
  final Ref ref;
  final String conversationId;
  final String receiverId;

  StreamSubscription? _newMsgSub;
  StreamSubscription? _readSub;
  StreamSubscription? _typingSub;

  bool _bootstrapped = false;

  ChatRealtimeController({
    required this.ref,
    required this.conversationId,
    required this.receiverId,
  }) : super(const ChatRealtimeState());
  void addLocalMessage(ChatMessage msg) {
    _addOrUpdate(msg);
  }

  Future<void> bootstrap() async {
    if (_bootstrapped) return;
    _bootstrapped = true;

    // ensure socket is connected
    ref.read(chatSocketControllerProvider);

    state = state.copyWith(isLoading: true);

    try {
      final api = ref.read(chatApiProvider);

      // mark conversation read (backend)
      await api.markConversationRead(conversationId: conversationId);

      // load messages once
      final list = await api.getMessages(conversationId: conversationId);
      state = state.copyWith(isLoading: false, messages: list);
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }

    _attachSocketListeners();
  }

  void _attachSocketListeners() {
    final socket = ref.read(chatSocketServiceProvider);

    _newMsgSub = socket.onNewMessage.listen((payload) async {
      final cid = payload["conversationId"]?.toString();
      if (cid != conversationId) return;

      final msgJson = payload["message"];
      if (msgJson is! Map) {
        await refresh();
        return;
      }

      final msg = ChatMessage.fromJson(Map<String, dynamic>.from(msgJson));
      _addOrUpdate(msg);

      // if message came from educator -> mark read
      final senderType = msg.sender.userType.toLowerCase();
      if (senderType == "educator") {
        await markMessageRead(msg.id);
      }

      // update conversation list + badge
      ref.invalidate(chatConversationsProvider);
      ref.invalidate(chatUnreadCountProvider);
    });

    _readSub = socket.onMessageRead.listen((payload) async {
      final cid = payload["conversationId"]?.toString();
      if (cid != null && cid != conversationId) return;

      final messageId = payload["messageId"]?.toString();
      if (messageId == null || messageId.isEmpty) {
        await refresh();
        return;
      }

      _setRead(messageId);
      ref.invalidate(chatConversationsProvider);
      ref.invalidate(chatUnreadCountProvider);
    });

    _typingSub = socket.onTyping.listen((payload) {
      final cid = payload["conversationId"]?.toString();
      final uid = payload["userId"]?.toString();
      final isTyping = payload["isTyping"] == true;

      if (cid == conversationId && uid == receiverId) {
        state = state.copyWith(otherTyping: isTyping);
      }
    });
  }

  Future<void> refresh() async {
    try {
      final api = ref.read(chatApiProvider);
      final list = await api.getMessages(conversationId: conversationId);
      state = state.copyWith(messages: list);
    } catch (_) {}
  }

  void _addOrUpdate(ChatMessage msg) {
    final list = [...state.messages];

    final index = list.indexWhere((e) => e.id == msg.id);
    if (index >= 0) {
      list[index] = msg;
    } else {
      list.add(msg);
    }

    list.sort((a, b) {
      final ad = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bd = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return ad.compareTo(bd);
    });

    state = state.copyWith(messages: list);
  }

  void _setRead(String messageId) {
    final updated = state.messages.map((m) {
      if (m.id == messageId) return m.copyWith(isRead: true);
      return m;
    }).toList();

    state = state.copyWith(messages: updated);
  }

  Future<void> markMessageRead(String messageId) async {
    try {
      final api = ref.read(chatApiProvider);
      await api.markMessageRead(messageId: messageId);

      // optimistic local update
      _setRead(messageId);

      // badges refresh
      ref.invalidate(chatUnreadCountProvider);
      ref.invalidate(chatConversationsProvider);
    } catch (_) {}
  }

  @override
  void dispose() {
    _newMsgSub?.cancel();
    _readSub?.cancel();
    _typingSub?.cancel();
    super.dispose();
  }
}

/// ============================
/// Provider
/// ============================

final chatRealtimeProvider = StateNotifierProvider.autoDispose
    .family<ChatRealtimeController, ChatRealtimeState, ChatRealtimeArgs>(
      (ref, args) {
    final ctrl = ChatRealtimeController(
      ref: ref,
      conversationId: args.conversationId,
      receiverId: args.receiverId,
    );
    ctrl.bootstrap();
    return ctrl;
  },
);
