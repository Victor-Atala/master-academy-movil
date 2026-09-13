import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/constants/app_colors.dart';
import '../../../domain/entities/certificate.dart';
import '../../../domain/entities/course.dart';
import 'download_destination_modal.dart';

class CertificateViewerModal extends StatelessWidget {
  final Course course;
  final String studentName;
  final bool isDark;
  final String? overrideCertCode;
  final DateTime? overrideIssueDate;

  const CertificateViewerModal({
    super.key,
    required this.course,
    this.studentName = 'Estudiante Master Academy',
    required this.isDark,
    this.overrideCertCode,
    this.overrideIssueDate,
  });

  static void show(BuildContext context, Course course, {String studentName = 'Estudiante Master Academy'}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => CertificateViewerModal(
        course: course,
        studentName: studentName,
        isDark: isDark,
      ),
    );
  }

  static void showForCertificate(
    BuildContext context,
    Certificate cert, {
    String? studentName,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => CertificateViewerModal(
        course: Course(
          id: cert.courseId.toString(),
          title: cert.courseTitle,
          description: cert.title,
          category: 'Acreditación Oficial',
          instructor: 'Víctor Atala Lagunas',
          price: 0,
          rating: 5.0,
          studentsCount: 1,
          duration: 'Acreditado',
          thumbnail: '',
          level: 'Avanzado',
          lessonsCount: 5,
          isEnrolled: true,
          progressPercentage: 100.0,
        ),
        studentName: studentName ?? cert.recipientName,
        isDark: isDark,
        overrideCertCode: cert.verificationUuid,
        overrideIssueDate: cert.issuedAt,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final certCode = overrideCertCode ?? 'MA-CERT-${course.id.hashCode.abs().toString().padLeft(6, '0')}';
    final issueDate = overrideIssueDate ?? DateTime.now();
    final dateStr = '${issueDate.day}/${issueDate.month}/${issueDate.year}';

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        children: [
          // Drag Handle
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? Colors.white24 : Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.workspace_premium_rounded, color: Color(0xFFF59E0B), size: 24),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Certificado Oficial',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: isDark ? Colors.white : AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          'Acreditación 100% completada',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(),

          // Diploma Canvas Preview
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFFD97706),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFD97706).withOpacity(0.15),
                          blurRadius: 16,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Institution Header
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Image.asset(
                              isDark ? 'assets/images/icon_oscuro.png' : 'assets/images/app_icon.png',
                              width: 36,
                              height: 36,
                              errorBuilder: (_, __, ___) => const Icon(Icons.school, color: Color(0xFFD97706), size: 30),
                            ),
                            const SizedBox(width: 10),
                            const Text(
                              'MASTER ACADEMY',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                                letterSpacing: 2,
                                color: Color(0xFFD97706),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'CERTIFICADO DE FINALIZACIÓN',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.5,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Otorga el presente reconocimiento a:',
                          style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Color(0xFF94A3B8)),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          studentName,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: isDark ? Colors.white : AppColors.textPrimary,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Text(
                            'Por haber concluido y aprobado satisfactoriamente todos los módulos y evaluaciones del programa formativo:',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary, height: 1.4),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            course.title,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Footer & Verification Info
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Fecha de emisión:', style: TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                                Text(dateStr, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? Colors.white : AppColors.textPrimary)),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Text('Instructor Titular:', style: TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                                Text(course.instructor, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? Colors.white : AppColors.textPrimary)),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.black26 : Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.verified_rounded, size: 14, color: Color(0xFF10B981)),
                              const SizedBox(width: 6),
                              Text(
                                'Código de Validación: $certCode',
                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Actions Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: const BorderSide(color: AppColors.primary),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () {
                            Share.share(
                              '🎓 ¡He completado el curso "${course.title}" con éxito y obtuve mi Certificado Oficial en Master Academy!\nCódigo de validación: $certCode\nVerifica en: https://masteracademy.mx/certificados/$certCode',
                              subject: 'Certificado Oficial: ${course.title}',
                            );
                          },
                          icon: const Icon(Icons.share_rounded, size: 18, color: AppColors.primary),
                          label: const Text('Compartir Logro', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFD97706),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () {
                            DownloadDestinationModal.show(
                              context,
                              fileName: 'Certificado_${course.title.replaceAll(' ', '_')}_$certCode.pdf',
                              fileTitle: 'Certificado de Acreditación - ${course.title}',
                              fileType: 'Certificado Oficial PDF',
                              textContent: '===================================================\n'
                                  'MASTER ACADEMY - CERTIFICADO OFICIAL DE ACREDITACIÓN\n'
                                  '===================================================\n\n'
                                  'Por cuanto ha acreditado satisfactoriamente el curso:\n'
                                  '${course.title}\n\n'
                                  'Otorgado a: $studentName\n'
                                  'Folio de Validación: $certCode\n'
                                  'Fecha de Emisión: $dateStr\n'
                                  'Horas Acreditadas: ${course.duration}\n'
                                  'Verificación Oficial: https://masteracademy.mx/verify/$certCode\n\n'
                                  'Emitido electrónicamente por Master Academy LMS\n'
                                  'Acreditación bajo estándares internacionales',
                            );
                          },
                          icon: const Icon(Icons.download_rounded, size: 18),
                          label: const Text('Descargar PDF', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
