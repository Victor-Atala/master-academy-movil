import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../viewmodels/theme_viewmodel.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../views/auth/auth_screen.dart';
import '../views/profile/profile_screen.dart';
import '../views/support/support_center_screen.dart';
import '../views/notes/student_notebook_screen.dart';

class DrawerMenu extends StatefulWidget {
  final VoidCallback onClose;
  final Function(int) onNavigate;

  const DrawerMenu({
    super.key,
    required this.onClose,
    required this.onNavigate,
  });

  @override
  State<DrawerMenu> createState() => _DrawerMenuState();
}

class _DrawerMenuState extends State<DrawerMenu> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _slideAnimation = Tween<Offset>(begin: const Offset(0, -0.06), end: Offset.zero).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleClose() async {
    await _controller.reverse();
    widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.select<ThemeViewModel, bool>((vm) => vm.isDarkMode);
    final isAuthenticated = context.select<AuthViewModel, bool>(
      (vm) => vm.status == AuthStatus.authenticated,
    );

    final menuItems = [
      (
        title: 'Inicio',
        subtitle: 'Cursos destacados y catálogo',
        icon: Icons.home_rounded,
        color: const Color(0xFF3B82F6),
        index: 0,
      ),
      (
        title: 'Categorías',
        subtitle: 'Explora por especialidad técnica',
        icon: Icons.grid_view_rounded,
        color: const Color(0xFF10B981),
        index: 1,
      ),
      (
        title: 'Padrón de Cursos',
        subtitle: 'Mis capacitaciones en curso',
        icon: Icons.verified_user_rounded,
        color: const Color(0xFFF59E0B),
        index: 2,
      ),
      (
        title: 'Mis Apuntes (Bloc de Notas)',
        subtitle: 'Notas de todas mis clases',
        icon: Icons.edit_note_rounded,
        color: const Color(0xFF06B6D4),
        index: 5,
      ),
      (
        title: isAuthenticated ? 'Mi Perfil' : 'Iniciar Sesión / Registro',
        subtitle: isAuthenticated ? 'Ajustes, cupones y diplomas' : 'Accede a tu cuenta de estudiante',
        icon: isAuthenticated ? Icons.person_rounded : Icons.login_rounded,
        color: const Color(0xFF8B5CF6),
        index: 3,
      ),
      (
        title: 'Centro de Soporte',
        subtitle: 'Atención y ayuda 24/7',
        icon: Icons.headset_mic_rounded,
        color: const Color(0xFF00BFA5),
        index: 4,
      ),
    ];

    return RepaintBoundary(
      child: Stack(
        children: [
          // Fondo semi-translúcido interactivo (animado por GPU via FadeTransition aislado)
          RepaintBoundary(
            child: GestureDetector(
              onTap: _handleClose,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Container(
                  color: Colors.black.withOpacity(isDark ? 0.6 : 0.35),
                  width: double.infinity,
                  height: MediaQuery.of(context).size.height,
                ),
              ),
            ),
          ),

          // Panel del menú deslizante (Tarjeta flotante GPU de alto rendimiento)
          Positioned(
            top: 10,
            left: 12,
            right: 12,
            child: RepaintBoundary(
              child: SlideTransition(
                position: _slideAnimation,
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(isDark ? 0.35 : 0.1),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Elementos del menú
                      ...menuItems.map((item) {
                        return _buildMenuItem(
                          context: context,
                          title: item.title,
                          subtitle: item.subtitle,
                          icon: item.icon,
                          color: item.color,
                          index: item.index,
                          isDark: isDark,
                        );
                      }),

                      const SizedBox(height: 8),
                      Divider(color: isDark ? AppColors.darkBorder : AppColors.divider),
                      const SizedBox(height: 8),

                      // Switch de Modo Oscuro estilizado
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withOpacity(0.05)
                              : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                                    color: AppColors.primary,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Modo Oscuro',
                                      style: TextStyle(
                                        color: isDark ? Colors.white : AppColors.textPrimary,
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      isDark ? 'Tema nocturno activo' : 'Tema claro activo',
                                      style: TextStyle(
                                        color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            Switch(
                              value: isDark,
                              activeColor: AppColors.primary,
                              onChanged: (_) => context.read<ThemeViewModel>().toggleTheme(),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ],
  ),
);
  }

  Widget _buildMenuItem({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required int index,
    required bool isDark,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            widget.onClose();

            if (index == 3) {
              final authVm = context.read<AuthViewModel>();
              if (authVm.status != AuthStatus.authenticated) {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AuthScreen()),
                );
              } else {
                Navigator.push(
                  context,
                  ProfileScreen.route(),
                );
              }
            } else if (index < 3) {
              widget.onNavigate(index);
            } else if (index == 4) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SupportCenterScreen()),
              );
            } else if (index == 5) {
              Navigator.push(
                context,
                StudentNotebookScreen.route(),
              );
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: color.withOpacity(isDark ? 0.18 : 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: color.withOpacity(0.3)),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: isDark ? Colors.white : AppColors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: isDark ? AppColors.darkTextMuted : const Color(0xFF94A3B8),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
