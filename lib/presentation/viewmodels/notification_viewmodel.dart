import 'package:flutter/material.dart';
import '../../domain/entities/notification.dart';

class NotificationViewModel extends ChangeNotifier {
  List<AppNotification> _notifications = [
    AppNotification(
      id: '1',
      title: '¡Bienvenido a Master Academy!',
      description: 'Explora nuestros cursos certificados e impulsa tu carrera profesional.',
      timestamp: DateTime.now().subtract(const Duration(hours: 2)),
      type: NotificationType.welcome,
    ),
    AppNotification(
      id: '2',
      title: 'Nuevo contenido en Ciberseguridad',
      description: 'Se han añadido 2 nuevas lecciones al módulo de Redes.',
      timestamp: DateTime.now().subtract(const Duration(days: 1)),
      type: NotificationType.courseUpdate,
    ),
    AppNotification(
      id: '3',
      title: 'Acceso y Beca Activada',
      description: 'Tu código de cupón/beca ha sido validado correctamente. Disfruta tu curso.',
      timestamp: DateTime.now().subtract(const Duration(days: 2)),
      type: NotificationType.courseUpdate,
      isRead: true,
    ),
  ];

  List<AppNotification> get notifications => _notifications;

  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  void markAsRead(String id) {
    final index = _notifications.indexWhere((n) => n.id == id);
    if (index != -1) {
      _notifications[index] = _notifications[index].copyWith(isRead: true);
      notifyListeners();
    }
  }

  void addNotification(AppNotification notification) {
    _notifications.insert(0, notification);
    notifyListeners();
  }

  void markAllAsRead() {
    _notifications = _notifications.map((n) => n.copyWith(isRead: true)).toList();
    notifyListeners();
  }
}
