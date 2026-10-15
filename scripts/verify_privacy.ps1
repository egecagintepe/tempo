# TEMPO — Privacy Audit Script
Write-Host "Running TEMPO Privacy Audit..." -ForegroundColor Cyan

$forbiddenKeywords = @(
    "anizon",
    "novzon",
    "ankaref",
    "auscultaforge",
    "eee433",
    "eee303"
)

$targetPaths = @(
    "lib",
    "config/seeds/public.json",
    "archive",
    "README.md",
    "docs/PROJECT_AUDIT.md",
    "pubspec.yaml"
)

$violationsFound = $false

foreach ($path in $targetPaths) {
    if (Test-Path $path) {
        $files = Get-ChildItem -Path $path -Recurse -File -ErrorAction SilentlyContinue
        foreach ($file in $files) {
            # Skip binary files
            if ($file.Extension -in @(".png", ".jpg", ".ico", ".apk", ".jar", ".class", ".zip")) {
                continue
            }
            # Skip PROJECT_AUDIT.md as it documents the audit of the legacy zip
            if ($file.Name -eq "PROJECT_AUDIT.md") {
                continue
            }
            $content = Get-Content -Path $file.FullName -Raw -ErrorAction SilentlyContinue
            if ($null -ne $content) {
                foreach ($keyword in $forbiddenKeywords) {
                    if ($content -match "(?i)$keyword") {
                        Write-Host "[PRIVACY VIOLATION] Found '$keyword' in $($file.FullName)" -ForegroundColor Red
                        $violationsFound = $true
                    }
                }
            }
        }
    }
}

if ($violationsFound) {
    Write-Host "`nPRIVACY AUDIT FAILED! Sensitive data detected in public files." -ForegroundColor Red
    exit 1
} else {
    Write-Host "`nPRIVACY AUDIT PASSED: Zero private keywords found in public codebase." -ForegroundColor Green
    exit 0
}
