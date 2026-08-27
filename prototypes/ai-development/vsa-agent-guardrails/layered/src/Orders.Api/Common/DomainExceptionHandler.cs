using Microsoft.AspNetCore.Diagnostics;
using Microsoft.AspNetCore.Mvc;
using Orders.Domain.Exceptions;

namespace Orders.Api.Common;

public sealed class DomainExceptionHandler(IProblemDetailsService problemDetails) : IExceptionHandler
{
    // Safety net: in the baseline no handler lets a DomainException escape (policies are checked first and answer
    // with Results.Problem). It exists so that a slice which calls Order.Ship()/Cancel() directly still yields a 409.
    public async ValueTask<bool> TryHandleAsync(HttpContext httpContext, Exception exception, CancellationToken cancellationToken)
    {
        if (exception is not DomainException || httpContext.Response.HasStarted)
        {
            return false;
        }
        httpContext.Response.StatusCode = StatusCodes.Status409Conflict;
        // Written by the same service as Results.Problem, so both 409 paths have the same shape (type, traceId, customisation).
        return await problemDetails.TryWriteAsync(new ProblemDetailsContext
        {
            HttpContext = httpContext,
            Exception = exception,
            ProblemDetails = new ProblemDetails
            {
                Status = StatusCodes.Status409Conflict,
                Title = "Business rule violated",
                Detail = exception.Message,
            },
        });
    }
}
