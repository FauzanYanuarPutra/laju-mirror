$ErrorActionPreference = "Stop"

$manifestPath = "artifacts/windows-release/release-manifest.json"
$checksumPath = "artifacts/windows-release/SHA256SUMS.txt"
$configPath = "src-tauri/tauri.conf.json"
$toolDirectory = "src-tauri/resources/tools/scrcpy"
foreach ($requiredPath in @($manifestPath, $checksumPath, $configPath, $toolDirectory)) {
    if (-not (Test-Path -LiteralPath $requiredPath)) {
        throw "A required release verification input is missing: $requiredPath"
    }
}

$repoRoot = [IO.Path]::GetFullPath((Get-Location).Path).TrimEnd([IO.Path]::DirectorySeparatorChar)
$rootPrefix = $repoRoot + [IO.Path]::DirectorySeparatorChar
$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
$config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json

if (-not $manifest.signingConfigured -or -not $manifest.signingRequired) {
    throw "Refusing to publish: the manifest does not confirm required trusted code signing."
}
if ($manifest.buildPurpose -ne "release") {
    throw "Refusing to publish a build not marked as a tagged release."
}
if ($manifest.version -ne $config.version) {
    throw "Manifest version does not match src-tauri/tauri.conf.json."
}
if (-not [string]::IsNullOrWhiteSpace($env:GITHUB_SHA) -and $manifest.sourceCommit -ne $env:GITHUB_SHA) {
    throw "Manifest source commit does not match the commit being released."
}
if (-not [string]::IsNullOrWhiteSpace($env:GITHUB_REF) -and $manifest.sourceRef -ne $env:GITHUB_REF) {
    throw "Manifest source ref does not match the tag being released."
}
if ($null -eq $manifest.files -or @($manifest.files).Count -eq 0) {
    throw "Release manifest contains no file inventory."
}

$msiPattern = "$($config.productName)_$($config.version)_x64_*.msi"
$nsisPattern = "$($config.productName)_$($config.version)_x64-setup.exe"
$requiredFiles = [System.Collections.Generic.List[string]]::new()
$requiredFiles.Add("src-tauri/target/release/lajumirror.exe")
$requiredFiles.Add((Join-Path $toolDirectory "scrcpy.exe"))
$requiredFiles.Add((Join-Path $toolDirectory "adb.exe"))

$runtimeFiles = @(Get-ChildItem -LiteralPath $toolDirectory -Recurse -File |
    Where-Object { $_.Extension -in @(".exe", ".dll") })
if ($runtimeFiles.Count -lt 2) {
    throw "The bundled runtime directory does not contain the expected ADB and scrcpy binaries."
}
foreach ($runtimeFile in $runtimeFiles) {
    $requiredFiles.Add($runtimeFile.FullName)
}

$msiFiles = @(Get-ChildItem -Path "src-tauri/target/release/bundle/msi" -Filter $msiPattern -File -ErrorAction SilentlyContinue)
$nsisFiles = @(Get-ChildItem -Path "src-tauri/target/release/bundle/nsis" -Filter $nsisPattern -File -ErrorAction SilentlyContinue)
if ($msiFiles.Count -eq 0) {
    throw "No MSI installer matching '$msiPattern' was found."
}
if ($nsisFiles.Count -eq 0) {
    throw "No NSIS installer matching '$nsisPattern' was found."
}
foreach ($installer in @($msiFiles) + @($nsisFiles)) {
    $requiredFiles.Add($installer.FullName)
}

$manifestByPath = @{}
$invalid = [System.Collections.Generic.List[string]]::new()
foreach ($entry in $manifest.files) {
    if ([string]::IsNullOrWhiteSpace($entry.path)) {
        $invalid.Add("Manifest contains a blank file path.")
        continue
    }
    if ([IO.Path]::IsPathRooted($entry.path) -or ($entry.path -split '[/\\]' -contains "..")) {
        $invalid.Add("Manifest path is not a safe repository-relative path: $($entry.path)")
        continue
    }
    if ($manifestByPath.ContainsKey($entry.path)) {
        $invalid.Add("Manifest contains a duplicate file path: $($entry.path)")
        continue
    }
    if ($entry.sha256 -notmatch '^[0-9a-fA-F]{64}$') {
        $invalid.Add("$($entry.path): invalid SHA-256 format")
        continue
    }

    $candidatePath = [IO.Path]::GetFullPath((Join-Path $repoRoot ($entry.path.Replace("/", [string][char]92))))
    if (-not $candidatePath.StartsWith($rootPrefix, [StringComparison]::OrdinalIgnoreCase)) {
        $invalid.Add("$($entry.path): resolves outside the repository root")
        continue
    }
    if (-not (Test-Path -LiteralPath $candidatePath -PathType Leaf)) {
        $invalid.Add("$($entry.path): file is missing")
        continue
    }

    $actualHash = (Get-FileHash -LiteralPath $candidatePath -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actualHash -ne $entry.sha256.ToLowerInvariant()) {
        $invalid.Add("$($entry.path): SHA-256 does not match the manifest")
        continue
    }

    $signature = Get-AuthenticodeSignature -FilePath $candidatePath
    if ($signature.Status -ne "Valid") {
        $invalid.Add("$($entry.path): Authenticode status is $($signature.Status)")
        continue
    }
    if ($entry.signatureStatus -ne "Valid" -or
        [string]::IsNullOrWhiteSpace($entry.signer) -or
        [string]::IsNullOrWhiteSpace($entry.thumbprint)) {
        $invalid.Add("$($entry.path): manifest does not record a valid signer and thumbprint")
        continue
    }

    $manifestByPath[$entry.path] = $entry
}

foreach ($expectedPath in $requiredFiles) {
    $relativePath = [IO.Path]::GetRelativePath($repoRoot, $expectedPath).Replace([string][char]92, "/")
    if (-not $manifestByPath.ContainsKey($relativePath)) {
        $invalid.Add("${relativePath}: required distributable is missing from the manifest")
    }
}

$checksumLines = @(Get-Content -LiteralPath $checksumPath)
if ($checksumLines.Count -ne @($manifest.files).Count) {
    $invalid.Add("SHA256SUMS.txt file count does not match the release manifest.")
} else {
    foreach ($entry in $manifest.files) {
        $expectedLine = "$($entry.sha256.ToLowerInvariant())  $($entry.path)"
        if ($checksumLines -notcontains $expectedLine) {
            $invalid.Add("$($entry.path): SHA256SUMS.txt does not match the release manifest")
        }
    }
}

if ($invalid.Count -gt 0) {
    Write-Host "Release integrity/signature verification failed:" -ForegroundColor Red
    $invalid | ForEach-Object { Write-Host ("  " + $_) -ForegroundColor Red }
    throw "Release blocked: one or more distributable files are unsigned, invalid, missing, or changed."
}

Write-Host "All application, ADB/scrcpy, DLL and installer files have matching SHA-256 hashes and valid Authenticode signatures." -ForegroundColor Green
