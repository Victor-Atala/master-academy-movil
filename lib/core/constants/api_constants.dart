import 'package:flutter/foundation.dart';

class ApiConstants {
  static String _customBaseUrl = '';

  static void setBaseUrl(String url) {
    _customBaseUrl = url.trim();
  }

  static void resetToDefault() {
    _customBaseUrl = '';
  }

  // Default base URLs depending on runtime platform
  static String get baseUrl {
    if (_customBaseUrl.isNotEmpty) {
      return _customBaseUrl;
    }
    if (kIsWeb) {
      return 'http://localhost:8000/api/v1';
    }
    // IP local actual de la máquina de desarrollo en la red Wi-Fi
    return 'http://192.168.68.106:8000/api/v1';
  }

  // Auth endpoints
  static const String login = '/auth/login';
  static const String register = '/auth/register';
  static const String me = '/auth/me';
  static const String logout = '/auth/logout';
  static const String updateProfile = '/auth/profile';
  static const String updatePassword = '/auth/password';

  // Catalog endpoints
  static const String courses = '/courses';
  static const String categories = '/categories';

  // Learning & Student endpoints
  static const String learningCourses = '/me/courses/learning';
  static String courseSyllabi(dynamic courseId) => '/courses/$courseId/syllabi';
  static String courseProgress(dynamic courseId) => '/courses/$courseId/progress';
  static String lessonProgress(dynamic lessonId) => '/lessons/$lessonId/complete';
  static String lessonResources(dynamic lessonId) => '/lessons/$lessonId/resources';
  static String enrollCourse(dynamic courseId) => '/courses/$courseId/enroll';

  // Commerce & Checkout
  static String checkoutCourse(dynamic courseId) => '/courses/$courseId/checkout';
  static String orderPayments(dynamic orderId) => '/orders/$orderId/payments';

  // Certificates
  static const String certificates = '/certificates';
  static String verifyCertificate(String uuid) => '/certificates/verify/$uuid';
}