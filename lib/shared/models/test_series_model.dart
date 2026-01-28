class TestSeries {
  final String id;
  final String title;
  final String? description;
  final String? slug;
  final TestSeriesImage? image;
  final List<String> subject;
  final String? testSeriesId;
  final List<String> specialization;
  final String? educatorId;
  final String? educatorName;
  final double? fees;
  final double? discount;
  final int? totalTests;
  final int? enrolledCount;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? status;
  final double? rating;
  final int? ratingCount;
  final bool? isActive;
  final DateTime? createdAt;
  final List<Test>? tests;
  
  TestSeries({
    required this.id,
    required this.title,
    this.description,
    this.slug,
    this.image,
    this.testSeriesId,
    this.subject = const [],
    this.specialization = const [],
    this.educatorId,
    this.educatorName,
    this.rating,
    this.ratingCount,
    this.fees,
    this.discount,
    this.totalTests,
    this.enrolledCount,
    this.startDate,
    this.endDate,
    this.status,
    this.isActive,
    this.createdAt,
    this.tests,
  });
  
  String get imageUrl => image?.url ?? '';

  factory TestSeries.fromJson(Map<String, dynamic> json) {
    return TestSeries(
      id: json['_id'] ?? json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'],
      slug: json['slug'],
      testSeriesId: json['testSeriesId']?.toString(),
      image: json['image'] != null ? TestSeriesImage.fromJson(json['image']) : null,
      subject: _parseStringList(json['subject']),
      specialization: _parseStringList(json['specialization']),
      educatorId: _parseEducatorId(json),
      educatorName: _parseEducatorName(json),
      fees: (json['fees'] as num?)?.toDouble() ?? (json['price'] as num?)?.toDouble(),
      discount: (json['discount'] as num?)?.toDouble(),
      totalTests: (json['totalTests'] as num?)?.toInt()
          ?? (json['testCount'] as num?)?.toInt()
          ?? (json['numberOfTests'] as num?)?.toInt(),
      enrolledCount: (json['enrolledCount'] as num?)?.toInt()
          ?? (json['enrolledStudents'] is List ? (json['enrolledStudents'] as List).length : null),
      startDate: json['startDate'] != null ? DateTime.tryParse(json['startDate'].toString()) : null,
      endDate: json['endDate'] != null ? DateTime.tryParse(json['endDate'].toString()) : null,
      status: json['status'],
      rating: (json['rating'] as num?)?.toDouble(),
      ratingCount: (json['ratingCount'] as num?)?.toInt(),
      isActive: json['isActive'],
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt'].toString()) : null,
      tests: (json['tests'] is List)
          ? (json['tests'] as List).map((e) {
        if (e is Map<String, dynamic>) {
          return Test.fromJson(e);
        } else {
          return Test(id: e.toString());
        }
      }).toList()
          : null,
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
    final educator = json['educatorId'] ?? json['educatorID'] ?? json['educator'];
    if (educator is String) return educator;
    if (educator is Map) return educator['_id']?.toString();
    return null;
  }
  
  static String? _parseEducatorName(Map<String, dynamic> json) {
    final educator = json['educatorId'] ?? json['educatorID'] ?? json['educator'];
    if (educator is Map) {
      return educator['name'] ?? educator['fullName'];
    }
    return json['educatorName'];
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
      'educatorId': educatorId,
      'educatorName': educatorName,
      'fees': fees,
      'discount': discount,
      'totalTests': totalTests,
      'enrolledCount': enrolledCount,
      'startDate': startDate?.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'status': status,
      'rating': rating,
      'ratingCount': ratingCount,
      'isActive': isActive,
      'createdAt': createdAt?.toIso8601String(),
    };
  }
}

class TestSeriesImage {
  final String? url;
  final String? publicId;
  
  TestSeriesImage({this.url, this.publicId});
  
  factory TestSeriesImage.fromJson(dynamic json) {
    if (json is String) {
      return TestSeriesImage(url: json);
    }
    if (json is Map<String, dynamic>) {
      return TestSeriesImage(
        url: json['url'],
        publicId: json['publicId'] ?? json['public_id'],
      );
    }
    return TestSeriesImage();
  }
  
  Map<String, dynamic> toJson() {
    return {
      'url': url,
      'publicId': publicId,
    };
  }
}

class Test {
  final String id;
  final String? title;
  final String? description;
  final int? duration;

  final int? totalQuestions;

  /// ✅ keep this (represents backend overallMarks)
  final int? overallMarks;

  /// ✅ store backend markingType
  final String? markingType;

  final int? totalMarks; // you can keep this if used elsewhere
  final int? passingMarks;
  final bool? negativeMarking;
  final DateTime? startTime;
  final DateTime? endTime;
  final String? status;
  final bool? isActive;
  final List<Question>? questions;

  Test({
    required this.id,
    this.title,
    this.description,
    this.duration,
    this.totalQuestions,
    this.overallMarks,
    this.markingType,
    this.totalMarks,
    this.passingMarks,
    this.negativeMarking,
    this.startTime,
    this.endTime,
    this.status,
    this.isActive,
    this.questions,
  });

  /// ✅ FINAL MARKS LOGIC (same as LiveTest)
  int get displayMarks {
    // per question => sum positive marks
    if (markingType == 'per_question' && questions != null && questions!.isNotEmpty) {
      return questions!.fold<int>(0, (sum, q) => sum + (q.marks ?? 0));
    }

    // overall => use overallMarks
    return overallMarks ?? totalMarks ?? 0;
  }

  factory Test.fromJson(Map<String, dynamic> json) {
    return Test(
      id: json['_id'] ?? json['id'] ?? '',
      title: json['title'],
      description: json['description'],
      duration: (json['duration'] as num?)?.toInt(),

      /// ✅ overallMarks comes from backend
      overallMarks: (json['overallMarks'] as num?)?.toInt(),

      /// ✅ backend markingType
      markingType: json['markingType']?.toString(),

      /// (keep old mapping if you want)
      totalMarks: (json['totalMarks'] as num?)?.toInt()
          ?? (json['overallMarks'] as num?)?.toInt(),

      totalQuestions: (json['totalQuestions'] as num?)?.toInt()
          ?? (json['questionCount'] as num?)?.toInt()
          ?? (json['questions'] is List ? (json['questions'] as List).length : null),

      passingMarks: (json['passingMarks'] as num?)?.toInt(),

      negativeMarking: json['negativeMarking'] is bool
          ? json['negativeMarking']
          : (json['negativeMarking'] is num
          ? (json['negativeMarking'] as num).toInt() == 1
          : null),

      startTime: json['startTime'] != null ? DateTime.tryParse(json['startTime'].toString()) : null,
      endTime: json['endTime'] != null ? DateTime.tryParse(json['endTime'].toString()) : null,
      status: json['status'],
      isActive: json['isActive'],

      questions: (json['questions'] is List)
          ? (json['questions'] as List).map((e) {
        if (e is Map<String, dynamic>) {
          return Question.fromJson(e);
        } else {
          return Question(id: e.toString());
        }
      }).toList()
          : null,
    );
  }


  
  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'title': title,
      'description': description,
      'duration': duration,
      'totalQuestions': totalQuestions,
      'totalMarks': totalMarks,
      'passingMarks': passingMarks,
      'negativeMarking': negativeMarking,
      'startTime': startTime?.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
      'status': status,
      'isActive': isActive,
    };
  }
}

class Question {
  final String id;
  final String? text;
  final String? imageUrl;
  final List<Option> options;

  final String? questionType; // ✅ add
  final int? correctOption; // for single-select
  final Set<int>? correctOptionsSet; // ✅ for multi-select
  final int? correctIntegerAnswer; // ✅ for integer

  final String? explanation;
  final int? marks;
  final int? negativeMarks;
  final String? subject;
  final String? topic;

  Question({
    required this.id,
    this.text,
    this.imageUrl,
    this.options = const [],
    this.questionType,
    this.correctOption,
    this.correctOptionsSet,
    this.correctIntegerAnswer,
    this.explanation,
    this.marks,
    this.negativeMarks,
    this.subject,
    this.topic,
  });

  factory Question.fromJson(Map<String, dynamic> json) {
    final parsedOptions = _parseOptions(json['options']);

    final marksMap = json['marks'];
    final int? positiveMarks = (marksMap is Map && marksMap['positive'] is num)
        ? (marksMap['positive'] as num).toInt()
        : null;

    final int? negative = (marksMap is Map && marksMap['negative'] is num)
        ? (marksMap['negative'] as num).toInt()
        : null;

    final type = json['questionType']?.toString();

    // correctOptions parsing
    int? singleCorrect;
    Set<int>? multiCorrect;
    int? integerCorrect;

    final correctRaw = json['correctOptions'];

    if (type == 'single-select') {
      if (correctRaw is String) {
        singleCorrect = _letterToIndex(correctRaw);
      } else if (correctRaw is List && correctRaw.isNotEmpty && correctRaw.first is String) {
        singleCorrect = _letterToIndex(correctRaw.first);
      }
    }

    if (type == 'multi-select') {
      if (correctRaw is List) {
        final indices = correctRaw
            .whereType<String>()
            .map((e) => _letterToIndex(e))
            .whereType<int>()
            .toSet();
        multiCorrect = indices;
      } else if (correctRaw is String) {
        final idx = _letterToIndex(correctRaw);
        if (idx != null) multiCorrect = {idx};
      }
    }

    if (type == 'integer') {
      if (correctRaw is num) {
        integerCorrect = correctRaw.toInt();
      } else if (correctRaw is String) {
        integerCorrect = int.tryParse(correctRaw);
      }
    }

    return Question(
      id: json['_id'] ?? json['id'] ?? '',
      text: json['title'] ?? json['text'] ?? json['question'],
      imageUrl: json['questionImage'] ?? json['imageUrl'] ?? json['image'],
      questionType: type,
      options: parsedOptions,
      correctOption: singleCorrect,
      correctOptionsSet: multiCorrect,
      correctIntegerAnswer: integerCorrect,
      explanation: json['explanation'],
      marks: positiveMarks,
      negativeMarks: negative,
      subject: (json['subject'] is List && (json['subject'] as List).isNotEmpty)
          ? (json['subject'][0]).toString()
          : json['subject']?.toString(),
      topic: (json['topics'] is List && (json['topics'] as List).isNotEmpty)
          ? (json['topics'][0]).toString()
          : json['topic']?.toString(),
    );
  }

  static List<Option> _parseOptions(dynamic options) {
    // Backend: { A: "...", B: "...", C: "...", D: "..." }
    if (options is Map) {
      final a = options['A']?.toString();
      final b = options['B']?.toString();
      final c = options['C']?.toString();
      final d = options['D']?.toString();

      final list = <Option>[];

      if (a != null) list.add(Option(index: 0, text: a));
      if (b != null) list.add(Option(index: 1, text: b));
      if (c != null) list.add(Option(index: 2, text: c));
      if (d != null) list.add(Option(index: 3, text: d));

      return list;
    }

    // If it comes as List (fallback)
    if (options is List) {
      return options.asMap().entries.map((e) => Option.fromJson(e.value, e.key)).toList();
    }

    return [];
  }

  static int? _parseCorrectOptionIndex(dynamic correctOptions) {
    // Backend correctOptions can be:
    // single-select => "A"/"B"/"C"/"D"
    // multi-select => ["A","C"]
    // integer => 12 (not supported in MCQ UI)
    if (correctOptions == null) return null;

    if (correctOptions is String) {
      return _letterToIndex(correctOptions);
    }

    if (correctOptions is List && correctOptions.isNotEmpty) {
      // For multi-select, take first correct option (or return null if you want)
      final first = correctOptions.first;
      if (first is String) return _letterToIndex(first);
    }

    // Integer type questions cannot be mapped to option index
    if (correctOptions is num) return null;

    return null;
  }

  static int? _letterToIndex(String letter) {
    switch (letter.toUpperCase()) {
      case "A":
        return 0;
      case "B":
        return 1;
      case "C":
        return 2;
      case "D":
        return 3;
      default:
        return null;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'text': text,
      'imageUrl': imageUrl,
      'options': options.map((o) => o.toJson()).toList(),
      'correctOption': correctOption,
      'explanation': explanation,
      'marks': marks,
      'negativeMarks': negativeMarks,
      'subject': subject,
      'topic': topic,
    };
  }
}

class Option {
  final int index;
  final String? text;
  final String? imageUrl;
  
  Option({required this.index, this.text, this.imageUrl});
  
  factory Option.fromJson(dynamic json, int index) {
    if (json is String) {
      return Option(index: index, text: json);
    }
    if (json is Map<String, dynamic>) {
      return Option(
        index: json['index'] ?? index,
        text: json['text'],
        imageUrl: json['imageUrl'] ?? json['image'],
      );
    }
    return Option(index: index);
  }
  
  Map<String, dynamic> toJson() {
    return {
      'index': index,
      'text': text,
      'imageUrl': imageUrl,
    };
  }
}
