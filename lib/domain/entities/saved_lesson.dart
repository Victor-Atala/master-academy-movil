class SavedLesson {
  final int lessonId;
  final String courseId;
  final String courseTitle;
  final String lessonTitle;
  final String localFilePath;
  final int fileSizeBytes;
  final DateTime downloadedAt;
  final String thumbnail;

  SavedLesson({
    required this.lessonId,
    required this.courseId,
    required this.courseTitle,
    required this.lessonTitle,
    required this.localFilePath,
    required this.fileSizeBytes,
    required this.downloadedAt,
    required this.thumbnail,
  });

  Map<String, dynamic> toJson() => {
    'lessonId': lessonId,
    'courseId': courseId,
    'courseTitle': courseTitle,
    'lessonTitle': lessonTitle,
    'localFilePath': localFilePath,
    'fileSizeBytes': fileSizeBytes,
    'downloadedAt': downloadedAt.toIso8601String(),
    'thumbnail': thumbnail,
  };

  factory SavedLesson.fromJson(Map<String, dynamic> json) => SavedLesson(
    lessonId: json['lessonId'] is int
        ? json['lessonId'] as int
        : int.tryParse(json['lessonId']?.toString() ?? '0') ?? 0,
    courseId: json['courseId']?.toString() ?? '1',
    courseTitle: json['courseTitle']?.toString() ?? 'Curso',
    lessonTitle: json['lessonTitle']?.toString() ?? 'Lección',
    localFilePath: json['localFilePath'] as String? ?? '',
    fileSizeBytes: json['fileSizeBytes'] as int? ?? 0,
    downloadedAt: json['downloadedAt'] != null
        ? DateTime.tryParse(json['downloadedAt'].toString()) ?? DateTime.now()
        : DateTime.now(),
    thumbnail: json['thumbnail'] as String? ?? '',
  );

  String get formattedSize {
    final mb = fileSizeBytes / (1024 * 1024);
    return '${mb.toStringAsFixed(1)} MB';
  }
}