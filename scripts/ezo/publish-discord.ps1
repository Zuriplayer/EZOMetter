[CmdletBinding()]
param(
    [string] $WebhookUrl,
    [string] $Username = "EZO Addons",
    [string] $Content,
    [string] $Title,
    [string] $Description,
    [int] $Color = 3447295,
    [string] $FilePath,
    [string] $ExpectedChannelId,
    [string] $ChannelName,
    [switch] $DryRun
)

$ErrorActionPreference = "Stop"

if (-not $DryRun -and [string]::IsNullOrWhiteSpace($WebhookUrl)) {
    throw "WebhookUrl is required unless -DryRun is used."
}

if ($FilePath -and -not (Test-Path -LiteralPath $FilePath)) {
    throw "Attachment not found: $FilePath"
}

if (-not [string]::IsNullOrWhiteSpace($ExpectedChannelId)) {
    if ([string]::IsNullOrWhiteSpace($WebhookUrl)) {
        throw "WebhookUrl is required to verify Discord channel '$ChannelName'."
    }

    $webhookInfoUri = $WebhookUrl -replace "\?.*$", ""
    $webhookInfo = Invoke-RestMethod -Uri $webhookInfoUri -Method Get
    $actualChannelId = [string] $webhookInfo.channel_id
    if ($actualChannelId -ne $ExpectedChannelId) {
        $label = if ($ChannelName) { $ChannelName } else { "configured Discord channel" }
        throw "Discord webhook channel mismatch for $label. Expected channel_id=$ExpectedChannelId but webhook resolves to channel_id=$actualChannelId."
    }
}

$embed = [ordered]@{}
if ($Title) {
    $embed.title = $Title
}
if ($Description) {
    $embed.description = $Description
}
$embed.color = $Color
$embed.timestamp = (Get-Date).ToUniversalTime().ToString("o")

$payload = [ordered]@{
    username = $Username
    embeds = @($embed)
}

if ($Content) {
    $payload.content = $Content
}

$payloadJson = $payload | ConvertTo-Json -Depth 10

if ($DryRun) {
    Write-Host "DRY RUN: Discord payload"
    Write-Host $payloadJson
    if ($FilePath) {
        Write-Host "DRY RUN: attachment=$FilePath"
    }
    return
}

if ($FilePath) {
    $form = @{
        payload_json = $payloadJson
        file1 = Get-Item -LiteralPath $FilePath
    }
    Invoke-RestMethod -Uri $WebhookUrl -Method Post -Form $form | Out-Null
}
else {
    Invoke-RestMethod -Uri $WebhookUrl -Method Post -ContentType "application/json" -Body $payloadJson | Out-Null
}
