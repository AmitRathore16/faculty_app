import 'user_model.dart';

class Educator extends User {
  final List<String> subject;
  final List<String> specialization;
  final List<Qualification> qualifications;
  final List<WorkExperience> workExperience;
  final int? yearsOfExperience;
  final Rating? rating;
  final int followerCount;
  final String? status;

  /// ✅ backend: introVideo OR introVideoLink
  final String? introVideoLink;

  /// ✅ backend: introVideoVimeoUri
  final String? introVideoVimeoUri;

  Educator({
    required super.id,
    super.name,
    super.firstName,
    super.lastName,
    required super.email,
    super.mobileNumber,
    super.username,
    super.image,
    super.bio,
    super.joinedAt,
    super.createdAt,
    this.subject = const [],
    this.specialization = const [],
    this.qualifications = const [],
    this.workExperience = const [],
    this.yearsOfExperience,
    this.rating,
    this.followerCount = 0,
    this.status,
    this.introVideoLink,
    this.introVideoVimeoUri,
  }) : super(role: 'educator');

  /// ✅ single source of truth for active status (UI should use this)
  bool get isActive {
    final s = (status ?? '').toLowerCase().trim();
    return s == 'active';
  }

  /// ✅ best link chooser
  /// priority: direct introVideoLink -> vimeo uri
  String? get introVideoBestLink {
    final a = (introVideoLink ?? '').trim();
    if (a.isNotEmpty) return a;

    final b = (introVideoVimeoUri ?? '').trim();
    if (b.isNotEmpty) return b;

    return null;
  }

  String get displaySubjects {
    if (subject.isEmpty) return 'Not specified';
    return subject.map((s) => _formatSubject(s)).join(', ');
  }

  String _formatSubject(String value) {
    return value
        .replaceAll('-', ' ')
        .split(' ')
        .map((word) => word.isNotEmpty
        ? '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}'
        : word)
        .join(' ');
  }

  String get displayExperience {
    if (yearsOfExperience != null) {
      return '$yearsOfExperience+ years';
    }
    return 'Not specified';
  }

  String? get displayQualification {
    if (qualifications.isNotEmpty) {
      return qualifications.first.title ?? qualifications.first.degree;
    }
    return null;
  }

  factory Educator.fromJson(Map<String, dynamic> json) {
    return Educator(
      id: json['_id'] ?? json['id'] ?? '',
      name: json['fullName'] ?? json['name'],
      firstName: json['firstName'],
      lastName: json['lastName'],
      email: json['email'] ?? '',
      mobileNumber: json['mobileNumber'] ?? json['mobile'],
      username: json['username'],
      image: _parseImage(json),
      bio: json['bio'] ?? json['description'],
      joinedAt: json['joinedAt'] != null
          ? DateTime.tryParse(json['joinedAt'].toString())
          : null,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
      subject: _parseStringList(json['subject']),
      specialization: _parseStringList(json['specialization']),
      qualifications: (json['qualification'] as List<dynamic>?)
          ?.map((e) =>
          Qualification.fromJson(Map<String, dynamic>.from(e)))
          .toList() ??
          (json['qualifications'] as List<dynamic>?)
              ?.map((e) =>
              Qualification.fromJson(Map<String, dynamic>.from(e)))
              .toList() ??
          [],
      workExperience: (json['workExperience'] as List<dynamic>?)
          ?.map((e) =>
          WorkExperience.fromJson(Map<String, dynamic>.from(e)))
          .toList() ??
          [],
      yearsOfExperience: (json['yoe'] as num?)?.toInt() ??
          (json['yearsExperience'] as num?)?.toInt() ??
          (json['experience'] as num?)?.toInt(),
      rating: json['rating'] != null
          ? Rating.fromJson(Map<String, dynamic>.from(json['rating']))
          : null,
      followerCount: _parseFollowerCount(json),
      status: json['status'],

      /// ✅ parse both
      introVideoLink: json['introVideoLink'] ?? json['introVideo'],
      introVideoVimeoUri: json['introVideoVimeoUri'],
    );
  }

  static UserImage? _parseImage(Map<String, dynamic> json) {
    if (json['profileImage'] != null) {
      return UserImage.fromJson(json['profileImage']);
    }
    if (json['profilePicture'] != null) {
      return UserImage.fromJson(json['profilePicture']);
    }
    if (json['image'] != null) {
      return UserImage.fromJson(json['image']);
    }
    return null;
  }

  static List<String> _parseStringList(dynamic value) {
    if (value == null) return [];
    if (value is String) return [value];
    if (value is List) {
      return value.map((e) => e.toString()).toList();
    }
    return [];
  }

  static int _parseFollowerCount(Map<String, dynamic> json) {
    if (json['followerCount'] is int) return json['followerCount'];
    if (json['followers'] is List) return (json['followers'] as List).length;
    return 0;
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      ...super.toJson(),
      'subject': subject,
      'specialization': specialization,
      'qualification': qualifications.map((q) => q.toJson()).toList(),
      'workExperience': workExperience.map((w) => w.toJson()).toList(),
      'yoe': yearsOfExperience,
      'rating': rating?.toJson(),
      'followerCount': followerCount,
      'status': status,

      /// ✅ include both
      'introVideoLink': introVideoLink,
      'introVideoVimeoUri': introVideoVimeoUri,
    };
  }
}

class Qualification {
  final String? title;
  final String? degree;
  final String? institution;
  final String? year;

  Qualification({this.title, this.degree, this.institution, this.year});

  factory Qualification.fromJson(Map<String, dynamic> json) {
    return Qualification(
      title: json['title'],
      degree: json['degree'],
      institution: json['institution'] ?? json['institute'],
      year: json['year']?.toString() ??
          (json['endDate'] != null
              ? DateTime.tryParse(json['endDate'].toString())
              ?.year
              .toString()
              : null),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'degree': degree,
      'institution': institution,
      'year': year,
    };
  }
}

class WorkExperience {
  final String? title;
  final String? company;
  final String? duration;
  final String? description;

  WorkExperience({this.title, this.company, this.duration, this.description});

  factory WorkExperience.fromJson(Map<String, dynamic> json) {
    return WorkExperience(
      title: json['title'],
      company: json['company'],
      duration: json['duration'],
      description: json['description'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'company': company,
      'duration': duration,
      'description': description,
    };
  }
}

class Rating {
  final double? average;
  final int? count;

  Rating({this.average, this.count});

  factory Rating.fromJson(Map<String, dynamic> json) {
    return Rating(
      average: (json['average'] as num?)?.toDouble(),
      count: json['count'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'average': average,
      'count': count,
    };
  }
}
