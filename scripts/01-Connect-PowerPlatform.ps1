[CmdletBinding()]
param(
    [string]$ConfigPath = (Join-Path $PSScriptRoot "../config/tenant.json"),
    [switch]$ConnectGraph
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "../shared/PowerPlatformAudit.Common.ps1")

Import-PowerPlatformAuditPrereqs
$config = Get-PowerPlatformAuditConfig -ConfigPath $ConfigPath

$ppStatus = Connect-PowerPlatformFromConfig -Config $config
$graphStatus = $null

if ($ConnectGraph) {
    try {
        $graphStatus = Connect-GraphFromConfig -Config $config
    }
    catch {
        Write-Warning "Graph connection failed: $($_.Exception.Message)"
    }
}

[pscustomobject]@{
    PowerPlatformConnected = $ppStatus.Connected
    PowerPlatformTenantId = $ppStatus.TenantId
    GraphConnected = [bool]$graphStatus
    GraphTenantId = if ($graphStatus) { $graphStatus.TenantId } else { $null }
    GraphScopes = if ($graphStatus) { ($graphStatus.Scopes -join ",") } else { $null }
} | Format-List
