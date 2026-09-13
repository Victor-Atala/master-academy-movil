import '../../domain/entities/order.dart';
import '../../domain/entities/payment_result.dart';
import '../../domain/repositories/payment_repository.dart';
import '../datasources/payment_remote_datasource.dart';
import '../datasources/checkout_remote_datasource.dart';

class PaymentRepositoryImpl implements PaymentRepository {
  final PaymentRemoteDataSource remoteDataSource;
  final CheckoutRemoteDataSource checkoutRemoteDataSource;

  PaymentRepositoryImpl({
    required this.remoteDataSource,
    required this.checkoutRemoteDataSource,
  });

  @override
  Future<PaymentResult> processPayment({
    required String courseId,
    required double amount,
    required String paymentMethodId,
  }) async {
    return await remoteDataSource.charge(
      courseId: courseId,
      amount: amount,
      paymentMethodId: paymentMethodId,
    );
  }

  @override
  Future<Order> createCheckout(dynamic courseId, {String? couponCode}) async {
    return await checkoutRemoteDataSource.createCheckout(courseId, couponCode: couponCode);
  }

  @override
  Future<PaymentConfirmation> processOrderPayment(
    dynamic orderId, {
    required String gatewayCode,
    String? externalReference,
  }) async {
    return await checkoutRemoteDataSource.processOrderPayment(
      orderId,
      gatewayCode: gatewayCode,
      externalReference: externalReference,
    );
  }
}
