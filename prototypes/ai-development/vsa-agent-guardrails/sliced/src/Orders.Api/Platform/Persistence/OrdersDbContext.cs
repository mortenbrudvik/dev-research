using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Storage.ValueConversion;
using Orders.Api.Domain;

namespace Orders.Api.Platform.Persistence;

public sealed class OrdersDbContext(DbContextOptions<OrdersDbContext> options) : DbContext(options)
{
    public DbSet<Order> Orders => Set<Order>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.Entity<Order>(order =>
        {
            order.HasKey(o => o.Id);
            order.Property(o => o.CustomerId).IsRequired().HasMaxLength(100);
            order.Property(o => o.Status).HasConversion<string>().HasMaxLength(20);
            // SQLite stores DateTimeOffset as TEXT and cannot order or compare it in SQL (EF Core throws
            // NotSupportedException on ORDER BY). The binary converter stores an orderable INTEGER and
            // round-trips the offset, so handlers can OrderBy/Where on these columns.
            order.Property(o => o.CreatedAt).HasConversion<DateTimeOffsetToBinaryConverter>();
            order.Property(o => o.ShippedAt).HasConversion<DateTimeOffsetToBinaryConverter>();
            order.Property(o => o.CancelledAt).HasConversion<DateTimeOffsetToBinaryConverter>();
            order.Ignore(o => o.Total);
            order.OwnsMany(o => o.Lines, line =>
            {
                line.ToTable("OrderLines");
                line.WithOwner().HasForeignKey("OrderId");
                line.Property<int>("Id");
                line.HasKey("Id");
                line.Property(l => l.Sku).IsRequired().HasMaxLength(50);
                line.Ignore(l => l.Total);
            });
        });
    }
}
