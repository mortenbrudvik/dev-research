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
