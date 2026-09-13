import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/common/ui_state.dart';
import '../../../core/constants/app_colors.dart';
import '../../../domain/entities/certificate.dart';
import '../../../domain/entities/course.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/certificate_viewmodel.dart';
import '../../viewmodels/course_viewmodel.dart';
import '../../viewmodels/theme_viewmodel.dart';
import 'certificates_screen.dart';
import 'coupons_management_screen.dart';
import 'saved_lessons_screen.dart';
import 'security_settings_screen.dart';
import '../notes/student_notebook_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  static final RegExp _durationRegex = RegExp(r'(\d+)');

  static Route route() {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => const ProfileScreen(),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(0.0, 0.06);
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
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    // Cargar certificados únicamente tras completar la animación para evitar congelamientos en GPU/UI
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final modalRoute = ModalRoute.of(context);
      if (modalRoute != null && modalRoute.animation != null) {
        if (modalRoute.animation!.isCompleted) {
          _checkFetchCertificates();
        } else {
          modalRoute.animation!.addStatusListener((status) {
            if (status == AnimationStatus.completed && mounted) {
              _checkFetchCertificates();
            }
          });
        }
      } else {
        _checkFetchCertificates();
      }
    });
  }

  void _checkFetchCertificates() {
    final certVm = context.read<CertificateViewModel>();
    if (certVm.state is UiInitial) {
      certVm.fetchCertificates();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.select<ThemeViewModel, bool>((vm) => vm.isDarkMode);
    final userName = context.select<AuthViewModel, String>((vm) => vm.currentUserName ?? 'Usuario Estudiante');
    final userEmail = context.select<AuthViewModel, String>((vm) => vm.currentUserEmail ?? 'estudiante@masteracademy.mx');
    final enrolledCourses = context.select<CourseViewModel, List<Course>>((vm) => vm.enrolledCourses);
    final enrolledCount = enrolledCourses.length;

    final certsCount = context.select<CertificateViewModel, int>((vm) {
      final s = vm.state;
      return s is UiSuccess<List<Certificate>> ? s.data.length : 0;
    });

    // Cálculo dinámico de horas reales acumuladas en cursos inscritos
    int totalEstimatedMinutes = 0;
    for (final course in enrolledCourses) {
      final match = ProfileScreen._durationRegex.firstMatch(course.duration);
      if (match != null) {
        final val = int.tryParse(match.group(1) ?? '0') ?? 0;
        if (course.duration.toLowerCase().contains('min')) {
          totalEstimatedMinutes += val;
        } else {
          totalEstimatedMinutes += val * 60;
        }
      } else {
        totalEstimatedMinutes += 120;
      }
    }
    final int dynamicHours = (totalEstimatedMinutes / 60).round();
    final String hoursDisplay = dynamicHours > 0 ? '${dynamicHours}h' : '${enrolledCount > 0 ? enrolledCount * 2 : 0}h';

    // Cálculo dinámico de diplomas
    final int completedCount = enrolledCourses.where((c) => c.progressPercentage >= 100.0).length;
    final int diplomasCount = certsCount > completedCount ? certsCount : completedCount;

    // Cálculo dinámico de porcentaje promedio de la Ruta de Especialización
    final double averageProgress = enrolledCourses.isEmpty
        ? 0.0
        : (enrolledCourses.map((c) => c.progressPercentage).reduce((a, b) => a + b) / enrolledCourses.length);
    final int displayProgress = averageProgress.round();

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF0F172A) : AppColors.primary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Mi Perfil',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Header Hero con Gradiente y Avatar
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [const Color(0xFF0F172A), const Color(0xFF1E293B)]
                      : [AppColors.primary, const Color(0xFF00BFA5)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Avatar con aro brillante
                  Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: CircleAvatar(
                          radius: 46,
                          backgroundColor: Colors.white.withOpacity(0.2),
                          child: const Icon(Icons.person_rounded, size: 54, color: Colors.white),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: Color(0xFF10B981),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.check_rounded, color: Colors.white, size: 14),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    userName,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    userEmail,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.85),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Insignia de Membresía sin planes "PRO" ficticios
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withOpacity(0.3)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.school_rounded, color: Color(0xFFFFD700), size: 16),
                        SizedBox(width: 6),
                        Text(
                          'ESTUDIANTE ACTIVO',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 📊 STATS EN TARJETAS FLOTANTES DINÁMICAS
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
              child: Row(
                children: [
                  _buildStatCard('Cursos', '$enrolledCount', Icons.menu_book_rounded, const Color(0xFF3B82F6), isDark),
                  const SizedBox(width: 12),
                  _buildStatCard('Horas', hoursDisplay, Icons.timer_rounded, const Color(0xFF10B981), isDark),
                  const SizedBox(width: 12),
                  _buildStatCard(
                    'Diplomas',
                    '$diplomasCount',
                    Icons.workspace_premium_rounded,
                    const Color(0xFFF59E0B),
                    isDark,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CertificatesScreen())),
                  ),
                ],
              ),
            ),
          ),

          // 🌟 TARJETA DE PROGRESO DE APRENDIZAJE REAL
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                        : [Colors.white, const Color(0xFFF8FAFC)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF00BFA5).withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.rocket_launch_rounded, color: Color(0xFF00BFA5), size: 20),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Ruta de Especialización',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : AppColors.textPrimary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '$displayProgress%',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF00BFA5),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: (averageProgress / 100.0).clamp(0.0, 1.0),
                        backgroundColor: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                        color: const Color(0xFF00BFA5),
                        minHeight: 8,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      displayProgress >= 100
                          ? '¡Felicidades! Has completado al 100% tus especializaciones inscritas.'
                          : displayProgress > 0
                              ? 'Progreso promedio acumulado en tus clases y especializaciones.'
                              : 'Inscríbete a un curso y completa lecciones para ver tu progreso en tiempo real.',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ⚙️ GRUPOS DE OPCIONES & AJUSTES
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionHeader('Cuenta y Seguridad', isDark),
                  _buildSettingsGroup(
                    isDark,
                    [
                      _buildSettingsTile(
                        Icons.download_for_offline_rounded,
                        'Clases Guardadas (Offline)',
                        'Accede a tus videos descargados sin conexión',
                        () => Navigator.push(context, SavedLessonsScreen.route()),
                        isDark,
                      ),
                      _buildSettingsTile(
                        Icons.edit_note_rounded,
                        'Mis Apuntes (Bloc de Notas)',
                        'Consulta y edita las notas tomadas en tus clases',
                        () => Navigator.push(context, StudentNotebookScreen.route()),
                        isDark,
                      ),
                      _buildSettingsTile(
                        Icons.shield_outlined,
                        'Seguridad y Biometría',
                        'Protege el acceso y activa huella digital',
                        () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SecuritySettingsScreen())),
                        isDark,
                      ),
                      _buildSettingsTile(
                        Icons.confirmation_number_outlined,
                        'Canjear Cupones y Becas',
                        'Ingresa tus códigos promocionales o cupones de acceso',
                        () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CouponsManagementScreen())),
                        isDark,
                      ),
                      _buildSettingsTile(
                        Icons.school_outlined,
                        'Mis Certificados Oficiales',
                        'Descarga tus constancias con folio y QR',
                        () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CertificatesScreen())),
                        isDark,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _buildSectionHeader('Preferencias', isDark),
                  _buildSettingsGroup(
                    isDark,
                    [
                      ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                            color: AppColors.primary,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          'Modo Oscuro',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : AppColors.textPrimary,
                          ),
                        ),
                        subtitle: Text(
                          isDark ? 'Activado' : 'Desactivado',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
                          ),
                        ),
                        trailing: Switch(
                          value: isDark,
                          activeColor: AppColors.primary,
                          onChanged: (_) => context.read<ThemeViewModel>().toggleTheme(),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Botón Cerrar Sesión con confirmación
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppColors.error.withOpacity(0.3)),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              title: const Text('¿Cerrar sesión?'),
                              content: const Text('Podrás volver a entrar con tu correo y contraseña en cualquier momento.'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx),
                                  child: const Text('Cancelar'),
                                ),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.error,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  onPressed: () {
                                    Navigator.pop(ctx);
                                    Navigator.pop(context); // Salir de la pantalla de perfil
                                    context.read<AuthViewModel>().logout();
                                  },
                                  child: const Text('Cerrar Sesión'),
                                ),
                              ],
                            ),
                          );
                        },
                        child: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.logout_rounded, color: AppColors.error, size: 20),
                              SizedBox(width: 8),
                              Text(
                                'Cerrar Sesión',
                                style: TextStyle(
                                  color: AppColors.error,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color, bool isDark, {VoidCallback? onTap}) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(height: 8),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? AppColors.darkTextMuted : const Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: isDark ? AppColors.darkTextMuted : const Color(0xFF64748B),
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildSettingsGroup(bool isDark, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildSettingsTile(IconData icon, String title, String subtitle, VoidCallback onTap, bool isDark) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: AppColors.primary, size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.white : AppColors.textPrimary,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 12,
          color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
        ),
      ),
      trailing: const Icon(Icons.chevron_right_rounded, size: 20, color: Color(0xFF94A3B8)),
    );
  }
}
