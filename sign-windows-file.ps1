$ErrorActionPreference = "Stop"

$signer = Join-Path $PSScriptRoot "src-tauri/sign-windows-file.ps1"
if (-not (Test-Path -LiteralPath $signer -PathType Leaf)) {
    throw "LajuMirror signing helper was not found: $signer"
}

if ($args.Count -ne 1) {
    throw "Expected exactly one binary path argument."
}

& $signer -Path $args[0]
if ($LASTEXITCODE -and $LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}
