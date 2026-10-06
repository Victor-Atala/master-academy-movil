import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/services/session_storage_service.dart';
import '../../domain/entities/syllabus.dart';
import '../../domain/usecases/get_courses_usecase.dart';

class LearningViewModel extends ChangeNotifier {
  final GetCoursesUseCase _getCoursesUseCase;
  final FlutterSecureStorage _storage;

  LearningViewModel({
    required GetCoursesUseCase getCoursesUseCase,
    FlutterSecureStorage? storage,
  })  : _getCoursesUseCase = getCoursesUseCase,
        _storage = storage ??
            const FlutterSecureStorage(
              aOptions: SessionStorageService.safeAndroidOptions,
            );

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  List<SyllabusSection> _sections = [];
  List<SyllabusSection> get sections => _sections;

  Lesson? _activeLesson;
  Lesson? get activeLesson => _activeLesson;

  double _progressPercentage = 0.0;
  double get progressPercentage => _progressPercentage;

  int _completedLessonsCount = 0;
  int get completedLessonsCount => _completedLessonsCount;

  int _totalLessonsCount = 0;
  int get totalLessonsCount => _totalLessonsCount;

  dynamic _currentCourseId;
  dynamic get currentCourseId => _currentCourseId;

  final Map<String, Set<int>> _savedCompletedLessonsCache = {};

  Future<Set<int>> _getSavedCompletedLessonIds(dynamic courseId) async {
    if (courseId == null) return {};
    final key = courseId.toString();
    if (_savedCompletedLessonsCache.containsKey(key)) {
      return Set<int>.from(_savedCompletedLessonsCache[key]!);
    }

    final Set<int> result = {};
    try {
      final raw = await _storage.read(key: 'completed_lessons_course_$courseId');
      if (raw != null && raw.isNotEmpty) {
        final List list = jsonDecode(raw);
        for (final item in list) {
          final parsed = int.tryParse(item.toString());
          if (parsed != null && parsed > 0) result.add(parsed);
        }
      }

      // Also check cleaned numeric id if courseId is e.g. "course-1"
      final cleanId = courseId.toString().replaceAll(RegExp(r'[^0-9]'), '');
      if (cleanId.isNotEmpty && cleanId != courseId.toString()) {
        final rawClean = await _storage.read(key: 'completed_lessons_course_$cleanId');
        if (rawClean != null && rawClean.isNotEmpty) {
          final List list = jsonDecode(rawClean);
          for (final item in list) {
            final parsed = int.tryParse(item.toString());
            if (parsed != null && parsed > 0) result.add(parsed);
          }
        }
      }
    } catch (_) {}
    _savedCompletedLessonsCache[key] = Set<int>.from(result);
    return result;
  }

  Future<void> _saveCompletedLessonId(dynamic courseId, int lessonId) async {
    try {
      final set = await _getSavedCompletedLessonIds(courseId);
      set.add(lessonId);
      _savedCompletedLessonsCache[courseId.toString()] = Set<int>.from(set);
      final jsonVal = jsonEncode(set.toList());

      await _storage.write(
        key: 'completed_lessons_course_$courseId',
        value: jsonVal,
      );

      final cleanId = courseId.toString().replaceAll(RegExp(r'[^0-9]'), '');
      if (cleanId.isNotEmpty && cleanId != courseId.toString()) {
        _savedCompletedLessonsCache[cleanId] = Set<int>.from(set);
        await _storage.write(
          key: 'completed_lessons_course_$cleanId',
          value: jsonVal,
        );
      }

      // Also persist individual lesson key
      await _storage.write(
        key: 'completed_lesson_$lessonId',
        value: 'true',
      );
    } catch (_) {}
  }

  Future<void> _removeCompletedLessonId(dynamic courseId, int lessonId) async {
    try {
      final set = await _getSavedCompletedLessonIds(courseId);
      set.remove(lessonId);
      _savedCompletedLessonsCache[courseId.toString()] = Set<int>.from(set);
      final jsonVal = jsonEncode(set.toList());

      await _storage.write(
        key: 'completed_lessons_course_$courseId',
        value: jsonVal,
      );

      final cleanId = courseId.toString().replaceAll(RegExp(r'[^0-9]'), '');
      if (cleanId.isNotEmpty && cleanId != courseId.toString()) {
        _savedCompletedLessonsCache[cleanId] = Set<int>.from(set);
        await _storage.write(
          key: 'completed_lessons_course_$cleanId',
          value: jsonVal,
        );
      }

      await _storage.delete(key: 'completed_lesson_$lessonId');
    } catch (_) {}
  }

  Future<void> loadCourseSyllabus(dynamic courseId) async {
    _currentCourseId = courseId;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final syllabi = await _getCoursesUseCase.getSyllabi(courseId);
      final savedCompletedIds = await _getSavedCompletedLessonIds(courseId);

      // Apply locally saved completed progress to the syllabus
      _sections = syllabi.map((section) {
        final updatedLessons = section.lessons.map((lesson) {
          final isLocallySaved = savedCompletedIds.contains(lesson.id);
          final isCompleted = lesson.isCompleted || isLocallySaved;
          return Lesson(
            id: lesson.id,
            syllabusId: lesson.syllabusId,
            title: lesson.title,
            description: lesson.description,
            videoUrl: lesson.videoUrl,
            durationSeconds: lesson.durationSeconds,
            order: lesson.order,
            isCompleted: isCompleted,
            isFreePreview: lesson.isFreePreview,
            resources: lesson.resources,
            type: lesson.type,
          );
        }).toList();

        return SyllabusSection(
          id: section.id,
          title: section.title,
          order: section.order,
          lessons: updatedLessons,
          evaluation: section.evaluation,
          isFinalCertification: section.isFinalCertification,
        );
      }).toList();

      // Recalculate totals
      int total = 0;
      int completed = 0;
      for (final s in _sections) {
        for (final l in s.lessons) {
          total++;
          if (l.isCompleted) completed++;
        }
      }
      _totalLessonsCount = total;
      _completedLessonsCount = completed;
      _progressPercentage = total > 0 ? (completed / total) * 100 : 0.0;

      // Update stored progress
      await _storage.write(
        key: 'course_progress_percentage_$courseId',
        value: _progressPercentage.toString(),
      );

      // Set active lesson to first uncompleted or first lesson
      if (_sections.isNotEmpty && _sections.first.lessons.isNotEmpty) {
        Lesson? firstUncompleted;
        for (final s in _sections) {
          for (final l in s.lessons) {
            if (!l.isCompleted) {
              firstUncompleted = l;
              break;
            }
          }
          if (firstUncompleted != null) break;
        }
        _activeLesson = firstUncompleted ?? _sections.first.lessons.first;
      }
    } catch (e) {
      _errorMessage = 'No se pudo cargar el temario del curso.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void selectLesson(Lesson lesson) {
    _activeLesson = lesson;
    notifyListeners();
  }

  Lesson? getNextLesson(Lesson currentLesson) {
    bool foundCurrent = false;
    for (final section in _sections) {
      for (final lesson in section.lessons) {
        if (foundCurrent) {
          return lesson;
        }
        if (lesson.id == currentLesson.id) {
          foundCurrent = true;
        }
      }
    }
    return null;
  }

  void _updateLessonStateInMemory(int lessonId, bool isCompleted) {
    _sections = _sections.map((section) {
      final updatedLessons = section.lessons.map((l) {
        if (l.id == lessonId) {
          return Lesson(
            id: l.id,
            syllabusId: l.syllabusId,
            title: l.title,
            description: l.description,
            videoUrl: l.videoUrl,
            durationSeconds: l.durationSeconds,
            order: l.order,
            isCompleted: isCompleted,
            isFreePreview: l.isFreePreview,
            resources: l.resources,
            type: l.type,
          );
        }
        return l;
      }).toList();

      return SyllabusSection(
        id: section.id,
        title: section.title,
        order: section.order,
        lessons: updatedLessons,
        evaluation: section.evaluation,
        isFinalCertification: section.isFinalCertification,
      );
    }).toList();

    if (_activeLesson?.id == lessonId) {
      _activeLesson = Lesson(
        id: _activeLesson!.id,
        syllabusId: _activeLesson!.syllabusId,
        title: _activeLesson!.title,
        description: _activeLesson!.description,
        videoUrl: _activeLesson!.videoUrl,
        durationSeconds: _activeLesson!.durationSeconds,
        order: _activeLesson!.order,
        isCompleted: isCompleted,
        isFreePreview: _activeLesson!.isFreePreview,
        resources: _activeLesson!.resources,
        type: _activeLesson!.type,
      );
    }

    int total = 0;
    int completed = 0;
    for (final s in _sections) {
      for (final l in s.lessons) {
        total++;
        if (l.isCompleted) completed++;
      }
    }
    _totalLessonsCount = total;
    _completedLessonsCount = completed;
    _progressPercentage = total > 0 ? (completed / total) * 100 : 0.0;

    if (_currentCourseId != null) {
      _storage.write(
        key: 'course_progress_percentage_$_currentCourseId',
        value: _progressPercentage.toString(),
      );
    }
  }

  /// Update the active lesson's real duration once loaded by the media player
  void updateActiveLessonDuration(int durationSeconds) {
    if (_activeLesson == null || durationSeconds <= 0) return;
    if (_activeLesson!.durationSeconds == durationSeconds) return;

    _activeLesson = Lesson(
      id: _activeLesson!.id,
      syllabusId: _activeLesson!.syllabusId,
      title: _activeLesson!.title,
      description: _activeLesson!.description,
      videoUrl: _activeLesson!.videoUrl,
      durationSeconds: durationSeconds,
      order: _activeLesson!.order,
      isCompleted: _activeLesson!.isCompleted,
      isFreePreview: _activeLesson!.isFreePreview,
      resources: _activeLesson!.resources,
      type: _activeLesson!.type,
    );

    _sections = _sections.map((section) {
      final updatedLessons = section.lessons.map((l) {
        if (l.id == _activeLesson!.id) {
          return Lesson(
            id: l.id,
            syllabusId: l.syllabusId,
            title: l.title,
            description: l.description,
            videoUrl: l.videoUrl,
            durationSeconds: durationSeconds,
            order: l.order,
            isCompleted: l.isCompleted,
            isFreePreview: l.isFreePreview,
            resources: l.resources,
            type: l.type,
          );
        }
        return l;
      }).toList();
      return SyllabusSection(
        id: section.id,
        title: section.title,
        order: section.order,
        lessons: updatedLessons,
        evaluation: section.evaluation,
        isFinalCertification: section.isFinalCertification,
      );
    }).toList();

    notifyListeners();
  }

  /// Mark lesson completed automatically upon video or activity end
  Future<bool> markLessonAsCompleted(Lesson lesson, {dynamic courseId}) async {
    if (lesson.isCompleted) return false; // Already completed
    final targetCourseId = courseId ?? _currentCourseId;

    if (targetCourseId != null) {
      await _saveCompletedLessonId(targetCourseId, lesson.id);
    }

    _updateLessonStateInMemory(lesson.id, true);
    notifyListeners();

    // Fire API call concurrently
    try {
      await _getCoursesUseCase.updateLessonProgress(
        lesson.id,
        completed: true,
        timeSpentSeconds: lesson.durationSeconds > 0 ? lesson.durationSeconds : 120,
      );
      return true;
    } catch (_) {
      return true;
    }
  }

  /// Toggle lesson completed manually by user tap
  Future<bool> toggleLessonCompletion(Lesson lesson, {dynamic courseId}) async {
    final targetCourseId = courseId ?? _currentCourseId;
    final newStatus = !lesson.isCompleted;

    if (targetCourseId != null) {
      if (newStatus) {
        await _saveCompletedLessonId(targetCourseId, lesson.id);
      } else {
        await _removeCompletedLessonId(targetCourseId, lesson.id);
      }
    }

    _updateLessonStateInMemory(lesson.id, newStatus);
    notifyListeners();

    // Fire API call concurrently
    try {
      await _getCoursesUseCase.updateLessonProgress(
        lesson.id,
        completed: newStatus,
        timeSpentSeconds: lesson.durationSeconds > 0 ? lesson.durationSeconds : 120,
      );
    } catch (_) {}

    return newStatus;
  }
}
