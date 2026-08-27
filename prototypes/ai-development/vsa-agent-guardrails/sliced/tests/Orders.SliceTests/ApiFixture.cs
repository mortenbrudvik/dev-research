using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Data.Sqlite;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Orders.Api.Domain;
using Orders.Api.Platform.Persistence;

namespace Orders.SliceTests;

/// <summary>
/// Boots the API in-process against a fresh SQLite file. xUnit creates one fixture per test class
/// (IClassFixture), so classes never share state.
/// </summary>
public sealed class ApiFixture : WebApplicationFactory<Program>, IAsyncLifetime
{
    private readonly string _dbPath = Path.Combine(Path.GetTempPath(), $"orders-slicetests-{Guid.NewGuid():N}.db");

    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.UseEnvironment("Testing");
        builder.UseSetting("ConnectionStrings:Orders", $"Data Source={_dbPath}");
    }

    public Task InitializeAsync()
    {
        using var scope = Services.CreateScope();
        scope.ServiceProvider.GetRequiredService<OrdersDbContext>().Database.Migrate();
        return Task.CompletedTask;
    }

    async Task IAsyncLifetime.DisposeAsync()
    {
        await base.DisposeAsync();
        SqliteConnection.ClearAllPools();
        if (File.Exists(_dbPath))
        {
            File.Delete(_dbPath);
        }
    }

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
