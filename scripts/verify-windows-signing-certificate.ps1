$ErrorActionPreference = "Stop"

$encodedPfx = $env:WINDOWS_SIGNING_PFX_BASE64
$password = $env:WINDOWS_SIGNING_PFX_PASSWORD

if ([string]::IsNullOrWhiteSpace($encodedPfx) -or [string]::IsNullOrWhiteSpace($password)) {
    throw "A trusted Windows code-signing PFX and password are required for a public release."
}

$bytes = [Convert]::FromBase64String($encodedPfx)
$certificate = $null
$chain = $null

try {
    $flags = [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::EphemeralKeySet
    $certificate = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new(
        $bytes, $password, $flags
    )

    if (-not $certificate.HasPrivateKey) {
        throw "The configured PFX does not contain its private key."
    }
    $now = Get-Date
    if ($certificate.NotBefore -gt $now -or $certificate.NotAfter -le $now) {
        throw "The configured code-signing certificate is not currently valid."
    }

    $ekuExtension = $certificate.Extensions |
        Where-Object { $_.Oid.Value -eq "2.5.29.37" } |
        Select-Object -First 1
    if ($null -eq $ekuExtension) {
        throw "The configured certificate has no Extended Key Usage extension for code signing."
    }

    $typedEku = [System.Security.Cryptography.X509Certificates.X509EnhancedKeyUsageExtension]::new(
        $ekuExtension, $ekuExtension.Critical
    )
    $ekuValues = @($typedEku.EnhancedKeyUsages | ForEach-Object { $_.Value })
    if ($ekuValues -notcontains "1.3.6.1.5.5.7.3.3") {
        throw "The configured certificate does not include the Code Signing EKU."
    }

    $chain = [System.Security.Cryptography.X509Certificates.X509Chain]::new()
    $chain.ChainPolicy.RevocationMode = [System.Security.Cryptography.X509Certificates.X509RevocationMode]::Online
    $chain.ChainPolicy.RevocationFlag = [System.Security.Cryptography.X509Certificates.X509RevocationFlag]::ExcludeRoot
    if (-not $chain.Build($certificate)) {
        $status = ($chain.ChainStatus | ForEach-Object { $_.StatusInformation.Trim() }) -join "; "
        throw "The configured certificate chain is not trusted or could not be checked: $status"
    }

    Write-Host "A valid Code Signing certificate with a private key and trusted chain is configured." -ForegroundColor Green
}
finally {
    if ($null -ne $chain) { $chain.Dispose() }
    if ($null -ne $certificate) { $certificate.Dispose() }
    if ($null -ne $bytes) { [Array]::Clear($bytes, 0, $bytes.Length) }
}
