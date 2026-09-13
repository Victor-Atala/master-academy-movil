import '../entities/certificate.dart';
import '../repositories/certificate_repository.dart';

class CertificateUseCase {
  final CertificateRepository repository;

  CertificateUseCase(this.repository);

  Future<List<Certificate>> getCertificates() async {
    return await repository.getCertificates();
  }

  Future<Certificate?> verifyCertificate(String uuid) async {
    return await repository.verifyCertificate(uuid);
  }
}
