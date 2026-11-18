$ErrorActionPreference = "Stop"

$toolDirectory = "src-tauri/resources/tools/scrcpy"
if (-not (Test-Path -LiteralPath $toolDirectory -PathType Container)) {
    throw "The bundled scrcpy/ADB tool directory is missing: $toolDirectory"
}

$files = @(Get-ChildItem -Path $toolDirectory -Recurse -File |
    Where-Object { $_.Extension -in @(".exe", ".dll") })

if ($files.Count -eq 0) {
    throw "No Windows executable or DLL files were found in $toolDirectory."
}

$hasTrustedCertificate =
    -not [string]::IsNullOrWhiteSpace($env:WINDOWS_SIGNING_PFX_BASE64) -and
    -not [string]::IsNullOrWhiteSpace($env:WINDOWS_SIGNING_PFX_PASSWORD)

if (-not $hasTrustedCertificate) {
    Write-Warning "No trusted code-signing certificate is configured. Bundled scrcpy/ADB files will not be re-signed."
    if ($env:WINDOWS_SIGNING_REQUIRED -eq "true") {
        throw "WINDOWS_SIGNING_REQUIRED is true, but trusted signing credentials are missing."
    }
    return
}

$signer = Join-Path $PSScriptRoot "../src-tauri/sign-windows-file.ps1"
if (-not (Test-Path -LiteralPath $signer)) {
    throw "Signing helper was not found: $signer"
}

foreach ($file in $files) {
    $signature = Get-AuthenticodeSignature -FilePath $file.FullName

    if ($signature.Status -eq "Valid") {
        Write-Host "Already Authenticode-valid: $($file.Name)" -ForegroundColor Green
        continue
    }

    if ($signature.Status -ne "NotSigned") {
        throw "Refusing to replace an existing non-valid signature on '$($file.FullName)'. Status: $($signature.Status). Review the upstream binary before packaging."
    }

    Write-Host "Applying the LajuMirror distribution signature to unsigned upstream tool: $($file.Name)" -ForegroundColor Yellow
    & $signer -Path $file.FullName

    $verified = Get-AuthenticodeSignature -FilePath $file.FullName
    if ($verified.Status -ne "Valid") {
        throw "The signature could not be verified for '$($file.FullName)'. Status: $($verified.Status)."
    }
}

Write-Host "All bundled scrcpy/ADB executables and DLLs have valid Authenticode signatures." -ForegroundColor Green
