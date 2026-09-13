import 'package:flutter/material.dart';
import '../../domain/entities/order.dart';
import '../../domain/entities/payment_result.dart';
import '../../domain/usecases/checkout_usecase.dart';
import '../../domain/usecases/process_payment_usecase.dart';

enum PaymentStatus { idle, processing, success, failed }

class PaymentViewModel extends ChangeNotifier {
  final ProcessPaymentUseCase? _processPaymentUseCase;
  final CheckoutUseCase? _checkoutUseCase;

  PaymentViewModel({
    ProcessPaymentUseCase? processPaymentUseCase,
    CheckoutUseCase? checkoutUseCase,
  })  : _processPaymentUseCase = processPaymentUseCase,
        _checkoutUseCase = checkoutUseCase;

  PaymentStatus _status = PaymentStatus.idle;
  PaymentStatus get status => _status;

  PaymentResult? _result;
  PaymentResult? get result => _result;

  Order? _currentOrder;
  Order? get currentOrder => _currentOrder;

  String? _appliedCoupon;
  String? get appliedCoupon => _appliedCoupon;

  double _discountAmount = 0.0;
  double get discountAmount => _discountAmount;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  void applyCoupon(String couponCode, double originalPrice) {
    final code = couponCode.trim().toUpperCase();
    if (code == 'MASTER20' || code == 'PROMO20') {
      _appliedCoupon = code;
      _discountAmount = originalPrice * 0.20;
      _errorMessage = null;
    } else if (code == 'MASTER50' || code == 'BECA50') {
      _appliedCoupon = code;
      _discountAmount = originalPrice * 0.50;
      _errorMessage = null;
    } else if (code.isNotEmpty) {
      _appliedCoupon = code;
      _discountAmount = originalPrice * 0.10; // Default valid promo
      _errorMessage = null;
    } else {
      _appliedCoupon = null;
      _discountAmount = 0.0;
    }
    notifyListeners();
  }

  void removeCoupon() {
    _appliedCoupon = null;
    _discountAmount = 0.0;
    notifyListeners();
  }

  Future<bool> executePayment({
    required String courseId,
    required double amount,
    required String cardToken,
    String gatewayCode = 'stripe',
  }) async {
    _status = PaymentStatus.processing;
    _errorMessage = null;
    notifyListeners();

    try {
      if (_checkoutUseCase != null) {
        // Step 1: Create checkout order on the backend API
        _currentOrder = await _checkoutUseCase!.createCheckout(
          courseId,
          couponCode: _appliedCoupon,
        );

        // Step 2: Process payment for the order
        final confirmation = await _checkoutUseCase!.processOrderPayment(
          _currentOrder!.id,
          gatewayCode: gatewayCode,
          externalReference: cardToken,
        );

        if (confirmation.isSuccess) {
          _result = PaymentResult(
            isSuccess: true,
            transactionId: confirmation.transactionId,
          );
          _status = PaymentStatus.success;
          notifyListeners();
          return true;
        } else {
          _result = PaymentResult(
            isSuccess: false,
            transactionId: '',
            errorMessage: confirmation.message,
          );
          _status = PaymentStatus.failed;
          _errorMessage = confirmation.message;
          notifyListeners();
          return false;
        }
      } else if (_processPaymentUseCase != null) {
        _result = await _processPaymentUseCase!(
          courseId: courseId,
          amount: amount,
          paymentMethodId: cardToken,
        );

        if (_result!.isSuccess) {
          _status = PaymentStatus.success;
          notifyListeners();
          return true;
        } else {
          _status = PaymentStatus.failed;
          _errorMessage = _result?.errorMessage ?? 'Error al procesar el pago';
          notifyListeners();
          return false;
        }
      } else {
        await Future.delayed(const Duration(seconds: 1));
        _result = PaymentResult(
          isSuccess: true,
          transactionId: 'TXN_${DateTime.now().millisecondsSinceEpoch}',
        );
        _status = PaymentStatus.success;
        notifyListeners();
        return true;
      }
    } catch (e) {
      _status = PaymentStatus.failed;
      _errorMessage = e.toString().replaceAll('Exception:', '').trim();
      notifyListeners();
      return false;
    }
  }

  void reset() {
    _status = PaymentStatus.idle;
    _result = null;
    _currentOrder = null;
    _appliedCoupon = null;
    _discountAmount = 0.0;
    _errorMessage = null;
    notifyListeners();
  }
}
