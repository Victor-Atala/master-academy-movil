import '../../domain/entities/certificate.dart';
import '../../domain/repositories/certificate_repository.dart';
import '../datasources/certificate_remote_datasource.dart';

class CertificateRepositoryImpl implements CertificateRepository {
  final CertificateRemoteDataSource remoteDataSource;

  CertificateRepositoryImpl({required this.remoteDataSource});

  @override
  Future<List<Certificate>> getCertificates() async {
    return await remoteDataSource.fetchCertificates();
  }

  @override
  Future<Certificate?> verifyCertificate(String uuid) async {
    return await remoteDataSource.verifyCertificate(uuid);
  }
}
