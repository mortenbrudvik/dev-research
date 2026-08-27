namespace Orders.Api.Domain;

/// <summary>A business rule was violated. Mapped to HTTP 409 by the platform.</summary>
public sealed class DomainException(string message) : Exception(message);
