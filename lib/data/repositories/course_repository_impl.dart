import '../../domain/entities/course.dart';
import '../../domain/entities/syllabus.dart';
import '../../domain/repositories/course_repository.dart';
import '../datasources/course_remote_datasource.dart';

class CourseRepositoryImpl implements CourseRepository {
  final CourseRemoteDataSource remoteDataSource;

  CourseRepositoryImpl({required this.remoteDataSource});

  @override
  bool get isOffline => remoteDataSource.isOffline;

  @override
  void setOffline(bool offline) {
    remoteDataSource.setOffline(offline);
  }

  @override
  Future<List<Course>> getCourses({String? category, String? search}) async {
    return await remoteDataSource.fetchCourses(category: category, search: search);
  }

  @override
  Future<Course> getCourseById(String id) async {
    return await remoteDataSource.fetchCourseDetail(id);
  }

  @override
  Future<List<Category>> getCategories() async {
    return await remoteDataSource.fetchCategories();
  }

  @override
  Future<List<Course>> getLearningCourses() async {
    return await remoteDataSource.fetchLearningCourses();
  }

  @override
  Future<List<SyllabusSection>> getCourseSyllabi(dynamic courseId) async {
    return await remoteDataSource.fetchCourseSyllabi(courseId);
  }

  @override
  Future<Map<String, dynamic>> getCourseProgress(dynamic courseId) async {
    return await remoteDataSource.fetchCourseProgress(courseId);
  }

  @override
  Future<bool> updateLessonProgress(dynamic lessonId, {required bool completed, int timeSpentSeconds = 0}) async {
    return await remoteDataSource.updateLessonProgress(
      lessonId,
      completed: completed,
      timeSpentSeconds: timeSpentSeconds,
    );
  }

  @override
  Future<bool> enrollCourse(dynamic courseId, {String? code}) async {
    return await remoteDataSource.enrollCourse(courseId, code: code);
  }
}