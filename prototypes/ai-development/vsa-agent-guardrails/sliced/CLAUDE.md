# Orders API (sliced) — conventions for agents

## Commands

- Build: `dotnet build --nologo` — warnings are errors (`Directory.Build.props`): a nullable or unused-using
  warning fails the build.
- Behaviour tests: `dotnet test tests/Orders.SliceTests --nologo` (add `--filter FullyQualifiedName~<UseCase>` for one slice)
- Architecture tests: `dotnet test tests/Orders.ArchitectureTests --nologo` — fails on any dependency between slices
- Migrations: `dotnet tool restore` once, then
  `dotnet ef migrations add <Name> --project src/Orders.Api --output-dir Platform/Persistence/Migrations`

## Layout rules

- One use case = one folder under `src/Orders.Api/Features/<UseCase>/`, holding the handler, the endpoint, the
  response, and — when the command carries a body — the request and its validator. `Features/CreateOrder/` is
  the reference for a command with a body, `Features/CancelOrder/` for a command whose only input is the route
  id, `Features/GetOrder/` for a query. Copy the shape, not the logic.
- A slice is one flat namespace, `Orders.Api.Features.<UseCase>`: keep all of its files in the folder root. A
  sub-folder such as `Validators/` becomes a separate namespace, which the architecture test counts as another slice.
- Slices never reference other slices, and depend only on `Domain/`, `Platform/` and framework packages. Code
  that two slices need lives in `src/Orders.Api/Domain/` (entities, value objects, policies) or
  `src/Orders.Api/Platform/` (persistence, endpoint discovery, HTTP concerns). Do not create a `Common/`,
  `Shared/` or `Helpers/` folder or a type directly under `Features/`: the architecture test fails as soon as a
  slice uses one.
- Handlers are discovered by name (`*Handler` under `Features`) and endpoints by `IEndpoint`; nothing is
  registered in `Program.cs` per slice. An endpoint class needs a public parameterless constructor — take
  dependencies as parameters of the route delegate, not of the class.
- `Program.cs` is the composition root: service registration and `app.MapEndpoints()` only. Do not add routes
  there — an architecture test reads the file and fails on any `Map`/`MapGet`/`MapPost`/... call in it.
- An endpoint that binds a request body adds `.AddEndpointFilter<ValidationFilter<TRequest>>()`, which requires
  a public `<Request>Validator` (`AbstractValidator<TRequest>`) in the slice; the filter throws if none is registered.
- Every slice ships with a test class in `tests/Orders.SliceTests/<UseCase>Tests.cs` that sends the request
  through the endpoint and asserts the response and the persisted state. Use `ApiFixture` and
  `await response.ShouldBe(HttpStatusCode.X)`; do not mock the database.
- Domain rule violations surface as HTTP 409 (`DomainException` or an explicit conflict result); validation
  failures as 400.

## Scope

- Keep a change inside one slice plus its test. If the task needs edits under `Domain/` or `Platform/`, say so
  in your final message and keep those edits minimal.
- Do not edit files under `Platform/Persistence/Migrations/`; generate a new migration with `dotnet ef` instead.
- Before finishing, run the architecture tests and the slice tests. Hooks also run them after every edit of a
  `.cs`/`.csproj`/`.props` file (architecture tests) and when you stop (both); a failure blocks with the test
  output. They append to `.gate.log` in the project root — it is gitignored; leave it alone.
