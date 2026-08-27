using System.Text.RegularExpressions;
using ArchUnitNET.Domain;
using ArchUnitNET.Loader;
using ArchUnitNET.xUnit;
using static ArchUnitNET.Fluent.ArchRuleDefinition;

namespace Orders.ArchitectureTests;

/// <summary>
/// Both sides of every rule are deny-lists, so an unbounded prefix such as ^Orders\.Domain can only over-match (a
/// hypothetical Orders.DomainServices would be held to the Domain rule); no (\.|$) bound is needed here, unlike the
/// sliced copy's allow-list rule. Program.cs is outside every rule: ArchUnitNET drops the &lt;Main&gt;$ method and the
/// closure types that top-level statements compile into, which is why CompositionRoot reads that file as text.
/// </summary>
public class LayerRules
{
    private const string PersistenceNamespace = @"^Orders\.Infrastructure\.Persistence";
    private const string DbAbstraction = @"^Orders\.Application\.Common\.Interfaces\.IOrdersDbContext$";

    private static readonly Architecture Layers = new ArchLoader().LoadAssemblies(
        typeof(Orders.Domain.Entities.Order).Assembly,
        typeof(Orders.Application.DependencyInjection).Assembly,
        typeof(Orders.Infrastructure.DependencyInjection).Assembly,
        typeof(Program).Assembly).Build();

    // A rule whose object pattern matches nothing passes silently, so both object patterns of the third rule are
    // pinned to real types (a mistyped subject pattern, by contrast, fails the rule on its own).
    [Fact]
    public void The_persistence_patterns_still_match_real_types()
    {
        Assert.Contains(Layers.Types, t => Regex.IsMatch(t.Namespace.FullName, PersistenceNamespace));
        Assert.Contains(Layers.Types, t => Regex.IsMatch(t.FullName, DbAbstraction));
    }

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

    // The API talks to handlers, never to the database: neither the concrete DbContext nor the IOrdersDbContext
    // abstraction (which exists for the Application layer) may be referenced from Orders.Api.
    [Fact]
    public void Api_does_not_use_persistence_directly() =>
        Types().That().ResideInNamespaceMatching(@"^Orders\.Api")
            .Should().NotDependOnAny(Types().That().ResideInNamespaceMatching(PersistenceNamespace)
                .Or().HaveFullNameMatching(DbAbstraction))
            .Check(Layers);
}
