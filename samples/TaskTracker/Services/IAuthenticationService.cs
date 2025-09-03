namespace TaskTracker.Blazor.Services
{
    public interface IAuthenticationService
    {
    Task<string> LoginAsync(string email, string password);
    Task LogoutAsync();
    Task<bool> IsAuthenticatedAsync();
    string? GetCurrentTenantId();
    string? GetCurrentUserId();
    }
}
