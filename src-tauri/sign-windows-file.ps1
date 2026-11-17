param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$Path
)

$ErrorActionPreference = "Stop"

$certificateBase64 = $env:WINDOWS_SIGNING_PFX_BASE64
$certificatePassword = $env:WINDOWS_SIGNING_PFX_PASSWORD

if ([string]::IsNullOrWhiteSpace($certificateBase64) -or [string]::IsNullOrWhiteSpace($certificatePassword)) {
    Write-Host "Trusted code-signing credentials are not configured; leaving '$Path' unsigned." -ForegroundColor Yellow
    return
}

if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
    throw "Signing input does not exist: $Path"
}

$resolvedPath = (Resolve-Path -LiteralPath $Path).Path
$signature = Get-AuthenticodeSignature -FilePath $resolvedPath

if ($signature.Status -eq "Valid") {
    Write-Host "Already signed and valid: $resolvedPath" -ForegroundColor Green
    return
}

if ($signature.Status -ne "NotSigned") {
    throw "Refusing to overwrite a non-valid existing signature on '$resolvedPath'. Status: $($signature.Status)."
}

$pfxDirectory = if ($env:RUNNER_TEMP) { $env:RUNNER_TEMP } else { $env:TEMP }
$pfxPath = Join-Path $pfxDirectory ("lajumirror-signing-" + [Guid]::NewGuid().ToString("N") + ".pfx")

try {
    [IO.File]::WriteAllBytes($pfxPath, [Convert]::FromBase64String($certificateBase64))

    $programFilesX86 = [Environment]::GetFolderPath("ProgramFilesX86")
    $sdkBin = Join-Path $programFilesX86 "Windows Kits/10/bin"
    $signtool = Get-ChildItem -Path $sdkBin -Filter "signtool.exe" -Recurse -File -ErrorAction Stop |
        Where-Object { $_.FullName -match "\\x64\\signtool\.exe$" } |
        Sort-Object FullName -Descending |
        Select-Object -First 1

    if (-not $signtool) {
        throw "Windows SDK SignTool was not found on this runner."
    }

    Write-Host "Signing: $resolvedPath"
    & $signtool.FullName sign /fd SHA256 /td SHA256 /tr "http://timestamp.digicert.com" /f $pfxPath /p $certificatePassword $resolvedPath
    if ($LASTEXITCODE -ne 0) {
        throw "SignTool failed to sign '$resolvedPath'."
    }

    & $signtool.FullName verify /pa /v $resolvedPath
    if ($LASTEXITCODE -ne 0) {
        throw "SignTool could not verify '$resolvedPath'."
    }

    $verified = Get-AuthenticodeSignature -FilePath $resolvedPath
    if ($verified.Status -ne "Valid") {
        throw "The signature on '$resolvedPath' did not validate. Status: $($verified.Status)."
    }

    Write-Host "Signature verified: $resolvedPath" -ForegroundColor Green
}
finally {
    if (Test-Path -LiteralPath $pfxPath) {
        Remove-Item -LiteralPath $pfxPath -Force
    }
}
