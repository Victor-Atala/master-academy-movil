import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/common/ui_state.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/services/student_notes_service.dart';
import '../../../domain/entities/course.dart';
import '../../viewmodels/course_viewmodel.dart';
import '../learning/lesson_player_screen.dart';

class StudentNotebookScreen extends StatefulWidget {
  const StudentNotebookScreen({super.key});

  static Route<void> route() {
    return MaterialPageRoute(builder: (_) => const StudentNotebookScreen());
  }

  @override
  State<StudentNotebookScreen> createState() => _StudentNotebookScreenState();
}

class _StudentNotebookScreenState extends State<StudentNotebookScreen> {
  final StudentNotesService _notesService = sl<StudentNotesService>();
  final TextEditingController _searchController = TextEditingController();

  List<StudentNote> _allNotes = [];
  bool _isLoading = true;
  String _selectedCourseFilter = 'Todos';

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadNotes() async {
    setState(() => _isLoading = true);
    final notes = await _notesService.getAllNotes();
    if (mounted) {
      setState(() {
        _allNotes = notes;
        _isLoading = false;
      });
    }
  }

  List<String> get _courseFilters {
    final uniqueCourses = _allNotes.map((n) => n.courseTitle).toSet().toList();
    uniqueCourses.sort();
    return ['Todos', ...uniqueCourses];
  }

  List<StudentNote> get _filteredNotes {
    final query = _searchController.text.trim().toLowerCase();
    return _allNotes.where((n) {
      final matchesFilter =
          _selectedCourseFilter == 'Todos' || n.courseTitle == _selectedCourseFilter;
      if (!matchesFilter) return false;

      if (query.isEmpty) return true;
      return n.content.toLowerCase().contains(query) ||
          n.lessonTitle.toLowerCase().contains(query) ||
          n.courseTitle.toLowerCase().contains(query);
    }).toList();
  }

  void _showEditNoteModal(StudentNote note) {
    final editController = TextEditingController(text: note.content);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Editar Apunte',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                Text(
                  '${note.courseTitle} • ${note.lessonTitle}',
                  style: const TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkBackground : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
                  ),
                  child: TextField(
                    controller: editController,
                    maxLines: 6,
                    style: TextStyle(color: isDark ? Colors.white : AppColors.textPrimary, fontSize: 13, height: 1.4),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText: 'Escribe tu nota aquí...',
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () async {
                      final newText = editController.text.trim();
                      if (newText.isEmpty) {
                        await _notesService.deleteNote(note.lessonId);
                      } else {
                        await _notesService.saveNote(
                          courseId: note.courseId,
                          courseTitle: note.courseTitle,
                          lessonId: note.lessonId,
                          lessonTitle: note.lessonTitle,
                          content: newText,
                        );
                      }
                      if (ctx.mounted) Navigator.pop(ctx);
                      _loadNotes();
                    },
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: const Text('Guardar Cambios', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _confirmDeleteNote(StudentNote note) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Eliminar apunte?'),
        content: Text('Se eliminará tu nota de "${note.lessonTitle}". Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await _notesService.deleteNote(note.lessonId);
              _loadNotes();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Apunte eliminado')),
                );
              }
            },
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  void _navigateToLesson(StudentNote note) {
    final courseVm = context.read<CourseViewModel>();
    final List<Course> allCourses = List<Course>.from(courseVm.enrolledCourses);
    if (courseVm.state is UiSuccess<List<Course>>) {
      final catalog = (courseVm.state as UiSuccess<List<Course>>).data;
      for (final c in catalog) {
        if (!allCourses.any((x) => x.id == c.id)) {
          allCourses.add(c);
        }
      }
    }

    final matchedCourse = allCourses.firstWhere(
      (c) => c.id == '${note.courseId}',
      orElse: () => allCourses.isNotEmpty
          ? allCourses.first
          : Course(
              id: '${note.courseId}',
              title: note.courseTitle,
              description: '',
              category: '',
              instructor: 'Instructor Master Academy',
              price: 0,
              rating: 5,
              studentsCount: 0,
              duration: '',
              thumbnail: '',
            ),
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LessonPlayerScreen(
          course: matchedCourse,
          initialLessonId: note.lessonId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final filtered = _filteredNotes;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: isDark ? Colors.white : AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Mis Apuntes (Bloc de Notas)',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : AppColors.textPrimary,
              ),
            ),
            Text(
              '${_allNotes.length} notas guardadas en tus cursos',
              style: const TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Buscador
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              style: TextStyle(color: isDark ? Colors.white : AppColors.textPrimary, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Buscar en mis notas o clases...',
                hintStyle: TextStyle(color: isDark ? AppColors.darkTextMuted : AppColors.textMuted, fontSize: 13),
                prefixIcon: Icon(Icons.search_rounded, size: 20, color: isDark ? AppColors.darkTextMuted : AppColors.textMuted),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                        },
                      )
                    : null,
                filled: true,
                fillColor: isDark ? AppColors.darkSurface : Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.border),
                ),
              ),
            ),
          ),

          // Filtros por Curso
          if (_courseFilters.length > 2)
            SizedBox(
              height: 38,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _courseFilters.length,
                itemBuilder: (ctx, i) {
                  final filter = _courseFilters[i];
                  final isSelected = filter == _selectedCourseFilter;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(filter, style: TextStyle(fontSize: 11, fontWeight: isSelected ? FontWeight.bold : FontWeight.w500)),
                      selected: isSelected,
                      onSelected: (_) => setState(() => _selectedCourseFilter = filter),
                      selectedColor: AppColors.primary,
                      labelStyle: TextStyle(color: isSelected ? Colors.white : (isDark ? Colors.white70 : AppColors.textPrimary)),
                      backgroundColor: isDark ? AppColors.darkSurface : Colors.grey.shade100,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      side: BorderSide(color: isSelected ? AppColors.primary : (isDark ? AppColors.darkBorder : AppColors.border)),
                    ),
                  );
                },
              ),
            ),

          const SizedBox(height: 8),

          // Lista de Notas
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                    ? Center(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.edit_note_rounded, size: 64, color: AppColors.primary),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _allNotes.isEmpty
                                    ? 'Aún no tienes notas guardadas'
                                    : 'No se encontraron notas coincidentes',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _allNotes.isEmpty
                                    ? 'Escribe tus apuntes dentro del reproductor de cualquier clase en la pestaña "Recursos y Notas". Se sincronizarán automáticamente aquí.'
                                    : 'Prueba buscando con otra palabra o selecciona otro curso.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadNotes,
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                          itemCount: filtered.length,
                          itemBuilder: (ctx, idx) {
                            final note = filtered[idx];
                            return _buildNoteCard(note, isDark);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoteCard(StudentNote note, bool isDark) {
    final dateStr =
        '${note.updatedAt.day.toString().padLeft(2, '0')}/${note.updatedAt.month.toString().padLeft(2, '0')}/${note.updatedAt.year}';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.25 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header con curso y fecha
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    note.courseTitle,
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Spacer(),
                Text(
                  dateStr,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Título de la clase
            Row(
              children: [
                const Icon(Icons.play_circle_fill_rounded, size: 16, color: Color(0xFF00BFA5)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    note.lessonTitle,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Contenido del apunte
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B).withOpacity(0.5) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
              ),
              child: Text(
                note.content,
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.45,
                  color: isDark ? Colors.white70 : const Color(0xFF334155),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Acciones de la nota
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => _navigateToLesson(note),
                  icon: const Icon(Icons.open_in_new_rounded, size: 14, color: AppColors.primary),
                  label: const Text('Ir a la clase', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary)),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: const Size(0, 30),
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  tooltip: 'Editar apunte',
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  color: isDark ? Colors.white70 : AppColors.textSecondary,
                  onPressed: () => _showEditNoteModal(note),
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  padding: EdgeInsets.zero,
                ),
                IconButton(
                  tooltip: 'Compartir nota',
                  icon: const Icon(Icons.share_outlined, size: 16),
                  color: isDark ? Colors.white70 : AppColors.textSecondary,
                  onPressed: () {
                    Share.share(
                      '📝 Mis apuntes de "${note.lessonTitle}" (${note.courseTitle}):\n\n${note.content}\n\nEstudiado en Master Academy',
                      subject: 'Apunte: ${note.lessonTitle}',
                    );
                  },
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  padding: EdgeInsets.zero,
                ),
                IconButton(
                  tooltip: 'Eliminar apunte',
                  icon: const Icon(Icons.delete_outline_rounded, size: 16, color: Color(0xFFEF4444)),
                  onPressed: () => _confirmDeleteNote(note),
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
