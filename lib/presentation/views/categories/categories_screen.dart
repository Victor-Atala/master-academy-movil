import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../domain/entities/course.dart';
import '../../viewmodels/course_viewmodel.dart';
import '../course_detail/course_detail_screen.dart';

import '../../../core/common/ui_state.dart';
import '../../../core/constants/app_dimensions.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  String _selectedCategory = 'Todas';
  final TextEditingController _searchController = TextEditingController();

  final List<String> _defaultCategories = [
    'Todas',
    'Tecnologías e información',
    'Seguridad Industrial',
    'Negocios',
    'Salud y Prevención',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final vm = context.read<CourseViewModel>();
      vm.fetchCategories();
      vm.fetchCourses();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final courseVm = context.watch<CourseViewModel>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Catálogo de Cursos',
          style: TextStyle(
            color: isDark ? Colors.white : AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search Bar & Filter Button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppDimensions.s20, vertical: AppDimensions.s10),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) => setState(() {}),
                    style: TextStyle(color: isDark ? Colors.white : AppColors.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Buscar cursos...',
                      hintStyle: TextStyle(color: isDark ? AppColors.darkTextMuted : AppColors.textMuted),
                      prefixIcon: Icon(Icons.search, color: isDark ? AppColors.darkTextMuted : AppColors.textMuted),
                      filled: true,
                      fillColor: isDark ? AppColors.darkSurface : AppColors.backgroundAlt,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppDimensions.r12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    ),
                  ),
                ),
                const SizedBox(width: AppDimensions.s12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(AppDimensions.r12),
                  ),
                  child: const Icon(Icons.tune_rounded, color: Colors.white),
                ),
              ],
            ),
          ),

          // Categories Chips
          SizedBox(
            height: 60,
            child: Builder(
              builder: (context) {
                final displayCategories = courseVm.categories.isNotEmpty
                    ? ['Todas', ...courseVm.categories.map((c) => c.name)]
                    : _defaultCategories;

                // Sync with CourseViewModel if changed externally
                final currentSelected = courseVm.selectedCategory != 'Todos' && courseVm.selectedCategory.isNotEmpty
                    ? courseVm.selectedCategory
                    : _selectedCategory;

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: AppDimensions.s16),
                  scrollDirection: Axis.horizontal,
                  itemCount: displayCategories.length,
                  itemBuilder: (context, index) {
                    final cat = displayCategories[index];
                    final isSelected = currentSelected == cat ||
                        (currentSelected == 'Todas' && cat == 'Todas') ||
                        (currentSelected == 'Todos' && cat == 'Todas');
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
                      child: FilterChip(
                        label: Text(cat),
                        selected: isSelected,
                        onSelected: (val) {
                          setState(() => _selectedCategory = cat);
                          courseVm.selectCategory(cat == 'Todas' ? 'Todos' : cat);
                        },
                        backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
                        selectedColor: AppColors.primary,
                        checkmarkColor: Colors.white,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : (isDark ? Colors.white70 : AppColors.textPrimary),
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          fontSize: AppDimensions.f13,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppDimensions.r24),
                          side: BorderSide(color: isSelected ? AppColors.primary : (isDark ? AppColors.darkBorder : AppColors.border)),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),

          Expanded(
            child: _buildContent(courseVm.state, isDark),
          ),
        ],
      ),
    );
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

  bool _matchesCategory(Course course, String selected) {
    if (selected == 'Todas' || selected == 'Todos' || selected.isEmpty) return true;
    final cCat = _normalize(course.category);
    final sCat = _normalize(selected);

    if (cCat == sCat) return true;
    if (cCat.contains(sCat) || sCat.contains(cCat)) return true;

    // Keyword matching
    if (sCat.contains('tecno') && (cCat.contains('tecno') || cCat.contains('desarrollo') || cCat.contains('program') || cCat.contains('software') || cCat.contains('web') || cCat.contains('movil') || cCat.contains('ciber'))) return true;
    if (sCat.contains('seguridad') && cCat.contains('seguridad')) return true;
    if (sCat.contains('negocio') && (cCat.contains('negocio') || cCat.contains('admin') || cCat.contains('finanz') || cCat.contains('liderazgo') || cCat.contains('pyme'))) return true;
    if (sCat.contains('salud') && (cCat.contains('salud') || cCat.contains('bienestar') || cCat.contains('prevenc') || cCat.contains('primeros') || cCat.contains('brigada'))) return true;
    if (sCat.contains('legal') && (cCat.contains('legal') || cCat.contains('normat') || cCat.contains('ley'))) return true;
    if (sCat.contains('ambiente') && (cCat.contains('ambiente') || cCat.contains('eco') || cCat.contains('sustent'))) return true;

    return false;
  }

  Widget _buildContent(UiState<List<Course>> state, bool isDark) {
    return switch (state) {
      UiInitial() || UiLoading() => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
      UiError(failure: final f) => Center(child: Text(f.message, style: TextStyle(color: isDark ? Colors.white70 : AppColors.textSecondary))),
      UiSuccess(data: final courses) => _buildList(courses, isDark),
    };
  }

  Widget _buildList(List<Course> courses, bool isDark) {
    final courseVm = context.read<CourseViewModel>();
    final activeCat = (courseVm.selectedCategory != 'Todos' && courseVm.selectedCategory.isNotEmpty)
        ? courseVm.selectedCategory
        : _selectedCategory;
    final query = _normalize(_searchController.text);

    final filteredCourses = courses.where((course) {
      final matchesCategory = _matchesCategory(course, activeCat);
      final matchesSearch = query.isEmpty ||
          _normalize(course.title).contains(query) ||
          _normalize(course.description).contains(query) ||
          _normalize(course.instructor).contains(query) ||
          _normalize(course.category).contains(query);
      return matchesCategory && matchesSearch;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppDimensions.s20, vertical: AppDimensions.s8),
          child: Text(
            '${filteredCourses.length} cursos encontrados',
            style: TextStyle(
              color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
              fontSize: AppDimensions.f13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: AppDimensions.s20),
            itemCount: filteredCourses.length,
            itemBuilder: (context, index) {
              return _CourseSearchCard(
                course: filteredCourses[index],
                isDark: isDark,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CourseDetailScreen(course: filteredCourses[index]),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _CourseSearchCard extends StatelessWidget {
  final Course course;
  final VoidCallback onTap;
  final bool isDark;

  const _CourseSearchCard({required this.course, required this.onTap, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(AppDimensions.r16),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimensions.r16),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Thumbnail
              ClipRRect(
                borderRadius: BorderRadius.circular(AppDimensions.r12),
                child: course.thumbnail.isNotEmpty
                    ? Image.network(
                        course.thumbnail,
                        width: 100,
                        height: 80,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          width: 100,
                          height: 80,
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
                              size: 36,
                              color: isDark ? Colors.white38 : AppColors.primary,
                            ),
                          ),
                        ),
                      )
                    : Container(
                        width: 100,
                        height: 80,
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
                            size: 36,
                            color: isDark ? Colors.white38 : AppColors.primary,
                          ),
                        ),
                      ),
              ),
              const SizedBox(width: 16),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.star_rounded, color: Colors.amber, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          course.studentsCount > 0
                              ? '${course.rating} (${course.studentsCount})'
                              : '${course.rating} ★',
                          style: TextStyle(
                            fontSize: 11, 
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white70 : AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      course.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isDark ? Colors.white : AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      course.instructor,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary, fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    Builder(
                      builder: (context) {
                        final isEnrolled = course.isEnrolled ||
                            context.select<CourseViewModel, bool>(
                              (vm) => vm.isCourseEnrolled(course.id),
                            );

                        if (isEnrolled) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withOpacity(isDark ? 0.2 : 0.1),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: const Color(0xFF10B981).withOpacity(0.4),
                                width: 1,
                              ),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.check_circle_rounded, size: 14, color: Color(0xFF10B981)),
                                SizedBox(width: 4),
                                Text(
                                  'Adquirido',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF10B981),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '\$${(course.price * 1.5).toStringAsFixed(0)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '\$${course.price.toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(width: 2),
                            Text('MXN', style: TextStyle(fontSize: 10, color: isDark ? AppColors.darkTextMuted : AppColors.textMuted)),
                          ],
                        );
                      },
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
}
