abstract class Failure {
  final String message;
  const Failure(this.message);
}

class ServerFailure extends Failure {
  const ServerFailure([String message = 'Error en el servidor']) : super(message);
}

class PaymentFailure extends Failure {
  const PaymentFailure([String message = 'Fallo en la pasarela de pagos']) : super(message);
}

class AuthFailure extends Failure {
  const AuthFailure([String message = 'Credenciales inválidas']) : super(message);
}
