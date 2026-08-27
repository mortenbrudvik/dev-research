using FluentValidation;
using Microsoft.EntityFrameworkCore;
using Orders.Api.Platform.Endpoints;
using Orders.Api.Platform.Http;
using Orders.Api.Platform.Persistence;

var builder = WebApplication.CreateBuilder(args);

// Fail at startup, not on first request, when a handler depends on something that is not registered.
builder.Host.UseDefaultServiceProvider(options =>
{
    options.ValidateOnBuild = true;
    options.ValidateScopes = true;
});

builder.Services.AddDbContext<OrdersDbContext>(options =>
    options.UseSqlite(builder.Configuration.GetConnectionString("Orders") ?? "Data Source=orders.db"));
builder.Services.AddSingleton(TimeProvider.System);
builder.Services.AddValidatorsFromAssemblyContaining<Program>();
builder.Services.AddFeatureHandlers();
builder.Services.AddProblemDetails(options => options.CustomizeProblemDetails = context =>
{
    // Outside Production, put the exception message in the 500 body so a failing test or curl says why.
    if (!builder.Environment.IsProduction() && context.Exception is not null)
    {
        context.ProblemDetails.Detail = context.Exception.Message;
    }
});
builder.Services.AddExceptionHandler<DomainExceptionHandler>();

var app = builder.Build();

app.UseExceptionHandler();

if (app.Environment.IsDevelopment())
{
    using var scope = app.Services.CreateScope();
    scope.ServiceProvider.GetRequiredService<OrdersDbContext>().Database.Migrate();
}

app.MapEndpoints();

app.Run();

public partial class Program { }
