class Webinar {
  final String id;
  final String title;
  final String? description;
  final String? slug;
  final WebinarImage? image;
  final List<String> subject;
  final String? educatorId;
  final String? educatorName;
  final String? educatorImage;
  final double? fees;
  final bool? isFree;
  final DateTime? scheduledAt;
  final int? duration; // in minutes
  final String? meetingLink;
  final int? maxAttendees;
  final int? registeredCount;
  final String? status;
  final bool? isActive;
  final DateTime? createdAt;
  
  Webinar({
    required this.id,
    required this.title,
    this.description,
    this.slug,
    this.image,
    this.subject = const [],
    this.educatorId,
    this.educatorName,
    this.educatorImage,
    this.fees,
    this.isFree,
    this.scheduledAt,
    this.duration,
    this.meetingLink,
    this.maxAttendees,
    this.registeredCount,
    this.status,
    this.isActive,
    this.createdAt,
  });
  
  String get imageUrl => image?.url ?? '';
  
  bool get isUpcoming {
    if (scheduledAt == null) return false;
    return scheduledAt!.isAfter(DateTime.now());
  }
  
  bool get isLive {
    if (scheduledAt == null || duration == null) return false;
    final now = DateTime.now();
    final endTime = scheduledAt!.add(Duration(minutes: duration!));
    return now.isAfter(scheduledAt!) && now.isBefore(endTime);
  }
  
  factory Webinar.fromJson(Map<String, dynamic> json) {
    return Webinar(
      id: json['_id'] ?? json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'],
      slug: json['slug'],
      image: json['image'] != null ? WebinarImage.fromJson(json['image']) : null,
      subject: _parseStringList(json['subject']),
      educatorId: _parseEducatorId(json),
      educatorName: _parseEducatorName(json),
      educatorImage: _parseEducatorImage(json),
      fees: (json['fees'] as num?)?.toDouble(),
      isFree: json['isFree'] ?? (json['fees'] == 0),
      scheduledAt: json['scheduledAt'] != null
          ? DateTime.tryParse(json['scheduledAt'])
          : (json['timing'] != null
          ? DateTime.tryParse(json['timing'])
          : (json['startTime'] != null ? DateTime.tryParse(json['startTime']) : null)),

      duration: json['duration'] is int
          ? json['duration']
          : int.tryParse(json['duration']?.toString() ?? ''),

      meetingLink: json['meetingLink'] ?? json['link'],
      maxAttendees: json['maxAttendees'],
      registeredCount: json['registeredCount'] ?? json['attendees'],
      status: json['status'],
      isActive: json['isActive'],
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt']) : null,
    );
  }
  
  static List<String> _parseStringList(dynamic value) {
    if (value == null) return [];
    if (value is String) return [value];
    if (value is List) {
      return value.map((e) => e.toString()).toList();
    }
    return [];
  }

  static String? _parseEducatorId(Map<String, dynamic> json) {
    final educator =
        json['educatorId'] ?? json['educatorID'] ?? json['educator'] ?? json['educatorID'];
    if (educator is String) return educator;
    if (educator is Map) return educator['_id']?.toString();
    return json['educatorID']?.toString(); // ✅ backend uses educatorID
  }


  static String? _parseEducatorName(Map<String, dynamic> json) {
    final educator = json['educatorId'] ?? json['educatorID'] ?? json['educator'];
    if (educator is Map) {
      return educator['name'] ?? educator['fullName'];
    }
    return json['educatorName'];
  }
  
  static String? _parseEducatorImage(Map<String, dynamic> json) {
    final educator = json['educatorId'] ?? json['educatorID'] ?? json['educator'];
    if (educator is Map) {
      final img = educator['profilePicture'] ?? educator['profileImage'];
      if (img is String) return img;
      if (img is Map) return img['url'];
    }
    return json['educatorImage'];
  }
  
  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'title': title,
      'description': description,
      'slug': slug,
      'image': image?.toJson(),
      'subject': subject,
      'educatorId': educatorId,
      'educatorName': educatorName,
      'educatorImage': educatorImage,
      'fees': fees,
      'isFree': isFree,
      'scheduledAt': scheduledAt?.toIso8601String(),
      'duration': duration,
      'meetingLink': meetingLink,
      'maxAttendees': maxAttendees,
      'registeredCount': registeredCount,
      'status': status,
      'isActive': isActive,
      'createdAt': createdAt?.toIso8601String(),
    };
  }
}

class WebinarImage {
  final String? url;
  final String? publicId;
  
  WebinarImage({this.url, this.publicId});
  
  factory WebinarImage.fromJson(dynamic json) {
    if (json is String) {
      return WebinarImage(url: json);
    }
    if (json is Map<String, dynamic>) {
      return WebinarImage(
        url: json['url'],
        publicId: json['publicId'] ?? json['public_id'],
      );
    }
    return WebinarImage();
  }
  
  Map<String, dynamic> toJson() {
    return {
      'url': url,
      'publicId': publicId,
    };
  }
}
