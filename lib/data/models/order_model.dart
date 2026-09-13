import '../../domain/entities/order.dart';

class OrderModel extends Order {
  const OrderModel({
    required super.id,
    required super.orderNumber,
    required super.courseId,
    required super.total,
    required super.subtotal,
    super.discount,
    required super.status,
    super.couponCode,
    required super.createdAt,
  });

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    return OrderModel(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      orderNumber: json['order_number']?.toString() ?? json['orderNumber']?.toString() ?? 'ORD-${DateTime.now().millisecondsSinceEpoch}',
      courseId: json['course_id'] is int ? json['course_id'] : int.tryParse(json['course_id'].toString()) ?? 0,
      total: (json['total'] is num)
          ? (json['total'] as num).toDouble()
          : double.tryParse(json['total'].toString()) ?? 0.0,
      subtotal: (json['subtotal'] is num)
          ? (json['subtotal'] as num).toDouble()
          : double.tryParse(json['subtotal']?.toString() ?? '') ?? 0.0,
      discount: (json['discount'] is num)
          ? (json['discount'] as num).toDouble()
          : double.tryParse(json['discount']?.toString() ?? '') ?? 0.0,
      status: json['status']?.toString() ?? 'pending',
      couponCode: json['coupon_code']?.toString(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
