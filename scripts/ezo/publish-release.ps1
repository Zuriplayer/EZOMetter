[CmdletBinding()]
param(
    [string] $ConfigPath,
    [string] $ReleaseWebhookUrl = $env:EZO_CODEX_RELEASES,
    [string] $DownloadWebhookUrl = $env:EZO_CODEX_DOWNLOADS,
    [string] $AnnouncementWebhookUrl = $env:EZO_CODEX_ANNOUNCER,
    [string] $CodexLogWebhookUrl = $env:CODEX_LOG,
    [string] $Note = "Release prepared from GitHub Actions.",
    [string] $AnnouncementNote,
    [switch] $PublishDownload,
    [switch] $PublishAnnouncement,
    [switch] $PublishCodexLog,
    [switch] $AttachPackageToRelease,
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
$publishDiscord = Join-Path $PSScriptRoot "publish-discord.ps1"
$zipPath = $null

if ($AttachPackageToRelease) {
    $buildScript = Join-Path $PSScriptRoot "build-addon-package.ps1"
    $buildJson = & $buildScript -ConfigPath $ConfigPath -Force:$Force | ConvertFrom-Json
    $zipPath = $buildJson.ZipPath
}

$description = @(
    "**Addon:** $($addon.name)"
    "**Version:** $($addon.version)"
    "**Status:** $($addon.status)"
    ""
    $Note
) -join "`n"

& $publishDiscord `
    -WebhookUrl $ReleaseWebhookUrl `
    -Title "Release note: $($addon.name) v$($addon.version)" `
    -Description $description `
    -Color 5763719 `
    -FilePath $zipPath `
    -DryRun:$DryRun

if ($PublishDownload) {
    $downloadScript = Join-Path $PSScriptRoot "publish-download.ps1"
    & $downloadScript -ConfigPath $ConfigPath -WebhookUrl $DownloadWebhookUrl -Note $Note -DryRun:$DryRun -Force:$Force
}

if ($PublishAnnouncement) {
    $announcementScript = Join-Path $PSScriptRoot "publish-announcement.ps1"
    $effectiveAnnouncementNote = if ([string]::IsNullOrWhiteSpace($AnnouncementNote)) { $Note } else { $AnnouncementNote }
    & $announcementScript -ConfigPath $ConfigPath -WebhookUrl $AnnouncementWebhookUrl -Note $effectiveAnnouncementNote -DryRun:$DryRun
}

if ($PublishCodexLog) {
    $codexLogScript = Join-Path $PSScriptRoot "publish-codex-log.ps1"
    & $codexLogScript -ConfigPath $ConfigPath -WebhookUrl $CodexLogWebhookUrl -Action "Release workflow completed" -Note $Note -DryRun:$DryRun
}
