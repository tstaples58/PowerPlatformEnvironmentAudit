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

$flows = [System.Collections.Generic.List[object]]::new()
$environments = @(Get-AdminPowerAppEnvironment)

foreach ($environment in $environments) {
    $environmentName = $environment.EnvironmentName
    $environmentFlows = @(Get-AdminFlow -EnvironmentName $environmentName -ErrorAction SilentlyContinue)

    foreach ($flow in $environmentFlows) {
        [void]$flows.Add([pscustomobject]@{
            FlowName = $flow.FlowName
            DisplayName = $flow.DisplayName
            Environment = $environmentName
            Owner = $flow.CreatedBy.displayName
            OwnerObjectId = $flow.CreatedBy.id
            EnabledState = $flow.Enabled
            CreatedTime = $flow.CreatedTime
            LastModifiedTime = $flow.LastModifiedTime
        })
    }
}

Write-JsonFile -Path (Join-Path $OutputDirectory "flows.json") -InputObject $flows
Write-CsvFile -Path (Join-Path $OutputDirectory "flows.csv") -InputObject $flows

$flows
