using System.Text.RegularExpressions;

namespace Orders.ArchitectureTests;

/// <summary>
/// Program.cs is a composition root: it registers services and calls the Map*Endpoints() extensions; it defines no
/// routes. ArchUnitNET cannot enforce that — top-level statements compile into a &lt;Main&gt;$ method and closure
/// types that it drops from the architecture — so this test reads the source file instead. The pattern is checked
/// against every route verb and against a legitimate Map*Endpoints() call first, so a rotted pattern cannot pass
/// vacuously in either direction.
/// </summary>
public class CompositionRoot
{
    // app.Map(, app.MapGet( ... app.MapFallback(: the "(" right after the verb is what excludes app.MapEndpoints()
    // and app.MapOrdersEndpoints().
    private static readonly Regex RouteRegistration =
        new(@"\.Map(Get|Post|Put|Patch|Delete|Methods|Group|Fallback)?\s*\(", RegexOptions.Compiled);

    [Fact]
    public void The_route_pattern_matches_every_route_verb_and_no_endpoint_extension()
    {
        var routes = new[]
        {
            "app.Map(", "app.MapGet(", "app.MapPost(", "app.MapPut(", "app.MapPatch(",
            "app.MapDelete(", "app.MapMethods(", "app.MapGroup(", "app.MapFallback(",
        };

        Assert.All(routes, r => Assert.Matches(RouteRegistration, r));
        Assert.DoesNotMatch(RouteRegistration, "app.MapEndpoints();");
        Assert.DoesNotMatch(RouteRegistration, "app.MapOrdersEndpoints();");
    }

    [Fact]
    public void Program_cs_registers_no_routes()
    {
        var source = File.ReadAllText(ProgramCsPath());

        var routes = RouteRegistration.Matches(source).Select(m => m.Value).ToList();

        if (routes.Count > 0)
        {
            Assert.Fail($"Program.cs is a composition root: move {string.Join(", ", routes)} into an endpoint class under src/Orders.Api (see CLAUDE.md).");
        }
    }

    private static string ProgramCsPath()
    {
        var dir = new DirectoryInfo(AppContext.BaseDirectory);
        while (dir is not null && !File.Exists(Path.Combine(dir.FullName, "Orders.sln")))
        {
            dir = dir.Parent;
        }

        if (dir is null)
        {
            throw new InvalidOperationException($"No Orders.sln above {AppContext.BaseDirectory}");
        }

        return Path.Combine(dir.FullName, "src", "Orders.Api", "Program.cs");
    }
}
