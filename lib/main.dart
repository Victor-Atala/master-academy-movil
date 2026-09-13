import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'core/di/service_locator.dart' as di;
import 'presentation/viewmodels/auth_viewmodel.dart';
import 'presentation/viewmodels/certificate_viewmodel.dart';
import 'presentation/viewmodels/course_viewmodel.dart';
import 'presentation/viewmodels/learning_viewmodel.dart';
import 'presentation/viewmodels/notification_viewmodel.dart';
import 'presentation/viewmodels/payment_viewmodel.dart';
import 'presentation/viewmodels/theme_viewmodel.dart';
import 'presentation/viewmodels/download_viewmodel.dart';
import 'presentation/views/auth/syncing_screen.dart';
import 'presentation/views/home/main_navigation_shell.dart';
import 'core/constants/app_colors.dart';
import 'core/constants/navigation_keys.dart';
import 'core/services/realtime_sync_service.dart';
import 'l10n/app_localizations.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  

  await di.init();

  // Restore existing session and enforce 1-week inactivity policy synchronously before rendering
  await di.sl<AuthViewModel>().restoreSession();

  // Start background real-time synchronization
  di.sl<RealtimeSyncService>().start();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthViewModel>(create: (_) => di.sl<AuthViewModel>()),
        ChangeNotifierProvider<CourseViewModel>(create: (_) => di.sl<CourseViewModel>()),
        ChangeNotifierProvider<LearningViewModel>(create: (_) => di.sl<LearningViewModel>()),
        ChangeNotifierProvider<PaymentViewModel>(create: (_) => di.sl<PaymentViewModel>()),
        ChangeNotifierProvider<CertificateViewModel>(create: (_) => di.sl<CertificateViewModel>()),
        ChangeNotifierProvider<NotificationViewModel>(create: (_) => di.sl<NotificationViewModel>()),
        ChangeNotifierProvider<ThemeViewModel>(create: (_) => di.sl<ThemeViewModel>()),
        ChangeNotifierProvider<DownloadViewModel>(create: (_) => di.sl<DownloadViewModel>()),
      ],
      child: const MasterAcademyApp(),
    ),
  );
}

class MasterAcademyApp extends StatelessWidget {
  const MasterAcademyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final authVm = context.watch<AuthViewModel>();
    final themeVm = context.watch<ThemeViewModel>();

    return MaterialApp(
      navigatorKey: rootNavigatorKey,
      title: 'Master Academy',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: AppColors.background,
        colorSchemeSeed: AppColors.primary,
        fontFamily: 'Roboto',
        cardTheme: const CardThemeData(color: Colors.white),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.darkBackground,
        colorSchemeSeed: AppColors.primary,
        fontFamily: 'Roboto',
        cardTheme: const CardThemeData(color: AppColors.darkSurface),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: AppColors.darkBackground,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: AppColors.darkTextMuted,
        ),
      ),
      themeMode: themeVm.themeMode,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('es', ''),
      ],
      locale: const Locale('es', ''),
      home: _getHome(authVm),
    );
  }

  Widget _getHome(AuthViewModel authVm) {
    if (authVm.status == AuthStatus.syncing){
    return const SyncingScreen();
    }
    return const MainNavigationShell();
  }
}
