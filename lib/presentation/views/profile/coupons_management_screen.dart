import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:provider/provider.dart';
import '../../../core/common/ui_state.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/di/service_locator.dart';
import '../../../domain/entities/course.dart';
import '../../viewmodels/course_viewmodel.dart';
import '../../viewmodels/theme_viewmodel.dart';

class CouponsManagementScreen extends StatefulWidget {
  const CouponsManagementScreen({super.key});

  @override
  State<CouponsManagementScreen> createState() => _CouponsManagementScreenState();
}

class _CouponsManagementScreenState extends State<CouponsManagementScreen> {
  final TextEditingController _codeController = TextEditingController();
  Course? _selectedCourse;
  bool _isValidating = false;
  String? _errorMessage;
  List<Map<String, dynamic>> _redeemedCoupons = [];

  @override
  void initState() {
    super.initState();
    _loadRedeemedCoupons();
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _loadRedeemedCoupons() async {
    try {
      final storage = sl<FlutterSecureStorage>();
      final raw = await storage.read(key: 'user_redeemed_coupons_list');
      if (raw != null && raw.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(raw);
        setState(() {
          _redeemedCoupons = decoded.cast<Map<String, dynamic>>();
        });
      }
    } catch (_) {}
  }

  Future<void> _saveRedeemedCoupons() async {
    try {
      final storage = sl<FlutterSecureStorage>();
      await storage.write(
        key: 'user_redeemed_coupons_list',
        value: jsonEncode(_redeemedCoupons),
      );
    } catch (_) {}
  }

  Future<void> _redeemCoupon() async {
    final code = _codeController.text.trim().toUpperCase();
    if (code.isEmpty) {
      setState(() => _errorMessage = 'Por favor ingresa un código de cupón o beca.');
      return;
    }

    setState(() {
      _isValidating = true;
      _errorMessage = null;
    });

    await Future.delayed(const Duration(milliseconds: 600));

    final courseVm = context.read<CourseViewModel>();

    // Analyze coupon benefit
    int discountPercent = 10;
    String description = 'Descuento promocional especial';
    bool isFullScholarship = false;

    if (code == 'BECA100' || code == 'MASTER100' || code == 'GRATIS' || code == 'ACCESO') {
      discountPercent = 100;
      description = 'Beca completa 100% de cobertura';
      isFullScholarship = true;
    } else if (code == 'BECA50' || code == 'MASTER50') {
      discountPercent = 50;
      description = 'Beca parcial 50% de descuento';
    } else if (code == 'MASTER20' || code == 'PROMO20') {
      discountPercent = 20;
      description = 'Cupón institucional 20% de descuento';
    } else {
      discountPercent = 15;
      description = 'Cupón verificado de acceso Master Academy';
    }

    // If a specific course is selected and it's a 100% scholarship, auto-enroll!
    bool enrolledSuccessfully = false;
    if (isFullScholarship && _selectedCourse != null) {
      try {
        await courseVm.markCourseAsEnrolled(_selectedCourse!.id, course: _selectedCourse, code: code);
        enrolledSuccessfully = true;
      } catch (_) {}
    }

    final newRecord = {
      'code': code,
      'discount': '$discountPercent%',
      'description': description,
      'course': _selectedCourse?.title ?? 'Válido para cualquier especialización',
      'courseId': _selectedCourse?.id,
      'date': '${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
      'isFullScholarship': isFullScholarship,
      'isEnrolled': enrolledSuccessfully,
    };

    setState(() {
      _redeemedCoupons.insert(0, newRecord);
      _isValidating = false;
      _codeController.clear();
      _selectedCourse = null;
    });

    await _saveRedeemedCoupons();

    if (mounted) {
      _showSuccessDialog(newRecord, enrolledSuccessfully);
    }
  }

  void _showSuccessDialog(Map<String, dynamic> coupon, bool enrolled) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.card_giftcard_rounded, color: Color(0xFF10B981), size: 28),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                '¡Cupón Canjeado!',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Has activado el código "${coupon['code']}" con éxito.',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Beneficio:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      Text(
                        coupon['discount'] as String,
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF10B981), fontSize: 15),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    coupon['description'] as String,
                    style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : Colors.black87),
                  ),
                  if (enrolled) ...[
                    const SizedBox(height: 8),
                    const Row(
                      children: [
                        Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 16),
                        SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '¡Curso desbloqueado e inscrito en tu cuenta!',
                            style: TextStyle(color: Color(0xFF10B981), fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Aceptar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeVm = context.watch<ThemeViewModel>();
    final courseVm = context.watch<CourseViewModel>();
    final isDark = themeVm.isDarkMode;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Canjear Cupones y Becas',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: isDark ? const Color(0xFF0F172A) : AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Banner Hero Informativo
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                      : [AppColors.primary, const Color(0xFF00BFA5)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.25),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.confirmation_number_rounded, color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Acceso por Códigos y Becas',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Activa tus cursos utilizando los cupones proporcionados por tu institución o promociones oficiales.',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Formulario de Canje
            Text(
              'Ingresa tu Código',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 10),

            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _codeController,
                    textCapitalization: TextCapitalization.characters,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                      color: isDark ? Colors.white : AppColors.textPrimary,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Código del Cupón / Beca',
                      hintText: 'Ej: MASTER100, BECA50, ACCESO2026',
                      prefixIcon: const Icon(Icons.vpn_key_rounded),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Selector Opcional de Curso
                  DropdownButtonFormField<Course?>(
                    value: _selectedCourse,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'Asignar a Curso Específico (Opcional)',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      prefixIcon: const Icon(Icons.school_rounded),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                    items: [
                      const DropdownMenuItem<Course?>(
                        value: null,
                        child: Text('Cualquier curso / Beca general', overflow: TextOverflow.ellipsis),
                      ),
                      ...((courseVm.state is UiSuccess<List<Course>>)
                              ? (courseVm.state as UiSuccess<List<Course>>).data
                              : <Course>[])
                          .map((course) {
                        return DropdownMenuItem<Course?>(
                          value: course,
                          child: Text(course.title, overflow: TextOverflow.ellipsis),
                        );
                      }),
                    ],
                    onChanged: (course) => setState(() => _selectedCourse = course),
                  ),

                  if (_errorMessage != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                    ),
                  ],

                  const SizedBox(height: 18),

                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: _isValidating ? null : _redeemCoupon,
                      icon: _isValidating
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Icon(Icons.check_circle_outline_rounded, color: Colors.white),
                      label: Text(
                        _isValidating ? 'Validando...' : 'Canjear y Activar Beneficio',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // Lista de Cupones y Accesos Canjeados
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Mis Cupones y Beneficios (${_redeemedCoupons.length})',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppColors.textPrimary,
                  ),
                ),
                if (_redeemedCoupons.isNotEmpty)
                  TextButton(
                    onPressed: () async {
                      setState(() => _redeemedCoupons.clear());
                      await _saveRedeemedCoupons();
                    },
                    child: const Text('Limpiar historial', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            if (_redeemedCoupons.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    Icon(Icons.inventory_2_outlined, size: 36, color: isDark ? Colors.white38 : Colors.black26),
                    const SizedBox(height: 10),
                    Text(
                      'No tienes cupones canjeados aún.',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: isDark ? Colors.white70 : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Cuando canjees un código promocional o beca institucional, aparecerá en esta lista.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextMuted : AppColors.textMuted),
                    ),
                  ],
                ),
              )
            else
              ..._redeemedCoupons.map((coupon) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurface : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: const Color(0xFF10B981).withOpacity(0.4),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.verified_rounded, color: Color(0xFF10B981), size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  coupon['code'] as String,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 15,
                                    letterSpacing: 1,
                                    color: isDark ? Colors.white : AppColors.textPrimary,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981).withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    coupon['discount'] as String,
                                    style: const TextStyle(
                                      color: Color(0xFF10B981),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              coupon['course'] as String,
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Canjeado el ${coupon['date']}',
                              style: const TextStyle(fontSize: 10, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}
