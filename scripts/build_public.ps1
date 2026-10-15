# TEMPO — Public Release Build Script
$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "    TEMPO -- Building PUBLIC Release     " -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

$flutter = "C:\src\flutter\bin\flutter.bat"

# 1. Clean previous generated assets
Write-Host "`nStep 1/5: Preparing public seed assets..." -ForegroundColor Yellow
if (Test-Path "assets/seed.json") {
    Remove-Item "assets/seed.json" -Force
}
Copy-Item "config/seeds/public.json" -Destination "assets/seed.json" -Force

# 2. Run Privacy Audit Verification
Write-Host "Step 2/5: Running privacy verification..." -ForegroundColor Yellow
& powershell -ExecutionPolicy Bypass -File scripts/verify_privacy.ps1
if ($LASTEXITCODE -ne 0) {
    Write-Host "Build aborted due to privacy failure!" -ForegroundColor Red
    exit 1
}

# 3. Flutter Pub Get
Write-Host "Step 3/5: Resolving dependencies..." -ForegroundColor Yellow
& $flutter pub get

# 4. Build Public APK
Write-Host "Step 4/5: Deriving release APK (Flavor: public)..." -ForegroundColor Yellow
& $flutter build apk --flavor public -t lib/main.dart --release

if ($LASTEXITCODE -ne 0) {
    Write-Host "Flutter build failed!" -ForegroundColor Red
    exit 1
}

# 5. Deliver Named Artifact
Write-Host "Step 5/5: Packaging release output..." -ForegroundColor Yellow
$sourceApk = "build/app/outputs/flutter-apk/app-public-release.apk"
$targetApk = "build/app/outputs/flutter-apk/TEMPO-Public-release.apk"

if (Test-Path $sourceApk) {
    Copy-Item $sourceApk -Destination $targetApk -Force
    $fileInfo = Get-Item $targetApk
    $sizeMB = [math]::Round($fileInfo.Length / 1MB, 2)
    Write-Host "`n>>> SUCCESS! Public APK ready:" -ForegroundColor Green
    Write-Host "    Path: $targetApk" -ForegroundColor Green
    Write-Host "    Size: $sizeMB MB" -ForegroundColor Green
} else {
    Write-Host "Could not locate generated APK at $sourceApk" -ForegroundColor Red
    exit 1
}
