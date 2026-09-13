import '../entities/order.dart';
import '../entities/payment_result.dart';

abstract class PaymentRepository {
  Future<PaymentResult> processPayment({
    required String courseId,
    required double amount,
    required String paymentMethodId,
  });

  Future<Order> createCheckout(dynamic courseId, {String? couponCode});
  Future<PaymentConfirmation> processOrderPayment(
    dynamic orderId, {
    required String gatewayCode,
    String? externalReference,
  });
}
