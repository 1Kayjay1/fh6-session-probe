$ErrorActionPreference = "Stop"

$RepoRoot = Split-Path -Parent $PSScriptRoot
$Failures = New-Object System.Collections.Generic.List[string]
$Passes = 0

function Pass([string]$name) {
    $script:Passes++
    Write-Host "[PASS] $name" -ForegroundColor Green
}

function Fail([string]$name, [string]$detail) {
    $script:Failures.Add("$name :: $detail")
    Write-Host "[FAIL] $name - $detail" -ForegroundColor Red
}

function Assert-True([string]$name, [bool]$condition, [string]$detail) {
    if ($condition) { Pass $name } else { Fail $name $detail }
}

function Parse-Script([string]$path) {
    $tokens = $null
    $errors = $null
    [System.Management.Automation.Language.Parser]::ParseFile($path,[ref]$tokens,[ref]$errors) | Out-Null
    if ($errors.Count -eq 0) {
        Pass ("PowerShell syntax: " + (Split-Path -Leaf $path))
    } else {
        foreach ($e in $errors) {
            Fail ("PowerShell syntax: " + (Split-Path -Leaf $path)) $e.Message
        }
    }
}

$main = Join-Path $RepoRoot "FH6_Session_Tester.ps1"
$preflight = Join-Path $RepoRoot "tools\Preflight.ps1"
$launcher = Join-Path $RepoRoot "RUN FH6 SESSION TESTER.cmd"
$preflightLauncher = Join-Path $RepoRoot "PRE-FLIGHT CHECK.cmd"
$html = Join-Path $RepoRoot "README.html"

Assert-True "Main script exists" (Test-Path -LiteralPath $main) $main
Assert-True "Preflight script exists" (Test-Path -LiteralPath $preflight) $preflight
Assert-True "Main launcher exists" (Test-Path -LiteralPath $launcher) $launcher
Assert-True "Preflight launcher exists" (Test-Path -LiteralPath $preflightLauncher) $preflightLauncher
Assert-True "Visual README exists" (Test-Path -LiteralPath $html) $html

Parse-Script $main
Parse-Script $preflight

$source = Get-Content -LiteralPath $main -Raw
Assert-True "Metadata-only pktmon flags" ($source -match '--flags","0x00E"') "Expected pktmon metadata flags 0x00E."
Assert-True "Raw-byte flag not enabled" (-not ($source -match '--flags"\s*,\s*"0x010')) "Raw packet byte flag 0x010 must never be enabled."
Assert-True "Manual folder fallback present" ($source -match 'Find-ForzaExecutableInFolder' -and $source -match 'FolderBrowserDialog') "Folder fallback missing."
Assert-True "Live-process recheck present" ($source -match 'Always re-check the live process immediately before capture') "Capture should reject stale/missing FH6 processes."
Assert-True "Radio-mod exclusion preserved" ($source -match 'fh6-radio') "Known radio mod exclusion missing."
Assert-True "No PID automatic-variable parameter collision" (-not ($source -match 'function\s+Get-ProcessNameSafe\s*\(\s*\[int\]\s*\$pid\s*\)')) "PowerShell's automatic $PID variable is read-only; use a different parameter name."
Assert-True "No assignment to automatic args variable" (-not ($source -match '(?m)^\s*\$args\s*=')) "Avoid assigning to PowerShell automatic $args; use a normal local variable name."

$forbidden = @(
    "ReadProcessMemory",
    "WriteProcessMemory",
    "VirtualAllocEx",
    "CreateRemoteThread",
    "NtWriteVirtualMemory"
)
foreach ($term in $forbidden) {
    Assert-True ("No injection API: " + $term) (-not ($source -match [regex]::Escape($term))) ("Found forbidden API reference: " + $term)
}

$cmd = Get-Content -LiteralPath $launcher -Raw
Assert-True "Launcher points to main script" ($cmd -match 'FH6_Session_Tester\.ps1') "Launcher target mismatch."

# Verify that PowerShell can create the same kind of share ZIP used by the probe.
$temp = Join-Path ([IO.Path]::GetTempPath()) ("fh6-probe-test-" + [Guid]::NewGuid().ToString("N"))
try {
    New-Item -ItemType Directory -Path $temp | Out-Null
    $a = Join-Path $temp "probe.log"
    $b = Join-Path $temp "socket_snapshots.csv"
    Set-Content -LiteralPath $a -Value "test" -Encoding UTF8
    Set-Content -LiteralPath $b -Value "Proto,PID" -Encoding UTF8
    $zip = Join-Path $temp "share.zip"
    Compress-Archive -LiteralPath @($a,$b) -DestinationPath $zip -Force
    Assert-True "Share ZIP smoke test" (Test-Path -LiteralPath $zip) "Compress-Archive did not produce a ZIP."
} catch {
    Fail "Share ZIP smoke test" $_.Exception.Message
} finally {
    Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue
}

$htmlText = Get-Content -LiteralPath $html -Raw
Assert-True "HTML explains no injection" ($htmlText -match 'No injection') "Trust explanation missing."
Assert-True "HTML explains folder fallback" ($htmlText -match 'Choose Folder') "Folder fallback instructions missing."
Assert-True "HTML explains admin reason" ($htmlText -match 'Administrator') "Elevation explanation missing."

Write-Host ""
Write-Host ("Passed: {0}" -f $Passes)
Write-Host ("Failed: {0}" -f $Failures.Count)

if ($Failures.Count -gt 0) {
    Write-Host ""
    foreach ($f in $Failures) { Write-Host (" - " + $f) -ForegroundColor Red }
    exit 1
}

Write-Host "All tests passed." -ForegroundColor Green
exit 0
