$ErrorActionPreference = "Stop"

$manifestDirectory = "artifacts/windows-release"
New-Item -ItemType Directory -Path $manifestDirectory -Force | Out-Null

$config = Get-Content "src-tauri/tauri.conf.json" -Raw | ConvertFrom-Json
$files = @()

$appBinary = "src-tauri/target/release/lajumirror.exe"
if (Test-Path $appBinary) {
    $files += Get-Item $appBinary
}

$toolDirectory = "src-tauri/resources/tools/scrcpy"
if (Test-Path $toolDirectory) {
    $files += Get-ChildItem -Path $toolDirectory -Recurse -File |
        Where-Object { $_.Extension -in @(".exe", ".dll") }
}

foreach ($directory in @("src-tauri/target/release/bundle/msi", "src-tauri/target/release/bundle/nsis")) {
    if (Test-Path $directory) {
        $files += Get-ChildItem -Path $directory -File |
            Where-Object { $_.Extension -in @(".msi", ".exe") }
    }
}

$entries = foreach ($file in ($files | Sort-Object FullName -Unique)) {
    $signature = Get-AuthenticodeSignature -FilePath $file.FullName
    $relativePath = [IO.Path]::GetRelativePath((Get-Location).Path, $file.FullName).Replace("\\", "/")
    $hash = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant()

    [ordered]@{
        path = $relativePath
        sizeBytes = $file.Length
        sha256 = $hash
        signatureStatus = [string]$signature.Status
        signer = $(if ($signature.SignerCertificate) { $signature.SignerCertificate.Subject } else { $null })
        thumbprint = $(if ($signature.SignerCertificate) { $signature.SignerCertificate.Thumbprint } else { $null })
    }
}

$manifest = [ordered]@{
    product = "LajuMirror"
    version = $config.version
    sourceCommit = $env:GITHUB_SHA
    sourceRef = $env:GITHUB_REF
    generatedAtUtc = [DateTime]::UtcNow.ToString("o")
    signingConfigured = -not ([string]::IsNullOrWhiteSpace($env:WINDOWS_SIGNING_PFX_BASE64) -or [string]::IsNullOrWhiteSpace($env:WINDOWS_SIGNING_PFX_PASSWORD))
    files = @($entries)
}

$manifestPath = Join-Path $manifestDirectory "release-manifest.json"
$manifest | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $manifestPath -Encoding utf8

$checksumPath = Join-Path $manifestDirectory "SHA256SUMS.txt"
$checksumLines = @($entries | ForEach-Object { "$($_.sha256)  $($_.path)" })
$checksumLines | Set-Content -LiteralPath $checksumPath -Encoding utf8

$unsigned = @($entries | Where-Object { $_.signatureStatus -ne "Valid" })
Write-Host "Manifest created: $manifestPath"
Write-Host "SHA-256 checksums created: $checksumPath"
Write-Host "Tracked PE/MSI files: $(@($entries).Count)"
Write-Host "Files without a valid Authenticode signature: $($unsigned.Count)" -ForegroundColor $(if ($unsigned.Count -gt 0) { "Yellow" } else { "Green" })

if ($env:GITHUB_STEP_SUMMARY) {
    @(
        "### Windows binary signature audit"
        ""
        "| File | Authenticode | SHA-256 |"
        "|---|---|---|"
    ) | Out-File -FilePath $env:GITHUB_STEP_SUMMARY -Append -Encoding utf8

    foreach ($entry in $entries) {
        "| $($entry.path) | $($entry.signatureStatus) | $($entry.sha256) |" |
            Out-File -FilePath $env:GITHUB_STEP_SUMMARY -Append -Encoding utf8
    }

    if ($unsigned.Count -gt 0) {
        " " | Out-File -FilePath $env:GITHUB_STEP_SUMMARY -Append -Encoding utf8
        "Warning: one or more files are not Authenticode-valid. Review the manifest before distribution." |
            Out-File -FilePath $env:GITHUB_STEP_SUMMARY -Append -Encoding utf8
    }
}
