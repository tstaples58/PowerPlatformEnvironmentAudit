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

$environments = @(Get-AdminPowerAppEnvironment | ForEach-Object {
    [pscustomobject]@{
        EnvironmentName = $_.EnvironmentName
        DisplayName = $_.DisplayName
        Location = $_.Location
        Type = $_.EnvironmentType
        CreatedTime = $_.CreatedTime
        CreatedBy = $_.CreatedBy.displayName
        ProvisioningState = $_.ProvisioningState
    }
})

Write-JsonFile -Path (Join-Path $OutputDirectory "environments.json") -InputObject $environments
Write-CsvFile -Path (Join-Path $OutputDirectory "environments.csv") -InputObject $environments

$environments
