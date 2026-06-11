[CmdletBinding()]
param(
    [string] $ConfigPath,
    [string] $WebhookUrl = $env:EZO_CODEX_STATUS,
    [string] $CodexLogWebhookUrl = $env:CODEX_LOG,
    [switch] $PublishCodexLog,
    [switch] $DryRun
)

$ErrorActionPreference = "Stop"

$repoRoot = (Get-Item -LiteralPath (Join-Path $PSScriptRoot "..\..")).FullName
if (-not $ConfigPath) {
    $ConfigPath = Join-Path $repoRoot "ezo-addon.json"
}

$config = Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Json
$addon = $config.addon
$publishDiscord = Join-Path $PSScriptRoot "publish-discord.ps1"

$description = @(
    "**Addon:** $($addon.name)"
    "**Version:** $($addon.version)"
    "**Status:** $($addon.status)"
    "**Phase:** $($addon.phase)"
    "**Visibility:** $($addon.visibility)"
    "**Manifest:** $($addon.manifest)"
) -join "`n"

& $publishDiscord `
    -WebhookUrl $WebhookUrl `
    -Title "EZO addon status: $($addon.name)" `
    -Description $description `
    -Color 3447295 `
    -DryRun:$DryRun

if ($PublishCodexLog) {
    & $publishDiscord `
        -WebhookUrl $CodexLogWebhookUrl `
        -Title "Codex log: status published for $($addon.name)" `
        -Description $description `
        -Color 10181046 `
        -DryRun:$DryRun
}
