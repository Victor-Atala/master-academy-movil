class Order {
  final int id;
  final String orderNumber;
  final int courseId;
  final double total;
  final double subtotal;
  final double discount;
  final String status;
  final String? couponCode;
  final DateTime createdAt;

  const Order({
    required this.id,
    required this.orderNumber,
    required this.courseId,
    required this.total,
    required this.subtotal,
    this.discount = 0.0,
    required this.status,
    this.couponCode,
    required this.createdAt,
  });
}

class PaymentConfirmation {
  final bool isSuccess;
  final String transactionId;
  final String message;
  final DateTime? timestamp;

  const PaymentConfirmation({
    required this.isSuccess,
    required this.transactionId,
    required this.message,
    this.timestamp,
  });
}
