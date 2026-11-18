[CmdletBinding()]
param(
    [string]$OutputDirectory = "artifacts/windows-store",
    [string]$LayoutDirectory = "artifacts/windows-store/layout"
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
Push-Location $repoRoot

function Write-StoreStage {
    param([string]$Message)
    Write-Host ""
    Write-Host ("=" * 68) -ForegroundColor DarkGreen
    Write-Host ("  " + $Message) -ForegroundColor Cyan
    Write-Host ("=" * 68) -ForegroundColor DarkGreen
}

function New-SquareStoreAsset {
    param(
        [string]$SourcePath,
        [string]$DestinationPath,
        [int]$Size
    )

    $source = [System.Drawing.Image]::FromFile($SourcePath)
    $bitmap = [System.Drawing.Bitmap]::new(
        $Size,
        $Size,
        [System.Drawing.Imaging.PixelFormat]::Format32bppArgb
    )
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)

    try {
        $graphics.Clear([System.Drawing.Color]::FromArgb(11, 44, 35))
        $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
        $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality

        $padding = [Math]::Max(2, [int][Math]::Round($Size * 0.06))
        $available = $Size - (2 * $padding)
        $scale = [Math]::Min($available / $source.Width, $available / $source.Height)
        $width = [int][Math]::Round($source.Width * $scale)
        $height = [int][Math]::Round($source.Height * $scale)
        $x = [int][Math]::Round(($Size - $width) / 2)
        $y = [int][Math]::Round(($Size - $height) / 2)

        $graphics.DrawImage($source, $x, $y, $width, $height)
        $bitmap.Save($DestinationPath, [System.Drawing.Imaging.ImageFormat]::Png)
    }
    finally {
        $graphics.Dispose()
        $bitmap.Dispose()
        $source.Dispose()
    }
}

function New-WideStoreAsset {
    param(
        [string]$SourcePath,
        [string]$DestinationPath
    )

    $source = [System.Drawing.Image]::FromFile($SourcePath)
    $bitmap = [System.Drawing.Bitmap]::new(
        310,
        150,
        [System.Drawing.Imaging.PixelFormat]::Format32bppArgb
    )
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $whiteBrush = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::White)
    $greenBrush = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(129, 227, 168))
    $titleFont = [System.Drawing.Font]::new("Segoe UI", 22, [System.Drawing.FontStyle]::Bold)
    $subtitleFont = [System.Drawing.Font]::new("Segoe UI", 10, [System.Drawing.FontStyle]::Regular)

    try {
        $graphics.Clear([System.Drawing.Color]::FromArgb(11, 44, 35))
        $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
        $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $graphics.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit

        $graphics.DrawImage($source, 20, 20, 110, 110)
        $graphics.DrawString("LajuMirror", $titleFont, $whiteBrush, 145, 48)
        $graphics.DrawString("ANDROID SCREEN CONTROL", $subtitleFont, $greenBrush, 148, 82)
        $bitmap.Save($DestinationPath, [System.Drawing.Imaging.ImageFormat]::Png)
    }
    finally {
        $titleFont.Dispose()
        $subtitleFont.Dispose()
        $whiteBrush.Dispose()
        $greenBrush.Dispose()
        $graphics.Dispose()
        $bitmap.Dispose()
        $source.Dispose()
    }
}

try {
    Write-StoreStage "Validate Windows build output"

    $config = Get-Content "src-tauri/tauri.conf.json" -Raw | ConvertFrom-Json
    $appBinary = "src-tauri/target/release/lajumirror.exe"
    $toolDirectory = "src-tauri/resources/tools/scrcpy"
    $sourceIcon = "src-tauri/icons/128x128.png"
    $notices = "THIRD-PARTY-NOTICES.md"
    $license = "LICENSE"

    foreach ($required in @($appBinary, $sourceIcon, $notices, $license)) {
        if (-not (Test-Path -LiteralPath $required -PathType Leaf)) {
            throw "A required Store packaging input is missing: $required"
        }
    }
    foreach ($requiredTool in @("scrcpy.exe", "adb.exe")) {
        if (-not (Test-Path -LiteralPath (Join-Path $toolDirectory $requiredTool) -PathType Leaf)) {
            throw "Required bundled tool is missing: $requiredTool"
        }
    }

    $winapp = Get-Command "winapp" -ErrorAction SilentlyContinue
    if ($null -eq $winapp) {
        throw "WinApp CLI was not found. Add microsoft/setup-WinAppCli to the Windows workflow before this step."
    }

    $outputPath = [System.IO.Path]::GetFullPath((Join-Path $repoRoot $OutputDirectory))
    $layoutPath = [System.IO.Path]::GetFullPath((Join-Path $repoRoot $LayoutDirectory))
    New-Item -ItemType Directory -Path $outputPath -Force | Out-Null

    if (Test-Path -LiteralPath $layoutPath) {
        Remove-Item -LiteralPath $layoutPath -Recurse -Force
    }
    New-Item -ItemType Directory -Path $layoutPath -Force | Out-Null

    Write-StoreStage "Stage the full Tauri application and Android runtime"
    Copy-Item -LiteralPath $appBinary -Destination (Join-Path $layoutPath "lajumirror.exe") -Force

    $resourceRoot = Join-Path $layoutPath "resources"
    $toolsTarget = Join-Path $resourceRoot "tools/scrcpy"
    New-Item -ItemType Directory -Path $toolsTarget -Force | Out-Null
    Get-ChildItem -LiteralPath $toolDirectory -Force |
        Copy-Item -Destination $toolsTarget -Recurse -Force

    Copy-Item -LiteralPath $notices -Destination (Join-Path $resourceRoot "THIRD-PARTY-NOTICES.md") -Force
    Copy-Item -LiteralPath $license -Destination (Join-Path $resourceRoot "LICENSE") -Force

    Write-StoreStage "Generate package assets and manifest"
    & $winapp.Source init $layoutPath --use-defaults --setup-sdks=none
    if ($LASTEXITCODE -ne 0) {
        throw "WinApp CLI could not initialize the MSIX layout. Exit code: $LASTEXITCODE"
    }

    $assetDirectory = Join-Path $layoutPath "Assets"
    New-Item -ItemType Directory -Path $assetDirectory -Force | Out-Null
    New-SquareStoreAsset -SourcePath $sourceIcon -DestinationPath (Join-Path $assetDirectory "StoreLogo.png") -Size 50
    New-SquareStoreAsset -SourcePath $sourceIcon -DestinationPath (Join-Path $assetDirectory "Square44x44Logo.png") -Size 44
    New-SquareStoreAsset -SourcePath $sourceIcon -DestinationPath (Join-Path $assetDirectory "Square150x150Logo.png") -Size 150
    New-WideStoreAsset -SourcePath $sourceIcon -DestinationPath (Join-Path $assetDirectory "Wide310x150Logo.png")

    $storeIdentity = $env:LAJUMIRROR_STORE_IDENTITY_NAME
    $storePublisher = $env:LAJUMIRROR_STORE_PUBLISHER
    $storePublisherDisplay = $env:LAJUMIRROR_STORE_PUBLISHER_DISPLAY_NAME
    $submissionReady = -not (
        [string]::IsNullOrWhiteSpace($storeIdentity) -or
        [string]::IsNullOrWhiteSpace($storePublisher)
    )

    if (-not $submissionReady) {
        $storeIdentity = "LajuMirror.Preview"
        $storePublisher = "CN=LajuMirror Preview"
        $storePublisherDisplay = "LajuMirror Preview"
        Write-Warning "Partner Center identity variables are not set. This MSIX is a packaging preview and must not be submitted to the Store."
    }
    elseif ([string]::IsNullOrWhiteSpace($storePublisherDisplay)) {
        throw "LAJUMIRROR_STORE_PUBLISHER_DISPLAY_NAME must be set when Store identity variables are configured."
    }

    if ($storeIdentity -notmatch "^[A-Za-z0-9.]{3,50}$") {
        throw "Store package identity must contain only letters, numbers, or periods and be 3 to 50 characters."
    }
    if ([string]::IsNullOrWhiteSpace($storePublisher) -or [string]::IsNullOrWhiteSpace($storePublisherDisplay)) {
        throw "Store publisher identity and display name must not be empty."
    }

    $versionParts = @($config.version -split "\.")
    if ($versionParts.Count -eq 3) {
        $packageVersion = "$($config.version).0"
    }
    elseif ($versionParts.Count -eq 4) {
        $packageVersion = $config.version
    }
    else {
        throw "Tauri version must contain three or four numeric components for MSIX packaging."
    }
    if ($packageVersion -notmatch "^\d+\.\d+\.\d+\.\d+$") {
        throw "MSIX version must use four numeric components."
    }

    $escapedIdentity = [System.Security.SecurityElement]::Escape($storeIdentity)
    $escapedPublisher = [System.Security.SecurityElement]::Escape($storePublisher)
    $escapedPublisherDisplay = [System.Security.SecurityElement]::Escape($storePublisherDisplay)
    $manifestText = Get-Content "msix/appxmanifest.xml" -Raw
    $manifestText = $manifestText.Replace("__PACKAGE_IDENTITY_NAME__", $escapedIdentity)
    $manifestText = $manifestText.Replace("__PACKAGE_PUBLISHER__", $escapedPublisher)
    $manifestText = $manifestText.Replace("__PUBLISHER_DISPLAY_NAME__", $escapedPublisherDisplay)
    $manifestText = $manifestText.Replace("__PACKAGE_VERSION__", $packageVersion)

    $manifestPath = Join-Path $layoutPath "Package.appxmanifest"
    Set-Content -LiteralPath $manifestPath -Value $manifestText -Encoding utf8

    [xml]$validatedManifest = $manifestText
    $identityNode = $validatedManifest.SelectSingleNode("/*[local-name()='Package']/*[local-name()='Identity']")
    if ($null -eq $identityNode -or $identityNode.GetAttribute("Name") -ne $storeIdentity) {
        throw "The generated MSIX identity could not be validated."
    }

    Write-StoreStage "Create unsigned Microsoft Store submission package"
    $outputName = "LajuMirror_$($packageVersion)_x64.msix"
    Push-Location $outputPath
    try {
        $env:WINAPP_CLI_TELEMETRY_OPTOUT = "1"
        & $winapp.Source package $layoutPath --manifest $manifestPath --executable "lajumirror.exe" --output $outputName
        if ($LASTEXITCODE -ne 0) {
            throw "WinApp CLI could not create the MSIX package. Exit code: $LASTEXITCODE"
        }
    }
    finally {
        Pop-Location
    }

    $msixPath = Join-Path $outputPath $outputName
    if (-not (Test-Path -LiteralPath $msixPath -PathType Leaf)) {
        throw "WinApp CLI completed without producing the expected MSIX file: $msixPath"
    }

    Write-StoreStage "Verify package contents and provenance"
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $archive = [System.IO.Compression.ZipFile]::OpenRead($msixPath)
    try {
        $entryNames = @($archive.Entries | ForEach-Object { $_.FullName.Replace("\", "/").ToLowerInvariant() })
        $requiredEntries = @(
            "lajumirror.exe",
            "resources/tools/scrcpy/scrcpy.exe",
            "resources/tools/scrcpy/adb.exe",
            "resources/third-party-notices.md",
            "resources/license",
            "assets/storelogo.png",
            "assets/square44x44logo.png",
            "assets/square150x150logo.png",
            "assets/wide310x150logo.png"
        )
        foreach ($entryName in $requiredEntries) {
            if ($entryNames -notcontains $entryName.ToLowerInvariant()) {
                throw "MSIX package is missing a required file: $entryName"
            }
        }

        $manifestEntry = $archive.Entries |
            Where-Object { $_.FullName -match "(?i)(^|/)appxmanifest\.xml$|(^|/)package\.appxmanifest$" } |
            Select-Object -First 1
        if ($null -eq $manifestEntry) {
            throw "The MSIX archive does not contain an Appx manifest."
        }

        $stream = $manifestEntry.Open()
        $reader = [System.IO.StreamReader]::new($stream)
        try {
            [xml]$packagedManifest = $reader.ReadToEnd()
        }
        finally {
            $reader.Dispose()
            $stream.Dispose()
        }

        $packagedIdentity = $packagedManifest.SelectSingleNode("/*[local-name()='Package']/*[local-name()='Identity']")
        $packagedPublisher = $packagedIdentity.GetAttribute("Publisher")
        if ($packagedIdentity.GetAttribute("Name") -ne $storeIdentity -or
            $packagedPublisher -ne $storePublisher -or
            $packagedIdentity.GetAttribute("Version") -ne $packageVersion) {
            throw "Packaged MSIX identity does not match the requested Store identity."
        }
    }
    finally {
        $archive.Dispose()
    }

    $hash = (Get-FileHash -LiteralPath $msixPath -Algorithm SHA256).Hash.ToLowerInvariant()
    $metadata = [ordered]@{
        product = "LajuMirror"
        version = $config.version
        packageVersion = $packageVersion
        packageIdentity = $storeIdentity
        publisher = $storePublisher
        publisherDisplayName = $storePublisherDisplay
        architecture = "x64"
        packageFormat = "MSIX"
        signature = "unsigned-for-Microsoft-Store-submission"
        storeSubmissionReady = $submissionReady
        sha256 = $hash
        sourceCommit = $env:GITHUB_SHA
        generatedAtUtc = [DateTime]::UtcNow.ToString("o")
        note = if ($submissionReady) {
            "Package identity values are supplied from Partner Center. Submit this unsigned MSIX package to Partner Center; Microsoft signs it after certification."
        }
        else {
            "Packaging preview only. Replace the preview identity with the exact reserved app identity and publisher from Partner Center before submission."
        }
    }
    $metadataPath = Join-Path $outputPath "store-msix-metadata.json"
    $metadata | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $metadataPath -Encoding utf8

    Write-Host "MSIX package created: $msixPath" -ForegroundColor Green
    Write-Host "SHA-256: $hash"
    Write-Host "Store submission ready: $submissionReady"
    Write-Host "Package metadata: $metadataPath"

    if (-not [string]::IsNullOrWhiteSpace($env:GITHUB_OUTPUT)) {
        $outputValue = $submissionReady.ToString().ToLowerInvariant()
        "store_submission_ready=$outputValue" |
            Out-File -FilePath $env:GITHUB_OUTPUT -Append -Encoding utf8
    }

    if ($env:GITHUB_STEP_SUMMARY) {
        @(
            "### Microsoft Store MSIX package"
            ""
            "- Package: $outputName"
            "- Package identity: $storeIdentity"
            "- Publisher: $storePublisher"
            "- Signature: unsigned, for Microsoft Store submission"
            "- Store submission identity configured: $submissionReady"
            "- SHA-256: $hash"
        ) | Out-File -FilePath $env:GITHUB_STEP_SUMMARY -Append -Encoding utf8
    }
}
finally {
    Pop-Location
}
