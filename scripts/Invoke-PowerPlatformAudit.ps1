[CmdletBinding()]
param(
    [string]$ConfigPath = (Join-Path $PSScriptRoot "../config/tenant.json"),
    [switch]$ConnectGraph
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "../shared/PowerPlatformAudit.Common.ps1")

Import-PowerPlatformAuditPrereqs
$config = Get-PowerPlatformAuditConfig -ConfigPath $ConfigPath
$outputDirectory = New-AuditRunDirectory -Config $config

Connect-PowerPlatformFromConfig -Config $config | Out-Null

if ($ConnectGraph) {
    try {
        Connect-GraphFromConfig -Config $config | Out-Null
    }
    catch {
        Write-Warning "Graph connection failed before workload execution: $($_.Exception.Message)"
    }
}

$workloads = @(
    [pscustomobject]@{ Name = "Environments"; Script = "02-Export-Environments.ps1" },
    [pscustomobject]@{ Name = "PowerApps"; Script = "03-Export-PowerAppsInventory.ps1" },
    [pscustomobject]@{ Name = "Flows"; Script = "04-Export-FlowsInventory.ps1" },
    [pscustomobject]@{ Name = "Connectors"; Script = "05-Export-ConnectorsReport.ps1" },
    [pscustomobject]@{ Name = "OrphanedAssets"; Script = "06-Find-OrphanedAssets.ps1" },
    [pscustomobject]@{ Name = "PremiumConnectors"; Script = "07-Find-PremiumConnectorUsage.ps1" },
    [pscustomobject]@{ Name = "DlpPolicies"; Script = "08-Export-DlpPolicies.ps1" },
    [pscustomobject]@{ Name = "GovernanceSummary"; Script = "09-Export-GovernanceSummary.ps1" }
)

$manifest = [System.Collections.Generic.List[object]]::new()

foreach ($workload in $workloads) {
    if (-not (Test-ConfiguredWorkload -Config $config -WorkloadName $workload.Name)) {
        continue
    }

    $scriptPath = Join-Path $PSScriptRoot $workload.Script
    $started = Get-Date

    try {
        & $scriptPath -ConfigPath $ConfigPath -OutputDirectory $outputDirectory -SkipConnect:$true | Out-Null

        [void]$manifest.Add([pscustomobject]@{
            Workload = $workload.Name
            Script = $workload.Script
            Status = "Succeeded"
            Started = $started.ToString("o")
            Finished = (Get-Date).ToString("o")
            Error = $null
        })
    }
    catch {
        [void]$manifest.Add([pscustomobject]@{
            Workload = $workload.Name
            Script = $workload.Script
            Status = "Failed"
            Started = $started.ToString("o")
            Finished = (Get-Date).ToString("o")
            Error = $_.Exception.Message
        })
    }
}

Write-JsonFile -Path (Join-Path $outputDirectory "manifest.json") -InputObject $manifest
Write-CsvFile -Path (Join-Path $outputDirectory "manifest.csv") -InputObject $manifest

$manifest
