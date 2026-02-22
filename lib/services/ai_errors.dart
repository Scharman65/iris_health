class AiError implements Exception {
  AiError(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => 'AiError: $message';
}

class AiTimeoutError extends AiError {
  AiTimeoutError(super.message, {super.cause});
}

class AiNetworkError extends AiError {
  AiNetworkError(super.message, {super.cause});
}

class AiServerError extends AiError {
  AiServerError(
    super.message, {
    required this.statusCode,
    this.body,
    super.cause,
  });

  final int statusCode;
  final String? body;

  @override
  String toString() => 'AiServerError($statusCode): $message';
}

class AiParseError extends AiError {
  AiParseError(super.message, {super.cause});
}
