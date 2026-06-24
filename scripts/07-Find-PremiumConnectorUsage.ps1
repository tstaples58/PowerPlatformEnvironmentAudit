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

$connectorsPath = Join-Path $OutputDirectory "connectors.json"
if (-not (Test-Path -LiteralPath $connectorsPath)) {
    throw "Premium connector detection expects connectors.json in the output directory."
}

$premiumIndicators = @(
    "http",
    "sql",
    "salesforce",
    "servicebus",
    "azuredevops",
    "oracle",
    "customapi"
)

$matches = @(Get-Content -LiteralPath $connectorsPath -Raw | ConvertFrom-Json | Where-Object {
    $name = $_.ConnectorName.ToString().ToLowerInvariant()
    $premiumIndicators | Where-Object { $name -like "*$_*" }
} | ForEach-Object {
    [pscustomobject]@{
        ConnectorName = $_.ConnectorName
        ConnectorType = $_.ConnectorType
        Environment = $_.Environment
        RelatedAssetType = $_.RelatedAssetType
        RelatedAssetName = $_.RelatedAssetName
        RiskCategory = "PremiumOrHighRisk"
    }
})

$summary = [pscustomobject]@{
    GeneratedTime = (Get-Date).ToString("o")
    CandidateCount = @($matches).Count
    Indicators = $premiumIndicators
}

Write-CsvFile -Path (Join-Path $OutputDirectory "premiumConnectorUsage.csv") -InputObject $matches
Write-JsonFile -Path (Join-Path $OutputDirectory "premiumConnectorUsage.summary.json") -InputObject $summary

$matches
