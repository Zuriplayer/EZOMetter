[CmdletBinding()]
param(
    [string] $ConfigPath,
    [string] $WebhookUrl = $env:CODEX_LOG,
    [string] $ExpectedChannelId = $env:CODEX_LOG_CHANNEL_ID,
    [string] $Action = "Automation event",
    [string] $Note = "",
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
    "**Action:** $Action"
    "**Status:** $($addon.status)"
    ""
    $Note
) -join "`n"

& $publishDiscord `
    -WebhookUrl $WebhookUrl `
    -Title "Codex log: $($addon.name)" `
    -Description $description `
    -Color 10181046 `
    -ExpectedChannelId $ExpectedChannelId `
    -ChannelName "codex-log" `
    -DryRun:$DryRun
