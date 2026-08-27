using ArchUnitNET.Domain;
using ArchUnitNET.Loader;
using ArchUnitNET.xUnit;
using static ArchUnitNET.Fluent.ArchRuleDefinition;
using static ArchUnitNET.Fluent.Slices.SliceRuleDefinition;

namespace Orders.ArchitectureTests;

public class SliceRules
{
    private static readonly Architecture Api =
        new ArchLoader().LoadAssemblies(typeof(Program).Assembly).Build();

    [Fact]
    public void Slices_do_not_depend_on_each_other() =>
        Slices().Matching("Orders.Api.Features.(*)")
            .Should().NotDependOnEachOther()
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
