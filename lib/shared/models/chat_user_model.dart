class ChatUser {
  final String id;
  final String userType; // Student / Educator
  final String? fullName;
  final String? name;
  final String? username;
  final String? email;
  final String? profilePicture;
  final String? image;

  ChatUser({
    required this.id,
    required this.userType,
    this.fullName,
    this.name,
    this.username,
    this.email,
    this.profilePicture,
    this.image,
  });

  factory ChatUser.fromParticipantJson(Map<String, dynamic> json) {
    final userIdRaw = json["userId"];
    final type = (json["userType"] ?? "").toString();

    // userId may be populated object OR string
    if (userIdRaw is Map) {
      final id = (userIdRaw["_id"] ?? userIdRaw["id"] ?? "").toString();
      return ChatUser(
        id: id,
        userType: type,
        fullName: userIdRaw["fullName"]?.toString(),
        name: userIdRaw["name"]?.toString(),
        username: userIdRaw["username"]?.toString(),
        email: userIdRaw["email"]?.toString(),
        profilePicture: userIdRaw["profilePicture"]?.toString(),
        image: userIdRaw["image"]?.toString(),
      );
    }

    return ChatUser(
      id: (userIdRaw ?? "").toString(),
      userType: type,
    );
  }

  String get displayName =>
      (fullName ?? name ?? username ?? "User").trim();

  String? get avatarUrl {
    final url = (profilePicture ?? image ?? "").trim();
    return url.isEmpty ? null : url;
  }
}
