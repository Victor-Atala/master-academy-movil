import 'package:flutter/material.dart';
import '../../core/common/ui_state.dart';
import '../../core/error/failure.dart';
import '../../domain/entities/certificate.dart';
import '../../domain/usecases/certificate_usecase.dart';

class CertificateViewModel extends ChangeNotifier {
  final CertificateUseCase _certificateUseCase;

  CertificateViewModel({required CertificateUseCase certificateUseCase})
      : _certificateUseCase = certificateUseCase;

  UiState<List<Certificate>> _state = const UiInitial();
  UiState<List<Certificate>> get state => _state;

  Certificate? _verifiedCertificate;
  Certificate? get verifiedCertificate => _verifiedCertificate;

  bool _isVerifying = false;
  bool get isVerifying => _isVerifying;

  Future<void> fetchCertificates({bool force = false}) async {
    if (!force && _state is UiSuccess<List<Certificate>>) {
      return;
    }
    _state = const UiLoading();
    notifyListeners();

    try {
      final certs = await _certificateUseCase.getCertificates();
      _state = UiSuccess(certs);
    } catch (e) {
      _state = const UiError(ServerFailure('No se pudieron obtener los certificados'));
    } finally {
      notifyListeners();
    }
  }

  Future<bool> verifyCertificate(String uuid) async {
    _isVerifying = true;
    _verifiedCertificate = null;
    notifyListeners();

    try {
      final cert = await _certificateUseCase.verifyCertificate(uuid);
      _verifiedCertificate = cert;
      return cert != null;
    } catch (_) {
      return false;
    } finally {
      _isVerifying = false;
      notifyListeners();
    }
  }
}
