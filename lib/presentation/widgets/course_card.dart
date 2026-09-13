import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../domain/entities/course.dart';
import '../viewmodels/course_viewmodel.dart';

class CourseCard extends StatelessWidget {
  final Course course;
  final VoidCallback onTap;

  const CourseCard({
    super.key,
    required this.course,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bool isEnrolled = course.isEnrolled ||
        context.select<CourseViewModel, bool>(
          (vm) => vm.isCourseEnrolled(course.id),
        );

    return Container(
      margin: const EdgeInsets.only(bottom: AppDimensions.s20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(AppDimensions.r16),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.border,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppDimensions.r16),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppDimensions.r16),
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Thumbnail with Category Badge & Purchased Badge
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(AppDimensions.r16)),
                    child: Image.network(
                      course.thumbnail,
                      height: 160,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      cacheWidth: 600,
                      cacheHeight: 340,
                      filterQuality: FilterQuality.medium,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          height: 160,
                          color: isDark ? AppColors.darkBackground : AppColors.divider,
                          child: const Center(
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          height: 160,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: isDark
                                  ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                                  : [AppColors.primary.withOpacity(0.12), const Color(0xFF00BFA5).withOpacity(0.08)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: Center(
                            child: Icon(
                              Icons.school_rounded,
                              size: 48,
                              color: isDark ? Colors.white24 : AppColors.primary.withOpacity(0.4),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  Positioned(
                    top: AppDimensions.s12,
                    left: AppDimensions.s12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.tagBadge.withOpacity(0.85),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        course.category.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: AppDimensions.f11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  if (isEnrolled)
                    Positioned(
                      top: AppDimensions.s12,
                      right: AppDimensions.s12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withOpacity(0.92),
                          borderRadius: BorderRadius.circular(6),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_circle_rounded, size: 14, color: Colors.white),
                            SizedBox(width: 4),
                            Text(
                              'ADQUIRIDO',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),

              Padding(
                padding: const EdgeInsets.all(AppDimensions.s16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      course.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: AppDimensions.f15,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : AppColors.textPrimary,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: AppDimensions.s12),

                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children: [
                          _buildMeta(
                            Icons.people_outline_rounded,
                            course.studentsCount > 0 ? '${course.studentsCount} alumnos' : 'Inscripción abierta',
                            isDark,
                          ),
                          const SizedBox(width: AppDimensions.s12),
                          _buildMeta(
                            Icons.layers_outlined,
                            course.lessonsCount > 0 ? '${course.lessonsCount} ${course.lessonsCount == 1 ? "clase" : "clases"}' : 'Por módulos',
                            isDark,
                          ),
                          const SizedBox(width: AppDimensions.s12),
                          _buildMeta(
                            Icons.access_time_rounded,
                            (course.duration.isNotEmpty && course.duration != '0' && course.duration != '0 horas')
                                ? course.duration
                                : 'A tu ritmo',
                            isDark,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppDimensions.s12),

                    Container(
                      height: 1,
                      color: isDark ? AppColors.darkBorder : AppColors.divider,
                    ),
                    const SizedBox(height: AppDimensions.s12),

                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isDark ? AppColors.darkBackground : AppColors.divider,
                          ),
                          child: Icon(Icons.person, size: 16, color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
                        ),
                        const SizedBox(width: AppDimensions.s8),
                        Expanded(
                          child: Text(
                            course.instructor,
                            style: TextStyle(
                              fontSize: AppDimensions.f13,
                              color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppDimensions.s12),

                    // Price or "Adquirido" Badge
                    if (isEnrolled)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withOpacity(isDark ? 0.2 : 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: const Color(0xFF10B981).withOpacity(0.4),
                            width: 1,
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_circle_rounded, size: 16, color: Color(0xFF10B981)),
                            SizedBox(width: 6),
                            Text(
                              'Adquirido',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF10B981),
                              ),
                            ),
                          ],
                        ),
                      )
                    else if (course.price > 0)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text(
                            '\$',
                            style: TextStyle(
                              fontSize: AppDimensions.f18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                          Text(
                            course.price.toStringAsFixed(0),
                            style: const TextStyle(
                              fontSize: AppDimensions.f18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'MXN',
                            style: TextStyle(
                              fontSize: AppDimensions.f12,
                              color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                            ),
                          ),
                        ],
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00BFA5).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Acceso por Beca / Cupón',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF00BFA5),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMeta(IconData icon, String label, bool isDark) {
    return Row(
      children: [
        Icon(icon, size: 14, color: isDark ? AppColors.darkTextMuted : AppColors.textMuted),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: AppDimensions.f12, 
            color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
          ),
        ),
      ],
    );
  }
}
