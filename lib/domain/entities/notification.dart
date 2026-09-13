import 'package:flutter/material.dart';

enum NotificationType { welcome, courseUpdate, reminder, paymentSuccess }

class AppNotification {
  final String id;
  final String title;
  final String description;
  final DateTime timestamp;
  final NotificationType type;
  final bool isRead;
  final String? courseId;
  final String? categoryName;

  const AppNotification({
    required this.id,
    required this.title,
    required this.description,
    required this.timestamp,
    required this.type,
    this.isRead = false,
    this.courseId,
    this.categoryName,
  });

  AppNotification copyWith({
    bool? isRead,
    String? courseId,
    String? categoryName,
  }) {
    return AppNotification(
      id: id,
      title: title,
      description: description,
      timestamp: timestamp,
      type: type,
      isRead: isRead ?? this.isRead,
      courseId: courseId ?? this.courseId,
      categoryName: categoryName ?? this.categoryName,
    );
  }

  IconData get icon {
    switch (type) {
      case NotificationType.welcome:
        return Icons.celebration_rounded;
      case NotificationType.courseUpdate:
        return Icons.auto_stories_rounded;
      case NotificationType.reminder:
        return Icons.notification_important_rounded;
      case NotificationType.paymentSuccess:
        return Icons.check_circle_rounded;
    }
  }
}
