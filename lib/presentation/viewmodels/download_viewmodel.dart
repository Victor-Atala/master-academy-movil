import 'package:flutter/material.dart';
import '../../core/services/download_service.dart';
import '../../domain/entities/saved_lesson.dart';

class DownloadViewModel extends ChangeNotifier {
  final DownloadService _service;

  DownloadViewModel({DownloadService? service})
      : _service = service ?? DownloadService() {
    loadSavedLessons();
  }

  List<SavedLesson> _savedLessons = [];
  List<SavedLesson> get savedLessons => _savedLessons;

  final Map<int, double> _downloadProgress = {};
  Map<int, double> get downloadProgress => _downloadProgress;

  Future<void> loadSavedLessons() async {
    _savedLessons = await _service.getSavedLessons();
    notifyListeners();
  }

  bool isDownloaded(int lessonId) {
    return _savedLessons.any((l) => l.lessonId == lessonId);
  }

  bool isDownloading(int lessonId) {
    return _downloadProgress.containsKey(lessonId);
  }

  double getProgress(int lessonId) {
    return _downloadProgress[lessonId] ?? 0.0;
  }

  Future<bool> downloadLesson({
    required int lessonId,
    required String courseId,
    required String courseTitle,
    required String lessonTitle,
    required String videoUrl,
    required String thumbnail,
  }) async {
    _downloadProgress[lessonId] = 0.01;
    notifyListeners();

    final result = await _service.downloadLessonVideo(
      lessonId: lessonId,
      courseId: courseId,
      courseTitle: courseTitle,
      lessonTitle: lessonTitle,
      videoUrl: videoUrl,
      thumbnail: thumbnail,
      onProgress: (progress) {
        _downloadProgress[lessonId] = progress;
        notifyListeners();
      },
    );

    _downloadProgress.remove(lessonId);
    if (result != null) {
      await loadSavedLessons();
      notifyListeners();
      return true;
    }
    notifyListeners();
    return false;
  }

  Future<bool> downloadReadingLesson({
    required int lessonId,
    required String courseId,
    required String courseTitle,
    required String lessonTitle,
    required String thumbnail,
  }) async {
    _downloadProgress[lessonId] = 0.50;
    notifyListeners();

    final result = await _service.saveReadingLessonOffline(
      lessonId: lessonId,
      courseId: courseId,
      courseTitle: courseTitle,
      lessonTitle: lessonTitle,
      thumbnail: thumbnail,
    );

    _downloadProgress.remove(lessonId);
    if (result != null) {
      await loadSavedLessons();
      notifyListeners();
      return true;
    }
    notifyListeners();
    return false;
  }

  Future<void> deleteLesson(int lessonId) async {
    await _service.deleteSavedLesson(lessonId);
    await loadSavedLessons();
  }

  String get totalFormattedSize {
    final totalBytes = _savedLessons.fold<int>(0, (sum, item) => sum + item.fileSizeBytes);
    final mb = totalBytes / (1024 * 1024);
    return '${mb.toStringAsFixed(1)} MB';
  }
}
