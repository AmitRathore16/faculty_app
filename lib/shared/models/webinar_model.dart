class Webinar {
  final String id;

  final String title;
  final String description;
  final String slug;

  /// backend: image is String
  final String? image;

  /// backend: arrays
  final List<String> subject;
  final List<String> specialization;
  final List<String> classes; // backend key: "class"

  /// backend: educatorID populated OR string
  final String educatorId;
  final String? educatorName;
  final String? educatorEmail;

  final String webinarType; // "one-to-one" | "one-to-all"

  final DateTime timing; // backend key: timing
  final String duration; // backend: String

  final double fees;
  final bool isFree;

  final int seatLimit;

  /// backend: studentEnrolled list
  final List<String> studentEnrolled;

  /// backend: optional
  final String? webinarLink;

  /// backend: assetsLink array
  final List<String> assetsLink;

  /// backend: isActive
  final bool isActive;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// backend virtuals
  final int? enrolledCount;
  final int? seatsAvailable;
  final bool? isFull;

  Webinar({
    required this.id,
    required this.title,
    required this.description,
    required this.slug,
    required this.image,
    required this.subject,
    required this.specialization,
    required this.classes,
    required this.educatorId,
    required this.educatorName,
    required this.educatorEmail,
    required this.webinarType,
    required this.timing,
    required this.duration,
    required this.fees,
    required this.isFree,
    required this.seatLimit,
    required this.studentEnrolled,
    required this.webinarLink,
    required this.assetsLink,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    required this.enrolledCount,
    required this.seatsAvailable,
    required this.isFull,
  });

  /// ✅ for UI
  String get imageUrl => (image ?? '').trim();

  bool get hasJoinLink => (webinarLink ?? '').trim().isNotEmpty;
  bool get hasRecordings => assetsLink.isNotEmpty;

  /// Seats taken
  int get registeredCount => enrolledCount ?? studentEnrolled.length;

  int get remainingSeats {
    if (seatsAvailable != null) return seatsAvailable!;
    final rem = seatLimit - registeredCount;
    return rem < 0 ? 0 : rem;
  }

  bool get isUpcoming => timing.isAfter(DateTime.now());

  int? get durationMinutes {
    final match = RegExp(r'(\d+)').firstMatch(duration.toLowerCase().trim());
    if (match == null) return null;
    return int.tryParse(match.group(1)!);
  }

  bool get isLive {
    final mins = durationMinutes;
    if (mins == null) return false;
    final now = DateTime.now();
    final end = timing.add(Duration(minutes: mins));
    return now.isAfter(timing) && now.isBefore(end);
  }

  bool get isEnded {
    final mins = durationMinutes;
    if (mins == null) return timing.isBefore(DateTime.now());
    return DateTime.now().isAfter(timing.add(Duration(minutes: mins)));
  }

  factory Webinar.fromJson(Map<String, dynamic> json) {
    final educator = json['educatorID']; // backend: educatorID

    return Webinar(
      id: (json['_id'] ?? '').toString(),

      title: (json['title'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      slug: (json['slug'] ?? '').toString(),

      image: json['image']?.toString(),

      subject: _parseStringList(json['subject']),
      specialization: _parseStringList(json['specialization']),
      classes: _parseStringList(json['class']),

      educatorId: _parseEducatorId(educator, json),
      educatorName: _parseEducatorName(educator),
      educatorEmail: _parseEducatorEmail(educator),

      webinarType: (json['webinarType'] ?? 'one-to-all').toString(),

      timing: DateTime.parse(json['timing'].toString()),
      duration: (json['duration'] ?? '').toString(),

      fees: (json['fees'] as num?)?.toDouble() ?? 0,
      isFree: ((json['fees'] as num?)?.toDouble() ?? 0) == 0,

      seatLimit: (json['seatLimit'] as num?)?.toInt() ?? 0,

      studentEnrolled: _parseObjectIdList(json['studentEnrolled']),

      webinarLink: json['webinarLink']?.toString(),
      assetsLink: _parseStringList(json['assetsLink']),

      isActive: json['isActive'] == true,

      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'].toString())
          : null,

      enrolledCount: (json['enrolledCount'] as num?)?.toInt(),
      seatsAvailable: (json['seatsAvailable'] as num?)?.toInt(),
      isFull: json['isFull'] as bool?,
    );
  }

  static List<String> _parseStringList(dynamic value) {
    if (value == null) return [];
    if (value is String) return [value];
    if (value is List) return value.map((e) => e.toString()).toList();
    return [];
  }

  static List<String> _parseObjectIdList(dynamic value) {
    if (value == null) return [];

    if (value is List) {
      return value.map((e) {
        // ✅ populated object case
        if (e is Map && e['_id'] != null) return e['_id'].toString();
        return e.toString();
      }).toList();
    }

    return [];
  }


  static String _parseEducatorId(dynamic educator, Map<String, dynamic> json) {
    if (educator is String) return educator;
    if (educator is Map) return (educator['_id'] ?? '').toString();
    return (json['educatorID'] ?? '').toString();
  }

  static String? _parseEducatorName(dynamic educator) {
    if (educator is Map) return educator['name']?.toString();
    return null;
  }

  static String? _parseEducatorEmail(dynamic educator) {
    if (educator is Map) return educator['email']?.toString();
    return null;
  }

  Map<String, dynamic> toJson() {
    return {
      "_id": id,
      "title": title,
      "description": description,
      "slug": slug,
      "image": image,
      "subject": subject,
      "specialization": specialization,
      "class": classes,
      "educatorID": educatorId,
      "webinarType": webinarType,
      "timing": timing.toIso8601String(),
      "fees": fees,
      "duration": duration,
      "seatLimit": seatLimit,
      "studentEnrolled": studentEnrolled,
      "webinarLink": webinarLink,
      "assetsLink": assetsLink,
      "isActive": isActive,
      "createdAt": createdAt?.toIso8601String(),
      "updatedAt": updatedAt?.toIso8601String(),
    };
  }
}
