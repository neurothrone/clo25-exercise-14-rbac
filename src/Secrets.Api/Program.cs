var builder = WebApplication.CreateBuilder(args);

var app = builder.Build();

app.MapGet("/", () => "Secrets.Api is running. Try /secret-check.");

// The app never knows that Key Vault exists. It reads an environment variable, and
// App Service fills in the value from the vault before the app sees it.
// Never return the value itself: whatever an endpoint returns ends up in a log sooner or later.
app.MapGet("/secret-check", () =>
{
    var value = Environment.GetEnvironmentVariable("MY_SECRET");

    return new
    {
        present = !string.IsNullOrEmpty(value),
        length = value?.Length ?? 0,
        // True when App Service could not resolve the reference and passed the
        // reference string itself through instead of the secret.
        unresolved = value?.StartsWith("@Microsoft.KeyVault(", StringComparison.OrdinalIgnoreCase) ?? false
    };
});

app.Run();
