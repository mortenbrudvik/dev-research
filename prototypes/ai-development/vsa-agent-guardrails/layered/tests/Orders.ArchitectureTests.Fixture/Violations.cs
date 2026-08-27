// Deliberate violations. The architecture tests assert that the rules FAIL on this assembly.
namespace Fixture.Domain
{
    public sealed class Entity
    {
        public string Describe() => Fixture.Application.Formatter.Format(this);   // domain reaches up into application
    }
}

namespace Fixture.Application
{
    public static class Formatter
    {
        public static string Format(object value) => new Fixture.Infrastructure.Repo().Save(value);   // application reaches down into infrastructure
    }
}

namespace Fixture.Infrastructure
{
    public sealed class Repo
    {
        public string Save(object value) => value.ToString() ?? "";
    }
}

namespace Fixture.Api
{
    public sealed class Handler
    {
        public string Run() => new Fixture.Infrastructure.Persistence.Store().Save("");   // api reaches into persistence
    }
}

namespace Fixture.Infrastructure.Persistence
{
    public sealed class Store
    {
        public string Save(object value) => value.ToString() ?? "";
    }
}
