$ErrorActionPreference = "Stop"

$manifestPath = "artifacts/windows-release/release-manifest.json"
if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
    throw "Release manifest is missing: $manifestPath"
}

$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
if (-not $manifest.signingConfigured -or -not $manifest.signingRequired) {
    throw "Refusing to publish: the manifest does not confirm required trusted code signing."
}

$expectedFiles = @(
    "src-tauri/target/release/lajumirror.exe",
    "src-tauri/target/release/bundle/msi/LajuMirror_0.1.0_x64_en-US.msi",
    "src-tauri/target/release/bundle/nsis/LajuMirror_0.1.0_x64-setup.exe"
)

foreach ($expected in $expectedFiles) {
    if (-not (Test-Path -LiteralPath $expected -PathType Leaf)) {
        throw "A required release binary is missing: $expected"
    }
}

$invalid = @()
foreach ($entry in $manifest.files) {
    $path = Join-Path (Get-Location) ($entry.path.Replace("/", [string][char]92))
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        $invalid += "$($entry.path): file is missing"
        continue
    }

    $actualHash = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actualHash -ne $entry.sha256.ToLowerInvariant()) {
        $invalid += "$($entry.path): SHA-256 does not match the manifest"
        continue
    }

    $signature = Get-AuthenticodeSignature -FilePath $path
    if ($signature.Status -ne "Valid") {
        $invalid += "$($entry.path): Authenticode status is $($signature.Status)"
        continue
    }

    if ($entry.signatureStatus -ne "Valid") {
        $invalid += "$($entry.path): manifest signature status is $($entry.signatureStatus)"
    }
}

if ($invalid.Count -gt 0) {
    Write-Host "Release integrity/signature verification failed:" -ForegroundColor Red
    $invalid | ForEach-Object { Write-Host ("  " + $_) -ForegroundColor Red }
    throw "Release blocked: one or more distributable files are unsigned, invalid, missing, or changed."
}

Write-Host "All manifest-listed binaries have matching SHA-256 hashes and valid Authenticode signatures." -ForegroundColor Green
