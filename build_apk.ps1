# ─── Glimpse Release Build ─────────────────────────────────────────────
# Usage:
#   .\build_apk.ps1 -GeminiKey "YOUR_KEY" -VoyageKey "YOUR_KEY"
#
# API keys are injected at build time via --dart-define and are NOT
# stored in source code.
param(
    [Parameter(Mandatory=$true)]
    [string]$GeminiKey,

    [Parameter(Mandatory=$true)]
    [string]$VoyageKey
)

$env:JAVA_HOME = "C:\Program Files\Java\jdk-17"
$env:PATH = "C:\flutter\bin;$env:JAVA_HOME\bin;$env:LOCALAPPDATA\Android\Sdk\platform-tools;$env:PATH"

flutter build apk --release `
    --dart-define="GEMINI_KEY=$GeminiKey" `
    --dart-define="VOYAGE_KEY=$VoyageKey"

$src = "build\app\outputs\flutter-apk\app-release.apk"
$dst = "build\app\outputs\flutter-apk\glimpse.apk"

if (Test-Path $src) {
    Copy-Item $src $dst -Force
    Write-Host "Output: $dst"
}
