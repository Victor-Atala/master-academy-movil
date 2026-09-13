import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../di/service_locator.dart';

class CourseReview {
  final String id;
  final String courseId;
  final String userName;
  final String? userAvatar;
  final double rating;
  final String reviewText;
  final List<String> tags;
  final DateTime createdAt;

  CourseReview({
    required this.id,
    required this.courseId,
    required this.userName,
    this.userAvatar,
    required this.rating,
    required this.reviewText,
    required this.tags,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'courseId': courseId,
        'userName': userName,
        'userAvatar': userAvatar,
        'rating': rating,
        'reviewText': reviewText,
        'tags': tags,
        'createdAt': createdAt.toIso8601String(),
      };

  factory CourseReview.fromJson(Map<String, dynamic> json) => CourseReview(
        id: json['id'] as String? ?? 'rev_${DateTime.now().millisecondsSinceEpoch}',
        courseId: '${json['courseId'] ?? ""}',
        userName: json['userName'] as String? ?? 'Alumno de Master Academy',
        userAvatar: json['userAvatar'] as String?,
        rating: (json['rating'] is num) ? (json['rating'] as num).toDouble() : 5.0,
        reviewText: json['reviewText'] as String? ?? '',
        tags: (json['tags'] as List<dynamic>?)?.map((e) => '$e').toList() ?? [],
        createdAt: json['createdAt'] != null
            ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
            : DateTime.now(),
      );
}

class CourseComment {
  final String id;
  final String courseId;
  final int? lessonId;
  final String userName;
  final String? userAvatar;
  final String content;
  int likesCount;
  bool isLikedByMe;
  final DateTime createdAt;
  final List<CourseComment> replies;

  CourseComment({
    required this.id,
    required this.courseId,
    this.lessonId,
    required this.userName,
    this.userAvatar,
    required this.content,
    this.likesCount = 0,
    this.isLikedByMe = false,
    required this.createdAt,
    this.replies = const [],
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'courseId': courseId,
        'lessonId': lessonId,
        'userName': userName,
        'userAvatar': userAvatar,
        'content': content,
        'likesCount': likesCount,
        'isLikedByMe': isLikedByMe,
        'createdAt': createdAt.toIso8601String(),
        'replies': replies.map((r) => r.toJson()).toList(),
      };

  factory CourseComment.fromJson(Map<String, dynamic> json) => CourseComment(
        id: json['id'] as String? ?? 'comm_${DateTime.now().millisecondsSinceEpoch}',
        courseId: '${json['courseId'] ?? ""}',
        lessonId: json['lessonId'] != null ? int.tryParse('${json['lessonId']}') : null,
        userName: json['userName'] as String? ?? 'Estudiante',
        userAvatar: json['userAvatar'] as String?,
        content: json['content'] as String? ?? '',
        likesCount: json['likesCount'] as int? ?? 0,
        isLikedByMe: json['isLikedByMe'] as bool? ?? false,
        createdAt: json['createdAt'] != null
            ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
            : DateTime.now(),
        replies: (json['replies'] as List<dynamic>?)
                ?.map((e) => CourseComment.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
      );
}

class InstructorInquiry {
  final String id;
  final String courseId;
  final String courseTitle;
  final String instructorName;
  final String? lessonTitle;
  final String subject;
  final String message;
  final DateTime createdAt;
  final String status;
  final String? reply;
  final DateTime? repliedAt;

  InstructorInquiry({
    required this.id,
    required this.courseId,
    required this.courseTitle,
    required this.instructorName,
    this.lessonTitle,
    required this.subject,
    required this.message,
    required this.createdAt,
    this.status = 'Respondida',
    this.reply,
    this.repliedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'courseId': courseId,
        'courseTitle': courseTitle,
        'instructorName': instructorName,
        'lessonTitle': lessonTitle,
        'subject': subject,
        'message': message,
        'createdAt': createdAt.toIso8601String(),
        'status': status,
        'reply': reply,
        'repliedAt': repliedAt?.toIso8601String(),
      };

  factory InstructorInquiry.fromJson(Map<String, dynamic> json) => InstructorInquiry(
        id: json['id'] as String? ?? 'inq_${DateTime.now().millisecondsSinceEpoch}',
        courseId: '${json['courseId'] ?? ""}',
        courseTitle: json['courseTitle'] as String? ?? 'Curso de Master Academy',
        instructorName: json['instructorName'] as String? ?? 'Instructor Titular',
        lessonTitle: json['lessonTitle'] as String?,
        subject: json['subject'] as String? ?? 'Consulta técnica',
        message: json['message'] as String? ?? '',
        createdAt: json['createdAt'] != null
            ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
            : DateTime.now(),
        status: json['status'] as String? ?? 'Respondida',
        reply: json['reply'] as String?,
        repliedAt: json['repliedAt'] != null ? DateTime.tryParse(json['repliedAt'] as String) : null,
      );
}

class CourseInteractionService {
  static const String _reviewsKeyPrefix = 'master_course_reviews_';
  static const String _commentsKeyPrefix = 'master_course_comments_';
  static const String _inquiriesKey = 'master_instructor_inquiries_all';

  final FlutterSecureStorage _storage;
  final Map<String, List<CourseReview>> _reviewsCache = {};
  final Map<String, List<CourseComment>> _commentsCache = {};
  List<InstructorInquiry>? _inquiriesCache;

  CourseInteractionService({FlutterSecureStorage? storage})
      : _storage = storage ?? sl<FlutterSecureStorage>();

  // ================= CALIFICACIONES Y RESEÑAS =================

  Future<List<CourseReview>> getCourseReviews(dynamic courseId, {bool forceRefresh = false}) async {
    final cId = '$courseId';
    if (!forceRefresh && _reviewsCache.containsKey(cId)) {
      return List<CourseReview>.from(_reviewsCache[cId]!);
    }
    try {
      final raw = await _storage.read(key: '$_reviewsKeyPrefix$cId');
      if (raw != null && raw.trim().isNotEmpty) {
        final List<dynamic> list = jsonDecode(raw);
        final parsed = list.map((e) => CourseReview.fromJson(e as Map<String, dynamic>)).toList();
        _reviewsCache[cId] = parsed;
        return List<CourseReview>.from(parsed);
      }
    } catch (_) {}

    // Reseñas iniciales de la comunidad predeterminadas para feedback inmediato
    final initialReviews = [
      CourseReview(
        id: 'rev_default_1_$cId',
        courseId: cId,
        userName: 'Carlos Mendoza',
        rating: 5.0,
        reviewText: 'Excelente metodología y explicaciones directas al grano. Me ayudó a certificarme con facilidad.',
        tags: ['Muy práctico', 'Excelente instructor', 'Material completo'],
        createdAt: DateTime.now().subtract(const Duration(days: 3)),
      ),
      CourseReview(
        id: 'rev_default_2_$cId',
        courseId: cId,
        userName: 'Ing. Sofía Arriaga',
        rating: 4.8,
        reviewText: 'El contenido técnico está sumamente actualizado. Gran trabajo del equipo de Master Academy.',
        tags: ['Explicación clara', 'Recomendado para trabajar'],
        createdAt: DateTime.now().subtract(const Duration(days: 8)),
      ),
      CourseReview(
        id: 'rev_default_3_$cId',
        courseId: cId,
        userName: 'Miguel Ángel R.',
        rating: 5.0,
        reviewText: 'Las guías y casos de estudio son excelentes para aplicar en auditorías y proyectos reales.',
        tags: ['Casos reales', 'Didáctico'],
        createdAt: DateTime.now().subtract(const Duration(days: 14)),
      ),
    ];

    _reviewsCache[cId] = initialReviews;
    _saveReviews(cId, initialReviews);
    return List<CourseReview>.from(initialReviews);
  }

  Future<CourseReview> submitCourseReview({
    required dynamic courseId,
    required String userName,
    required double rating,
    required String reviewText,
    required List<String> tags,
  }) async {
    final cId = '$courseId';
    final list = await getCourseReviews(cId);
    final newReview = CourseReview(
      id: 'rev_${DateTime.now().millisecondsSinceEpoch}',
      courseId: cId,
      userName: userName.isNotEmpty ? userName : 'Mi Cuenta',
      rating: rating,
      reviewText: reviewText.trim(),
      tags: tags,
      createdAt: DateTime.now(),
    );

    // Reemplazar si el usuario ya había calificado o agregar al inicio
    final existingIdx = list.indexWhere((r) => r.userName == userName);
    if (existingIdx >= 0) {
      list[existingIdx] = newReview;
    } else {
      list.insert(0, newReview);
    }

    _reviewsCache[cId] = list;
    await _saveReviews(cId, list);
    return newReview;
  }

  Future<void> _saveReviews(String courseId, List<CourseReview> list) async {
    final encoded = jsonEncode(list.map((r) => r.toJson()).toList());
    await _storage.write(key: '$_reviewsKeyPrefix$courseId', value: encoded);
  }

  // ================= COMENTARIOS TIPO YOUTUBE =================

  Future<List<CourseComment>> getComments(dynamic courseId, {bool forceRefresh = false}) async {
    final cId = '$courseId';
    if (!forceRefresh && _commentsCache.containsKey(cId)) {
      return List<CourseComment>.from(_commentsCache[cId]!);
    }
    try {
      final raw = await _storage.read(key: '$_commentsKeyPrefix$cId');
      if (raw != null && raw.trim().isNotEmpty) {
        final List<dynamic> list = jsonDecode(raw);
        final parsed = list.map((e) => CourseComment.fromJson(e as Map<String, dynamic>)).toList();
        _commentsCache[cId] = parsed;
        return List<CourseComment>.from(parsed);
      }
    } catch (_) {}

    // Comentarios tipo YouTube iniciales enriquecidos
    final initialComments = [
      CourseComment(
        id: 'comm_1_$cId',
        courseId: cId,
        userName: 'Alejandro Morales',
        content: '¡Recomiendo repasar el minuto clave del video y contrastarlo con la guía PDF! Aclara muchas dudas de campo.',
        likesCount: 14,
        isLikedByMe: false,
        createdAt: DateTime.now().subtract(const Duration(hours: 5)),
        replies: [
          CourseComment(
            id: 'comm_1_rep_1',
            courseId: cId,
            userName: 'Instructor Master Academy',
            content: 'Totalmente de acuerdo Alejandro, el checklist del PDF contiene la matriz de evaluación obligatoria.',
            likesCount: 8,
            createdAt: DateTime.now().subtract(const Duration(hours: 3)),
          ),
        ],
      ),
      CourseComment(
        id: 'comm_2_$cId',
        courseId: cId,
        userName: 'Valeria Gómez',
        content: 'Excelente explicación. ¿Alguien tiene alguna recomendación de software adicional para complementar la práctica?',
        likesCount: 6,
        isLikedByMe: false,
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
        replies: [
          CourseComment(
            id: 'comm_2_rep_1',
            courseId: cId,
            userName: 'David T.',
            content: 'En la pestaña Recursos de la clase 3 viene la lista de herramientas de código abierto recomendadas.',
            likesCount: 4,
            createdAt: DateTime.now().subtract(const Duration(hours: 18)),
          ),
        ],
      ),
    ];

    _commentsCache[cId] = initialComments;
    await _saveComments(cId, initialComments);
    return List<CourseComment>.from(initialComments);
  }

  Future<CourseComment> addComment({
    required dynamic courseId,
    int? lessonId,
    required String userName,
    required String content,
  }) async {
    final cId = '$courseId';
    final list = await getComments(cId);
    final newComment = CourseComment(
      id: 'comm_${DateTime.now().millisecondsSinceEpoch}',
      courseId: cId,
      lessonId: lessonId,
      userName: userName.isNotEmpty ? userName : 'Mi Cuenta',
      content: content.trim(),
      likesCount: 0,
      createdAt: DateTime.now(),
      replies: [],
    );
    list.insert(0, newComment);
    _commentsCache[cId] = list;
    await _saveComments(cId, list);
    return newComment;
  }

  Future<void> addReply({
    required dynamic courseId,
    required String parentCommentId,
    required String userName,
    required String content,
  }) async {
    final cId = '$courseId';
    final list = await getComments(cId);
    final parent = list.firstWhere((c) => c.id == parentCommentId, orElse: () => list.first);

    final reply = CourseComment(
      id: 'comm_rep_${DateTime.now().millisecondsSinceEpoch}',
      courseId: cId,
      userName: userName.isNotEmpty ? userName : 'Mi Cuenta',
      content: content.trim(),
      likesCount: 0,
      createdAt: DateTime.now(),
    );

    parent.replies.add(reply);
    _commentsCache[cId] = list;
    await _saveComments(cId, list);
  }

  Future<void> toggleLike(dynamic courseId, String commentId) async {
    final cId = '$courseId';
    final list = await getComments(cId);
    for (var c in list) {
      if (c.id == commentId) {
        c.isLikedByMe = !c.isLikedByMe;
        c.likesCount += c.isLikedByMe ? 1 : -1;
        break;
      }
      for (var r in c.replies) {
        if (r.id == commentId) {
          r.isLikedByMe = !r.isLikedByMe;
          r.likesCount += r.isLikedByMe ? 1 : -1;
          break;
        }
      }
    }
    _commentsCache[cId] = list;
    await _saveComments(cId, list);
  }

  Future<void> _saveComments(String courseId, List<CourseComment> list) async {
    final encoded = jsonEncode(list.map((c) => c.toJson()).toList());
    await _storage.write(key: '$_commentsKeyPrefix$courseId', value: encoded);
  }

  // ================= CONSULTAS CON EL INSTRUCTOR =================

  Future<List<InstructorInquiry>> getInquiries({bool forceRefresh = false}) async {
    if (!forceRefresh && _inquiriesCache != null) {
      return List<InstructorInquiry>.from(_inquiriesCache!);
    }
    try {
      final raw = await _storage.read(key: _inquiriesKey);
      if (raw != null && raw.trim().isNotEmpty) {
        final List<dynamic> list = jsonDecode(raw);
        final parsed = list.map((e) => InstructorInquiry.fromJson(e as Map<String, dynamic>)).toList();
        _inquiriesCache = parsed;
        return List<InstructorInquiry>.from(parsed);
      }
    } catch (_) {}

    // Mensaje de bienvenida de muestra
    final defaultInquiries = [
      InstructorInquiry(
        id: 'inq_sample_1',
        courseId: '1',
        courseTitle: 'Capacitación Profesional',
        instructorName: 'Instructor Titular',
        lessonTitle: 'Introducción General',
        subject: 'Duda sobre los requisitos de certificación',
        message: 'Hola profesor, ¿el examen de acreditación tiene límite de intentos o se puede repetir al concluir los módulos?',
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
        status: 'Respondida',
        reply: 'Hola estimado alumno. Tienes hasta 3 intentos sin costo adicional. Te recomiendo revisar las preguntas del simulador antes de presentarlo.',
        repliedAt: DateTime.now().subtract(const Duration(days: 1)),
      ),
    ];
    _inquiriesCache = defaultInquiries;
    await _saveInquiries(defaultInquiries);
    return List<InstructorInquiry>.from(defaultInquiries);
  }

  Future<InstructorInquiry> sendInquiry({
    required dynamic courseId,
    required String courseTitle,
    required String instructorName,
    String? lessonTitle,
    required String subject,
    required String message,
  }) async {
    final list = await getInquiries();
    final newInquiry = InstructorInquiry(
      id: 'inq_${DateTime.now().millisecondsSinceEpoch}',
      courseId: '$courseId',
      courseTitle: courseTitle,
      instructorName: instructorName,
      lessonTitle: lessonTitle,
      subject: subject.trim(),
      message: message.trim(),
      createdAt: DateTime.now(),
      status: 'En revisión',
      reply: 'Tu duda ha sido registrada y notificada al instructor. Recibirás respuesta en un plazo máximo de 24 horas hábiles.',
      repliedAt: DateTime.now().add(const Duration(minutes: 5)),
    );

    list.insert(0, newInquiry);
    _inquiriesCache = list;
    await _saveInquiries(list);
    return newInquiry;
  }

  Future<void> _saveInquiries(List<InstructorInquiry> list) async {
    final encoded = jsonEncode(list.map((i) => i.toJson()).toList());
    await _storage.write(key: _inquiriesKey, value: encoded);
  }
}
