$env:JAVA_HOME = "C:\Program Files\Java\jdk-17"
$env:PATH = "C:\flutter\bin;$env:JAVA_HOME\bin;$env:LOCALAPPDATA\Android\Sdk\platform-tools;$env:PATH"

flutter build apk --release

$src = "build\app\outputs\flutter-apk\app-release.apk"
$dst = "build\app\outputs\flutter-apk\glimpse.apk"

if (Test-Path $src) {
    Copy-Item $src $dst -Force
    Write-Host "Output: $dst"
}
