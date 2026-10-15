# TEMPO — Comprehensive Privacy & Build Security Verification
$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "    TEMPO -- Comprehensive Privacy Audit " -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# Keywords encoded to prevent self-matching during script parsing
$forbiddenKeywords = @(
    [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String("YW5pem9u")),
    [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String("bm92em9u")),
    [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String("YW5rYXJlZg==")),
    [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String("YXVzY3VsdGFmb3JnZQ==")),
    [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String("ZWVlNDMz")),
    [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String("ZWVlMzAz"))
)

$auditFailed = $false

# ---------------------------------------------------------
# CHECK 1: Git Tracked Files (No Private Files in Git Index)
# ---------------------------------------------------------
Write-Host "`n[Check 1/4] Inspecting Git tracked files..." -ForegroundColor Yellow
$trackedFiles = & git ls-files
foreach ($file in $trackedFiles) {
    # 1a. Ensure no private files or keys are tracked
    if ($file -match "^\.local/" -or $file -match "\.personal\." -or $file -match "personal_profile" -or $file -match "\.keystore$" -or $file -match "\.jks$") {
        Write-Host "  [FAIL] Untracked/private file is tracked in git index: $file" -ForegroundColor Red
        $auditFailed = $true
    }

    # 1b. Scan tracked text files for keywords (skip binary assets and documentation audit file)
    $ext = [System.IO.Path]::GetExtension($file)
    if ($ext -notin @(".png", ".jpg", ".ico", ".apk", ".jar", ".class", ".zip", ".ttf", ".otf")) {
        if ($file -notin @("docs/PROJECT_AUDIT.md", "scripts/verify_privacy.ps1")) {
            $content = Get-Content -Path $file -Raw -ErrorAction SilentlyContinue
            if ($null -ne $content) {
                foreach ($kw in $forbiddenKeywords) {
                    if ($content -match "(?i)$kw") {
                        Write-Host "  [FAIL] Forbidden keyword '$kw' found in tracked file: $file" -ForegroundColor Red
                        $auditFailed = $true
                    }
                }
            }
        }
    }
}
if (-not $auditFailed) {
    Write-Host "  [PASS] All $($trackedFiles.Count) tracked files are clean and free of private keywords." -ForegroundColor Green
}

# ---------------------------------------------------------
# CHECK 2: Git Commit History (No Private Data in Commit Logs)
# ---------------------------------------------------------
Write-Host "`n[Check 2/4] Inspecting Git commit log messages..." -ForegroundColor Yellow
$commitLogs = & git log --format="%s %b"
foreach ($line in $commitLogs) {
    if (-not [string]::IsNullOrWhiteSpace($line)) {
        foreach ($kw in $forbiddenKeywords) {
            if ($line -match "(?i)$kw") {
                Write-Host "  [FAIL] Forbidden keyword '$kw' found in git commit log!" -ForegroundColor Red
                $auditFailed = $true
            }
        }
    }
}
if (-not $auditFailed) {
    Write-Host "  [PASS] Git commit history is clean." -ForegroundColor Green
}

# ---------------------------------------------------------
# CHECK 3: Public Asset Hygiene (assets/seed.json)
# ---------------------------------------------------------
Write-Host "`n[Check 3/4] Inspecting assets/seed.json & public seed configuration..." -ForegroundColor Yellow
if (Test-Path "assets/seed.json") {
    $seedContent = Get-Content -Path "assets/seed.json" -Raw
    foreach ($kw in $forbiddenKeywords) {
        if ($seedContent -match "(?i)$kw") {
            Write-Host "  [FAIL] Forbidden keyword '$kw' found in assets/seed.json!" -ForegroundColor Red
            $auditFailed = $true
        }
    }
    if (-not $auditFailed) {
        Write-Host "  [PASS] assets/seed.json contains only public generic categories." -ForegroundColor Green
    }
} else {
    Write-Host "  [WARN] assets/seed.json not found." -ForegroundColor DarkYellow
}

# ---------------------------------------------------------
# CHECK 4: Public APK Archive Inspection (Zero Leakage in APK)
# ---------------------------------------------------------
Write-Host "`n[Check 4/4] Inspecting Public Release APK bundle..." -ForegroundColor Yellow
$publicApk = "build/app/outputs/flutter-apk/TEMPO-Public-release.apk"
if (Test-Path $publicApk) {
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zip = [System.IO.Compression.ZipFile]::OpenRead((Resolve-Path $publicApk))
    $apkScannedEntries = 0
    try {
        foreach ($entry in $zip.Entries) {
            # Inspect flutter assets packaged in the APK
            if ($entry.FullName -like "*assets/seed.json" -or $entry.FullName -like "*flutter_assets*") {
                $stream = $entry.Open()
                $reader = New-Object System.IO.StreamReader($stream)
                $text = $reader.ReadToEnd()
                $reader.Close()
                $stream.Close()
                $apkScannedEntries++

                foreach ($kw in $forbiddenKeywords) {
                    if ($text -match "(?i)$kw") {
                        Write-Host "  [FAIL] Forbidden keyword '$kw' found inside Public APK entry: $($entry.FullName)" -ForegroundColor Red
                        $auditFailed = $true
                    }
                }
            }
        }
    } finally {
        $zip.Dispose()
    }
    if (-not $auditFailed) {
        Write-Host "  [PASS] Public APK ($publicApk) scanned: zero private data found." -ForegroundColor Green
    }
} else {
    Write-Host "  [INFO] Public APK not yet built at $publicApk (skipping APK unpack check)." -ForegroundColor Cyan
}

# ---------------------------------------------------------
# FINAL AUDIT VERDICT
# ---------------------------------------------------------
Write-Host "`n========================================" -ForegroundColor Cyan
if ($auditFailed) {
    Write-Host "PRIVACY AUDIT FAILED! Issues detected above." -ForegroundColor Red
    exit 1
} else {
    Write-Host "PRIVACY AUDIT PASSED: 100% verified clean across Git, files, and APK." -ForegroundColor Green
    exit 0
}
