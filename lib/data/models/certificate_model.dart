import '../../domain/entities/certificate.dart';

class CertificateModel extends Certificate {
  const CertificateModel({
    required super.id,
    required super.title,
    required super.courseId,
    required super.courseTitle,
    required super.recipientName,
    required super.verificationUuid,
    required super.issuedAt,
    super.qrCodeUrl,
    super.certificatePdfUrl,
  });

  factory CertificateModel.fromJson(Map<String, dynamic> json) {
    return CertificateModel(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      title: json['title']?.toString() ?? 'Certificado de Finalización',
      courseId: json['course_id'] is int ? json['course_id'] : int.tryParse(json['course_id']?.toString() ?? '0') ?? 0,
      courseTitle: json['course_title']?.toString() ?? json['course']?['title']?.toString() ?? 'Curso Profesional',
      recipientName: json['recipient_name']?.toString() ?? json['user']?['name']?.toString() ?? 'Estudiante',
      verificationUuid: json['verification_uuid']?.toString() ?? json['uuid']?.toString() ?? '',
      issuedAt: json['issued_at'] != null
          ? DateTime.tryParse(json['issued_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      qrCodeUrl: json['qr_code_url']?.toString() ?? json['qr_code']?.toString(),
      certificatePdfUrl: json['pdf_url']?.toString() ?? json['certificate_pdf_url']?.toString(),
    );
  }
}
