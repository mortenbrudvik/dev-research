using System.Text.RegularExpressions;

namespace Orders.ArchitectureTests;

/// <summary>
/// Program.cs is a composition root: it registers services and calls the Map*Endpoints() extensions; it defines no
/// routes. ArchUnitNET cannot enforce that — top-level statements compile into a <Main>$ method and closure types
/// that it drops from the architecture — so this test reads the source file instead. The pattern is checked against
/// a known route first so that a rotted pattern cannot pass vacuously.
/// </summary>
public class CompositionRoot
{
    private static readonly Regex RouteRegistration =
        new(@"\.Map(Get|Post|Put|Patch|Delete|Methods|Group|Fallback)\s*\(", RegexOptions.Compiled);

    [Fact]
    public void The_route_pattern_still_matches_a_route() =>
        Assert.Matches(RouteRegistration, "app.MapGet(\"/orders\", () => Results.Ok());");

    [Fact]
    public void Program_cs_registers_no_routes()
    {
        var source = File.ReadAllText(ProgramCsPath());

        var routes = RouteRegistration.Matches(source).Select(m => m.Value).ToList();

        Assert.Empty(routes);
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
