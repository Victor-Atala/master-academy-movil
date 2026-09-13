import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../viewmodels/notification_viewmodel.dart';
import '../viewmodels/theme_viewmodel.dart';
import '../views/auth/auth_screen.dart';
import '../views/notifications/notifications_screen.dart';
import '../views/profile/profile_screen.dart';

class MobileHeader extends StatelessWidget implements PreferredSizeWidget {
  final bool isMenuOpen;
  final VoidCallback onMenuToggle;

  const MobileHeader({
    super.key,
    required this.isMenuOpen,
    required this.onMenuToggle,
  });

  @override
  Widget build(BuildContext context) {
    final authVm = context.watch<AuthViewModel>();
    final notificationVm = context.watch<NotificationViewModel>();
    final themeVm = context.watch<ThemeViewModel>();

    final isAuthenticated = authVm.status == AuthStatus.authenticated;
    final unreadCount = notificationVm.unreadCount;
    final isDark = themeVm.isDarkMode;

    return AppBar(
      backgroundColor: isDark ? AppColors.darkBackground : Colors.white,
      elevation: 0,
      surfaceTintColor: isDark ? AppColors.darkBackground : Colors.white,
      leading: IconButton(
        icon: SizedBox(
          width: 24,
          height: 24,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: child,
            ),
            child: Icon(
              isMenuOpen ? Icons.close_rounded : Icons.menu_rounded,
              key: ValueKey<bool>(isMenuOpen),
              color: isDark ? Colors.white : AppColors.textPrimary,
            ),
          ),
        ),
        onPressed: onMenuToggle,
      ),
      title: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Transform.scale(
              scale: isDark ? 1.0 : 1.12,
              child: Image.asset(
                isDark ? 'assets/images/icon_oscuro.png' : 'assets/images/app_icon.png',
                width: 32,
                height: 32,
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: RichText(
              overflow: TextOverflow.ellipsis,
              text: TextSpan(
                children: [
                  TextSpan(
                    text: 'Master',
                    style: TextStyle(
                      color: isDark ? Colors.white : AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  const TextSpan(
                    text: 'Academy',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      actions: [
        if (isAuthenticated) ...[
          // 🔔 Notificaciones
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: Icon(Icons.notifications_none_rounded, color: isDark ? Colors.white : AppColors.textPrimary),
                onPressed: () {
                  Navigator.push(
                    context,
                    NotificationsScreen.route(),
                  );
                },
              ),
              if (unreadCount > 0)
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
          // 👤 Perfil (Solo en la barra de arriba)
          IconButton(
            icon: Icon(Icons.person_outline_rounded, color: isDark ? Colors.white : AppColors.textPrimary),
            onPressed: () {
              Navigator.push(
                context,
                ProfileScreen.route(),
              );
            },
          ),
          const SizedBox(width: 8),
        ] else ...[
          // 🟢 BOTÓN REGÍSTRATE
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                minimumSize: const Size(0, 36),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AuthScreen()),
                );
              },
              child: const Text(
                'Regístrate',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ),
        ],
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(color: isDark ? AppColors.darkBorder : AppColors.border, height: 1),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
