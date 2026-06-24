[CmdletBinding()]
param(
    [switch]$InstallMissing
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "../shared/PowerPlatformAudit.Common.ps1")

$requiredModules = @(
    "Microsoft.PowerApps.Administration.PowerShell",
    "Microsoft.PowerApps.PowerShell",
    "Microsoft.Graph.Authentication",
    "Microsoft.Graph"
)

$results = foreach ($moduleName in $requiredModules) {
    $module = Get-Module -ListAvailable -Name $moduleName | Sort-Object Version -Descending | Select-Object -First 1
    if (-not $module -and $InstallMissing) {
        Install-Module -Name $moduleName -Scope CurrentUser -Force -AllowClobber
        $module = Get-Module -ListAvailable -Name $moduleName | Sort-Object Version -Descending | Select-Object -First 1
    }

    [pscustomobject]@{
        Module = $moduleName
        Installed = [bool]$module
        Version = if ($module) { $module.Version.ToString() } else { $null }
    }
}

$results | Format-Table -AutoSize

if ($results.Installed -contains $false) {
    Write-Warning "One or more required modules are missing. Re-run with -InstallMissing to install them."
}
