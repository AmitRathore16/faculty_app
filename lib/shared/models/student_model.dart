import 'package:faculty_pedia/shared/models/test_series_model.dart';

import 'user_model.dart';

class Student extends User {
  final String? specialization;
  final String? academicClass;
  final List<EnrolledCourse> courses;
  final List<String> followingEducators;
  final List<StudentTest> tests;
  final List<TestResult> results;
  final List<TestSeries> testSeries;

  Student({
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
    this.specialization,
    this.academicClass,
    this.courses = const [],
    this.followingEducators = const [],
    this.tests = const [],
    this.results = const [],
    this.testSeries = const [],
  }) : super(role: 'student');
  
  factory Student.fromJson(Map<String, dynamic> json) {
    return Student(
      id: json['_id'] ?? json['id'] ?? '',
      name: json['name'],
      firstName: json['firstName'],
      lastName: json['lastName'],
      email: json['email'] ?? '',
      mobileNumber: json['mobileNumber'] ?? json['mobile'],
      username: json['username'],
      image: json['image'] != null ? UserImage.fromJson(json['image']) : null,
      bio: json['bio'],
      joinedAt: json['joinedAt'] != null ? DateTime.tryParse(json['joinedAt']) : null,
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt']) : null,
      specialization: json['specialization'],
      academicClass: json['class'],
      courses: (json['courses'] as List<dynamic>?)
          ?.map((e) => EnrolledCourse.fromJson(e))
          .toList() ?? [],
      followingEducators: (json['followingEducators'] as List<dynamic>?)
          ?.map((e) {
        // Case 1: backend sends direct string ids
        if (e is String) return e.toString();

        // Case 2: backend sends object { educatorId, followedAt }
        if (e is Map) {
          final educatorId = e['educatorId'];

          // educatorId could be string OR object {_id: ...}
          if (educatorId is String) return educatorId.trim();
          if (educatorId is Map && educatorId['_id'] != null) {
            return educatorId['_id'].toString().trim();
          }
        }

        return '';
      })
          .where((id) => id.trim().isNotEmpty)
          .toList() ??
          [],

      tests: (json['tests'] as List<dynamic>?)
          ?.map((e) => StudentTest.fromJson(e))
          .toList() ?? [],
      testSeries: (json['testSeries'] as List<dynamic>?)
          ?.map((e) {
        // backend format: { testSeriesId: ... }
        if (e is Map && e['testSeriesId'] != null) {
          final ts = e['testSeriesId'];

          // case 1: testSeriesId is string id
          if (ts is String) {
            return TestSeries(id: ts, title: "");
          }

          // case 2: populated testSeries object
          if (ts is Map) {
            final map = Map<String, dynamic>.from(ts);
            return TestSeries.fromJson(map);
          }
        }

        // fallback: sometimes backend might already send populated object
        if (e is Map) {
          return TestSeries.fromJson(Map<String, dynamic>.from(e));
        }

        // fallback empty
        return TestSeries(id: "", title: "");
      })
          .where((t) => t.id.trim().isNotEmpty)
          .toList() ??
          [],

      results: (json['results'] as List<dynamic>?)
          ?.map((e) => TestResult.fromJson(Map<String, dynamic>.from(e)))
          .toList() ?? [],
    );
  }
  
  @override
  Map<String, dynamic> toJson() {
    return {
      ...super.toJson(),
      'specialization': specialization,
      'class': academicClass,
      'courses': courses.map((c) => c.toJson()).toList(),
      'followingEducators': followingEducators,
      'tests': tests.map((t) => t.toJson()).toList(),
      'results': results.map((r) => r.toJson()).toList(),
      'testSeries': testSeries.map((t) => t.toJson()).toList(),

    };
  }
}

class EnrolledCourse {
  final String courseId;
  final DateTime? enrolledAt;
  final String? completionStatus;
  final double? progressPercentage;
  
  EnrolledCourse({
    required this.courseId,
    this.enrolledAt,
    this.completionStatus,
    this.progressPercentage,
  });
  
  factory EnrolledCourse.fromJson(Map<String, dynamic> json) {
    String courseId = '';
    if (json['courseId'] is String) {
      courseId = json['courseId'];
    } else if (json['courseId'] is Map) {
      courseId = json['courseId']['_id'] ?? '';
    } else if (json['_id'] != null) {
      courseId = json['_id'];
    }
    
    return EnrolledCourse(
      courseId: courseId,
      enrolledAt: json['enrolledAt'] != null 
          ? DateTime.tryParse(json['enrolledAt']) 
          : null,
      completionStatus: json['completionStatus'],
      progressPercentage: (json['progressPercentage'] as num?)?.toDouble(),
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'courseId': courseId,
      'enrolledAt': enrolledAt?.toIso8601String(),
      'completionStatus': completionStatus,
      'progressPercentage': progressPercentage,
    };
  }
}

class StudentTest {
  final String testSeriesId;
  final String? testId;
  
  StudentTest({required this.testSeriesId, this.testId});
  
  factory StudentTest.fromJson(Map<String, dynamic> json) {
    String seriesId = '';
    if (json['testSeriesId'] is String) {
      seriesId = json['testSeriesId'];
    } else if (json['testSeriesId'] is Map) {
      seriesId = json['testSeriesId']['_id'] ?? '';
    }
    
    return StudentTest(
      testSeriesId: seriesId,
      testId: json['testId']?.toString(),
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'testSeriesId': testSeriesId,
      'testId': testId,
    };
  }
}

class TestResult {
  final String id;
  final String? testId;
  final String? seriesId;
  final int? score;
  final int? totalMarks;
  final int? correctAnswers;
  final int? wrongAnswers;
  final String? title;
  final int? unattempted;
  final DateTime? submittedAt;
  final DateTime? completedAt;
  
  TestResult({
    required this.id,
    this.testId,
    this.seriesId,
    this.score,
    this.totalMarks,
    this.correctAnswers,
    this.wrongAnswers,
    this.title,
    this.unattempted,
    this.submittedAt,
    this.completedAt,
  });
  
  double get percentage {
    if (totalMarks == null || totalMarks == 0) return 0;
    return ((score ?? 0) / totalMarks!) * 100;
  }
  
  factory TestResult.fromJson(Map<String, dynamic> json) {
    return TestResult(
      id: json['_id'] ?? json['id'] ?? '',
      testId: json['testId']?.toString(),
      seriesId: json['seriesId']?.toString(),
      title: json['title'],
      score: json['score'] as int?,
      totalMarks: json['totalMarks'] as int?,
      correctAnswers: json['correctAnswers'] as int?,
      wrongAnswers: json['wrongAnswers'] as int?,
      unattempted: json['unattempted'] as int?,
      submittedAt: json['submittedAt'] != null 
          ? DateTime.tryParse(json['submittedAt']) 
          : null,
      completedAt: json['completedAt'] != null
          ? DateTime.tryParse(json['completedAt'].toString())
          : null,

    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'testId': testId,
      'seriesId': seriesId,
      'score': score,
      'totalMarks': totalMarks,
      'correctAnswers': correctAnswers,
      'title': title,
      'wrongAnswers': wrongAnswers,
      'unattempted': unattempted,
      'submittedAt': submittedAt?.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
    };
  }
}
