import 'package:flutter_test/flutter_test.dart';
import 'package:master_academy/core/di/service_locator.dart' as di;
import 'package:master_academy/main.dart';
import 'package:provider/provider.dart';
import 'package:master_academy/presentation/viewmodels/auth_viewmodel.dart';
import 'package:master_academy/presentation/viewmodels/course_viewmodel.dart';
import 'package:master_academy/presentation/viewmodels/learning_viewmodel.dart';
import 'package:master_academy/presentation/viewmodels/payment_viewmodel.dart';
import 'package:master_academy/presentation/viewmodels/certificate_viewmodel.dart';
import 'package:master_academy/presentation/viewmodels/notification_viewmodel.dart';
import 'package:master_academy/presentation/viewmodels/theme_viewmodel.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await di.init();
  });

  testWidgets('App smoke test - verifies initial widget tree renders', (WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthViewModel>(create: (_) => di.sl<AuthViewModel>()),
          ChangeNotifierProvider<CourseViewModel>(create: (_) => di.sl<CourseViewModel>()),
          ChangeNotifierProvider<LearningViewModel>(create: (_) => di.sl<LearningViewModel>()),
          ChangeNotifierProvider<PaymentViewModel>(create: (_) => di.sl<PaymentViewModel>()),
          ChangeNotifierProvider<CertificateViewModel>(create: (_) => di.sl<CertificateViewModel>()),
          ChangeNotifierProvider<NotificationViewModel>(create: (_) => di.sl<NotificationViewModel>()),
          ChangeNotifierProvider<ThemeViewModel>(create: (_) => di.sl<ThemeViewModel>()),
        ],
        child: const MasterAcademyApp(),


      ),
    );

    expect(find.byType(MasterAcademyApp), findsOneWidget);

    // Fast-forward timers
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(seconds: 11));
  });
}
