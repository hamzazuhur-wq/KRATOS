// ignore_for_file: public_member_api_docs
//
// Domain error hierarchy. Pure Dart. No Flutter/Drift/Supabase.

sealed class DomainError implements Exception {
  final String message;
  const DomainError(this.message);

  @override
  String toString() => '$runtimeType: $message';
}

class ValidationError extends DomainError {
  final String field;
  const ValidationError(this.field, String message) : super(message);
}

class InvariantViolation extends DomainError {
  final String invariant;
  const InvariantViolation(this.invariant, String message) : super(message);
}

class NotFoundError extends DomainError {
  final String entity;
  final String id;
  NotFoundError(this.entity, this.id)
      : super('$entity with id="$id" not found');
}

class ConflictError extends DomainError {
  final String reason;
  const ConflictError(this.reason) : super(reason);
}
