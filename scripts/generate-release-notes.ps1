<#
.SYNOPSIS
    DiscordStorage Release Notes Generator (PowerShell Wrapper)

.DESCRIPTION
    Generates RELEASE_<version>.md using either Google Gemini API or Antigravity CLI (agy).

.PARAMETER Engine
    'auto' (default), 'gemini', or 'agy'

.PARAMETER ApiKey
    Optional Gemini API key. If omitted, checks $env:GEMINI_API_KEY
    or C:\Users\kerem\Projects\imza-bilgileri\gemini.key.

.PARAMETER Version
    Optional version override (e.g. "0.5.0-beta"). Defaults to pubspec.yaml version.

.PARAMETER OpenFiles
    If set, opens the generated markdown file in your default editor.

.EXAMPLE
    .\scripts\generate-release-notes.ps1
    .\scripts\generate-release-notes.ps1 -Engine agy
    .\scripts\generate-release-notes.ps1 -Engine gemini -ApiKey "AIzaSy..."
#>

[CmdletBinding()]
param (
    [ValidateSet("auto", "gemini", "agy")]
    [string]$Engine = "auto",

    [string]$ApiKey = "",

    [string]$Version = "",

    [switch]$OpenFiles
)

$ErrorActionPreference = "Stop"

$scriptDir   = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Split-Path -Parent $scriptDir
$pyScript    = Join-Path $scriptDir "generate_release_notes.py"

if (-not (Test-Path $pyScript)) {
    throw "Script not found: $pyScript"
}

# Find python
$pythonCmd = Get-Command "python" -ErrorAction SilentlyContinue
if (-not $pythonCmd) {
    throw "Python 3 is required but was not found in PATH."
}

$argsList = @($pyScript, "--engine", $Engine)

if ($ApiKey) {
    $argsList += @("--api-key", $ApiKey)
}

if ($Version) {
    $argsList += @("--version", $Version)
}

Write-Host "Running release notes generator..." -ForegroundColor Cyan
& python $argsList

if ($LASTEXITCODE -ne 0) {
    Write-Error "Release notes generation failed with exit code $LASTEXITCODE"
    exit $LASTEXITCODE
}

# Extract current version to find generated file
$pubspecPath = Join-Path $projectRoot "pubspec.yaml"
$targetVer = $Version
if (-not $targetVer -and (Test-Path $pubspecPath)) {
    $m = Select-String -Path $pubspecPath -Pattern '^version:\s*([^\+\s]+)'
    if ($m) { $targetVer = $m.Matches[0].Groups[1].Value.Trim() }
}

if ($targetVer -and $OpenFiles) {
    $ghFile = Join-Path $projectRoot "RELEASE_$targetVer.md"

    if (Test-Path $ghFile) {
        Write-Host "Opening $ghFile..." -ForegroundColor Gray
        Start-Process $ghFile
    }
}
