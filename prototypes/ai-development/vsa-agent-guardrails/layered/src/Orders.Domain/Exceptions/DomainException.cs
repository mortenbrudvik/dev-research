namespace Orders.Domain.Exceptions;

/// <summary>A business rule was violated. Mapped to HTTP 409 by the API.</summary>
public sealed class DomainException(string message) : Exception(message);
