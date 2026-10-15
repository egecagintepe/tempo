# TEMPO — Personal Edition Build Script
$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Magenta
Write-Host "    TEMPO -- Building PERSONAL Edition   " -ForegroundColor Magenta
Write-Host "========================================" -ForegroundColor Magenta

$flutter = "C:\src\flutter\bin\flutter.bat"

# 1. Verify private profile configuration
Write-Host "`nStep 1/5: Verifying local personal profile..." -ForegroundColor Yellow
if (-not (Test-Path ".local/personal_profile.json")) {
    Write-Host "ERROR: .local/personal_profile.json not found! Cannot build personal edition." -ForegroundColor Red
    exit 1
}

# 2. Stage personal seed asset
Write-Host "Step 2/5: Staging private personal seed asset..." -ForegroundColor Yellow
Copy-Item ".local/personal_profile.json" -Destination "assets/seed.json" -Force

# 3. Flutter Pub Get
Write-Host "Step 3/5: Resolving dependencies..." -ForegroundColor Yellow
& $flutter pub get

# 4. Build Personal APK
Write-Host "Step 4/5: Deriving release APK (Flavor: personal)..." -ForegroundColor Yellow
$buildSuccess = $false
try {
    & $flutter build apk --flavor personal -t lib/main.dart --release
    $buildSuccess = ($LASTEXITCODE -eq 0)
} finally {
    # 5. Clean private seed from assets immediately to protect Git working directory
    Write-Host "`nCleanup: Restoring public seed into assets/seed.json..." -ForegroundColor Cyan
    Copy-Item "config/seeds/public.json" -Destination "assets/seed.json" -Force
}

if (-not $buildSuccess) {
    Write-Host "Personal Flutter build failed!" -ForegroundColor Red
    exit 1
}

# 6. Deliver Named Artifact
$sourceApk = "build/app/outputs/flutter-apk/app-personal-release.apk"
$targetApk = "build/app/outputs/flutter-apk/TEMPO-Personal-release.apk"

if (Test-Path $sourceApk) {
    Copy-Item $sourceApk -Destination $targetApk -Force
    Copy-Item $sourceApk -Destination "TEMPO-Personal-release.apk" -Force
    $fileInfo = Get-Item $targetApk
    $sizeMB = [math]::Round($fileInfo.Length / 1MB, 2)
    Write-Host "`n>>> SUCCESS! Personal APK ready:" -ForegroundColor Green
    Write-Host "    Path: $targetApk" -ForegroundColor Green
    Write-Host "    Root: TEMPO-Personal-release.apk" -ForegroundColor Green
    Write-Host "    Size: $sizeMB MB" -ForegroundColor Green
} else {
    Write-Host "Could not locate generated APK at $sourceApk" -ForegroundColor Red
    exit 1
}
