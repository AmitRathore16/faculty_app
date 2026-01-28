import 'dart:async';
import 'dart:io';

import 'package:faculty_pedia/features/messages/provider/chat_realtime_provider.dart';
import 'package:faculty_pedia/features/messages/provider/chat_providers.dart';
import 'package:faculty_pedia/features/messages/provider/chat_spcket_provider.dart';
import 'package:faculty_pedia/features/messages/services/chat_socket_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/models/message_model.dart';
import '../../../shared/widgets/app_network_image.dart';
import '../../../shared/widgets/state_widgets.dart';

class StudentChatScreen extends ConsumerStatefulWidget {
  final String conversationId;
  final String? title;
  final String receiverId;
  final String receiverType; // Educator

  const StudentChatScreen({
    super.key,
    required this.conversationId,
    this.title,
    required this.receiverId,
    required this.receiverType,
  });

  @override
  ConsumerState<StudentChatScreen> createState() => _StudentChatScreenState();
}

class _StudentChatScreenState extends ConsumerState<StudentChatScreen> {
  final _controller = TextEditingController();
  final _scrollCtrl = ScrollController();

  bool _sending = false;
  Timer? _typingStopTimer;

  @override
  void dispose() {
    _typingStopTimer?.cancel();

    // stop typing when leaving
    final socket = ChatSocketService.instance;
    socket.emitTyping(
      receiverId: widget.receiverId,
      conversationId: widget.conversationId,
      isTyping: false,
    );

    _controller.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 150), () {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _onTypingChanged(String value) {
    ref.read(chatSocketControllerProvider); // ensure socket connected

    final socket = ChatSocketService.instance;

    socket.emitTyping(
      receiverId: widget.receiverId,
      conversationId: widget.conversationId,
      isTyping: true,
    );

    _typingStopTimer?.cancel();
    _typingStopTimer = Timer(const Duration(milliseconds: 900), () {
      socket.emitTyping(
        receiverId: widget.receiverId,
        conversationId: widget.conversationId,
        isTyping: false,
      );
    });
  }

  Future<void> _sendText() async {
    final args = ChatRealtimeArgs(
      conversationId: widget.conversationId,
      receiverId: widget.receiverId,
    );
    final ctrl = ref.read(chatRealtimeProvider(args).notifier);

    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;

    setState(() => _sending = true);

    try {
      final msg = await ref.read(
        sendMessageProvider(
          SendMessagePayload(
            conversationId: widget.conversationId,
            receiverId: widget.receiverId,
            receiverType: widget.receiverType,
            content: text,
            messageType: "text",
            attachments: const [],
          ),
        ).future,
      );

// ✅ add message instantly to UI
      ctrl.addLocalMessage(msg);

      _controller.clear();
      _scrollToBottom();


      // typing off
      final socket = ChatSocketService.instance;
      socket.emitTyping(
        receiverId: widget.receiverId,
        conversationId: widget.conversationId,
        isTyping: false,
      );

      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send message: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _pickAndSendImage() async {
    if (_sending) return;

    final picker = ImagePicker();
    final img = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (img == null) return;

    setState(() => _sending = true);

    try {
      final chatApi = ref.read(chatApiProvider);

      final attachment = await chatApi.uploadChatImage(File(img.path));
      final url = attachment["url"];

      if (url == null) throw Exception("Image upload failed");

      await ref.read(
        sendMessageProvider(
          SendMessagePayload(
            conversationId: widget.conversationId,
            receiverId: widget.receiverId,
            receiverType: widget.receiverType,
            content: "Image",
            messageType: "image",
            attachments: [
              {"url": url, "type": "image"}
            ],
          ),
        ).future,
      );

      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send image: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // ensure socket connected
    ref.watch(chatSocketControllerProvider);

    final args = ChatRealtimeArgs(
      conversationId: widget.conversationId,
      receiverId: widget.receiverId,
    );


    final rt = ref.watch(chatRealtimeProvider(args));
    final ctrl = ref.read(chatRealtimeProvider(args).notifier);

    // auto scroll when messages change
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.title ?? 'Chat'),
            if (rt.otherTyping)
              const Text(
                "typing...",
                style: TextStyle(fontSize: 12, color: AppColors.primary),
              ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              context.go('/messages');
            }
          },
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: Builder(
              builder: (_) {
                if (rt.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                final messages = rt.messages;

                if (messages.isEmpty) {
                  return const EmptyStateWidget(
                    icon: Icons.chat_outlined,
                    title: 'No messages yet',
                    subtitle: 'Say hi 👋 to start conversation',
                  );
                }

                return ListView.builder(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final ChatMessage m = messages[index];
                    final isMe = m.sender.userType.toLowerCase() == "student";

                    // ✅ Feature 7: mark educator message read when displayed
                    if (!isMe && !m.isRead) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        ctrl.markMessageRead(m.id);
                      });
                    }

                    return _MessageBubble(message: m, isMe: isMe);
                  },
                );
              },
            ),
          ),

          // composer
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 12,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: _sending ? null : _pickAndSendImage,
                    icon: const Icon(Icons.image_outlined),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      minLines: 1,
                      maxLines: 4,
                      onChanged: _onTypingChanged,
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        filled: true,
                        fillColor: AppColors.grey100,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton(
                    onPressed: _sending ? null : _sendText,
                    icon: _sending
                        ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                        : const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// =======================
/// Message Bubble (same UI)
/// =======================

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMe;

  const _MessageBubble({
    required this.message,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
    final content = message.content.trim();
    final messageType = message.messageType;
    final attachments = message.attachments;

    final maxW = MediaQuery.of(context).size.width * 0.72;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxW),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: isMe ? AppColors.primary : AppColors.grey100,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (messageType == "image" && attachments.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: AppNetworkImage(
                      imageUrl: attachments.first.url,
                      height: 180,
                      width: maxW,
                      fit: BoxFit.cover,
                    ),
                  ),
                if (content.isNotEmpty) ...[
                  if (messageType == "image") const SizedBox(height: 8),
                  Text(
                    content,
                    style: TextStyle(
                      color: isMe ? Colors.white : AppColors.grey900,
                      fontSize: 14,
                      height: 1.35,
                    ),
                  ),
                ],
                const SizedBox(height: 6),

                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (message.createdAt != null)
                      Text(
                        _formatTime(message.createdAt!),
                        style: TextStyle(
                          fontSize: 10,
                          color: isMe ? Colors.white70 : AppColors.grey600,
                        ),
                      ),
                    if (isMe) ...[
                      const SizedBox(width: 6),
                      Icon(
                        message.isRead ? Icons.done_all : Icons.done,
                        size: 14,
                        color: message.isRead ? Colors.lightBlueAccent : Colors.white70,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final local = dt.toLocal();
    final h = local.hour.toString().padLeft(2, '0');
    final m = local.minute.toString().padLeft(2, '0');
    return "$h:$m";
  }
}
