import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../domain/entities/course.dart';
import '../../../domain/entities/saved_lesson.dart';
import '../../viewmodels/course_viewmodel.dart';
import '../../viewmodels/download_viewmodel.dart';
import '../../viewmodels/theme_viewmodel.dart';
import '../learning/lesson_player_screen.dart';

class SavedLessonsScreen extends StatefulWidget {
  const SavedLessonsScreen({super.key});

  static Route route() {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => const SavedLessonsScreen(),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(0.06, 0.0);
        const end = Offset.zero;
        const curve = Curves.easeOutCubic;
        final tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
        final fadeTween = Tween<double>(begin: 0.0, end: 1.0).chain(CurveTween(curve: Curves.easeIn));

        return SlideTransition(
          position: animation.drive(tween),
          child: FadeTransition(
            opacity: animation.drive(fadeTween),
            child: RepaintBoundary(child: child),
          ),
        );
      },
      transitionDuration: const Duration(milliseconds: 260),
    );
  }

  @override
  State<SavedLessonsScreen> createState() => _SavedLessonsScreenState();
}

class _SavedLessonsScreenState extends State<SavedLessonsScreen> {
  @override
  void initState() {
    super.initState();
    // Carga diferida post-transición para garantizar 60 FPS sin tirones durante el push
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final downloadVm = context.read<DownloadViewModel>();
      if (downloadVm.savedLessons.isEmpty) {
        downloadVm.loadSavedLessons();
      } else {
        final route = ModalRoute.of(context);
        if (route != null && route.animation != null) {
          if (route.animation!.isCompleted) {
            downloadVm.loadSavedLessons();
          } else {
            route.animation!.addStatusListener((status) {
              if (status == AnimationStatus.completed && mounted) {
                downloadVm.loadSavedLessons();
              }
            });
          }
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.select<ThemeViewModel, bool>((vm) => vm.isDarkMode);
    final saved = context.select<DownloadViewModel, List<SavedLesson>>((vm) => vm.savedLessons);
    final totalSize = context.select<DownloadViewModel, String>((vm) => vm.totalFormattedSize);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
        elevation: 0,
        title: Text(
          'Clases Guardadas (Offline)',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 18,
            color: isDark ? Colors.white : AppColors.textPrimary,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: isDark ? Colors.white : AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: isDark ? AppColors.darkBorder : AppColors.border, height: 1),
        ),
      ),
      body: saved.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.download_for_offline_outlined, size: 72, color: isDark ? Colors.white24 : AppColors.textMuted),
                    const SizedBox(height: 16),
                    Text(
                      'No tienes clases descargadas',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : AppColors.textPrimary),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Descarga lecciones desde el reproductor de video para estudiarlas en cualquier momento sin consumir datos móviles ni requerir internet.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: isDark ? AppColors.darkTextMuted : AppColors.textMuted, height: 1.4),
                    ),
                  ],
                ),
              ),
            )
          : Column(
              children: [
                // Info Bar de Almacenamiento
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                    border: Border(bottom: BorderSide(color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0))),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${saved.length} clases descargadas',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : AppColors.textPrimary),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00BFA5).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Espacio: $totalSize',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF00BFA5)),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: saved.length,
                    itemBuilder: (context, index) {
                      final item = saved[index];
                      return RepaintBoundary(
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.darkSurface : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          leading: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: item.localFilePath.endsWith('.txt')
                                  ? const Color(0xFF00BFA5).withOpacity(0.15)
                                  : AppColors.primary.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              item.localFilePath.endsWith('.txt')
                                  ? Icons.menu_book_rounded
                                  : Icons.play_circle_fill_rounded,
                              color: item.localFilePath.endsWith('.txt')
                                  ? const Color(0xFF00BFA5)
                                  : AppColors.primary,
                              size: 26,
                            ),
                          ),
                          title: Text(
                            item.lessonTitle,
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? Colors.white : AppColors.textPrimary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            item.localFilePath.endsWith('.txt')
                                ? '${item.courseTitle} • Lectura offline'
                                : '${item.courseTitle} • ${item.formattedSize}',
                            style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextMuted : AppColors.textMuted),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                            tooltip: 'Eliminar descarga',
                            onPressed: () {
                              context.read<DownloadViewModel>().deleteLesson(item.lessonId);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Clase eliminada de descargas locales.')),
                              );
                            },
                          ),
                          onTap: () {
                            // Find matching course or build fallback course
                            final all = context.read<CourseViewModel>().enrolledCourses;
                            final course = all.firstWhere(
                              (c) => c.id.toString() == item.courseId.toString(),
                              orElse: () => Course(
                                id: item.courseId,
                                title: item.courseTitle,
                                description: 'Curso descargado para reproducción offline.',
                                category: 'Descargado',
                                instructor: 'Master Academy',
                                price: 0.0,
                                rating: 5.0,
                                studentsCount: 1,
                                duration: 'Offline',
                                thumbnail: item.thumbnail,
                                isEnrolled: true,
                              ),
                            );

                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => LessonPlayerScreen(
                                  course: course,
                                  initialLessonId: item.lessonId,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    );
                  },
                  ),
                ),
              ],
            ),
    );
  }
}