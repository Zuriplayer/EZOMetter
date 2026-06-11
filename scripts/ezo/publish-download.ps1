[CmdletBinding()]
param(
    [string] $ConfigPath,
    [string] $WebhookUrl = $env:EZO_CODEX_DOWNLOADS,
    [string] $Note = "Clean addon ZIP attached.",
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
    "**Package:** $([System.IO.Path]::GetFileName($zipPath))"
    "**Runtime files:** $($buildJson.FileCount)"
    ""
    $Note
) -join "`n"

& $publishDiscord `
    -WebhookUrl $WebhookUrl `
    -Title "Download: $($addon.name) v$($addon.version)" `
    -Description $description `
    -Color 3066993 `
    -FilePath $zipPath `
    -DryRun:$DryRun
