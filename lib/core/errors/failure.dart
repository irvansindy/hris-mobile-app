abstract class Failure {
  const Failure(this.message);

  final String message;
}

class ServerFailure extends Failure {
  const ServerFailure(
    super.message, {
    this.statusCode,
    this.code,
    this.fieldErrors = const {},
  });

  final int? statusCode;
  final String? code;
  final Map<String, String> fieldErrors;
}

class AuthenticationFailure extends Failure {
  const AuthenticationFailure(super.message, {this.code});

  final String? code;
}

class ForbiddenFailure extends Failure {
  const ForbiddenFailure(super.message);
}

class ValidationFailure extends Failure {
  const ValidationFailure(super.message, {this.fieldErrors = const {}});

  final Map<String, String> fieldErrors;
}

class RateLimitFailure extends Failure {
  const RateLimitFailure(super.message, {this.retryAfterSeconds});

  final int? retryAfterSeconds;
}

class CacheFailure extends Failure {
  const CacheFailure(super.message);
}

class NetworkFailure extends Failure {
  const NetworkFailure(super.message);
}

class LocationFailure extends Failure {
  const LocationFailure(super.message);
}
