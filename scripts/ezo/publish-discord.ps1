[CmdletBinding()]
param(
    [string] $WebhookUrl,
    [string] $Username = "EZO Addons",
    [string] $Content,
    [string] $Title,
    [string] $Description,
    [int] $Color = 3447295,
    [string] $FilePath,
    [switch] $DryRun
)

$ErrorActionPreference = "Stop"

if (-not $DryRun -and [string]::IsNullOrWhiteSpace($WebhookUrl)) {
    throw "WebhookUrl is required unless -DryRun is used."
}

if ($FilePath -and -not (Test-Path -LiteralPath $FilePath)) {
    throw "Attachment not found: $FilePath"
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
