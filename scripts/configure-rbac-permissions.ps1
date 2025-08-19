# Configure RBAC permissions for Container App to read Azure resources
# This script grants the Container App's managed identity Reader access to the target subscriptions

param(
    [Parameter(Mandatory=$true)]
    [string]$ContainerAppName = "ca-stamps-portal",
    
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroupName = "rg-managemnt-portal",
    
    [string[]]$TargetSubscriptions = @(
        "2fb123ca-e419-4838-9b44-c2eb71a21769",  # MCAPS-Hybrid-REQ-101203-2024-scnichol-Host
        "480cb033-9a92-4912-9d30-c6b7bf795a87"   # MCAPS-Hybrid-REQ-103709-2024-scnichol-Hub
    )
)

Write-Host "🔐 Configuring RBAC permissions for Container App infrastructure discovery..." -ForegroundColor Cyan

# Get the Container App's managed identity principal ID
Write-Host "Getting Container App managed identity..." -ForegroundColor Yellow
$containerApp = az containerapp show --name $ContainerAppName --resource-group $ResourceGroupName --query "identity.principalId" -o tsv

if (-not $containerApp) {
    Write-Error "❌ Failed to get Container App managed identity. Make sure the Container App exists and has system-assigned managed identity enabled."
    exit 1
}

Write-Host "✅ Found Container App managed identity: $containerApp" -ForegroundColor Green

# Grant Reader role on each target subscription
foreach ($subscriptionId in $TargetSubscriptions) {
    Write-Host "Granting Reader access to subscription: $subscriptionId" -ForegroundColor Yellow
    
    try {
        $roleAssignment = az role assignment create `
            --assignee $containerApp `
            --role "Reader" `
            --scope "/subscriptions/$subscriptionId" `
            --output json | ConvertFrom-Json
        
        if ($roleAssignment) {
            Write-Host "✅ Successfully granted Reader access to subscription $subscriptionId" -ForegroundColor Green
        } else {
            Write-Warning "⚠️ Role assignment may already exist for subscription $subscriptionId"
        }
    }
    catch {
        Write-Error "❌ Failed to grant Reader access to subscription $subscriptionId : $($_.Exception.Message)"
    }
}

Write-Host "`n🎯 RBAC Configuration Summary:" -ForegroundColor Cyan
Write-Host "Container App: $ContainerAppName" -ForegroundColor White
Write-Host "Managed Identity: $containerApp" -ForegroundColor White
Write-Host "Role: Reader" -ForegroundColor White
Write-Host "Subscriptions:" -ForegroundColor White
foreach ($sub in $TargetSubscriptions) {
    Write-Host "  - $sub" -ForegroundColor White
}

Write-Host "`n🔄 The Container App will now be able to discover resources in the target subscriptions." -ForegroundColor Green
Write-Host "💡 Test the discovery by clicking 'Discover Infrastructure' button in the portal." -ForegroundColor Cyan
