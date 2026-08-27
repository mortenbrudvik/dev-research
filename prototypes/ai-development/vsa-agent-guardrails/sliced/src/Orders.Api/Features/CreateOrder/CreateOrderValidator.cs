using FluentValidation;

namespace Orders.Api.Features.CreateOrder;

public sealed class CreateOrderValidator : AbstractValidator<CreateOrderRequest>
{
    public CreateOrderValidator()
    {
        RuleFor(r => r.CustomerId).NotEmpty().MaximumLength(100);
        RuleFor(r => r.Lines).NotEmpty().WithMessage("At least one line is required.");   // deliberately not the domain's wording: the 400 (shape) and the 409 (invariant) are independent
        RuleForEach(r => r.Lines).ChildRules(line =>
        {
            line.RuleFor(l => l.Sku).NotEmpty().MaximumLength(50);
            line.RuleFor(l => l.Quantity).GreaterThan(0);
            line.RuleFor(l => l.UnitPrice).GreaterThan(0);
        });
    }
}
