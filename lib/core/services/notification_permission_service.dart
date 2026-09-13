import 'package:permission_handler/permission_handler.dart';

class NotificationPermissionService {
  Future<bool> isNotificationPermissionGranted() async {
    final status = await Permission.notification.status;
    return status.isGranted;
  }

  Future<bool> requestNotificationPermission() async {
    final status = await Permission.notification.request();
    return status.isGranted;
  }

  Future<bool> openAppSettingsIfDenied() async {
    final status = await Permission.notification.status;
    if (status.isPermanentlyDenied) {
      return await openAppSettings();
    }
    return false;
  }
}
