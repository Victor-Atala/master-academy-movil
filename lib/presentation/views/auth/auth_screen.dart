import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/biometric_service.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/theme_viewmodel.dart';
import 'forgot_password_screen.dart';

import '../../../core/di/service_locator.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> with SingleTickerProviderStateMixin {
  bool _isLogin = true;
  bool _obscurePassword = true;
  bool _canUseBiometrics = false;

  @override
  void initState() {
    super.initState();
    _checkBiometrics();
  }

  Future<void> _checkBiometrics() async {
    final allowed = await sl<BiometricService>().canUseBiometric();
    if (mounted) {
      setState(() => _canUseBiometrics = allowed);
    }
  }

  // Controllers Login
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  // Controllers Register
  final _nameController = TextEditingController();
  final _paternalController = TextEditingController();
  final _maternalController = TextEditingController();
  final _regEmailController = TextEditingController();
  final _regPasswordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _paternalController.dispose();
    _maternalController.dispose();
    _regEmailController.dispose();
    _regPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authVm = context.watch<AuthViewModel>();
    final themeVm = context.watch<ThemeViewModel>();
    final isDark = themeVm.isDarkMode;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: Icon(Icons.arrow_back_ios_new_rounded, color: isDark ? Colors.white : AppColors.textPrimary),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        actions: [
          IconButton(
            icon: Icon(isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded),
            color: isDark ? Colors.white : AppColors.textPrimary,
            onPressed: () => themeVm.toggleTheme(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 10),
              // Logo
              Center(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: (isDark ? Colors.black : AppColors.primary).withOpacity(0.2),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Transform.scale(
                      scale: isDark ? 1.0 : 1.12,
                      child: Image.asset(
                        isDark ? 'assets/images/icon_oscuro.png' : 'assets/images/app_icon.png',
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: 'Master',
                      style: TextStyle(
                        color: isDark ? Colors.white : AppColors.textPrimary,
                        fontWeight: FontWeight.w900,
                        fontSize: 24,
                      ),
                    ),
                    const TextSpan(
                      text: 'Academy',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w900,
                        fontSize: 24,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                _isLogin ? 'Bienvenido de vuelta' : 'Crea tu cuenta gratuita',
                style: TextStyle(
                  color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 32),

              // Segmented Toggle
              Container(
                height: 50,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : const Color(0xFFE2E8F0).withOpacity(0.5),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    _buildToggleButton('Iniciar sesión', _isLogin, () => setState(() => _isLogin = true), isDark),
                    _buildToggleButton('Registrarse', !_isLogin, () => setState(() => _isLogin = false), isDark),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Form Card
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: isDark ? AppColors.darkBorder : const Color(0xFFF1F5F9)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (authVm.errorMessage != null) _buildError(authVm.errorMessage!),
                    
                    _isLogin ? _buildLoginForm(authVm, isDark) : _buildRegisterForm(authVm, isDark),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              
              // Bottom Text with clickable Terms and Conditions
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    'Al continuar aceptas los ',
                    style: TextStyle(
                      color: isDark ? AppColors.darkTextMuted : const Color(0xFF94A3B8),
                      fontSize: 11,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _showTermsAndConditions(context, isDark),
                    child: const Text(
                      'Términos y Condiciones',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Text(
                    ' y el ',
                    style: TextStyle(
                      color: isDark ? AppColors.darkTextMuted : const Color(0xFF94A3B8),
                      fontSize: 11,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _showPrivacyPolicy(context, isDark),
                    child: const Text(
                      'Aviso de Privacidad',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Text(
                    ' de MasterAcademy.',
                    style: TextStyle(
                      color: isDark ? AppColors.darkTextMuted : const Color(0xFF94A3B8),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  void _showTermsAndConditions(BuildContext context, bool isDark) {
    final textColor = isDark ? Colors.white : AppColors.textPrimary;
    final secondaryTextColor = isDark ? AppColors.darkTextSecondary : const Color(0xFF475569);
    final mutedTextColor = isDark ? AppColors.darkTextMuted : const Color(0xFF64748B);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0),
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Términos y Condiciones',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close_rounded, color: isDark ? Colors.white70 : AppColors.textPrimary),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              // Body content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'TÉRMINOS Y CONDICIONES DE USO (VERSIÓN EN DESARROLLO / BETA)',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Última actualización: Agosto 2026',
                        style: TextStyle(
                          color: mutedTextColor,
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      const SizedBox(height: 14),
                      RichText(
                        text: TextSpan(
                          style: TextStyle(color: secondaryTextColor, fontSize: 13, height: 1.5),
                          children: [
                            const TextSpan(text: 'Bienvenido/a a la aplicación móvil de '),
                            TextSpan(
                              text: 'MasterAcademy',
                              style: TextStyle(fontWeight: FontWeight.bold, color: textColor),
                            ),
                            const TextSpan(
                              text: ' (en adelante, la "Aplicación"). Al descargar, instalar, acceder o utilizar esta Aplicación, usted (en adelante, el "Usuario") acepta quedar vinculado por los presentes Términos y Condiciones. Si no está de acuerdo con estos términos, le solicitamos no utilizar ni instalar la Aplicación.',
                            ),
                          ],
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Divider(),
                      ),

                      _buildTermsSection(
                        '1. Naturaleza de la Aplicación y Versión de Prueba',
                        [
                          'La Aplicación se encuentra actualmente en fase de desarrollo, pruebas y optimización (Versión Beta/Pre-lanzamiento).',
                          'El servicio se proporciona "tal cual" (as is) y "según disponibilidad". MasterAcademy no garantiza que la plataforma funcione de manera ininterrumpida, libre de errores, bugs o pérdidas temporales de sincronización.',
                          'Las interfaces, módulos, catálogos y funciones pueden modificarse, suspenderse o actualizarse en cualquier momento sin previo aviso.',
                        ],
                        isDark,
                      ),

                      _buildTermsSection(
                        '2. Registro y Seguridad de la Cuenta',
                        [
                          'Para acceder a los contenidos formativos y herramientas de red de contactos, el Usuario debe crear una cuenta proporcionando información veraz, actualizada y completa.',
                          'El Usuario es el único responsable de mantener la confidencialidad de sus credenciales de acceso y de todas las actividades realizadas desde su cuenta.',
                          'MasterAcademy se reserva el derecho de suspender o cancelar cuentas en caso de detectar actividad fraudulenta o uso indebido.',
                        ],
                        isDark,
                      ),

                      _buildTermsSection(
                        '3. Uso Permitido y Restricciones',
                        [
                          'Grabar, descargar, redistribuir, revender o compartir públicamente el material audiovisual o documental de los cursos sin autorización expresa.',
                          'Realizar ingeniería inversa, descompilar o intentar extraer el código fuente de la Aplicación.',
                          'Utilizar mecanismos automatizados (bots, scrapers) para interactuar con la plataforma.',
                          'Emplear la plataforma para hostigar, enviar spam o difundir material ilícito en los canales de networking o contacto.',
                        ],
                        isDark,
                        introText: 'El Usuario se compromete a utilizar la Aplicación exclusivamente con fines personales y de formación profesional lícita. Queda estrictamente prohibido:',
                      ),

                      _buildTermsSection(
                        '4. Propiedad Intelectual',
                        [
                          'Todos los derechos de propiedad industrial e intelectual sobre el diseño de la Aplicación, código, marcas, logotipos, textos, videos, exámenes y recursos pedagógicos son titularidad exclusiva de MasterAcademy o de sus respectivos instructores autorizados.',
                          'El acceso a un curso otorga únicamente una licencia de uso personal, no transferible y revocable para visualizar el contenido.',
                        ],
                        isDark,
                      ),

                      _buildTermsSection(
                        '5. Compras y Transacciones',
                        [
                          'Durante los períodos de prueba o despliegue en tiendas de aplicaciones, las transacciones pueden estar sujetas a pasarelas de pago de terceros o entornos sandbox de validación.',
                          'Los precios de los cursos y membresías se muestran en Moneda Nacional (MXN) y pueden ajustarse conforme a las promociones o actualizaciones oficiales de la plataforma web (masteracademy.mx).',
                        ],
                        isDark,
                      ),

                      _buildTermsSection(
                        '6. Privacidad y Protección de Datos',
                        [
                          'El tratamiento de los datos personales recabados mediante la Aplicación se rige por la legislación aplicable en los Estados Unidos Mexicanos (LFPDPPP). Los datos serán utilizados exclusivamente para la gestión académica, autenticación y soporte técnico.',
                        ],
                        isDark,
                      ),

                      _buildTermsSection(
                        '7. Limitación de Responsabilidad',
                        [
                          'MasterAcademy no será responsable por fallas técnicas derivadas de incompatibilidad con el dispositivo móvil, problemas de conexión a internet o pérdidas de progreso generadas por actualizaciones de la versión en desarrollo.',
                        ],
                        isDark,
                      ),

                      _buildTermsSection(
                        '8. Contacto y Soporte',
                        [
                          'Correo electrónico: ayuda@masteracademy.mx',
                          'Sitio oficial: https://masteracademy.mx/',
                        ],
                        isDark,
                        introText: 'Para dudas, reportes de fallas (bugs) o comentarios sobre estos términos, puede comunicarse a:',
                      ),
                    ],
                  ),
                ),
              ),
              // Bottom Action Button
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0),
                    ),
                  ),
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Entendido', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showPrivacyPolicy(BuildContext context, bool isDark) {
    final textColor = isDark ? Colors.white : AppColors.textPrimary;
    final secondaryTextColor = isDark ? AppColors.darkTextSecondary : const Color(0xFF475569);
    final mutedTextColor = isDark ? AppColors.darkTextMuted : const Color(0xFF64748B);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0),
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Aviso de Privacidad',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close_rounded, color: isDark ? Colors.white70 : AppColors.textPrimary),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              // Body content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AVISO DE PRIVACIDAD INTEGRAL (VERSIÓN EN DESARROLLO / APLICACIÓN MÓVIL)',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Última actualización: Agosto 2026',
                        style: TextStyle(
                          color: mutedTextColor,
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      const SizedBox(height: 14),
                      RichText(
                        text: TextSpan(
                          style: TextStyle(color: secondaryTextColor, fontSize: 13, height: 1.5),
                          children: [
                            TextSpan(
                              text: 'MasterAcademy',
                              style: TextStyle(fontWeight: FontWeight.bold, color: textColor),
                            ),
                            const TextSpan(
                              text: ' (en adelante, el "Responsable"), con portal web oficial en https://masteracademy.mx/ y correo de contacto ayuda@masteracademy.mx, es el responsable del tratamiento y protección de sus datos personales, en estricto cumplimiento de la Ley Federal de Protección de Datos Personales en Posesión de los Particulares (LFPDPPP) y su Reglamento.',
                            ),
                          ],
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Divider(),
                      ),

                      _buildTermsSection(
                        '1. Datos Personales que se Recaban',
                        [
                          'Datos de identificación y contacto: Nombre completo, correo electrónico, número telefónico y fotografía de perfil (opcional).',
                          'Datos académicos y profesionales: Cursos inscritos, avance modular, calificaciones, certificaciones obtenidas e historial formativo.',
                          'Datos de uso y técnicos del dispositivo: Identificadores únicos del dispositivo (Device ID), versión del sistema operativo, registros de fallos (crash logs), dirección IP y datos analíticos de rendimiento de la app.',
                        ],
                        isDark,
                        introText: 'Para la operación y pruebas de la aplicación móvil, podemos recopilar y tratar las siguientes categorías de datos:\n\nNota: La aplicación móvil no solicita ni trata datos personales sensibles.',
                      ),

                      _buildTermsSection(
                        '2. Finalidades del Tratamiento de Datos',
                        [
                          'Registro, creación y autenticación de la cuenta de usuario.',
                          'Proporcionar acceso al catálogo de cursos, material audiovisual y evaluaciones.',
                          'Registro y sincronización del progreso académico y emisión de constancias.',
                          'Soporte técnico, resolución de incidencias (debugging) y optimización del rendimiento de la app.',
                          'Comunicación sobre actualizaciones críticas, cambios en el servicio o restablecimiento de credenciales.',
                        ],
                        isDark,
                        introText: 'Finalidades Primarias (necesarias para el servicio):',
                      ),

                      _buildTermsSection(
                        'Finalidades Secundarias (opcionales)',
                        [
                          'Envío de notificaciones informativas sobre nuevos cursos, promociones o eventos de networking.',
                          'Encuestas de satisfacción y retroalimentación sobre la experiencia de usuario (beta testing).',
                        ],
                        isDark,
                        introText: 'Si no desea que sus datos se utilicen para finalidades secundarias, puede manifestarlo enviando un correo a ayuda@masteracademy.mx.',
                      ),

                      _buildTermsSection(
                        '3. Transferencia y Uso de Servicios de Terceros',
                        [
                          'Proveedores de infraestructura en la nube y bases de datos seguras.',
                          'Servicios analíticos de monitoreo y diagnóstico de errores en la app.',
                          'Autoridades competentes cuando exista un requerimiento legal formal conforme a las leyes mexicanas.',
                        ],
                        isDark,
                        introText: 'Sus datos personales no serán vendidos ni transferidos a terceros con fines comerciales sin su previo consentimiento. Únicamente se podrán compartir datos técnicos o de autenticación con:',
                      ),

                      _buildTermsSection(
                        '4. Derechos ARCO (Acceso, Rectificación, Cancelación y Oposición)',
                        [
                          'Usted tiene derecho a conocer qué datos personales tenemos de usted, para qué los usamos y las condiciones del uso que les damos (Acceso); solicitar la corrección de su información desactualizada o inexacta (Rectificación); pedir que se elimine de nuestros registros cuando considere que no está siendo utilizada adecuadamente (Cancelación); así como oponerse al uso de sus datos para fines específicos (Oposición).',
                        ],
                        isDark,
                        introText: 'Procedimiento: Para ejercer sus derechos ARCO, envíe una solicitud por correo electrónico a ayuda@masteracademy.mx con el asunto "Solicitud de Derechos ARCO - App Móvil", detallando su nombre completo, el correo asociado a su cuenta y la descripción clara del derecho que desea ejercer.',
                      ),

                      _buildTermsSection(
                        '5. Medidas de Seguridad',
                        [
                          'Implementamos medidas de seguridad administrativas, técnicas y físicas orientadas a proteger sus datos personales contra daño, pérdida, alteración, destrucción o uso, acceso o tratamiento no autorizado, empleando protocolos de comunicación cifrada (HTTPS/SSL) en la transmisión de datos.',
                        ],
                        isDark,
                      ),

                      _buildTermsSection(
                        '6. Modificaciones al Aviso de Privacidad',
                        [
                          'El presente Aviso de Privacidad puede sufrir modificaciones o actualizaciones derivadas de nuevos requerimientos legales, necesidades operativas o la incorporación de nuevas funciones en la aplicación móvil. Las modificaciones estarán disponibles directamente dentro de la app en este apartado y en el sitio web masteracademy.mx.',
                        ],
                        isDark,
                      ),
                    ],
                  ),
                ),
              ),
              // Bottom Action Button
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0),
                    ),
                  ),
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Entendido', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTermsSection(String title, List<String> bulletPoints, bool isDark, {String? introText}) {
    final textColor = isDark ? Colors.white : AppColors.textPrimary;
    final secondaryTextColor = isDark ? AppColors.darkTextSecondary : const Color(0xFF475569);

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: textColor,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (introText != null) ...[
            const SizedBox(height: 6),
            Text(
              introText,
              style: TextStyle(color: secondaryTextColor, fontSize: 13, height: 1.4),
            ),
          ],
          const SizedBox(height: 8),
          ...bulletPoints.map((point) => Padding(
                padding: const EdgeInsets.only(left: 8, bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('• ', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 14)),
                    Expanded(
                      child: Text(
                        point,
                        style: TextStyle(color: secondaryTextColor, fontSize: 13, height: 1.4),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildToggleButton(String label, bool active, VoidCallback onTap, bool isDark) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? (isDark ? AppColors.darkBackground : Colors.white) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    )
                  ]
                : [],
          ),
          child: Text(
            label,
            style: TextStyle(
              color: active ? (isDark ? Colors.white : AppColors.textPrimary) : (isDark ? Colors.white54 : const Color(0xFF64748B)),
              fontWeight: active ? FontWeight.bold : FontWeight.w500,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginForm(AuthViewModel authVm, bool isDark) {
    final bool canUseBiometrics = _canUseBiometrics;

    return Column(
      key: const ValueKey('login'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInputLabel('Correo electrónico', isDark),
        _buildTextField(_emailController, 'tucorreo@ejemplo.com', Icons.email_outlined, isDark),
        const SizedBox(height: 20),
        _buildInputLabel('Contraseña', isDark),
        _buildTextField(
          _passwordController, 
          '••••••••', 
          Icons.lock_outline_rounded, 
          isDark, 
          isPassword: true
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ForgotPasswordScreen()),
              );
            },
            child: const Text(
              '¿Olvidaste tu contraseña?',
              style: TextStyle(color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildActionButton('Ingresar', AppColors.primary, authVm, () async {
                final success = await authVm.login(_emailController.text, _passwordController.text);
                if (success && context.mounted) {
                  if (Navigator.canPop(context)) {
                    Navigator.pop(context);
                  }
                }
              }),
            ),
            if (canUseBiometrics && authVm.status != AuthStatus.authenticating && authVm.status != AuthStatus.syncing) ...[
              const SizedBox(width: 12),
              InkWell(
                onTap: () async {
                  final success = await authVm.loginWithBiometrics();
                  if (success && context.mounted) {
                    if (Navigator.canPop(context)) {
                      Navigator.pop(context);
                    }
                  }
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  height: 52,
                  width: 52,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                  ),
                  child: const Icon(Icons.fingerprint_rounded, color: AppColors.primary, size: 28),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 16),
        Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('¿No tienes cuenta? ', style: TextStyle(color: isDark ? Colors.white54 : const Color(0xFF64748B))),
              GestureDetector(
                onTap: () => setState(() => _isLogin = false),
                child: const Text('Regístrate gratis', style: TextStyle(color: Color(0xFF00BFA5), fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRegisterForm(AuthViewModel authVm, bool isDark) {
    return Column(
      key: const ValueKey('register'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInputLabel('Nombre(s)', isDark),
        _buildTextField(_nameController, 'Ingresa tu nombre', Icons.person_outline_rounded, isDark),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInputLabel('Apellido paterno', isDark),
                  _buildTextField(_paternalController, 'Primer apellido', null, isDark),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInputLabel('Apellido materno', isDark),
                  _buildTextField(_maternalController, 'Segundo apellido (opcional)', null, isDark),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildInputLabel('Correo electrónico', isDark),
        _buildTextField(_regEmailController, 'correo@ejemplo.com', Icons.email_outlined, isDark),
        const SizedBox(height: 16),
        _buildInputLabel('Contraseña', isDark),
        _buildTextField(
          _regPasswordController, 
          'Mínimo 8 caracteres', 
          Icons.lock_outline_rounded, 
          isDark, 
          isPassword: true
        ),
        const SizedBox(height: 24),
        _buildActionButton('Crear cuenta gratis', const Color(0xFF00BFA5), authVm, () async {
          final fullName = '${_nameController.text.trim()} ${_paternalController.text.trim()} ${_maternalController.text.trim()}'.trim();
          final success = await authVm.register(
            fullName, 
            _regEmailController.text.trim(), 
            _regPasswordController.text.trim(),
          );
          if (success && context.mounted) {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            }
          }
        }),
        const SizedBox(height: 16),
        Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('¿Ya tienes cuenta? ', style: TextStyle(color: isDark ? Colors.white54 : const Color(0xFF64748B))),
              GestureDetector(
                onTap: () => setState(() => _isLogin = true),
                child: const Text('Inicia sesión', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInputLabel(String label, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        label,
        style: TextStyle(
          color: isDark ? Colors.white : AppColors.textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint, IconData? icon, bool isDark, {bool isPassword = false}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword ? _obscurePassword : false,
        style: TextStyle(color: isDark ? Colors.white : AppColors.textPrimary),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: isDark ? Colors.white24 : const Color(0xFF94A3B8), fontWeight: FontWeight.normal),
          prefixIcon: icon != null ? Icon(icon, size: 20, color: const Color(0xFF94A3B8)) : null,
          suffixIcon: isPassword 
            ? IconButton(
                icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 20, color: const Color(0xFF94A3B8)),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              )
            : null,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(String label, Color color, AuthViewModel authVm, VoidCallback onPressed) {
    final isLoading = authVm.status == AuthStatus.authenticating || authVm.status == AuthStatus.syncing;
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          backgroundColor: color,
          foregroundColor: Colors.white,
          elevation: 4,
          shadowColor: color.withOpacity(0.4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        onPressed: isLoading ? null : onPressed,
        child: isLoading
            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildError(String message) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.error.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withOpacity(0.2)),
      ),
      child: Text(
        message,
        style: const TextStyle(color: AppColors.error, fontSize: 13),
        textAlign: TextAlign.center,
      ),
    );
  }
}
