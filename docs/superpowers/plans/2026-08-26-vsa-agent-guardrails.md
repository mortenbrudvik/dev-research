# vsa-agent-guardrails Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build `prototypes/ai-development/vsa-agent-guardrails/`: one small orders API twice (vertical slices with guardrails, and layered), with identical behaviour tests, plus a PowerShell harness that runs Claude Code headlessly against each copy on five tasks and records what it read, spent, changed and broke.

**Architecture:** Two self-contained .NET 10 solutions, `sliced/` and `layered/`, share no code; parity is enforced by identical HTTP-level test cases. Each copy carries its own `CLAUDE.md`, ArchUnitNET architecture tests (with a negative-control fixture), Claude Code hooks (`gate.sh`) and a jscpd config. `experiment/` holds five task prompts, `run.ps1` (copies a variant to a temp git repo, runs `claude -p`, measures) and `Parse-Events.ps1` (stream-json → metrics).

**Tech Stack:** .NET SDK 10.0.100, ASP.NET Core Minimal APIs, EF Core 10.0.11 + SQLite, FluentValidation 12.1.1, xUnit 2.9.3 (VSTest), ArchUnitNET 0.13.4, dotnet-ef 10.0.11 (local tool), PowerShell 7.6, Node 22 (`npx jscpd@4`), Claude Code 2.1.246, Git Bash (hooks).

**Spec:** `docs/superpowers/specs/2026-08-26-vsa-agent-guardrails-design.md` — read it first; section numbers below refer to it.

**Conventions for every task:**

- Working directory is the repository root `C:\code\prototypes\ai-development` unless a step says otherwise. Paths are repo-relative. `P` means `prototypes/ai-development/vsa-agent-guardrails`.
- Commands are Git Bash unless marked `pwsh`. `dotnet` prints a MSBuild banner; "Expected" lines describe the tail of the output.
- Commit steps are included as the skill prescribes. **The repository owner commits by default (root `CLAUDE.md`): perform a commit step only if the owner has authorised commits for this plan; otherwise `git add` the files and continue.**
- Never run `mkdocs`; nothing here is under `docs/` except the plan and spec, which are excluded from the site.

---

## File structure

| Path (under `P/`) | Responsibility |
|---|---|
| `.gitignore` | `*.db*`, `.gate.log`, `.jscpd-report/`, `experiment/results/*` except the example |
| `README.md` | what it demonstrates, how to build/test each copy, how to run the experiment, link to guide §10 |
| `sliced/Orders.sln`, `sliced/Directory.Build.props`, `sliced/.config/dotnet-tools.json` | solution, shared build props (warnings as errors), local `dotnet-ef` |
| `sliced/src/Orders.Api/Program.cs` | composition root; `public partial class Program` |
| `sliced/src/Orders.Api/Domain/*.cs` | `Order`, `OrderLine`, `OrderStatus`, `DomainException`, `CancellationPolicy` |
| `sliced/src/Orders.Api/Platform/Persistence/OrdersDbContext.cs` + `Migrations/` | EF Core model and migrations |
| `sliced/src/Orders.Api/Platform/Endpoints/EndpointExtensions.cs` | `IEndpoint`, handler and endpoint discovery |
| `sliced/src/Orders.Api/Platform/Http/ValidationFilter.cs`, `DomainExceptionHandler.cs` | 400 for validation failures, 409 for domain rule violations |
| `sliced/src/Orders.Api/Features/<UseCase>/` | one folder per use case: Request, Response, Validator (commands), Handler, Endpoint |
| `sliced/tests/Orders.SliceTests/ApiFixture.cs` + one test class per slice | HTTP in, HTTP + DB out |
| `sliced/tests/Orders.ArchitectureTests/` (+ `Orders.ArchitectureTests.Fixture/`) | ArchUnitNET rules and the negative control |
| `sliced/CLAUDE.md`, `sliced/.claude/settings.json`, `sliced/.claude/hooks/gate.sh`, `sliced/.jscpd.json` | guardrails (spec §4.5) |
| `layered/src/Orders.Domain`, `Orders.Application`, `Orders.Infrastructure`, `Orders.Api` | the same behaviour in four projects |
| `layered/tests/Orders.IntegrationTests`, `Orders.ArchitectureTests` (+ `.Fixture`) | the same test cases; layer rules |
| `layered/CLAUDE.md`, `.claude/`, `.jscpd.json` | guardrails, layer flavour |
| `experiment/tasks/T1..T5-*.md` | task prompts with scope front matter |
| `experiment/Parse-Events.ps1`, `experiment/Test-ParseEvents.ps1`, `experiment/fixtures/sample-events.jsonl` | stream-json → metrics, and its test |
| `experiment/run.ps1` | the runner (spec §5.2) |
| `experiment/Test-Parity.ps1` | HTTP-level parity check of the two copies (spec §6) |
| `experiment/results/example-results.csv`, `experiment/REPORT.md` | column reference; report template |

---

## Part A — the sliced copy

### Task 1: Scaffold the prototype folder and the sliced solution

**Files:**
- Create: `P/.gitignore`, `P/sliced/Directory.Build.props`, `P/sliced/Orders.sln`, `P/sliced/src/Orders.Api/*` (template), `P/sliced/.config/dotnet-tools.json`

- [ ] **Step 1: Create the prototype folder and its `.gitignore`**

```bash
mkdir -p prototypes/ai-development/vsa-agent-guardrails
cat > prototypes/ai-development/vsa-agent-guardrails/.gitignore <<'EOF'
# SQLite files produced by running the apps or the tests
*.db
*.db-shm
*.db-wal
# written by the Claude Code hook
.gate.log
# jscpd output
.jscpd-report/
# experiment runs (keep only the committed example)
experiment/results/*
!experiment/results/example-results.csv
EOF
```

- [ ] **Step 2: Create the solution and the API project**

```bash
cd prototypes/ai-development/vsa-agent-guardrails && mkdir sliced && cd sliced
dotnet new sln -n Orders
dotnet new web -o src/Orders.Api
dotnet sln add src/Orders.Api
dotnet new tool-manifest
dotnet tool install dotnet-ef --version 10.0.11
dotnet add src/Orders.Api package Microsoft.EntityFrameworkCore.Sqlite --version 10.0.11
dotnet add src/Orders.Api package Microsoft.EntityFrameworkCore.Design --version 10.0.11
dotnet add src/Orders.Api package FluentValidation.DependencyInjectionExtensions --version 12.1.1
```

Expected: each command ends with "The template ... was created successfully" / "Project ... added to the solution" / "info : PackageReference ... added". The `dotnet new web` template creates `Program.cs`, `appsettings*.json`, `Properties/launchSettings.json` and `Orders.Api.csproj`.

- [ ] **Step 3: Write `Directory.Build.props` and trim the csproj**

Create `sliced/Directory.Build.props`:

```xml
<Project>
  <PropertyGroup>
    <TargetFramework>net10.0</TargetFramework>
    <Nullable>enable</Nullable>
    <ImplicitUsings>enable</ImplicitUsings>
    <TreatWarningsAsErrors>true</TreatWarningsAsErrors>
  </PropertyGroup>
</Project>
```

Replace `sliced/src/Orders.Api/Orders.Api.csproj` with:

```xml
<Project Sdk="Microsoft.NET.Sdk.Web">

  <ItemGroup>
    <PackageReference Include="FluentValidation.DependencyInjectionExtensions" Version="12.1.1" />
    <PackageReference Include="Microsoft.EntityFrameworkCore.Design" Version="10.0.11">
      <PrivateAssets>all</PrivateAssets>
      <IncludeAssets>runtime; build; native; contentfiles; analyzers; buildtransitive</IncludeAssets>
    </PackageReference>
    <PackageReference Include="Microsoft.EntityFrameworkCore.Sqlite" Version="10.0.11" />
  </ItemGroup>

  <ItemGroup>
    <InternalsVisibleTo Include="Orders.SliceTests" />
  </ItemGroup>

</Project>
```

- [ ] **Step 4: Build**

Run (in `sliced/`): `dotnet build --nologo`
Expected: `Build succeeded.` with `0 Warning(s)`, `0 Error(s)`.

- [ ] **Step 5: Commit**

```bash
git add prototypes/ai-development/vsa-agent-guardrails
git commit -m "vsa-agent-guardrails: scaffold sliced solution"
```

---

### Task 2: Domain model (sliced)

**Files:**
- Create: `P/sliced/src/Orders.Api/Domain/OrderStatus.cs`, `OrderLine.cs`, `Order.cs`, `DomainException.cs`, `CancellationPolicy.cs`

No test of its own: the domain is exercised through the slice tests in Tasks 4–7. Keep it free of any dependency on `Features` or `Platform` — the architecture test in Task 8 enforces that.

- [ ] **Step 1: Write the five domain files**

`Domain/OrderStatus.cs`:

```csharp
namespace Orders.Api.Domain;

public enum OrderStatus
{
    Pending,
    Shipped,
    Cancelled,
}
```

`Domain/DomainException.cs`:

```csharp
namespace Orders.Api.Domain;

/// <summary>A business rule was violated. Mapped to HTTP 409 by the platform.</summary>
public sealed class DomainException(string message) : Exception(message);
```

`Domain/OrderLine.cs`:

```csharp
namespace Orders.Api.Domain;

public sealed class OrderLine
{
    public OrderLine(string sku, int quantity, decimal unitPrice)
    {
        Sku = sku;
        Quantity = quantity;
        UnitPrice = unitPrice;
    }

    public string Sku { get; private set; }
    public int Quantity { get; private set; }
    public decimal UnitPrice { get; private set; }

    public decimal Total => Quantity * UnitPrice;
}
```

`Domain/Order.cs`:

```csharp
namespace Orders.Api.Domain;

public sealed class Order
{
    private Order() { }

    public Guid Id { get; private set; }
    public string CustomerId { get; private set; } = "";
    public OrderStatus Status { get; private set; }
    public DateTimeOffset CreatedAt { get; private set; }
    public DateTimeOffset? ShippedAt { get; private set; }
    public DateTimeOffset? CancelledAt { get; private set; }
    public List<OrderLine> Lines { get; private set; } = new();

    public decimal Total => Lines.Sum(l => l.Total);

    public static Order Create(string customerId, IEnumerable<OrderLine> lines, DateTimeOffset now)
    {
        var order = new Order
        {
            Id = Guid.NewGuid(),
            CustomerId = customerId,
            Status = OrderStatus.Pending,
            CreatedAt = now,
        };
        order.Lines.AddRange(lines);
        if (order.Lines.Count == 0)
        {
            throw new DomainException("An order needs at least one line.");
        }
        return order;
    }

    public void Ship(DateTimeOffset now)
    {
        if (Status != OrderStatus.Pending)
        {
            throw new DomainException($"Order {Id} cannot be shipped because it is {Status}.");
        }
        Status = OrderStatus.Shipped;
        ShippedAt = now;
    }

    public void Cancel(DateTimeOffset now)
    {
        if (Status == OrderStatus.Cancelled)
        {
            throw new DomainException($"Order {Id} is already cancelled.");
        }
        Status = OrderStatus.Cancelled;
        CancelledAt = now;
    }
}
```

`Domain/CancellationPolicy.cs` — deliberately permissive in the baseline (spec §4.1): task T2 changes it.

```csharp
namespace Orders.Api.Domain;

public static class CancellationPolicy
{
    /// <summary>Only already-cancelled orders cannot be cancelled. Shipped orders can (for now).</summary>
    public static bool CanCancel(Order order) => order.Status != OrderStatus.Cancelled;
}
```

- [ ] **Step 2: Build**

Run (in `sliced/`): `dotnet build --nologo`
Expected: `Build succeeded.`, 0 warnings.

- [ ] **Step 3: Commit**

```bash
git add prototypes/ai-development/vsa-agent-guardrails/sliced/src/Orders.Api/Domain
git commit -m "vsa-agent-guardrails(sliced): domain model"
```

---

### Task 3: Platform — persistence, endpoint discovery, HTTP concerns, first migration (sliced)

**Files:**
- Create: `P/sliced/src/Orders.Api/Platform/Persistence/OrdersDbContext.cs`, `Platform/Endpoints/EndpointExtensions.cs`, `Platform/Http/ValidationFilter.cs`, `Platform/Http/DomainExceptionHandler.cs`
- Modify: `P/sliced/src/Orders.Api/Program.cs` (replace), `appsettings.json` (replace)
- Generate: `Platform/Persistence/Migrations/*`

- [ ] **Step 1: DbContext**

`Platform/Persistence/OrdersDbContext.cs`:

```csharp
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
```

- [ ] **Step 2: Endpoint and handler discovery**

`Platform/Endpoints/EndpointExtensions.cs`:

```csharp
namespace Orders.Api.Platform.Endpoints;

/// <summary>
/// Each slice exposes one endpoint class that maps its route(s). Implementations are created with
/// Activator.CreateInstance, so they need a public parameterless constructor: take dependencies as
/// parameters of the route delegate, not of the class.
/// </summary>
public interface IEndpoint
{
    void Map(IEndpointRouteBuilder app);
}

public static class EndpointExtensions
{
    private const string FeaturesNamespace = "Orders.Api.Features";

    /// <summary>Registers every *Handler class under Features as scoped, so a slice never touches Program.cs.</summary>
    public static IServiceCollection AddFeatureHandlers(this IServiceCollection services)
    {
        var handlers = typeof(EndpointExtensions).Assembly.GetTypes()
            .Where(t => t.IsClass && !t.IsAbstract
                        && t.Name.EndsWith("Handler", StringComparison.Ordinal)
                        && (t.Namespace == FeaturesNamespace
                            || t.Namespace?.StartsWith(FeaturesNamespace + ".", StringComparison.Ordinal) == true));
        foreach (var handler in handlers)
        {
            services.AddScoped(handler);
        }
        return services;
    }

    public static IEndpointRouteBuilder MapEndpoints(this IEndpointRouteBuilder app)
    {
        var endpoints = typeof(EndpointExtensions).Assembly.GetTypes()
            .Where(t => t.IsClass && !t.IsAbstract && typeof(IEndpoint).IsAssignableFrom(t))
            .Select(t => (IEndpoint)Activator.CreateInstance(t)!);
        foreach (var endpoint in endpoints)
        {
            endpoint.Map(app);
        }
        return app;
    }
}
```

- [ ] **Step 3: Validation filter and domain-exception handler**

`Platform/Http/ValidationFilter.cs`:

```csharp
using FluentValidation;

namespace Orders.Api.Platform.Http;

/// <summary>
/// Runs the FluentValidation validator registered for TRequest; 400 with ProblemDetails on failure.
/// Adding this filter to an endpoint is a statement that a validator exists, so a missing registration
/// throws at request time (a 500 in the slice test) instead of silently skipping validation.
/// </summary>
public sealed class ValidationFilter<TRequest> : IEndpointFilter
{
    public async ValueTask<object?> InvokeAsync(EndpointFilterInvocationContext context, EndpointFilterDelegate next)
    {
        var validator = context.HttpContext.RequestServices.GetService<IValidator<TRequest>>()
            ?? throw new InvalidOperationException(
                $"No validator is registered for {typeof(TRequest).Name}. Add a public class deriving from AbstractValidator<{typeof(TRequest).Name}> next to the request.");
        var request = context.Arguments.OfType<TRequest>().FirstOrDefault();
        if (request is not null)
        {
            var result = await validator.ValidateAsync(request, context.HttpContext.RequestAborted);
            if (!result.IsValid)
            {
                return TypedResults.ValidationProblem(result.ToDictionary());
            }
        }
        return await next(context);
    }
}
```

`Platform/Http/DomainExceptionHandler.cs`:

```csharp
using Microsoft.AspNetCore.Diagnostics;
using Microsoft.AspNetCore.Mvc;
using Orders.Api.Domain;

namespace Orders.Api.Platform.Http;

/// <summary>A DomainException anywhere in a slice becomes a 409 ProblemDetails.</summary>
public sealed class DomainExceptionHandler : IExceptionHandler
{
    public async ValueTask<bool> TryHandleAsync(HttpContext httpContext, Exception exception, CancellationToken cancellationToken)
    {
        if (exception is not DomainException || httpContext.Response.HasStarted)
        {
            return false;
        }
        httpContext.Response.StatusCode = StatusCodes.Status409Conflict;
        await httpContext.Response.WriteAsJsonAsync(new ProblemDetails
        {
            Status = StatusCodes.Status409Conflict,
            Title = "Business rule violated",
            Detail = exception.Message,
        }, options: null, contentType: "application/problem+json", cancellationToken);   // same media type as Results.Problem
        return true;
    }
}
```

- [ ] **Step 4: Program.cs and appsettings**

Replace `Program.cs`:

```csharp
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
// In Development and Testing, put the exception message in the 500 body so a failing test or curl says why.
var exposeExceptionDetail = builder.Environment.IsDevelopment() || builder.Environment.IsEnvironment("Testing");
builder.Services.AddProblemDetails(options => options.CustomizeProblemDetails = context =>
{
    if (exposeExceptionDetail && context.Exception is not null)
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
```

Replace `appsettings.json`:

```json
{
  "ConnectionStrings": {
    "Orders": "Data Source=orders.db"
  },
  "Logging": {
    "LogLevel": {
      "Default": "Information",
      "Microsoft.AspNetCore": "Warning"
    }
  },
  "AllowedHosts": "*"
}
```

- [ ] **Step 5: Build, then add the initial migration**

Run (in `sliced/`):

```bash
dotnet build --nologo
dotnet ef migrations add InitialCreate --project src/Orders.Api --output-dir Platform/Persistence/Migrations
```

Expected: `Build succeeded.`; then `Done. To undo this action, use 'ef migrations remove'` and three files under `src/Orders.Api/Platform/Persistence/Migrations/` (`<timestamp>_InitialCreate.cs`, `.Designer.cs`, `OrdersDbContextModelSnapshot.cs`). Open the migration: it creates tables `Orders` (Id, CustomerId, Status, and CreatedAt/ShippedAt/CancelledAt as `INTEGER` — `table.Column<long>` — because of the binary converter) and `OrderLines` (Id autoincrement, OrderId, Sku, Quantity, UnitPrice).

- [ ] **Step 6: Run once to see the empty API start**

Run (in `sliced/`): `dotnet run --project src/Orders.Api --urls http://localhost:5101` and, in another terminal, `curl -i http://localhost:5101/orders/00000000-0000-0000-0000-000000000000`
Expected: `HTTP/1.1 404 Not Found` (no endpoints yet, so the default 404). Stop the server (Ctrl+C). Delete the `orders.db` it created in `src/Orders.Api/` (it is gitignored anyway).

- [ ] **Step 7: Commit**

```bash
git add prototypes/ai-development/vsa-agent-guardrails/sliced
git commit -m "vsa-agent-guardrails(sliced): platform, first migration"
```

---

### Task 4: Slice tests project, fixture, and the CreateOrder slice (sliced)

**Files:**
- Create: `P/sliced/tests/Orders.SliceTests/Orders.SliceTests.csproj`, `ApiFixture.cs`, `CreateOrderTests.cs`
- Create: `P/sliced/src/Orders.Api/Features/CreateOrder/CreateOrderRequest.cs`, `CreateOrderResponse.cs`, `CreateOrderValidator.cs`, `CreateOrderHandler.cs`, `CreateOrderEndpoint.cs`

- [ ] **Step 1: Create the test project**

Run (in `sliced/`):

```bash
dotnet new xunit -o tests/Orders.SliceTests
dotnet sln add tests/Orders.SliceTests
dotnet add tests/Orders.SliceTests reference src/Orders.Api
dotnet add tests/Orders.SliceTests package Microsoft.AspNetCore.Mvc.Testing --version 10.0.11
rm tests/Orders.SliceTests/UnitTest1.cs
```

Replace `tests/Orders.SliceTests/Orders.SliceTests.csproj`:

```xml
<Project Sdk="Microsoft.NET.Sdk">

  <PropertyGroup>
    <IsPackable>false</IsPackable>
  </PropertyGroup>

  <ItemGroup>
    <PackageReference Include="Microsoft.AspNetCore.Mvc.Testing" Version="10.0.11" />
    <PackageReference Include="Microsoft.NET.Test.Sdk" Version="17.14.1" />
    <PackageReference Include="xunit" Version="2.9.3" />
    <PackageReference Include="xunit.runner.visualstudio" Version="3.1.4" />
  </ItemGroup>

  <ItemGroup>
    <ProjectReference Include="..\..\src\Orders.Api\Orders.Api.csproj" />
  </ItemGroup>

  <ItemGroup>
    <Using Include="Xunit" />
    <Using Include="System.Net" />
    <Using Include="System.Net.Http.Json" />
  </ItemGroup>

</Project>
```

- [ ] **Step 2: The fixture — one SQLite file per test class**

`tests/Orders.SliceTests/ApiFixture.cs`:

```csharp
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
```

- [ ] **Step 3: Write the assertion helper and the failing CreateOrder tests**

`tests/Orders.SliceTests/HttpAssertions.cs` — on a status mismatch the failure message carries the response body, so a 500 says why (the platform puts the exception message in the ProblemDetails `detail` outside Production):

```csharp
namespace Orders.SliceTests;

public static class HttpAssertions
{
    public static async Task ShouldBe(this HttpResponseMessage response, HttpStatusCode expected)
    {
        if (response.StatusCode != expected)
        {
            var body = await response.Content.ReadAsStringAsync();
            Assert.Fail($"Expected {(int)expected} {expected} but got {(int)response.StatusCode} {response.StatusCode}. Body: {body}");
        }
    }
}
```

`tests/Orders.SliceTests/CreateOrderTests.cs`:

```csharp
using Microsoft.EntityFrameworkCore;
using Orders.Api.Features.CreateOrder;

namespace Orders.SliceTests;

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
        var body = await response.Content.ReadFromJsonAsync<CreateOrderResponse>();
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
```

- [ ] **Step 4: Run the tests to see them fail**

Run (in `sliced/`): `dotnet test tests/Orders.SliceTests --nologo`
Expected: build error `CS0234: The type or namespace name 'CreateOrder' does not exist in the namespace 'Orders.Api.Features'` — the slice does not exist yet.

- [ ] **Step 5: Implement the CreateOrder slice**

`src/Orders.Api/Features/CreateOrder/CreateOrderRequest.cs`:

```csharp
namespace Orders.Api.Features.CreateOrder;

public sealed record CreateOrderRequest(string CustomerId, IReadOnlyList<CreateOrderLine> Lines);

public sealed record CreateOrderLine(string Sku, int Quantity, decimal UnitPrice);
```

`Features/CreateOrder/CreateOrderResponse.cs`:

```csharp
namespace Orders.Api.Features.CreateOrder;

public sealed record CreateOrderResponse(Guid Id, string Status);
```

`Features/CreateOrder/CreateOrderValidator.cs`:

```csharp
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
```

`Features/CreateOrder/CreateOrderHandler.cs`:

```csharp
using Orders.Api.Domain;
using Orders.Api.Platform.Persistence;

namespace Orders.Api.Features.CreateOrder;

public sealed class CreateOrderHandler(OrdersDbContext db, TimeProvider clock)
{
    public async Task<CreateOrderResponse> Handle(CreateOrderRequest request, CancellationToken cancellationToken)
    {
        var lines = request.Lines.Select(l => new OrderLine(l.Sku, l.Quantity, l.UnitPrice));
        var order = Order.Create(request.CustomerId, lines, clock.GetUtcNow());

        db.Orders.Add(order);
        await db.SaveChangesAsync(cancellationToken);

        return new CreateOrderResponse(order.Id, order.Status.ToString());
    }
}
```

`Features/CreateOrder/CreateOrderEndpoint.cs`:

```csharp
using Orders.Api.Platform.Endpoints;
using Orders.Api.Platform.Http;

namespace Orders.Api.Features.CreateOrder;

public sealed class CreateOrderEndpoint : IEndpoint
{
    public void Map(IEndpointRouteBuilder app) =>
        app.MapPost("/orders", async (CreateOrderRequest request, CreateOrderHandler handler, CancellationToken cancellationToken) =>
            {
                var response = await handler.Handle(request, cancellationToken);
                return Results.Created($"/orders/{response.Id}", response);
            })
            .AddEndpointFilter<ValidationFilter<CreateOrderRequest>>();
}
```

- [ ] **Step 6: Run the tests to see them pass**

Run (in `sliced/`): `dotnet test tests/Orders.SliceTests --nologo`
Expected: `Passed!  - Failed: 0, Passed: 3, Skipped: 0, Total: 3`.

- [ ] **Step 7: Commit**

```bash
git add prototypes/ai-development/vsa-agent-guardrails/sliced
git commit -m "vsa-agent-guardrails(sliced): CreateOrder slice with slice tests"
```

---

### Task 5: GetOrder slice (sliced)

**Files:**
- Create: `P/sliced/tests/Orders.SliceTests/GetOrderTests.cs`
- Create: `P/sliced/src/Orders.Api/Features/GetOrder/GetOrderResponse.cs`, `GetOrderHandler.cs`, `GetOrderEndpoint.cs`

A query slice has no request record and no validator: the id comes from the route.

- [ ] **Step 1: Write the failing tests**

`tests/Orders.SliceTests/GetOrderTests.cs`:

```csharp
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
```

- [ ] **Step 2: Run to see the build fail**

Run: `dotnet test tests/Orders.SliceTests --nologo`
Expected: `CS0234 ... 'GetOrder' does not exist in the namespace 'Orders.Api.Features'`.

- [ ] **Step 3: Implement the slice**

`Features/GetOrder/GetOrderResponse.cs`:

```csharp
namespace Orders.Api.Features.GetOrder;

public sealed record GetOrderResponse(
    Guid Id,
    string CustomerId,
    string Status,
    DateTimeOffset CreatedAt,
    DateTimeOffset? ShippedAt,
    DateTimeOffset? CancelledAt,
    IReadOnlyList<GetOrderLine> Lines,
    decimal Total);

public sealed record GetOrderLine(string Sku, int Quantity, decimal UnitPrice);
```

`Features/GetOrder/GetOrderHandler.cs`:

```csharp
using Microsoft.EntityFrameworkCore;
using Orders.Api.Platform.Persistence;

namespace Orders.Api.Features.GetOrder;

public sealed class GetOrderHandler(OrdersDbContext db)
{
    public async Task<GetOrderResponse?> Handle(Guid id, CancellationToken cancellationToken)
    {
        var order = await db.Orders.AsNoTracking().SingleOrDefaultAsync(o => o.Id == id, cancellationToken);
        if (order is null)
        {
            return null;
        }
        return new GetOrderResponse(
            order.Id,
            order.CustomerId,
            order.Status.ToString(),
            order.CreatedAt,
            order.ShippedAt,
            order.CancelledAt,
            order.Lines.Select(l => new GetOrderLine(l.Sku, l.Quantity, l.UnitPrice)).ToList(),
            order.Total);
    }
}
```

`Features/GetOrder/GetOrderEndpoint.cs`:

```csharp
using Orders.Api.Platform.Endpoints;

namespace Orders.Api.Features.GetOrder;

public sealed class GetOrderEndpoint : IEndpoint
{
    public void Map(IEndpointRouteBuilder app) =>
        app.MapGet("/orders/{id:guid}", async (Guid id, GetOrderHandler handler, CancellationToken cancellationToken) =>
        {
            var response = await handler.Handle(id, cancellationToken);
            return response is null ? Results.NotFound() : Results.Ok(response);
        });
}
```

- [ ] **Step 4: Run the tests**

Run: `dotnet test tests/Orders.SliceTests --nologo`
Expected: `Passed! ... Passed: 6, Total: 6`.

- [ ] **Step 5: Commit**

```bash
git add prototypes/ai-development/vsa-agent-guardrails/sliced
git commit -m "vsa-agent-guardrails(sliced): GetOrder slice"
```

---
### Task 6: CancelOrder slice (sliced)

**Files:**
- Create: `P/sliced/tests/Orders.SliceTests/CancelOrderTests.cs`
- Create: `P/sliced/src/Orders.Api/Features/CancelOrder/CancelOrderResponse.cs`, `CancelOrderHandler.cs`, `CancelOrderEndpoint.cs`

The test `Cancel_shipped_order_is_allowed` documents the baseline's permissive policy on purpose; experiment task T2 asks the agent to change that behaviour, and a correct T2 solution must change this test.

- [ ] **Step 1: Write the failing tests**

`tests/Orders.SliceTests/CancelOrderTests.cs`:

```csharp
using Microsoft.EntityFrameworkCore;
using Orders.Api.Domain;
using Orders.Api.Features.CancelOrder;

namespace Orders.SliceTests;

public class CancelOrderTests(ApiFixture api) : IClassFixture<ApiFixture>
{
    [Fact]
    public async Task Cancel_pending_order_returns_200_and_sets_cancelled()
    {
        var id = await api.SeedOrderAsync("cust-1");
        var client = api.CreateClient();

        var response = await client.PostAsync($"/orders/{id}/cancel", content: null);

        await response.ShouldBe(HttpStatusCode.OK);
        var body = await response.Content.ReadFromJsonAsync<CancelOrderResponse>();
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
```

- [ ] **Step 2: Run to see the build fail**

Run (in `sliced/`): `dotnet test tests/Orders.SliceTests --nologo`
Expected: `CS0234 ... 'CancelOrder' does not exist`.

- [ ] **Step 3: Implement the slice**

`Features/CancelOrder/CancelOrderResponse.cs`:

```csharp
namespace Orders.Api.Features.CancelOrder;

public sealed record CancelOrderResponse(Guid Id, string Status, DateTimeOffset? CancelledAt);
```

`Features/CancelOrder/CancelOrderHandler.cs`:

```csharp
using Microsoft.EntityFrameworkCore;
using Orders.Api.Domain;
using Orders.Api.Platform.Persistence;

namespace Orders.Api.Features.CancelOrder;

public sealed class CancelOrderHandler(OrdersDbContext db, TimeProvider clock)
{
    public sealed record Result(CancelOrderResponse? Response, string? Conflict, bool NotFound);

    public async Task<Result> Handle(Guid id, CancellationToken cancellationToken)
    {
        var order = await db.Orders.SingleOrDefaultAsync(o => o.Id == id, cancellationToken);
        if (order is null)
        {
            return new Result(null, null, NotFound: true);
        }
        if (!CancellationPolicy.CanCancel(order))
        {
            return new Result(null, $"Order {id} cannot be cancelled because it is {order.Status}.", NotFound: false);
        }

        order.Cancel(clock.GetUtcNow());
        await db.SaveChangesAsync(cancellationToken);

        return new Result(new CancelOrderResponse(order.Id, order.Status.ToString(), order.CancelledAt), null, NotFound: false);
    }
}
```

`Features/CancelOrder/CancelOrderEndpoint.cs`:

```csharp
using Orders.Api.Platform.Endpoints;

namespace Orders.Api.Features.CancelOrder;

public sealed class CancelOrderEndpoint : IEndpoint
{
    public void Map(IEndpointRouteBuilder app) =>
        app.MapPost("/orders/{id:guid}/cancel", async (Guid id, CancelOrderHandler handler, CancellationToken cancellationToken) =>
        {
            var result = await handler.Handle(id, cancellationToken);
            if (result.NotFound)
            {
                return Results.NotFound();
            }
            if (result.Conflict is not null)
            {
                return Results.Problem(statusCode: StatusCodes.Status409Conflict, title: "Business rule violated", detail: result.Conflict);
            }
            return Results.Ok(result.Response);
        });
}
```

- [ ] **Step 4: Run the tests**

Run: `dotnet test tests/Orders.SliceTests --nologo`
Expected: `Passed! ... Passed: 10, Total: 10`.

- [ ] **Step 5: Commit**

```bash
git add prototypes/ai-development/vsa-agent-guardrails/sliced
git commit -m "vsa-agent-guardrails(sliced): CancelOrder slice"
```

---

### Task 7: ListOrders slice (sliced)

**Files:**
- Create: `P/sliced/tests/Orders.SliceTests/ListOrdersTests.cs`
- Create: `P/sliced/src/Orders.Api/Features/ListOrders/ListOrdersResponse.cs`, `ListOrdersHandler.cs`, `ListOrdersEndpoint.cs`

- [ ] **Step 1: Write the failing tests**

`tests/Orders.SliceTests/ListOrdersTests.cs`:

```csharp
using Orders.Api.Domain;
using Orders.Api.Features.ListOrders;

namespace Orders.SliceTests;

public class ListOrdersTests(ApiFixture api) : IClassFixture<ApiFixture>
{
    [Fact]
    public async Task List_returns_orders_newest_first()
    {
        var older = await api.SeedOrderAsync("cust-1", createdAt: new DateTimeOffset(2026, 1, 1, 10, 0, 0, TimeSpan.Zero));
        var newer = await api.SeedOrderAsync("cust-1", createdAt: new DateTimeOffset(2026, 1, 2, 10, 0, 0, TimeSpan.Zero));
        var client = api.CreateClient();

        var body = await client.GetFromJsonAsync<ListOrdersResponse>("/orders");

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

        var body = await client.GetFromJsonAsync<ListOrdersResponse>("/orders?status=Shipped");

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
}
```

- [ ] **Step 2: Run to see the build fail**

Run: `dotnet test tests/Orders.SliceTests --nologo`
Expected: `CS0234 ... 'ListOrders' does not exist`.

- [ ] **Step 3: Implement the slice**

`Features/ListOrders/ListOrdersResponse.cs`:

```csharp
namespace Orders.Api.Features.ListOrders;

public sealed record ListOrdersResponse(IReadOnlyList<OrderSummary> Orders);

public sealed record OrderSummary(Guid Id, string CustomerId, string Status, DateTimeOffset CreatedAt, int LineCount, decimal Total);
```

`Features/ListOrders/ListOrdersHandler.cs`:

```csharp
using Microsoft.EntityFrameworkCore;
using Orders.Api.Domain;
using Orders.Api.Platform.Persistence;

namespace Orders.Api.Features.ListOrders;

public sealed class ListOrdersHandler(OrdersDbContext db)
{
    public async Task<ListOrdersResponse> Handle(OrderStatus? status, CancellationToken cancellationToken)
    {
        var query = db.Orders.AsNoTracking();
        if (status is not null)
        {
            query = query.Where(o => o.Status == status);
        }

        var orders = await query.OrderByDescending(o => o.CreatedAt).ToListAsync(cancellationToken);

        return new ListOrdersResponse(orders
            .Select(o => new OrderSummary(o.Id, o.CustomerId, o.Status.ToString(), o.CreatedAt, o.Lines.Count, o.Total))
            .ToList());
    }
}
```

`Features/ListOrders/ListOrdersEndpoint.cs`:

```csharp
using Orders.Api.Domain;
using Orders.Api.Platform.Endpoints;

namespace Orders.Api.Features.ListOrders;

public sealed class ListOrdersEndpoint : IEndpoint
{
    public void Map(IEndpointRouteBuilder app) =>
        app.MapGet("/orders", async (string? status, ListOrdersHandler handler, CancellationToken cancellationToken) =>
        {
            OrderStatus? filter = null;
            if (status is not null)
            {
                if (!Enum.TryParse<OrderStatus>(status, ignoreCase: true, out var parsed))
                {
                    return Results.ValidationProblem(new Dictionary<string, string[]>
                    {
                        ["status"] = [$"'{status}' is not one of {string.Join(", ", Enum.GetNames<OrderStatus>())}."],
                    });
                }
                filter = parsed;
            }
            return Results.Ok(await handler.Handle(filter, cancellationToken));
        });
}
```

- [ ] **Step 4: Run the whole slice suite**

Run: `dotnet test tests/Orders.SliceTests --nologo`
Expected: `Passed! ... Passed: 13, Total: 13`.

- [ ] **Step 5: Commit**

```bash
git add prototypes/ai-development/vsa-agent-guardrails/sliced
git commit -m "vsa-agent-guardrails(sliced): ListOrders slice"
```

---

### Task 8: Architecture tests with a negative control (sliced)

**Files:**
- Create: `P/sliced/tests/Orders.ArchitectureTests.Fixture/Orders.ArchitectureTests.Fixture.csproj`, `Violations.cs`
- Create: `P/sliced/tests/Orders.ArchitectureTests/Orders.ArchitectureTests.csproj`, `SliceRules.cs`, `NegativeControl.cs`

The fixture is a tiny class library whose only purpose is to contain a deliberate cross-slice dependency, so the tests can prove the rule fails when it should (spec §4.4).

- [ ] **Step 1: Create the two projects**

Run (in `sliced/`):

```bash
dotnet new classlib -o tests/Orders.ArchitectureTests.Fixture
dotnet sln add tests/Orders.ArchitectureTests.Fixture
rm tests/Orders.ArchitectureTests.Fixture/Class1.cs
dotnet new xunit -o tests/Orders.ArchitectureTests
dotnet sln add tests/Orders.ArchitectureTests
rm tests/Orders.ArchitectureTests/UnitTest1.cs
dotnet add tests/Orders.ArchitectureTests reference src/Orders.Api tests/Orders.ArchitectureTests.Fixture
dotnet add tests/Orders.ArchitectureTests package TngTech.ArchUnitNET.xUnit --version 0.13.4
```

Replace `tests/Orders.ArchitectureTests.Fixture/Orders.ArchitectureTests.Fixture.csproj`:

```xml
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <RootNamespace>Fixture</RootNamespace>
  </PropertyGroup>
</Project>
```

Replace `tests/Orders.ArchitectureTests/Orders.ArchitectureTests.csproj`:

```xml
<Project Sdk="Microsoft.NET.Sdk">

  <PropertyGroup>
    <IsPackable>false</IsPackable>
  </PropertyGroup>

  <ItemGroup>
    <PackageReference Include="Microsoft.NET.Test.Sdk" Version="17.14.1" />
    <PackageReference Include="TngTech.ArchUnitNET.xUnit" Version="0.13.4" />
    <PackageReference Include="xunit" Version="2.9.3" />
    <PackageReference Include="xunit.runner.visualstudio" Version="3.1.4" />
  </ItemGroup>

  <ItemGroup>
    <ProjectReference Include="..\..\src\Orders.Api\Orders.Api.csproj" />
    <ProjectReference Include="..\Orders.ArchitectureTests.Fixture\Orders.ArchitectureTests.Fixture.csproj" />
  </ItemGroup>

  <ItemGroup>
    <Using Include="Xunit" />
  </ItemGroup>

</Project>
```

- [ ] **Step 2: The fixture with a deliberate violation**

`tests/Orders.ArchitectureTests.Fixture/Violations.cs`:

```csharp
// Deliberate violations. The architecture tests assert that the rules FAIL on this assembly.
namespace Fixture.Features.A
{
    public sealed class AHandler
    {
        public string Handle() => new Fixture.Features.B.BHelper().Value;   // slice A reaches into slice B
    }
}

namespace Fixture.Features.B
{
    public sealed class BHelper
    {
        public string Value => "b";
    }
}

namespace Fixture.Domain
{
    public sealed class Entity
    {
        public string Describe() => Fixture.Platform.Formatter.Format(this);   // domain reaches into platform
    }
}

namespace Fixture.Platform
{
    public static class Formatter
    {
        public static string Format(object value) => value.ToString() ?? "";
    }
}
```

- [ ] **Step 3: Write the negative-control tests first**

`tests/Orders.ArchitectureTests/NegativeControl.cs`:

```csharp
using ArchUnitNET.Domain;
using ArchUnitNET.Loader;
using static ArchUnitNET.Fluent.ArchRuleDefinition;
using static ArchUnitNET.Fluent.Slices.SliceRuleDefinition;

namespace Orders.ArchitectureTests;

/// <summary>Proves the rules can fail: each rule is evaluated against a fixture assembly that violates it.</summary>
public class NegativeControl
{
    private static readonly Architecture FixtureArchitecture =
        new ArchLoader().LoadAssemblies(typeof(global::Fixture.Features.A.AHandler).Assembly).Build();

    [Fact]
    public void Slice_rule_fails_on_a_cross_slice_dependency()
    {
        var rule = Slices().Matching("Fixture.Features.(*)").Should().NotDependOnEachOther();

        Assert.False(rule.HasNoViolations(FixtureArchitecture));
    }

    [Fact]
    public void Domain_rule_fails_when_domain_uses_platform()
    {
        var rule = Types().That().ResideInNamespaceMatching(@"^Fixture\.Domain")
            .Should().NotDependOnAny(Types().That().ResideInNamespaceMatching(@"^Fixture\.(Features|Platform)"));

        Assert.False(rule.HasNoViolations(FixtureArchitecture));
    }
}
```

- [ ] **Step 4: Run — the negative controls must pass (the rules do fail on the fixture)**

Run (in `sliced/`): `dotnet test tests/Orders.ArchitectureTests --nologo`
Expected: `Passed! ... Passed: 2, Total: 2`. If a negative control fails, the rule is not matching anything — fix the pattern before going on.

- [ ] **Step 5: The real rules**

`tests/Orders.ArchitectureTests/SliceRules.cs`:

```csharp
using ArchUnitNET.Domain;
using ArchUnitNET.Loader;
using ArchUnitNET.xUnit;
using static ArchUnitNET.Fluent.ArchRuleDefinition;
using static ArchUnitNET.Fluent.Slices.SliceRuleDefinition;

namespace Orders.ArchitectureTests;

public class SliceRules
{
    private static readonly Architecture Api =
        new ArchLoader().LoadAssemblies(typeof(Program).Assembly).Build();

    [Fact]
    public void Slices_do_not_depend_on_each_other() =>
        Slices().Matching("Orders.Api.Features.(*)")
            .Should().NotDependOnEachOther()
            .Check(Api);

    [Fact]
    public void Domain_does_not_depend_on_features_or_platform() =>
        Types().That().ResideInNamespaceMatching(@"^Orders\.Api\.Domain")
            .Should().NotDependOnAny(Types().That().ResideInNamespaceMatching(@"^Orders\.Api\.(Features|Platform)"))
            .Check(Api);

    [Fact]
    public void Platform_does_not_depend_on_features() =>
        Types().That().ResideInNamespaceMatching(@"^Orders\.Api\.Platform")
            .Should().NotDependOnAny(Types().That().ResideInNamespaceMatching(@"^Orders\.Api\.Features"))
            .Check(Api);
}
```

- [ ] **Step 6: Run all architecture tests**

Run: `dotnet test tests/Orders.ArchitectureTests --nologo`
Expected: `Passed! ... Passed: 5, Total: 5`.

- [ ] **Step 7: Prove the slice rule bites on the real code, then revert**

Temporarily add to `src/Orders.Api/Features/GetOrder/GetOrderHandler.cs` a field `private readonly Orders.Api.Features.CreateOrder.CreateOrderResponse? _leak;` (with `#pragma warning disable CS0169, CS0649` on the line above it, because warnings are errors), run `dotnet test tests/Orders.ArchitectureTests --nologo`.
Expected: `Failed Orders.ArchitectureTests.SliceRules.Slices_do_not_depend_on_each_other` with a message naming `GetOrderHandler` and `CreateOrderResponse`. Then `git checkout -- src/Orders.Api/Features/GetOrder/GetOrderHandler.cs` and re-run: 5 passed.

- [ ] **Step 8: Commit**

```bash
git add prototypes/ai-development/vsa-agent-guardrails/sliced
git commit -m "vsa-agent-guardrails(sliced): architecture tests with negative control"
```

---

### Task 9: Guardrail files — CLAUDE.md, hooks, jscpd (sliced)

**Files:**
- Create: `P/sliced/CLAUDE.md`, `P/sliced/.claude/settings.json`, `P/sliced/.claude/hooks/gate.sh`, `P/sliced/.jscpd.json`

- [ ] **Step 1: CLAUDE.md**

`sliced/CLAUDE.md`:

```markdown
# Orders API (sliced) — conventions for agents

## Commands

- Build: `dotnet build --nologo`
- Behaviour tests: `dotnet test tests/Orders.SliceTests --nologo` (add `--filter FullyQualifiedName~<UseCase>` for one slice)
- Architecture tests: `dotnet test tests/Orders.ArchitectureTests --nologo` — fails on any dependency between slices
- Migrations: `dotnet ef migrations add <Name> --project src/Orders.Api --output-dir Platform/Persistence/Migrations`

## Layout rules

- One use case = one folder under `src/Orders.Api/Features/<UseCase>/`, holding the request, the response,
  the validator (commands only), the handler and the endpoint. `Features/CreateOrder/` is the reference slice:
  copy its shape, not its logic.
- Slices never reference other slices. Code that two slices need lives in `src/Orders.Api/Domain/`
  (entities, value objects, policies) or `src/Orders.Api/Platform/` (persistence, endpoint discovery, HTTP
  concerns). There is no `Common/`, `Shared/` or `Helpers/` folder; do not create one.
- Handlers are discovered by name (`*Handler` under `Features`) and endpoints by `IEndpoint`; nothing is
  registered in `Program.cs` per slice. An endpoint class needs a public parameterless constructor — take
  dependencies as parameters of the route delegate, not of the class.
- A command endpoint adds `.AddEndpointFilter<ValidationFilter<TRequest>>()`, which requires a public
  `<Request>Validator` (`AbstractValidator<TRequest>`) in the slice; the filter throws if none is registered.
- Every slice ships with a test class in `tests/Orders.SliceTests/<UseCase>Tests.cs` that sends the request
  through the endpoint and asserts the response and the persisted state. Use `ApiFixture`; do not mock the
  database.
- Domain rule violations surface as HTTP 409 (`DomainException` or an explicit conflict result); validation
  failures as 400.

## Scope

- Keep a change inside one slice plus its test. If the task needs edits under `Domain/` or `Platform/`, say so
  in your final message and keep those edits minimal.
- Do not edit files under `Platform/Persistence/Migrations/`; generate a new migration with `dotnet ef` instead.
- Before finishing, run the architecture tests and the slice tests; the hooks run them for you as well.
```

- [ ] **Step 2: Hook settings and the gate script**

`sliced/.claude/settings.json`:

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          { "type": "command", "command": "${CLAUDE_PROJECT_DIR}/.claude/hooks/gate.sh", "timeout": 300 }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          { "type": "command", "command": "${CLAUDE_PROJECT_DIR}/.claude/hooks/gate.sh", "timeout": 600 }
        ]
      }
    ]
  }
}
```

`sliced/.claude/hooks/gate.sh` (LF line endings; run `git update-index --chmod=+x` after adding so the executable bit is tracked):

```sh
#!/usr/bin/env sh
# Guardrail gate for Claude Code.
#   PostToolUse (Edit|Write): architecture tests.
#   Stop:                     architecture tests, then the behaviour tests.
# Exit 2 (blocking) with the failure text on stderr. Appends one line per invocation to .gate.log.
cd "$CLAUDE_PROJECT_DIR" || exit 2
input=$(cat)
# The hook input is JSON on stdin; tolerate both compact and pretty-printed forms.
event=$(printf '%s' "$input" | grep -o '"hook_event_name": *"[^"]*"' | head -1 | sed 's/.*"\([^"]*\)"$/\1/')
stamp() { date -u +%Y-%m-%dT%H:%M:%SZ; }

if printf '%s' "$input" | grep -q '"stop_hook_active": *true'; then
  echo "$(stamp) $event skipped stop_hook_active" >> .gate.log
  exit 0
fi

projects="tests/Orders.ArchitectureTests"
if [ "$event" = "Stop" ]; then
  projects="$projects tests/Orders.SliceTests"
fi

for project in $projects; do
  if ! out=$(dotnet test "$project" --nologo -v q 2>&1); then
    echo "$(stamp) $event exit=2 $project" >> .gate.log
    printf '%s\n' "$out" | tail -40 >&2
    exit 2
  fi
done

echo "$(stamp) $event exit=0" >> .gate.log
exit 0
```

- [ ] **Step 3: jscpd config**

`sliced/.jscpd.json`:

```json
{
  "format": ["csharp"],
  "path": ["src"],
  "ignore": ["**/Migrations/**", "**/bin/**", "**/obj/**"],
  "minTokens": 50,
  "minLines": 5,
  "threshold": 0,
  "reporters": ["console", "json"],
  "output": "./.jscpd-report",
  "gitignore": true
}
```

- [ ] **Step 4: Test the gate script by hand**

Run (in `sliced/`, Git Bash):

```bash
chmod +x .claude/hooks/gate.sh
CLAUDE_PROJECT_DIR="$PWD" sh -c 'echo "{\"hook_event_name\":\"Stop\",\"stop_hook_active\":false}" | .claude/hooks/gate.sh'; echo "exit=$?"; cat .gate.log
```

Expected: `exit=0` and a `.gate.log` line ending in `Stop exit=0`. Now break a test (`ShouldBe(HttpStatusCode.Created)` → `ShouldBe(HttpStatusCode.OK)` in `CreateOrderTests.cs`) and repeat: `exit=2`, the failure text on stderr, and a log line `Stop exit=2 tests/Orders.SliceTests`. Revert the test and `rm .gate.log`.

- [ ] **Step 5: Test the gate through Claude Code headlessly (spec §6)**

Run (in `sliced/`, Git Bash) — this makes one short paid call:

```bash
printf 'Change nothing. Reply with the word done.' | claude -p --output-format stream-json --verbose --no-session-persistence --setting-sources project --permission-mode dontAsk --allowedTools Read > /tmp/gate-probe.jsonl 2>/dev/null
grep -c '"hook_event":"Stop"' /tmp/gate-probe.jsonl; cat .gate.log
```

Expected: `.gate.log` contains a `Stop exit=0` line (the hook ran at the end of the turn, both test projects green). The grep count may be 0 — Stop-hook events are not reliably streamed (spec §4.5); `.gate.log` is the evidence. Remove `.gate.log`.

- [ ] **Step 6: Run jscpd once**

Run (in `sliced/`): `npx -y jscpd@4 --config .jscpd.json`
Expected: a console table with `csharp` and no clones (`Found 0 clones.`); `.jscpd-report/jscpd-report.json` exists with `"statistics": { "total": { ... "clones": 0, ... "percentage": 0 } }`. Note the exact key names — `Parse-Events.ps1` does not read this file, but `run.ps1` (Task 17) reads `statistics.total.clones` and `statistics.total.percentage`.

- [ ] **Step 7: Commit**

```bash
git add prototypes/ai-development/vsa-agent-guardrails/sliced
git update-index --chmod=+x prototypes/ai-development/vsa-agent-guardrails/sliced/.claude/hooks/gate.sh
git commit -m "vsa-agent-guardrails(sliced): CLAUDE.md, hooks, jscpd"
```

---
## Part B — the layered copy

The layered copy implements the same four use cases with the same JSON, the same status codes and the same test cases, in four projects. Reuse nothing from `sliced/` at the file level — the copies must stay independent — but the *code* below is deliberately the same logic moved into layers, so the only variable is layout.

### Task 10: Scaffold the layered solution and the Domain project

**Files:**
- Create: `P/layered/Orders.sln`, `Directory.Build.props`, `.config/dotnet-tools.json`, `src/Orders.Domain/*`, `src/Orders.Application/*.csproj`, `src/Orders.Infrastructure/*.csproj`, `src/Orders.Api/*.csproj`

- [ ] **Step 1: Create the projects**

```bash
cd prototypes/ai-development/vsa-agent-guardrails && mkdir layered && cd layered
dotnet new sln -n Orders
dotnet new classlib -o src/Orders.Domain
dotnet new classlib -o src/Orders.Application
dotnet new classlib -o src/Orders.Infrastructure
dotnet new web -o src/Orders.Api
dotnet sln add src/Orders.Domain src/Orders.Application src/Orders.Infrastructure src/Orders.Api
rm src/Orders.Domain/Class1.cs src/Orders.Application/Class1.cs src/Orders.Infrastructure/Class1.cs
dotnet add src/Orders.Application reference src/Orders.Domain
dotnet add src/Orders.Infrastructure reference src/Orders.Application
dotnet add src/Orders.Api reference src/Orders.Application src/Orders.Infrastructure
dotnet add src/Orders.Application package FluentValidation.DependencyInjectionExtensions --version 12.1.1
dotnet add src/Orders.Application package Microsoft.EntityFrameworkCore --version 10.0.11
dotnet add src/Orders.Infrastructure package Microsoft.EntityFrameworkCore.Sqlite --version 10.0.11
dotnet add src/Orders.Infrastructure package Microsoft.EntityFrameworkCore.Design --version 10.0.11
dotnet add src/Orders.Api package Microsoft.EntityFrameworkCore.Design --version 10.0.11
dotnet new tool-manifest
dotnet tool install dotnet-ef --version 10.0.11
```

Create `layered/Directory.Build.props` with exactly the content of `sliced/Directory.Build.props` (Task 1, Step 3).

- [ ] **Step 2: Domain project**

`src/Orders.Domain/Enums/OrderStatus.cs`:

```csharp
namespace Orders.Domain.Enums;

public enum OrderStatus
{
    Pending,
    Shipped,
    Cancelled,
}
```

`src/Orders.Domain/Exceptions/DomainException.cs`:

```csharp
namespace Orders.Domain.Exceptions;

/// <summary>A business rule was violated. Mapped to HTTP 409 by the API.</summary>
public sealed class DomainException(string message) : Exception(message);
```

`src/Orders.Domain/Entities/OrderLine.cs`:

```csharp
namespace Orders.Domain.Entities;

public sealed class OrderLine
{
    public OrderLine(string sku, int quantity, decimal unitPrice)
    {
        Sku = sku;
        Quantity = quantity;
        UnitPrice = unitPrice;
    }

    public string Sku { get; private set; }
    public int Quantity { get; private set; }
    public decimal UnitPrice { get; private set; }

    public decimal Total => Quantity * UnitPrice;
}
```

`src/Orders.Domain/Entities/Order.cs`:

```csharp
using Orders.Domain.Enums;
using Orders.Domain.Exceptions;

namespace Orders.Domain.Entities;

public sealed class Order
{
    private Order() { }

    public Guid Id { get; private set; }
    public string CustomerId { get; private set; } = "";
    public OrderStatus Status { get; private set; }
    public DateTimeOffset CreatedAt { get; private set; }
    public DateTimeOffset? ShippedAt { get; private set; }
    public DateTimeOffset? CancelledAt { get; private set; }
    public List<OrderLine> Lines { get; private set; } = new();

    public decimal Total => Lines.Sum(l => l.Total);

    public static Order Create(string customerId, IEnumerable<OrderLine> lines, DateTimeOffset now)
    {
        var order = new Order
        {
            Id = Guid.NewGuid(),
            CustomerId = customerId,
            Status = OrderStatus.Pending,
            CreatedAt = now,
        };
        order.Lines.AddRange(lines);
        if (order.Lines.Count == 0)
        {
            throw new DomainException("An order needs at least one line.");
        }
        return order;
    }

    public void Ship(DateTimeOffset now)
    {
        if (Status != OrderStatus.Pending)
        {
            throw new DomainException($"Order {Id} cannot be shipped because it is {Status}.");
        }
        Status = OrderStatus.Shipped;
        ShippedAt = now;
    }

    public void Cancel(DateTimeOffset now)
    {
        if (Status == OrderStatus.Cancelled)
        {
            throw new DomainException($"Order {Id} is already cancelled.");
        }
        Status = OrderStatus.Cancelled;
        CancelledAt = now;
    }
}
```

`src/Orders.Domain/Policies/CancellationPolicy.cs`:

```csharp
using Orders.Domain.Entities;
using Orders.Domain.Enums;

namespace Orders.Domain.Policies;

public static class CancellationPolicy
{
    /// <summary>Only already-cancelled orders cannot be cancelled. Shipped orders can (for now).</summary>
    public static bool CanCancel(Order order) => order.Status != OrderStatus.Cancelled;
}
```

- [ ] **Step 3: Build**

Run (in `layered/`): `dotnet build --nologo`
Expected: `Build succeeded.`, 0 warnings.

- [ ] **Step 4: Commit**

```bash
git add prototypes/ai-development/vsa-agent-guardrails/layered
git commit -m "vsa-agent-guardrails(layered): scaffold and domain"
```

---

### Task 11: Application layer — commands, queries, validators, DTOs (layered)

**Files:**
- Create: `P/layered/src/Orders.Application/Common/Interfaces/IOrdersDbContext.cs`, `DependencyInjection.cs`, `Orders/Commands/CreateOrder/{CreateOrderCommand,CreateOrderCommandValidator,CreateOrderCommandHandler}.cs`, `Orders/Commands/CancelOrder/{CancelOrderCommandHandler}.cs`, `Orders/Queries/GetOrder/{GetOrderQueryHandler}.cs`, `Orders/Queries/ListOrders/{ListOrdersQueryHandler}.cs`, `Orders/OrderDtos.cs`

The DTO records carry exactly the property names of the sliced copy's response records, so the JSON is identical.

- [ ] **Step 1: The persistence abstraction and DI**

`src/Orders.Application/Common/Interfaces/IOrdersDbContext.cs`:

```csharp
using Microsoft.EntityFrameworkCore;
using Orders.Domain.Entities;

namespace Orders.Application.Common.Interfaces;

public interface IOrdersDbContext
{
    DbSet<Order> Orders { get; }
    Task<int> SaveChangesAsync(CancellationToken cancellationToken);
}
```

`src/Orders.Application/DependencyInjection.cs`:

```csharp
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
```

- [ ] **Step 2: DTOs**

`src/Orders.Application/Orders/OrderDtos.cs`:

```csharp
namespace Orders.Application.Orders;

public sealed record CreateOrderResult(Guid Id, string Status);

public sealed record CancelOrderResult(Guid Id, string Status, DateTimeOffset? CancelledAt);

public sealed record OrderDto(
    Guid Id,
    string CustomerId,
    string Status,
    DateTimeOffset CreatedAt,
    DateTimeOffset? ShippedAt,
    DateTimeOffset? CancelledAt,
    IReadOnlyList<OrderLineDto> Lines,
    decimal Total);

public sealed record OrderLineDto(string Sku, int Quantity, decimal UnitPrice);

public sealed record OrderListDto(IReadOnlyList<OrderSummaryDto> Orders);

public sealed record OrderSummaryDto(Guid Id, string CustomerId, string Status, DateTimeOffset CreatedAt, int LineCount, decimal Total);
```

- [ ] **Step 3: CreateOrder command**

`src/Orders.Application/Orders/Commands/CreateOrder/CreateOrderCommand.cs`:

```csharp
namespace Orders.Application.Orders.Commands.CreateOrder;

public sealed record CreateOrderCommand(string CustomerId, IReadOnlyList<CreateOrderLine> Lines);

public sealed record CreateOrderLine(string Sku, int Quantity, decimal UnitPrice);
```

`Orders/Commands/CreateOrder/CreateOrderCommandValidator.cs`:

```csharp
using FluentValidation;

namespace Orders.Application.Orders.Commands.CreateOrder;

public sealed class CreateOrderCommandValidator : AbstractValidator<CreateOrderCommand>
{
    public CreateOrderCommandValidator()
    {
        RuleFor(c => c.CustomerId).NotEmpty().MaximumLength(100);
        RuleFor(c => c.Lines).NotEmpty().WithMessage("At least one line is required.");   // deliberately not the domain's wording: the 400 (shape) and the 409 (invariant) are independent
        RuleForEach(c => c.Lines).ChildRules(line =>
        {
            line.RuleFor(l => l.Sku).NotEmpty().MaximumLength(50);
            line.RuleFor(l => l.Quantity).GreaterThan(0);
            line.RuleFor(l => l.UnitPrice).GreaterThan(0);
        });
    }
}
```

`Orders/Commands/CreateOrder/CreateOrderCommandHandler.cs`:

```csharp
using Orders.Application.Common.Interfaces;
using Orders.Domain.Entities;

namespace Orders.Application.Orders.Commands.CreateOrder;

public sealed class CreateOrderCommandHandler(IOrdersDbContext db, TimeProvider clock)
{
    public async Task<CreateOrderResult> Handle(CreateOrderCommand command, CancellationToken cancellationToken)
    {
        var lines = command.Lines.Select(l => new OrderLine(l.Sku, l.Quantity, l.UnitPrice));
        var order = Order.Create(command.CustomerId, lines, clock.GetUtcNow());

        db.Orders.Add(order);
        await db.SaveChangesAsync(cancellationToken);

        return new CreateOrderResult(order.Id, order.Status.ToString());
    }
}
```

- [ ] **Step 4: CancelOrder command**

`Orders/Commands/CancelOrder/CancelOrderCommandHandler.cs`:

```csharp
using Microsoft.EntityFrameworkCore;
using Orders.Application.Common.Interfaces;
using Orders.Domain.Policies;

namespace Orders.Application.Orders.Commands.CancelOrder;

public sealed class CancelOrderCommandHandler(IOrdersDbContext db, TimeProvider clock)
{
    public sealed record Result(CancelOrderResult? Response, string? Conflict, bool NotFound);

    public async Task<Result> Handle(Guid id, CancellationToken cancellationToken)
    {
        var order = await db.Orders.SingleOrDefaultAsync(o => o.Id == id, cancellationToken);
        if (order is null)
        {
            return new Result(null, null, NotFound: true);
        }
        if (!CancellationPolicy.CanCancel(order))
        {
            return new Result(null, $"Order {id} cannot be cancelled because it is {order.Status}.", NotFound: false);
        }

        order.Cancel(clock.GetUtcNow());
        await db.SaveChangesAsync(cancellationToken);

        return new Result(new CancelOrderResult(order.Id, order.Status.ToString(), order.CancelledAt), null, NotFound: false);
    }
}
```

- [ ] **Step 5: Queries**

`Orders/Queries/GetOrder/GetOrderQueryHandler.cs`:

```csharp
using Microsoft.EntityFrameworkCore;
using Orders.Application.Common.Interfaces;

namespace Orders.Application.Orders.Queries.GetOrder;

public sealed class GetOrderQueryHandler(IOrdersDbContext db)
{
    public async Task<OrderDto?> Handle(Guid id, CancellationToken cancellationToken)
    {
        var order = await db.Orders.AsNoTracking().SingleOrDefaultAsync(o => o.Id == id, cancellationToken);
        if (order is null)
        {
            return null;
        }
        return new OrderDto(
            order.Id,
            order.CustomerId,
            order.Status.ToString(),
            order.CreatedAt,
            order.ShippedAt,
            order.CancelledAt,
            order.Lines.Select(l => new OrderLineDto(l.Sku, l.Quantity, l.UnitPrice)).ToList(),
            order.Total);
    }
}
```

`Orders/Queries/ListOrders/ListOrdersQueryHandler.cs`:

```csharp
using Microsoft.EntityFrameworkCore;
using Orders.Application.Common.Interfaces;
using Orders.Domain.Enums;

namespace Orders.Application.Orders.Queries.ListOrders;

public sealed class ListOrdersQueryHandler(IOrdersDbContext db)
{
    public async Task<OrderListDto> Handle(OrderStatus? status, CancellationToken cancellationToken)
    {
        var query = db.Orders.AsNoTracking();
        if (status is not null)
        {
            query = query.Where(o => o.Status == status);
        }

        var orders = await query.OrderByDescending(o => o.CreatedAt).ToListAsync(cancellationToken);

        return new OrderListDto(orders
            .Select(o => new OrderSummaryDto(o.Id, o.CustomerId, o.Status.ToString(), o.CreatedAt, o.Lines.Count, o.Total))
            .ToList());
    }
}
```

- [ ] **Step 6: Build**

Run (in `layered/`): `dotnet build --nologo`
Expected: `Build succeeded.`, 0 warnings.

- [ ] **Step 7: Commit**

```bash
git add prototypes/ai-development/vsa-agent-guardrails/layered
git commit -m "vsa-agent-guardrails(layered): application layer"
```

---

### Task 12: Infrastructure and Api layers, first migration (layered)

**Files:**
- Create: `P/layered/src/Orders.Infrastructure/Persistence/OrdersDbContext.cs`, `DependencyInjection.cs`, `Persistence/Migrations/*` (generated)
- Create: `P/layered/src/Orders.Api/Common/ValidationFilter.cs`, `Common/DomainExceptionHandler.cs`, `Endpoints/OrdersEndpoints.cs`
- Modify: `P/layered/src/Orders.Api/Program.cs`, `appsettings.json`

- [ ] **Step 1: Infrastructure**

`src/Orders.Infrastructure/Persistence/OrdersDbContext.cs`:

```csharp
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Storage.ValueConversion;
using Orders.Application.Common.Interfaces;
using Orders.Domain.Entities;

namespace Orders.Infrastructure.Persistence;

public sealed class OrdersDbContext(DbContextOptions<OrdersDbContext> options) : DbContext(options), IOrdersDbContext
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
```

`src/Orders.Infrastructure/DependencyInjection.cs`:

```csharp
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Orders.Application.Common.Interfaces;
using Orders.Infrastructure.Persistence;

namespace Orders.Infrastructure;

public static class DependencyInjection
{
    /// <summary>The composition root passes the connection string; the library takes no configuration dependency.</summary>
    public static IServiceCollection AddInfrastructure(this IServiceCollection services, string connectionString)
    {
        services.AddDbContext<OrdersDbContext>(options => options.UseSqlite(connectionString));
        services.AddScoped<IOrdersDbContext>(sp => sp.GetRequiredService<OrdersDbContext>());
        services.AddSingleton(TimeProvider.System);
        return services;
    }
}
```

In `src/Orders.Infrastructure/Orders.Infrastructure.csproj`, the `dotnet add package` calls in Task 10 created the two `PackageReference`s; give the Design package `<PrivateAssets>all</PrivateAssets>` as in the sliced csproj (Task 1, Step 3). No other change: `IServiceCollection` and `AddDbContext` come with the EF Core package.

- [ ] **Step 2: Api — HTTP concerns**

`src/Orders.Api/Common/ValidationFilter.cs`:

```csharp
using FluentValidation;

namespace Orders.Api.Common;

/// <summary>
/// Runs the FluentValidation validator registered for TRequest; 400 with ProblemDetails on failure.
/// Adding this filter to an endpoint is a statement that a validator exists, so a missing registration
/// throws at request time (a 500 in the slice test) instead of silently skipping validation.
/// </summary>
public sealed class ValidationFilter<TRequest> : IEndpointFilter
{
    public async ValueTask<object?> InvokeAsync(EndpointFilterInvocationContext context, EndpointFilterDelegate next)
    {
        var validator = context.HttpContext.RequestServices.GetService<IValidator<TRequest>>()
            ?? throw new InvalidOperationException(
                $"No validator is registered for {typeof(TRequest).Name}. Add a public class deriving from AbstractValidator<{typeof(TRequest).Name}> next to the request.");
        var request = context.Arguments.OfType<TRequest>().FirstOrDefault();
        if (request is not null)
        {
            var result = await validator.ValidateAsync(request, context.HttpContext.RequestAborted);
            if (!result.IsValid)
            {
                return TypedResults.ValidationProblem(result.ToDictionary());
            }
        }
        return await next(context);
    }
}
```

`src/Orders.Api/Common/DomainExceptionHandler.cs`:

```csharp
using Microsoft.AspNetCore.Diagnostics;
using Microsoft.AspNetCore.Mvc;
using Orders.Domain.Exceptions;

namespace Orders.Api.Common;

public sealed class DomainExceptionHandler : IExceptionHandler
{
    public async ValueTask<bool> TryHandleAsync(HttpContext httpContext, Exception exception, CancellationToken cancellationToken)
    {
        if (exception is not DomainException || httpContext.Response.HasStarted)
        {
            return false;
        }
        httpContext.Response.StatusCode = StatusCodes.Status409Conflict;
        await httpContext.Response.WriteAsJsonAsync(new ProblemDetails
        {
            Status = StatusCodes.Status409Conflict,
            Title = "Business rule violated",
            Detail = exception.Message,
        }, options: null, contentType: "application/problem+json", cancellationToken);   // same media type as Results.Problem
        return true;
    }
}
```

- [ ] **Step 3: Api — all routes in one endpoints file**

`src/Orders.Api/Endpoints/OrdersEndpoints.cs`:

```csharp
using Orders.Api.Common;
using Orders.Application.Orders.Commands.CancelOrder;
using Orders.Application.Orders.Commands.CreateOrder;
using Orders.Application.Orders.Queries.GetOrder;
using Orders.Application.Orders.Queries.ListOrders;
using Orders.Domain.Enums;

namespace Orders.Api.Endpoints;

public static class OrdersEndpoints
{
    public static IEndpointRouteBuilder MapOrdersEndpoints(this IEndpointRouteBuilder app)
    {
        var group = app.MapGroup("/orders");

        group.MapPost("/", async (CreateOrderCommand command, CreateOrderCommandHandler handler, CancellationToken cancellationToken) =>
            {
                var result = await handler.Handle(command, cancellationToken);
                return Results.Created($"/orders/{result.Id}", result);
            })
            .AddEndpointFilter<ValidationFilter<CreateOrderCommand>>();

        group.MapGet("/{id:guid}", async (Guid id, GetOrderQueryHandler handler, CancellationToken cancellationToken) =>
        {
            var order = await handler.Handle(id, cancellationToken);
            return order is null ? Results.NotFound() : Results.Ok(order);
        });

        group.MapGet("/", async (string? status, ListOrdersQueryHandler handler, CancellationToken cancellationToken) =>
        {
            OrderStatus? filter = null;
            if (status is not null)
            {
                if (!Enum.TryParse<OrderStatus>(status, ignoreCase: true, out var parsed))
                {
                    return Results.ValidationProblem(new Dictionary<string, string[]>
                    {
                        ["status"] = [$"'{status}' is not one of {string.Join(", ", Enum.GetNames<OrderStatus>())}."],
                    });
                }
                filter = parsed;
            }
            return Results.Ok(await handler.Handle(filter, cancellationToken));
        });

        group.MapPost("/{id:guid}/cancel", async (Guid id, CancelOrderCommandHandler handler, CancellationToken cancellationToken) =>
        {
            var result = await handler.Handle(id, cancellationToken);
            if (result.NotFound)
            {
                return Results.NotFound();
            }
            if (result.Conflict is not null)
            {
                return Results.Problem(statusCode: StatusCodes.Status409Conflict, title: "Business rule violated", detail: result.Conflict);
            }
            return Results.Ok(result.Response);
        });

        return app;
    }
}
```

- [ ] **Step 4: Program.cs, appsettings, csproj**

Replace `src/Orders.Api/Program.cs`:

```csharp
using Microsoft.EntityFrameworkCore;
using Orders.Api.Common;
using Orders.Api.Endpoints;
using Orders.Application;
using Orders.Infrastructure;
using Orders.Infrastructure.Persistence;

var builder = WebApplication.CreateBuilder(args);

// Fail at startup, not on first request, when a handler depends on something that is not registered.
builder.Host.UseDefaultServiceProvider(options =>
{
    options.ValidateOnBuild = true;
    options.ValidateScopes = true;
});

builder.Services.AddApplication();
builder.Services.AddInfrastructure(builder.Configuration.GetConnectionString("Orders") ?? "Data Source=orders.db");
// In Development and Testing, put the exception message in the 500 body so a failing test or curl says why.
var exposeExceptionDetail = builder.Environment.IsDevelopment() || builder.Environment.IsEnvironment("Testing");
builder.Services.AddProblemDetails(options => options.CustomizeProblemDetails = context =>
{
    if (exposeExceptionDetail && context.Exception is not null)
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

app.MapOrdersEndpoints();

app.Run();

public partial class Program { }
```

Replace `src/Orders.Api/appsettings.json` with the content from Task 3, Step 4. Replace `src/Orders.Api/Orders.Api.csproj`:

```xml
<Project Sdk="Microsoft.NET.Sdk.Web">

  <ItemGroup>
    <PackageReference Include="Microsoft.EntityFrameworkCore.Design" Version="10.0.11">
      <PrivateAssets>all</PrivateAssets>
      <IncludeAssets>runtime; build; native; contentfiles; analyzers; buildtransitive</IncludeAssets>
    </PackageReference>
  </ItemGroup>

  <ItemGroup>
    <ProjectReference Include="..\Orders.Application\Orders.Application.csproj" />
    <ProjectReference Include="..\Orders.Infrastructure\Orders.Infrastructure.csproj" />
  </ItemGroup>

  <ItemGroup>
    <InternalsVisibleTo Include="Orders.IntegrationTests" />
  </ItemGroup>

</Project>
```

- [ ] **Step 5: Build and add the migration**

Run (in `layered/`):

```bash
dotnet build --nologo
dotnet ef migrations add InitialCreate --project src/Orders.Infrastructure --startup-project src/Orders.Api --output-dir Persistence/Migrations
```

Expected: `Build succeeded.`; `Done.`; three files under `src/Orders.Infrastructure/Persistence/Migrations/` creating `Orders` and `OrderLines` with the same columns as the sliced copy's migration (compare the two `Up` methods — they must define the same tables and columns).

- [ ] **Step 6: Commit**

```bash
git add prototypes/ai-development/vsa-agent-guardrails/layered
git commit -m "vsa-agent-guardrails(layered): infrastructure, api, first migration"
```

---

### Task 13: Integration tests — the same cases as the slice tests (layered)

**Files:**
- Create: `P/layered/tests/Orders.IntegrationTests/Orders.IntegrationTests.csproj`, `ApiFixture.cs`, `CreateOrderTests.cs`, `GetOrderTests.cs`, `CancelOrderTests.cs`, `ListOrdersTests.cs`

- [ ] **Step 1: Create the project**

Run (in `layered/`):

```bash
dotnet new xunit -o tests/Orders.IntegrationTests
dotnet sln add tests/Orders.IntegrationTests
rm tests/Orders.IntegrationTests/UnitTest1.cs
```

Replace `tests/Orders.IntegrationTests/Orders.IntegrationTests.csproj` with the content of `sliced/tests/Orders.SliceTests/Orders.SliceTests.csproj` (Task 4, Step 1), changing the project reference to `..\..\src\Orders.Api\Orders.Api.csproj` (same relative path) — the file is otherwise identical.

- [ ] **Step 2: Fixture**

`tests/Orders.IntegrationTests/ApiFixture.cs` — identical to the sliced fixture except for the namespaces:

```csharp
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Data.Sqlite;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Orders.Domain.Entities;
using Orders.Domain.Enums;
using Orders.Infrastructure.Persistence;

namespace Orders.IntegrationTests;

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
```

- [ ] **Step 3: The assertion helper and the four test classes**

Copy `HttpAssertions.cs` and the four test files from `sliced/tests/Orders.SliceTests/` (Tasks 4–7) into `tests/Orders.IntegrationTests/` and apply exactly these edits to each:

- `namespace Orders.SliceTests;` → `namespace Orders.IntegrationTests;`
- `using Orders.Api.Domain;` → `using Orders.Domain.Enums;`
- `using Orders.Api.Features.CreateOrder;` → `using Orders.Application.Orders;` and `CreateOrderResponse` → `CreateOrderResult`
- `using Orders.Api.Features.GetOrder;` → `using Orders.Application.Orders;` and `GetOrderResponse` → `OrderDto`
- `using Orders.Api.Features.CancelOrder;` → `using Orders.Application.Orders;` and `CancelOrderResponse` → `CancelOrderResult`
- `using Orders.Api.Features.ListOrders;` → `using Orders.Application.Orders;` and `ListOrdersResponse` → `OrderListDto`

Test method names, requests, and assertions stay byte-for-byte the same — that is the parity contract. The file names and method names are compared by `Test-Parity.ps1` (Task 19).

- [ ] **Step 4: Run**

Run (in `layered/`): `dotnet test tests/Orders.IntegrationTests --nologo`
Expected: `Passed! ... Passed: 13, Total: 13` — the same count as the sliced suite.

- [ ] **Step 5: Commit**

```bash
git add prototypes/ai-development/vsa-agent-guardrails/layered
git commit -m "vsa-agent-guardrails(layered): integration tests mirroring the slice tests"
```

---

### Task 14: Architecture tests and guardrail files (layered)

**Files:**
- Create: `P/layered/tests/Orders.ArchitectureTests.Fixture/{Orders.ArchitectureTests.Fixture.csproj,Violations.cs}`, `P/layered/tests/Orders.ArchitectureTests/{Orders.ArchitectureTests.csproj,LayerRules.cs,NegativeControl.cs}`
- Create: `P/layered/CLAUDE.md`, `.claude/settings.json`, `.claude/hooks/gate.sh`, `.jscpd.json`

- [ ] **Step 1: Projects**

Run (in `layered/`):

```bash
dotnet new classlib -o tests/Orders.ArchitectureTests.Fixture
dotnet sln add tests/Orders.ArchitectureTests.Fixture
rm tests/Orders.ArchitectureTests.Fixture/Class1.cs
dotnet new xunit -o tests/Orders.ArchitectureTests
dotnet sln add tests/Orders.ArchitectureTests
rm tests/Orders.ArchitectureTests/UnitTest1.cs
dotnet add tests/Orders.ArchitectureTests reference src/Orders.Api src/Orders.Application src/Orders.Infrastructure src/Orders.Domain tests/Orders.ArchitectureTests.Fixture
dotnet add tests/Orders.ArchitectureTests package TngTech.ArchUnitNET.xUnit --version 0.13.4
```

Replace the fixture csproj with the content from Task 8, Step 1 (`RootNamespace` `Fixture`). Replace `tests/Orders.ArchitectureTests/Orders.ArchitectureTests.csproj` with the Task 8 version plus the three extra `ProjectReference`s (`Orders.Application`, `Orders.Infrastructure`, `Orders.Domain`).

- [ ] **Step 2: Fixture violation**

`tests/Orders.ArchitectureTests.Fixture/Violations.cs`:

```csharp
// Deliberate violations. The architecture tests assert that the rules FAIL on this assembly.
namespace Fixture.Domain
{
    public sealed class Entity
    {
        public string Describe() => Fixture.Application.Formatter.Format(this);   // domain reaches up into application
    }
}

namespace Fixture.Application
{
    public static class Formatter
    {
        public static string Format(object value) => new Fixture.Infrastructure.Repo().Save(value);   // application reaches down into infrastructure
    }
}

namespace Fixture.Infrastructure
{
    public sealed class Repo
    {
        public string Save(object value) => value.ToString() ?? "";
    }
}
```

- [ ] **Step 3: Negative control**

`tests/Orders.ArchitectureTests/NegativeControl.cs`:

```csharp
using ArchUnitNET.Domain;
using ArchUnitNET.Loader;
using static ArchUnitNET.Fluent.ArchRuleDefinition;

namespace Orders.ArchitectureTests;

public class NegativeControl
{
    private static readonly Architecture FixtureArchitecture =
        new ArchLoader().LoadAssemblies(typeof(global::Fixture.Domain.Entity).Assembly).Build();

    [Fact]
    public void Domain_rule_fails_when_domain_uses_application()
    {
        var rule = Types().That().ResideInNamespaceMatching(@"^Fixture\.Domain")
            .Should().NotDependOnAny(Types().That().ResideInNamespaceMatching(@"^Fixture\.(Application|Infrastructure)"));

        Assert.False(rule.HasNoViolations(FixtureArchitecture));
    }

    [Fact]
    public void Application_rule_fails_when_application_uses_infrastructure()
    {
        var rule = Types().That().ResideInNamespaceMatching(@"^Fixture\.Application")
            .Should().NotDependOnAny(Types().That().ResideInNamespaceMatching(@"^Fixture\.Infrastructure"));

        Assert.False(rule.HasNoViolations(FixtureArchitecture));
    }
}
```

Run: `dotnet test tests/Orders.ArchitectureTests --nologo` — Expected: `Passed: 2`.

- [ ] **Step 4: The real rules**

`tests/Orders.ArchitectureTests/LayerRules.cs`:

```csharp
using ArchUnitNET.Domain;
using ArchUnitNET.Loader;
using ArchUnitNET.xUnit;
using static ArchUnitNET.Fluent.ArchRuleDefinition;

namespace Orders.ArchitectureTests;

public class LayerRules
{
    private static readonly Architecture Layers = new ArchLoader().LoadAssemblies(
        typeof(Orders.Domain.Entities.Order).Assembly,
        typeof(Orders.Application.DependencyInjection).Assembly,
        typeof(Orders.Infrastructure.DependencyInjection).Assembly,
        typeof(Program).Assembly).Build();

    [Fact]
    public void Domain_depends_on_no_other_layer() =>
        Types().That().ResideInNamespaceMatching(@"^Orders\.Domain")
            .Should().NotDependOnAny(Types().That().ResideInNamespaceMatching(@"^Orders\.(Application|Infrastructure|Api)"))
            .Check(Layers);

    [Fact]
    public void Application_does_not_depend_on_infrastructure_or_api() =>
        Types().That().ResideInNamespaceMatching(@"^Orders\.Application")
            .Should().NotDependOnAny(Types().That().ResideInNamespaceMatching(@"^Orders\.(Infrastructure|Api)"))
            .Check(Layers);

    [Fact]
    public void Api_does_not_use_persistence_directly() =>
        Types().That().ResideInNamespaceMatching(@"^Orders\.Api")
            .Should().NotDependOnAny(Types().That().ResideInNamespaceMatching(@"^Orders\.Infrastructure\.Persistence"))
            .Check(Layers);
}
```

(`Program` has no namespace, so the composition root's `Migrate()` call is outside the third rule on purpose.)

Run: `dotnet test tests/Orders.ArchitectureTests --nologo` — Expected: `Passed: 5`.

- [ ] **Step 5: Guardrail files**

`layered/CLAUDE.md`:

```markdown
# Orders API (layered) — conventions for agents

## Commands

- Build: `dotnet build --nologo`
- Behaviour tests: `dotnet test tests/Orders.IntegrationTests --nologo` (add `--filter FullyQualifiedName~<UseCase>` for one)
- Architecture tests: `dotnet test tests/Orders.ArchitectureTests --nologo` — fails on any dependency that points outward
- Migrations: `dotnet ef migrations add <Name> --project src/Orders.Infrastructure --startup-project src/Orders.Api --output-dir Persistence/Migrations`

## Layout rules

- `src/Orders.Domain`: entities, enums, policies, exceptions. Depends on nothing else.
- `src/Orders.Application`: one folder per command or query under `Orders/Commands/<Name>/` or `Orders/Queries/<Name>/`
  (command/query record, validator for commands, handler class), DTOs in `Orders/OrderDtos.cs`, the `IOrdersDbContext`
  abstraction in `Common/Interfaces/`. Register every handler in `DependencyInjection.cs`. `Orders/Commands/CreateOrder/`
  is the reference command: copy its shape, not its logic. Depends on Domain only. A command endpoint adds
  `.AddEndpointFilter<ValidationFilter<TCommand>>()`, which requires a public `<Command>Validator` in the
  command's folder; the filter throws if none is registered.
- `src/Orders.Infrastructure`: `OrdersDbContext`, migrations, `DependencyInjection.cs`. Depends on Application and Domain.
- `src/Orders.Api`: all routes in `Endpoints/OrdersEndpoints.cs`; HTTP concerns in `Common/`. Never reference
  `Orders.Infrastructure.Persistence` from the API; the composition root in `Program.cs` is the only exception.
- Every command or query ships with a test class in `tests/Orders.IntegrationTests/<UseCase>Tests.cs` that sends the
  request through the endpoint and asserts the response and the persisted state. Use `ApiFixture`; do not mock the database.
- Domain rule violations surface as HTTP 409 (`DomainException` or an explicit conflict result); validation failures as 400.

## Scope

- Keep a change to the layers it needs and its test. If the task needs edits under `Orders.Domain` or
  `Orders.Infrastructure`, say so in your final message and keep those edits minimal.
- Do not edit files under `Persistence/Migrations/`; generate a new migration with `dotnet ef` instead.
- Before finishing, run the architecture tests and the integration tests; the hooks run them for you as well.
```

`layered/.claude/settings.json`: identical to `sliced/.claude/settings.json` (Task 9, Step 2).

`layered/.claude/hooks/gate.sh`: identical to the sliced one (Task 9, Step 2) except the behaviour-test project line:

```sh
if [ "$event" = "Stop" ]; then
  projects="$projects tests/Orders.IntegrationTests"
fi
```

`layered/.jscpd.json`: identical to `sliced/.jscpd.json` (Task 9, Step 3).

- [ ] **Step 6: Test the gate and jscpd**

Run (in `layered/`, Git Bash): the hand test from Task 9, Step 4 (expect `Stop exit=0`, then `exit=2` with a broken test, then revert), and `npx -y jscpd@4 --config .jscpd.json` (expect 0 clones). Remove `.gate.log`.

- [ ] **Step 7: Commit**

```bash
git add prototypes/ai-development/vsa-agent-guardrails/layered
git update-index --chmod=+x prototypes/ai-development/vsa-agent-guardrails/layered/.claude/hooks/gate.sh
git commit -m "vsa-agent-guardrails(layered): architecture tests, CLAUDE.md, hooks, jscpd"
```

---
## Part C — the experiment

### Task 15: Task prompts

**Files:**
- Create: `P/experiment/tasks/T1-ship-order.md`, `T2-no-cancel-after-ship.md`, `T3-orders-by-customer.md`, `T4-audit-trail.md`, `T5-order-notes.md`

Front matter is `key: value` lines between `---` fences; `scope.sliced` and `scope.layered` are comma-separated globs (`*` = one path segment, `**` = any depth). The body is the prompt, identical for both copies, written like a ticket — behaviour and acceptance criteria, never file names.

- [ ] **Step 1: Write the five files**

`experiment/tasks/T1-ship-order.md`:

```markdown
---
id: T1
title: Ship an order
kind: slice-local
scope.sliced: src/Orders.Api/Features/Ship*/**, tests/Orders.SliceTests/**
scope.layered: src/Orders.Application/Orders/Commands/Ship*/**, src/Orders.Application/DependencyInjection.cs, src/Orders.Application/Orders/OrderDtos.cs, src/Orders.Api/Endpoints/**, tests/Orders.IntegrationTests/**
---
Add the ability to ship an order.

`POST /orders/{id}/ship`:
- 404 for an unknown order.
- 409 (ProblemDetails, title "Business rule violated") if the order is not Pending.
- Otherwise 200 with `{ "id", "status", "shippedAt" }`, and the order is stored as Shipped with the shipping time.

Add tests covering all three outcomes, following the conventions of the existing tests. Run the tests before you finish.
```

`experiment/tasks/T2-no-cancel-after-ship.md`:

```markdown
---
id: T2
title: Shipped orders cannot be cancelled
kind: slice-local
scope.sliced: src/Orders.Api/Features/CancelOrder/**, src/Orders.Api/Domain/CancellationPolicy.cs, tests/Orders.SliceTests/**
scope.layered: src/Orders.Application/Orders/Commands/CancelOrder/**, src/Orders.Domain/Policies/**, tests/Orders.IntegrationTests/**
---
Shipped orders can no longer be cancelled.

`POST /orders/{id}/cancel` on a Shipped order must return 409 with a ProblemDetails whose `detail` says that shipped orders cannot be cancelled. Pending orders still cancel as before; already-cancelled orders still return 409; unknown orders still return 404.

Update or add tests so that the suite reflects the new rule. Run the tests before you finish.
```

`experiment/tasks/T3-orders-by-customer.md`:

```markdown
---
id: T3
title: List a customer's orders
kind: slice-local
scope.sliced: src/Orders.Api/Features/*Customer*/**, tests/Orders.SliceTests/**
scope.layered: src/Orders.Application/Orders/Queries/*Customer*/**, src/Orders.Application/DependencyInjection.cs, src/Orders.Application/Orders/OrderDtos.cs, src/Orders.Api/Endpoints/**, tests/Orders.IntegrationTests/**
---
Add a way to list one customer's orders.

`GET /customers/{customerId}/orders` returns `{ "orders": [ ... ] }` with the same summary shape as `GET /orders`, newest first, containing only that customer's orders. An unknown customer returns 200 with an empty list.

Add tests. Run them before you finish.
```

`experiment/tasks/T4-audit-trail.md`:

```markdown
---
id: T4
title: Audit trail for every command
kind: cross-cutting
scope.sliced: src/Orders.Api/Domain/**, src/Orders.Api/Platform/**, src/Orders.Api/Features/**, tests/Orders.SliceTests/**
scope.layered: src/Orders.Domain/**, src/Orders.Application/**, src/Orders.Infrastructure/**, src/Orders.Api/**, tests/Orders.IntegrationTests/**
---
Record an audit trail for every operation that changes an order — creating and cancelling today, and any command added later: who (the value of an `X-User` request header, or "anonymous" when absent), what (the operation name), when, and the order id. An entry must be persisted in the same transaction as the change it records.

Expose `GET /orders/{id}/audit` returning `{ "entries": [ { "actor", "action", "at" } ] }`, oldest first; 404 for an unknown order.

Add tests showing that creating and then cancelling an order produces two entries with the right actor and action, and that an unknown order returns 404. Run the tests before you finish.
```

`experiment/tasks/T5-order-notes.md`:

```markdown
---
id: T5
title: Optional notes on an order
kind: persistence
scope.sliced: src/Orders.Api/Domain/Order.cs, src/Orders.Api/Platform/Persistence/**, src/Orders.Api/Features/CreateOrder/**, src/Orders.Api/Features/GetOrder/**, tests/Orders.SliceTests/**
scope.layered: src/Orders.Domain/Entities/Order.cs, src/Orders.Infrastructure/Persistence/**, src/Orders.Application/Orders/Commands/CreateOrder/**, src/Orders.Application/Orders/Queries/GetOrder/**, src/Orders.Application/Orders/OrderDtos.cs, tests/Orders.IntegrationTests/**
---
Orders get an optional free-text `notes` field of at most 500 characters.

It can be set when creating an order (`"notes"` in the `POST /orders` body, optional) and is returned by `GET /orders/{id}` as `"notes"` (null when not set). A value longer than 500 characters is a validation error (400). Persist it in the database with a new migration.

Add tests for creating with notes, creating without notes, the length limit, and reading notes back. Run the tests before you finish.
```

- [ ] **Step 2: Commit**

```bash
git add prototypes/ai-development/vsa-agent-guardrails/experiment/tasks
git commit -m "vsa-agent-guardrails(experiment): five task prompts"
```

---

### Task 16: Metrics library and its test (`Parse-Events.ps1`)

**Files:**
- Create: `P/experiment/fixtures/sample-events.jsonl`, `P/experiment/fixtures/sample-task.md`, `P/experiment/Test-ParseEvents.ps1`, `P/experiment/Parse-Events.ps1`

The library holds every pure function the runner needs: `ConvertFrom-AgentEvents` (stream-json → metrics), `Get-TaskSpec`, `ConvertTo-GlobRegex`, `Test-PathInScope`, `Read-TrxSummary`, `Read-JscpdSummary`. The fixture mirrors the event shapes observed on Claude Code 2.1.246 (spec §5.3).

- [ ] **Step 1: Fixtures**

`experiment/fixtures/sample-events.jsonl` (seven lines, one JSON object each):

```json
{"type":"system","subtype":"init","cwd":"C:\\run","session_id":"s1","tools":["Read","Bash"],"model":"claude-fable-5","permissionMode":"dontAsk"}
{"type":"assistant","message":{"role":"assistant","content":[{"type":"text","text":"I'll read the file."},{"type":"tool_use","id":"toolu_1","name":"Read","input":{"file_path":"C:\\run\\src\\A.cs"}}]},"session_id":"s1"}
{"type":"user","message":{"role":"user","content":[{"type":"tool_result","tool_use_id":"toolu_1","content":"1\tclass A {}"}]},"session_id":"s1"}
{"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","id":"toolu_2","name":"Bash","input":{"command":"ls -la src","description":"List"}}]},"session_id":"s1"}
{"type":"user","message":{"role":"user","content":[{"type":"tool_result","tool_use_id":"toolu_2","content":"A.cs","is_error":false}]},"session_id":"s1"}
{"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","id":"toolu_3","name":"Read","input":{"file_path":"c:\\run\\src\\a.cs"}},{"type":"tool_use","id":"toolu_4","name":"Grep","input":{"pattern":"class","path":"src"}},{"type":"tool_use","id":"toolu_5","name":"Edit","input":{"file_path":"C:\\run\\src\\A.cs","old_string":"class A {}","new_string":"class A { }"}}]},"session_id":"s1"}
{"type":"result","subtype":"success","is_error":false,"duration_ms":19662,"duration_api_ms":8241,"num_turns":5,"result":"done","session_id":"s1","total_cost_usd":0.17785,"usage":{"input_tokens":10,"cache_creation_input_tokens":8569,"cache_read_input_tokens":135344,"output_tokens":939},"permission_denials":[{"tool_name":"Bash","tool_input":{"command":"cat x"}}],"modelUsage":{"claude-fable-5":{"inputTokens":10}}}
```

`experiment/fixtures/sample-task.md`:

```markdown
---
id: T9
title: Sample task
kind: slice-local
scope.sliced: src/Orders.Api/Features/Ship*/**, tests/Orders.SliceTests/**
scope.layered: src/Orders.Application/Orders/Commands/Ship*/**
---
Do the thing.
Then do the other thing.
```

- [ ] **Step 2: Write the test script first**

`experiment/Test-ParseEvents.ps1`:

```powershell
#requires -Version 7
# Plain assertions, no Pester dependency. Run: pwsh experiment/Test-ParseEvents.ps1
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/Parse-Events.ps1"

$failures = 0
function Assert-Equal($expected, $actual, $name) {
    if ("$expected" -ne "$actual") { Write-Host "FAIL $name : expected '$expected', got '$actual'"; $script:failures++ }
    else { Write-Host "ok   $name" }
}

$m = ConvertFrom-AgentEvents -Path "$PSScriptRoot/fixtures/sample-events.jsonl"
Assert-Equal 2 $m.read_calls 'read_calls'
Assert-Equal 1 $m.files_read_distinct 'files_read_distinct (case-insensitive)'
Assert-Equal 1 $m.grep_calls 'grep_calls'
Assert-Equal 0 $m.glob_calls 'glob_calls'
Assert-Equal 1 $m.edit_calls 'edit_calls'
Assert-Equal 0 $m.write_calls 'write_calls'
Assert-Equal 1 $m.bash_calls 'bash_calls'
Assert-Equal 1 $m.bash_search_calls 'bash_search_calls'
Assert-Equal 0.17785 $m.cost_usd 'cost_usd'
Assert-Equal 5 $m.num_turns 'num_turns'
Assert-Equal 19662 $m.duration_ms 'duration_ms'
Assert-Equal 8241 $m.duration_api_ms 'duration_api_ms'
Assert-Equal 10 $m.input_tokens 'input_tokens'
Assert-Equal 939 $m.output_tokens 'output_tokens'
Assert-Equal 135344 $m.cache_read_tokens 'cache_read_tokens'
Assert-Equal 8569 $m.cache_create_tokens 'cache_create_tokens'
Assert-Equal 'success' $m.ended 'ended'
Assert-Equal $false $m.is_error 'is_error'
Assert-Equal 1 $m.permission_denials 'permission_denials'

$spec = Get-TaskSpec -Path "$PSScriptRoot/fixtures/sample-task.md"
Assert-Equal 'T9' $spec.id 'task id'
Assert-Equal 'Sample task' $spec.title 'task title'
Assert-Equal 2 $spec.scope.sliced.Count 'scope.sliced count'
Assert-Equal 1 $spec.scope.layered.Count 'scope.layered count'
Assert-Equal "Do the thing.`nThen do the other thing." $spec.prompt 'prompt body'

Assert-Equal '^src/Orders\.Api/Features/Ship[^/]*/.*$' (ConvertTo-GlobRegex 'src/Orders.Api/Features/Ship*/**') 'glob regex'
Assert-Equal $true (Test-PathInScope -Path 'src/Orders.Api/Features/ShipOrder/ShipOrderHandler.cs' -Globs $spec.scope.sliced) 'in scope'
Assert-Equal $true (Test-PathInScope -Path 'tests\Orders.SliceTests\ShipOrderTests.cs' -Globs $spec.scope.sliced) 'in scope, backslashes'
Assert-Equal $false (Test-PathInScope -Path 'src/Orders.Api/Domain/Order.cs' -Globs $spec.scope.sliced) 'out of scope'

$trx = Join-Path ([IO.Path]::GetTempPath()) 'parse-events-sample.trx'
@'
<?xml version="1.0" encoding="utf-8"?>
<TestRun xmlns="http://microsoft.com/schemas/VisualStudio/TeamTest/2010">
  <ResultSummary outcome="Failed"><Counters total="13" executed="13" passed="12" failed="1" /></ResultSummary>
</TestRun>
'@ | Set-Content -Path $trx -Encoding utf8
$t = Read-TrxSummary -Path $trx
Assert-Equal 13 $t.total 'trx total'
Assert-Equal 12 $t.passed 'trx passed'
Assert-Equal 1 $t.failed 'trx failed'
Remove-Item $trx

$jscpd = Join-Path ([IO.Path]::GetTempPath()) 'parse-events-sample-jscpd.json'
'{"statistics":{"total":{"lines":100,"sources":5,"clones":2,"duplicatedLines":12,"percentage":12.0}}}' | Set-Content -Path $jscpd -Encoding utf8
$j = Read-JscpdSummary -Path $jscpd
Assert-Equal 2 $j.clones 'jscpd clones'
Assert-Equal 12 $j.percentage 'jscpd percentage'
Remove-Item $jscpd

if ($failures -gt 0) { Write-Host "$failures assertion(s) failed"; exit 1 }
Write-Host 'Test-ParseEvents: all assertions passed'
```

- [ ] **Step 3: Run it to see it fail**

Run: `pwsh prototypes/ai-development/vsa-agent-guardrails/experiment/Test-ParseEvents.ps1`
Expected: an error that `Parse-Events.ps1` cannot be found (dot-source fails), exit code 1.

- [ ] **Step 4: Implement the library**

`experiment/Parse-Events.ps1`:

```powershell
#requires -Version 7
# Pure functions used by run.ps1. Dot-source this file. Tested by Test-ParseEvents.ps1.

function Get-Prop($object, [string]$name) {
    # Property access that returns $null instead of throwing when the property is absent.
    if ($null -eq $object) { return $null }
    $p = $object.PSObject.Properties[$name]
    if ($null -eq $p) { return $null }
    return $p.Value
}

function ConvertFrom-AgentEvents {
    # Reads a `claude -p --output-format stream-json --verbose` transcript and returns one metrics object.
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path)

    $m = [ordered]@{
        read_calls = 0; grep_calls = 0; glob_calls = 0; edit_calls = 0; write_calls = 0
        bash_calls = 0; bash_search_calls = 0; files_read_distinct = 0
        cost_usd = $null; num_turns = $null; duration_ms = $null; duration_api_ms = $null
        input_tokens = $null; output_tokens = $null; cache_read_tokens = $null; cache_create_tokens = $null
        ended = $null; is_error = $null; permission_denials = 0
    }
    $files = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

    foreach ($line in [System.IO.File]::ReadLines($Path)) {
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        try { $e = $line | ConvertFrom-Json -Depth 100 } catch { continue }
        switch (Get-Prop $e 'type') {
            'assistant' {
                foreach ($block in @(Get-Prop (Get-Prop $e 'message') 'content')) {
                    if ((Get-Prop $block 'type') -ne 'tool_use') { continue }
                    $input = Get-Prop $block 'input'
                    switch (Get-Prop $block 'name') {
                        'Read'  { $m.read_calls++; $f = Get-Prop $input 'file_path'; if ($f) { [void]$files.Add([string]$f) } }
                        'Grep'  { $m.grep_calls++ }
                        'Glob'  { $m.glob_calls++ }
                        'Edit'  { $m.edit_calls++ }
                        'Write' { $m.write_calls++ }
                        'Bash'  {
                            $m.bash_calls++
                            if ([string](Get-Prop $input 'command') -match '^\s*(ls|dir|find|grep|rg|git\s+grep)\b') { $m.bash_search_calls++ }
                        }
                    }
                }
            }
            'result' {
                $m.cost_usd = Get-Prop $e 'total_cost_usd'
                $m.num_turns = Get-Prop $e 'num_turns'
                $m.duration_ms = Get-Prop $e 'duration_ms'
                $m.duration_api_ms = Get-Prop $e 'duration_api_ms'
                $m.ended = Get-Prop $e 'subtype'
                $m.is_error = [bool](Get-Prop $e 'is_error')
                $usage = Get-Prop $e 'usage'
                $m.input_tokens = Get-Prop $usage 'input_tokens'
                $m.output_tokens = Get-Prop $usage 'output_tokens'
                $m.cache_read_tokens = Get-Prop $usage 'cache_read_input_tokens'
                $m.cache_create_tokens = Get-Prop $usage 'cache_creation_input_tokens'
                $m.permission_denials = @(Get-Prop $e 'permission_denials').Count
            }
        }
    }
    $m.files_read_distinct = $files.Count
    return [pscustomobject]$m
}

function Get-TaskSpec {
    # Parses a task file: `key: value` front matter between --- fences, then the prompt body.
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path)

    $lines = @(Get-Content -Path $Path -Encoding utf8)
    if ($lines.Count -lt 3 -or $lines[0].Trim() -ne '---') { throw "Task file $Path has no front matter" }
    $end = 1
    while ($end -lt $lines.Count -and $lines[$end].Trim() -ne '---') { $end++ }
    if ($end -ge $lines.Count) { throw "Task file $Path has an unterminated front matter block" }

    $meta = @{}
    foreach ($l in $lines[1..($end - 1)]) {
        if ($l -match '^([A-Za-z0-9_.]+):\s*(.*)$') { $meta[$Matches[1]] = $Matches[2].Trim() }
    }
    $body = if ($end + 1 -lt $lines.Count) { ($lines[($end + 1)..($lines.Count - 1)] -join "`n").Trim() } else { '' }

    function Split-Globs([string]$value) { @($value -split ',\s*' | Where-Object { $_ -ne '' }) }

    return [pscustomobject]@{
        id     = $meta['id']
        title  = $meta['title']
        kind   = $meta['kind']
        scope  = @{ sliced = Split-Globs $meta['scope.sliced']; layered = Split-Globs $meta['scope.layered'] }
        prompt = $body
        path   = $Path
    }
}

function ConvertTo-GlobRegex {
    # `*` = one path segment, `**` = any depth, `?` = one character. Paths are compared with forward slashes.
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Glob)

    $g = $Glob -replace '\\', '/'
    $sb = [System.Text.StringBuilder]::new('^')
    $i = 0
    while ($i -lt $g.Length) {
        $c = $g[$i]
        if ($c -eq '*') {
            if ($i + 1 -lt $g.Length -and $g[$i + 1] -eq '*') {
                if ($i + 2 -lt $g.Length -and $g[$i + 2] -eq '/') { [void]$sb.Append('(?:.*/)?'); $i += 3 }
                else { [void]$sb.Append('.*'); $i += 2 }
            }
            else { [void]$sb.Append('[^/]*'); $i++ }
        }
        elseif ($c -eq '?') { [void]$sb.Append('[^/]'); $i++ }
        else { [void]$sb.Append([regex]::Escape([string]$c)); $i++ }
    }
    [void]$sb.Append('$')
    return $sb.ToString()
}

function Test-PathInScope {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path, [Parameter(Mandatory)][AllowEmptyCollection()][string[]]$Globs)

    $p = $Path -replace '\\', '/'
    foreach ($glob in $Globs) {
        if ($p -match (ConvertTo-GlobRegex -Glob $glob)) { return $true }
    }
    return $false
}

function Read-TrxSummary {
    # Reads the Counters element of a VSTest .trx file.
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path)

    if (-not (Test-Path -Path $Path)) { return [pscustomobject]@{ total = $null; passed = $null; failed = $null } }
    [xml]$x = Get-Content -Path $Path -Raw
    $c = $x.TestRun.ResultSummary.Counters
    return [pscustomobject]@{ total = [int]$c.total; passed = [int]$c.passed; failed = [int]$c.failed }
}

function Read-JscpdSummary {
    # Reads statistics.total from jscpd's JSON reporter output.
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path)

    if (-not (Test-Path -Path $Path)) { return [pscustomobject]@{ clones = $null; percentage = $null } }
    $j = Get-Content -Path $Path -Raw | ConvertFrom-Json -Depth 20
    return [pscustomobject]@{ clones = [int]$j.statistics.total.clones; percentage = [double]$j.statistics.total.percentage }
}
```

- [ ] **Step 5: Run the test**

Run: `pwsh prototypes/ai-development/vsa-agent-guardrails/experiment/Test-ParseEvents.ps1`
Expected: every line starts with `ok`, last line `Test-ParseEvents: all assertions passed`, exit code 0.

- [ ] **Step 6: Commit**

```bash
git add prototypes/ai-development/vsa-agent-guardrails/experiment
git commit -m "vsa-agent-guardrails(experiment): metrics library with tests"
```

---

### Task 17: The runner (`run.ps1`)

**Files:**
- Create: `P/experiment/run.ps1`

- [ ] **Step 1: Write the runner**

`experiment/run.ps1`:

```powershell
#requires -Version 7
<#
.SYNOPSIS
  Runs Claude Code headlessly against the sliced and layered copies on the experiment tasks and records metrics.
.DESCRIPTION
  Per copy x task x repetition: copies the variant to %TEMP%\vsa-runs\<name>, makes it a git repo with one baseline commit,
  runs `claude -p` with the prompt on stdin (spec 5.2), then builds, tests, diffs, runs jscpd, and appends one CSV row.
.EXAMPLE
  pwsh experiment/run.ps1 -Copy sliced -Task T1 -Repetitions 1        # smoke run
  pwsh experiment/run.ps1                                              # full experiment: both copies, all tasks, 3 reps
#>
[CmdletBinding()]
param(
    [ValidateSet('sliced', 'layered', 'both')] [string]$Copy = 'both',
    [string[]]$Task = @('all'),
    [int]$Repetitions = 3,
    [double]$MaxBudgetUsd = 8,
    [string]$Model,
    [string]$ResultsDir,
    [switch]$KeepRuns
)

$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

. "$PSScriptRoot/Parse-Events.ps1"

$root = Split-Path -Path $PSScriptRoot -Parent
$claude = (Get-Command -Name claude -ErrorAction Stop).Source
$copies = if ($Copy -eq 'both') { @('sliced', 'layered') } else { @($Copy) }
$taskFiles = @(Get-ChildItem -Path "$PSScriptRoot/tasks" -Filter 'T*.md' | Sort-Object Name)
if ($Task -notcontains 'all') { $taskFiles = @($taskFiles | Where-Object { $Task -contains ($_.BaseName -split '-')[0] }) }
if ($taskFiles.Count -eq 0) { throw "No task files match -Task $($Task -join ',')" }
if (-not $ResultsDir) { $ResultsDir = Join-Path $PSScriptRoot "results/$(Get-Date -Format 'yyyyMMdd-HHmmss')" }
New-Item -ItemType Directory -Force -Path $ResultsDir | Out-Null
$csv = Join-Path $ResultsDir 'results.csv'
$runsRoot = Join-Path $env:TEMP 'vsa-runs'
$behaviourProject = @{ sliced = 'tests/Orders.SliceTests'; layered = 'tests/Orders.IntegrationTests' }
$archProject = 'tests/Orders.ArchitectureTests'
$git = @('-c', 'user.name=runner', '-c', 'user.email=runner@example.invalid')

function New-RunDirectory([string]$copyName, [string]$runName) {
    $src = Join-Path $root $copyName
    $dst = Join-Path $runsRoot $runName
    if (Test-Path $dst) { Remove-Item -Recurse -Force $dst }
    New-Item -ItemType Directory -Force -Path $dst | Out-Null
    & robocopy $src $dst /E /XD bin obj .jscpd-report .trx /XF *.db *.db-shm *.db-wal .gate.log /NFL /NDL /NJH /NJS /NP | Out-Null
    if ($LASTEXITCODE -ge 8) { throw "robocopy $src -> $dst failed with exit code $LASTEXITCODE" }
    Push-Location $dst
    try {
        & dotnet tool restore 2>&1 | Out-Null          # makes `dotnet ef` available in the fresh copy (local tool manifest)
        & git init -q
        & git @git add -A
        & git @git commit -q -m 'baseline'
        if ($LASTEXITCODE -ne 0) { throw "baseline commit failed in $dst" }
    }
    finally { Pop-Location }
    return $dst
}

function Invoke-DotnetTest([string]$dir, [string]$project, [string]$trxName) {
    Push-Location $dir
    try {
        $out = & dotnet test $project --nologo -v q --logger "trx;LogFileName=$trxName" --results-directory (Join-Path $dir '.trx') 2>&1
        return [pscustomobject]@{ ok = ($LASTEXITCODE -eq 0); output = (@($out) -join "`n"); trx = (Join-Path $dir ".trx/$trxName") }
    }
    finally { Pop-Location }
}

function Invoke-Jscpd([string]$dir) {
    Push-Location $dir
    try { & npx -y jscpd@4 --config .jscpd.json --silent 2>&1 | Out-Null }
    finally { Pop-Location }
    return Read-JscpdSummary -Path (Join-Path $dir '.jscpd-report/jscpd-report.json')
}

function Invoke-Agent([string]$dir, [string]$promptFile, [string]$eventsFile, [string]$stderrFile) {
    $cliArgs = @(
        '-p', '--output-format', 'stream-json', '--verbose', '--no-session-persistence',
        '--setting-sources', 'project', '--permission-mode', 'dontAsk',
        '--allowedTools', 'Read,Glob,Grep,Edit,Write,Bash(dotnet *),Bash(git *)',
        '--disallowedTools', 'Bash(cat *),Bash(head *),Bash(tail *),Bash(sed *),Bash(type *)',
        '--max-budget-usd', "$MaxBudgetUsd"
    )
    if ($Model) { $cliArgs += @('--model', $Model) }
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    Push-Location $dir
    try {
        Get-Content -Path $promptFile -Raw | & $claude @cliArgs 2> $stderrFile | Set-Content -Path $eventsFile -Encoding utf8
        $exit = $LASTEXITCODE
    }
    finally { Pop-Location }
    $sw.Stop()
    return [pscustomobject]@{ exit = $exit; wall_ms = $sw.ElapsedMilliseconds }
}

$runningTotal = 0.0
foreach ($copyName in $copies) {
    Write-Host "== baseline check: $copyName"
    $base = New-RunDirectory $copyName "$copyName-baseline"
    $archBase = Invoke-DotnetTest $base $archProject 'arch.trx'
    $behBase = Invoke-DotnetTest $base $behaviourProject[$copyName] 'behaviour.trx'
    if (-not ($archBase.ok -and $behBase.ok)) {
        throw "Baseline tests fail for $copyName; aborting.`n$($archBase.output)`n$($behBase.output)"
    }
    $dupBefore = Invoke-Jscpd $base
    if (-not $KeepRuns) { Remove-Item -Recurse -Force $base }

    foreach ($taskFile in $taskFiles) {
        $spec = Get-TaskSpec -Path $taskFile.FullName
        for ($rep = 1; $rep -le $Repetitions; $rep++) {
            $runName = "$copyName-$($spec.id)-$rep"
            Write-Host "== run $runName ($($spec.title))"
            $startedAt = Get-Date
            $dir = New-RunDirectory $copyName $runName
            $artefacts = Join-Path $ResultsDir $runName
            New-Item -ItemType Directory -Force -Path $artefacts | Out-Null
            $promptFile = Join-Path $artefacts 'prompt.md'
            Set-Content -Path $promptFile -Value $spec.prompt -Encoding utf8
            $events = Join-Path $artefacts 'events.jsonl'

            $agent = Invoke-Agent $dir $promptFile $events (Join-Path $artefacts 'stderr.txt')
            $m = ConvertFrom-AgentEvents -Path $events

            Push-Location $dir
            try {
                & dotnet build --nologo -v q 2>&1 | Set-Content -Path (Join-Path $artefacts 'build.txt')
                $buildOk = ($LASTEXITCODE -eq 0)
            }
            finally { Pop-Location }
            $arch = Invoke-DotnetTest $dir $archProject 'arch.trx'
            $beh = Invoke-DotnetTest $dir $behaviourProject[$copyName] 'behaviour.trx'
            Set-Content -Path (Join-Path $artefacts 'test-output.txt') -Value ($arch.output + "`n`n" + $beh.output)
            $archSum = Read-TrxSummary -Path $arch.trx
            $behSum = Read-TrxSummary -Path $beh.trx

            Push-Location $dir
            try {
                & git @git add -A
                $changed = @(& git diff --cached --name-only)
                $numstat = @(& git diff --cached --numstat)
                & git diff --cached | Set-Content -Path (Join-Path $artefacts 'diff.patch') -Encoding utf8
            }
            finally { Pop-Location }
            $added = 0; $deleted = 0
            foreach ($n in $numstat) {
                $parts = $n -split "`t"
                if ($parts[0] -match '^\d+$') { $added += [int]$parts[0]; $deleted += [int]$parts[1] }
            }
            $outOfScope = @($changed | Where-Object { -not (Test-PathInScope -Path $_ -Globs $spec.scope[$copyName]) })
            Set-Content -Path (Join-Path $artefacts 'out-of-scope.txt') -Value ($outOfScope -join "`n")

            $dupAfter = Invoke-Jscpd $dir
            Copy-Item -Path (Join-Path $dir '.jscpd-report/jscpd-report.json') -Destination (Join-Path $artefacts 'jscpd.json') -ErrorAction SilentlyContinue

            $gateBlocks = 0
            $gateLog = Join-Path $dir '.gate.log'
            if (Test-Path $gateLog) {
                $gateBlocks = @(Get-Content $gateLog | Where-Object { $_ -match 'exit=2' }).Count
                Copy-Item -Path $gateLog -Destination (Join-Path $artefacts 'gate.log')
            }

            $notes = @()
            if ($agent.exit -ne 0) { $notes += "claude exit $($agent.exit)" }
            if ($m.ended -ne 'success') { $notes += "ended=$($m.ended)" }
            if ($m.permission_denials -gt 0) { $notes += "$($m.permission_denials) permission denials" }

            $row = [pscustomobject][ordered]@{
                copy = $copyName; task = $spec.id; rep = $rep; model = ($Model ? $Model : 'default')
                started_at = $startedAt.ToString('s'); wall_ms = $agent.wall_ms
                cost_usd = $m.cost_usd; num_turns = $m.num_turns; duration_ms = $m.duration_ms; duration_api_ms = $m.duration_api_ms
                input_tokens = $m.input_tokens; output_tokens = $m.output_tokens
                cache_read_tokens = $m.cache_read_tokens; cache_create_tokens = $m.cache_create_tokens
                ended = $m.ended; is_error = $m.is_error; permission_denials = $m.permission_denials
                files_read_distinct = $m.files_read_distinct; read_calls = $m.read_calls; grep_calls = $m.grep_calls; glob_calls = $m.glob_calls
                edit_calls = $m.edit_calls; write_calls = $m.write_calls; bash_calls = $m.bash_calls; bash_search_calls = $m.bash_search_calls
                gate_blocks = $gateBlocks
                files_changed = $changed.Count; lines_added = $added; lines_deleted = $deleted; files_out_of_scope = $outOfScope.Count
                build_ok = $buildOk
                behaviour_tests_passed = $behSum.passed; behaviour_tests_failed = $behSum.failed
                arch_tests_passed = $archSum.passed; arch_tests_failed = $archSum.failed
                dup_blocks_before = $dupBefore.clones; dup_blocks_after = $dupAfter.clones; dup_lines_pct_after = $dupAfter.percentage
                notes = ($notes -join '; ')
            }
            $row | Export-Csv -Path $csv -Append -NoTypeInformation
            $runningTotal += [double]($m.cost_usd ?? 0)
            Write-Host ("   cost `${0:N2}  turns {1}  files_read {2}  changed {3}  out_of_scope {4}  build {5}  behaviour {6}/{7}  arch {8}/{9}  total so far `${10:N2}" -f
                $m.cost_usd, $m.num_turns, $m.files_read_distinct, $changed.Count, $outOfScope.Count, $buildOk,
                $behSum.passed, $behSum.total, $archSum.passed, $archSum.total, $runningTotal)

            if (-not $KeepRuns) { Remove-Item -Recurse -Force $dir }
        }
    }
}
Write-Host "Results: $csv"
```

- [ ] **Step 2: Dry-check the script parses**

Run: `pwsh -NoProfile -Command "[scriptblock]::Create((Get-Content -Raw prototypes/ai-development/vsa-agent-guardrails/experiment/run.ps1)) | Out-Null; 'parses'"`
Expected: `parses`.

- [ ] **Step 3: Check the baseline path without spending anything**

Run: `pwsh prototypes/ai-development/vsa-agent-guardrails/experiment/run.ps1 -Copy sliced -Task T0 -Repetitions 1`
Expected: `No task files match -Task T0` — the argument validation runs before any copy is made. Then confirm the baseline copy works by running with `-KeepRuns` and a deliberately unavailable `claude`: `$env:PATH` unchanged is fine — instead run only the copy helper interactively:

```powershell
pwsh -NoProfile -Command ". prototypes/ai-development/vsa-agent-guardrails/experiment/Parse-Events.ps1; robocopy prototypes/ai-development/vsa-agent-guardrails/sliced $env:TEMP/vsa-runs/probe /E /XD bin obj /XF *.db /NFL /NDL /NJH /NJS /NP | Out-Null; Get-ChildItem $env:TEMP/vsa-runs/probe -Name"
```

Expected: `CLAUDE.md`, `Directory.Build.props`, `Orders.sln`, `src`, `tests`, `.claude`, `.config`, `.jscpd.json` listed and no `bin`/`obj`. Remove `$env:TEMP/vsa-runs/probe`.

- [ ] **Step 4: Commit**

```bash
git add prototypes/ai-development/vsa-agent-guardrails/experiment/run.ps1
git commit -m "vsa-agent-guardrails(experiment): runner"
```

---

### Task 18: Smoke run, example results, report template

**Files:**
- Create: `P/experiment/results/example-results.csv`, `P/experiment/REPORT.md`

Prerequisites: `claude` logged in on this machine (`claude --version` prints `2.1.x`), Node 22 on PATH (`npx --version`). The smoke run makes one paid agent run (expected `$2–8`, capped at `$8`).

- [ ] **Step 1: Run the smoke test**

Run: `pwsh prototypes/ai-development/vsa-agent-guardrails/experiment/run.ps1 -Copy sliced -Task T1 -Repetitions 1`
Expected: `== baseline check: sliced`, `== run sliced-T1-1 (Ship an order)`, then a summary line such as `cost $3.12  turns 24  files_read 9  changed 6  out_of_scope 0  build True  behaviour 16/16  arch 5/5  total so far $3.12`, then `Results: ...results/<timestamp>/results.csv`. Open the CSV: one data row with every column filled (`notes` may be empty). Look at `events.jsonl`, `diff.patch` and `gate.log` in the run's artefact folder; the diff should show a new `Features/ShipOrder/` folder and a new test class. If `behaviour_tests_failed` is not 0 or `files_out_of_scope` is not 0, that is a finding, not a harness error — keep it.

If the run ends with `ended=error_max_budget_usd` or `claude exit 1` in `notes`, raise `-MaxBudgetUsd` and repeat once; if it ends with permission denials, inspect `stderr.txt` and `events.jsonl` for the denied tool.

- [ ] **Step 2: Keep the row as the committed example**

```bash
cp prototypes/ai-development/vsa-agent-guardrails/experiment/results/<timestamp>/results.csv prototypes/ai-development/vsa-agent-guardrails/experiment/results/example-results.csv
```

- [ ] **Step 3: Report template**

`experiment/REPORT.md`:

```markdown
# vsa-agent-guardrails — experiment report

**Run:** (results folder name) · **Model:** (from the `model` column) · **Repetitions:** (n) · **Claude Code:** (version) · **Date:** (date)

## Setup

Two copies of the same orders API (`sliced/`, `layered/`), identical behaviour tests, five tasks (`experiment/tasks/`), each run in a fresh
temporary copy with `claude -p` (project settings only, `dontAsk`, tool allow-list; see the spec, section 5.2). Numbers below are medians
over the repetitions, with the range in parentheses.

## Results per task

| Task | Copy | files read | input tokens | cost USD | turns | files changed | out of scope | green runs |
|---|---|---|---|---|---|---|---|---|
| T1 ship order | sliced | | | | | | | /n |
| T1 ship order | layered | | | | | | | /n |
| T2 no cancel after ship | sliced | | | | | | | /n |
| T2 no cancel after ship | layered | | | | | | | /n |
| T3 orders by customer | sliced | | | | | | | /n |
| T3 orders by customer | layered | | | | | | | /n |
| T4 audit trail | sliced | | | | | | | /n |
| T4 audit trail | layered | | | | | | | /n |
| T5 order notes | sliced | | | | | | | /n |
| T5 order notes | layered | | | | | | | /n |

"Green" = `build_ok` and no failed behaviour or architecture test. Duplication (`dup_blocks_after − dup_blocks_before`) and gate blocks
(`gate_blocks`) are reported per task below the table when non-zero.

## Hypotheses

- **H1** (slice-local tasks T1–T3: fewer files read, fewer input tokens, fewer out-of-scope edits in `sliced/`): supported / not supported / mixed — because …
- **H2** (T4 and T5: no advantage for `sliced/`): …
- **H3** (behaviour-test pass rate does not differ materially): …

## Caveats

Three repetitions; one model; one prompt per task; the layered copy is a well-structured layered app, not a big ball of mud;
the harness denies `cat`/`head`/`tail`/`sed` so file reads are countable, which changes agent behaviour slightly but equally for both copies.

## Raw data

`results/<folder>/results.csv`, with `events.jsonl`, `diff.patch`, `test-output.txt`, `gate.log` and `jscpd.json` per run.
```

- [ ] **Step 4: Commit**

```bash
git add prototypes/ai-development/vsa-agent-guardrails/experiment/results/example-results.csv prototypes/ai-development/vsa-agent-guardrails/experiment/REPORT.md
git commit -m "vsa-agent-guardrails(experiment): smoke-run example results and report template"
```

---

### Task 19: Parity check between the two copies

**Files:**
- Create: `P/experiment/Test-Parity.ps1`

Runs both APIs, sends the same request sequence to each, and compares status codes and bodies with ids, timestamps and trace ids masked; also compares the test file names and test method names of the two test projects (spec §6).

- [ ] **Step 1: Write the script**

`experiment/Test-Parity.ps1`:

```powershell
#requires -Version 7
# Run: pwsh experiment/Test-Parity.ps1   (exit code 0 = the copies behave identically)
param([int]$SlicedPort = 5101, [int]$LayeredPort = 5102)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Path $PSScriptRoot -Parent

function Start-Api([string]$copyName, [int]$port) {
    $db = Join-Path $env:TEMP "parity-$copyName-$([guid]::NewGuid().ToString('N')).db"
    $psi = [System.Diagnostics.ProcessStartInfo]::new()
    $psi.FileName = 'dotnet'
    $psi.Arguments = "run --project src/Orders.Api --no-launch-profile --urls http://localhost:$port"
    $psi.WorkingDirectory = Join-Path $root $copyName
    $psi.Environment['ConnectionStrings__Orders'] = "Data Source=$db"
    $psi.Environment['ASPNETCORE_ENVIRONMENT'] = 'Development'
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $proc = [System.Diagnostics.Process]::Start($psi)
    $deadline = (Get-Date).AddSeconds(120)
    while ((Get-Date) -lt $deadline) {
        Start-Sleep -Milliseconds 500
        if ($proc.HasExited) { throw "$copyName exited early:`n$($proc.StandardError.ReadToEnd())" }
        try {
            $r = Invoke-WebRequest -Uri "http://localhost:$port/orders" -SkipHttpErrorCheck -TimeoutSec 2
            if ($r.StatusCode -eq 200) { return [pscustomobject]@{ proc = $proc; db = $db } }
        }
        catch { }
    }
    throw "$copyName did not start on port $port within 120 s"
}

function Invoke-Scenario([int]$port) {
    $base = "http://localhost:$port"
    $steps = [System.Collections.Generic.List[object]]::new()
    $record = { param($name, $r) $steps.Add([pscustomobject]@{ step = $name; status = $r.StatusCode; body = $r.Content }) }

    $created = Invoke-WebRequest -Uri "$base/orders" -Method Post -ContentType 'application/json' -SkipHttpErrorCheck `
        -Body '{"customerId":"c1","lines":[{"sku":"S1","quantity":2,"unitPrice":9.5}]}'
    & $record 'create' $created
    $id = ($created.Content | ConvertFrom-Json).id
    & $record 'create-invalid' (Invoke-WebRequest -Uri "$base/orders" -Method Post -ContentType 'application/json' -SkipHttpErrorCheck -Body '{"customerId":"c1","lines":[]}')
    & $record 'get' (Invoke-WebRequest -Uri "$base/orders/$id" -SkipHttpErrorCheck)
    & $record 'get-unknown' (Invoke-WebRequest -Uri "$base/orders/$([guid]::Empty)" -SkipHttpErrorCheck)
    & $record 'list' (Invoke-WebRequest -Uri "$base/orders" -SkipHttpErrorCheck)
    & $record 'list-bad-status' (Invoke-WebRequest -Uri "$base/orders?status=Lost" -SkipHttpErrorCheck)
    & $record 'cancel' (Invoke-WebRequest -Uri "$base/orders/$id/cancel" -Method Post -SkipHttpErrorCheck)
    & $record 'cancel-again' (Invoke-WebRequest -Uri "$base/orders/$id/cancel" -Method Post -SkipHttpErrorCheck)
    & $record 'list-cancelled' (Invoke-WebRequest -Uri "$base/orders?status=Cancelled" -SkipHttpErrorCheck)
    return $steps
}

function Normalize([string]$s) {
    $s = $s -replace '[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}', '<guid>'
    $s = $s -replace '\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d+)?(Z|[+-]\d{2}:\d{2})', '<time>'
    $s = $s -replace '"traceId":"[^"]*"', '"traceId":"<trace>"'
    return $s
}

function Get-TestMethods([string]$dir) {
    $result = @{}
    foreach ($f in Get-ChildItem -Path $dir -Filter '*Tests.cs') {
        $methods = @(Select-String -Path $f.FullName -Pattern 'public async Task (\w+)\(' -AllMatches |
            ForEach-Object { $_.Matches } | ForEach-Object { $_.Groups[1].Value } | Sort-Object)
        $result[$f.Name] = $methods
    }
    return $result
}

$failures = 0
$sliced = $null; $layered = $null
try {
    Write-Host 'Starting both APIs...'
    $sliced = Start-Api 'sliced' $SlicedPort
    $layered = Start-Api 'layered' $LayeredPort

    $a = Invoke-Scenario $SlicedPort
    $b = Invoke-Scenario $LayeredPort
    for ($i = 0; $i -lt $a.Count; $i++) {
        $sa = $a[$i]; $sb = $b[$i]
        $bodyA = Normalize $sa.body; $bodyB = Normalize $sb.body
        if ($sa.status -ne $sb.status -or $bodyA -ne $bodyB) {
            $failures++
            Write-Host "DIFF $($sa.step): sliced $($sa.status) $bodyA`n                 layered $($sb.status) $bodyB"
        }
        else { Write-Host "same $($sa.step) ($($sa.status))" }
    }

    $ta = Get-TestMethods (Join-Path $root 'sliced/tests/Orders.SliceTests')
    $tb = Get-TestMethods (Join-Path $root 'layered/tests/Orders.IntegrationTests')
    foreach ($file in (@($ta.Keys) + @($tb.Keys) | Sort-Object -Unique)) {
        $ma = @($ta[$file]) -join ','; $mb = @($tb[$file]) -join ','
        if ($ma -ne $mb) { $failures++; Write-Host "DIFF tests $file`n  sliced:  $ma`n  layered: $mb" }
        else { Write-Host "same tests $file ($(@($ta[$file]).Count) methods)" }
    }
}
finally {
    foreach ($api in @($sliced, $layered)) {
        if ($null -ne $api) {
            if (-not $api.proc.HasExited) { $api.proc.Kill($true) }
            Remove-Item -Path $api.db -ErrorAction SilentlyContinue
        }
    }
}
if ($failures -gt 0) { Write-Host "$failures difference(s)"; exit 1 }
Write-Host 'Test-Parity: the copies behave identically'
```

- [ ] **Step 2: Run it**

Run: `pwsh prototypes/ai-development/vsa-agent-guardrails/experiment/Test-Parity.ps1`
Expected: nine `same <step> (<status>)` lines (201, 400, 200, 404, 200, 400, 200, 409, 200), four `same tests <file>` lines, then `Test-Parity: the copies behave identically`, exit 0. A `DIFF` line means the copies diverged — fix the copy that deviates from the spec (§4.1), not the script.

- [ ] **Step 3: Commit**

```bash
git add prototypes/ai-development/vsa-agent-guardrails/experiment/Test-Parity.ps1
git commit -m "vsa-agent-guardrails(experiment): parity check"
```

---

### Task 20: README and final verification

**Files:**
- Create: `P/README.md`

- [ ] **Step 1: README**

`P/README.md`:

```markdown
# vsa-agent-guardrails

The minimal-pair experiment proposed in the guide
[Vertical Slice Architecture for AI Development](https://mortenbrudvik.github.io/dev-research/ai-development/vertical-slice-architecture/)
(section 10): the same small orders API built twice — `sliced/` as vertical slices with the guide's guardrails, `layered/` as
Domain / Application / Infrastructure / Api — with identical behaviour tests, and a harness that gives Claude Code the same five
tasks against each copy and records what it read, spent, changed and broke. Design: `docs/superpowers/specs/2026-08-26-vsa-agent-guardrails-design.md`
in the repository.

## What is in each copy

| | `sliced/` | `layered/` |
|---|---|---|
| Use cases | `src/Orders.Api/Features/{CreateOrder,CancelOrder,GetOrder,ListOrders}/` | `src/Orders.Application/Orders/{Commands,Queries}/…`, routes in `src/Orders.Api/Endpoints/OrdersEndpoints.cs` |
| Shared code | `Domain/`, `Platform/` | `Orders.Domain`, `Orders.Infrastructure` |
| Behaviour tests | `tests/Orders.SliceTests` | `tests/Orders.IntegrationTests` (same cases, file for file) |
| Architecture tests | slices independent; Domain and Platform never depend on Features | Domain depends on nothing; Application not on Infrastructure/Api; Api not on persistence |
| Agent guardrails | `CLAUDE.md`, `.claude/settings.json` + `.claude/hooks/gate.sh`, `.jscpd.json` | same, layer flavour |

## Build and test a copy

Requires the .NET SDK 10.0.100 or later. SQLite is embedded; no database server or Docker.

    cd sliced          # or layered
    dotnet build --nologo
    dotnet test --nologo                       # behaviour tests + architecture tests (+ negative controls)
    dotnet run --project src/Orders.Api        # http://localhost:5000, creates orders.db in the project folder

## Run the experiment

Requires PowerShell 7, Node 22 (`npx jscpd@4`), Git, Git Bash (the hooks are `sh` scripts), and Claude Code logged in.

    pwsh experiment/Test-ParseEvents.ps1                                  # the metrics library's tests, free
    pwsh experiment/Test-Parity.ps1                                       # both copies answer identically, free
    pwsh experiment/run.ps1 -Copy sliced -Task T1 -Repetitions 1          # smoke run, one paid agent run (~$2–8)
    pwsh experiment/run.ps1                                               # both copies, five tasks, 3 repetitions (~$60–150)

Each run copies the variant to `%TEMP%\vsa-runs\`, gives Claude Code the task with project settings only (no user-level plugins or
hooks), an explicit tool allow-list and a budget cap, then builds, tests, diffs, runs jscpd, and appends a row to
`experiment/results/<timestamp>/results.csv`. `experiment/results/example-results.csv` shows the columns; `experiment/REPORT.md`
is the template for writing the numbers up. Nothing in the repository is modified by a run.

## Tasks

`experiment/tasks/`: T1 ship an order, T2 shipped orders cannot be cancelled, T3 list a customer's orders (slice-local);
T4 audit trail for every command (cross-cutting); T5 optional notes with a migration (persistence). Each file's front matter lists
the paths a correct solution is expected to touch in each copy; edits outside that list count as `files_out_of_scope`.
```

- [ ] **Step 2: Final checks**

Run, from the repository root:

```bash
(cd prototypes/ai-development/vsa-agent-guardrails/sliced && dotnet test --nologo) 2>&1 | tail -3
(cd prototypes/ai-development/vsa-agent-guardrails/layered && dotnet test --nologo) 2>&1 | tail -3
pwsh prototypes/ai-development/vsa-agent-guardrails/experiment/Test-ParseEvents.ps1 | tail -1
.venv/Scripts/python -m mkdocs build --strict 2>&1 | grep -c "WARNING -"
git status --short
```

Expected: both `dotnet test` runs report `Passed!` for every project (13 behaviour + 5 architecture tests in each copy); `Test-ParseEvents: all assertions passed`; `0` warnings from the strict site build (the prototype is outside `docs/`); `git status` shows only the untracked/modified files of this task.

- [ ] **Step 3: Commit**

```bash
git add prototypes/ai-development/vsa-agent-guardrails/README.md
git commit -m "vsa-agent-guardrails: README"
```

---

## Not in this plan (spec §7)

After the first full experiment: fill in `experiment/REPORT.md`; add the prototype to the Prototypes list in
`docs/ai-development/index.md`; add the headline numbers and a link to sections 8.1 and 10 of the guide. Those are documentation
changes that follow from results and are done as a separate change.
