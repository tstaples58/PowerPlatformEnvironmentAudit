Set-StrictMode -Version Latest

function Get-PowerPlatformAuditRoot {
    [CmdletBinding()]
    param()

    return (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
}

function Get-PowerPlatformAuditConfig {
    [CmdletBinding()]
    param(
        [string]$ConfigPath
    )

    if ([string]::IsNullOrWhiteSpace($ConfigPath)) {
        $ConfigPath = Join-Path (Get-PowerPlatformAuditRoot) "config/tenant.json"
    }

    if (-not (Test-Path -LiteralPath $ConfigPath)) {
        throw "Configuration file not found: $ConfigPath"
    }

    $raw = Get-Content -LiteralPath $ConfigPath -Raw
    $config = $raw | ConvertFrom-Json

    if (-not $config.reportOutputPath) {
        $config | Add-Member -NotePropertyName reportOutputPath -NotePropertyValue "output"
    }

    if (-not $config.inactiveDays) {
        $config | Add-Member -NotePropertyName inactiveDays -NotePropertyValue 90
    }

    if (-not $config.graphScopes) {
        $config | Add-Member -NotePropertyName graphScopes -NotePropertyValue @("Directory.Read.All", "User.Read.All")
    }

    if (-not $config.workloads) {
        $config | Add-Member -NotePropertyName workloads -NotePropertyValue @()
    }

    return $config
}

function Ensure-Module {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name,
        [string]$MinimumVersion
    )

    $available = Get-Module -ListAvailable -Name $Name | Sort-Object Version -Descending | Select-Object -First 1
    if (-not $available) {
        throw "Required module '$Name' is not installed."
    }

    $importParams = @{ Name = $Name; ErrorAction = "Stop" }
    if ($MinimumVersion) {
        $importParams.MinimumVersion = $MinimumVersion
    }

    Import-Module @importParams | Out-Null
}

function Import-PowerPlatformAuditPrereqs {
    [CmdletBinding()]
    param()

    Ensure-Module -Name "Microsoft.PowerApps.Administration.PowerShell"
    Ensure-Module -Name "Microsoft.PowerApps.PowerShell"

    $graphAuth = Get-Module -ListAvailable -Name "Microsoft.Graph.Authentication" | Select-Object -First 1
    $graphCore = Get-Module -ListAvailable -Name "Microsoft.Graph" | Select-Object -First 1

    if ($graphAuth) {
        Import-Module Microsoft.Graph.Authentication -ErrorAction Stop | Out-Null
    }

    if ($graphCore) {
        Import-Module Microsoft.Graph -ErrorAction SilentlyContinue | Out-Null
    }
}

function Ensure-OutputDirectory {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        $null = New-Item -ItemType Directory -Path $Path -Force
    }

    return (Resolve-Path -LiteralPath $Path).Path
}

function New-AuditRunDirectory {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Config
    )

    $root = Get-PowerPlatformAuditRoot
    $baseOutput = Join-Path $root $Config.reportOutputPath
    $baseOutput = Ensure-OutputDirectory -Path $baseOutput

    $folderName = "run-{0}" -f (Get-Date -Format "yyyyMMdd-HHmmss")
    $runPath = Join-Path $baseOutput $folderName
    $null = New-Item -ItemType Directory -Path $runPath -Force
    return (Resolve-Path -LiteralPath $runPath).Path
}

function Write-JsonFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,
        [Parameter(Mandatory)]
        $InputObject,
        [int]$Depth = 10
    )

    $directory = Split-Path -Parent $Path
    if ($directory) {
        Ensure-OutputDirectory -Path $directory | Out-Null
    }

    $json = $InputObject | ConvertTo-Json -Depth $Depth
    Set-Content -LiteralPath $Path -Value $json -Encoding utf8
}

function Write-CsvFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,
        [Parameter(Mandatory)]
        $InputObject
    )

    $directory = Split-Path -Parent $Path
    if ($directory) {
        Ensure-OutputDirectory -Path $directory | Out-Null
    }

    @($InputObject) | Export-Csv -LiteralPath $Path -NoTypeInformation -Encoding utf8
}

function Connect-PowerPlatformFromConfig {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Config
    )

    $tenantId = $Config.tenantId
    $connectParams = @{ ErrorAction = "Stop" }
    if ($tenantId -and $tenantId -ne "<TENANT_ID>") {
        $connectParams.TenantID = $tenantId
    }

    Add-PowerAppsAccount @connectParams | Out-Null

    return [pscustomobject]@{
        Connected = $true
        TenantId = if ($tenantId) { $tenantId } else { $null }
    }
}

function Connect-GraphFromConfig {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Config
    )

    if (-not (Get-Command -Name Connect-MgGraph -ErrorAction SilentlyContinue)) {
        throw "Microsoft Graph PowerShell is not available."
    }

    $scopes = @($Config.graphScopes | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    if (-not $scopes) {
        $scopes = @("Directory.Read.All", "User.Read.All")
    }

    Connect-MgGraph -Scopes $scopes -NoWelcome | Out-Null
    $context = Get-MgContext

    return [pscustomobject]@{
        Connected = $true
        TenantId = $context.TenantId
        Scopes = @($context.Scopes)
    }
}

function Invoke-GraphRequestJson {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Uri
    )

    if (-not (Get-Command -Name Invoke-MgGraphRequest -ErrorAction SilentlyContinue)) {
        throw "Invoke-MgGraphRequest is not available."
    }

    return Invoke-MgGraphRequest -Method GET -Uri $Uri -OutputType PSObject
}

function Get-GraphCollectionAll {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Uri
    )

    $results = [System.Collections.Generic.List[object]]::new()
    $nextLink = $Uri

    while ($nextLink) {
        $response = Invoke-GraphRequestJson -Uri $nextLink
        if ($response.value) {
            foreach ($item in $response.value) {
                [void]$results.Add($item)
            }
        }

        $nextLink = $response.'@odata.nextLink'
    }

    return $results
}

function Test-ConfiguredWorkload {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Config,
        [Parameter(Mandatory)]
        [string]$WorkloadName
    )

    return @($Config.workloads) -contains $WorkloadName
}

function Get-DaysSinceDateTime {
    [CmdletBinding()]
    param(
        $Value
    )

    if (-not $Value) {
        return $null
    }

    try {
        $parsed = [datetimeoffset]::Parse($Value.ToString())
        return [math]::Round(((Get-Date) - $parsed.LocalDateTime).TotalDays, 2)
    }
    catch {
        return $null
    }
}

function Resolve-UserDisplayNameFromId {
    [CmdletBinding()]
    param(
        [string]$UserId
    )

    if ([string]::IsNullOrWhiteSpace($UserId)) {
        return [pscustomobject]@{
            UserId = $UserId
            DisplayName = $null
            UserPrincipalName = $null
            AccountEnabled = $null
            Status = "Missing"
        }
    }

    if (-not (Get-Command -Name Get-MgUser -ErrorAction SilentlyContinue)) {
        return [pscustomobject]@{
            UserId = $UserId
            DisplayName = $null
            UserPrincipalName = $null
            AccountEnabled = $null
            Status = "GraphUnavailable"
        }
    }

    try {
        $user = Get-MgUser -UserId $UserId -Property Id,DisplayName,UserPrincipalName,AccountEnabled -ErrorAction Stop
        return [pscustomobject]@{
            UserId = $user.Id
            DisplayName = $user.DisplayName
            UserPrincipalName = $user.UserPrincipalName
            AccountEnabled = $user.AccountEnabled
            Status = if ($user.AccountEnabled -eq $false) { "Disabled" } else { "Resolved" }
        }
    }
    catch {
        return [pscustomobject]@{
            UserId = $UserId
            DisplayName = $null
            UserPrincipalName = $null
            AccountEnabled = $null
            Status = "NotFound"
        }
    }
}

function New-PortfolioSafeWarning {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Message
    )

    return [pscustomobject]@{
        timestamp = (Get-Date).ToString("o")
        warning = $Message
    }
}
