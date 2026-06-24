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

$apps = [System.Collections.Generic.List[object]]::new()
$environments = @(Get-AdminPowerAppEnvironment)

foreach ($environment in $environments) {
    $environmentName = $environment.EnvironmentName
    $environmentApps = @(Get-AdminPowerApp -EnvironmentName $environmentName -ErrorAction SilentlyContinue)

    foreach ($app in $environmentApps) {
        [void]$apps.Add([pscustomobject]@{
            AppName = $app.AppName
            DisplayName = $app.DisplayName
            Environment = $environmentName
            Owner = $app.Owner.displayName
            OwnerObjectId = $app.Owner.id
            CreatedTime = $app.CreatedTime
            LastModifiedTime = $app.LastModifiedTime
            AppType = $app.AppType
        })
    }
}

Write-JsonFile -Path (Join-Path $OutputDirectory "apps.json") -InputObject $apps
Write-CsvFile -Path (Join-Path $OutputDirectory "apps.csv") -InputObject $apps

$apps
