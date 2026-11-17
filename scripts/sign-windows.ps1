$ErrorActionPreference = "Stop"

$signer = Join-Path $PSScriptRoot "../src-tauri/sign-windows-file.ps1"
if (-not (Test-Path -LiteralPath $signer)) {
    throw "Signing helper was not found: $signer"
}

$installers = @()
$msiDirectory = "src-tauri/target/release/bundle/msi"
$nsisDirectory = "src-tauri/target/release/bundle/nsis"

if (Test-Path $msiDirectory) {
    $installers += Get-ChildItem -Path $msiDirectory -Filter "*.msi" -File
}
if (Test-Path $nsisDirectory) {
    $installers += Get-ChildItem -Path $nsisDirectory -Filter "*.exe" -File
}

if ($installers.Count -eq 0) {
    throw "No MSI or NSIS installer files were found."
}

if ([string]::IsNullOrWhiteSpace($env:WINDOWS_SIGNING_PFX_BASE64) -or [string]::IsNullOrWhiteSpace($env:WINDOWS_SIGNING_PFX_PASSWORD)) {
    Write-Warning "No trusted code-signing certificate is configured. The generated installers remain unsigned."
    if ($env:WINDOWS_SIGNING_REQUIRED -eq "true") {
        throw "WINDOWS_SIGNING_REQUIRED is true, but trusted signing credentials are missing."
    }
    return
}

foreach ($installer in $installers) {
    & $signer -Path $installer.FullName
}

Write-Host "All installer signing operations completed. Signature status will be recorded in the release manifest." -ForegroundColor Green
