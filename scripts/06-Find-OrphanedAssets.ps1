[CmdletBinding()]
param(
    [string]$ConfigPath = (Join-Path $PSScriptRoot "../config/tenant.json"),
    [string]$OutputDirectory,
    [switch]$SkipConnect,
    [switch]$SkipGraph
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
    throw "Orphaned asset detection expects apps.json and flows.json in the output directory."
}

Import-PowerPlatformAuditPrereqs

if (-not $SkipGraph) {
    try {
        Connect-GraphFromConfig -Config $config | Out-Null
    }
    catch {
        Write-Warning "Graph enrichment unavailable: $($_.Exception.Message)"
    }
}

$candidates = [System.Collections.Generic.List[object]]::new()
$assets = @()
$assets += Get-Content -LiteralPath $appsPath -Raw | ConvertFrom-Json | ForEach-Object {
    $_ | Add-Member -NotePropertyName AssetType -NotePropertyValue "App" -Force
    $_ | Add-Member -NotePropertyName AssetName -NotePropertyValue $_.DisplayName -Force
    $_
}
$assets += Get-Content -LiteralPath $flowsPath -Raw | ConvertFrom-Json | ForEach-Object {
    $_ | Add-Member -NotePropertyName AssetType -NotePropertyValue "Flow" -Force
    $_ | Add-Member -NotePropertyName AssetName -NotePropertyValue $_.DisplayName -Force
    $_
}

foreach ($asset in $assets) {
    $ownerId = $asset.OwnerObjectId
    $resolution = Resolve-UserDisplayNameFromId -UserId $ownerId
    $isOrphanCandidate = [string]::IsNullOrWhiteSpace($asset.Owner) -or @("Missing", "NotFound", "Disabled", "GraphUnavailable") -contains $resolution.Status

    if ($isOrphanCandidate) {
        [void]$candidates.Add([pscustomobject]@{
            AssetType = $asset.AssetType
            AssetName = $asset.AssetName
            Environment = $asset.Environment
            RecordedOwner = $asset.Owner
            OwnerObjectId = $ownerId
            ResolutionStatus = $resolution.Status
            ResolvedDisplayName = $resolution.DisplayName
            ResolvedUserPrincipalName = $resolution.UserPrincipalName
            Confidence = if ($resolution.Status -in @("NotFound", "Disabled")) { "High" } elseif ($resolution.Status -eq "Missing") { "Medium" } else { "Low" }
        })
    }
}

$summary = [pscustomobject]@{
    GeneratedTime = (Get-Date).ToString("o")
    CandidateCount = @($candidates).Count
    Warning = if ($SkipGraph) { "Graph enrichment was skipped." } else { $null }
}

Write-CsvFile -Path (Join-Path $OutputDirectory "orphanedAssets.csv") -InputObject $candidates
Write-JsonFile -Path (Join-Path $OutputDirectory "orphanedAssets.summary.json") -InputObject $summary

$candidates
