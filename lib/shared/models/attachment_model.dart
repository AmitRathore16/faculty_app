class ChatAttachment {
  final String url;
  final String? type; // image/pdf/document
  final String? filename;
  final int? size;

  ChatAttachment({
    required this.url,
    this.type,
    this.filename,
    this.size,
  });

  factory ChatAttachment.fromJson(Map<String, dynamic> json) {
    return ChatAttachment(
      url: json['url'] ?? '',
      type: json['type'],
      filename: json['filename'],
      size: json['size'],
    );
  }

  Map<String, dynamic> toJson() => {
    "url": url,
    "type": type,
    "filename": filename,
    "size": size,
  };
}
