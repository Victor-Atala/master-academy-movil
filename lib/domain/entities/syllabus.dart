class SyllabusSection {
  final int id;
  final String title;
  final int order;
  final List<Lesson> lessons;

  const SyllabusSection({
    required this.id,
    required this.title,
    required this.order,
    this.lessons = const [],
  });
}

class Lesson {
  final int id;
  final int syllabusId;
  final String title;
  final String? description;
  final String? videoUrl;
  final int durationSeconds;
  final int order;
  final bool isCompleted;
  final bool isFreePreview;
  final List<LessonResource> resources;
  final String type; // 'video', 'reading', 'mixed'

  const Lesson({
    required this.id,
    required this.syllabusId,
    required this.title,
    this.description,
    this.videoUrl,
    this.durationSeconds = 0,
    required this.order,
    this.isCompleted = false,
    this.isFreePreview = false,
    this.resources = const [],
    this.type = 'video',
  });

  bool get isReading {
    final hasNoVideo = videoUrl == null || videoUrl!.trim().isEmpty;
    return type == 'reading' || type == 'lectura' || type == 'contenido' || type == 'texto' || hasNoVideo;
  }

  bool get isMixed {
    final hasVideo = videoUrl != null && videoUrl!.trim().isNotEmpty;
    final hasLongText = description != null && description!.trim().length > 80;
    return type == 'mixed' || (hasVideo && hasLongText);
  }

  bool get isVideoOnly => !isReading && !isMixed;

  String get formattedDuration {
    if (isReading) {
      final text = description?.trim() ?? '';
      final wordCount = text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
      final readingMins = (wordCount / 160).ceil().clamp(1, 45);
      return 'Lectura • $readingMins min';
    }
    if (durationSeconds <= 0) {
      return isMixed ? 'Video + Lectura' : 'Clase en video';
    }
    final minutes = durationSeconds ~/ 60;
    final seconds = durationSeconds % 60;
    if (minutes > 0) {
      return '$minutes min${seconds > 0 ? ' $seconds s' : ''}';
    }
    return '$seconds s';
  }
}

class LessonResource {
  final int id;
  final String title;
  final String? fileUrl;
  final String? fileType;

  const LessonResource({
    required this.id,
    required this.title,
    this.fileUrl,
    this.fileType,
  });
}
