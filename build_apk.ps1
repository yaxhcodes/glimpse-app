# ─── Glimpse Release Build ─────────────────────────────────────────────
# Usage:
#   .\build_apk.ps1 `
#     -ProxyBaseUrl "https://glimpse-proxy.glimpse.workers.dev" `
#     -RevenueCatAndroidKey "goog_xxx"
#
# AI_PROXY_USER_ID is no longer needed — the app generates and persists a
# per-install UUID at runtime (see ai_user_id_service.dart).
#
# The RevenueCat entitlement id ("Glimpse Pro") is hardcoded in
# lib/core/services/subscription_service.dart — it never changes per
# build, and passing it through PowerShell --dart-define was a source of
# quote-injection bugs (e.g. the literal string ended up as
# `"Glimpse Pro"` at runtime and silently missed the real key).
#
# AI provider keys are never injected into the Flutter app. Gemini and
# embedding requests go through the Cloudflare Worker proxy.
param(
    [string]$ProxyBaseUrl = "",
    [string]$RevenueCatAndroidKey = "",
    [string]$RevenueCatIosKey = ""
)

$env:JAVA_HOME = "C:\Program Files\Java\jdk-17"
$env:PATH = "C:\flutter\bin;$env:JAVA_HOME\bin;$env:LOCALAPPDATA\Android\Sdk\platform-tools;$env:PATH"

$defines = @()
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
