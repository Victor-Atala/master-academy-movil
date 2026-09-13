import '../../domain/entities/payment_result.dart';

abstract class PaymentRemoteDataSource {
  Future<PaymentResult> charge({
    required String courseId,
    required double amount,
    required String paymentMethodId,
  });
}

class PaymentRemoteDataSourceImpl implements PaymentRemoteDataSource {
  @override
  Future<PaymentResult> charge({
    required String courseId,
    required double amount,
    required String paymentMethodId,
  }) async {
    await Future.delayed(const Duration(seconds: 2)); // Simulación de procesamiento con Gateway

    if (paymentMethodId.isEmpty || paymentMethodId.contains('invalid')) {
      return PaymentResult(
        isSuccess: false,
        transactionId: '',
        errorMessage: 'Tarjeta rechazada o método de pago inválido.',
      );
    }

    return PaymentResult(
      isSuccess: true,
      transactionId: 'TXN_${DateTime.now().millisecondsSinceEpoch}',
    );
  }
}
