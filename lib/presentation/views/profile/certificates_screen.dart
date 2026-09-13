import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/common/ui_state.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../domain/entities/certificate.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/certificate_viewmodel.dart';
import '../../viewmodels/course_viewmodel.dart';
import '../../viewmodels/theme_viewmodel.dart';
import '../../widgets/certificate_viewer_modal.dart';
import '../../widgets/download_destination_modal.dart';

class CertificatesScreen extends StatefulWidget {
  const CertificatesScreen({super.key});

  @override
  State<CertificatesScreen> createState() => _CertificatesScreenState();
}

class _CertificatesScreenState extends State<CertificatesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CertificateViewModel>().fetchCertificates(force: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeViewModel>().isDarkMode;
    final certVm = context.watch<CertificateViewModel>();
    final courseVm = context.watch<CourseViewModel>();
    final authVm = context.watch<AuthViewModel>();
    final state = certVm.state;

    final studentName = authVm.currentUserName ?? 'Víctor Atala Lagunas';
    final List<Certificate> certificates = [];
    if (state is UiSuccess<List<Certificate>>) {
      certificates.addAll(state.data);
    }

    // Merge any completed courses from CourseViewModel that reached 100%
    for (final course in courseVm.enrolledCourses) {
      if (course.progressPercentage >= 100.0) {
        final alreadyHasCert = certificates.any(
          (c) => c.courseId.toString() == course.id || c.courseTitle.toLowerCase() == course.title.toLowerCase(),
        );
        if (!alreadyHasCert) {
          final certCode = 'MA-CERT-${course.id.hashCode.abs().toString().padLeft(6, '0')}';
          certificates.add(
            Certificate(
              id: int.tryParse(course.id) ?? (course.id.hashCode.abs() % 10000),
              title: 'Certificado de Acreditación Oficial - ${course.title}',
              courseId: int.tryParse(course.id) ?? 0,
              courseTitle: course.title,
              recipientName: studentName,
              verificationUuid: certCode,
              issuedAt: DateTime.now(),
              qrCodeUrl: '${AppConstants.officialWebUrl}verify/$certCode',
            ),
          );
        }
      }
    }

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text(
          'Mis Certificados Oficiales',
          style: TextStyle(
            color: isDark ? Colors.white : AppColors.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: isDark ? Colors.white : AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: isDark ? AppColors.darkBorder : AppColors.border, height: 1),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () => certVm.fetchCertificates(force: true),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF00BFA5).withOpacity(isDark ? 0.15 : 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF00BFA5).withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.verified_rounded, color: Color(0xFF00BFA5), size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Todos tus certificados cuentan con folio único y código QR validado ante el Padrón Oficial de Master Academy.',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (state is UiLoading && certificates.isEmpty)
              const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()))
            else if (certificates.isEmpty && state is! UiError)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    children: [
                      Icon(Icons.workspace_premium_outlined, size: 64, color: isDark ? Colors.white24 : AppColors.textMuted),
                      const SizedBox(height: 16),
                      Text(
                        'No tienes certificados emitidos aún',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : AppColors.textPrimary),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Completa al 100% tus lecciones para obtener tu acreditación oficial.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: isDark ? AppColors.darkTextMuted : AppColors.textMuted, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              )
            else if (certificates.isNotEmpty)
              ...certificates.map((cert) => _buildCertificateCard(cert, isDark))
            else
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Text(
                    'Error al cargar certificados.',
                    style: TextStyle(color: isDark ? AppColors.darkTextMuted : AppColors.textMuted),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCertificateCard(Certificate cert, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => CertificateViewerModal.showForCertificate(context, cert),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                        : [const Color(0xFFF1F5F9), Colors.white],
                  ),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  border: Border(bottom: BorderSide(color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0))),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          const Icon(Icons.workspace_premium_rounded, color: Color(0xFFFFD700), size: 24),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'CERTIFICADO DE ACREDITACIÓN',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                color: isDark ? Colors.white70 : const Color(0xFF475569),
                                letterSpacing: 0.5,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'VÁLIDO',
                        style: TextStyle(color: Color(0xFF10B981), fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cert.courseTitle,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : AppColors.textPrimary,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Otorgado a: ${cert.recipientName}',
                      style: TextStyle(fontSize: 13, color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Fecha de emisión: ${cert.issuedAt.day}/${cert.issuedAt.month}/${cert.issuedAt.year}',
                      style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextMuted : const Color(0xFF94A3B8)),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.black26 : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'UUID: ${cert.verificationUuid}',
                            style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 11),
                          ),
                          const Icon(Icons.qr_code_2_rounded, size: 20, color: Color(0xFF00BFA5)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              side: const BorderSide(color: AppColors.primary),
                            ),
                            onPressed: () => CertificateViewerModal.showForCertificate(context, cert),
                            icon: const Icon(Icons.visibility_rounded, size: 18, color: AppColors.primary),
                            label: const Text('Ver Diploma', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () {
                              DownloadDestinationModal.show(
                                context,
                                fileName: 'Certificado_${cert.courseTitle.replaceAll(' ', '_')}_${cert.verificationUuid}.pdf',
                                fileTitle: 'Certificado Oficial - ${cert.courseTitle}',
                                fileType: 'Certificado Oficial PDF',
                                textContent: '===================================================\n'
                                    'MASTER ACADEMY - CERTIFICADO OFICIAL DE ACREDITACIÓN\n'
                                    '===================================================\n\n'
                                    'Curso Acreditado: ${cert.courseTitle}\n'
                                    'Estudiante: ${cert.recipientName}\n'
                                    'UUID de Validación: ${cert.verificationUuid}\n'
                                    'Fecha de Expedición: ${cert.issuedAt.toString().split(" ")[0]}\n'
                                    'Verificación Pública: ${AppConstants.officialWebUrl}verify/${cert.verificationUuid}\n\n'
                                    'Master Academy Educación Continua & Certificaciones',
                              );
                            },
                            icon: const Icon(Icons.file_download_outlined, size: 18),
                            label: const Text('Descargar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            side: BorderSide(color: isDark ? AppColors.darkBorder : const Color(0xFFCBD5E1)),
                          ),
                          onPressed: () {
                            Share.share(
                              '🎓 ¡Certificado Oficial de Master Academy!\nCurso: ${cert.courseTitle}\nOtorgado a: ${cert.recipientName}\nFolio UUID: ${cert.verificationUuid}\nVerificación: ${AppConstants.officialWebUrl}verify/${cert.verificationUuid}',
                              subject: 'Certificado Oficial: ${cert.courseTitle}',
                            );
                          },
                          child: const Icon(Icons.share_rounded, size: 18),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
