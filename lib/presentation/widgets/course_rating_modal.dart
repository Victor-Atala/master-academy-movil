import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/common/ui_state.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/services/course_interaction_service.dart';
import '../../../domain/entities/course.dart';
import '../viewmodels/course_viewmodel.dart';

class CourseRatingModal extends StatefulWidget {
  final dynamic courseId;
  final String courseTitle;
  final Function(CourseReview review)? onReviewSubmitted;
  final bool? isEnrolled;

  const CourseRatingModal({
    super.key,
    required this.courseId,
    required this.courseTitle,
    this.onReviewSubmitted,
    this.isEnrolled,
  });

  static void show(
    BuildContext context, {
    required dynamic courseId,
    required String courseTitle,
    Function(CourseReview review)? onReviewSubmitted,
    bool? isEnrolled,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => CourseRatingModal(
        courseId: courseId,
        courseTitle: courseTitle,
        onReviewSubmitted: onReviewSubmitted,
        isEnrolled: isEnrolled,
      ),
    );
  }

  @override
  State<CourseRatingModal> createState() => _CourseRatingModalState();
}

class _CourseRatingModalState extends State<CourseRatingModal> {
  final _commentController = TextEditingController();
  final _nameController = TextEditingController(text: 'Estudiante Master Academy');
  double _rating = 5.0;
  bool _isSubmitting = false;

  final List<String> _availableTags = [
    'Explicación clara',
    'Muy práctico',
    'Excelente docente',
    'Material completo',
    'Casos reales',
    'Didáctico y ameno',
    'Recomendado para trabajar',
  ];

  final Set<String> _selectedTags = {'Explicación clara', 'Muy práctico'};

  @override
  void dispose() {
    _commentController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  String _getRatingLabel(double rating) {
    if (rating >= 5.0) return '¡Excelente curso!';
    if (rating >= 4.0) return 'Muy bueno y recomendable';
    if (rating >= 3.0) return 'Bueno, cumple su cometido';
    if (rating >= 2.0) return 'Regular, puede mejorar';
    return 'Necesita mejoras importantes';
  }

  Color _getRatingColor(double rating) {
    if (rating >= 4.0) return const Color(0xFFF59E0B);
    if (rating >= 3.0) return const Color(0xFF3B82F6);
    return const Color(0xFFEF4444);
  }

  bool get _isEnrolled {
    if (widget.isEnrolled != null) return widget.isEnrolled!;
    try {
      final courseVm = context.read<CourseViewModel>();
      final isLocallyEnrolled = courseVm.isCourseEnrolled('${widget.courseId}');
      if (isLocallyEnrolled) return true;
      if (courseVm.state is UiSuccess<List<Course>>) {
        final list = (courseVm.state as UiSuccess<List<Course>>).data;
        return list.any((c) => c.id == '${widget.courseId}' && c.isEnrolled);
      }
    } catch (_) {}
    return false;
  }

  Future<void> _submitReview() async {
    if (!_isEnrolled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debes estar inscrito en este curso para poder calificarlo.'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }

    if (_commentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor escribe tu opinión o recomendación sobre el curso.'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final interactionService = sl<CourseInteractionService>();
      final review = await interactionService.submitCourseReview(
        courseId: widget.courseId,
        userName: _nameController.text.trim().isNotEmpty ? _nameController.text.trim() : 'Estudiante',
        rating: _rating,
        reviewText: _commentController.text.trim(),
        tags: _selectedTags.toList(),
      );

      if (mounted) {
        Navigator.pop(context);
        widget.onReviewSubmitted?.call(review);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: const [
                Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Expanded(child: Text('¡Muchas gracias por calificar este curso!')),
              ],
            ),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar reseña: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    // 🔒 RESTRICCIÓN DE CLIENTE: Si el alumno no está inscrito, se bloquea la calificación
    if (!_isEnrolled) {
      return Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.fromLTRB(24, 16, 24, bottomInset > 0 ? bottomInset + 24 : 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2.5),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withOpacity(0.15),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.3), width: 1.5),
              ),
              child: const Icon(Icons.lock_rounded, size: 40, color: Color(0xFFF59E0B)),
            ),
            const SizedBox(height: 16),
            Text(
              'Calificación Exclusiva para Alumnos',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Para asegurar la autenticidad de las valoraciones y la calidad de los cursos, únicamente los estudiantes con inscripción activa en "${widget.courseTitle}" pueden calificar el contenido y dejar una reseña.',
              style: TextStyle(
                fontSize: 13,
                height: 1.45,
                color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.check_rounded, size: 18),
                label: const Text('Entendido', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 16, 20, bottomInset > 0 ? bottomInset + 16 : 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2.5),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 26),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Calificar Curso',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        widget.courseTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Star Rating Section
            Center(
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      final starVal = index + 1.0;
                      return GestureDetector(
                        onTap: () => setState(() => _rating = starVal),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Icon(
                            _rating >= starVal ? Icons.star_rounded : Icons.star_outline_rounded,
                            size: 40,
                            color: _rating >= starVal ? const Color(0xFFF59E0B) : Colors.grey.shade400,
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _getRatingLabel(_rating),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _getRatingColor(_rating),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Highlight Tags
            Text(
              '¿Qué destacarías de este curso?',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white70 : AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _availableTags.map((tag) {
                final isSelected = _selectedTags.contains(tag);
                return FilterChip(
                  label: Text(tag),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedTags.add(tag);
                      } else {
                        _selectedTags.remove(tag);
                      }
                    });
                  },
                  selectedColor: AppColors.primary.withOpacity(0.2),
                  checkmarkColor: AppColors.primary,
                  labelStyle: TextStyle(
                    fontSize: 12,
                    color: isSelected
                        ? AppColors.primary
                        : (isDark ? Colors.white70 : AppColors.textPrimary),
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                  backgroundColor: isDark ? AppColors.darkSurface : Colors.grey.shade100,
                  side: BorderSide(
                    color: isSelected ? AppColors.primary : Colors.transparent,
                  ),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Review comment
            Text(
              'Tu Reseña y Recomendaciones',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white70 : AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _commentController,
              maxLines: 3,
              style: TextStyle(color: isDark ? Colors.white : AppColors.textPrimary, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Cuéntale a la comunidad qué te pareció el curso, el instructor y el material...',
                hintStyle: TextStyle(color: isDark ? AppColors.darkTextMuted : AppColors.textMuted, fontSize: 12),
                filled: true,
                fillColor: isDark ? AppColors.darkSurface : Colors.grey.shade50,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                ),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
            const SizedBox(height: 14),

            // Author Name
            Text(
              'Publicar como',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _nameController,
              style: TextStyle(color: isDark ? Colors.white : AppColors.textPrimary, fontSize: 13),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.person_outline_rounded, size: 18),
                filled: true,
                fillColor: isDark ? AppColors.darkSurface : Colors.grey.shade50,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.border),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
            const SizedBox(height: 20),

            // Submit Button
            ElevatedButton(
              onPressed: _isSubmitting ? null : _submitReview,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.rate_review_rounded, size: 18),
                        SizedBox(width: 8),
                        Text('Publicar Calificación', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
