import 'dart:convert';
import 'dart:io';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/constants/api_constants.dart';
import '../../core/network/api_client.dart';
import '../models/course_model.dart';
import '../models/syllabus_model.dart';

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

    final updatedSections = <SyllabusSectionModel>[];
    for (int i = 0; i < sections.length; i++) {
      final s = sections[i];
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
          ),
        );
      }
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
    ];
  }
}