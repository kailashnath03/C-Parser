# run_tests.ps1 - PowerShell test runner for C Parser Studio
# Usage: powershell -File tests/run_tests.ps1 [path_to_cparser]
#
# Runs all .c files in tests/valid/ (expect exit 0)
# and all .c files in tests/invalid/ (expect non-zero exit)
# Reports PASS/FAIL and returns exit code 1 if any test fails.

param(
    [string]$parser = "cparser.exe"
)

# Resolve parser path
if (-not (Test-Path $parser)) {
    # Try parent directory (called from parser/ dir)
    if (Test-Path ".\$parser") { $parser = ".\$parser" }
    elseif (Test-Path "..\parser\$parser") { $parser = "..\parser\$parser" }
}

$PASS = 0
$FAIL = 0

# Directories
$scriptDir  = Split-Path -Parent $MyInvocation.MyCommand.Path
$validDir   = Join-Path $scriptDir "valid"
$invalidDir = Join-Path $scriptDir "invalid"

function Run-Test {
    param([string]$file, [int]$expectSuccess)

    $name = Split-Path -Leaf $file
    $output = & $parser $file 2>&1
    $code   = $LASTEXITCODE

    if ($expectSuccess -eq 1) {
        if ($code -eq 0) {
            Write-Host "PASS  [valid]   $name" -ForegroundColor Green
            return 1
        } else {
            Write-Host "FAIL  [valid]   $name  (exit $code)" -ForegroundColor Red
            if ($output) { Write-Host "      $output" -ForegroundColor DarkRed }
            return 0
        }
    } else {
        if ($code -ne 0) {
            Write-Host "PASS  [invalid] $name  (correctly rejected, exit $code)" -ForegroundColor Green
            return 1
        } else {
            Write-Host "FAIL  [invalid] $name  (should have been rejected)" -ForegroundColor Red
            return 0
        }
    }
}

Write-Host ""
Write-Host "======================================================" -ForegroundColor Cyan
Write-Host "  C Parser Studio - Automated Test Suite"              -ForegroundColor Cyan
Write-Host "  Parser: $parser"                                      -ForegroundColor Cyan
Write-Host "======================================================" -ForegroundColor Cyan
Write-Host ""

# Valid tests
Write-Host "--- Valid programs (should parse successfully) ---"
Get-ChildItem -Path $validDir -Filter "*.c" | Sort-Object Name | ForEach-Object {
    $r = Run-Test $_.FullName 1
    if ($r -eq 1) { $PASS++ } else { $FAIL++ }
}

Write-Host ""
Write-Host "--- Invalid programs (should be rejected) ---"
Get-ChildItem -Path $invalidDir -Filter "*.c" | Sort-Object Name | ForEach-Object {
    $r = Run-Test $_.FullName 0
    if ($r -eq 1) { $PASS++ } else { $FAIL++ }
}

Write-Host ""
Write-Host "======================================================" -ForegroundColor Cyan
$total = $PASS + $FAIL
Write-Host "  Results: $PASS/$total passed" -ForegroundColor $(if ($FAIL -eq 0) { "Green" } else { "Yellow" })
Write-Host "======================================================" -ForegroundColor Cyan
Write-Host ""

if ($FAIL -gt 0) { exit 1 } else { exit 0 }

