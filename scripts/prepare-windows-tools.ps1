param(
  [string]$Destination = "src-tauri/resources/tools/scrcpy"
)

$ErrorActionPreference = "Stop"
$repo = "https://api.github.com/repos/Genymobile/scrcpy"
$expectedVersion = "v5.0.1"
$expectedArchiveSha256 = "b12a2c4ee8be317422451fc7dcf8ee20a71b5ea7ef9ad73ddd825a25316227a5"
$tempRoot = if (-not [string]::IsNullOrWhiteSpace($env:RUNNER_TEMP)) {
  $env:RUNNER_TEMP
} elseif (-not [string]::IsNullOrWhiteSpace($env:TEMP)) {
  $env:TEMP
} else {
  [System.IO.Path]::GetTempPath()
}
$temp = Join-Path $tempRoot "lajumirror-scrcpy"
$destinationPath = [System.IO.Path]::GetFullPath((Join-Path (Get-Location) $Destination))
$existingScrcpy = Join-Path $destinationPath "scrcpy.exe"
$existingAdb = Join-Path $destinationPath "adb.exe"

if ((Test-Path $existingScrcpy) -and (Test-Path $existingAdb)) {
  $existingVersionText = (& $existingScrcpy --version 2>&1 | Out-String).Trim()
  $existingVersionExitCode = $LASTEXITCODE
  if ($existingVersionExitCode -eq 0 -and $existingVersionText -match [regex]::Escape($expectedVersion.TrimStart("v"))) {
    Write-Host "Pinned scrcpy $expectedVersion and ADB tools are already present."
    Write-Host "Tool directory: $destinationPath"
    return
  }
  Write-Host "Replacing missing, invalid, or unpinned local Android tools."
}

Write-Host "Querying the pinned official scrcpy release $expectedVersion..."
$headers = @{
  "Accept" = "application/vnd.github+json"
  "User-Agent" = "LajuMirror-Windows-Build"
}

# The token is used only for GitHub API metadata. It is never forwarded to the public asset host.
if (-not [string]::IsNullOrWhiteSpace($env:GITHUB_TOKEN)) {
  $headers["Authorization"] = "Bearer $env:GITHUB_TOKEN"
}
$release = Invoke-RestMethod -Uri "$repo/releases/tags/$expectedVersion" -Headers $headers
if ($release.tag_name -ne $expectedVersion) {
  throw "Expected scrcpy $expectedVersion, but GitHub returned $($release.tag_name)."
}

$expectedAssetName = "scrcpy-win64-$expectedVersion.zip"
$asset = $release.assets | Where-Object { $_.name -eq $expectedAssetName } | Select-Object -First 1
if (-not $asset) {
  throw "The pinned release does not contain $expectedAssetName."
}
$expectedDigest = "sha256:$expectedArchiveSha256"
if ($asset.digest -ne $expectedDigest) {
  throw "The upstream GitHub release digest metadata does not match the pinned scrcpy archive digest."
}

if (Test-Path $temp) { Remove-Item $temp -Recurse -Force }
New-Item -ItemType Directory -Path $temp -Force | Out-Null
New-Item -ItemType Directory -Path $destinationPath -Force | Out-Null

$zipPath = Join-Path $temp $asset.name
Write-Host "Downloading $($asset.name) from the official scrcpy release..."
$downloadHeaders = @{
  "User-Agent" = "LajuMirror-Windows-Build"
}
Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $zipPath -Headers $downloadHeaders

$actualHash = (Get-FileHash -LiteralPath $zipPath -Algorithm SHA256).Hash.ToLowerInvariant()
if ($actualHash -ne $expectedArchiveSha256) {
  throw "scrcpy archive SHA-256 verification failed. Expected $expectedArchiveSha256; received $actualHash."
}
Write-Host "Verified pinned scrcpy archive SHA-256: $actualHash"

$extractPath = Join-Path $temp "extracted"
Expand-Archive -LiteralPath $zipPath -DestinationPath $extractPath -Force
$scrcpyExe = Get-ChildItem -Path $extractPath -Filter "scrcpy.exe" -Recurse -File | Select-Object -First 1
if (-not $scrcpyExe) {
  throw "The downloaded archive does not contain scrcpy.exe."
}

$sourceDirectory = $scrcpyExe.Directory.FullName
Get-ChildItem -Path $destinationPath -Force -ErrorAction SilentlyContinue |
  Remove-Item -Recurse -Force
Get-ChildItem -Path $sourceDirectory -Force |
  Copy-Item -Destination $destinationPath -Recurse -Force

$required = @("scrcpy.exe", "adb.exe")
foreach ($name in $required) {
  if (-not (Test-Path -LiteralPath (Join-Path $destinationPath $name) -PathType Leaf)) {
    throw "Required file $name is missing from the pinned scrcpy package."
  }
}

$installedVersionText = (& (Join-Path $destinationPath "scrcpy.exe") --version 2>&1 | Out-String).Trim()
if ($LASTEXITCODE -ne 0 -or $installedVersionText -notmatch [regex]::Escape($expectedVersion.TrimStart("v"))) {
  throw "The installed scrcpy executable does not report the pinned version $expectedVersion."
}
$adbVersionText = (& (Join-Path $destinationPath "adb.exe") --version 2>&1 | Out-String).Trim()
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($adbVersionText)) {
  throw "The bundled ADB executable failed its version smoke check."
}

Write-Host "Prepared scrcpy $expectedVersion and verified bundled ADB."
Write-Host "Tool directory: $destinationPath"
if ($env:GITHUB_STEP_SUMMARY) {
  @(
    "### Windows runtime tools"
    ""
    "- scrcpy release: [$($release.tag_name)]($($release.html_url))"
    "- Package: $($asset.name)"
    "- Pinned SHA-256: $expectedArchiveSha256"
    "- scrcpy and ADB version checks: passed."
  ) | Out-File -FilePath $env:GITHUB_STEP_SUMMARY -Append -Encoding utf8
}
