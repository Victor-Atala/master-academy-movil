import '../../domain/entities/syllabus.dart';

class SyllabusSectionModel extends SyllabusSection {
  const SyllabusSectionModel({
    required super.id,
    required super.title,
    required super.order,
    super.lessons,
  });

  factory SyllabusSectionModel.fromJson(Map<String, dynamic> json) {
    var rawLessons = json['lessons'] as List? ?? json['children'] as List? ?? [];
    List<Lesson> lessonsList = rawLessons
        .map((l) => LessonModel.fromJson(l as Map<String, dynamic>))
        .toList();

    return SyllabusSectionModel(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      title: json['title']?.toString() ?? json['titulo']?.toString() ?? 'Módulo',
      order: json['order'] as int? ?? json['orden'] as int? ?? json['sort_order'] as int? ?? 1,
      lessons: lessonsList,
    );
  }
}

class LessonModel extends Lesson {
  const LessonModel({
    required super.id,
    required super.syllabusId,
    required super.title,
    super.description,
    super.videoUrl,
    super.durationSeconds,
    required super.order,
    super.isCompleted,
    super.isFreePreview,
    super.resources,
    super.type,
  });

  factory LessonModel.fromJson(Map<String, dynamic> json) {
    var rawResources = json['resources'] as List? ?? [];
    List<LessonResource> resourcesList = rawResources
        .map((r) => LessonResourceModel.fromJson(r as Map<String, dynamic>))
        .toList();

    // Check completion status from progress relation if present
    bool completed = json['is_completed'] == true ||
        json['completed'] == true ||
        (json['progress'] != null && json['progress']['completed'] == true);

    final rawVideo = json['video_url']?.toString() ?? json['videoUrl']?.toString() ?? json['video']?.toString();
    final cleanVideo = (rawVideo != null && rawVideo.trim().isNotEmpty) ? rawVideo.trim() : null;
    final desc = json['description']?.toString() ?? json['content']?.toString() ?? json['contenido']?.toString();
    final rawType = json['type']?.toString().toLowerCase() ?? '';

    String detectedType = 'video';
    if (rawType.contains('lectura') || rawType.contains('contenido') || rawType.contains('articulo') || rawType.contains('texto')) {
      detectedType = (cleanVideo != null) ? 'mixed' : 'reading';
    } else if (cleanVideo == null || cleanVideo.isEmpty) {
      detectedType = 'reading';
    } else if (desc != null && desc.trim().length > 100) {
      detectedType = 'mixed';
    }

    int durationSec = 0;
    if (json['duration_seconds'] != null) {
      durationSec = json['duration_seconds'] is int ? json['duration_seconds'] as int : int.tryParse(json['duration_seconds'].toString()) ?? 0;
    } else if (json['duration'] != null && json['duration'] is int) {
      durationSec = json['duration'] as int;
    } else if (json['duration_minutes'] != null) {
      final mins = json['duration_minutes'] is int ? json['duration_minutes'] as int : int.tryParse(json['duration_minutes'].toString()) ?? 0;
      durationSec = mins * 60;
    }

    return LessonModel(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      syllabusId: json['course_syllabus_id'] as int? ??
          json['parent_id'] as int? ??
          json['syllabus_id'] as int? ??
          json['section_id'] as int? ??
          0,
      title: json['title']?.toString() ?? json['titulo']?.toString() ?? 'Lección',
      description: desc,
      videoUrl: cleanVideo,
      durationSeconds: durationSec,
      order: json['order'] as int? ?? json['orden'] as int? ?? json['sort_order'] as int? ?? 1,
      isCompleted: completed,
      isFreePreview: json['is_free_preview'] == true || json['is_preview'] == true,
      resources: resourcesList,
      type: detectedType,
    );
  }
}

class LessonResourceModel extends LessonResource {
  const LessonResourceModel({
    required super.id,
    required super.title,
    super.fileUrl,
    super.fileType,
  });

  factory LessonResourceModel.fromJson(Map<String, dynamic> json) {
    String? fileUrl = json['file_url']?.toString() ?? json['url']?.toString();
    if ((fileUrl == null || fileUrl.isEmpty) && json['file'] is Map && json['file']['path'] != null) {
      fileUrl = json['file']['path'].toString();
    }

    String? fileType = json['file_type']?.toString() ?? json['type']?.toString();
    if ((fileType == null || fileType.isEmpty) && json['file'] is Map && json['file']['extension'] != null) {
      fileType = json['file']['extension'].toString();
    }

    return LessonResourceModel(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      title: json['title']?.toString() ?? json['name']?.toString() ?? 'Recurso',
      fileUrl: fileUrl,
      fileType: fileType,
    );
  }
}
