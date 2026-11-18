$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "LajuMirror Windows development launcher" -ForegroundColor Cyan
Write-Host "This will run the local Vite and Rust development processes when Windows policy permits them."
Write-Host "It will not change App Control, Smart App Control, AppLocker, or antivirus settings."
Write-Host ""

$answer = Read-Host "Start the LajuMirror development app now? Type YES to continue"
if ($answer -cne "YES") {
    Write-Host "Cancelled. No development process was started." -ForegroundColor Yellow
    exit 0
}

if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
    Write-Host "Node.js is missing. Install the current Node.js LTS release first." -ForegroundColor Red
    exit 2
}
if (-not (Get-Command npm -ErrorAction SilentlyContinue)) {
    Write-Host "npm is missing. Reinstall Node.js with npm included." -ForegroundColor Red
    exit 2
}
if (-not (Get-Command rustc -ErrorAction SilentlyContinue) -or -not (Get-Command cargo -ErrorAction SilentlyContinue)) {
    Write-Host "Rust and Cargo are required for local Tauri development." -ForegroundColor Red
    exit 2
}

Write-Host ""
Write-Host "Node:" (node --version)
Write-Host "npm:" (npm --version)
Write-Host "Rust:" (rustc --version)
Write-Host "Cargo:" (cargo --version)
Write-Host ""

# Smart App Control state is read-only here. This launcher never changes policy.
$policyPath = "HKLM:\SYSTEM\CurrentControlSet\Control\CI\Policy"
$smartAppControlState = $null
try {
    $policy = Get-ItemProperty -Path $policyPath -Name "VerifiedAndReputablePolicyState" -ErrorAction Stop
    $smartAppControlState = [int]$policy.VerifiedAndReputablePolicyState
} catch {
    # Policy state unavailable: continue with the normal guarded development attempt.
}

if ($smartAppControlState -eq 1) {
    Write-Host "Smart App Control enforcement is active on this Windows installation." -ForegroundColor Yellow
    Write-Host "The diagnostic report confirmed that Windows blocks unsigned Cargo dependency build scripts." -ForegroundColor Yellow
    Write-Host "A code change, UAC prompt, or administrator PowerShell window cannot grant an individual Smart App Control exception." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "GitHub Actions produces an unsigned preview only. Do not install or force-run that preview on this PC." -ForegroundColor Yellow
    Write-Host "A trusted Authenticode signing certificate is required before LajuMirror can be installed under this policy." -ForegroundColor Cyan
    Write-Host "No Windows security settings were changed." -ForegroundColor Green
    Start-Process "https://github.com/FauzanYanuarPutra/laju-mirror/blob/main/docs/WINDOWS-APP-CONTROL.md"
    Start-Process "https://github.com/FauzanYanuarPutra/laju-mirror/releases"
    Write-Host "No Windows security settings were changed." -ForegroundColor Green
    exit 3
}

Write-Host "Starting LajuMirror development app." -ForegroundColor Yellow
npm run tauri dev
$devExitCode = $LASTEXITCODE

if ($devExitCode -ne 0) {
    Write-Host ""
    Write-Host "The development command failed with exit code $devExitCode." -ForegroundColor Red
    Write-Host "Starting the read-only Windows diagnostics helper." -ForegroundColor Yellow
    & (Join-Path $PSScriptRoot "windows-diagnostics.ps1")
    exit $devExitCode
}

exit 0
