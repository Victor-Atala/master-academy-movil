import '../entities/payment_result.dart';
import '../repositories/payment_repository.dart';

class ProcessPaymentUseCase {
  final PaymentRepository repository;

  ProcessPaymentUseCase(this.repository);

  Future<PaymentResult> call({
    required String courseId,
    required double amount,
    required String paymentMethodId,
  }) async {
    return await repository.processPayment(
      courseId: courseId,
      amount: amount,
      paymentMethodId: paymentMethodId,
    );
  }
}
