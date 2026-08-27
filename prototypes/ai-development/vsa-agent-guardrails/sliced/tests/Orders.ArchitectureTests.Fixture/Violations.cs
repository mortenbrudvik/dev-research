// Deliberate violations. The architecture tests assert that the rules FAIL on this assembly.
namespace Fixture.Features.A
{
    public sealed class AHandler
    {
        public string Handle() => new Fixture.Features.B.BHelper().Value;   // slice A reaches into slice B
    }
}

namespace Fixture.Features.B
{
    public sealed class BHelper
    {
        public string Value => "b";
    }
}

namespace Fixture.Domain
{
    public sealed class Entity
    {
        public string Describe() => Fixture.Platform.Formatter.Format(this);   // domain reaches into platform
    }
}

namespace Fixture.Platform
{
    public static class Formatter
    {
        public static string Format(object value) => value.ToString() ?? "";
    }
}

namespace Fixture.Features
{
    public static class SharedHelper   // a type directly under Features, outside any slice — the shared-code shortcut
    {
        public static string Format(string value) => value.ToUpperInvariant();
    }
}

namespace Fixture.Features.D
{
    public sealed class DUser
    {
        public string Handle() => Fixture.Features.SharedHelper.Format("d");   // slice D uses the shortcut
    }
}
