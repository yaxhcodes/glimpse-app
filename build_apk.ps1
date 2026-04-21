# ─── Glimpse Release Build ─────────────────────────────────────────────
# Usage (direct Google / Voyage):
#   .\build_apk.ps1 -GeminiKey "YOUR_KEY" -VoyageKey "YOUR_KEY" `
#     -RevenueCatAndroidKey "goog_xxx"
#
# Usage (Cloudflare Worker proxy — GEMINI_KEY / Voyage key can be empty):
#   .\build_apk.ps1 -GeminiKey "" -VoyageKey "" `
#     -ProxyDevSecret "YOUR_DEV_SECRET" -ProxyUserId "user-123" `
#     -RevenueCatAndroidKey "goog_xxx"
#
# The RevenueCat entitlement id ("Glimpse Pro") is hardcoded in
# lib/core/services/subscription_service.dart — it never changes per
# build, and passing it through PowerShell --dart-define was a source of
# quote-injection bugs (e.g. the literal string ended up as
# `"Glimpse Pro"` at runtime and silently missed the real key).
#
# API keys are injected at build time via --dart-define and are NOT
# stored in source code.
param(
    [string]$GeminiKey = "",
    [string]$VoyageKey = "",
    [string]$ProxyDevSecret = "",
    [string]$ProxyUserId = "",
    [string]$ProxyBaseUrl = "",
    [string]$RevenueCatAndroidKey = "",
    [string]$RevenueCatIosKey = ""
)

$env:JAVA_HOME = "C:\Program Files\Java\jdk-17"
$env:PATH = "C:\flutter\bin;$env:JAVA_HOME\bin;$env:LOCALAPPDATA\Android\Sdk\platform-tools;$env:PATH"

$defines = @(
    "--dart-define=GEMINI_KEY=$GeminiKey",
    "--dart-define=VOYAGE_KEY=$VoyageKey"
)
if ($ProxyDevSecret -ne "") { $defines += "--dart-define=AI_PROXY_DEV_SECRET=$ProxyDevSecret" }
if ($ProxyUserId -ne "") { $defines += "--dart-define=AI_PROXY_USER_ID=$ProxyUserId" }
if ($ProxyBaseUrl -ne "") { $defines += "--dart-define=AI_PROXY_BASE_URL=$ProxyBaseUrl" }
if ($RevenueCatAndroidKey -ne "") { $defines += "--dart-define=REVENUECAT_ANDROID_KEY=$RevenueCatAndroidKey" }
if ($RevenueCatIosKey -ne "") { $defines += "--dart-define=REVENUECAT_IOS_KEY=$RevenueCatIosKey" }

Write-Host "Building (entitlement id is hardcoded in subscription_service.dart)"

flutter build apk --release @defines

$src = "build\app\outputs\flutter-apk\app-release.apk"
$dst = "build\app\outputs\flutter-apk\glimpse.apk"

if (Test-Path $src) {
    Copy-Item $src $dst -Force
    Write-Host "Output: $dst"
}
