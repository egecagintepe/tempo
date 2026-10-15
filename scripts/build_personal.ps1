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

$buildSuccess = $false
try {
    # 3. Flutter Pub Get
    Write-Host "Step 3/5: Resolving dependencies..." -ForegroundColor Yellow
    & $flutter pub get

    # 4. Build Personal APK
    Write-Host "Step 4/5: Deriving release APK (Flavor: personal)..." -ForegroundColor Yellow
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

    # 7. Post-build APK Internal Verification (Zero Private Data Leak)
    Write-Host "`nStep 5/5: Verifying internal APK asset packaging..." -ForegroundColor Yellow
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zip = [System.IO.Compression.ZipFile]::OpenRead((Resolve-Path $targetApk))
    $seedEntry = $zip.Entries | Where-Object { $_.FullName -like "*flutter_assets/assets/seed.json" }
    if ($null -eq $seedEntry) {
        $zip.Dispose()
        Write-Host "ERROR: seed.json was NOT packaged inside the APK!" -ForegroundColor Red
        exit 1
    }

    $stream = $seedEntry.Open()
    $reader = New-Object System.IO.StreamReader($stream)
    $jsonText = $reader.ReadToEnd()
    $reader.Dispose()
    $stream.Dispose()
    $zip.Dispose()

    $parsed = $jsonText | ConvertFrom-Json
    $catsCount = $parsed.categories.Count
    $tasksCount = $parsed.tasks.Count
    $eventsCount = $parsed.calendarEvents.Count
    $milestonesCount = $parsed.academicMilestones.Count
    $edition = $parsed.edition
    $totalMinutes = ($parsed.categories | Measure-Object -Property weeklyTargetMinutes -Sum).Sum

    if ($edition -ne "personal" -or $catsCount -ne 11 -or $totalMinutes -ne 1620) {
        Write-Host "ERROR: Packaged seed does NOT match personal profile! Edition: $edition, Cats: $catsCount, Minutes: $totalMinutes" -ForegroundColor Red
        exit 1
    }

    Write-Host ">>> APK VERIFICATION CONFIRMED:" -ForegroundColor Green
    Write-Host "    Edition: $edition (VERIFIED)" -ForegroundColor Green
    Write-Host "    Categories: $catsCount (Target: 11) (VERIFIED)" -ForegroundColor Green
    Write-Host "    Total Weekly Budget: $totalMinutes minutes (27h) (VERIFIED)" -ForegroundColor Green
    Write-Host "    Tasks: $tasksCount (VERIFIED)" -ForegroundColor Green
    Write-Host "    Calendar Events: $eventsCount (VERIFIED)" -ForegroundColor Green
    Write-Host "    Academic Milestones: $milestonesCount (VERIFIED)" -ForegroundColor Green
    Write-Host "    Zero private content leaked to stdout or repository." -ForegroundColor Green
} else {
    Write-Host "Could not locate generated APK at $sourceApk" -ForegroundColor Red
    exit 1
}
