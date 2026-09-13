import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../constants/api_constants.dart';
import '../constants/navigation_keys.dart';
import '../../data/models/course_model.dart';
import '../../domain/entities/notification.dart';
import '../../presentation/viewmodels/course_viewmodel.dart';
import '../../presentation/viewmodels/notification_viewmodel.dart';
import '../../presentation/views/course_detail/course_detail_screen.dart';
import '../../presentation/widgets/in_app_notification_banner.dart';

class RealtimeSyncService {
  final Dio _dio;
  final CourseViewModel _courseViewModel;
  final NotificationViewModel _notificationViewModel;

  Timer? _syncTimer;
  int _lastCourseId = 0;
  bool _isInitialized = false;
  bool _isChecking = false;

  RealtimeSyncService({
    Dio? dio,
    required CourseViewModel courseViewModel,
    required NotificationViewModel notificationViewModel,
  })  : _dio = dio ?? Dio(),
        _courseViewModel = courseViewModel,
        _notificationViewModel = notificationViewModel;

  void start() {
    _syncTimer?.cancel();
    // Immediate initial check, then periodic poll every 8 seconds
    _checkForUpdates();
    _syncTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      _checkForUpdates();
    });
  }

  void stop() {
    _syncTimer?.cancel();
    _syncTimer = null;
  }

  Future<void> _checkForUpdates() async {
    if (_isChecking) return;
    _isChecking = true;

    try {
      final url = '${ApiConstants.baseUrl}/courses/latest-sync?since_id=$_lastCourseId';
      final response = await _dio.get(
        url,
        options: Options(
          sendTimeout: const Duration(seconds: 3),
          receiveTimeout: const Duration(seconds: 3),
          headers: {'Accept': 'application/json'},
        ),
      );

      if (response.statusCode == 200) {
        if (_courseViewModel.isOffline) {
          _courseViewModel.setOffline(false);
        }
      }

      if (response.statusCode == 200 && response.data is Map) {
        final data = response.data as Map<String, dynamic>;
        final latestCourseMap = data['latest_course'] as Map<String, dynamic>?;

        if (latestCourseMap != null && latestCourseMap['id'] != null) {
          final int courseId = latestCourseMap['id'] is int
              ? latestCourseMap['id']
              : int.tryParse(latestCourseMap['id'].toString()) ?? 0;

          // If first run, initialize baseline ID to avoid spamming existing courses
          if (!_isInitialized) {
            _lastCourseId = courseId;
            _isInitialized = true;
            return;
          }

          // If a genuinely new course was added
          if (courseId > _lastCourseId || data['has_new'] == true) {
            _lastCourseId = courseId;
            final newCourse = CourseModel.fromJson(latestCourseMap);

            // 1. Force catalog refresh in real-time
            _courseViewModel.fetchCourses(force: true);

            // 2. Evaluate Category Relevance:
            // Check if the new course matches user's enrolled courses, viewed category, or default interest
            final bool isCategoryMatch = _matchesUserCategory(newCourse);

            if (isCategoryMatch) {
              _triggerCourseRecommendation(newCourse);
            }
          }
        }
      }
    } catch (_) {
      // Gracefully ignore temporary network failures during polling
    } finally {
      _isChecking = false;
    }
  }

  bool _matchesUserCategory(CourseModel course) {
    final String targetCat = course.category.toLowerCase().trim();

    // Collect enrolled categories
    final enrolledCats = _courseViewModel.enrolledCourses
        .map((c) => c.category.toLowerCase().trim())
        .where((c) => c.isNotEmpty)
        .toSet();

    // If user has enrolled courses, check if category matches
    if (enrolledCats.isNotEmpty) {
      return enrolledCats.contains(targetCat);
    }

    // If no enrollments yet, check currently selected catalog filter
    final selectedCat = _courseViewModel.selectedCategory.toLowerCase().trim();
    if (selectedCat != 'todos' && selectedCat.isNotEmpty) {
      return selectedCat == targetCat;
    }

    // Default: recommend new course
    return true;
  }

  void _triggerCourseRecommendation(CourseModel course) {
    // 1. Insert notification into history
    final notif = AppNotification(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: 'Te podría gustar este nuevo curso',
      description: 'Se ha publicado "${course.title}" en la categoría ${course.category}.',
      timestamp: DateTime.now(),
      type: NotificationType.courseUpdate,
      courseId: course.id,
      categoryName: course.category,
    );
    _notificationViewModel.addNotification(notif);

    // 2. Display interactive top overlay banner
    final context = rootNavigatorKey.currentContext;
    if (context != null) {
      InAppNotificationBanner.show(
        context: context,
        course: course,
        onTap: () {
          rootNavigatorKey.currentState?.push(
            MaterialPageRoute(
              builder: (_) => CourseDetailScreen(course: course),
            ),
          );
        },
      );
    }
  }
}
