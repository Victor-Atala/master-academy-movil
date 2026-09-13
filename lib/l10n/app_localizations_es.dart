// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'Master Academy';

  @override
  String get featuredCourses => 'Cursos destacados';

  @override
  String get viewAll => 'Ver todos';

  @override
  String get exploreCourses => 'Explorar cursos';

  @override
  String get studyAtYourOwnPace => 'Estudia a tu ritmo';

  @override
  String get heroSubtitle =>
      'Cursos certificados para impulsar tu carrera profesional.';

  @override
  String get buyNow => 'Comprar ahora';

  @override
  String get priceLabel => 'Precio';

  @override
  String get enrolledLabel => 'Ya estás inscrito';

  @override
  String get notifications => 'Notificaciones';

  @override
  String get markAllAsRead => 'Marcar todas como leídas';

  @override
  String get noNotifications => 'No hay notificaciones';

  @override
  String get errorLoadingCourses => 'No se pudieron cargar los cursos';

  @override
  String get retry => 'Reintentar';
}
