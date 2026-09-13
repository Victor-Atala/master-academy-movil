import '../entities/certificate.dart';

abstract class CertificateRepository {
  Future<List<Certificate>> getCertificates();
  Future<Certificate?> verifyCertificate(String uuid);
}
