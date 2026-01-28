import 'user_model.dart';

class Course {
  final String id;
  final String title;
  final String? description;
  final String? slug;
  final CourseImage? image;
  final List<String> subject;
  final List<String> classList;
  final String? courseDuration;
  final String? introVideoVimeoUri; // ✅ NEW
  final List<String> specialization;
  final EducatorInfo? educator;
  final String? introVideo;
  final String? language;
  final bool? certificateAvailable;
  final double? rating;
  final int? ratingCount;
  final List<CourseVideo>? videos;
  final List<StudyMaterial>? studyMaterials;
  final List<String>? courseObjectives;
  final List<String>? prerequisites;
  final int? videoCount;
  final int? liveClassCount;
  final int? testSeriesCount;
  final bool? isFull;
  final int? seatsAvailable;
  final List<String>? enrolledStudents;
  final double? fees;
  final double? discount;
  final DateTime? startDate;
  final DateTime? endDate;
  final int? maxStudents;
  final int? enrolledCount;
  final String? status;
  final bool? isActive;
  final DateTime? createdAt;

  Course({
    required this.id,
    required this.title,
    this.description,
    this.slug,
    this.image,
    this.classList = const [],
    this.courseDuration,
    this.introVideo,
    this.language,
    this.certificateAvailable,
    this.rating,
    this.ratingCount,
    this.videos,
    this.studyMaterials,
    this.courseObjectives,
    this.prerequisites,
    this.videoCount,
    this.liveClassCount,
    this.testSeriesCount,
    this.isFull,
    this.seatsAvailable,
    this.enrolledStudents,
    this.subject = const [],
    this.specialization = const [],
    this.educator,
    this.fees,
    this.discount,
    this.startDate,
    this.endDate,
    this.maxStudents,
    this.enrolledCount,
    this.status,
    this.isActive,
    this.introVideoVimeoUri,
    this.createdAt,
  });
  
  String get imageUrl => image?.url ?? '';
  String? get introVideoBestLink {
    final a = (introVideo ?? '').trim();
    if (a.isNotEmpty) return a;

    final b = (introVideoVimeoUri ?? '').trim();
    if (b.isNotEmpty) return b;

    return null;
  }

  double get finalPrice {
    if (fees == null) return 0;
    if (discount == null || discount == 0) return fees!;
    return fees! * (1 - discount! / 100);
  }
  
  bool get hasDiscount => discount != null && discount! > 0;
  
  factory Course.fromJson(Map<String, dynamic> json) {
    return Course(
      id: json['_id'] ?? json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'],
      slug: json['slug'],
      classList: _parseStringList(json['class']),
      courseDuration: json['courseDuration'],
      image: _parseImage(json),
      subject: _parseStringList(json['subject']),
      specialization: _parseStringList(json['specialization']),
      educator: _parseEducator(json),
      fees: (json['fees'] as num?)?.toDouble(),
      discount: (json['discount'] as num?)?.toDouble(),
      startDate: json['startDate'] != null ? DateTime.tryParse(json['startDate']) : null,
      endDate: json['endDate'] != null ? DateTime.tryParse(json['endDate']) : null,
      maxStudents: json['maxStudents'] ?? json['seatLimit'],
      enrolledCount: json['enrolledCount'] ?? (json['enrolledStudents'] is List ? (json['enrolledStudents'] as List).length : null),
      status: json['status'],
      isActive: json['isActive'],
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt']) : null,
      introVideo: json['introVideo'],
      introVideoVimeoUri: json['introVideoVimeoUri'], // ✅ NEW
      language: json['language'],
      certificateAvailable: json['certificateAvailable'],
      rating: (json['rating'] as num?)?.toDouble(),
      ratingCount: json['ratingCount'],
      videos: (json['videos'] as List<dynamic>?)?.map((e) => CourseVideo.fromJson(e)).toList(),
      studyMaterials: (json['studyMaterials'] as List<dynamic>?)?.map((e) => StudyMaterial.fromJson(e)).toList(),
      courseObjectives: _parseStringList(json['courseObjectives']),
      prerequisites: _parseStringList(json['prerequisites']),
      videoCount: json['videoCount'],
      liveClassCount: json['liveClassCount'],
      testSeriesCount: json['testSeriesCount'],
      isFull: json['isFull'],
      seatsAvailable: json['seatsAvailable'],
      enrolledStudents: _parseIdList(json['enrolledStudents']),
    );
  }

  static CourseImage? _parseImage(Map<String, dynamic> json) {
    final img = json['courseThumbnail'] ?? json['image'];
    if (img == null) return null;

    if (img is String) {
      return CourseImage(url: img);
    }
    if (img is Map<String, dynamic>) {
      return CourseImage.fromJson(img);
    }
    return null;
  }
  static List<String> _parseIdList(dynamic value) {
    if (value == null) return [];

    if (value is List) {
      return value
          .map((e) {
        if (e is String) return e;
        if (e is Map<String, dynamic>) {
          return (e['_id'] ?? e['id'] ?? '').toString();
        }
        return e.toString();
      })
          .where((id) => id.isNotEmpty)
          .toList();
    }

    return [];
  }


  static List<String> _parseStringList(dynamic value) {
    if (value == null) return [];
    if (value is String) return [value];
    if (value is List) {
      return value.map((e) => e.toString()).toList();
    }
    return [];
  }
  
  static EducatorInfo? _parseEducator(Map<String, dynamic> json) {
    final educatorData = json['educatorID'] ?? 
        json['educatorId'] ?? 
        json['educator'] ?? 
        json['educatorDetails'];
    
    if (educatorData == null) return null;
    if (educatorData is String) {
      return EducatorInfo(id: educatorData);
    }
    if (educatorData is Map<String, dynamic>) {
      return EducatorInfo.fromJson(educatorData);
    }
    return null;
  }
  
  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'title': title,
      'description': description,
      'slug': slug,
      'image': image?.toJson(),
      'subject': subject,
      'specialization': specialization,
      'educator': educator?.toJson(),
      'fees': fees,
      'discount': discount,
      'startDate': startDate?.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'maxStudents': maxStudents,
      'enrolledCount': enrolledCount,
      'status': status,
      'isActive': isActive,
      'introVideo': introVideo,
      'introVideoVimeoUri': introVideoVimeoUri, // ✅ NEW
      'createdAt': createdAt?.toIso8601String(),
    };
  }
}

class CourseImage {
  final String? url;
  final String? publicId;
  
  CourseImage({this.url, this.publicId});
  
  factory CourseImage.fromJson(dynamic json) {
    if (json is String) {
      return CourseImage(url: json);
    }
    if (json is Map<String, dynamic>) {
      return CourseImage(
        url: json['url'],
        publicId: json['publicId'] ?? json['public_id'],
      );
    }
    return CourseImage();
  }
  
  Map<String, dynamic> toJson() {
    return {
      'url': url,
      'publicId': publicId,
    };
  }
}

class EducatorInfo {
  final String? id;
  final String? name;
  final String? profilePicture;
  
  EducatorInfo({this.id, this.name, this.profilePicture});
  
  factory EducatorInfo.fromJson(Map<String, dynamic> json) {
    return EducatorInfo(
      id: json['_id'] ?? json['id'],
      name: json['fullName'] ?? json['name'] ?? 
          [json['firstName'], json['lastName']]
              .where((s) => s != null)
              .join(' '),
      profilePicture: json['profilePicture'] is String 
          ? json['profilePicture'] 
          : json['profilePicture']?['url'],
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'name': name,
      'profilePicture': profilePicture,
    };
  }
}

class CourseClass {
  final String? id;
  final String? title;
  final String? description;
  final DateTime? scheduledAt;
  final int? duration;
  final String? status;

  CourseClass({
    this.id,
    this.title,
    this.description,
    this.scheduledAt,
    this.duration,
    this.status,
  });

  factory CourseClass.fromJson(Map<String, dynamic> json) {
    return CourseClass(
      id: json['_id'] ?? json['id'],
      title: json['title'],
      description: json['description'],
      scheduledAt: json['scheduledAt'] != null
          ? DateTime.tryParse(json['scheduledAt'])
          : null,
      duration: json['duration'],
      status: json['status'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'title': title,
      'description': description,
      'scheduledAt': scheduledAt?.toIso8601String(),
      'duration': duration,
      'status': status,
    };
  }
}

class CourseVideo {
  final String? id;
  final String? title;
  final String? link;
  final String? duration;
  final int? sequenceNumber;

  CourseVideo({
    this.id,
    this.title,
    this.link,
    this.duration,
    this.sequenceNumber,
  });

  factory CourseVideo.fromJson(Map<String, dynamic> json) {
    return CourseVideo(
      id: json['_id'] ?? json['id'],
      title: json['title'],
      link: json['link'],
      duration: json['duration'],
      sequenceNumber: json['sequenceNumber'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'title': title,
      'link': link,
      'duration': duration,
      'sequenceNumber': sequenceNumber,
    };
  }
}

class StudyMaterial {
  final String? id;
  final String? title;
  final String? link;
  final String? fileType;

  StudyMaterial({
    this.id,
    this.title,
    this.link,
    this.fileType,
  });

  factory StudyMaterial.fromJson(Map<String, dynamic> json) {
    return StudyMaterial(
      id: json['_id'] ?? json['id'],
      title: json['title'],
      link: json['link'],
      fileType: json['fileType'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'title': title,
      'link': link,
      'fileType': fileType,
    };
  }
}


