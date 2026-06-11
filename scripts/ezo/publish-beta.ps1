[CmdletBinding()]
param(
    [string] $ConfigPath,
    [string] $WebhookUrl = $env:EZO_CODEX_BETA_BUILDS,
    [string] $Note = "Clean beta build generated from GitHub Actions.",
    [switch] $DryRun,
    [switch] $Force
)

$ErrorActionPreference = "Stop"

$repoRoot = (Get-Item -LiteralPath (Join-Path $PSScriptRoot "..\..")).FullName
if (-not $ConfigPath) {
    $ConfigPath = Join-Path $repoRoot "ezo-addon.json"
}

$config = Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Json
$addon = $config.addon
$buildScript = Join-Path $PSScriptRoot "build-addon-package.ps1"
$publishDiscord = Join-Path $PSScriptRoot "publish-discord.ps1"

$buildJson = & $buildScript -ConfigPath $ConfigPath -Force:$Force | ConvertFrom-Json
$zipPath = $buildJson.ZipPath

$description = @(
    "**Addon:** $($addon.name)"
    "**Version:** $($addon.version)"
    "**Build type:** beta"
    "**Runtime files:** $($buildJson.FileCount)"
    ""
    $Note
) -join "`n"

& $publishDiscord `
    -WebhookUrl $WebhookUrl `
    -Title "Beta build: $($addon.name) v$($addon.version)" `
    -Description $description `
    -Color 16753920 `
    -FilePath $zipPath `
    -DryRun:$DryRun
