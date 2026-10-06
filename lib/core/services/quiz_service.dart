import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../data/models/quiz_model.dart';
import '../../domain/entities/quiz.dart';
import '../../domain/entities/certificate.dart';

class QuizService {
  final FlutterSecureStorage _storage;

  QuizService({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  String _attemptKey(String quizId) => 'quiz_attempt_$quizId';
  String _attemptsCountKey(String quizId) => 'quiz_attempts_count_$quizId';

  Future<QuizAttempt?> getAttempt(String quizId) async {
    try {
      final jsonStr = await _storage.read(key: _attemptKey(quizId));
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final map = jsonDecode(jsonStr) as Map<String, dynamic>;
        return QuizAttemptModel.fromJson(map);
      }
    } catch (_) {}
    return null;
  }

  Future<int> getAttemptsCount(String quizId) async {
    try {
      final countStr = await _storage.read(key: _attemptsCountKey(quizId));
      return int.tryParse(countStr ?? '0') ?? 0;
    } catch (_) {
      return 0;
    }
  }

  Future<bool> hasPassed(String quizId) async {
    final attempt = await getAttempt(quizId);
    return attempt != null && attempt.isPassed;
  }

  Future<bool> isCourseBlockedByCertification(int courseId) async {
    try {
      final val = await _storage.read(key: 'course_${courseId}_requires_repurchase');
      return val == 'true';
    } catch (_) {
      return false;
    }
  }

  Future<QuizAttempt> submitAttempt({
    required Quiz quiz,
    required Map<String, String> selectedOptionIds,
  }) async {
    int totalScore = 0;

    for (final question in quiz.questions) {
      final selectedId = selectedOptionIds[question.id];
      if (selectedId != null) {
        final option = question.options.firstWhere(
          (o) => o.id == selectedId,
          orElse: () => const QuizOption(id: '', text: '', isCorrect: false),
        );
        if (option.isCorrect) {
          totalScore += question.weightPoints;
        }
      }
    }

    final double percentage = quiz.totalPoints > 0
        ? (totalScore / quiz.totalPoints) * 100.0
        : 0.0;

    final bool isPassed = totalScore >= quiz.passingScore;

    // Conteo y regla de intentos
    final prevCount = await getAttemptsCount(quiz.id);
    final currentAttemptNumber = prevCount + 1;

    bool courseReset = false;
    bool requiresRepurchase = false;
    int? remainingAttempts;
    int? attemptsAllowed;
    String resultMessage = '';

    if (quiz.isFinal) {
      const maxAttempts = 5;
      attemptsAllowed = maxAttempts;
      remainingAttempts = (maxAttempts - currentAttemptNumber).clamp(0, maxAttempts);

      if (isPassed) {
        resultMessage =
            '¡Excelente! Has alcanzado la nota requerida (${percentage.toStringAsFixed(0)}% / mín. ${quiz.passingScore}%). El alumno es APTO PARA CERTIFICACIÓN OFICIAL (Intento $currentAttemptNumber de $maxAttempts).';
      } else {
        if (currentAttemptNumber >= maxAttempts) {
          // AGOTÓ LOS 5 INTENTOS: REINICIAR CURSO Y REQUERIR RECOMPRA
          courseReset = true;
          requiresRepurchase = true;
          remainingAttempts = 0;
          resultMessage =
              '¡ATENCIÓN! Has agotado tus 5 intentos permitidos para el Examen de Certificación con ${percentage.toStringAsFixed(0)}%. Tu progreso en este curso ha sido reiniciado a 0% y la matrícula ha quedado bloqueada. Deberás volver a adquirir el curso para acceder a una nueva oportunidad.';

          await _resetCourseProgressAndExpireEnrollment(quiz.courseId);
        } else {
          resultMessage =
              'No alcanzaste el mínimo requerido (${percentage.toStringAsFixed(0)}% / mín. ${quiz.passingScore}%). Intento $currentAttemptNumber de $maxAttempts utilizado. Te quedan $remainingAttempts intento(s) antes de que el curso sea reiniciado.';
        }
      }
    } else {
      // Examen formativo de módulo: Reintentos ilimitados
      attemptsAllowed = null;
      remainingAttempts = null;
      resultMessage = isPassed
          ? '¡Muy bien! Has superado la evaluación formativa de este módulo con ${percentage.toStringAsFixed(0)}%.'
          : 'Puntaje obtenido: ${percentage.toStringAsFixed(0)}%. Esta evaluación de módulo tiene reintentos ilimitados: puedes repasar los contenidos y reintentar las veces que desees sin penalización.';
    }

    // Persistir conteo de intentos
    try {
      await _storage.write(
        key: _attemptsCountKey(quiz.id),
        value: currentAttemptNumber.toString(),
      );
    } catch (_) {}

    final attempt = QuizAttemptModel(
      quizId: quiz.id,
      score: totalScore,
      percentage: percentage,
      isPassed: isPassed,
      timestamp: DateTime.now(),
      selectedOptionIds: selectedOptionIds,
      attemptNumber: currentAttemptNumber,
      attemptsAllowed: attemptsAllowed,
      remainingAttempts: remainingAttempts,
      courseReset: courseReset,
      requiresRepurchase: requiresRepurchase,
      resultMessage: resultMessage,
    );

    try {
      await _storage.write(
        key: _attemptKey(quiz.id),
        value: jsonEncode(attempt.toJson()),
      );
    } catch (_) {}

    // Si es el Examen Final para Diploma Oficial y el alumno es declarado APTO:
    if (quiz.isFinal && isPassed) {
      await _grantOfficialDiploma(quiz);
    }

    return attempt;
  }

  Future<void> _resetCourseProgressAndExpireEnrollment(int courseId) async {
    try {
      // Marcar curso como reseteado / expirado por agotar intentos
      await _storage.write(
        key: 'course_${courseId}_requires_repurchase',
        value: 'true',
      );
      await _storage.write(
        key: 'course_${courseId}_progress',
        value: '0.0',
      );
      await _storage.delete(
        key: 'official_diploma_course_$courseId',
      );
    } catch (_) {}
  }

  Future<void> _grantOfficialDiploma(Quiz quiz) async {
    try {
      final now = DateTime.now();
      final year = now.year;
      final randomHex = (now.millisecondsSinceEpoch % 100000).toString().padLeft(5, '0');
      final uuidCode = 'MA-$year-DEV-$randomHex';

      final certId = 99000 + (quiz.courseId > 0 ? quiz.courseId : 1);
      final newCert = Certificate(
        id: certId,
        title: 'Certificado de Aprobación Oficial',
        courseId: quiz.courseId > 0 ? quiz.courseId : 1,
        courseTitle: 'Desarrollo Web Fullstack & Ciberseguridad',
        recipientName: 'Víctor Atala Lagunas',
        verificationUuid: uuidCode,
        issuedAt: now,
        qrCodeUrl: 'https://masteracademy.mx/verify/$uuidCode',
        certificatePdfUrl: 'https://masteracademy.mx/storage/certificates/$uuidCode.pdf',
      );

      await _storage.write(
        key: 'official_diploma_course_${quiz.courseId}',
        value: jsonEncode({
          'id': newCert.id,
          'uuid': newCert.verificationUuid,
          'course_id': newCert.courseId,
          'issue_date': newCert.issuedAt.toIso8601String(),
          'student_name': newCert.recipientName,
          'course_title': newCert.courseTitle,
          'is_apto': true,
        }),
      );

      await _storage.write(key: 'diploma_uuid_${quiz.id}', value: uuidCode);
    } catch (_) {}
  }

  Future<void> clearAttempt(String quizId) async {
    try {
      await _storage.delete(key: _attemptKey(quizId));
    } catch (_) {}
  }

  Future<void> resetAllAttemptsForQuiz(String quizId) async {
    try {
      await _storage.delete(key: _attemptKey(quizId));
      await _storage.delete(key: _attemptsCountKey(quizId));
    } catch (_) {}
  }
}
