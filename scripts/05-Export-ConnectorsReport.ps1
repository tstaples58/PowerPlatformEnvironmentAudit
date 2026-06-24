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

$appsPath = Join-Path $OutputDirectory "apps.json"
$flowsPath = Join-Path $OutputDirectory "flows.json"

if (-not (Test-Path -LiteralPath $appsPath) -or -not (Test-Path -LiteralPath $flowsPath)) {
    throw "Connector reporting expects apps.json and flows.json in the output directory. Run the app and flow inventories first."
}

$connectorIndicators = @(
    "shared_",
    "sql",
    "azure",
    "http",
    "customapi",
    "salesforce",
    "servicebus"
)

$connectors = [System.Collections.Generic.List[object]]::new()

foreach ($app in (Get-Content -LiteralPath $appsPath -Raw | ConvertFrom-Json)) {
    $name = $app.DisplayName
    foreach ($indicator in $connectorIndicators) {
        if ($name -match [regex]::Escape($indicator)) {
            [void]$connectors.Add([pscustomobject]@{
                ConnectorName = $indicator
                ConnectorType = "Inferred"
                Environment = $app.Environment
                RelatedAssetType = "App"
                RelatedAssetName = $app.DisplayName
            })
        }
    }
}

foreach ($flow in (Get-Content -LiteralPath $flowsPath -Raw | ConvertFrom-Json)) {
    $name = $flow.DisplayName
    foreach ($indicator in $connectorIndicators) {
        if ($name -match [regex]::Escape($indicator)) {
            [void]$connectors.Add([pscustomobject]@{
                ConnectorName = $indicator
                ConnectorType = "Inferred"
                Environment = $flow.Environment
                RelatedAssetType = "Flow"
                RelatedAssetName = $flow.DisplayName
            })
        }
    }
}

Write-JsonFile -Path (Join-Path $OutputDirectory "connectors.json") -InputObject $connectors
Write-CsvFile -Path (Join-Path $OutputDirectory "connectors.csv") -InputObject $connectors

$connectors
