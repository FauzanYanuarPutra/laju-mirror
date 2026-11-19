[CmdletBinding()]
param(
    [string]$PackagePath
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
Push-Location $repoRoot

function Get-ArchiveEntrySha256 {
    param([System.IO.Compression.ZipArchiveEntry]$Entry)

    $stream = $Entry.Open()
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $digest = $sha.ComputeHash($stream)
        return [Convert]::ToHexString($digest).ToLowerInvariant()
    }
    finally {
        $sha.Dispose()
        $stream.Dispose()
    }
}

function Copy-ArchiveEntry {
    param(
        [System.IO.Compression.ZipArchiveEntry]$Entry,
        [string]$DestinationPath
    )

    $parent = Split-Path -Parent $DestinationPath
    New-Item -ItemType Directory -Path $parent -Force | Out-Null
    $input = $Entry.Open()
    $output = [System.IO.File]::Open(
        $DestinationPath,
        [System.IO.FileMode]::Create,
        [System.IO.FileAccess]::Write,
        [System.IO.FileShare]::None
    )
    try {
        $input.CopyTo($output)
    }
    finally {
        $output.Dispose()
        $input.Dispose()
    }
}

try {
    Add-Type -AssemblyName System.IO.Compression
    Add-Type -AssemblyName System.IO.Compression.FileSystem

    $config = Get-Content "src-tauri/tauri.conf.json" -Raw | ConvertFrom-Json
    if ([string]::IsNullOrWhiteSpace($PackagePath)) {
        $packageVersionForPath = if ($config.version -match '^\d+\.\d+\.\d+    if (-not (Test-Path -LiteralPath $metadataPath -PathType Leaf)) {
        throw "Store package metadata is missing: $metadataPath"
    }

    $metadata = Get-Content -LiteralPath $metadataPath -Raw | ConvertFrom-Json
    $appBinary = "src-tauri/target/release/lajumirror.exe"
    $toolDirectory = "src-tauri/resources/tools/scrcpy"
    foreach ($required in @($appBinary, $toolDirectory, $PackagePath)) {
        if (-not (Test-Path -LiteralPath $required)) {
            throw "A Store verification input is missing: $required"
        }
    }

    $packageFullPath = [IO.Path]::GetFullPath((Join-Path $repoRoot $PackagePath))
    $packageHash = (Get-FileHash -LiteralPath $packageFullPath -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($packageHash -ne $metadata.sha256.ToLowerInvariant()) {
        throw "The MSIX SHA-256 does not match store-msix-metadata.json."
    }

    $expectedPackageVersion = if ($config.version -match '^\d+\.\d+\.\d+$') {
        "$($config.version).0"
    } else {
        $config.version
    }
    if ($metadata.packageVersion -ne $expectedPackageVersion) {
        throw "MSIX package version does not match src-tauri/tauri.conf.json."
    }
    if ($metadata.version -ne $config.version) {
        throw "Store metadata version does not match the Tauri application version."
    }
    if ($metadata.signature -ne "unsigned-for-Microsoft-Store-submission") {
        throw "The Store package must remain unsigned for Microsoft Store submission."
    }
    if (-not [string]::IsNullOrWhiteSpace($env:GITHUB_SHA) -and
        $metadata.sourceCommit -ne $env:GITHUB_SHA) {
        throw "Store package provenance does not match the current Git commit."
    }

    $archive = [System.IO.Compression.ZipFile]::OpenRead($packageFullPath)
    $runtimeSmokeRoot = Join-Path ([IO.Path]::GetTempPath()) ("lajumirror-msix-smoke-" + [Guid]::NewGuid().ToString("N"))
    try {
        $entriesByPath = @{}
        foreach ($entry in $archive.Entries) {
            $entryPath = $entry.FullName.Replace([string][char]92, "/")
            if ([string]::IsNullOrWhiteSpace($entryPath) -or
                $entryPath.StartsWith("/") -or
                ($entryPath -split "/" -contains "..")) {
                throw "The MSIX contains an unsafe archive path: $($entry.FullName)"
            }

            $entryKey = $entryPath.ToLowerInvariant()
            if ($entriesByPath.ContainsKey($entryKey)) {
                throw "The MSIX contains duplicate paths that differ only by case: $entryPath"
            }
            $entriesByPath[$entryKey] = $entry
        }

        $manifestEntry = $entriesByPath["appxmanifest.xml"]
        if ($null -eq $manifestEntry) {
            throw "The MSIX package does not contain AppxManifest.xml."
        }

        $manifestStream = $manifestEntry.Open()
        $manifestReader = [System.IO.StreamReader]::new($manifestStream)
        try {
            [xml]$manifest = $manifestReader.ReadToEnd()
        }
        finally {
            $manifestReader.Dispose()
            $manifestStream.Dispose()
        }

        $identity = $manifest.SelectSingleNode("/*[local-name()='Package']/*[local-name()='Identity']")
        if ($null -eq $identity) {
            throw "AppxManifest.xml is missing its package identity."
        }
        if ($identity.GetAttribute("Name") -ne $metadata.packageIdentity -or
            $identity.GetAttribute("Publisher") -ne $metadata.publisher -or
            $identity.GetAttribute("Version") -ne $metadata.packageVersion -or
            $identity.GetAttribute("ProcessorArchitecture") -ne "x64") {
            throw "Packaged MSIX identity, publisher, version, or architecture does not match the metadata."
        }

        $application = $manifest.SelectSingleNode("/*[local-name()='Package']/*[local-name()='Applications']/*[local-name()='Application']")
        if ($null -eq $application -or
            $application.GetAttribute("Id") -ne "LajuMirror" -or
            $application.GetAttribute("Executable") -ne "lajumirror.exe" -or
            $application.GetAttribute("EntryPoint") -ne "Windows.FullTrustApplication") {
            throw "The MSIX application entry point is missing or incorrect."
        }

        $fullTrustCapability = $manifest.SelectSingleNode(
            "/*[local-name()='Package']/*[local-name()='Capabilities']/*[local-name()='Capability'][@Name='runFullTrust']"
        )
        if ($null -eq $fullTrustCapability) {
            throw "The MSIX manifest does not declare the required runFullTrust capability."
        }

        $expectedFiles = [System.Collections.Generic.List[object]]::new()
        [void]$expectedFiles.Add([pscustomobject]@{
            PackagePath = "lajumirror.exe"
            SourcePath = $appBinary
        })
        [void]$expectedFiles.Add([pscustomobject]@{
            PackagePath = "resources/license"
            SourcePath = "LICENSE"
        })
        [void]$expectedFiles.Add([pscustomobject]@{
            PackagePath = "resources/third-party-notices.md"
            SourcePath = "THIRD-PARTY-NOTICES.md"
        })

        $toolFiles = @(Get-ChildItem -LiteralPath $toolDirectory -Recurse -File -Force)
        if ($toolFiles.Count -lt 2) {
            throw "The source runtime directory must include ADB and scrcpy."
        }
        foreach ($file in $toolFiles) {
            $relative = [IO.Path]::GetRelativePath((Resolve-Path $toolDirectory).Path, $file.FullName).Replace([string][char]92, "/")
            [void]$expectedFiles.Add([pscustomobject]@{
                PackagePath = "resources/tools/scrcpy/$relative"
                SourcePath = $file.FullName
            })
        }

        foreach ($expected in $expectedFiles) {
            $key = $expected.PackagePath.ToLowerInvariant()
            $entry = $entriesByPath[$key]
            if ($null -eq $entry) {
                throw "The MSIX package is missing a required file: $($expected.PackagePath)"
            }

            $sourceHash = (Get-FileHash -LiteralPath $expected.SourcePath -Algorithm SHA256).Hash.ToLowerInvariant()
            $packageFileHash = Get-ArchiveEntrySha256 -Entry $entry
            if ($sourceHash -ne $packageFileHash) {
                throw "The MSIX file does not match its source file: $($expected.PackagePath)"
            }
        }

        foreach ($asset in @(
            "assets/storelogo.png",
            "assets/square44x44logo.png",
            "assets/square150x150logo.png",
            "assets/wide310x150logo.png"
        )) {
            if (-not $entriesByPath.ContainsKey($asset)) {
                throw "The MSIX is missing a required Store visual asset: $asset"
            }
        }

        New-Item -ItemType Directory -Path $runtimeSmokeRoot -Force | Out-Null
        foreach ($expected in $expectedFiles | Where-Object { $_.PackagePath.StartsWith("resources/tools/scrcpy/") }) {
            $relative = $expected.PackagePath.Substring("resources/tools/scrcpy/".Length)
            $destination = Join-Path $runtimeSmokeRoot ($relative.Replace("/", [string][char]92))
            Copy-ArchiveEntry -Entry $entriesByPath[$expected.PackagePath.ToLowerInvariant()] -DestinationPath $destination
        }

        $adbPath = Join-Path $runtimeSmokeRoot "adb.exe"
        $scrcpyPath = Join-Path $runtimeSmokeRoot "scrcpy.exe"
        foreach ($runtimeExe in @($adbPath, $scrcpyPath)) {
            if (-not (Test-Path -LiteralPath $runtimeExe -PathType Leaf)) {
                throw "The packaged Android runtime executable is missing: $runtimeExe"
            }
        }

        Push-Location $runtimeSmokeRoot
        try {
            $adbOutput = & $adbPath version 2>&1 | Out-String
            $adbExitCode = $LASTEXITCODE
            if ($adbExitCode -ne 0 -or $adbOutput -notmatch "Android Debug Bridge") {
                throw "Packaged ADB failed its runtime smoke test: $adbOutput"
            }

            $scrcpyOutput = & $scrcpyPath --version 2>&1 | Out-String
            $scrcpyExitCode = $LASTEXITCODE
            if ($scrcpyExitCode -ne 0 -or $scrcpyOutput -notmatch "scrcpy") {
                throw "Packaged scrcpy failed its runtime smoke test: $scrcpyOutput"
            }
        }
        finally {
            Pop-Location
        }

        Write-Host "MSIX SHA-256, identity, entry point, manifest, and resource checks passed." -ForegroundColor Green
        Write-Host "Verified $($expectedFiles.Count) source files against their packaged SHA-256 hashes." -ForegroundColor Green
        Write-Host "Packaged ADB and scrcpy runtime smoke tests passed." -ForegroundColor Green
        Write-Host "Store submission identity configured: $([bool]$metadata.storeSubmissionReady)"

        if ($env:GITHUB_STEP_SUMMARY) {
            @(
                "### Microsoft Store MSIX verification"
                ""
                "- Package SHA-256: passed"
                "- Package identity and publisher: passed"
                "- Full-trust app entry point: passed"
                "- Source files hash-matched in MSIX: $($expectedFiles.Count)"
                "- ADB runtime smoke test: passed"
                "- scrcpy runtime smoke test: passed"
                "- Partner Center identity configured: $([bool]$metadata.storeSubmissionReady)"
            ) | Out-File -FilePath $env:GITHUB_STEP_SUMMARY -Append -Encoding utf8
        }
    }
    finally {
        if (Test-Path -LiteralPath $runtimeSmokeRoot) {
            Remove-Item -LiteralPath $runtimeSmokeRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
        $archive.Dispose()
    }
}
finally {
    Pop-Location
}
) {
            "$($config.version).0"
        } else {
            $config.version
        }
        $PackagePath = "artifacts/windows-store/$($config.productName)_$($packageVersionForPath)_x64.msix"
    }

    $metadataPath = "artifacts/windows-store/store-msix-metadata.json"
    if (-not (Test-Path -LiteralPath $metadataPath -PathType Leaf)) {
        throw "Store package metadata is missing: $metadataPath"
    }

    $metadata = Get-Content -LiteralPath $metadataPath -Raw | ConvertFrom-Json
    $appBinary = "src-tauri/target/release/lajumirror.exe"
    $toolDirectory = "src-tauri/resources/tools/scrcpy"
    foreach ($required in @($appBinary, $toolDirectory, $PackagePath)) {
        if (-not (Test-Path -LiteralPath $required)) {
            throw "A Store verification input is missing: $required"
        }
    }

    $packageFullPath = [IO.Path]::GetFullPath((Join-Path $repoRoot $PackagePath))
    $packageHash = (Get-FileHash -LiteralPath $packageFullPath -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($packageHash -ne $metadata.sha256.ToLowerInvariant()) {
        throw "The MSIX SHA-256 does not match store-msix-metadata.json."
    }

    $expectedPackageVersion = if ($config.version -match '^\d+\.\d+\.\d+$') {
        "$($config.version).0"
    } else {
        $config.version
    }
    if ($metadata.packageVersion -ne $expectedPackageVersion) {
        throw "MSIX package version does not match src-tauri/tauri.conf.json."
    }
    if ($metadata.version -ne $config.version) {
        throw "Store metadata version does not match the Tauri application version."
    }
    if ($metadata.signature -ne "unsigned-for-Microsoft-Store-submission") {
        throw "The Store package must remain unsigned for Microsoft Store submission."
    }
    if (-not [string]::IsNullOrWhiteSpace($env:GITHUB_SHA) -and
        $metadata.sourceCommit -ne $env:GITHUB_SHA) {
        throw "Store package provenance does not match the current Git commit."
    }

    $archive = [System.IO.Compression.ZipFile]::OpenRead($packageFullPath)
    $runtimeSmokeRoot = Join-Path ([IO.Path]::GetTempPath()) ("lajumirror-msix-smoke-" + [Guid]::NewGuid().ToString("N"))
    try {
        $entriesByPath = @{}
        foreach ($entry in $archive.Entries) {
            $entryPath = $entry.FullName.Replace([string][char]92, "/")
            if ([string]::IsNullOrWhiteSpace($entryPath) -or
                $entryPath.StartsWith("/") -or
                ($entryPath -split "/" -contains "..")) {
                throw "The MSIX contains an unsafe archive path: $($entry.FullName)"
            }

            $entryKey = $entryPath.ToLowerInvariant()
            if ($entriesByPath.ContainsKey($entryKey)) {
                throw "The MSIX contains duplicate paths that differ only by case: $entryPath"
            }
            $entriesByPath[$entryKey] = $entry
        }

        $manifestEntry = $entriesByPath["appxmanifest.xml"]
        if ($null -eq $manifestEntry) {
            throw "The MSIX package does not contain AppxManifest.xml."
        }

        $manifestStream = $manifestEntry.Open()
        $manifestReader = [System.IO.StreamReader]::new($manifestStream)
        try {
            [xml]$manifest = $manifestReader.ReadToEnd()
        }
        finally {
            $manifestReader.Dispose()
            $manifestStream.Dispose()
        }

        $identity = $manifest.SelectSingleNode("/*[local-name()='Package']/*[local-name()='Identity']")
        if ($null -eq $identity) {
            throw "AppxManifest.xml is missing its package identity."
        }
        if ($identity.GetAttribute("Name") -ne $metadata.packageIdentity -or
            $identity.GetAttribute("Publisher") -ne $metadata.publisher -or
            $identity.GetAttribute("Version") -ne $metadata.packageVersion -or
            $identity.GetAttribute("ProcessorArchitecture") -ne "x64") {
            throw "Packaged MSIX identity, publisher, version, or architecture does not match the metadata."
        }

        $application = $manifest.SelectSingleNode("/*[local-name()='Package']/*[local-name()='Applications']/*[local-name()='Application']")
        if ($null -eq $application -or
            $application.GetAttribute("Id") -ne "LajuMirror" -or
            $application.GetAttribute("Executable") -ne "lajumirror.exe" -or
            $application.GetAttribute("EntryPoint") -ne "Windows.FullTrustApplication") {
            throw "The MSIX application entry point is missing or incorrect."
        }

        $fullTrustCapability = $manifest.SelectSingleNode(
            "/*[local-name()='Package']/*[local-name()='Capabilities']/*[local-name()='Capability'][@Name='runFullTrust']"
        )
        if ($null -eq $fullTrustCapability) {
            throw "The MSIX manifest does not declare the required runFullTrust capability."
        }

        $expectedFiles = [System.Collections.Generic.List[object]]::new()
        [void]$expectedFiles.Add([pscustomobject]@{
            PackagePath = "lajumirror.exe"
            SourcePath = $appBinary
        })
        [void]$expectedFiles.Add([pscustomobject]@{
            PackagePath = "resources/license"
            SourcePath = "LICENSE"
        })
        [void]$expectedFiles.Add([pscustomobject]@{
            PackagePath = "resources/third-party-notices.md"
            SourcePath = "THIRD-PARTY-NOTICES.md"
        })

        $toolFiles = @(Get-ChildItem -LiteralPath $toolDirectory -Recurse -File -Force)
        if ($toolFiles.Count -lt 2) {
            throw "The source runtime directory must include ADB and scrcpy."
        }
        foreach ($file in $toolFiles) {
            $relative = [IO.Path]::GetRelativePath((Resolve-Path $toolDirectory).Path, $file.FullName).Replace([string][char]92, "/")
            [void]$expectedFiles.Add([pscustomobject]@{
                PackagePath = "resources/tools/scrcpy/$relative"
                SourcePath = $file.FullName
            })
        }

        foreach ($expected in $expectedFiles) {
            $key = $expected.PackagePath.ToLowerInvariant()
            $entry = $entriesByPath[$key]
            if ($null -eq $entry) {
                throw "The MSIX package is missing a required file: $($expected.PackagePath)"
            }

            $sourceHash = (Get-FileHash -LiteralPath $expected.SourcePath -Algorithm SHA256).Hash.ToLowerInvariant()
            $packageFileHash = Get-ArchiveEntrySha256 -Entry $entry
            if ($sourceHash -ne $packageFileHash) {
                throw "The MSIX file does not match its source file: $($expected.PackagePath)"
            }
        }

        foreach ($asset in @(
            "assets/storelogo.png",
            "assets/square44x44logo.png",
            "assets/square150x150logo.png",
            "assets/wide310x150logo.png"
        )) {
            if (-not $entriesByPath.ContainsKey($asset)) {
                throw "The MSIX is missing a required Store visual asset: $asset"
            }
        }

        New-Item -ItemType Directory -Path $runtimeSmokeRoot -Force | Out-Null
        foreach ($expected in $expectedFiles | Where-Object { $_.PackagePath.StartsWith("resources/tools/scrcpy/") }) {
            $relative = $expected.PackagePath.Substring("resources/tools/scrcpy/".Length)
            $destination = Join-Path $runtimeSmokeRoot ($relative.Replace("/", [string][char]92))
            Copy-ArchiveEntry -Entry $entriesByPath[$expected.PackagePath.ToLowerInvariant()] -DestinationPath $destination
        }

        $adbPath = Join-Path $runtimeSmokeRoot "adb.exe"
        $scrcpyPath = Join-Path $runtimeSmokeRoot "scrcpy.exe"
        foreach ($runtimeExe in @($adbPath, $scrcpyPath)) {
            if (-not (Test-Path -LiteralPath $runtimeExe -PathType Leaf)) {
                throw "The packaged Android runtime executable is missing: $runtimeExe"
            }
        }

        Push-Location $runtimeSmokeRoot
        try {
            $adbOutput = & $adbPath version 2>&1 | Out-String
            $adbExitCode = $LASTEXITCODE
            if ($adbExitCode -ne 0 -or $adbOutput -notmatch "Android Debug Bridge") {
                throw "Packaged ADB failed its runtime smoke test: $adbOutput"
            }

            $scrcpyOutput = & $scrcpyPath --version 2>&1 | Out-String
            $scrcpyExitCode = $LASTEXITCODE
            if ($scrcpyExitCode -ne 0 -or $scrcpyOutput -notmatch "scrcpy") {
                throw "Packaged scrcpy failed its runtime smoke test: $scrcpyOutput"
            }
        }
        finally {
            Pop-Location
        }

        Write-Host "MSIX SHA-256, identity, entry point, manifest, and resource checks passed." -ForegroundColor Green
        Write-Host "Verified $($expectedFiles.Count) source files against their packaged SHA-256 hashes." -ForegroundColor Green
        Write-Host "Packaged ADB and scrcpy runtime smoke tests passed." -ForegroundColor Green
        Write-Host "Store submission identity configured: $([bool]$metadata.storeSubmissionReady)"

        if ($env:GITHUB_STEP_SUMMARY) {
            @(
                "### Microsoft Store MSIX verification"
                ""
                "- Package SHA-256: passed"
                "- Package identity and publisher: passed"
                "- Full-trust app entry point: passed"
                "- Source files hash-matched in MSIX: $($expectedFiles.Count)"
                "- ADB runtime smoke test: passed"
                "- scrcpy runtime smoke test: passed"
                "- Partner Center identity configured: $([bool]$metadata.storeSubmissionReady)"
            ) | Out-File -FilePath $env:GITHUB_STEP_SUMMARY -Append -Encoding utf8
        }
    }
    finally {
        if (Test-Path -LiteralPath $runtimeSmokeRoot) {
            Remove-Item -LiteralPath $runtimeSmokeRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
        $archive.Dispose()
    }
}
finally {
    Pop-Location
}
