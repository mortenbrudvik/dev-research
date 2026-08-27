using Microsoft.EntityFrameworkCore;
using Orders.Application.Orders;

namespace Orders.IntegrationTests;

public class CreateOrderTests(ApiFixture api) : IClassFixture<ApiFixture>
{
    [Fact]
    public async Task Post_valid_order_returns_201_and_persists()
    {
        var client = api.CreateClient();

        var response = await client.PostAsJsonAsync("/orders", new
        {
            customerId = "cust-1",
            lines = new[] { new { sku = "SKU-1", quantity = 2, unitPrice = 9.5 } },
        });

        await response.ShouldBe(HttpStatusCode.Created);
        var body = await response.Content.ReadFromJsonAsync<CreateOrderResult>();
        Assert.NotNull(body);
        Assert.Equal("Pending", body.Status);
        Assert.Equal($"/orders/{body.Id}", response.Headers.Location?.ToString());

        var stored = await api.WithDb(db => db.Orders.SingleAsync(o => o.Id == body.Id));
        Assert.Equal("cust-1", stored.CustomerId);
        Assert.Single(stored.Lines);
        Assert.Equal(19m, stored.Total);
    }

    [Fact]
    public async Task Post_order_without_lines_returns_400()
    {
        var client = api.CreateClient();

        var response = await client.PostAsJsonAsync("/orders", new { customerId = "cust-1", lines = Array.Empty<object>() });

        await response.ShouldBe(HttpStatusCode.BadRequest);
    }

    [Fact]
    public async Task Post_line_with_zero_quantity_returns_400()
    {
        var client = api.CreateClient();

        var response = await client.PostAsJsonAsync("/orders", new
        {
            customerId = "cust-1",
            lines = new[] { new { sku = "SKU-1", quantity = 0, unitPrice = 9.5 } },
        });

        await response.ShouldBe(HttpStatusCode.BadRequest);
    }
}
