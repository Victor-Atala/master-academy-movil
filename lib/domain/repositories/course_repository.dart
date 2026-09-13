import '../entities/course.dart';
import '../entities/syllabus.dart';

abstract class CourseRepository {
  bool get isOffline;
  void setOffline(bool offline);
  Future<List<Course>> getCourses({String? category, String? search});
  Future<Course> getCourseById(String id);
  Future<List<Category>> getCategories();
  Future<List<Course>> getLearningCourses();
  Future<List<SyllabusSection>> getCourseSyllabi(dynamic courseId);
  Future<Map<String, dynamic>> getCourseProgress(dynamic courseId);
  Future<bool> updateLessonProgress(dynamic lessonId, {required bool completed, int timeSpentSeconds = 0});
  Future<bool> enrollCourse(dynamic courseId, {String? code});
}