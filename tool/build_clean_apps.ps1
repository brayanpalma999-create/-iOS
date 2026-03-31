param(
  [string]$ProjectRoot = "C:\Users\braya\OneDrive\Escritorio\flutter projects\atob_app",
  [string]$AppsDir = "C:\Users\braya\OneDrive\Escritorio\APPS"
)

$ErrorActionPreference = "Stop"

Set-Location -LiteralPath $ProjectRoot

if (!(Test-Path -LiteralPath $AppsDir)) {
  New-Item -ItemType Directory -Path $AppsDir | Out-Null
}

Write-Host "Cleaning old Android/iOS artifacts..."
if (Test-Path -LiteralPath "build\app\outputs\flutter-apk") {
  Get-ChildItem -Path "build\app\outputs\flutter-apk" -File -ErrorAction SilentlyContinue |
    Where-Object { $_.Extension -eq ".apk" -or $_.Extension -eq ".sha1" } |
    Remove-Item -Force -ErrorAction SilentlyContinue
}
Get-ChildItem -Path $AppsDir -File -ErrorAction SilentlyContinue |
  Where-Object { $_.Extension -eq ".apk" -or $_.Extension -eq ".ipa" } |
  Remove-Item -Force -ErrorAction SilentlyContinue

if (Test-Path -LiteralPath "dist\ios") {
  Get-ChildItem -Path "dist\ios" -Filter "*.ipa" -File -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending |
    Select-Object -Skip 1 |
    Remove-Item -Force -ErrorAction SilentlyContinue
}

Write-Host "Building Android release APK..."
flutter build apk --release

$apkSrc = "build\app\outputs\flutter-apk\app-release.apk"
if (!(Test-Path -LiteralPath $apkSrc)) {
  throw "Release APK was not generated."
}

$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$apkDst = Join-Path $AppsDir "AtoB-android-release-$stamp.apk"
Copy-Item -LiteralPath $apkSrc -Destination $apkDst -Force
Copy-Item -LiteralPath $apkSrc -Destination (Join-Path $AppsDir "AtoB-android-release-latest.apk") -Force

$iphoneConnected = $false
try {
  $iphone = Get-PnpDevice -PresentOnly | Where-Object {
    $_.FriendlyName -match "Apple iPhone|Apple Mobile Device|iPhone"
  }
  $iphoneConnected = $null -ne $iphone
} catch {
  $iphoneConnected = $false
}

$latestIpa = $null
if (Test-Path -LiteralPath "dist\ios") {
  $latestIpa = Get-ChildItem -Path "dist\ios" -Filter "*.ipa" -File -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1
}

if ($latestIpa -ne $null) {
  $ipaDst = Join-Path $AppsDir "AtoB-ios-unsigned-$stamp.ipa"
  Copy-Item -LiteralPath $latestIpa.FullName -Destination $ipaDst -Force
  Copy-Item -LiteralPath $latestIpa.FullName -Destination (Join-Path $AppsDir "AtoB-ios-unsigned-latest.ipa") -Force
  Write-Host "IPA copied from local dist: $($latestIpa.FullName)"
} else {
  Write-Warning "No local IPA found in dist\\ios. Trigger iOS workflow and then place IPA in APPS."
}

if (-not $iphoneConnected) {
  Write-Host "iPhone not detected. APK/IPA were staged in Desktop\\APPS."
} else {
  Write-Host "iPhone detected. APK/IPA were staged in Desktop\\APPS."
}

Write-Host "Done."
