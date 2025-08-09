#requires -Version 7.0
param(
    [string]$GraphQLEndpoint = "http://localhost:8082/graphql",
    [switch]$AsAdmin
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function New-AppServicePrincipalHeader {
    param([switch]$Admin)
    $claims = @(
        @{ typ = "http://schemas.microsoft.com/identity/claims/identityprovider"; val = "aad" },
        @{ typ = "http://schemas.xmlsoap.org/ws/2005/05/identity/claims/nameidentifier"; val = "localdev" },
        @{ typ = "name"; val = "localdev" },
        @{ typ = "roles"; val = "authenticated" }
    )
    if ($Admin) {
        $claims += @{ typ = "roles"; val = "platform.admin" }
    }
    $principal = @{ auth_typ = "aad"; name_typ = "name"; role_typ = "roles"; claims = $claims }
    $json = $principal | ConvertTo-Json -Depth 5 -Compress
    # Base64 encode without CRLF
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
    $b64 = [System.Convert]::ToBase64String($bytes)
    return @{ 'X-MS-CLIENT-PRINCIPAL' = $b64 }
}

function Invoke-GraphQLQuery {
    param(
        [string]$Url,
        [string]$Query,
        [hashtable]$Variables,
        [hashtable]$Headers
    )
    $body = @{ query = $Query; variables = $Variables } | ConvertTo-Json -Depth 10
    if (-not $Headers) { $Headers = @{} }
    $resp = Invoke-RestMethod -Uri $Url -Method Post -ContentType 'application/json' -Headers $Headers -Body $body
    return $resp
}

Write-Host "GraphQL smoke test against $GraphQLEndpoint"
if ($AsAdmin) { Write-Host 'Simulating platform.admin via X-MS-CLIENT-PRINCIPAL header' }
${__headers} = New-AppServicePrincipalHeader -Admin:$AsAdmin.IsPresent

# 1. List Tenants
$q1 = 'query { Tenants { id domain status cellId } }'
$r1 = Invoke-GraphQLQuery -Url $GraphQLEndpoint -Query $q1 -Variables @{} -Headers ${__headers}
if (-not $r1.data -or -not $r1.data.Tenants) { throw 'Tenants query failed or returned no data' }
Write-Host ("Tenants count: {0}" -f $r1.data.Tenants.Count)

# 2. Create a temp tenant
$tenantId = "smoketest-" + [Guid]::NewGuid().ToString('N').Substring(0,8)
$createMutation = @'
mutation CreateTenant($t: Tenant_input!) {
  createTenant(item: $t) { id }
}
'@
$tenantObj = @{ id=$tenantId; tenantId=$tenantId; displayName='Smoke Test'; domain="$tenantId.example.com"; status='active'; tier='standard'; cellId='cell-eastus-1' }
$r2 = Invoke-GraphQLQuery -Url $GraphQLEndpoint -Query $createMutation -Variables @{ t = $tenantObj } -Headers ${__headers}
if ($r2.errors) { throw ("CreateTenant failed: " + ($r2.errors | ConvertTo-Json -Depth 10)) }
Write-Host "Created tenant $tenantId"

# 3. Delete temp tenant (requires partitionKeyValue)
$deleteMutation = 'mutation($id: ID!, $pk: String!) { deleteTenant(id: $id, partitionKeyValue: $pk) }'
$r3 = Invoke-GraphQLQuery -Url $GraphQLEndpoint -Query $deleteMutation -Variables @{ id = $tenantId; pk = $tenantId } -Headers ${__headers}
if ($r3.errors) { throw ("DeleteTenant failed: " + ($r3.errors | ConvertTo-Json -Depth 10)) }
Write-Host "Deleted tenant $tenantId"

Write-Host 'Smoke test passed.' -ForegroundColor Green
