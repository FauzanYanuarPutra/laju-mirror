$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "LajuMirror Windows development launcher" -ForegroundColor Cyan
Write-Host "This will run the local Vite and Rust development processes."
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
Write-Host "Starting LajuMirror. On a managed Windows device, App Control may block Cargo-generated build executables." -ForegroundColor Yellow
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
