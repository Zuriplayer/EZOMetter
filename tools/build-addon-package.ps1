[CmdletBinding()]
param(
    [switch] $Force
)

$ErrorActionPreference = "Stop"

& (Join-Path $PSScriptRoot "..\scripts\ezo\build-addon-package.ps1") -Force:$Force
