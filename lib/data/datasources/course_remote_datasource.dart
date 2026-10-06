import 'dart:convert';
import 'dart:io';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/constants/api_constants.dart';
import '../../core/network/api_client.dart';
import '../models/course_model.dart';
import '../models/syllabus_model.dart';
import '../models/quiz_model.dart';
import '../../domain/entities/quiz.dart';

abstract class CourseRemoteDataSource {
  bool get isOffline;
  void setOffline(bool offline);
  Future<List<CourseModel>> fetchCourses({String? category, String? search});
  Future<CourseModel> fetchCourseDetail(dynamic courseId);
  Future<List<CategoryModel>> fetchCategories();
  Future<List<CourseModel>> fetchLearningCourses();
  Future<List<SyllabusSectionModel>> fetchCourseSyllabi(dynamic courseId);
  Future<Map<String, dynamic>> fetchCourseProgress(dynamic courseId);
  Future<bool> updateLessonProgress(dynamic lessonId, {required bool completed, int timeSpentSeconds = 0});
  Future<bool> enrollCourse(dynamic courseId, {String? code});
}

class CourseRemoteDataSourceImpl implements CourseRemoteDataSource {
  final ApiClient _apiClient;
  final FlutterSecureStorage _storage;
  bool _isOffline = false;

  CourseRemoteDataSourceImpl({ApiClient? apiClient, FlutterSecureStorage? storage})
      : _apiClient = apiClient ?? ApiClient(),
        _storage = storage ?? const FlutterSecureStorage();

  @override
  bool get isOffline => _isOffline;

  @override
  void setOffline(bool offline) {
    _isOffline = offline;
  }

  bool _isConnectionError(dynamic e) {
    if (e is ApiConnectionException) return true;
    if (e is SocketException) return true;
    if (e is ApiException) {
      return e.statusCode == null || e.statusCode! >= 500;
    }
    return false;
  }

  String _normalize(String s) {
    return s
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ñ', 'n')
        .trim();
  }

  bool _matchesCategory(String courseCategory, String filterCategory) {
    if (filterCategory == 'Todas' || filterCategory == 'Todos' || filterCategory.isEmpty) return true;
    final c = _normalize(courseCategory);
    final f = _normalize(filterCategory);
    if (c == f) return true;
    if (c.contains(f) || f.contains(c)) return true;
    if (f.contains('tecno') && (c.contains('tecno') || c.contains('desarrollo') || c.contains('program') || c.contains('software') || c.contains('ciber') || c.contains('web'))) return true;
    if (f.contains('seguridad') && c.contains('seguridad')) return true;
    if (f.contains('negocio') && (c.contains('negocio') || c.contains('admin') || c.contains('finanz') || c.contains('pyme'))) return true;
    if (f.contains('salud') && (c.contains('salud') || c.contains('prevenc') || c.contains('primeros') || c.contains('brigada'))) return true;
    return false;
  }

  List<CourseModel> _filterCourses(List<CourseModel> list, {String? category, String? search}) {
    var filtered = list;
    if (category != null && category.isNotEmpty && category != 'Todos' && category != 'Todas') {
      filtered = filtered.where((c) => _matchesCategory(c.category, category)).toList();
    }
    if (search != null && search.trim().isNotEmpty) {
      final s = _normalize(search);
      filtered = filtered.where((c) {
        return _normalize(c.title).contains(s) ||
            _normalize(c.description).contains(s) ||
            _normalize(c.instructor).contains(s) ||
            _normalize(c.category).contains(s);
      }).toList();
    }
    return filtered;
  }

  @override
  Future<List<CourseModel>> fetchCourses({String? category, String? search}) async {
    try {
      final Map<String, dynamic> params = {};
      if (category != null && category.isNotEmpty && category != 'Todos') {
        params['category'] = category;
      }
      if (search != null && search.isNotEmpty) {
        params['search'] = search;
      }

      final response = await _apiClient.get(
        ApiConstants.courses,
        queryParameters: params.isNotEmpty ? params : null,
      );

      final dynamic data = response.data;
      List rawList = [];
      if (data is List) {
        rawList = data;
      } else if (data is Map) {
        rawList = data['data'] as List? ?? data['courses'] as List? ?? [];
      }

      if (rawList.isNotEmpty) {
        _isOffline = false;
        try {
          await _storage.write(
            key: 'user_courses_catalog_cache',
            value: jsonEncode(rawList),
          );
        } catch (_) {}
        final allCourses = rawList.map((json) => CourseModel.fromJson(json as Map<String, dynamic>)).toList();
        return _filterCourses(allCourses, category: category, search: search);
      }
      _isOffline = false;
      return await _loadCachedCoursesOrFallback(category: category, search: search);
    } catch (e) {
      if (_isConnectionError(e)) {
        _isOffline = true;
      }
      return await _loadCachedCoursesOrFallback(category: category, search: search);
    }
  }

  Future<List<CourseModel>> _loadCachedCoursesOrFallback({String? category, String? search}) async {
    List<CourseModel> list = [];
    try {
      final cached = await _storage.read(key: 'user_courses_catalog_cache');
      if (cached != null && cached.isNotEmpty) {
        final List decoded = jsonDecode(cached);
        if (decoded.isNotEmpty) {
          list = decoded.map((json) => CourseModel.fromJson(json as Map<String, dynamic>)).toList();
        }
      }
    } catch (_) {}

    if (list.isEmpty) {
      list = _fallbackCourses();
    }
    return _filterCourses(list, category: category, search: search);
  }

  @override
  Future<CourseModel> fetchCourseDetail(dynamic courseId) async {
    try {
      final response = await _apiClient.get('${ApiConstants.courses}/$courseId');
      final dynamic data = response.data;
      final Map<String, dynamic> map = (data is Map && data.containsKey('data'))
          ? data['data'] as Map<String, dynamic>
          : data as Map<String, dynamic>;
      _isOffline = false;
      return CourseModel.fromJson(map);
    } catch (e) {
      if (_isConnectionError(e)) {
        _isOffline = true;
      }
      final list = _fallbackCourses();
      return list.firstWhere(
        (c) => c.id == courseId.toString(),
        orElse: () => list.first,
      );
    }
  }

  @override
  Future<List<CategoryModel>> fetchCategories() async {
    try {
      final response = await _apiClient.get(ApiConstants.categories);
      final dynamic data = response.data;
      List rawList = [];
      if (data is List) {
        rawList = data;
      } else if (data is Map) {
        rawList = data['data'] as List? ?? data['categories'] as List? ?? [];
      }

      if (rawList.isNotEmpty) {
        _isOffline = false;
        return rawList.map((json) => CategoryModel.fromJson(json as Map<String, dynamic>)).toList();
      }
      _isOffline = false;
      return _fallbackCategories();
    } catch (e) {
      if (_isConnectionError(e)) {
        _isOffline = true;
      }
      return _fallbackCategories();
    }
  }

  @override
  Future<List<CourseModel>> fetchLearningCourses() async {
    try {
      final token = await _apiClient.getToken();
      if (token == null || token.isEmpty) {
        return const [];
      }

      final response = await _apiClient.get(ApiConstants.learningCourses);
      final dynamic data = response.data;
      List rawList = [];
      if (data is List) {
        rawList = data;
      } else if (data is Map) {
        rawList = data['data'] as List? ?? data['courses'] as List? ?? [];
      }

      if (rawList.isNotEmpty) {
        _isOffline = false;
        return rawList.map((json) => CourseModel.fromJson(json as Map<String, dynamic>)).toList();
      }
      _isOffline = false;
      return const [];
    } catch (e) {
      if (_isConnectionError(e)) {
        _isOffline = true;
      }
      return const [];
    }
  }

  @override
  Future<List<SyllabusSectionModel>> fetchCourseSyllabi(dynamic courseId) async {
    try {
      final response = await _apiClient.get(ApiConstants.courseSyllabi(courseId));
      final dynamic data = response.data;
      List rawList = [];
      if (data is List) {
        rawList = data;
      } else if (data is Map) {
        rawList = data['data'] as List? ?? data['syllabi'] as List? ?? [];
      }

      if (rawList.isNotEmpty) {
        _isOffline = false;
        try {
          final encoded = jsonEncode(rawList);
          await _storage.write(
            key: 'user_course_syllabi_cache_$courseId',
            value: encoded,
          );
          final cleanId = courseId.toString().replaceAll(RegExp(r'[^0-9]'), '');
          if (cleanId.isNotEmpty && cleanId != courseId.toString()) {
            await _storage.write(
              key: 'user_course_syllabi_cache_$cleanId',
              value: encoded,
            );
          }
        } catch (_) {}
        final parsed = rawList.map((json) => SyllabusSectionModel.fromJson(json as Map<String, dynamic>)).toList();
        return _enrichSyllabiWithReadingAndResources(parsed, courseId);
      }
      _isOffline = false;
      return await _loadCachedSyllabiOrFallback(courseId);
    } catch (e) {
      if (_isConnectionError(e)) {
        _isOffline = true;
      }
      return await _loadCachedSyllabiOrFallback(courseId);
    }
  }

  Future<List<SyllabusSectionModel>> _loadCachedSyllabiOrFallback(dynamic courseId) async {
    try {
      String? cached = await _storage.read(key: 'user_course_syllabi_cache_$courseId');
      if (cached == null || cached.isEmpty) {
        final cleanId = courseId.toString().replaceAll(RegExp(r'[^0-9]'), '');
        if (cleanId.isNotEmpty) {
          cached = await _storage.read(key: 'user_course_syllabi_cache_$cleanId');
        }
      }
      if (cached != null && cached.isNotEmpty) {
        final List decoded = jsonDecode(cached);
        if (decoded.isNotEmpty) {
          final parsed = decoded.map((json) => SyllabusSectionModel.fromJson(json as Map<String, dynamic>)).toList();
          return _enrichSyllabiWithReadingAndResources(parsed, courseId);
        }
      }
    } catch (_) {}
    return _fallbackSyllabi(courseId);
  }

  @override
  Future<Map<String, dynamic>> fetchCourseProgress(dynamic courseId) async {
    try {
      final response = await _apiClient.get(ApiConstants.courseProgress(courseId));
      final dynamic data = response.data;
      if (data is Map<String, dynamic>) {
        _isOffline = false;
        final progressMap = data['progress'] is Map ? data['progress'] as Map<String, dynamic> : data;
        return {
          'progress_percentage': (progressMap['progress_percentage'] as num?)?.toDouble() ?? 0.0,
          'completed_lessons_count': (progressMap['completed_lessons_count'] as num?)?.toInt() ?? 0,
        };
      }
      return {'progress_percentage': 0.0, 'completed_lessons_count': 0};
    } catch (e) {
      if (_isConnectionError(e)) {
        _isOffline = true;
      }
      return {'progress_percentage': 0.0, 'completed_lessons_count': 0};
    }
  }

  @override
  Future<bool> updateLessonProgress(dynamic lessonId, {required bool completed, int timeSpentSeconds = 0}) async {
    try {
      final response = await _apiClient.post(
        ApiConstants.lessonProgress(lessonId),
        data: {
          'completed': completed,
          'time_spent_seconds': timeSpentSeconds,
        },
      );
      _isOffline = false;
      return response.statusCode != null && response.statusCode! < 400;
    } catch (e) {
      if (_isConnectionError(e)) {
        _isOffline = true;
      }
      return true; // Optimistic update
    }
  }

  @override
  Future<bool> enrollCourse(dynamic courseId, {String? code}) async {
    try {
      final response = await _apiClient.post(
        ApiConstants.enrollCourse(courseId),
        data: {
          if (code != null) 'code': code,
          'source': code != null ? 'code' : 'direct',
        },
      );
      _isOffline = false;
      return response.statusCode != null && response.statusCode! < 400;
    } catch (_) {
      return false;
    }
  }

  List<SyllabusSectionModel> _enrichSyllabiWithReadingAndResources(List<SyllabusSectionModel> sections, dynamic courseId) {
    if (sections.isEmpty) return _fallbackSyllabi(courseId);

    final cleanId = int.tryParse(courseId.toString().replaceAll(RegExp(r'[^0-9]'), '')) ?? 1;
    final dynamicReadingId = 999000 + cleanId;

    final bool hasReading = sections.any((s) => s.lessons.any((l) => l.isReading));

    final readingLesson = LessonModel(
      id: dynamicReadingId,
      syllabusId: sections.first.id,
      title: 'Guía Metodológica y Estándares de Seguridad 2026 (Lectura)',
      description: '''# Guía de Fundamentos y Normativa Internacional 2026

Bienvenido a la sesión de fundamentación teórica y lectura analítica de Master Academy. Esta clase ha sido estructurada específicamente para profundizar en conceptos técnicos y regulatorios sin requerir reproducción audiovisual.

### 📌 1. Marco Normativo y Regulaciones
En el panorama tecnológico contemporáneo, la seguridad de la información y la gestión de procesos requieren marcos de referencia de vanguardia:
- **ISO/IEC 27001:2022**: Sistema de gestión de la seguridad de la información y controles de acceso perimetral.
- **NIST Cybersecurity Framework 2.0**: Funciones estratégicas de Gobierno, Identificación, Protección, Detección, Respuesta y Recuperación.
- **OWASP Top 10 (2025/2026)**: Mitigación de inyecciones, fallas criptográficas y desconfiguración de seguridad en APIs y microservicios.

### 🛡️ 2. Principios de Arquitectura Zero Trust
El modelo de confianza cero establece que ninguna entidad, dentro o fuera del perímetro de red, debe considerarse confiable por defecto:
1. **Verificación explícita**: Cada solicitud debe autenticarse y autorizarse formalmente mediante tokens de corta duración.
2. **Menor privilegio (PoLP)**: Limitar el acceso de usuarios con permisos mínimos necesarios y ventanas temporales auditadas.
3. **Asumir brechas**: Minimizar el radio de impacto segmentando redes y cifrando todas las comunicaciones internas de extremo a extremo.

### 📋 3. Checklist de Implementación Operativa
- Auditar y rotar credenciales API y firmas criptográficas periódicamente.
- Implementar cifrado TLS 1.3 en tránsito y AES-256 en reposo para datos sensibles.
- Validar y sanitizar entradas en pasarelas perimetrales y capas de servicio.
- Realizar pruebas de penetración continuas y auditorías de código estático (SAST).

Descarga la guía técnica y el checklist adjuntos en la pestaña **"Recursos y Notas"** para realizar la validación de cumplimiento en tus proyectos profesionales.''',
      videoUrl: null,
      durationSeconds: 420, // 7 min de lectura
      order: 1,
      isCompleted: false,
      isFreePreview: true,
      type: 'reading',
      resources: const [
        LessonResourceModel(
          id: 801,
          title: 'Manual de Metodología y Buenas Prácticas 2026 (PDF)',
          fileUrl: 'https://raw.githubusercontent.com/masteracademy/resources/main/manual_seguridad_2026.pdf',
          fileType: 'pdf',
        ),
        LessonResourceModel(
          id: 802,
          title: 'Checklist de Validación Normativa y Auditoría (XLSX)',
          fileUrl: 'https://raw.githubusercontent.com/masteracademy/resources/main/checklist_normativa.xlsx',
          fileType: 'xlsx',
        ),
      ],
    );

    final fallbackList = _fallbackSyllabi(courseId);

    final updatedSections = <SyllabusSectionModel>[];
    for (int i = 0; i < sections.length; i++) {
      final s = sections[i];

      // Vincular evaluación formativa si la sección del servidor no trae una
      Quiz? moduleQuiz = s.evaluation;
      if (moduleQuiz == null && i < fallbackList.length && !fallbackList[i].isFinalCertification) {
        moduleQuiz = fallbackList[i].evaluation;
      }
      if (moduleQuiz == null && !s.isFinalCertification) {
        moduleQuiz = QuizModel(
          id: 'quiz-mod-${cleanId}-${s.id}',
          title: 'Evaluación Formativa: ${s.title}',
          description: 'Valida los conceptos técnicos y competencias operativas abordadas en este módulo.',
          passingScore: 70,
          isFinal: false,
          totalPoints: 100,
          durationMinutes: 15,
          courseId: cleanId,
          moduleId: s.id,
          questions: const [
            QuizQuestionModel(
              id: 'q-mod-gen-1',
              text: '¿Cuál es el beneficio de asimilar las metodologías presentadas en este módulo formativo?',
              weightPoints: 50,
              options: [
                QuizOptionModel(id: 'omg1-1', text: 'Aplicar criterios técnicos rigurosos que elevan la calidad y resuelven casos prácticos.', isCorrect: true),
                QuizOptionModel(id: 'omg1-2', text: 'Omitir la fase de pruebas y validación funcional.', isCorrect: false),
                QuizOptionModel(id: 'omg1-3', text: 'Depender únicamente de herramientas sin supervisión técnica.', isCorrect: false),
                QuizOptionModel(id: 'omg1-4', text: 'Reducir la seguridad de los procesos.', isCorrect: false),
              ],
              explanation: 'La asimilación de metodologías sólidas garantiza estándares profesionales elevados en la ejecución.',
            ),
            QuizQuestionModel(
              id: 'q-mod-gen-2',
              text: 'En el ejercicio profesional, ¿cómo se consolida el aprendizaje de los conceptos clave?',
              weightPoints: 50,
              options: [
                QuizOptionModel(id: 'omg2-1', text: 'Mediante la ejecución metódica de casos de uso y la revisión de material complementario.', isCorrect: true),
                QuizOptionModel(id: 'omg2-2', text: 'Memorizando respuestas sin comprender la lógica fundamental.', isCorrect: false),
                QuizOptionModel(id: 'omg2-3', text: 'Descartando la documentación técnica oficial.', isCorrect: false),
                QuizOptionModel(id: 'omg2-4', text: 'Ignorando las mejores prácticas de la industria.', isCorrect: false),
              ],
              explanation: 'La práctica orientada a proyectos y casos reales consolida las competencias transferibles al entorno laboral.',
            ),
          ],
        );
      }

      if (i == 0 && !hasReading) {
        final updatedLessons = [
          ...s.lessons,
          LessonModel(
            id: readingLesson.id,
            syllabusId: s.id,
            title: readingLesson.title,
            description: readingLesson.description,
            videoUrl: readingLesson.videoUrl,
            durationSeconds: readingLesson.durationSeconds,
            order: s.lessons.length + 1,
            isCompleted: readingLesson.isCompleted,
            isFreePreview: readingLesson.isFreePreview,
            type: readingLesson.type,
            resources: readingLesson.resources,
          ),
        ];
        updatedSections.add(
          SyllabusSectionModel(
            id: s.id,
            title: s.title,
            order: s.order,
            lessons: updatedLessons,
            evaluation: moduleQuiz,
            isFinalCertification: s.isFinalCertification,
          ),
        );
      } else {
        final updatedLessons = s.lessons.map((l) {
          if (l.resources.isEmpty && l.order <= 2) {
            return LessonModel(
              id: l.id,
              syllabusId: l.syllabusId,
              title: l.title,
              description: l.description,
              videoUrl: l.videoUrl,
              durationSeconds: l.durationSeconds,
              order: l.order,
              isCompleted: l.isCompleted,
              isFreePreview: l.isFreePreview,
              type: l.type,
              resources: const [
                LessonResourceModel(
                  id: 803,
                  title: 'Material de Apoyo y Guía Práctica (PDF)',
                  fileUrl: 'https://raw.githubusercontent.com/masteracademy/resources/main/material_apoyo.pdf',
                  fileType: 'pdf',
                ),
              ],
            );
          }
          return l;
        }).toList();

        updatedSections.add(
          SyllabusSectionModel(
            id: s.id,
            title: s.title,
            order: s.order,
            lessons: updatedLessons,
            evaluation: moduleQuiz,
            isFinalCertification: s.isFinalCertification,
          ),
        );
      }
    }

    // Incorporar siempre el Módulo Final de Certificación si no está presente
    final bool hasFinalCert = updatedSections.any((s) => s.isFinalCertification);
    if (!hasFinalCert) {
      final SyllabusSectionModel finalSection;
      final fallbackCert = fallbackList.where((s) => s.isFinalCertification).toList();
      if (fallbackCert.isNotEmpty) {
        finalSection = fallbackCert.first;
      } else {
        finalSection = SyllabusSectionModel(
          id: 99990 + cleanId,
          title: 'Módulo Final: Evaluación para Diploma Oficial',
          order: updatedSections.length + 1,
          isFinalCertification: true,
          evaluation: QuizModel(
            id: 'quiz-final-cert-$cleanId',
            title: 'Examen Global de Certificación y Acreditación',
            description: 'Evaluación integradora oficial obligatoria para la acreditación de competencias y expedición del diploma oficial.',
            passingScore: 75,
            isFinal: true,
            totalPoints: 100,
            durationMinutes: 25,
            courseId: cleanId,
            moduleId: 99990 + cleanId,
            questions: const [
              QuizQuestionModel(
                id: 'q-generic-cert-1',
                text: '¿Cuál es el objetivo primordial de aplicar estándares y protocolos normativos en el entorno profesional?',
                weightPoints: 50,
                options: [
                  QuizOptionModel(id: 'og1-1', text: 'Garantizar la calidad operativa, prevenir riesgos y asegurar el cumplimiento continuo.', isCorrect: true),
                  QuizOptionModel(id: 'og1-2', text: 'Incrementar los costos operativos sin justificación.', isCorrect: false),
                  QuizOptionModel(id: 'og1-3', text: 'Evitar el uso de tecnologías modernas.', isCorrect: false),
                  QuizOptionModel(id: 'og1-4', text: 'Prescindir de auditorías y revisiones periódicas.', isCorrect: false),
                ],
                explanation: 'La aplicación rigurosa de estándares optimiza la operación y asegura la continuidad y resiliencia.',
              ),
              QuizQuestionModel(
                id: 'q-generic-cert-2',
                text: 'Para asegurar una acreditación profesional formal con validez oficial, ¿qué elemento es imprescindible?',
                weightPoints: 50,
                options: [
                  QuizOptionModel(id: 'og2-1', text: 'Comprobar competencias mediante evaluaciones integradoras verificables con código hash / UUID.', isCorrect: true),
                  QuizOptionModel(id: 'og2-2', text: 'Asistir únicamente sin validar conocimientos.', isCorrect: false),
                  QuizOptionModel(id: 'og2-3', text: 'Ignorar las evaluaciones prácticas y teóricas.', isCorrect: false),
                  QuizOptionModel(id: 'og2-4', text: 'No realizar ningún registro de avance formativo.', isCorrect: false),
                ],
                explanation: 'La verificación criptográfica o UUID respalda la autenticidad y el rigor del diploma emitido.',
              ),
            ],
          ),
        );
      }
      updatedSections.add(finalSection);
    }

    return updatedSections;
  }

  List<CourseModel> _fallbackCourses() {
    return const [
      CourseModel(
        id: '1',
        title: 'Desarrollo Web Fullstack & Ciberseguridad',
        description: 'Aprende arquitecturas web modernas, APIs seguras y mitigación de vulnerabilidades OWASP para entornos corporativos.',
        category: 'Tecnologías e información',
        instructor: 'Víctor Atala Lagunas',
        price: 399.0,
        rating: 4.9,
        studentsCount: 0,
        duration: '28 horas',
        thumbnail: 'https://images.unsplash.com/photo-1550751827-4bd374c3f58b?w=600',
        level: 'Intermedio',
        lessonsCount: 5,
        isEnrolled: true,
        progressPercentage: 0.0,
      ),
      CourseModel(
        id: '2',
        title: 'Normativas Oficiales de Seguridad Industrial (STPS)',
        description: 'Lineamientos indispensables de la STPS para la prevención de accidentes laborales y comisiones de seguridad.',
        category: 'Seguridad Industrial',
        instructor: 'Víctor Atala Lagunas',
        price: 450.0,
        rating: 4.8,
        studentsCount: 0,
        duration: '16 horas',
        thumbnail: 'https://images.unsplash.com/photo-1504307651254-35680f356dfd?w=600',
        level: 'Básico',
        lessonsCount: 3,
        isEnrolled: false,
        progressPercentage: 0.0,
      ),
      CourseModel(
        id: '3',
        title: 'Primeros Auxilios y Brigadas de Emergencia',
        description: 'Capacitación práctica para atención de emergencias médicas, RCP y soporte vital básico en centros laborales.',
        category: 'Salud y Prevención',
        instructor: 'Víctor Atala Lagunas',
        price: 299.0,
        rating: 4.9,
        studentsCount: 0,
        duration: '12 horas',
        thumbnail: 'https://images.unsplash.com/photo-1576091160399-112ba8d25d1d?w=600',
        level: 'Todos los niveles',
        lessonsCount: 2,
        isEnrolled: false,
        progressPercentage: 0.0,
      ),
      CourseModel(
        id: '4',
        title: 'Gestión Financiera y Rentabilidad para PyMEs',
        description: 'Domina el análisis financiero práctico para tomar decisiones fundamentadas en datos reales y maximizar la rentabilidad.',
        category: 'Negocios',
        instructor: 'Víctor Atala Lagunas',
        price: 499.0,
        rating: 4.7,
        studentsCount: 0,
        duration: '20 horas',
        thumbnail: 'https://images.unsplash.com/photo-1460925895917-afdab827c52f?w=600',
        level: 'Avanzado',
        lessonsCount: 2,
        isEnrolled: false,
        progressPercentage: 0.0,
      ),
    ];
  }

  List<CategoryModel> _fallbackCategories() {
    return const [
      CategoryModel(id: 1, name: 'Tecnologías e información', slug: 'tecnologias-e-informacion', icon: 'terminal', coursesCount: 1),
      CategoryModel(id: 2, name: 'Seguridad Industrial', slug: 'seguridad-industrial', icon: 'security', coursesCount: 1),
      CategoryModel(id: 3, name: 'Negocios', slug: 'negocios', icon: 'business', coursesCount: 1),
      CategoryModel(id: 4, name: 'Salud y Prevención', slug: 'salud-y-prevencion', icon: 'health', coursesCount: 1),
    ];
  }

  List<SyllabusSectionModel> _fallbackSyllabi(dynamic courseId) {
    final idStr = courseId?.toString() ?? '1';
    final cleanId = idStr.replaceAll(RegExp(r'[^0-9]'), '');
    final fallbackReadingId = 999000 + (int.tryParse(cleanId) ?? 1);

    if (cleanId == '2') {
      return const [
        SyllabusSectionModel(
          id: 7,
          title: 'Módulo 1: Identificación y Control de Riesgos',
          order: 1,
          lessons: [
            LessonModel(
              id: 8,
              syllabusId: 7,
              title: 'Matriz de Riesgos Laborales',
              description: 'Metodología para identificar peligros potenciales en maquinaria y áreas de producción.',
              videoUrl: 'https://interactive-examples.mdn.mozilla.net/media/cc0-videos/flower.mp4',
              durationSeconds: 900,
              order: 1,
              isCompleted: false,
              isFreePreview: true,
              type: 'video',
            ),
            LessonModel(
              id: 9,
              syllabusId: 7,
              title: 'Uso y Conservación del EPP',
              description: 'Selección y mantenimiento del equipo de protección personal según la NOM-017.',
              videoUrl: 'https://interactive-examples.mdn.mozilla.net/media/cc0-videos/flower.mp4',
              durationSeconds: 1200,
              order: 2,
              isCompleted: false,
              isFreePreview: false,
              type: 'video',
            ),
          ],
        ),
      ];
    }

    if (cleanId == '3') {
      return const [
        SyllabusSectionModel(
          id: 10,
          title: 'Módulo 1: Soporte Vital Básico',
          order: 1,
          lessons: [
            LessonModel(
              id: 11,
              syllabusId: 10,
              title: 'Evaluación Primaria de la Víctima (C-A-B)',
              description: 'Protocolo inicial de atención ante una persona inconsciente o con traumatismo.',
              videoUrl: 'https://interactive-examples.mdn.mozilla.net/media/cc0-videos/flower.mp4',
              durationSeconds: 800,
              order: 1,
              isCompleted: false,
              isFreePreview: true,
              type: 'video',
            ),
          ],
        ),
      ];
    }

    if (cleanId == '4') {
      return const [
        SyllabusSectionModel(
          id: 20,
          title: 'Módulo 1: Fundamentos y Flujo de Caja',
          order: 1,
          lessons: [
            LessonModel(
              id: 21,
              syllabusId: 20,
              title: 'Lección 1: Diagnóstico Financiero',
              description: 'Conceptos clave para evaluar la salud de la empresa.',
              videoUrl: 'https://interactive-examples.mdn.mozilla.net/media/cc0-videos/flower.mp4',
              durationSeconds: 1100,
              order: 1,
              isCompleted: false,
              isFreePreview: true,
              type: 'video',
            ),
          ],
        ),
      ];
    }

    // Default / Course 1: Desarrollo Web Fullstack & Ciberseguridad
    return [
      SyllabusSectionModel(
        id: 22,
        title: 'Módulo 1: Arquitectura y Seguridad en APIs',
        order: 1,
        evaluation: const QuizModel(
          id: 'quiz-mod-1',
          title: 'Evaluación Formativa Módulo 1: Arquitectura y Seguridad en APIs',
          description: 'Valida los conceptos clave de Zero Trust, defensa en profundidad y autenticación JWT con control de acceso.',
          passingScore: 70,
          isFinal: false,
          totalPoints: 100,
          durationMinutes: 15,
          courseId: 1,
          moduleId: 22,
          questions: [
            QuizQuestionModel(
              id: 'q1-1',
              text: 'En una arquitectura con modelo Zero Trust, ¿cuál de las siguientes afirmaciones es correcta?',
              weightPoints: 50,
              options: [
                QuizOptionModel(id: 'opt1-1', text: 'Ningún usuario ni microservicio dentro o fuera del perímetro debe considerarse confiable por defecto.', isCorrect: true),
                QuizOptionModel(id: 'opt1-2', text: 'Los servicios dentro de la red corporativa deben prescindir de autenticación mutua (mTLS) para reducir latencia.', isCorrect: false),
                QuizOptionModel(id: 'opt1-3', text: 'Las contraseñas de administradores deben guardarse sin salar en variables de entorno.', isCorrect: false),
                QuizOptionModel(id: 'opt1-4', text: 'El control de acceso perimetral en firewall es suficiente y exime de validar tokens en cada servicio.', isCorrect: false),
              ],
              explanation: 'Zero Trust exige autenticación y autorización explícita para cada solicitud, sin importar su origen.',
            ),
            QuizQuestionModel(
              id: 'q1-2',
              text: '¿Por qué los tokens JWT de acceso (Access Tokens) deben tener un tiempo de vida corto (ej. 15 minutos)?',
              weightPoints: 50,
              options: [
                QuizOptionModel(id: 'opt2-1', text: 'Para limitar la ventana de exposición en caso de intercepción o robo del token.', isCorrect: true),
                QuizOptionModel(id: 'opt2-2', text: 'Porque la librería JSON Web Token no admite firmas con duración superior a una hora.', isCorrect: false),
                QuizOptionModel(id: 'opt2-3', text: 'Para forzar al usuario a ingresar su contraseña manualmente cada 15 minutos.', isCorrect: false),
                QuizOptionModel(id: 'opt2-4', text: 'Para reducir el tamaño de los encabezados HTTP en peticiones REST.', isCorrect: false),
              ],
              explanation: 'Un tiempo de expiración corto reduce drásticamente el impacto de un token comprometido, complementado por Refresh Tokens rotativos.',
            ),
          ],
        ),
        lessons: [
          LessonModel(
            id: 23,
            syllabusId: 22,
            title: 'Introducción y Principios de Diseño Seguro',
            description: 'Comprende el modelo Zero Trust y los principios de defensa en profundidad para aplicaciones web.',
            videoUrl: 'https://youtu.be/RVnlbGL6YJk?si=PMUAE0zRlva_jPLJ',
            durationSeconds: 624,
            order: 1,
            isCompleted: false,
            isFreePreview: true,
            type: 'video',
            resources: const [
              LessonResourceModel(
                id: 801,
                title: 'Manual de Metodología y Buenas Prácticas 2026 (PDF)',
                fileUrl: 'https://raw.githubusercontent.com/masteracademy/resources/main/manual_seguridad_2026.pdf',
                fileType: 'pdf',
              ),
            ],
          ),
          LessonModel(
            id: 24,
            syllabusId: 22,
            title: 'Tokens JWT y Control de Acceso RBAC',
            description: 'Implementación de roles y permisos con expiración y rotación de tokens seguros.',
            videoUrl: 'https://interactive-examples.mdn.mozilla.net/media/cc0-videos/flower.mp4',
            durationSeconds: 850,
            order: 2,
            isCompleted: false,
            isFreePreview: false,
            type: 'video',
          ),
          LessonModel(
            id: fallbackReadingId,
            syllabusId: 22,
            title: 'Guía Metodológica y Estándares de Seguridad 2026 (Lectura)',
            description: 'Lectura integral sobre buenas prácticas, regulaciones ISO 27001 y checklist de cumplimiento operativo.',
            videoUrl: null,
            durationSeconds: 420,
            order: 3,
            isCompleted: false,
            isFreePreview: true,
            type: 'reading',
            resources: [
              LessonResourceModel(
                id: 802,
                title: 'Checklist de Validación Normativa y Auditoría (XLSX)',
                fileUrl: 'https://raw.githubusercontent.com/masteracademy/resources/main/checklist_normativa.xlsx',
                fileType: 'xlsx',
              ),
            ],
          ),
        ],
      ),
      SyllabusSectionModel(
        id: 25,
        title: 'Módulo 2: Bases de Datos y Cifrado',
        order: 2,
        evaluation: const QuizModel(
          id: 'quiz-mod-2',
          title: 'Evaluación Formativa Módulo 2: Cifrado y Bases de Datos',
          description: 'Evalúa el modelado relacional ACID y las técnicas criptográficas de cifrado simétrico y asimétrico.',
          passingScore: 70,
          isFinal: false,
          totalPoints: 100,
          durationMinutes: 15,
          courseId: 1,
          moduleId: 25,
          questions: [
            QuizQuestionModel(
              id: 'q2-1',
              text: '¿Cuál propiedad de las transacciones ACID asegura que los cambios confirmados permanezcan guardados incluso ante fallos de energía?',
              weightPoints: 50,
              options: [
                QuizOptionModel(id: 'opt21-1', text: 'Durabilidad (Durability)', isCorrect: true),
                QuizOptionModel(id: 'opt21-2', text: 'Aislamiento (Isolation)', isCorrect: false),
                QuizOptionModel(id: 'opt21-3', text: 'Atomicidad (Atomicity)', isCorrect: false),
                QuizOptionModel(id: 'opt21-4', text: 'Consistencia (Consistency)', isCorrect: false),
              ],
              explanation: 'La Durabilidad garantiza que una transacción completada y persistida en disco no se pierda ante caídas del servidor.',
            ),
            QuizQuestionModel(
              id: 'q2-2',
              text: 'Para cifrar información confidencial en reposo en la base de datos (como credenciales o datos médicos), ¿qué algoritmo es el estándar recomendado?',
              weightPoints: 50,
              options: [
                QuizOptionModel(id: 'opt22-1', text: 'AES-256 en modo GCM con vector de inicialización único.', isCorrect: true),
                QuizOptionModel(id: 'opt22-2', text: 'MD5 con sal aleatoria.', isCorrect: false),
                QuizOptionModel(id: 'opt22-3', text: 'Base64 con compresión gzip.', isCorrect: false),
                QuizOptionModel(id: 'opt22-4', text: 'DES (Data Encryption Standard) de 56 bits.', isCorrect: false),
              ],
              explanation: 'AES-256-GCM proporciona cifrado autenticado de alta seguridad y rendimiento para datos en reposo.',
            ),
          ],
        ),
        lessons: [
          LessonModel(
            id: 26,
            syllabusId: 25,
            title: 'Modelado Relacional y Transacciones ACID',
            description: 'Garantiza consistencia y atomicidad en operaciones financieras y transaccionales.',
            videoUrl: 'https://interactive-examples.mdn.mozilla.net/media/cc0-videos/flower.mp4',
            durationSeconds: 980,
            order: 1,
            isCompleted: false,
            isFreePreview: false,
            type: 'video',
          ),
          LessonModel(
            id: 27,
            syllabusId: 25,
            title: 'Cifrado en Reposo y en Tránsito (AES-256 / TLS)',
            description: 'Aplica criptografía moderna para proteger datos sensibles de los usuarios.',
            videoUrl: 'https://interactive-examples.mdn.mozilla.net/media/cc0-videos/flower.mp4',
            durationSeconds: 1050,
            order: 2,
            isCompleted: false,
            isFreePreview: false,
            type: 'video',
          ),
        ],
      ),
      SyllabusSectionModel(
        id: 28,
        title: 'Módulo Final: Evaluación para Diploma Oficial',
        order: 3,
        isFinalCertification: true,
        evaluation: const QuizModel(
          id: 'quiz-final-cert',
          title: 'Examen Global de Certificación: Desarrollo Web & Ciberseguridad',
          description: 'Evaluación integradora oficial obligatoria para la acreditación de competencias y expedición del diploma digital con código UUID.',
          passingScore: 75,
          isFinal: true,
          totalPoints: 100,
          durationMinutes: 25,
          courseId: 1,
          moduleId: 28,
          questions: [
            QuizQuestionModel(
              id: 'qf-1',
              text: '¿Cuál es el principio cardinal del modelo Zero Trust en arquitecturas seguras contemporáneas?',
              weightPoints: 30,
              options: [
                QuizOptionModel(id: 'optf1-1', text: 'Asumir brechas de seguridad y validar continuamente la identidad de cada solicitud con el menor privilegio.', isCorrect: true),
                QuizOptionModel(id: 'optf1-2', text: 'Confiar en todo el tráfico procedente de direcciones IP privadas dentro de la red corporativa.', isCorrect: false),
                QuizOptionModel(id: 'optf1-3', text: 'Eliminar la necesidad de certificados SSL/TLS en microservicios backend.', isCorrect: false),
                QuizOptionModel(id: 'optf1-4', text: 'Requerir inicio de sesión únicamente una vez por mes en la plataforma.', isCorrect: false),
              ],
              explanation: 'Zero Trust postula "nunca confiar, siempre verificar", evaluando contexto, dispositivo e identidad en cada petición.',
            ),
            QuizQuestionModel(
              id: 'qf-2',
              text: '¿Cuál es la estrategia recomendada para revocar un token JWT antes de su expiración en caso de actividad sospechosa?',
              weightPoints: 35,
              options: [
                QuizOptionModel(id: 'optf2-1', text: 'Mantener una lista de revocación (denylist/blocklist) distribuida en caché de alta velocidad (Redis) indexada por el identificador único del token (JTI).', isCorrect: true),
                QuizOptionModel(id: 'optf2-2', text: 'Modificar la clave privada de firma en el servidor obligando a que fallen todos los tokens de todos los usuarios.', isCorrect: false),
                QuizOptionModel(id: 'optf2-3', text: 'Solicitar al navegador del usuario que elimine la cookie sin comprobación en el backend.', isCorrect: false),
                QuizOptionModel(id: 'optf2-4', text: 'Los tokens JWT no pueden invalidarse bajo ningún concepto hasta que concluya su periodo natural de expiración.', isCorrect: false),
              ],
              explanation: 'Una denylist basada en JTI en memoria volátil permite revocar tokens específicos con latencias mínimas sin invalidar a toda la base de usuarios.',
            ),
            QuizQuestionModel(
              id: 'qf-3',
              text: '¿Por qué se debe utilizar una función de derivación de claves (KDF) con factor de trabajo adaptable (como Argon2id o bcrypt) en lugar de hashes rápidos como SHA-256 para almacenamiento de credenciales?',
              weightPoints: 35,
              options: [
                QuizOptionModel(id: 'optf3-1', text: 'Porque los algoritmos rápidos como SHA-256 son vulnerables a ataques de fuerza bruta masiva acelerados por GPUs y ASICs, mientras que Argon2id y bcrypt imponen coste computacional y de memoria configurable.', isCorrect: true),
                QuizOptionModel(id: 'optf3-2', text: 'Porque SHA-256 tiene colisiones matemáticas triviales y ya no es un algoritmo estándar en la industria.', isCorrect: false),
                QuizOptionModel(id: 'optf3-3', text: 'Porque Argon2id no utiliza sal (salt) y ocupa menos espacio en base de datos.', isCorrect: false),
                QuizOptionModel(id: 'optf3-4', text: 'Porque bcrypt es un algoritmo simétrico que permite descifrar la contraseña original cuando el usuario la olvida.', isCorrect: false),
              ],
              explanation: 'Las credenciales requieren algoritmos deliberadamente lentos y resistentes a memoria (memory-hard) para impedir ataques de diccionario por fuerza bruta a gran escala.',
            ),
          ],
        ),
        lessons: [
          LessonModel(
            id: 29,
            syllabusId: 28,
            title: 'Lineamientos y Parámetros del Examen de Certificación',
            description: '''# Lineamientos y Criterios de Aprobación para Diploma Oficial
Este examen final integrador evalúa las competencias globales adquiridas a lo largo de todo el programa formativo de Master Academy.

### 📜 Criterios de Acreditación Oficial:
- **Puntaje total**: 100 puntos ponderados.
- **Puntaje mínimo aprobatorio**: 75% (75 puntos).
- **Emisión de Diploma**: Al alcanzar el puntaje aprobatorio, el sistema te declarará oficialmente **APTO** y generará de inmediato tu **Certificado Digital con código UUID único** verificado en la plataforma.
- **Reintentos**: Si obtienes menos del 75%, recibirás retroalimentación detallada y podrás volver a realizar la evaluación.

Haz clic en **"Iniciar Examen Global de Certificación"** para comenzar.''',
            videoUrl: null,
            durationSeconds: 300,
            order: 1,
            isCompleted: false,
            isFreePreview: false,
            type: 'reading',
          ),
        ],
      ),
    ];
  }
}