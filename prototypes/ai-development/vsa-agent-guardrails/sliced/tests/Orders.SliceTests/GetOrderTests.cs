using Orders.Api.Domain;
using Orders.Api.Features.GetOrder;

namespace Orders.SliceTests;

public class GetOrderTests(ApiFixture api) : IClassFixture<ApiFixture>
{
    [Fact]
    public async Task Get_existing_order_returns_200_with_lines()
    {
        var id = await api.SeedOrderAsync("cust-7");
        var client = api.CreateClient();

        var response = await client.GetAsync($"/orders/{id}");

        await response.ShouldBe(HttpStatusCode.OK);
        var body = await response.Content.ReadFromJsonAsync<GetOrderResponse>();
        Assert.NotNull(body);
        Assert.Equal(id, body.Id);
        Assert.Equal("cust-7", body.CustomerId);
        Assert.Equal("Pending", body.Status);
        Assert.Null(body.ShippedAt);
        Assert.Null(body.CancelledAt);
        var line = Assert.Single(body.Lines);
        Assert.Equal("SKU-1", line.Sku);
        Assert.Equal(10m, body.Total);
    }

    [Fact]
    public async Task Get_shipped_order_reports_shipped_status_and_time()
    {
        var id = await api.SeedOrderAsync("cust-8", OrderStatus.Shipped);
        var client = api.CreateClient();

        var body = await client.GetFromJsonAsync<GetOrderResponse>($"/orders/{id}");

        Assert.NotNull(body);
        Assert.Equal("Shipped", body.Status);
        Assert.NotNull(body.ShippedAt);
    }

    [Fact]
    public async Task Get_unknown_order_returns_404()
    {
        var client = api.CreateClient();

        var response = await client.GetAsync($"/orders/{Guid.NewGuid()}");

        await response.ShouldBe(HttpStatusCode.NotFound);
    }
}
