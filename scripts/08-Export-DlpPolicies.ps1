[CmdletBinding()]
param(
    [string]$ConfigPath = (Join-Path $PSScriptRoot "../config/tenant.json"),
    [string]$OutputDirectory,
    [switch]$SkipConnect
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "../shared/PowerPlatformAudit.Common.ps1")

Import-PowerPlatformAuditPrereqs
$config = Get-PowerPlatformAuditConfig -ConfigPath $ConfigPath

if (-not $OutputDirectory) {
    $OutputDirectory = New-AuditRunDirectory -Config $config
}

Ensure-OutputDirectory -Path $OutputDirectory | Out-Null

if (-not $SkipConnect) {
    Connect-PowerPlatformFromConfig -Config $config | Out-Null
}

try {
    $policies = @(Get-AdminDlpPolicy | ForEach-Object {
        [pscustomobject]@{
            PolicyName = $_.PolicyName
            DisplayName = $_.DisplayName
            CreatedTime = $_.CreatedTime
            LastModifiedTime = $_.LastModifiedTime
            EnvironmentType = $_.EnvironmentType
        }
    })
}
catch {
    $policies = @()
    Write-Warning "DLP policy export failed gracefully: $($_.Exception.Message)"
    $warning = New-PortfolioSafeWarning -Message "DLP policy export was unavailable for this run."
    Write-JsonFile -Path (Join-Path $OutputDirectory "dlpPolicies.warning.json") -InputObject $warning
}

Write-JsonFile -Path (Join-Path $OutputDirectory "dlpPolicies.json") -InputObject $policies
Write-CsvFile -Path (Join-Path $OutputDirectory "dlpPolicies.csv") -InputObject $policies

$policies
