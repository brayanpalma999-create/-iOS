$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Split-Path -Parent $scriptDir

Set-Location $projectRoot

$apkOutputDir = Join-Path $projectRoot "build\app\outputs\flutter-apk"
$distDir = Join-Path $projectRoot "dist\android"

Write-Host "Cleaning previous APK artifacts..."
if (Test-Path $apkOutputDir) {
    Get-ChildItem -Path $apkOutputDir -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Extension -eq ".apk" -or $_.Extension -eq ".sha1" } |
        Remove-Item -Force -ErrorAction SilentlyContinue
}

Write-Host "Running flutter clean..."
flutter clean

Write-Host "Resolving packages..."
flutter pub get

Write-Host "Building release APK..."
flutter build apk --release

$releaseApk = Join-Path $apkOutputDir "app-release.apk"
if (-not (Test-Path $releaseApk)) {
    throw "Build finished but APK was not found at: $releaseApk"
}

Write-Host "Refreshing dist folder..."
if (Test-Path $distDir) {
    Get-ChildItem -Path $distDir -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Extension -eq ".apk" } |
        Remove-Item -Force -ErrorAction SilentlyContinue
} else {
    New-Item -ItemType Directory -Path $distDir | Out-Null
}

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$finalApk = Join-Path $distDir ("AtoB-android-release-" + $timestamp + ".apk")
Copy-Item -Path $releaseApk -Destination $finalApk -Force

Write-Host ""
Write-Host "APK READY:"
Write-Host $finalApk
