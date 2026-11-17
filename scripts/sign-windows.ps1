$ErrorActionPreference = "Stop"

$certificateBase64 = $env:WINDOWS_SIGNING_PFX_BASE64
$certificatePassword = $env:WINDOWS_SIGNING_PFX_PASSWORD

if ([string]::IsNullOrWhiteSpace($certificateBase64) -or [string]::IsNullOrWhiteSpace($certificatePassword)) {
    Write-Host "No trusted code-signing certificate configured. Windows installers will remain unsigned."
    exit 0
}

$pfxPath = Join-Path $env:RUNNER_TEMP "lajumirror-signing.pfx"

try {
    $pfxBytes = [Convert]::FromBase64String($certificateBase64)
    [IO.File]::WriteAllBytes($pfxPath, $pfxBytes)

    $programFilesX86 = [Environment]::GetFolderPath("ProgramFilesX86")
    $sdkBin = Join-Path $programFilesX86 "Windows Kits/10/bin"
    $signtool = Get-ChildItem -Path $sdkBin -Filter signtool.exe -Recurse -File -ErrorAction Stop |
        Where-Object { $_.FullName -match "\\x64\\signtool\.exe$" } |
        Sort-Object FullName -Descending |
        Select-Object -First 1

    if (-not $signtool) {
        throw "Windows SDK SignTool was not found on the runner."
    }

    $installers = @(
        Get-ChildItem "src-tauri/target/release/bundle/msi" -Filter "*.msi" -File
        Get-ChildItem "src-tauri/target/release/bundle/nsis" -Filter "*.exe" -File
    )

    if ($installers.Count -eq 0) {
        throw "No Windows installer files were found to sign."
    }

    foreach ($installer in $installers) {
        Write-Host "Signing $($installer.Name)"
        & $signtool.FullName sign /fd SHA256 /td SHA256 /tr "http://timestamp.digicert.com" /f $pfxPath /p $certificatePassword $installer.FullName
        if ($LASTEXITCODE -ne 0) {
            throw "SignTool failed for $($installer.Name)."
        }

        & $signtool.FullName verify /pa /v $installer.FullName
        if ($LASTEXITCODE -ne 0) {
            throw "Signature verification failed for $($installer.Name)."
        }
    }

    Write-Host "All Windows installers were signed and signature verification passed." -ForegroundColor Green
}
finally {
    if (Test-Path $pfxPath) {
        Remove-Item $pfxPath -Force
    }
}
