import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/common/ui_state.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../viewmodels/course_viewmodel.dart';
import '../../../domain/entities/course.dart';
import '../../widgets/course_card.dart';
import '../../widgets/hero_section.dart';
import '../../widgets/category_card.dart';
import '../course_detail/course_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  final Function(int)? onNavigate;
  final VoidCallback? onViewAll;
  final bool isActive;

  const HomeScreen({
    super.key,
    this.onNavigate,
    this.onViewAll,
    this.isActive = true,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  late final ScrollController _featuredScrollController;
  Timer? _carouselTimer;

  @override
  void initState() {
    super.initState();
    _featuredScrollController = ScrollController();
    if (widget.isActive) {
      _startAutoScroll();
    }

    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CourseViewModel>().fetchCourses();
    });
  }

  @override
  void didUpdateWidget(HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isActive != widget.isActive) {
      if (widget.isActive) {
        _startAutoScroll();
      } else {
        _carouselTimer?.cancel();
      }
    }
  }

  void _startAutoScroll() {
    _carouselTimer?.cancel();
    if (!widget.isActive) return;
    _carouselTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (_featuredScrollController.hasClients && widget.isActive) {
        const double cardWidth = 280.0 + AppDimensions.s16;
        final double nextOffset = _featuredScrollController.offset + cardWidth;
        _featuredScrollController.animateTo(
          nextOffset,
          duration: const Duration(milliseconds: 700),
          curve: Curves.easeInOutCubic,
        );
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      context.read<CourseViewModel>().fetchCourses();
      if (widget.isActive) {
        _startAutoScroll();
      }
    } else if (state == AppLifecycleState.paused) {
      _carouselTimer?.cancel();
    }
  }

  @override
  void dispose() {
    _carouselTimer?.cancel();
    _featuredScrollController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final courseVm = context.watch<CourseViewModel>();
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () => courseVm.fetchCourses(force: true),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: EdgeInsets.zero,
        children: [
          HeroSection(
            onExplore: () {
              if (widget.onNavigate != null) {
                widget.onNavigate!(1);
              }
            },
          ),

          // Sección de Cursos Destacados
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppDimensions.s20,
              AppDimensions.s24,
              AppDimensions.s20,
              AppDimensions.s16,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    l10n.featuredCourses,
                    style: TextStyle(
                      fontSize: AppDimensions.f18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : AppColors.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: AppDimensions.s8),
                TextButton(
                  onPressed: widget.onViewAll,
                  child: Text(
                    '${l10n.viewAll} >',
                    style: const TextStyle(
                      fontSize: AppDimensions.f14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),

          _buildContent(context, courseVm.state, l10n, isDark),
          const SizedBox(height: AppDimensions.s32),

          // Encabezado de la sección Categorías
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppDimensions.s20,
              0,
              AppDimensions.s20,
              AppDimensions.s16,
            ),
            child: Text(
              'Categorías',
              style: TextStyle(
                fontSize: AppDimensions.f18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : AppColors.textPrimary,
              ),
            ),
          ),

          // Cuadrícula de 2 columnas de Categorías optimizada (Renderizado dinámico en tiempo real)
          Builder(
            builder: (context) {
              final dynamicCategories = _getCategories(courseVm);
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppDimensions.s20),
                child: Column(
                  children: [
                    for (int i = 0; i < dynamicCategories.length; i += 2)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppDimensions.s12),
                        child: Row(
                          children: [
                            Expanded(
                              child: CategoryCard(
                                category: dynamicCategories[i],
                                onTap: () {
                                  context.read<CourseViewModel>().selectCategory(dynamicCategories[i].title);
                                  if (widget.onNavigate != null) {
                                    widget.onNavigate!(1);
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: AppDimensions.s12),
                            Expanded(
                              child: i + 1 < dynamicCategories.length
                                  ? CategoryCard(
                                      category: dynamicCategories[i + 1],
                                      onTap: () {
                                        context.read<CourseViewModel>().selectCategory(dynamicCategories[i + 1].title);
                                        if (widget.onNavigate != null) {
                                          widget.onNavigate!(1);
                                        }
                                      },
                                    )
                                  : const SizedBox.shrink(),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              );
            },
          ),

          if (courseVm.state is UiSuccess<List<Course>>) ...[
            const SizedBox(height: AppDimensions.s24),
            _buildRecentlyAddedSection(
              context,
              (courseVm.state as UiSuccess<List<Course>>).data,
              isDark,
            ),
          ],
          const SizedBox(height: AppDimensions.s32),

          // Footer
          _buildFooter(isDark),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, UiState<List<Course>> state, AppLocalizations l10n, bool isDark) {
    return switch (state) {
      UiInitial() || UiLoading() => const Center(
        child: Padding(
          padding: EdgeInsets.all(AppDimensions.s32),
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      ),
      UiError(failure: final f) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: AppDimensions.s48, color: AppColors.error),
            const SizedBox(height: AppDimensions.s16),
            Text(
              f.message,
              style: TextStyle(color: isDark ? Colors.white70 : AppColors.textSecondary),
            ),
            const SizedBox(height: AppDimensions.s12),
            ElevatedButton(
              onPressed: () => context.read<CourseViewModel>().fetchCourses(force: true),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              child: Text(l10n.retry, style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
      UiSuccess(data: final courses) => _buildFeaturedCarousel(courses),
    };
  }

  Widget _buildFeaturedCarousel(List<Course> courses) {
    final featuredItems = courses.take(4).toList();
    if (featuredItems.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 410,
      child: ListView.builder(
        controller: _featuredScrollController,
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: AppDimensions.s20),
        itemBuilder: (context, index) {
          final course = featuredItems[index % featuredItems.length];
          return Container(
            width: 290,
            margin: const EdgeInsets.only(right: AppDimensions.s16),
            child: CourseCard(
              course: course,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CourseDetailScreen(course: course),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  List<CategoryItem> _getCategories(CourseViewModel courseVm) {
    final courses = (courseVm.state is UiSuccess<List<Course>>)
        ? (courseVm.state as UiSuccess<List<Course>>).data
        : <Course>[];

    final Map<String, int> counts = {};
    for (final c in courses) {
      final name = c.category.trim();
      if (name.isNotEmpty) {
        counts[name] = (counts[name] ?? 0) + 1;
      }
    }

    if (courseVm.categories.isNotEmpty) {
      return courseVm.categories.map((cat) {
        final realCount = counts[cat.name] ?? cat.coursesCount;
        return CategoryItem(
          title: cat.name,
          count: realCount,
          icon: _mapIconForCategory(cat.name),
        );
      }).toList();
    }

    return [
      CategoryItem(
        title: 'Tecnología e información',
        count: counts['Tecnología e información'] ?? counts['Tecnología'] ?? 0,
        icon: Icons.memory_rounded,
      ),
      CategoryItem(
        title: 'Seguridad Industrial',
        count: counts['Seguridad Industrial'] ?? 0,
        icon: Icons.engineering_rounded,
      ),
      CategoryItem(
        title: 'Negocios y Finanzas',
        count: counts['Negocios y Finanzas'] ?? counts['Negocios'] ?? 0,
        icon: Icons.work_outline_rounded,
      ),
      CategoryItem(
        title: 'Salud y Bienestar',
        count: counts['Salud y Bienestar'] ?? counts['Salud'] ?? 0,
        icon: Icons.favorite_border_rounded,
      ),
      CategoryItem(
        title: 'Legal y Normativa',
        count: counts['Legal y Normativa'] ?? counts['Legal'] ?? 0,
        icon: Icons.balance_rounded,
      ),
      CategoryItem(
        title: 'Medio Ambiente',
        count: counts['Medio Ambiente'] ?? 0,
        icon: Icons.eco_outlined,
      ),
    ];
  }

  IconData _mapIconForCategory(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('tecno') || lower.contains('info') || lower.contains('ciber')) {
      return Icons.memory_rounded;
    } else if (lower.contains('seguridad') || lower.contains('riesgo') || lower.contains('indus')) {
      return Icons.engineering_rounded;
    } else if (lower.contains('negoc') || lower.contains('finan') || lower.contains('admin')) {
      return Icons.work_outline_rounded;
    } else if (lower.contains('salud') || lower.contains('bienestar') || lower.contains('medic')) {
      return Icons.favorite_border_rounded;
    } else if (lower.contains('legal') || lower.contains('norma') || lower.contains('ley')) {
      return Icons.balance_rounded;
    } else if (lower.contains('medio') || lower.contains('ambien') || lower.contains('eco')) {
      return Icons.eco_outlined;
    }
    return Icons.school_rounded;
  }

  Widget _buildRecentlyAddedSection(
    BuildContext context,
    List<Course> courses,
    bool isDark,
  ) {
    final recentCourses = courses.reversed.take(4).toList();
    if (recentCourses.isEmpty) return const SizedBox.shrink();

    final titleColor = isDark ? Colors.white : AppColors.textPrimary;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.s20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Agregado recientemente',
                style: TextStyle(
                  fontSize: AppDimensions.f18,
                  fontWeight: FontWeight.bold,
                  color: titleColor,
                ),
              ),
              if (widget.onViewAll != null)
                TextButton(
                  onPressed: widget.onViewAll,
                  child: const Text(
                    'Ver todos',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppDimensions.s16),
          // Renderizado directo en columna para máxima fluidez y cero tirones en scroll vertical
          Column(
            children: [
              for (final course in recentCourses)
                CourseCard(
                  course: course,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CourseDetailScreen(course: course),
                      ),
                    );
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(bool isDark) {
    final backgroundColor = isDark ? AppColors.darkSurface : const Color(0xFFF1F5F9);
    final borderColor = isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0);
    final textColor = isDark ? Colors.white : AppColors.textPrimary;
    final mutedColor = isDark ? AppColors.darkTextMuted : const Color(0xFF64748B);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.s20,
        vertical: AppDimensions.s32,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border(
          top: BorderSide(color: borderColor, width: 1),
        ),
      ),
      child: Column(
        children: [
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: 'Master',
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w900,
                    fontSize: 20,
                  ),
                ),
                const TextSpan(
                  text: 'Academy',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w900,
                    fontSize: 20,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Plataforma de formación y desarrollo profesional continuo.',
            textAlign: TextAlign.center,
            style: TextStyle(color: mutedColor, fontSize: 12),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.language_rounded, size: 14, color: AppColors.primary),
              const SizedBox(width: 4),
              const Text(
                'masteracademy.mx',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 16),
              Icon(Icons.email_outlined, size: 14, color: mutedColor),
              const SizedBox(width: 4),
              Text(
                'ayuda@masteracademy.mx',
                style: TextStyle(color: mutedColor, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Divider(color: borderColor, height: 1),
          const SizedBox(height: 16),
          Text(
            '© 2026 MasterAcademy. Todos los derechos reservados.',
            textAlign: TextAlign.center,
            style: TextStyle(color: mutedColor, fontSize: 11),
          ),
        ],
      ),
    );
  }
}