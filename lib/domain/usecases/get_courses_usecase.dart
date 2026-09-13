import '../entities/course.dart';
import '../entities/syllabus.dart';
import '../repositories/course_repository.dart';

class GetCoursesUseCase {
  final CourseRepository repository;

  GetCoursesUseCase(this.repository);

  bool get isOffline => repository.isOffline;
  void setOffline(bool offline) => repository.setOffline(offline);

  Future<List<Course>> execute({String? category, String? search}) async {
    return await repository.getCourses(category: category, search: search);
  }

  Future<Course> getById(String id) async {
    return await repository.getCourseById(id);
  }

  Future<List<Category>> getCategories() async {
    return await repository.getCategories();
  }

  Future<List<Course>> getLearningCourses() async {
    return await repository.getLearningCourses();
  }

  Future<List<SyllabusSection>> getSyllabi(dynamic courseId) async {
    return await repository.getCourseSyllabi(courseId);
  }

  Future<Map<String, dynamic>> getProgress(dynamic courseId) async {
    return await repository.getCourseProgress(courseId);
  }

  Future<bool> updateLessonProgress(dynamic lessonId, {required bool completed, int timeSpentSeconds = 0}) async {
    return await repository.updateLessonProgress(lessonId, completed: completed, timeSpentSeconds: timeSpentSeconds);
  }

  Future<bool> enrollCourse(dynamic courseId, {String? code}) async {
    return await repository.enrollCourse(courseId, code: code);
  }
}