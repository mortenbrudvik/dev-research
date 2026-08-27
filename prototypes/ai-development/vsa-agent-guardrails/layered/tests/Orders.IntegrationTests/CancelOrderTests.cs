using Microsoft.EntityFrameworkCore;
using Orders.Domain.Enums;
using Orders.Application.Orders;

namespace Orders.IntegrationTests;

public class CancelOrderTests(ApiFixture api) : IClassFixture<ApiFixture>
{
    [Fact]
    public async Task Cancel_pending_order_returns_200_and_sets_cancelled()
    {
        var id = await api.SeedOrderAsync("cust-1");
        var client = api.CreateClient();

        var response = await client.PostAsync($"/orders/{id}/cancel", content: null);

        await response.ShouldBe(HttpStatusCode.OK);
        var body = await response.Content.ReadFromJsonAsync<CancelOrderResult>();
        Assert.NotNull(body);
        Assert.Equal("Cancelled", body.Status);
        Assert.NotNull(body.CancelledAt);

        var stored = await api.WithDb(db => db.Orders.SingleAsync(o => o.Id == id));
        Assert.Equal(OrderStatus.Cancelled, stored.Status);
        Assert.NotNull(stored.CancelledAt);
    }

    [Fact]
    public async Task Cancel_unknown_order_returns_404()
    {
        var client = api.CreateClient();

        var response = await client.PostAsync($"/orders/{Guid.NewGuid()}/cancel", content: null);

        await response.ShouldBe(HttpStatusCode.NotFound);
    }

    [Fact]
    public async Task Cancel_cancelled_order_returns_409()
    {
        var id = await api.SeedOrderAsync("cust-1", OrderStatus.Cancelled);
        var client = api.CreateClient();

        var response = await client.PostAsync($"/orders/{id}/cancel", content: null);

        await response.ShouldBe(HttpStatusCode.Conflict);
    }

    [Fact]
    public async Task Cancel_shipped_order_is_allowed()
    {
        var id = await api.SeedOrderAsync("cust-1", OrderStatus.Shipped);
        var client = api.CreateClient();

        var response = await client.PostAsync($"/orders/{id}/cancel", content: null);

        await response.ShouldBe(HttpStatusCode.OK);
    }
}
