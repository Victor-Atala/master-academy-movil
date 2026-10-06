import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/services/course_interaction_service.dart';
import '../../../domain/entities/course.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/course_viewmodel.dart';
import '../../viewmodels/learning_viewmodel.dart';
import '../auth/auth_screen.dart';
import '../learning/lesson_player_screen.dart';
import '../../widgets/certificate_viewer_modal.dart';
import '../../widgets/course_access_modal.dart';
import '../../widgets/course_rating_modal.dart';
import '../../widgets/instructor_inquiry_modal.dart';
import '../../widgets/youtube_style_comments_section.dart';
import '../quiz/quiz_screen.dart';
import '../../../core/services/quiz_service.dart';
import '../../../domain/entities/quiz.dart';

class CourseDetailScreen extends StatefulWidget {
  final Course course;

  const CourseDetailScreen({super.key, required this.course});

  @override
  State<CourseDetailScreen> createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends State<CourseDetailScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<CourseReview> _reviews = [];
  List<InstructorInquiry> _inquiries = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await context.read<LearningViewModel>().loadCourseSyllabus(widget.course.id);
      if (mounted) {
        final total = context.read<LearningViewModel>().totalLessonsCount;
        if (total > 0) {
          context.read<CourseViewModel>().updateCourseLessonsCount(widget.course.id, total);
        }
      }
      _loadInteractions();
    });
  }

  Future<void> _loadInteractions() async {
    try {
      final service = sl<CourseInteractionService>();
      final reviews = await service.getCourseReviews(widget.course.id);
      final inquiries = await service.getInquiries();
      if (mounted) {
        setState(() {
          _reviews = reviews;
          _inquiries = inquiries.where((i) => i.courseId == widget.course.id || i.courseId == '1').toList();
        });
      }
    } catch (_) {}
  }

  double get _averageRating {
    if (_reviews.isEmpty) return widget.course.rating;
    final total = _reviews.fold<double>(0.0, (acc, r) => acc + r.rating);
    return double.parse((total / _reviews.length).toStringAsFixed(1));
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEnrolled = context.select<CourseViewModel, bool>(
      (vm) => vm.isCourseEnrolled(widget.course.id),
    );
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          _buildSliverHeader(),
          SliverToBoxAdapter(child: _buildMetricsSection(isDark)),
          SliverToBoxAdapter(
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelColor: AppColors.primary,
              unselectedLabelColor: isDark ? Colors.white70 : AppColors.textSecondary,
              indicatorColor: AppColors.primary,
              indicatorWeight: 3,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold),
              tabs: const [
                Tab(text: 'Visión general'),
                Tab(text: 'Temario'),
                Tab(text: 'Comunidad'),
                Tab(text: 'Instructor'),
              ],
            ),
          ),
          SliverFillRemaining(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(isDark, isEnrolled),
                _buildSyllabusTab(isDark, isEnrolled),
                _buildCommunityTab(isDark),
                _buildInstructorTab(isDark),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomAppBar(isEnrolled, isDark),
    );
  }

  Widget _buildSliverHeader() {
    final orientation = MediaQuery.of(context).orientation;
    final isLandscape = orientation == Orientation.landscape;

    return SliverAppBar(
      expandedHeight: isLandscape ? 140 : 240,
      pinned: true,
      backgroundColor: AppColors.heroBackground,
      leading: Padding(
        padding: const EdgeInsets.all(8.0),
        child: CircleAvatar(
          backgroundColor: Colors.white.withOpacity(0.9),
          child: IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
            onPressed: () => Navigator.pop(context),
          ),
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            widget.course.thumbnail.isNotEmpty
                ? Image.network(
                    widget.course.thumbnail,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(color: const Color(0xFF1E1B4B)),
                  )
                : Container(color: const Color(0xFF1E1B4B)),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withOpacity(0.8)],
                ),
              ),
            ),
            Positioned(
              bottom: 20,
              left: 20,
              right: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Cursos > ${widget.course.category}',
                    style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.course.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricsSection(bool isDark) {
    final learningVm = context.watch<LearningViewModel>();
    final realLessonCount = learningVm.totalLessonsCount > 0 ? learningVm.totalLessonsCount : widget.course.lessonsCount;
    final lessonsText = realLessonCount > 0 ? '$realLessonCount ${realLessonCount == 1 ? "clase" : "clases"}' : 'Por módulos';

    final studentsText = widget.course.studentsCount > 0
        ? '${widget.course.studentsCount} alumnos'
        : 'Inscripción abierta';
    final ratingText = widget.course.studentsCount > 0
        ? '${widget.course.rating} (${widget.course.studentsCount})'
        : '${widget.course.rating} ★';
    final durationText = widget.course.duration.isNotEmpty && widget.course.duration != '0' && widget.course.duration != '0 horas'
        ? widget.course.duration
        : 'A tu ritmo';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildMetric(Icons.star_rounded, ratingText, Colors.amber, isDark),
            const SizedBox(width: 16),
            _buildMetric(Icons.people_outline, studentsText, isDark ? AppColors.darkTextMuted : AppColors.textMuted, isDark),
            const SizedBox(width: 16),
            _buildMetric(Icons.layers_outlined, lessonsText, isDark ? AppColors.darkTextMuted : AppColors.textMuted, isDark),
            const SizedBox(width: 16),
            _buildMetric(Icons.access_time_rounded, durationText, isDark ? AppColors.darkTextMuted : AppColors.textMuted, isDark),
            const SizedBox(width: 16),
            _buildMetric(Icons.school_outlined, widget.course.level ?? 'Intermedio', isDark ? AppColors.darkTextMuted : AppColors.textMuted, isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildMetric(IconData icon, String label, Color color, bool isDark) {
    return Column(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 11, color: isDark ? Colors.white70 : AppColors.textSecondary)),
      ],
    );
  }

  Widget _buildOverviewTab(bool isDark, bool isEnrolled) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Descripción del curso',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: isDark ? Colors.white : AppColors.textPrimary),
          ),
          const SizedBox(height: 12),
          Text(
            widget.course.description,
            textAlign: TextAlign.justify,
            style: TextStyle(fontSize: 14, height: 1.6, color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
          ),
          const SizedBox(height: 24),
          Text(
            'Lo que aprenderás',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: isDark ? Colors.white : AppColors.textPrimary),
          ),
          const SizedBox(height: 12),
          _buildObjective('Domina herramientas de nivel profesional y estándares globales.', isDark),
          _buildObjective('Aprende con casos de estudio reales e interactivos.', isDark),
          _buildObjective('Obtén un certificado digital con código QR verificable.', isDark),
          _buildObjective('Acceso ilimitado al contenido y recursos descargables.', isDark),
          const SizedBox(height: 28),

          // Sección de Calificaciones y Reseñas
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Calificaciones y Reseñas',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : AppColors.textPrimary,
                ),
              ),
              OutlinedButton.icon(
                onPressed: () {
                  if (!isEnrolled) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Row(
                          children: [
                            Icon(Icons.lock_outline_rounded, color: Colors.white, size: 20),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Debes estar inscrito en este curso para poder calificarlo y dejar tu reseña.',
                                style: TextStyle(fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                        backgroundColor: const Color(0xFF0F172A),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    );
                    return;
                  }
                  CourseRatingModal.show(
                    context,
                    courseId: widget.course.id,
                    courseTitle: widget.course.title,
                    isEnrolled: isEnrolled,
                    onReviewSubmitted: (review) {
                      _loadInteractions();
                    },
                  );
                },
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: isEnrolled ? AppColors.primary : (isDark ? Colors.white24 : const Color(0xFFCBD5E1))),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: Icon(
                  isEnrolled ? Icons.rate_review_outlined : Icons.lock_outline_rounded,
                  size: 15,
                  color: isEnrolled ? AppColors.primary : (isDark ? Colors.white54 : AppColors.textMuted),
                ),
                label: Text(
                  isEnrolled ? 'Calificar' : 'Calificar (Inscritos)',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isEnrolled ? AppColors.primary : (isDark ? Colors.white54 : AppColors.textMuted),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Rating summary card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
            ),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      '$_averageRating',
                      style: TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                    Row(
                      children: List.generate(5, (idx) {
                        return Icon(
                          idx < _averageRating.floor() ? Icons.star_rounded : Icons.star_outline_rounded,
                          size: 16,
                          color: const Color(0xFFF59E0B),
                        );
                      }),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_reviews.length} opiniones',
                      style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkTextMuted : AppColors.textMuted),
                    ),
                  ],
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    children: [
                      _buildRatingBar(5, 0.85, isDark),
                      const SizedBox(height: 4),
                      _buildRatingBar(4, 0.12, isDark),
                      const SizedBox(height: 4),
                      _buildRatingBar(3, 0.03, isDark),
                      const SizedBox(height: 4),
                      _buildRatingBar(2, 0.0, isDark),
                      const SizedBox(height: 4),
                      _buildRatingBar(1, 0.0, isDark),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Top reviews list
          if (_reviews.isNotEmpty)
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _reviews.length > 3 ? 3 : _reviews.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, idx) {
                final rev = _reviews[idx];
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurface : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 12,
                                backgroundColor: AppColors.primary.withOpacity(0.15),
                                child: Text(
                                  rev.userName.isNotEmpty ? rev.userName[0].toUpperCase() : 'U',
                                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primary),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                rev.userName,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: List.generate(5, (starIdx) {
                              return Icon(
                                starIdx < rev.rating.floor() ? Icons.star_rounded : Icons.star_outline_rounded,
                                size: 13,
                                color: const Color(0xFFF59E0B),
                              );
                            }),
                          ),
                        ],
                      ),
                      if (rev.tags.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: rev.tags.map((t) {
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: isDark ? AppColors.darkCard : Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                t,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: isDark ? Colors.white70 : AppColors.textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                      const SizedBox(height: 6),
                      Text(
                        rev.reviewText,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.3,
                          color: isDark ? Colors.white70 : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildRatingBar(int stars, double pct, bool isDark) {
    return Row(
      children: [
        Text('$stars', style: TextStyle(fontSize: 10, color: isDark ? AppColors.darkTextMuted : AppColors.textMuted)),
        const SizedBox(width: 4),
        const Icon(Icons.star_rounded, size: 11, color: Color(0xFFF59E0B)),
        const SizedBox(width: 6),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 5,
              backgroundColor: isDark ? Colors.white12 : Colors.grey.shade200,
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFF59E0B)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildObjective(String text, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline_rounded, color: AppColors.success, size: 18),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: TextStyle(color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary))),
        ],
      ),
    );
  }

  Widget _buildSyllabusTab(bool isDark, bool isEnrolled) {
    final learningVm = context.watch<LearningViewModel>();

    if (learningVm.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (learningVm.sections.isEmpty) {
      return Center(
        child: Text(
          'Temario en desarrollo.',
          style: TextStyle(color: isDark ? AppColors.darkTextMuted : AppColors.textMuted),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: learningVm.sections.length,
      itemBuilder: (context, idx) {
        final section = learningVm.sections[idx];

        final bool isSectionCompleted = section.lessons.isNotEmpty && section.lessons.every((l) => l.isCompleted);
        final int completedLessonsCount = section.lessons.where((l) => l.isCompleted).length;

        final bool isFinalCert = section.isFinalCertification;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: isFinalCert
                ? (isDark ? const Color(0xFF064E3B).withOpacity(0.2) : const Color(0xFFECFDF5))
                : (isDark ? AppColors.darkSurface : AppColors.backgroundAlt),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isFinalCert
                  ? const Color(0xFF0AB39C)
                  : (isDark ? AppColors.darkBorder : AppColors.border),
              width: isFinalCert ? 1.5 : 1,
            ),
          ),
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              initiallyExpanded: idx == 0 || isFinalCert,
              iconColor: isFinalCert
                  ? const Color(0xFF0AB39C)
                  : (isSectionCompleted ? const Color(0xFF10B981) : AppColors.primary),
              collapsedIconColor: isFinalCert
                  ? const Color(0xFF0AB39C)
                  : (isSectionCompleted
                      ? const Color(0xFF10B981)
                      : (isDark ? Colors.white38 : AppColors.textMuted)),
              leading: Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: isFinalCert
                      ? const Color(0xFF0AB39C).withOpacity(0.18)
                      : (isSectionCompleted
                          ? const Color(0xFF10B981).withOpacity(0.15)
                          : (!isEnrolled
                              ? (isDark ? const Color(0xFF334155).withOpacity(0.5) : const Color(0xFFE2E8F0))
                              : AppColors.primary.withOpacity(0.12))),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  isFinalCert
                      ? Icons.workspace_premium_rounded
                      : (isSectionCompleted
                          ? Icons.check_circle_rounded
                          : (!isEnrolled ? Icons.lock_outline_rounded : Icons.folder_open_rounded)),
                  size: 16,
                  color: isFinalCert
                      ? const Color(0xFF0AB39C)
                      : (isSectionCompleted
                          ? const Color(0xFF10B981)
                          : (!isEnrolled
                              ? (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))
                              : AppColors.primary)),
                ),
              ),
              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      section.title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isFinalCert
                            ? const Color(0xFF0AB39C)
                            : (isSectionCompleted
                                ? (isDark ? Colors.white : AppColors.textPrimary)
                                : (isDark ? Colors.white : AppColors.textPrimary)),
                      ),
                    ),
                  ),
                  if (isFinalCert) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0AB39C).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'Diploma Oficial',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0AB39C),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              subtitle: Text(
                '${section.lessons.length} clases${section.evaluation != null ? ' • 1 examen' : ''}${!isEnrolled ? " • Bloqueado" : " • $completedLessonsCount completadas"}',
                style: TextStyle(
                  fontSize: 12,
                  color: isFinalCert
                      ? const Color(0xFF0AB39C)
                      : (isSectionCompleted
                          ? const Color(0xFF10B981)
                          : (isDark ? AppColors.darkTextSecondary : AppColors.textSecondary)),
                ),
              ),
              childrenPadding: const EdgeInsets.only(bottom: 8),
              children: [
                ...section.lessons.map((lesson) {
                  final bool isLessonUnlocked = isEnrolled || lesson.isFreePreview;

                  return ListTile(
                    leading: Icon(
                      lesson.isCompleted
                          ? Icons.check_circle_rounded
                          : (isLessonUnlocked
                              ? Icons.play_circle_outline_rounded
                              : Icons.lock_outline_rounded),
                      color: lesson.isCompleted
                          ? AppColors.success
                          : (isLessonUnlocked
                              ? AppColors.primary
                              : (isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8))),
                      size: 20,
                    ),
                    title: Text(
                      lesson.title,
                      style: TextStyle(
                        fontSize: 13,
                        color: isLessonUnlocked
                            ? (isDark ? Colors.white : AppColors.textPrimary)
                            : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (lesson.isFreePreview)
                          Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: AppColors.success.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                            child: const Text('Gratis', style: TextStyle(color: AppColors.success, fontSize: 10, fontWeight: FontWeight.bold)),
                          )
                        else if (!isEnrolled)
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: Icon(
                              Icons.lock_rounded,
                              size: 13,
                              color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                            ),
                          ),
                        Text(lesson.formattedDuration, style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkTextMuted : AppColors.textMuted)),
                      ],
                    ),
                    onTap: () async {
                      final authVm = context.read<AuthViewModel>();
                      final isAuthenticated = authVm.status == AuthStatus.authenticated;
                      if (isEnrolled || lesson.isFreePreview) {
                        learningVm.selectLesson(lesson);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => LessonPlayerScreen(course: widget.course)),
                        ).then((_) {
                          if (mounted) {
                            context.read<LearningViewModel>().loadCourseSyllabus(widget.course.id);
                          }
                        });
                      } else if (!isAuthenticated) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const AuthScreen()),
                        );
                      } else {
                        final redeemed = await CourseAccessModal.show(context, widget.course);
                        if (redeemed == true && mounted) {
                          setState(() {});
                        }
                      }
                    },
                  );
                }),
                if (section.evaluation != null)
                  _buildEvaluationItem(section.evaluation!, isDark, isEnrolled),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEvaluationItem(Quiz quiz, bool isDark, bool isEnrolled) {
    return FutureBuilder<bool>(
      future: sl<QuizService>().hasPassed(quiz.id),
      builder: (context, snapshot) {
        final bool isPassed = snapshot.data == true;

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: quiz.isFinal
                  ? const Color(0xFF0AB39C).withOpacity(0.5)
                  : (isDark ? AppColors.darkBorder : AppColors.border),
              width: quiz.isFinal ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isPassed
                      ? const Color(0xFF10B981).withOpacity(0.15)
                      : (quiz.isFinal
                          ? const Color(0xFFF59E0B).withOpacity(0.15)
                          : AppColors.primary.withOpacity(0.12)),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isPassed
                      ? Icons.check_circle_rounded
                      : (quiz.isFinal ? Icons.workspace_premium_rounded : Icons.assignment_turned_in_rounded),
                  size: 18,
                  color: isPassed
                      ? const Color(0xFF10B981)
                      : (quiz.isFinal ? const Color(0xFFD97706) : AppColors.primary),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: quiz.isFinal
                                ? const Color(0xFFF59E0B).withOpacity(0.12)
                                : AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            quiz.isFinal ? 'EXAMEN FINAL DIPLOMA' : 'EVALUACIÓN',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: quiz.isFinal ? const Color(0xFFD97706) : AppColors.primary,
                            ),
                          ),
                        ),
                        if (isPassed) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withOpacity(0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'APTO',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF10B981),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      quiz.title,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${quiz.questions.length} preguntas • Mínimo ${quiz.passingScore}%',
                      style: TextStyle(
                        fontSize: 10,
                        color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () async {
                  final authVm = context.read<AuthViewModel>();
                  final isAuthenticated = authVm.status == AuthStatus.authenticated;
                  if (isEnrolled) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => QuizScreen(
                          quiz: quiz,
                          course: widget.course,
                          onCompleted: () {
                            if (mounted) {
                              setState(() {});
                              context.read<LearningViewModel>().loadCourseSyllabus(widget.course.id);
                            }
                          },
                        ),
                      ),
                    ).then((_) {
                      if (mounted) setState(() {});
                    });
                  } else if (!isAuthenticated) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AuthScreen()),
                    );
                  } else {
                    final redeemed = await CourseAccessModal.show(context, widget.course);
                    if (redeemed == true && mounted) {
                      setState(() {});
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: isPassed
                      ? (isDark ? AppColors.darkCard : Colors.grey.shade100)
                      : (quiz.isFinal ? const Color(0xFF0AB39C) : AppColors.primary),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  isPassed ? 'Ver nota' : 'Rendir',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isPassed
                        ? (isDark ? Colors.white70 : AppColors.textSecondary)
                        : Colors.white,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCommunityTab(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.primary.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.forum_outlined, color: AppColors.primary, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Comunidad de Aprendizaje',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Comparte recomendaciones, resuelve dudas y debate sobre los temas del curso con otros alumnos.',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          YoutubeStyleCommentsSection(
            courseId: widget.course.id,
            courseTitle: widget.course.title,
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildInstructorTab(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Instructor profile card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 44,
                  backgroundColor: isDark ? AppColors.darkBorder : AppColors.divider,
                  child: const Icon(Icons.person_rounded, size: 52, color: AppColors.primary),
                ),
                const SizedBox(height: 14),
                Text(
                  widget.course.instructor,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Instructor Certificado Master Academy',
                    style: TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Especialista con amplia trayectoria profesional en el sector, enfocado en metodologías prácticas, resolución de dudas operativas y desarrollo de competencias de alto impacto.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      InstructorInquiryModal.show(
                        context,
                        courseId: widget.course.id,
                        courseTitle: widget.course.title,
                        instructorName: widget.course.instructor,
                        onInquirySent: (inquiry) {
                          _loadInteractions();
                        },
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.mark_chat_unread_rounded, size: 18),
                    label: const Text('Contactar al Instructor', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Inquiries History Section
          Row(
            children: [
              const Icon(Icons.question_answer_rounded, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                'Mis Consultas y Respuestas',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              Text(
                '${_inquiries.length} registradas',
                style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkTextMuted : AppColors.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (_inquiries.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
              ),
              child: Column(
                children: [
                  Icon(Icons.live_help_outlined, size: 36, color: isDark ? Colors.white30 : Colors.grey.shade400),
                  const SizedBox(height: 8),
                  Text(
                    '¿Tienes alguna duda sobre este curso?',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? Colors.white : AppColors.textPrimary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Haz una consulta al docente y obtén asesoría técnica directa.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextMuted : AppColors.textMuted),
                  ),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _inquiries.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final inq = _inquiries[index];
                final isAnswered = inq.reply != null && inq.reply!.isNotEmpty;

                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurface : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              inq.subject,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: isDark ? Colors.white : AppColors.textPrimary,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: isAnswered
                                  ? const Color(0xFF10B981).withOpacity(0.15)
                                  : const Color(0xFFF59E0B).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isAnswered ? Icons.check_circle_outline_rounded : Icons.hourglass_top_rounded,
                                  size: 12,
                                  color: isAnswered ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  inq.status,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: isAnswered ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        inq.message,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.3,
                          color: isDark ? Colors.white70 : AppColors.textSecondary,
                        ),
                      ),
                      if (isAnswered) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.school_rounded, size: 14, color: AppColors.primary),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Respuesta de ${inq.instructorName}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                inq.reply!,
                                style: TextStyle(
                                  fontSize: 12,
                                  height: 1.3,
                                  color: isDark ? Colors.white : AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildBottomAppBar(bool isEnrolled, bool isDark) {
    final authVm = context.watch<AuthViewModel>();
    final learningVm = context.watch<LearningViewModel>();
    final isAuthenticated = authVm.status == AuthStatus.authenticated;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkBackground : Colors.white,
        border: Border(top: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.border)),
      ),
      child: SafeArea(
        child: isEnrolled
            ? Row(
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Estado',
                        style: TextStyle(color: isDark ? AppColors.darkTextMuted : AppColors.textMuted, fontSize: 12),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.check_circle_rounded, color: AppColors.success, size: 16),
                          SizedBox(width: 4),
                          Text(
                            'Adquirido',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.success,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Builder(
                      builder: (context) {
                        final isCompleted = learningVm.progressPercentage >= 100.0 ||
                            (learningVm.totalLessonsCount > 0 &&
                                learningVm.completedLessonsCount >= learningVm.totalLessonsCount);

                        return ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            backgroundColor: isCompleted ? const Color(0xFFD97706) : AppColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          onPressed: () {
                            if (isCompleted) {
                              CertificateViewerModal.show(context, widget.course);
                            } else {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => LessonPlayerScreen(course: widget.course)),
                              ).then((_) {
                                if (mounted) {
                                  context.read<LearningViewModel>().loadCourseSyllabus(widget.course.id);
                                }
                              });
                            }
                          },
                          icon: isCompleted
                              ? const Icon(Icons.workspace_premium_rounded, size: 20)
                              : const Icon(Icons.play_circle_fill_rounded, size: 20),
                          label: Text(
                            isCompleted ? 'Descargar certificado' : 'Continuar curso',
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              )
            : (!isAuthenticated
                ? SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const AuthScreen()),
                        );
                      },
                      icon: const Icon(Icons.login_rounded, size: 20),
                      label: const Text(
                        'Inicia sesión para inscribirte',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                    ),
                  )
                : Row(
                    children: [
                      // Opción 1: Agregar código
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            foregroundColor: const Color(0xFF3B82F6),
                            side: const BorderSide(color: Color(0xFF3B82F6), width: 1.5),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          onPressed: () async {
                            final redeemed = await CourseAccessModal.show(context, widget.course);
                            if (redeemed == true && mounted) {
                              setState(() {});
                            }
                          },
                          icon: const Icon(Icons.confirmation_number_outlined, size: 18),
                          label: const Text(
                            'Agregar código',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Opción 2: Compra en web
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          onPressed: () async {
                            final uri = Uri.parse(AppConstants.coursePurchaseWebUrl);
                            try {
                              final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
                              if (!launched && context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Visita https://masteracademy.mx/')),
                                );
                              }
                            } catch (_) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Visita https://masteracademy.mx/')),
                                );
                              }
                            }
                          },
                          icon: const Icon(Icons.open_in_new_rounded, size: 18),
                          label: const Text(
                            'Compra en web',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  )),
      ),
    );
  }
}
