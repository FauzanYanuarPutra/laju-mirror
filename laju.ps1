[CmdletBinding()]
param(
    [ValidateSet("Gui", "QuickStart", "Build", "Diagnose")]
    [string]$Mode = "Gui"
)

$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path -Parent $PSCommandPath
Set-Location $RepoRoot

function Write-Stage {
    param([string]$Message, [string]$Color = "Cyan")
    Write-Host ""
    Write-Host ("=" * 68) -ForegroundColor DarkGreen
    Write-Host ("  " + $Message) -ForegroundColor $Color
    Write-Host ("=" * 68) -ForegroundColor DarkGreen
}

function Invoke-Npm {
    param([string[]]$Arguments)
    & npm.cmd @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "npm $($Arguments -join ' ') failed with exit code $LASTEXITCODE."
    }
}

function Test-AppControlEnforced {
    $policyPath = "HKLM:\SYSTEM\CurrentControlSet\Control\CI\Policy"
    try {
        $policy = Get-ItemProperty -Path $policyPath -Name "VerifiedAndReputablePolicyState" -ErrorAction Stop
        return ([int]$policy.VerifiedAndReputablePolicyState -eq 1)
    } catch {
        return $false
    }
}

function Start-RemoteBuild {
    $url = "https://github.com/FauzanYanuarPutra/laju-mirror/actions/workflows/ci.yml"
    Write-Host ""
    Write-Host "Windows Application Control is enforcing a policy on this machine." -ForegroundColor Yellow
    Write-Host "Local Cargo build scripts may be blocked with error 4551." -ForegroundColor Yellow
    Write-Host "No Windows security settings will be changed." -ForegroundColor Green
    Write-Host "The official Windows build runs on a GitHub-hosted runner."
    Write-Host "On the Actions page, select Run workflow and choose the main branch."
    Start-Process $url
}

function Invoke-Pipeline {
    Write-Stage "LajuMirror smart setup"

    foreach ($tool in @("node", "npm")) {
        if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) {
            throw "$tool is missing. Install Node.js LTS from https://nodejs.org/ and reopen this launcher."
        }
    }
    Write-Host ("Node.js: " + (& node --version)) -ForegroundColor Green
    Write-Host ("npm: " + (& npm.cmd --version)) -ForegroundColor Green

    if ($Mode -eq "Diagnose") {
        Write-Stage "Read-only Windows diagnostics"
        & (Join-Path $RepoRoot "scripts/windows-diagnostics.ps1") -ConsentGiven -NoElevation
        if ($LASTEXITCODE -ne 0) { throw "Windows diagnostics failed." }
        return
    }

    Write-Stage "Install project dependencies"
    Invoke-Npm @("install", "--no-audit", "--no-fund", "--no-package-lock")

    Write-Stage "Validate frontend"
    Invoke-Npm @("run", "check")
    Invoke-Npm @("run", "build")

    if (Test-AppControlEnforced) {
        Start-RemoteBuild
        return
    }

    foreach ($tool in @("rustc", "cargo")) {
        if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) {
            throw "Rust is missing. Install Rust stable from https://rustup.rs/, then reopen this launcher."
        }
    }
    Write-Host ("Rust: " + (& rustc --version)) -ForegroundColor Green
    Write-Host ("Cargo: " + (& cargo --version)) -ForegroundColor Green

    $toolsDirectory = Join-Path $RepoRoot "src-tauri/resources/tools/scrcpy"
    if (-not ((Test-Path (Join-Path $toolsDirectory "scrcpy.exe")) -and
              (Test-Path (Join-Path $toolsDirectory "adb.exe")))) {
        Write-Stage "Download official ADB and scrcpy tools"
        & (Join-Path $RepoRoot "scripts/prepare-windows-tools.ps1")
        if ($LASTEXITCODE -ne 0) { throw "Could not prepare official Android tools." }
    } else {
        Write-Host "Official ADB and scrcpy tools are already installed." -ForegroundColor Green
    }

    Write-Stage "Generate application icons"
    Invoke-Npm @("run", "tauri", "icon", "src-tauri/icons/icon.svg")

    if ($Mode -eq "Build") {
        Write-Stage "Build Windows installer"
        Invoke-Npm @("run", "tauri", "build", "--", "--bundles", "msi,nsis")
        Write-Host "Installer output: src-tauri/target/release/bundle" -ForegroundColor Green
    } else {
        Write-Stage "Start LajuMirror desktop GUI"
        Invoke-Npm @("run", "tauri", "dev")
    }
}

if ($Mode -ne "Gui") {
    try {
        Invoke-Pipeline
        exit 0
    } catch {
        Write-Host ""
        Write-Host ("LajuMirror task failed: " + $_.Exception.Message) -ForegroundColor Red
        if ($_.Exception.Message -match "(?i)4551|Application Control|blocked") {
            Write-Host "Opening the official remote Windows build workflow." -ForegroundColor Yellow
            Start-RemoteBuild
        } else {
            Write-Host "Run the read-only diagnostics from the LajuMirror control panel for more detail." -ForegroundColor Yellow
        }
        exit 1
    }
}

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

$form = New-Object System.Windows.Forms.Form
$form.Text = "LajuMirror Control Center"
$form.StartPosition = "CenterScreen"
$form.Size = New-Object System.Drawing.Size(820, 690)
$form.MinimumSize = New-Object System.Drawing.Size(820, 690)
$form.MaximumSize = New-Object System.Drawing.Size(820, 690)
$form.BackColor = [System.Drawing.Color]::FromArgb(10, 20, 14)
$form.ForeColor = [System.Drawing.Color]::FromArgb(226, 241, 230)
$form.Font = New-Object System.Drawing.Font("Segoe UI", 9)

$header = New-Object System.Windows.Forms.Panel
$header.Location = New-Object System.Drawing.Point(0, 0)
$header.Size = New-Object System.Drawing.Size(804, 112)
$header.BackColor = [System.Drawing.Color]::FromArgb(17, 43, 28)
$form.Controls.Add($header)

$brand = New-Object System.Windows.Forms.Label
$brand.Text = "LAJUMIRROR"
$brand.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 23, [System.Drawing.FontStyle]::Bold)
$brand.ForeColor = [System.Drawing.Color]::FromArgb(133, 225, 161)
$brand.AutoSize = $true
$brand.Location = New-Object System.Drawing.Point(28, 19)
$header.Controls.Add($brand)

$subtitle = New-Object System.Windows.Forms.Label
$subtitle.Text = "WINDOWS CONTROL CENTER  |  ANDROID USB / WI-FI"
$subtitle.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$subtitle.ForeColor = [System.Drawing.Color]::FromArgb(166, 197, 176)
$subtitle.AutoSize = $true
$subtitle.Location = New-Object System.Drawing.Point(31, 66)
$header.Controls.Add($subtitle)

$status = New-Object System.Windows.Forms.Label
$nodeStatus = if (Get-Command node -ErrorAction SilentlyContinue) { "Node.js OK" } else { "Node.js missing" }
$npmStatus = if (Get-Command npm -ErrorAction SilentlyContinue) { "npm OK" } else { "npm missing" }
$rustStatus = if (Get-Command rustc -ErrorAction SilentlyContinue) { "Rust OK" } else { "Rust missing" }
$cargoStatus = if (Get-Command cargo -ErrorAction SilentlyContinue) { "Cargo OK" } else { "Cargo missing" }
$appControl = if (Test-AppControlEnforced) { "Windows App Control: enforcing" } else { "Windows App Control: not detected" }
$status.Text = ($nodeStatus + "   |   " + $npmStatus + "   |   " + $rustStatus + "   |   " + $cargoStatus + [Environment]::NewLine + $appControl)
$status.Location = New-Object System.Drawing.Point(30, 133)
$status.Size = New-Object System.Drawing.Size(740, 48)
$status.ForeColor = [System.Drawing.Color]::FromArgb(163, 202, 176)
$form.Controls.Add($status)

$intro = New-Object System.Windows.Forms.Label
$intro.Text = "Satu panel untuk menyiapkan tools resmi, memeriksa proyek, menjalankan GUI, atau membuat installer Windows."
$intro.Location = New-Object System.Drawing.Point(30, 195)
$intro.Size = New-Object System.Drawing.Size(735, 42)
$intro.ForeColor = [System.Drawing.Color]::FromArgb(210, 226, 215)
$form.Controls.Add($intro)

$consent1 = New-Object System.Windows.Forms.CheckBox
$consent1.Text = "Saya setuju mengunduh ADB dan scrcpy dari rilis resmi Genymobile ke folder proyek."
$consent1.Location = New-Object System.Drawing.Point(31, 252)
$consent1.Size = New-Object System.Drawing.Size(735, 28)
$consent1.ForeColor = [System.Drawing.Color]::FromArgb(220, 237, 225)
$form.Controls.Add($consent1)

$consent2 = New-Object System.Windows.Forms.CheckBox
$consent2.Text = "Saya memahami ADB dapat mendeteksi HP dan scrcpy dapat mengendalikan layar setelah saya menyetujui izin di HP."
$consent2.Location = New-Object System.Drawing.Point(31, 283)
$consent2.Size = New-Object System.Drawing.Size(735, 38)
$consent2.ForeColor = [System.Drawing.Color]::FromArgb(220, 237, 225)
$form.Controls.Add($consent2)

$diagnosticConsent = New-Object System.Windows.Forms.CheckBox
$diagnosticConsent.Text = "Saya menyetujui pengumpulan laporan diagnostik Windows yang bersifat read-only."
$diagnosticConsent.Location = New-Object System.Drawing.Point(31, 327)
$diagnosticConsent.Size = New-Object System.Drawing.Size(735, 28)
$diagnosticConsent.ForeColor = [System.Drawing.Color]::FromArgb(167, 198, 176)
$form.Controls.Add($diagnosticConsent)

$note = New-Object System.Windows.Forms.Label
$note.Text = "Izin USB debugging atau Wireless Debugging ditampilkan Android langsung di HP. Windows tidak bisa menyetujui dialog itu untukmu. LajuMirror tidak meminta Administrator dan tidak mengubah keamanan Windows."
$note.Location = New-Object System.Drawing.Point(31, 367)
$note.Size = New-Object System.Drawing.Size(735, 65)
$note.ForeColor = [System.Drawing.Color]::FromArgb(125, 164, 139)
$form.Controls.Add($note)

function New-ActionButton {
    param([string]$Text, [int]$X, [int]$Y, [int]$Width, [System.Drawing.Color]$Background)
    $button = New-Object System.Windows.Forms.Button
    $button.Text = $Text
    $button.Location = New-Object System.Drawing.Point($X, $Y)
    $button.Size = New-Object System.Drawing.Size($Width, 43)
    $button.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $button.FlatAppearance.BorderSize = 0
    $button.BackColor = $Background
    $button.ForeColor = [System.Drawing.Color]::White
    $button.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 9, [System.Drawing.FontStyle]::Bold)
    $form.Controls.Add($button)
    return $button
}

$quick = New-ActionButton "SETUP & RUN GUI" 31 450 350 ([System.Drawing.Color]::FromArgb(31, 148, 91))
$build = New-ActionButton "BUILD WINDOWS INSTALLER" 397 450 369 ([System.Drawing.Color]::FromArgb(34, 102, 72))
$diagnose = New-ActionButton "WINDOWS DIAGNOSTICS" 31 506 350 ([System.Drawing.Color]::FromArgb(47, 67, 54))
$workflow = New-ActionButton "OPEN REMOTE WINDOWS BUILD" 397 506 369 ([System.Drawing.Color]::FromArgb(47, 67, 54))

$readme = New-Object System.Windows.Forms.LinkLabel
$readme.Text = "README and setup guide"
$readme.LinkColor = [System.Drawing.Color]::FromArgb(126, 210, 154)
$readme.ActiveLinkColor = [System.Drawing.Color]::White
$readme.Location = New-Object System.Drawing.Point(31, 575)
$readme.Size = New-Object System.Drawing.Size(250, 24)
$form.Controls.Add($readme)

$footer = New-Object System.Windows.Forms.Label
$footer.Text = "LajuMirror by Lajukan  |  Local-first  |  No cloud relay"
$footer.Location = New-Object System.Drawing.Point(31, 612)
$footer.Size = New-Object System.Drawing.Size(735, 22)
$footer.ForeColor = [System.Drawing.Color]::FromArgb(102, 135, 113)
$form.Controls.Add($footer)

$startTask = {
    param($TaskMode)
    $commandLine = '-NoProfile -ExecutionPolicy Bypass -File "{0}" -Mode {1}' -f $PSCommandPath, $TaskMode
    Start-Process -FilePath "powershell.exe" -ArgumentList $commandLine -WorkingDirectory $RepoRoot
}

$quick.Enabled = $false
$build.Enabled = $false
$consentChanged = {
    $allowed = $consent1.Checked -and $consent2.Checked
    $quick.Enabled = $allowed
    $build.Enabled = $allowed
}
$consent1.Add_CheckedChanged($consentChanged)
$consent2.Add_CheckedChanged($consentChanged)
$quick.Add_Click({
    & $startTask "QuickStart"
    [System.Windows.Forms.MessageBox]::Show("Setup berjalan di jendela PowerShell baru. Ikuti hasil pemeriksaan di sana.", "LajuMirror", "OK", "Information") | Out-Null
})
$build.Add_Click({
    & $startTask "Build"
    [System.Windows.Forms.MessageBox]::Show("Proses build berjalan di jendela PowerShell baru. Installer akan dibuat setelah pemeriksaan berhasil.", "LajuMirror", "OK", "Information") | Out-Null
})
$diagnose.Add_Click({
    if (-not $diagnosticConsent.Checked) {
        [System.Windows.Forms.MessageBox]::Show("Centang persetujuan diagnostik terlebih dahulu.", "Persetujuan diperlukan", "OK", "Warning") | Out-Null
        return
    }
    & $startTask "Diagnose"
})
$workflow.Add_Click({
    Start-Process "https://github.com/FauzanYanuarPutra/laju-mirror/actions/workflows/ci.yml"
})
$readme.Add_Click({
    Start-Process "https://github.com/FauzanYanuarPutra/laju-mirror#quick-start"
})
[void]$form.ShowDialog()
