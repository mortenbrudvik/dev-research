using Orders.Domain.Enums;
using Orders.Application.Orders;

namespace Orders.IntegrationTests;

public class ListOrdersTests(ApiFixture api) : IClassFixture<ApiFixture>
{
    [Fact]
    public async Task List_returns_orders_newest_first()
    {
        var older = await api.SeedOrderAsync("cust-1", createdAt: new DateTimeOffset(2026, 1, 1, 10, 0, 0, TimeSpan.Zero));
        var newer = await api.SeedOrderAsync("cust-1", createdAt: new DateTimeOffset(2026, 1, 2, 10, 0, 0, TimeSpan.Zero));
        var client = api.CreateClient();

        var body = await client.GetFromJsonAsync<OrderListDto>("/orders");

        // Tests in this class share one database, so assert relative order, not the whole list.
        Assert.NotNull(body);
        var ids = body.Orders.Select(o => o.Id).ToList();
        Assert.Contains(newer, ids);
        Assert.Contains(older, ids);
        Assert.True(ids.IndexOf(newer) < ids.IndexOf(older), "the newer order must be listed before the older one");
        var summary = body.Orders.Single(o => o.Id == newer);
        Assert.Equal("cust-1", summary.CustomerId);
        Assert.Equal("Pending", summary.Status);
        Assert.Equal(1, summary.LineCount);
        Assert.Equal(10m, summary.Total);
    }

    [Fact]
    public async Task List_filters_by_status()
    {
        await api.SeedOrderAsync("cust-2");
        var shipped = await api.SeedOrderAsync("cust-2", OrderStatus.Shipped);
        var client = api.CreateClient();

        var body = await client.GetFromJsonAsync<OrderListDto>("/orders?status=Shipped");

        Assert.NotNull(body);
        var only = Assert.Single(body.Orders);
        Assert.Equal(shipped, only.Id);
    }

    [Fact]
    public async Task List_with_unknown_status_returns_400()
    {
        var client = api.CreateClient();

        var response = await client.GetAsync("/orders?status=Lost");

        await response.ShouldBe(HttpStatusCode.BadRequest);
    }

    [Fact]
    public async Task List_with_numeric_status_returns_400()
    {
        var client = api.CreateClient();

        var response = await client.GetAsync("/orders?status=1");   // Enum.TryParse would accept this as Shipped

        await response.ShouldBe(HttpStatusCode.BadRequest);
    }
}
