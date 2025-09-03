using System.Threading.Tasks;
using Microsoft.JSInterop;

namespace TaskTracker.Blazor.Services
{
    public class AuthenticationService : IAuthenticationService
    {
        private readonly IJSRuntime _jsRuntime;
    private string? _currentTenantId;
    private string? _currentUserId;
        public AuthenticationService(IJSRuntime jsRuntime)
        {
            _jsRuntime = jsRuntime;
        }

        public string? GetCurrentTenantId()
        {
            return _currentTenantId ?? "tenant-demo";
        }

        public string? GetCurrentUserId()
        {
            return _currentUserId ?? "demo-user-id";
        }

        public async Task<string> LoginAsync(string email, string password)
        {
            // Demo: Always return a fake token
            var token = $"fake-token-for-{email}";

            // Map email to tenantId (demo-only)
            var tenantId = email?.ToLowerInvariant() switch
            {
                string e when string.IsNullOrWhiteSpace(e) => null,
                string e when e.EndsWith("@contoso.com") => "tenant-contoso",
                string e when e.EndsWith("@fabrikam.com") => "tenant-fabrikam",
                string e when e.EndsWith("@adventure-works.com") => "tenant-adventure-works",
                _ => "tenant-demo"
            };

            var userId = Guid.NewGuid().ToString();

            await _jsRuntime.InvokeVoidAsync("localStorage.setItem", "authToken", token);
            if (!string.IsNullOrEmpty(tenantId))
            {
                await _jsRuntime.InvokeVoidAsync("localStorage.setItem", "tenantId", tenantId);
                _currentTenantId = tenantId;
            }
            await _jsRuntime.InvokeVoidAsync("localStorage.setItem", "userId", userId);
            _currentUserId = userId;

            return token;
        }

        public async Task LogoutAsync()
        {
            await _jsRuntime.InvokeVoidAsync("localStorage.removeItem", "authToken");
            await _jsRuntime.InvokeVoidAsync("localStorage.removeItem", "tenantId");
            await _jsRuntime.InvokeVoidAsync("localStorage.removeItem", "userId");
            _currentTenantId = null;
            _currentUserId = null;
        }

        public async Task<bool> IsAuthenticatedAsync()
        {
            var token = await _jsRuntime.InvokeAsync<string?>("localStorage.getItem", "authToken");
            var tenant = await _jsRuntime.InvokeAsync<string?>("localStorage.getItem", "tenantId");
            return !string.IsNullOrEmpty(token) && !string.IsNullOrEmpty(tenant);
        }
    }
}
