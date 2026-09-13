import '../entities/order.dart';
import '../repositories/payment_repository.dart';

class CheckoutUseCase {
  final PaymentRepository repository;

  CheckoutUseCase(this.repository);

  Future<Order> createCheckout(dynamic courseId, {String? couponCode}) async {
    return await repository.createCheckout(courseId, couponCode: couponCode);
  }

  Future<PaymentConfirmation> processOrderPayment(
    dynamic orderId, {
    required String gatewayCode,
    String? externalReference,
  }) async {
    return await repository.processOrderPayment(
      orderId,
      gatewayCode: gatewayCode,
      externalReference: externalReference,
    );
  }
}
