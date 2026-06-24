[CmdletBinding()]
param(
    [string]$ConfigPath = (Join-Path $PSScriptRoot "../config/tenant.json"),
    [string]$OutputDirectory,
    [switch]$SkipConnect
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "../shared/PowerPlatformAudit.Common.ps1")

$config = Get-PowerPlatformAuditConfig -ConfigPath $ConfigPath
if (-not $OutputDirectory) {
    $OutputDirectory = New-AuditRunDirectory -Config $config
}

Ensure-OutputDirectory -Path $OutputDirectory | Out-Null

function Get-JsonItemCount {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        return 0
    }

    $data = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
    return @($data).Count
}

$summary = [pscustomobject]@{
    EnvironmentCount = Get-JsonItemCount -Path (Join-Path $OutputDirectory "environments.json")
    AppCount = Get-JsonItemCount -Path (Join-Path $OutputDirectory "apps.json")
    FlowCount = Get-JsonItemCount -Path (Join-Path $OutputDirectory "flows.json")
    ConnectorCount = Get-JsonItemCount -Path (Join-Path $OutputDirectory "connectors.json")
    OrphanedAssetCandidates = if (Test-Path -LiteralPath (Join-Path $OutputDirectory "orphanedAssets.csv")) { @(Import-Csv -LiteralPath (Join-Path $OutputDirectory "orphanedAssets.csv")).Count } else { 0 }
    PremiumConnectorCandidates = if (Test-Path -LiteralPath (Join-Path $OutputDirectory "premiumConnectorUsage.csv")) { @(Import-Csv -LiteralPath (Join-Path $OutputDirectory "premiumConnectorUsage.csv")).Count } else { 0 }
    DlpPolicyCount = Get-JsonItemCount -Path (Join-Path $OutputDirectory "dlpPolicies.json")
    GeneratedTimestamp = (Get-Date).ToString("o")
  }

Write-JsonFile -Path (Join-Path $OutputDirectory "governanceSummary.json") -InputObject $summary

$summary
