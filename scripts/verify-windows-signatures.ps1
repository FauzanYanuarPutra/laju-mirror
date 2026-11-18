$ErrorActionPreference = "Stop"

$manifestPath = "artifacts/windows-release/release-manifest.json"
$configPath = "src-tauri/tauri.conf.json"
if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
    throw "Release manifest is missing: $manifestPath"
}
if (-not (Test-Path -LiteralPath $configPath -PathType Leaf)) {
    throw "Tauri configuration is missing: $configPath"
}

$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
$config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
if (-not $manifest.signingConfigured -or -not $manifest.signingRequired) {
    throw "Refusing to publish: the manifest does not confirm required trusted code signing."
}
if ($manifest.buildPurpose -ne "release") {
    throw "Refusing to publish a build not marked as a tagged release."
}

$msiPattern = "$($config.productName)_$($config.version)_x64_*.msi"
$nsisPattern = "$($config.productName)_$($config.version)_x64-setup.exe"
$requiredFiles = @(
    "src-tauri/target/release/lajumirror.exe"
)
$msiFiles = @(Get-ChildItem -Path "src-tauri/target/release/bundle/msi" -Filter $msiPattern -File -ErrorAction SilentlyContinue)
$nsisFiles = @(Get-ChildItem -Path "src-tauri/target/release/bundle/nsis" -Filter $nsisPattern -File -ErrorAction SilentlyContinue)
if ($msiFiles.Count -eq 0) {
    throw "No MSI installer matching '$msiPattern' was found."
}
if ($nsisFiles.Count -eq 0) {
    throw "No NSIS installer matching '$nsisPattern' was found."
}
$requiredFiles += @($msiFiles | ForEach-Object { $_.FullName })
$requiredFiles += @($nsisFiles | ForEach-Object { $_.FullName })
foreach ($expected in $requiredFiles) {
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

$manifestPaths = @($manifest.files | ForEach-Object { $_.path })
foreach ($expected in $requiredFiles) {
    $relative = [IO.Path]::GetRelativePath((Get-Location).Path, $expected).Replace([string][char]92, "/")
    if ($manifestPaths -notcontains $relative) {
        $invalid += "$relative: required distributable is missing from the manifest"
    }
}

if ($invalid.Count -gt 0) {
    Write-Host "Release integrity/signature verification failed:" -ForegroundColor Red
    $invalid | ForEach-Object { Write-Host ("  " + $_) -ForegroundColor Red }
    throw "Release blocked: one or more distributable files are unsigned, invalid, missing, or changed."
}

Write-Host "All manifest-listed binaries have matching SHA-256 hashes and valid Authenticode signatures." -ForegroundColor Green
