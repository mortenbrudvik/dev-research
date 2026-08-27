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
- A slice is one flat namespace, `Orders.Api.Features.<UseCase>`: keep all of its files in the folder root. A
  sub-folder such as `Validators/` becomes a separate namespace, which the architecture test counts as another slice.
- Slices never reference other slices, and depend only on `Domain/`, `Platform/` and framework packages. Code
  that two slices need lives in `src/Orders.Api/Domain/` (entities, value objects, policies) or
  `src/Orders.Api/Platform/` (persistence, endpoint discovery, HTTP concerns). There is no `Common/`, `Shared/`
  or `Helpers/` folder and no type directly under `Features/`; the architecture test fails on any of them.
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
