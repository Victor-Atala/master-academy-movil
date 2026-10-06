import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/services/quiz_service.dart';
import '../../../domain/entities/course.dart';
import '../../../domain/entities/quiz.dart';
import '../../widgets/certificate_viewer_modal.dart';

class QuizScreen extends StatefulWidget {
  final Quiz quiz;
  final Course course;
  final VoidCallback? onCompleted;

  const QuizScreen({
    super.key,
    required this.quiz,
    required this.course,
    this.onCompleted,
  });

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  int _currentIndex = 0;
  final Map<String, String> _selectedAnswers = {}; // questionId -> optionId
  bool _isSubmitted = false;
  QuizAttempt? _attempt;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _checkExistingAttempt();
  }

  Future<void> _checkExistingAttempt() async {
    final service = sl<QuizService>();
    final existing = await service.getAttempt(widget.quiz.id);
    if (existing != null && mounted) {
      setState(() {
        _attempt = existing;
        _isSubmitted = true;
        _selectedAnswers.addAll(existing.selectedOptionIds);
      });
    }
  }

  void _selectOption(String questionId, String optionId) {
    if (_isSubmitted) return;
    setState(() {
      _selectedAnswers[questionId] = optionId;
    });
  }

  Future<void> _submitQuiz() async {
    final unattempted = widget.quiz.questions.length - _selectedAnswers.length;
    if (unattempted > 0) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Preguntas sin responder'),
          content: Text('Tienes $unattempted pregunta(s) sin responder. ¿Deseas entregar la evaluación de todas formas?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Continuar respondiendo'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              child: const Text('Entregar evaluación', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
      if (confirm != true) return;
    }

    setState(() => _isSubmitting = true);
    final service = sl<QuizService>();
    final result = await service.submitAttempt(
      quiz: widget.quiz,
      selectedOptionIds: _selectedAnswers,
    );

    if (mounted) {
      setState(() {
        _isSubmitting = false;
        _isSubmitted = true;
        _attempt = result;
      });
      widget.onCompleted?.call();
    }
  }

  void _retryQuiz() async {
    if (widget.quiz.isFinal && _attempt != null && _attempt!.courseReset) {
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.lock_rounded, color: AppColors.error),
              SizedBox(width: 8),
              Text('Curso Reiniciado'),
            ],
          ),
          content: const Text(
            'Has agotado los 5 intentos del examen de certificación. Tu progreso se ha reiniciado a 0% y la matrícula ha expirado. Debes volver a adquirir el curso para acceder a una nueva oportunidad.',
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              child: const Text('Entendido', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
      return;
    }

    final service = sl<QuizService>();
    await service.clearAttempt(widget.quiz.id);
    setState(() {
      _isSubmitted = false;
      _attempt = null;
      _currentIndex = 0;
      _selectedAnswers.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final totalQuestions = widget.quiz.questions.length;
    final currentQ = totalQuestions > 0 ? widget.quiz.questions[_currentIndex] : null;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.quiz.isFinal ? 'Examen de Certificación (5 Intentos)' : 'Evaluación de Módulo (Ilimitada)',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () {
            if (!_isSubmitted && _selectedAnswers.isNotEmpty) {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('¿Salir de la evaluación?'),
                  content: const Text('Si sales ahora, tus respuestas actuales no se guardarán hasta entregar.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Quedarme')),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        Navigator.pop(context);
                      },
                      child: const Text('Salir', style: TextStyle(color: AppColors.error)),
                    ),
                  ],
                ),
              );
            } else {
              Navigator.pop(context);
            }
          },
        ),
      ),
      body: _isSubmitted && _attempt != null
          ? _buildResultsView(isDark)
          : (currentQ != null
              ? _buildQuizTakingView(currentQ, totalQuestions, isDark)
              : const Center(child: Text('No hay preguntas configuradas para esta evaluación.'))),
    );
  }

  Widget _buildQuizTakingView(QuizQuestion question, int totalQuestions, bool isDark) {
    final progress = (totalQuestions > 0) ? (_currentIndex + 1) / totalQuestions : 0.0;
    final isLast = _currentIndex == totalQuestions - 1;

    return SafeArea(
      child: Column(
        children: [
          // Header Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : Colors.white,
              border: Border(bottom: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.border)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: widget.quiz.isFinal
                            ? const Color(0xFFF59E0B).withOpacity(0.15)
                            : AppColors.primary.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        widget.quiz.isFinal
                            ? '⭐ CERTIFICACIÓN OFICIAL (MÁX. 5 INTENTOS)'
                            : '🔄 EVALUACIÓN FORMATIVA (REINTENTOS ILIMITADOS)',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: widget.quiz.isFinal ? const Color(0xFFD97706) : AppColors.primary,
                        ),
                      ),
                    ),
                    Text(
                      'Mínimo: ${widget.quiz.passingScore}% • Total: ${widget.quiz.totalPoints} pts',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  widget.quiz.title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 6,
                          backgroundColor: isDark ? Colors.white12 : Colors.grey.shade200,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            widget.quiz.isFinal ? const Color(0xFF0AB39C) : AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${_currentIndex + 1} de $totalQuestions',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Question & Options Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Question Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurface : AppColors.backgroundAlt,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Pregunta ${_currentIndex + 1}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '${question.weightPoints} pts',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          question.text,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            height: 1.4,
                            color: isDark ? Colors.white : AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Options List
                  Text(
                    'Selecciona la respuesta correcta:',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 10),

                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: question.options.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, optIdx) {
                      final opt = question.options[optIdx];
                      final isSelected = _selectedAnswers[question.id] == opt.id;

                      return InkWell(
                        onTap: () => _selectOption(question.id, opt.id),
                        borderRadius: BorderRadius.circular(12),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primary.withOpacity(isDark ? 0.2 : 0.08)
                                : (isDark ? AppColors.darkSurface : Colors.white),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.primary
                                  : (isDark ? AppColors.darkBorder : AppColors.border),
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isSelected ? AppColors.primary : Colors.transparent,
                                  border: Border.all(
                                    color: isSelected
                                        ? AppColors.primary
                                        : (isDark ? Colors.white30 : Colors.grey.shade400),
                                    width: 2,
                                  ),
                                ),
                                child: isSelected
                                    ? const Icon(Icons.check, size: 14, color: Colors.white)
                                    : null,
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(
                                  opt.text,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    color: isDark ? Colors.white : AppColors.textPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          // Bottom Bar Navigation
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : Colors.white,
              border: Border(top: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.border)),
            ),
            child: Row(
              children: [
                if (_currentIndex > 0)
                  OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        _currentIndex--;
                      });
                    },
                    icon: const Icon(Icons.arrow_back_rounded, size: 16),
                    label: const Text('Anterior'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                  ),
                const Spacer(),
                if (!isLast)
                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _currentIndex++;
                      });
                    },
                    icon: const Icon(Icons.arrow_forward_rounded, size: 16, color: Colors.white),
                    label: const Text('Siguiente', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    ),
                  )
                else
                  ElevatedButton.icon(
                    onPressed: _isSubmitting ? null : _submitQuiz,
                    icon: _isSubmitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Icon(Icons.check_circle_rounded, size: 16, color: Colors.white),
                    label: const Text(
                      'Entregar Evaluación',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0AB39C),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsView(bool isDark) {
    final attempt = _attempt!;
    final isPassed = attempt.isPassed;
    final isFinal = widget.quiz.isFinal;
    final isCourseReset = attempt.courseReset;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Status Icon & Title
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: isPassed
                    ? const Color(0xFF10B981).withOpacity(0.15)
                    : (isCourseReset
                        ? const Color(0xFFDC2626).withOpacity(0.18)
                        : const Color(0xFFEF4444).withOpacity(0.15)),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isPassed
                    ? Icons.workspace_premium_rounded
                    : (isCourseReset ? Icons.lock_reset_rounded : Icons.cancel_outlined),
                size: 44,
                color: isPassed
                    ? const Color(0xFF10B981)
                    : (isCourseReset ? const Color(0xFFDC2626) : const Color(0xFFEF4444)),
              ),
            ),
            const SizedBox(height: 14),

            Text(
              isPassed
                  ? (isFinal
                      ? '¡APTO PARA CERTIFICACIÓN OFICIAL!'
                      : '¡EVALUACIÓN DE MÓDULO APROBADA!')
                  : (isCourseReset
                      ? 'CURSO REINICIADO (5 Intentos Agotados)'
                      : (isFinal ? 'NO APTO (Requiere Reintento)' : 'EVALUACIÓN NO SUPERADA')),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: isPassed
                    ? const Color(0xFF10B981)
                    : (isCourseReset ? const Color(0xFFDC2626) : const Color(0xFFEF4444)),
              ),
            ),
            const SizedBox(height: 6),

            // Attempt Number Pill
            if (isFinal)
              Container(
                margin: const EdgeInsets.symmetric(vertical: 6),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: isCourseReset
                      ? const Color(0xFFDC2626).withOpacity(0.15)
                      : (isPassed
                          ? const Color(0xFF10B981).withOpacity(0.15)
                          : const Color(0xFFF59E0B).withOpacity(0.15)),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  isCourseReset
                      ? 'Intento 5 de 5 (Límite Agotado)'
                      : 'Intento ${attempt.attemptNumber} de 5',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isCourseReset
                        ? const Color(0xFFDC2626)
                        : (isPassed ? const Color(0xFF059669) : const Color(0xFFD97706)),
                  ),
                ),
              )
            else
              Container(
                margin: const EdgeInsets.symmetric(vertical: 6),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Evaluación de Módulo • Reintentos Ilimitados',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),

            const SizedBox(height: 6),

            // Description Text / Warning
            Text(
              isPassed
                  ? (isFinal
                      ? 'Has superado el puntaje mínimo requerido (${widget.quiz.passingScore}%) demostrando las competencias globales del programa formativo.'
                      : 'Has acreditado con éxito este módulo temático.')
                  : (isCourseReset
                      ? 'Has agotado tus 5 intentos del examen de certificación con ${attempt.percentage.toStringAsFixed(0)}%. Tu progreso en este curso ha sido reiniciado a 0% y la matrícula ha expirado. Para tener una nueva oportunidad, deberás volver a adquirir el curso con un nuevo código.'
                      : (isFinal
                          ? 'Has obtenido ${attempt.score} de ${widget.quiz.totalPoints} puntos (${attempt.percentage.toStringAsFixed(0)}%). Se requiere un mínimo del ${widget.quiz.passingScore}%. Te quedan ${attempt.remainingAttempts ?? (5 - attempt.attemptNumber)} intento(s) antes de que el curso sea reiniciado.'
                          : 'Has obtenido ${attempt.percentage.toStringAsFixed(0)}%. Esta es una evaluación formativa de módulo con reintentos ilimitados. Puedes repasar los temas y reintentar las veces que desees.')),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 20),

            // Score Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isPassed
                      ? const Color(0xFF10B981).withOpacity(0.3)
                      : (isCourseReset
                          ? const Color(0xFFDC2626).withOpacity(0.4)
                          : const Color(0xFFEF4444).withOpacity(0.3)),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      const Text('Puntaje', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                      const SizedBox(height: 4),
                      Text(
                        '${attempt.score} / ${widget.quiz.totalPoints}',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  Container(width: 1, height: 35, color: isDark ? AppColors.darkBorder : AppColors.border),
                  Column(
                    children: [
                      const Text('Porcentaje', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                      const SizedBox(height: 4),
                      Text(
                        '${attempt.percentage.toStringAsFixed(0)}%',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: isPassed
                              ? const Color(0xFF10B981)
                              : (isCourseReset ? const Color(0xFFDC2626) : const Color(0xFFEF4444)),
                        ),
                      ),
                    ],
                  ),
                  Container(width: 1, height: 35, color: isDark ? AppColors.darkBorder : AppColors.border),
                  Column(
                    children: [
                      const Text('Requisito', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                      const SizedBox(height: 4),
                      Text(
                        '${widget.quiz.passingScore}%',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Action Buttons
            if (isPassed && isFinal) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    CertificateViewerModal.show(
                      context,
                      widget.course,
                      studentName: 'Víctor Atala Lagunas',
                    );
                  },
                  icon: const Icon(Icons.workspace_premium_rounded, color: Colors.white),
                  label: const Text(
                    'Ver Diploma Oficial con Código UUID',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0AB39C),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 2,
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],

            if (!isPassed && !isCourseReset) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _retryQuiz,
                  icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                  label: Text(
                    isFinal
                        ? 'Reintentar Examen (${attempt.remainingAttempts ?? (5 - attempt.attemptNumber)} restantes)'
                        : 'Reintentar Evaluación (Ilimitado)',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isFinal ? const Color(0xFFD97706) : AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],

            if (isCourseReset) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFDC2626).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFDC2626).withOpacity(0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 24),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Curso bloqueado por exceder el máximo de 5 intentos. Se debe volver a adquirir el curso para reiniciar.',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFDC2626),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.shopping_bag_outlined, color: Colors.white),
                  label: const Text(
                    'Volver al Catálogo / Re-adquirir Curso',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFDC2626),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],

            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Volver al temario del curso'),
              ),
            ),
            const SizedBox(height: 28),

            // Detailed Review Section
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Revisión y Retroalimentación:',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : AppColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: 12),

            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: widget.quiz.questions.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, qIdx) {
                final q = widget.quiz.questions[qIdx];
                final selectedOptId = attempt.selectedOptionIds[q.id];
                final correctOpt = q.options.firstWhere(
                  (o) => o.isCorrect,
                  orElse: () => const QuizOption(id: '', text: '', isCorrect: false),
                );
                final isQCorrect = selectedOptId == correctOpt.id;

                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurface : AppColors.backgroundAlt,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isQCorrect
                          ? const Color(0xFF10B981).withOpacity(0.3)
                          : const Color(0xFFEF4444).withOpacity(0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                isQCorrect ? Icons.check_circle_rounded : Icons.cancel_rounded,
                                size: 16,
                                color: isQCorrect ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Pregunta ${qIdx + 1}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isQCorrect ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                                ),
                              ),
                            ],
                          ),
                          Text(
                            isQCorrect ? '+${q.weightPoints} pts' : '0 / ${q.weightPoints} pts',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isQCorrect ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        q.text,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkCard : Colors.white,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Respuesta correcta: ${correctOpt.text}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF10B981),
                              ),
                            ),
                            if (q.explanation != null && q.explanation!.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                q.explanation!,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontStyle: FontStyle.italic,
                                  color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
