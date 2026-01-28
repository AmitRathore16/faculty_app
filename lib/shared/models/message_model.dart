import 'chat_user_model.dart';

class ChatAttachment {
  final String url;
  final String type;
  final String? filename;
  final int? size;

  ChatAttachment({
    required this.url,
    required this.type,
    this.filename,
    this.size,
  });

  factory ChatAttachment.fromJson(Map<String, dynamic> json) {
    return ChatAttachment(
      url: (json["url"] ?? "").toString(),
      type: (json["type"] ?? "image").toString(),
      filename: json["filename"]?.toString(),
      size: json["size"] is int ? json["size"] : int.tryParse("${json["size"]}"),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "url": url,
      "type": type,
      if (filename != null) "filename": filename,
      if (size != null) "size": size,
    };
  }
}

class ChatSideUser {
  final String userType;
  final ChatUser? user; // populated
  final String? userId; // not populated

  ChatSideUser({
    required this.userType,
    this.user,
    this.userId,
  });

  factory ChatSideUser.fromJson(Map<String, dynamic> json) {
    final raw = json["userId"];
    final type = (json["userType"] ?? "").toString();

    if (raw is Map) {
      final id = (raw["_id"] ?? raw["id"] ?? "").toString();
      return ChatSideUser(
        userType: type,
        userId: id,
        user: ChatUser(
          id: id,
          userType: type,
          fullName: raw["fullName"]?.toString(),
          name: raw["name"]?.toString(),
          username: raw["username"]?.toString(),
          email: raw["email"]?.toString(),
          profilePicture: raw["profilePicture"]?.toString(),
          image: raw["image"]?.toString(),
        ),
      );
    }

    return ChatSideUser(
      userType: type,
      userId: raw?.toString(),
    );
  }

  String get id => user?.id ?? userId ?? "";
}

class ChatMessage {
  final String id;
  final String conversationId;
  final ChatSideUser sender;
  final ChatSideUser receiver;
  final String content;
  final String messageType;
  final List<ChatAttachment> attachments;
  final bool isRead;
  final DateTime? createdAt;

  ChatMessage({
    required this.id,
    required this.conversationId,
    required this.sender,
    required this.receiver,
    required this.content,
    required this.messageType,
    required this.attachments,
    required this.isRead,
    required this.createdAt,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: (json["_id"] ?? json["id"] ?? "").toString(),
      conversationId: (json["conversationId"] ?? "").toString(),
      sender: ChatSideUser.fromJson(Map<String, dynamic>.from(json["sender"] ?? {})),
      receiver: ChatSideUser.fromJson(Map<String, dynamic>.from(json["receiver"] ?? {})),
      content: (json["content"] ?? "").toString(),
      messageType: (json["messageType"] ?? "text").toString(),
      attachments: ((json["attachments"] as List?) ?? [])
          .map((e) => ChatAttachment.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      isRead: json["isRead"] == true,
      createdAt: json["createdAt"] != null
          ? DateTime.tryParse(json["createdAt"].toString())
          : null,
    );
  }
  ChatMessage copyWith({
    bool? isRead,
  }) {
    return ChatMessage(
      id: id,
      conversationId: conversationId,
      sender: sender,
      receiver: receiver,
      content: content,
      messageType: messageType,
      attachments: attachments,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt,
    );
  }

}
