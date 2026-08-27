using FluentValidation;

namespace Orders.Api.Platform.Http;

/// <summary>
/// Runs the FluentValidation validator registered for TRequest; 400 with ProblemDetails on failure.
/// Adding this filter to an endpoint is a statement that a validator exists, so a missing registration
/// throws at request time (a 500 in the slice test) instead of silently skipping validation.
/// </summary>
public sealed class ValidationFilter<TRequest> : IEndpointFilter
{
    public async ValueTask<object?> InvokeAsync(EndpointFilterInvocationContext context, EndpointFilterDelegate next)
    {
        var validator = context.HttpContext.RequestServices.GetService<IValidator<TRequest>>()
            ?? throw new InvalidOperationException(
                $"No validator is registered for {typeof(TRequest).Name}. Add a public class deriving from AbstractValidator<{typeof(TRequest).Name}> next to the request.");
        var request = context.Arguments.OfType<TRequest>().FirstOrDefault();
        if (request is not null)
        {
            var result = await validator.ValidateAsync(request, context.HttpContext.RequestAborted);
            if (!result.IsValid)
            {
                return TypedResults.ValidationProblem(result.ToDictionary());
            }
        }
        return await next(context);
    }
}
