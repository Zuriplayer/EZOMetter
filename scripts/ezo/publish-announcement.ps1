[CmdletBinding()]
param(
    [string] $ConfigPath,
    [string] $WebhookUrl = $env:EZO_CODEX_ANNOUNCER,
    [string] $ExpectedChannelId = $env:EZO_CODEX_ANNOUNCER_CHANNEL_ID,
    [string] $Note = "Addon update available.",
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
    ""
    $Note
) -join "`n"

& $publishDiscord `
    -WebhookUrl $WebhookUrl `
    -Title "Announcement: $($addon.name) v$($addon.version)" `
    -Description $description `
    -Color 15844367 `
    -ExpectedChannelId $ExpectedChannelId `
    -ChannelName "announcements" `
    -DryRun:$DryRun
