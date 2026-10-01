$ErrorActionPreference = "SilentlyContinue"

Write-Host ""
Write-Host "FH6 Session Probe - Preflight Check" -ForegroundColor Cyan
Write-Host "==================================" -ForegroundColor Cyan
Write-Host ""

$failed = 0
$warned = 0

function Result([string]$name, [bool]$ok, [string]$detail) {
    if ($ok) {
        Write-Host ("[PASS] {0} - {1}" -f $name,$detail) -ForegroundColor Green
    } else {
        Write-Host ("[FAIL] {0} - {1}" -f $name,$detail) -ForegroundColor Red
        $script:failed++
    }
}

function Warn([string]$name, [string]$detail) {
    Write-Host ("[WARN] {0} - {1}" -f $name,$detail) -ForegroundColor Yellow
    $script:warned++
}

Result "Windows" ($env:OS -eq "Windows_NT") "$([Environment]::OSVersion.VersionString)"
Result "PowerShell" ($PSVersionTable.PSVersion.Major -ge 5) "$($PSVersionTable.PSVersion)"

try {
    Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
    Result "WinForms" $true "UI assembly loaded"
} catch {
    Result "WinForms" $false $_.Exception.Message
}

$required = @("Get-NetTCPConnection","Get-NetUDPEndpoint","Compress-Archive")
foreach ($cmd in $required) {
    $exists = $null -ne (Get-Command $cmd -ErrorAction SilentlyContinue)
    Result $cmd $exists $(if ($exists) {"available"} else {"missing"})
}

$pktmon = Get-Command pktmon.exe -ErrorAction SilentlyContinue
if ($pktmon) {
    Result "Packet Monitor" $true $pktmon.Source
} else {
    Warn "Packet Monitor" "pktmon.exe was not found. Capture metadata will be unavailable."
}

try {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $p = New-Object Security.Principal.WindowsPrincipal($id)
    $admin = $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if ($admin) {
        Result "Administrator" $true "elevated"
    } else {
        Warn "Administrator" "not elevated; the tester will request elevation when launched"
    }
} catch {
    Warn "Administrator" "could not determine elevation state"
}

$forza = @(Get-Process -ErrorAction SilentlyContinue | Where-Object {
    $_.ProcessName -match '(?i)^forzahorizon6$|forza.*horizon.*6'
} | Select-Object -First 1)

if ($forza.Count -gt 0) {
    Result "FH6 process" $true ("{0}.exe PID {1}" -f $forza[0].ProcessName,$forza[0].Id)
} else {
    Warn "FH6 process" "not running right now; launch FH6 before starting a capture"
}

$base = Join-Path $env:LOCALAPPDATA "ForzaSessionProbe"
try {
    New-Item -ItemType Directory -Force -Path $base | Out-Null
    $probe = Join-Path $base "preflight_write_test.tmp"
    Set-Content -LiteralPath $probe -Value "ok" -Encoding UTF8
    Remove-Item -LiteralPath $probe -Force
    Result "Capture folder" $true $base
} catch {
    Result "Capture folder" $false $_.Exception.Message
}

Write-Host ""
if ($failed -eq 0) {
    Write-Host "Preflight passed. Warnings: $warned" -ForegroundColor Green
    exit 0
} else {
    Write-Host "Preflight failed with $failed required check(s). Warnings: $warned" -ForegroundColor Red
    exit 1
}
