param(
  [string]$Destination = "src-tauri/resources/tools/scrcpy"
)

$ErrorActionPreference = "Stop"
$repo = "https://api.github.com/repos/Genymobile/scrcpy"
$tempRoot = if (-not [string]::IsNullOrWhiteSpace($env:RUNNER_TEMP)) {
  $env:RUNNER_TEMP
} elseif (-not [string]::IsNullOrWhiteSpace($env:TEMP)) {
  $env:TEMP
} else {
  [System.IO.Path]::GetTempPath()
}
$temp = Join-Path $tempRoot "lajumirror-scrcpy"
$destinationPath = [System.IO.Path]::GetFullPath((Join-Path (Get-Location) $Destination))

if ((Test-Path (Join-Path $destinationPath "scrcpy.exe")) -and
    (Test-Path (Join-Path $destinationPath "adb.exe"))) {
  Write-Host "Official scrcpy and ADB tools are already present."
  Write-Host "Tool directory: $destinationPath"
  exit 0
}

Write-Host "Querying the official scrcpy release..."
$headers = @{
  "Accept" = "application/vnd.github+json"
  "User-Agent" = "LajuMirror-Windows-Build"
}

# Prefer the per-run GitHub token to avoid shared anonymous API rate limits.
# The token is never written to the workflow log or included in artifacts.
if (-not [string]::IsNullOrWhiteSpace($env:GITHUB_TOKEN)) {
  $headers["Authorization"] = "Bearer $env:GITHUB_TOKEN"
}
$release = Invoke-RestMethod -Uri "$repo/releases/latest" -Headers $headers
$asset = $release.assets | Where-Object { $_.name -match "^scrcpy-win64-.*\.zip$" } | Select-Object -First 1

if (-not $asset) {
  throw "No official Windows 64-bit scrcpy ZIP was found in release $($release.tag_name)."
}

if (Test-Path $temp) { Remove-Item $temp -Recurse -Force }
New-Item -ItemType Directory -Path $temp -Force | Out-Null
New-Item -ItemType Directory -Path $destinationPath -Force | Out-Null

$zipPath = Join-Path $temp $asset.name
Write-Host "Downloading $($asset.name) from the official scrcpy release..."
# The archive is public. Do not forward the repository-scoped API token to the asset host.
$downloadHeaders = @{
  "User-Agent" = "LajuMirror-Windows-Build"
}
Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $zipPath -Headers $downloadHeaders

if ($asset.digest -and $asset.digest.StartsWith("sha256:")) {
  $expectedHash = $asset.digest.Substring(7).ToLowerInvariant()
  $actualHash = (Get-FileHash -Path $zipPath -Algorithm SHA256).Hash.ToLowerInvariant()
  if ($actualHash -ne $expectedHash) {
    throw "scrcpy archive SHA-256 verification failed."
  }
  Write-Host "Verified scrcpy archive SHA-256."
} else {
  Write-Warning "GitHub did not provide an asset SHA-256 digest; download integrity could not be independently checked."
}

$extractPath = Join-Path $temp "extracted"
Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force
$scrcpyExe = Get-ChildItem -Path $extractPath -Filter "scrcpy.exe" -Recurse -File | Select-Object -First 1

if (-not $scrcpyExe) {
  throw "The downloaded archive does not contain scrcpy.exe."
}

$sourceDirectory = $scrcpyExe.Directory.FullName
Get-ChildItem -Path $sourceDirectory -Force | Copy-Item -Destination $destinationPath -Recurse -Force

$required = @("scrcpy.exe", "adb.exe")
foreach ($name in $required) {
  if (-not (Test-Path (Join-Path $destinationPath $name))) {
    throw "Required file $name is missing from the downloaded scrcpy package."
  }
}

Write-Host "Prepared scrcpy $($release.tag_name) and its bundled ADB tools."
Write-Host "Tool directory: $destinationPath"
if ($env:GITHUB_STEP_SUMMARY) {
  @(
    "### Windows tools"
    ""
    "- scrcpy release: [$($release.tag_name)]($($release.html_url))"
    "- Package: $($asset.name)"
    "- ADB and scrcpy executables verified."
  ) | Out-File -FilePath $env:GITHUB_STEP_SUMMARY -Append -Encoding utf8
}