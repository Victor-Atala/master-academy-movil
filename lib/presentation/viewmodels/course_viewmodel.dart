import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/common/ui_state.dart';
import '../../core/constants/api_constants.dart';
import '../../core/error/failure.dart';
import '../../data/models/course_model.dart';
import '../../domain/entities/course.dart';
import '../../domain/usecases/get_courses_usecase.dart';

class CourseViewModel extends ChangeNotifier with WidgetsBindingObserver {
  final GetCoursesUseCase _getCoursesUseCase;
  final FlutterSecureStorage _storage;
  final Set<String> _locallyEnrolledCourseIds = {};
  Timer? _connectivityTimer;
  bool _isCheckingConnection = false;

  CourseViewModel({
    required GetCoursesUseCase getCoursesUseCase,
    FlutterSecureStorage? storage,
  })  : _getCoursesUseCase = getCoursesUseCase,
        _storage = storage ?? const FlutterSecureStorage() {
    _loadEnrolledCoursesFromStorage();
    WidgetsBinding.instance.addObserver(this);
    _startConnectivityMonitor();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      checkConnectivity();
    }
  }

  bool get isOffline => _getCoursesUseCase.isOffline;

  void setOffline(bool offline) {
    final bool previous = _getCoursesUseCase.isOffline;
    _getCoursesUseCase.setOffline(offline);
    if (previous != offline) {
      notifyListeners();
      if (!offline) {
        // Al volver a tener conexión, refrescar automáticamente catálogo y padrón
        fetchCourses(force: true);
        fetchLearningCourses(force: true);
      }
    }
  }

  void _startConnectivityMonitor() {
    _connectivityTimer?.cancel();
    _connectivityTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      checkConnectivity();
    });
  }

  Future<bool> checkConnectivity() async {
    if (_isCheckingConnection) return !isOffline;
    _isCheckingConnection = true;

    try {
      final bool hasConnection = await _probeInternetOrServer();
      setOffline(!hasConnection);
      return hasConnection;
    } finally {
      _isCheckingConnection = false;
    }
  }

  Future<bool> _probeInternetOrServer() async {
    // 1. Probar servidor API configurado actualmente con timeout tolerante
    try {
      final uri = Uri.parse(ApiConstants.baseUrl);
      final socket = await Socket.connect(
        uri.host,
        uri.port,
        timeout: const Duration(seconds: 4),
      );
      socket.destroy();
      return true;
    } catch (_) {}

    // 2. Solo si el servidor principal falla y estamos offline, probar candidatos locales de respaldo
    if (isOffline) {
      final candidateHosts = [
        '192.168.68.103',
        '192.168.68.104',
        '192.168.68.106',
        '10.0.2.2',
        '127.0.0.1',
      ];
      for (final host in candidateHosts) {
        try {
          final socket = await Socket.connect(
            host,
            8000,
            timeout: const Duration(milliseconds: 1500),
          );
          socket.destroy();
          // Servidor detectado en host candidato -> actualizar y persistir
          final discoveredUrl = 'http://$host:8000/api/v1';
          ApiConstants.setBaseUrl(discoveredUrl);
          await _storage.write(key: 'custom_api_base_url', value: discoveredUrl);
          return true;
        } catch (_) {}
      }
    }

    // 3. Probar conectividad global a internet (DNS google.com)
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 2));
      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
        return true;
      }
    } catch (_) {}

    return false;
  }

  Future<bool> setCustomApiUrl(String newUrl) async {
    final clean = newUrl.trim();
    if (clean.isEmpty) return false;
    ApiConstants.setBaseUrl(clean);
    await _storage.write(key: 'custom_api_base_url', value: clean);
    final connected = await checkConnectivity();
    if (connected) {
      fetchCourses(force: true);
      fetchLearningCourses(force: true);
    }
    return connected;
  }

  // Catalog State
  UiState<List<Course>> _state = const UiInitial();
  UiState<List<Course>> get state => _state;

  // Categories State
  List<Category> _categories = [];
  List<Category> get categories => _categories;

  String _selectedCategory = 'Todos';
  String get selectedCategory => _selectedCategory;

  String _searchQuery = '';
  String get searchQuery => _searchQuery;

  // Learning / Padrón State
  UiState<List<Course>> _learningState = const UiInitial();
  UiState<List<Course>> get learningState => _learningState;

  final List<Course> _enrolledCourses = [];
  List<Course> get enrolledCourses => List.unmodifiable(_enrolledCourses);

  Future<void> _loadEnrolledCoursesFromStorage() async {
    try {
      final rawIds = await _storage.read(key: 'user_enrolled_course_ids');
      if (rawIds != null && rawIds.isNotEmpty) {
        final List list = jsonDecode(rawIds);
        _locallyEnrolledCourseIds.addAll(list.map((e) => e.toString()));
      }

      final rawCourses = await _storage.read(key: 'user_enrolled_courses_data');
      if (rawCourses != null && rawCourses.isNotEmpty) {
        final List list = jsonDecode(rawCourses);
        for (final item in list) {
          try {
            final course = CourseModel.fromJson(item as Map<String, dynamic>);
            if (!_enrolledCourses.any((c) => c.id == course.id)) {
              _enrolledCourses.add(course);
            }
            _locallyEnrolledCourseIds.add(course.id);
          } catch (_) {}
        }
      }

      if (_enrolledCourses.isNotEmpty) {
        _learningState = UiSuccess(List.unmodifiable(_enrolledCourses));
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> _saveEnrolledCoursesToStorage() async {
    try {
      await _storage.write(
        key: 'user_enrolled_course_ids',
        value: jsonEncode(_locallyEnrolledCourseIds.toList()),
      );

      final List<Map<String, dynamic>> coursesJson = [];
      for (final c in _enrolledCourses) {
        coursesJson.add({
          'id': c.id,
          'title': c.title,
          'description': c.description,
          'category': c.category,
          'instructor': c.instructor,
          'price': c.price,
          'rating': c.rating,
          'studentsCount': c.studentsCount,
          'duration': c.duration,
          'thumbnail': c.thumbnail,
          'level': c.level,
          'lessonsCount': c.lessonsCount,
          'is_enrolled': true,
          'progress_percentage': c.progressPercentage,
        });
      }
      await _storage.write(
        key: 'user_enrolled_courses_data',
        value: jsonEncode(coursesJson),
      );
    } catch (_) {}
  }

  Future<void> fetchCourses({bool force = false}) async {
    if (!force && _state is UiSuccess<List<Course>>) {
      return;
    }
    _state = const UiLoading();
    notifyListeners();

    try {
      final courses = await _getCoursesUseCase.execute(
        category: (_selectedCategory == 'Todos' || _selectedCategory == 'Todas') ? null : _selectedCategory,
        search: _searchQuery.isEmpty ? null : _searchQuery,
      );
      _state = UiSuccess(courses);
    } catch (e) {
      _state = const UiError(ServerFailure('No se pudieron cargar los cursos'));
    } finally {
      notifyListeners();
    }
  }

  Future<void> fetchCategories() async {
    try {
      final cats = await _getCoursesUseCase.getCategories();
      _categories = cats;
      notifyListeners();
    } catch (_) {}
  }

  final Map<String, double> _courseProgressMemoryCache = {};

  Future<double?> _getStoredCourseProgress(dynamic courseId) async {
    final key = courseId.toString();
    if (_courseProgressMemoryCache.containsKey(key)) {
      return _courseProgressMemoryCache[key];
    }
    try {
      final raw = await _storage.read(key: 'course_progress_percentage_$courseId');
      if (raw != null && raw.isNotEmpty) {
        final val = double.tryParse(raw);
        if (val != null) {
          _courseProgressMemoryCache[key] = val;
          return val;
        }
      }
      final completedRaw = await _storage.read(key: 'completed_lessons_course_$courseId');
      if (completedRaw != null && completedRaw.isNotEmpty) {
        final List list = jsonDecode(completedRaw);
        final val = list.isEmpty ? 0.0 : ((list.length / 4.0) * 100.0).clamp(0.0, 100.0);
        _courseProgressMemoryCache[key] = val;
        return val;
      }
    } catch (_) {}
    return null;
  }

  Future<void> fetchLearningCourses({bool force = false}) async {
    if (!force && _learningState is UiSuccess<List<Course>> && _enrolledCourses.isNotEmpty) {
      return;
    }

    try {
      final token = await _storage.read(key: 'jwt_auth_token');
      if (token == null || token.isEmpty) {
        await _loadEnrolledCoursesFromStorage();
        if (_enrolledCourses.isNotEmpty) {
          _learningState = UiSuccess(List.unmodifiable(_enrolledCourses));
        } else {
          _learningState = const UiInitial();
        }
        notifyListeners();
        return;
      }

      if (_enrolledCourses.isEmpty) {
        _learningState = const UiLoading();
        notifyListeners();
      }

      await _loadEnrolledCoursesFromStorage();

      final learning = await _getCoursesUseCase.getLearningCourses();
      
      final Map<String, Course> mergedMap = {};
      for (final c in _enrolledCourses) {
        mergedMap[c.id] = c;
      }

      for (final c in learning) {
        final storedProgress = await _getStoredCourseProgress(c.id);
        final finalProgress = storedProgress ?? c.progressPercentage;
        mergedMap[c.id] = Course(
          id: c.id,
          title: c.title,
          description: c.description,
          category: c.category,
          instructor: c.instructor,
          price: c.price,
          rating: c.rating,
          studentsCount: c.studentsCount,
          duration: c.duration,
          thumbnail: c.thumbnail,
          level: c.level,
          lessonsCount: c.lessonsCount,
          isEnrolled: true,
          progressPercentage: finalProgress,
        );
        _locallyEnrolledCourseIds.add(c.id);
      }

      _enrolledCourses.clear();
      _enrolledCourses.addAll(mergedMap.values);
      await _saveEnrolledCoursesToStorage();

      _learningState = UiSuccess(List.unmodifiable(_enrolledCourses));
    } catch (e) {
      if (_enrolledCourses.isNotEmpty) {
        _learningState = UiSuccess(List.unmodifiable(_enrolledCourses));
      } else {
        _learningState = const UiError(ServerFailure('No se pudo cargar tu padrón de cursos'));
      }
    } finally {
      notifyListeners();
    }
  }

  void selectCategory(String category) {
    _selectedCategory = category;
    notifyListeners();
    fetchCourses(force: true);
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
    fetchCourses(force: true);
  }

  Future<void> markCourseAsEnrolled(String courseId, {Course? course, String? code}) async {
    _locallyEnrolledCourseIds.add(courseId);

    Course? targetCourse = course;
    if (targetCourse == null && _state is UiSuccess<List<Course>>) {
      final allCourses = (_state as UiSuccess<List<Course>>).data;
      final match = allCourses.where((c) => c.id == courseId);
      if (match.isNotEmpty) {
        targetCourse = match.first;
      }
    }
    if (targetCourse == null) {
      final matchEnrolled = _enrolledCourses.where((c) => c.id == courseId);
      if (matchEnrolled.isNotEmpty) {
        targetCourse = matchEnrolled.first;
      }
    }

    if (targetCourse != null) {
      final enrolledCourse = Course(
        id: targetCourse.id,
        title: targetCourse.title,
        description: targetCourse.description,
        category: targetCourse.category,
        instructor: targetCourse.instructor,
        price: targetCourse.price,
        rating: targetCourse.rating,
        studentsCount: targetCourse.studentsCount,
        duration: targetCourse.duration,
        thumbnail: targetCourse.thumbnail,
        level: targetCourse.level,
        lessonsCount: targetCourse.lessonsCount,
        isEnrolled: true,
        progressPercentage: targetCourse.progressPercentage,
      );

      final idx = _enrolledCourses.indexWhere((c) => c.id == courseId);
      if (idx >= 0) {
        _enrolledCourses[idx] = enrolledCourse;
      } else {
        _enrolledCourses.add(enrolledCourse);
      }
    }

    _learningState = UiSuccess(List.unmodifiable(_enrolledCourses));
    await _saveEnrolledCoursesToStorage();
    notifyListeners();

    // Sincronizar de inmediato con el backend Laravel si hay conexiÃ³n/sesiÃ³n
    try {
      await _getCoursesUseCase.enrollCourse(courseId, code: code);
    } catch (_) {}

    await fetchLearningCourses(force: true);
  }

  Future<void> clearEnrolledCourses() async {
    _enrolledCourses.clear();
    _locallyEnrolledCourseIds.clear();
    _learningState = const UiInitial();
    notifyListeners();
  }

  bool isCourseEnrolled(String courseId) {
    return _locallyEnrolledCourseIds.contains(courseId) ||
        _enrolledCourses.any((c) => c.id == courseId);
  }

  void updateCourseProgress(String courseId, double progressPercentage) {
    _courseProgressMemoryCache[courseId] = progressPercentage;
    _storage.write(
      key: 'course_progress_percentage_$courseId',
      value: progressPercentage.toString(),
    );

    bool updated = false;
    for (int i = 0; i < _enrolledCourses.length; i++) {
      if (_enrolledCourses[i].id == courseId) {
        final old = _enrolledCourses[i];
        _enrolledCourses[i] = Course(
          id: old.id,
          title: old.title,
          description: old.description,
          category: old.category,
          instructor: old.instructor,
          price: old.price,
          rating: old.rating,
          studentsCount: old.studentsCount,
          duration: old.duration,
          thumbnail: old.thumbnail,
          level: old.level,
          lessonsCount: old.lessonsCount,
          isEnrolled: true,
          progressPercentage: progressPercentage,
        );
        updated = true;
        break;
      }
    }
    if (updated) {
      _saveEnrolledCoursesToStorage();
      notifyListeners();
    }
  }

  void updateCourseLessonsCount(String courseId, int lessonsCount) {
    if (lessonsCount <= 0) return;
    bool changed = false;

    for (int i = 0; i < _enrolledCourses.length; i++) {
      if (_enrolledCourses[i].id == courseId && _enrolledCourses[i].lessonsCount != lessonsCount) {
        _enrolledCourses[i] = _enrolledCourses[i].copyWith(lessonsCount: lessonsCount);
        changed = true;
      }
    }

    if (_state is UiSuccess<List<Course>>) {
      final currentList = (_state as UiSuccess<List<Course>>).data;
      final updatedList = currentList.map((c) {
        if (c.id == courseId && c.lessonsCount != lessonsCount) {
          changed = true;
          return c.copyWith(lessonsCount: lessonsCount);
        }
        return c;
      }).toList();
      if (changed) {
        _state = UiSuccess(updatedList);
      }
    }

    if (changed) {
      _saveEnrolledCoursesToStorage();
      notifyListeners();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _connectivityTimer?.cancel();
    super.dispose();
  }
}
