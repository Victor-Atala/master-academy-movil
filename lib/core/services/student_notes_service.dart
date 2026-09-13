import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../di/service_locator.dart';

class StudentNote {
  final String id;
  final String courseId;
  final String courseTitle;
  final int lessonId;
  final String lessonTitle;
  final String content;
  final DateTime updatedAt;

  StudentNote({
    required this.id,
    required this.courseId,
    required this.courseTitle,
    required this.lessonId,
    required this.lessonTitle,
    required this.content,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'courseId': courseId,
        'courseTitle': courseTitle,
        'lessonId': lessonId,
        'lessonTitle': lessonTitle,
        'content': content,
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory StudentNote.fromJson(Map<String, dynamic> json) => StudentNote(
        id: json['id'] as String? ?? 'note_${json['lessonId']}',
        courseId: '${json['courseId'] ?? "0"}',
        courseTitle: json['courseTitle'] as String? ?? 'Curso de Master Academy',
        lessonId: json['lessonId'] is int ? json['lessonId'] as int : int.tryParse('${json['lessonId']}') ?? 0,
        lessonTitle: json['lessonTitle'] as String? ?? 'Lección',
        content: json['content'] as String? ?? '',
        updatedAt: json['updatedAt'] != null
            ? DateTime.tryParse(json['updatedAt'] as String) ?? DateTime.now()
            : DateTime.now(),
      );

  StudentNote copyWith({
    String? content,
    DateTime? updatedAt,
  }) {
    return StudentNote(
      id: id,
      courseId: courseId,
      courseTitle: courseTitle,
      lessonId: lessonId,
      lessonTitle: lessonTitle,
      content: content ?? this.content,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class StudentNotesService {
  static const String _storageKey = 'master_student_all_notes_index_v1';
  final FlutterSecureStorage _storage;
  List<StudentNote>? _cachedNotes;

  StudentNotesService({FlutterSecureStorage? storage})
      : _storage = storage ?? sl<FlutterSecureStorage>();

  /// Obtiene todos los apuntes registrados por el estudiante ordenados por fecha descendente
  Future<List<StudentNote>> getAllNotes({bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedNotes != null) {
      return List<StudentNote>.from(_cachedNotes!);
    }
    try {
      final raw = await _storage.read(key: _storageKey);
      if (raw != null && raw.trim().isNotEmpty) {
        final List<dynamic> list = jsonDecode(raw);
        final notes = list
            .map((item) => StudentNote.fromJson(item as Map<String, dynamic>))
            .toList();
        notes.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        _cachedNotes = notes;
        return List<StudentNote>.from(_cachedNotes!);
      }
    } catch (_) {}
    _cachedNotes = [];
    return [];
  }

  /// Obtiene los apuntes filtrados por curso
  Future<List<StudentNote>> getNotesForCourse(dynamic courseId) async {
    final cId = '$courseId';
    final all = await getAllNotes();
    return all.where((n) => n.courseId == cId).toList();
  }

  /// Obtiene el apunte de una lección específica
  Future<StudentNote?> getNoteForLesson(int lessonId) async {
    try {
      final all = await getAllNotes();
      final index = all.indexWhere((n) => n.lessonId == lessonId);
      if (index >= 0) return all[index];
      return null;
    } catch (_) {
      // Fallback para verificar compatibilidad con clave anterior
      try {
        final legacyContent = await _storage.read(key: 'lesson_notes_$lessonId');
        if (legacyContent != null && legacyContent.trim().isNotEmpty) {
          return StudentNote(
            id: 'note_$lessonId',
            courseId: '0',
            courseTitle: 'Mis Apuntes',
            lessonId: lessonId,
            lessonTitle: 'Clase #$lessonId',
            content: legacyContent,
            updatedAt: DateTime.now(),
          );
        }
      } catch (_) {}
      return null;
    }
  }

  /// Guarda o actualiza un apunte y mantiene el índice sincronizado
  Future<StudentNote> saveNote({
    required dynamic courseId,
    required String courseTitle,
    required int lessonId,
    required String lessonTitle,
    required String content,
  }) async {
    final cId = '$courseId';
    final all = await getAllNotes();
    final noteId = 'note_$lessonId';
    final existingIndex = all.indexWhere((n) => n.lessonId == lessonId);

    final updatedNote = StudentNote(
      id: noteId,
      courseId: cId,
      courseTitle: courseTitle.isNotEmpty ? courseTitle : 'Curso de Master Academy',
      lessonId: lessonId,
      lessonTitle: lessonTitle.isNotEmpty ? lessonTitle : 'Clase #$lessonId',
      content: content.trim(),
      updatedAt: DateTime.now(),
    );

    if (existingIndex >= 0) {
      all[existingIndex] = updatedNote;
    } else {
      all.insert(0, updatedNote);
    }

    // Actualizar caché en memoria inmediatamente
    _cachedNotes = all;

    // Persistir el índice completo en secure storage
    final encoded = jsonEncode(all.map((n) => n.toJson()).toList());
    await _storage.write(key: _storageKey, value: encoded);

    // Mantener también la clave individual para compatibilidad con el reproductor
    await _storage.write(key: 'lesson_notes_$lessonId', value: content.trim());

    return updatedNote;
  }

  /// Elimina un apunte
  Future<bool> deleteNote(int lessonId) async {
    final all = await getAllNotes();
    all.removeWhere((n) => n.lessonId == lessonId);
    _cachedNotes = all;
    final encoded = jsonEncode(all.map((n) => n.toJson()).toList());
    await _storage.write(key: _storageKey, value: encoded);
    await _storage.delete(key: 'lesson_notes_$lessonId');
    return true;
  }
}
