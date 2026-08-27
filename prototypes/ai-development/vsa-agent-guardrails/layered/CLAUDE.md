# Orders API (layered) — conventions for agents

## Commands

- Build: `dotnet build --nologo` — warnings are errors (`Directory.Build.props`): a nullable or unused-using
  warning fails the build.
- Behaviour tests: `dotnet test tests/Orders.IntegrationTests --nologo` (add `--filter FullyQualifiedName~<UseCase>` for one)
- Architecture tests: `dotnet test tests/Orders.ArchitectureTests --nologo` — fails on any dependency that points outward
- Migrations: `dotnet tool restore` once, then
  `dotnet ef migrations add <Name> --project src/Orders.Infrastructure --startup-project src/Orders.Api --output-dir Persistence/Migrations`

## Layout rules

- `src/Orders.Domain`: entities, enums, policies, exceptions. Depends on nothing else.
- `src/Orders.Application`: one folder per command or query under `Orders/Commands/<Name>/` or `Orders/Queries/<Name>/`
  (handler class; command record and validator when the command carries a body), DTOs in `Orders/OrderDtos.cs`, the
  `IOrdersDbContext` abstraction in `Common/Interfaces/`. Register every handler in `DependencyInjection.cs`.
  `Orders/Commands/CreateOrder/` is the reference for a command with a body, `Orders/Commands/CancelOrder/` for one
  whose only input is the route id, `Orders/Queries/GetOrder/` for a query: copy the shape, not the logic. Depends on
  Domain only. An endpoint that binds a request body adds `.AddEndpointFilter<ValidationFilter<TCommand>>()`, which
  requires a public `<Command>Validator` in the command's folder; the filter throws if none is registered.
- `src/Orders.Infrastructure`: `OrdersDbContext`, migrations, `DependencyInjection.cs`. Depends on Application and Domain.
- `src/Orders.Api`: the `/orders` routes live in `Endpoints/OrdersEndpoints.cs`; a route outside `/orders` gets its
  own `Endpoints/<Name>Endpoints.cs` with a `Map<Name>Endpoints` extension called from `Program.cs`. HTTP concerns
  in `Common/`. Never reference `Orders.Infrastructure.Persistence` from the API; the composition root in
  `Program.cs` is the only exception.
- Every command or query ships with a test class in `tests/Orders.IntegrationTests/<UseCase>Tests.cs` that sends the
  request through the endpoint and asserts the response and the persisted state. Use `ApiFixture`; do not mock the database.
- Domain rule violations surface as HTTP 409 (`DomainException` or an explicit conflict result); validation failures as 400.

## Scope

- Keep a change to the layers it needs and its test. If the task needs edits under `Orders.Domain` or
  `Orders.Infrastructure`, say so in your final message and keep those edits minimal.
- Do not edit files under `Persistence/Migrations/`; generate a new migration with `dotnet ef` instead.
- Before finishing, run the architecture tests and the integration tests. Hooks also run them after every edit of a
  `.cs`/`.csproj`/`.props` file (architecture tests) and when you stop (both); a failure blocks with the test output.
  They append to `.gate.log` in the solution root — it is gitignored; leave it alone.
