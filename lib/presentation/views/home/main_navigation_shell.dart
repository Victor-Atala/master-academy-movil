import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/constants/app_colors.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/course_viewmodel.dart';
import '../../widgets/mobile_header.dart';
import '../../widgets/drawer_menu.dart';
import '../auth/auth_screen.dart';
import '../categories/categories_screen.dart';
import '../learning/lesson_player_screen.dart';
import 'home_screen.dart';

class MainNavigationShell extends StatefulWidget {
  const MainNavigationShell({super.key});

  @override
  State<MainNavigationShell> createState() => MainNavigationShellState();
}

class MainNavigationShellState extends State<MainNavigationShell> with WidgetsBindingObserver {
  int _currentIndex = 0;
  final ValueNotifier<bool> _isMenuOpenNotifier = ValueNotifier<bool>(false);
  Timer? _tooltipTimer;
  bool _showTooltip = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Temporizador de 10 segundos para mostrar el globo flotante si no hay sesión
    _tooltipTimer = Timer(const Duration(seconds: 10), () {
      if (mounted) {
        final authVm = context.read<AuthViewModel>();
        if (authVm.status != AuthStatus.authenticated) {
          setState(() => _showTooltip = true);
        }
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      context.read<AuthViewModel>().checkInactivityOrRecordActivity();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tooltipTimer?.cancel();
    _isMenuOpenNotifier.dispose();
    super.dispose();
  }

  Future<bool> _onWillPop() async {
    if (_isMenuOpenNotifier.value) {
      _isMenuOpenNotifier.value = false;
      return false;
    }
    if (_currentIndex != 0) {
      setState(() => _currentIndex = 0);
      return false;
    }
    return await _showExitConfirmationDialog(context);
  }

  Future<bool> _showExitConfirmationDialog(BuildContext context) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.exit_to_app_rounded, color: AppColors.primary, size: 22),
            ),
            const SizedBox(width: 12),
            Text(
              '¿Salir de la app?',
              style: TextStyle(
                color: isDark ? Colors.white : AppColors.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 17,
              ),
            ),
          ],
        ),
        content: Text(
          '¿Estás seguro de que deseas salir de Master Academy?',
          style: TextStyle(
            color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
            fontSize: 13,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Cancelar',
              style: TextStyle(
                color: isDark ? Colors.white70 : AppColors.textMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Salir', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    return shouldExit ?? false;
  }

  void _showPlatformModal(BuildContext context, bool isDark) {
    setState(() => _showTooltip = false);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
        final subtitleColor = isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B);
        final lineColor = isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0);
        const circleColor = Color(0xFF00BFA5);

        final steps = [
          (
            title: '1. Regístrate',
            description: 'Crea tu cuenta gratis en menos de un minuto.',
            icon: Icons.person_add_alt_1_rounded,
          ),
          (
            title: '2. Inscríbete a un curso',
            description: 'Explora el catálogo y elige tu especialidad.',
            icon: Icons.menu_book_rounded,
          ),
          (
            title: '3. Comienza a aprender',
            description: 'Estudia a tu ritmo desde cualquier dispositivo.',
            icon: Icons.play_circle_outline_rounded,
          ),
        ];

        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.black12,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text(
                  'Conozca la plataforma',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: titleColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Empieza en tres sencillos pasos.',
                  style: TextStyle(fontSize: 14, color: subtitleColor),
                ),
                const SizedBox(height: 24),
                ...List.generate(steps.length, (index) {
                  final step = steps[index];
                  final isLast = index == steps.length - 1;

                  return IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Column(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: const BoxDecoration(
                                color: circleColor,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(step.icon, color: Colors.white, size: 20),
                            ),
                            if (!isLast)
                              Expanded(
                                child: Container(
                                  width: 2,
                                  margin: const EdgeInsets.symmetric(vertical: 4),
                                  color: lineColor,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(bottom: isLast ? 0 : 20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  step.title,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: titleColor,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  step.description,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: subtitleColor,
                                    height: 1.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const AuthScreen()),
                      );
                    },
                    child: const Text(
                      'Crear cuenta / Iniciar sesión',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _toggleMenu() {
    _isMenuOpenNotifier.value = !_isMenuOpenNotifier.value;
  }

  void _closeMenu() {
    _isMenuOpenNotifier.value = false;
  }

  @override
  Widget build(BuildContext context) {
    final isAuthenticated = context.select<AuthViewModel, bool>(
      (vm) => vm.status == AuthStatus.authenticated,
    );
    final isOffline = context.select<CourseViewModel, bool>(
      (vm) => vm.isOffline,
    );
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldExit = await _onWillPop();
        if (shouldExit && context.mounted) {
          SystemNavigator.pop();
        }
      },
      child: Provider.value(
        value: this,
        child: Scaffold(
        backgroundColor: isDark ? AppColors.darkBackground : const Color(0xFFF8FAFC),
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(kToolbarHeight),
          child: ValueListenableBuilder<bool>(
            valueListenable: _isMenuOpenNotifier,
            builder: (context, isMenuOpen, _) => MobileHeader(
              isMenuOpen: isMenuOpen,
              onMenuToggle: _toggleMenu,
            ),
          ),
        ),
        body: Stack(
          children: [
            // 🌟 INDEXEDSTACK DE ALTO RENDIMIENTO (60/120 FPS sin reconstrucción parásita ni saveLayer GPU)
            RepaintBoundary(
              child: _AnimatedIndexedStack(
                index: _currentIndex,
                children: [
                  HomeScreen(
                    isActive: _currentIndex == 0,
                    onNavigate: (idx) => setState(() => _currentIndex = idx),
                    onViewAll: () => setState(() => _currentIndex = 1),
                  ),
                  const CategoriesScreen(),
                  const _MyCoursesScreen(),
                ],
              ),
            ),

            ValueListenableBuilder<bool>(
              valueListenable: _isMenuOpenNotifier,
              builder: (context, isMenuOpen, _) {
                if (!isMenuOpen) return const SizedBox.shrink();
                return Positioned.fill(
                  child: RepaintBoundary(
                    child: DrawerMenu(
                      onClose: _closeMenu,
                      onNavigate: (idx) {
                        setState(() => _currentIndex = idx);
                        _closeMenu();
                      },
                    ),
                  ),
                );
              },
            ),

            // 🟢 GLOBO FLOTANTE DE "¿QUIERES CONOCER MÁS?" (Aparece a los 10s si no hay sesión)
            if (_showTooltip && !isAuthenticated)
              Positioned(
                top: 8,
                right: 14,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 450),
                  curve: Curves.easeOutBack,
                  builder: (context, val, child) {
                    return Transform.scale(
                      scale: val,
                      alignment: Alignment.topRight,
                      child: Opacity(
                        opacity: val.clamp(0.0, 1.0),
                        child: child,
                      ),
                    );
                  },
                  child: Material(
                    elevation: 14,
                    borderRadius: BorderRadius.circular(16),
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFF0F172A),
                    shadowColor: Colors.black.withOpacity(0.4),
                    child: InkWell(
                      onTap: () => _showPlatformModal(context, isDark),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(0xFF00BFA5).withOpacity(0.4),
                            width: 1.2,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('▲ ', style: TextStyle(color: Color(0xFF00BFA5), fontSize: 11)),
                            const Text(
                              '¿Quieres conocer más?',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFF00BFA5), size: 12),
                            const SizedBox(width: 6),
                            GestureDetector(
                              onTap: () => setState(() => _showTooltip = false),
                              child: const Icon(Icons.close_rounded, color: Colors.white54, size: 16),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        // 💎 BARRA DE NAVEGACIÓN INFERIOR ESTILO CÁPSULA FLOTANTE MAXIMALISTA
        bottomNavigationBar: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.35 : 0.06),
                    blurRadius: 20,
                    offset: const Offset(0, -5),
                  ),
                ],
                border: Border(
                  top: BorderSide(
                    color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0),
                    width: 1,
                  ),
                ),
              ),
              child: SafeArea(
                top: false,
                bottom: !isOffline,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildNavTab(0, Icons.home_outlined, Icons.home_rounded, 'Inicio', isDark),
                      _buildNavTab(1, Icons.grid_view_outlined, Icons.grid_view_rounded, 'Categorías', isDark),
                      _buildNavTab(2, Icons.verified_user_outlined, Icons.verified_user_rounded, 'Padrón', isDark),
                    ],
                  ),
                ),
              ),
            ),
            // 🟡 LÍNEA DE AVISO DE MODO OFFLINE EN LA PARTE INFERIOR
            if (isOffline)
              Consumer<CourseViewModel>(
                builder: (context, courseVm, _) => GestureDetector(
                  onLongPress: () => _showServerConfigDialog(context, courseVm),
                  onTap: () async {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Comprobando conexión al backend...'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                    final connected = await courseVm.checkConnectivity();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).hideCurrentSnackBar();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(connected
                              ? '¡Conexión detectada! Modo online reactivado.'
                              : 'Aún sin conexión. Mantén presionado para cambiar IP.'),
                          backgroundColor: connected ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
                  decoration: const BoxDecoration(
                    color: Color(0xFF0F172A),
                    border: Border(
                      top: BorderSide(color: Color(0xFFF59E0B), width: 1.5),
                    ),
                  ),
                  child: SafeArea(
                    top: false,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(
                            color: Color(0xFFF59E0B),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.cloud_off_rounded, size: 14, color: Color(0xFFF59E0B)),
                        const SizedBox(width: 6),
                        const Text(
                          'Modo Offline · Toca para reconectar',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
          ),
        ),
      ),
    );
  }

  void _showServerConfigDialog(BuildContext context, CourseViewModel courseVm) async {
    final controller = TextEditingController(text: ApiConstants.baseUrl);
    try {
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.dns_rounded, color: Color(0xFF00BFA5)),
              SizedBox(width: 8),
              Text('Conexión del Backend', style: TextStyle(fontSize: 16)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Dirección URL de la API Laravel:',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  isDense: true,
                  hintText: 'http://192.168.68.103:8000/api/v1',
                ),
              ),
              const SizedBox(height: 12),
              const Text('Acceso rápido:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  ActionChip(
                    label: const Text('192.168.68.103'),
                    onPressed: () => controller.text = 'http://192.168.68.103:8000/api/v1',
                  ),
                  ActionChip(
                    label: const Text('192.168.68.104'),
                    onPressed: () => controller.text = 'http://192.168.68.104:8000/api/v1',
                  ),
                  ActionChip(
                    label: const Text('10.0.2.2 (Emulador)'),
                    onPressed: () => controller.text = 'http://10.0.2.2:8000/api/v1',
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                final text = controller.text;
                Navigator.pop(ctx);
                final ok = await courseVm.setCustomApiUrl(text);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(ok
                          ? '¡Servidor conectado exitosamente!'
                          : 'No se pudo conectar a esa dirección.'),
                      backgroundColor: ok ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                    ),
                  );
                }
              },
              child: const Text('Guardar y Probar'),
            ),
          ],
        ),
      );
    } finally {
      controller.dispose();
    }
  }

  Widget _buildNavTab(int index, IconData inactiveIcon, IconData activeIcon, String label, bool isDark) {
    final isSelected = _currentIndex == index;
    return GestureDetector(
      onTap: () {
        if (_currentIndex != index) {
          setState(() {
            _currentIndex = index;
            if (_isMenuOpenNotifier.value) _isMenuOpenNotifier.value = false;
          });
        }
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(horizontal: isSelected ? 18 : 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? AppColors.primary.withOpacity(0.2) : AppColors.primary.withOpacity(0.12))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: isSelected
              ? Border.all(
                  color: AppColors.primary.withOpacity(0.4),
                  width: 1,
                )
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? activeIcon : inactiveIcon,
              size: 22,
              color: isSelected
                  ? AppColors.primary
                  : (isDark ? AppColors.darkTextMuted : const Color(0xFF94A3B8)),
            ),
            if (isSelected) ...[
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// 🚀 WIDGET DE TRANSICIÓN GPU DE ALTO RENDIMIENTO (120 FPS sin costosos saveLayer ni tirones)
class _AnimatedIndexedStack extends StatelessWidget {
  final int index;
  final List<Widget> children;

  const _AnimatedIndexedStack({
    required this.index,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return IndexedStack(
      index: index,
      children: children,
    );
  }
}

class _MyCoursesScreen extends StatefulWidget {
  const _MyCoursesScreen();

  @override
  State<_MyCoursesScreen> createState() => _MyCoursesScreenState();
}

class _MyCoursesScreenState extends State<_MyCoursesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CourseViewModel>().fetchLearningCourses();
    });
  }

  @override
  Widget build(BuildContext context) {
    final authVm = context.watch<AuthViewModel>();
    final isAuthenticated = authVm.status == AuthStatus.authenticated;
    final courseVm = context.watch<CourseViewModel>();
    final myCourses = courseVm.enrolledCourses;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Padrón de Aprendizaje',
          style: TextStyle(fontWeight: FontWeight.w900, color: isDark ? Colors.white : AppColors.textPrimary),
        ),
      ),
      body: !isAuthenticated
          ? Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.lock_person_rounded,
                        size: 64,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Inicia sesión para ver tu padrón',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Accede con tu cuenta de alumno para consultar tus cursos activos, continuar tus clases y obtener certificados.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                        height: 1.4,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 26),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
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
                        'Iniciar Sesión / Registrarme',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: () => courseVm.fetchLearningCourses(force: true),
              child: myCourses.isEmpty
                  ? Center(
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(32.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Opacity(
                              opacity: 0.4,
                              child: Image.asset(
                                isDark ? 'assets/images/icon_oscuro.png' : 'assets/images/app_icon.png',
                                width: 90,
                                height: 90,
                                errorBuilder: (_, __, ___) => const Icon(Icons.school_outlined, size: 70, color: AppColors.primary),
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'Aún no tienes cursos en tu padrón',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : AppColors.textPrimary),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Explora el catálogo y adquiere tu primer curso para comenzar a estudiar.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary, height: 1.4),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: myCourses.length,
                      itemBuilder: (context, index) {
                  final course = myCourses[index];
                  final double progress = course.progressPercentage;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurface : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark ? AppColors.darkBorder : AppColors.border,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => LessonPlayerScreen(course: course)),
                        );
                        if (context.mounted) {
                          context.read<CourseViewModel>().fetchLearningCourses(force: true);
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: course.thumbnail.isNotEmpty
                                      ? Image.network(
                                          course.thumbnail,
                                          width: 65,
                                          height: 65,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => Container(
                                            width: 65,
                                            height: 65,
                                            color: AppColors.primary,
                                            child: const Icon(Icons.school, color: Colors.white),
                                          ),
                                        )
                                      : Container(
                                          width: 65,
                                          height: 65,
                                          color: AppColors.primary,
                                          child: const Icon(Icons.school, color: Colors.white),
                                        ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        course.title,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: isDark ? Colors.white : AppColors.textPrimary,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${course.instructor} • ${course.category}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            // Progress bar
                            Row(
                              children: [
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: progress / 100.0,
                                      minHeight: 6,
                                      backgroundColor: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0),
                                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF00BFA5)),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  '${progress.toInt()}%',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF00BFA5),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton.icon(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (_) => LessonPlayerScreen(course: course)),
                                    );
                                  },
                                  icon: const Icon(Icons.play_arrow_rounded, size: 18, color: AppColors.primary),
                                  label: const Text(
                                    'Continuar Aprendiendo',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
