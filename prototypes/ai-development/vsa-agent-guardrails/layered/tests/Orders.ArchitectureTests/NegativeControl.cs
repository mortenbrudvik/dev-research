using ArchUnitNET.Domain;
using ArchUnitNET.Loader;
using ArchUnitNET.xUnit;
using static ArchUnitNET.Fluent.ArchRuleDefinition;

namespace Orders.ArchitectureTests;

/// <summary>
/// Proves the rules can fail: each rule is evaluated against a fixture assembly that violates it. The controls assert
/// the *named* violation, because ArchUnitNET reports a mistyped subject pattern as a violation too, which would let
/// a rotted pattern pass a plain HasNoViolations check.
/// </summary>
public class NegativeControl
{
    private static readonly Architecture FixtureArchitecture =
        new ArchLoader().LoadAssemblies(typeof(global::Fixture.Domain.Entity).Assembly).Build();

    [Fact]
    public void Domain_rule_fails_when_domain_uses_application()
    {
        var rule = Types().That().ResideInNamespaceMatching(@"^Fixture\.Domain")
            .Should().NotDependOnAny(Types().That().ResideInNamespaceMatching(@"^Fixture\.(Application|Infrastructure)"));

        var error = Assert.Throws<FailedArchRuleException>(() => rule.Check(FixtureArchitecture));
        Assert.Contains("Fixture.Domain.Entity", error.Message, StringComparison.Ordinal);
    }

    [Fact]
    public void Application_rule_fails_when_application_uses_infrastructure()
    {
        var rule = Types().That().ResideInNamespaceMatching(@"^Fixture\.Application")
            .Should().NotDependOnAny(Types().That().ResideInNamespaceMatching(@"^Fixture\.Infrastructure"));

        var error = Assert.Throws<FailedArchRuleException>(() => rule.Check(FixtureArchitecture));
        Assert.Contains("Fixture.Application.Formatter", error.Message, StringComparison.Ordinal);
    }
}
