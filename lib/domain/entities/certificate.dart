class Certificate {
  final int id;
  final String title;
  final int courseId;
  final String courseTitle;
  final String recipientName;
  final String verificationUuid;
  final DateTime issuedAt;
  final String? qrCodeUrl;
  final String? certificatePdfUrl;

  const Certificate({
    required this.id,
    required this.title,
    required this.courseId,
    required this.courseTitle,
    required this.recipientName,
    required this.verificationUuid,
    required this.issuedAt,
    this.qrCodeUrl,
    this.certificatePdfUrl,
  });
}
