[CmdletBinding()]
param(
    [string] $ConfigPath,
    [switch] $Force
)

$ErrorActionPreference = "Stop"

function Get-RepoRoot {
    if ($PSScriptRoot) {
        return (Get-Item -LiteralPath (Join-Path $PSScriptRoot "..\..")).FullName
    }

    return (Get-Location).Path
}

function Normalize-RelativePath {
    param([string] $Path)
    return ($Path -replace "\\", "/").TrimStart("/")
}

function Test-RelativePathMatch {
    param(
        [string] $RelativePath,
        [string] $Pattern
    )

    $relative = Normalize-RelativePath $RelativePath
    $patternText = Normalize-RelativePath $Pattern

    if ($patternText.EndsWith("/**")) {
        $prefix = $patternText.Substring(0, $patternText.Length - 3).TrimEnd("/")
        return $relative -ieq $prefix -or $relative.StartsWith("$prefix/", [System.StringComparison]::OrdinalIgnoreCase)
    }

    $wildcard = [System.Management.Automation.WildcardPattern]::new(
        $patternText,
        [System.Management.Automation.WildcardOptions]::IgnoreCase
    )
    return $wildcard.IsMatch($relative)
}

function Test-Excluded {
    param(
        [string] $RelativePath,
        [object[]] $Patterns
    )

    foreach ($pattern in $Patterns) {
        if (Test-RelativePathMatch -RelativePath $RelativePath -Pattern ([string] $pattern)) {
            return $true
        }
    }

    return $false
}

function Get-IncludedFiles {
    param(
        [string] $RepoRoot,
        [object[]] $IncludePatterns,
        [object[]] $ExcludePatterns
    )

    $filesByPath = @{}

    foreach ($patternValue in $IncludePatterns) {
        $pattern = Normalize-RelativePath ([string] $patternValue)

        if ($pattern.EndsWith("/**")) {
            $directory = $pattern.Substring(0, $pattern.Length - 3).TrimEnd("/")
            $fullDirectory = Join-Path $RepoRoot ($directory -replace "/", [System.IO.Path]::DirectorySeparatorChar)

            if (Test-Path -LiteralPath $fullDirectory) {
                Get-ChildItem -LiteralPath $fullDirectory -Recurse -File | ForEach-Object {
                    $relative = Normalize-RelativePath ([System.IO.Path]::GetRelativePath($RepoRoot, $_.FullName))
                    if (-not (Test-Excluded -RelativePath $relative -Patterns $ExcludePatterns)) {
                        $filesByPath[$relative] = $_.FullName
                    }
                }
            }

            continue
        }

        if ($pattern -notmatch "/") {
            Get-ChildItem -LiteralPath $RepoRoot -File -Filter $pattern | ForEach-Object {
                $relative = Normalize-RelativePath ([System.IO.Path]::GetRelativePath($RepoRoot, $_.FullName))
                if (-not (Test-Excluded -RelativePath $relative -Patterns $ExcludePatterns)) {
                    $filesByPath[$relative] = $_.FullName
                }
            }

            continue
        }

        Get-ChildItem -LiteralPath $RepoRoot -Recurse -File | ForEach-Object {
            $relative = Normalize-RelativePath ([System.IO.Path]::GetRelativePath($RepoRoot, $_.FullName))
            if ((Test-RelativePathMatch -RelativePath $relative -Pattern $pattern) -and -not (Test-Excluded -RelativePath $relative -Patterns $ExcludePatterns)) {
                $filesByPath[$relative] = $_.FullName
            }
        }
    }

    return $filesByPath.GetEnumerator() | Sort-Object Name
}

$repoRoot = Get-RepoRoot
if (-not $ConfigPath) {
    $ConfigPath = Join-Path $repoRoot "ezo-addon.json"
}

$config = Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Json
$addon = $config.addon
$package = $addon.package

if (-not $addon.name -or -not $addon.manifest -or -not $package.rootFolderName -or -not $package.zipName) {
    throw "Invalid ezo-addon.json: addon.name, addon.manifest, package.rootFolderName and package.zipName are required."
}

$manifestPath = Join-Path $repoRoot $addon.manifest
if (-not (Test-Path -LiteralPath $manifestPath)) {
    throw "Manifest not found: $manifestPath"
}

$outputDirectory = Join-Path $repoRoot $package.outputPath
$zipPath = Join-Path $outputDirectory $package.zipName

if ((Test-Path -LiteralPath $zipPath) -and -not $Force) {
    throw "Package already exists: $zipPath. Use -Force to overwrite it."
}

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("ezo-addon-package-" + [System.Guid]::NewGuid().ToString("N"))
$stagingRoot = Join-Path $tempRoot $package.rootFolderName

New-Item -ItemType Directory -Path $stagingRoot -Force | Out-Null
New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null

try {
    $includedFiles = @(Get-IncludedFiles -RepoRoot $repoRoot -IncludePatterns $package.include -ExcludePatterns $package.exclude)

    if ($includedFiles.Count -eq 0) {
        throw "No runtime files matched package include rules."
    }

    foreach ($entry in $includedFiles) {
        $relative = Normalize-RelativePath $entry.Name
        $target = Join-Path $stagingRoot ($relative -replace "/", [System.IO.Path]::DirectorySeparatorChar)
        $targetDirectory = Split-Path -Parent $target

        if (-not (Test-Path -LiteralPath $targetDirectory)) {
            New-Item -ItemType Directory -Path $targetDirectory -Force | Out-Null
        }

        Copy-Item -LiteralPath $entry.Value -Destination $target -Force
    }

    if (Test-Path -LiteralPath $zipPath) {
        Remove-Item -LiteralPath $zipPath -Force
    }

    Compress-Archive -Path $stagingRoot -DestinationPath $zipPath -Force

    [pscustomobject]@{
        Addon = $addon.name
        Version = $addon.version
        ZipPath = $zipPath
        RootFolder = $package.rootFolderName
        FileCount = $includedFiles.Count
        Files = @($includedFiles | ForEach-Object { $_.Name })
    } | ConvertTo-Json -Depth 5
}
finally {
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force
    }
}
