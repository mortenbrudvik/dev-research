using FluentValidation;
using Microsoft.Extensions.DependencyInjection;
using Orders.Application.Orders.Commands.CancelOrder;
using Orders.Application.Orders.Commands.CreateOrder;
using Orders.Application.Orders.Queries.GetOrder;
using Orders.Application.Orders.Queries.ListOrders;

namespace Orders.Application;

public static class DependencyInjection
{
    public static IServiceCollection AddApplication(this IServiceCollection services)
    {
        services.AddValidatorsFromAssemblyContaining<CreateOrderCommandValidator>();
        services.AddScoped<CreateOrderCommandHandler>();
        services.AddScoped<CancelOrderCommandHandler>();
        services.AddScoped<GetOrderQueryHandler>();
        services.AddScoped<ListOrdersQueryHandler>();
        return services;
    }
}
