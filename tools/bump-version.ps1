param(
    [string] $Version,

    [int] $AddOnVersion,

    [switch] $Patch,

    [switch] $Check,

    [string] $ApiVersion
)

$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot "..")).ProviderPath
$utf8 = New-Object System.Text.UTF8Encoding($false)

function Read-Text {
    param([Parameter(Mandatory = $true)][string] $Path)
    return [System.IO.File]::ReadAllText($Path, $utf8)
}

function Write-Text {
    param(
        [Parameter(Mandatory = $true)][string] $Path,
        [Parameter(Mandatory = $true)][string] $Content
    )
    [System.IO.File]::WriteAllText($Path, $Content, $utf8)
}

function Get-RegexValue {
    param(
        [Parameter(Mandatory = $true)][string] $Content,
        [Parameter(Mandatory = $true)][string] $Pattern,
        [int] $Group = 1
    )
    $match = [regex]::Match($Content, $Pattern, [System.Text.RegularExpressions.RegexOptions]::Multiline)
    if (-not $match.Success) {
        return $null
    }
    return $match.Groups[$Group].Value
}

function Set-RegexValue {
    param(
        [Parameter(Mandatory = $true)][string] $Content,
        [Parameter(Mandatory = $true)][string] $Pattern,
        [Parameter(Mandatory = $true)][string] $Value
    )
    return [regex]::Replace($Content, $Pattern, {
        param($match)
        return $match.Groups[1].Value + $Value + $match.Groups[2].Value
    }, [System.Text.RegularExpressions.RegexOptions]::Multiline)
}

function Increment-PatchVersion {
    param([Parameter(Mandatory = $true)][string] $CurrentVersion)
    $parts = $CurrentVersion.Split(".")
    if ($parts.Count -ne 3) {
        throw "Cannot patch-bump non-semver version '$CurrentVersion'. Pass -Version explicitly."
    }
    $patchNumber = 0
    if (-not [int]::TryParse($parts[2], [ref]$patchNumber)) {
        throw "Cannot patch-bump version '$CurrentVersion'. Pass -Version explicitly."
    }
    return "$($parts[0]).$($parts[1]).$($patchNumber + 1)"
}

function Get-ApiVersionTokens {
    param([string] $Value)
    if (-not $Value) {
        return @()
    }
    return @($Value -split '\s+' | Where-Object { $_ })
}

function Test-ApiVersionList {
    param(
        [Parameter(Mandatory = $true)][string[]] $Tokens,
        [Parameter(Mandatory = $true)][string] $Label
    )
    if ($Tokens.Count -eq 0) {
        throw "$Label must contain at least one API version."
    }
    if ($Tokens.Count -gt 2) {
        throw "$Label contains $($Tokens.Count) API versions. ESO only honors the first 2 entries."
    }
    foreach ($token in $Tokens) {
        if ($token -notmatch '^\d+$') {
            throw "$Label contains invalid API version '$token'."
        }
    }
}

$manifest = Join-Path $root "EZOMetter.txt"
$core = Join-Path $root "modules\core.lua"
$config = Join-Path $root "ezo-addon.json"

if (-not (Test-Path -LiteralPath $manifest)) {
    throw "Manifest not found: $manifest"
}
if (-not (Test-Path -LiteralPath $core)) {
    throw "Core version file not found: $core"
}
if (-not (Test-Path -LiteralPath $config)) {
    throw "Addon config not found: $config"
}

$manifestText = Read-Text $manifest
$coreText = Read-Text $core
$configText = Read-Text $config

$manifestVersion = Get-RegexValue $manifestText '^## Version:\s*(.+?)\s*$'
$manifestAddOnVersion = Get-RegexValue $manifestText '^## AddOnVersion:\s*(\d+)\s*$'
$manifestApiVersion = Get-RegexValue $manifestText '^## APIVersion:\s*(.+?)\s*$'
$coreVersion = Get-RegexValue $coreText '^\s*EZOMetter\.ADDON_VERSION\s*=\s*"([^"]+)"\s*$'
$configVersion = Get-RegexValue $configText '"version":\s*"([^"]+)"'

if ($Check) {
    $ok = $true
    if ($manifestVersion -ne $coreVersion) {
        Write-Error "Version mismatch: EZOMetter.txt=$manifestVersion modules/core.lua=$coreVersion"
        $ok = $false
    }
    if ($manifestVersion -ne $configVersion) {
        Write-Error "Version mismatch: EZOMetter.txt=$manifestVersion ezo-addon.json=$configVersion"
        $ok = $false
    }
    if (-not $manifestAddOnVersion) {
        Write-Error "Missing ## AddOnVersion in EZOMetter.txt"
        $ok = $false
    }
    $manifestApiTokens = Get-ApiVersionTokens $manifestApiVersion
    try {
        Test-ApiVersionList $manifestApiTokens "## APIVersion"
    } catch {
        Write-Error $_
        $ok = $false
    }
    if ($ApiVersion) {
        $expectedApiTokens = Get-ApiVersionTokens $ApiVersion
        try {
            Test-ApiVersionList $expectedApiTokens "-ApiVersion"
            foreach ($expectedApiToken in $expectedApiTokens) {
                if ($manifestApiTokens -notcontains $expectedApiToken) {
                    Write-Error "APIVersion mismatch: EZOMetter.txt='$manifestApiVersion' does not include expected API '$expectedApiToken'"
                    $ok = $false
                }
            }
        } catch {
            Write-Error $_
            $ok = $false
        }
    }
    if (-not $ok) {
        exit 1
    }
    if ($ApiVersion) {
        Write-Host "Version check OK: $manifestVersion / AddOnVersion $manifestAddOnVersion / APIVersion $manifestApiVersion"
    } else {
        Write-Host "Version check OK: $manifestVersion / AddOnVersion $manifestAddOnVersion / APIVersion $manifestApiVersion"
        Write-Host "Pass -ApiVersion <GetAPIVersion()> to verify the AddOns screen out-of-date flag against a known client API."
    }
    exit 0
}

if ($Patch) {
    if ($Version) {
        throw "Use either -Patch or -Version, not both."
    }
    $Version = Increment-PatchVersion $manifestVersion
}

if (-not $Version) {
    throw "Pass -Version <x.y.z>, or use -Patch, or use -Check."
}

if ($manifestVersion -ne $coreVersion) {
    throw "Refusing to bump from inconsistent state: EZOMetter.txt=$manifestVersion modules/core.lua=$coreVersion"
}
if ($manifestVersion -ne $configVersion) {
    throw "Refusing to bump from inconsistent state: EZOMetter.txt=$manifestVersion ezo-addon.json=$configVersion"
}

if (-not $PSBoundParameters.ContainsKey("AddOnVersion")) {
    $currentAddOnVersion = 0
    if (-not [int]::TryParse($manifestAddOnVersion, [ref]$currentAddOnVersion)) {
        throw "Cannot read current ## AddOnVersion. Pass -AddOnVersion explicitly."
    }
    $AddOnVersion = $currentAddOnVersion + 1
}

$manifestText = Set-RegexValue $manifestText '^(## Version:\s*).+?(\s*)$' $Version
$manifestText = Set-RegexValue $manifestText '^(## AddOnVersion:\s*)\d+(\s*)$' ([string]$AddOnVersion)
if ($ApiVersion) {
    $apiTokens = Get-ApiVersionTokens $ApiVersion
    Test-ApiVersionList $apiTokens "-ApiVersion"
    $manifestText = Set-RegexValue $manifestText '^(## APIVersion:\s*).+?(\s*)$' $ApiVersion
}
Write-Text $manifest $manifestText

$coreText = Set-RegexValue $coreText '^(\s*EZOMetter\.ADDON_VERSION\s*=\s*")[^"]+("\s*)$' $Version
Write-Text $core $coreText

$configText = Set-RegexValue $configText '^(\s*"version":\s*")[^"]+(",?\s*)$' $Version
$configText = Set-RegexValue $configText '^(\s*"zipName":\s*"EZOMetter_v)[^"]+(\.zip",?\s*)$' $Version
Write-Text $config $configText

Write-Host "Version updated to $Version / AddOnVersion $AddOnVersion"
if ($ApiVersion) {
    Write-Host "APIVersion updated to $ApiVersion"
} else {
    Write-Host "APIVersion unchanged: $manifestApiVersion"
}
Write-Host "Review with: git diff --check; git diff"
