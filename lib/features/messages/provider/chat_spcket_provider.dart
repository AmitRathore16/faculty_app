import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/chat_socket_service.dart';

/// socket service provider (singleton)
final chatSocketServiceProvider = Provider<ChatSocketService>((ref) {
  return ChatSocketService.instance;
});

/// controller provider => just ensures connection lifecycle
// final chatSocketControllerProvider = Provider.autoDispose<void>((ref) {
//   final socket = ref.watch(chatSocketServiceProvider);
//
//   // connect once
//   socket.connect();
//
//   // disconnect when module disposed
//   ref.onDispose(() {
//     // ⚠️ optional:
//     // If you want socket always on, comment this line.
//     // For production I recommend keeping it connected globally.
//     // socket.disconnect();
//   });
// });
final chatSocketControllerProvider = Provider<void>((ref) {
  final socket = ref.watch(chatSocketServiceProvider);

  socket.connect();

  // ❌ no ref.onDispose disconnect
});
