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

    private const string RestoreFixture = "the fixture no longer violates the rule — restore tests/Orders.ArchitectureTests.Fixture/Violations.cs";

    [Fact]
    public void Slice_rule_fails_on_a_cross_slice_dependency()
    {
        var rule = Slices().Matching("Fixture.Features.(*)").Should().NotDependOnEachOther();

        Assert.False(rule.HasNoViolations(FixtureArchitecture), RestoreFixture);
    }

    [Fact]
    public void Shared_code_rule_fails_when_a_slice_uses_a_type_directly_under_features()
    {
        var rule = Types().That().ResideInNamespaceMatching(@"^Fixture\.Features\.")
            .Should().NotDependOnAny(Types().That().ResideInNamespaceMatching(@"^Fixture(?!\.(Features\.|Domain|Platform))"));

        Assert.False(rule.HasNoViolations(FixtureArchitecture), RestoreFixture);
    }

    [Fact]
    public void Domain_rule_fails_when_domain_uses_platform()
    {
        var rule = Types().That().ResideInNamespaceMatching(@"^Fixture\.Domain")
            .Should().NotDependOnAny(Types().That().ResideInNamespaceMatching(@"^Fixture\.(Features|Platform)"));

        Assert.False(rule.HasNoViolations(FixtureArchitecture), RestoreFixture);
    }
}
