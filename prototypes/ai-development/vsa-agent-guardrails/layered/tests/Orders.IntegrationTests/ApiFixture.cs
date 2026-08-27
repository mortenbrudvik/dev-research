using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Data.Sqlite;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Orders.Domain.Entities;
using Orders.Domain.Enums;
using Orders.Infrastructure.Persistence;

namespace Orders.IntegrationTests;

/// <summary>
/// Boots the API in-process against a fresh SQLite file. xUnit creates one fixture per test class
/// (IClassFixture), so classes never share state.
/// </summary>
public sealed class ApiFixture : WebApplicationFactory<Program>, IAsyncLifetime
{
    private readonly string _dbPath = Path.Combine(Path.GetTempPath(), $"orders-integrationtests-{Guid.NewGuid():N}.db");

    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.UseEnvironment("Testing");
        builder.UseSetting("ConnectionStrings:Orders", $"Data Source={_dbPath}");
    }

    public async Task InitializeAsync()
    {
        using var scope = Services.CreateScope();
        await scope.ServiceProvider.GetRequiredService<OrdersDbContext>().Database.MigrateAsync();
    }

    // Explicit: the base class already has a ValueTask DisposeAsync(); xUnit's IAsyncLifetime wants a Task.
    async Task IAsyncLifetime.DisposeAsync()
    {
        await base.DisposeAsync();
        SqliteConnection.ClearAllPools();   // process-wide on purpose: Microsoft.Data.Sqlite has no per-connection-string clear
        try
        {
            File.Delete(_dbPath);
        }
        catch (IOException)
        {
            // A leaked temp file is better than a false test failure; %TEMP% cleanup takes care of it.
        }
    }

    /// <summary>
    /// Runs a query in a fresh scope. The context is disposed when the delegate returns: owned collections
    /// (Lines) are loaded with the order, any other navigation needs an Include inside the delegate.
    /// </summary>
    public async Task<T> WithDb<T>(Func<OrdersDbContext, Task<T>> action)
    {
        using var scope = Services.CreateScope();
        return await action(scope.ServiceProvider.GetRequiredService<OrdersDbContext>());
    }

    /// <summary>Inserts an order directly, bypassing the API, so tests can start from any status.</summary>
    public Task<Guid> SeedOrderAsync(string customerId, OrderStatus status = OrderStatus.Pending, DateTimeOffset? createdAt = null) =>
        WithDb(async db =>
        {
            var now = createdAt ?? DateTimeOffset.UtcNow;
            var order = Order.Create(customerId, [new OrderLine("SKU-1", 1, 10m)], now);
            if (status == OrderStatus.Shipped)
            {
                order.Ship(now.AddMinutes(1));
            }
            if (status == OrderStatus.Cancelled)
            {
                order.Cancel(now.AddMinutes(1));
            }
            db.Orders.Add(order);
            await db.SaveChangesAsync();
            return order.Id;
        });
}
