using ArchUnitNET.Domain;
using ArchUnitNET.Loader;
using ArchUnitNET.xUnit;
using static ArchUnitNET.Fluent.ArchRuleDefinition;
using static ArchUnitNET.Fluent.Slices.SliceRuleDefinition;

namespace Orders.ArchitectureTests;

/// <summary>
/// The sliced copy's rules. A slice is one flat namespace, Orders.Api.Features.[UseCase]: ArchUnitNET treats a
/// sub-namespace (Features.X.Internal) as a separate slice, so every file of a slice lives in its folder root.
/// </summary>
public class SliceRules
{
    private const string SlicePattern = "Orders.Api.Features.(*)";

    private static readonly Architecture Api =
        new ArchLoader().LoadAssemblies(typeof(Program).Assembly).Build();

    [Fact]
    public void The_slice_pattern_still_matches_slices() =>
        // A slice rule passes vacuously when its pattern matches nothing; this keeps the rule below honest.
        Assert.Contains(Api.Types, t => t.Namespace.FullName.StartsWith("Orders.Api.Features.", StringComparison.Ordinal));

    [Fact]
    public void Slices_do_not_depend_on_each_other() =>
        Slices().Matching(SlicePattern)
            .Should().NotDependOnEachOther()
            .Check(Api);

    [Fact]
    public void Slices_depend_only_on_domain_platform_and_frameworks() =>
        // Anything else under Orders.Api — a type directly in Features, a Common/ or Helpers/ namespace — is a shared-code shortcut.
        Types().That().ResideInNamespaceMatching(@"^Orders\.Api\.Features\.")
            .Should().NotDependOnAny(Types().That().ResideInNamespaceMatching(@"^Orders\.Api(?!\.(Features\.|Domain|Platform))"))
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
