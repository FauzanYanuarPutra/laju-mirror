param(
    [int]$Hours = 24,
    [switch]$Elevated,
    [string]$OutputPath,
    [switch]$ConsentGiven,
    [switch]$NoElevation
)

$ErrorActionPreference = "Continue"

function Test-IsAdministrator {
    try {
        $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = New-Object -TypeName Security.Principal.WindowsPrincipal -ArgumentList $identity
        return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    }
    catch { return $false }
}

function Add-Section {
    param([System.Collections.Generic.List[string]]$Lines, [string]$Title)
    $Lines.Add("")
    $Lines.Add(("=" * 76))
    $Lines.Add($Title)
    $Lines.Add(("=" * 76))
}

function Get-EventDataMap {
    param($EventRecord)
    $map = @{}
    try {
        [xml]$eventXml = $EventRecord.ToXml()
        foreach ($node in $eventXml.Event.EventData.Data) {
            $fieldName = $null
            if ($node.Attributes -and $node.Attributes["Name"]) {
                $fieldName = [string]$node.Attributes["Name"].Value
            }
            if ([string]::IsNullOrWhiteSpace($fieldName)) {
                $fieldName = "Data" + ($map.Count + 1)
            }
            $map[$fieldName] = [string]$node.InnerText
        }
    }
    catch { $map["ParseError"] = $_.Exception.Message }
    return $map
}

if ($Hours -lt 1 -or $Hours -gt 720) {
    Write-Host "Hours must be between 1 and 720." -ForegroundColor Red
    exit 2
}

if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    $desktop = [Environment]::GetFolderPath("Desktop")
    if ([string]::IsNullOrWhiteSpace($desktop) -or -not (Test-Path $desktop)) { $desktop = $env:TEMP }
    $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $OutputPath = Join-Path $desktop "LajuMirror-Windows-Diagnostics-$stamp.txt"
}

Write-Host ""
Write-Host "LajuMirror Windows diagnostics" -ForegroundColor Cyan
Write-Host "Read-only: this tool inspects system details and recent application-control logs."
Write-Host "It does NOT whitelist files, change Windows security, disable protections, or install software."
Write-Host "Review the saved report before sharing it; event messages can contain local file paths and device or user names."
Write-Host ""
if (-not $ConsentGiven) {
    $consent = Read-Host "Do you consent to collect this diagnostic report? Type YES to continue"
    if ($consent -cne "YES") {
        Write-Host "No report was collected." -ForegroundColor Yellow
        exit 0
    }
}

$isAdmin = Test-IsAdministrator
$lines = New-Object 'System.Collections.Generic.List[string]'
$lines.Add("LajuMirror Windows diagnostics")
$lines.Add("Collected: $(Get-Date -Format o)")
$lines.Add("Computer: $env:COMPUTERNAME")
$lines.Add("User: $env:USERNAME")
$lines.Add("Administrator process: $isAdmin")
$lines.Add("Lookback hours: $Hours")
$lines.Add("Read-only diagnostic. No App Control policy was changed.")

Add-Section -Lines $lines -Title "WINDOWS"
try {
    $os = Get-CimInstance Win32_OperatingSystem
    $lines.Add("Caption: $($os.Caption)")
    $lines.Add("Version: $($os.Version)")
    $lines.Add("Build: $($os.BuildNumber)")
    $lines.Add("Architecture: $($os.OSArchitecture)")
}
catch { $lines.Add("Could not read OS information: $($_.Exception.Message)") }

Add-Section -Lines $lines -Title "DEVELOPMENT TOOL VERSIONS"
foreach ($tool in @("node", "npm", "rustc", "cargo", "rustup", "git")) {
    $command = Get-Command $tool -ErrorAction SilentlyContinue
    if ($null -eq $command) {
        $lines.Add($tool + " : not found")
        continue
    }
    try {
        $versionOutput = & $command.Path --version 2>&1 | Select-Object -First 2
        $lines.Add($tool + " path: " + $command.Path)
        foreach ($versionLine in $versionOutput) { $lines.Add("  " + [string]$versionLine) }
    }
    catch { $lines.Add($tool + " : version check failed: " + $_.Exception.Message) }
}

Add-Section -Lines $lines -Title "APPLICATION CONTROL POLICY SNAPSHOT"
$adminRetryNeeded = $false
$ciTool = Join-Path $env:windir "System32\CiTool.exe"
if (Test-Path $ciTool) {
    try {
        $policyOutput = & $ciTool -lp -json 2>&1
        $lines.Add("CiTool -lp -json output:")
        foreach ($line in $policyOutput) { $lines.Add([string]$line) }
    }
    catch {
        $toolError = $_.Exception.Message
        $lines.Add("CiTool query failed: " + $toolError)
        if ($toolError -match "(?i)access is denied|unauthori[sz]ed|not allowed|privilege") { $adminRetryNeeded = $true }
    }
}
else { $lines.Add("CiTool.exe was not found. This can depend on Windows version.") }

$policyRegistry = "HKLM:\SYSTEM\CurrentControlSet\Control\CI\Policy"
try {
    $policy = Get-ItemProperty -Path $policyRegistry -ErrorAction Stop
    $lines.Add("Code Integrity policy registry values (read-only):")
    foreach ($name in @("VerifiedAndReputablePolicyState", "SkuPolicyRequired", "PolicyOptions")) {
        if ($null -ne $policy.$name) { $lines.Add("  " + $name + " = " + $policy.$name) }
    }
}
catch { $lines.Add("Code Integrity policy registry values unavailable: " + $_.Exception.Message) }

try {
    $appId = Get-Service -Name AppIDSvc -ErrorAction Stop
    $lines.Add("AppIDSvc status: $($appId.Status)")
    $lines.Add("AppIDSvc start type: $($appId.StartType)")
}
catch { $lines.Add("AppIDSvc information unavailable: " + $_.Exception.Message) }

Add-Section -Lines $lines -Title "CODE INTEGRITY BLOCK / AUDIT EVENTS"
$startTime = (Get-Date).AddHours(-$Hours)
$codeIntegrityEvents = @()
$ciLogName = "Microsoft-Windows-CodeIntegrity/Operational"

try {
    $codeIntegrityEvents = @(
        Get-WinEvent -FilterHashtable @{
            LogName = $ciLogName
            Id = @(3076, 3077, 3089, 3033, 3034)
            StartTime = $startTime
        } -MaxEvents 100 -ErrorAction Stop
    )
    if ($codeIntegrityEvents.Count -eq 0) { $lines.Add("No matching Code Integrity events found in the last $Hours hour(s).") }
    foreach ($eventRecord in $codeIntegrityEvents) {
        $data = Get-EventDataMap -EventRecord $eventRecord
        $lines.Add("")
        $lines.Add("Time: " + $eventRecord.TimeCreated.ToString("o"))
        $lines.Add("Event ID: " + $eventRecord.Id)
        $lines.Add("Record ID: " + $eventRecord.RecordId)
        foreach ($key in $data.Keys) { $lines.Add("  " + $key + ": " + $data[$key]) }
        if (-not [string]::IsNullOrWhiteSpace($eventRecord.Message)) {
            $lines.Add("Message:")
            $lines.Add($eventRecord.Message)
        }
    }
}
catch {
    $message = $_.Exception.Message
    $lines.Add("Could not read Code Integrity events: " + $message)
    if ($message -match "(?i)access is denied|unauthori[sz]ed|not allowed|privilege") { $adminRetryNeeded = $true }
}

Add-Section -Lines $lines -Title "APPLOCKER MSI AND SCRIPT EVENTS"
$appLockerEvents = @()
try {
    $appLockerEvents = @(
        Get-WinEvent -FilterHashtable @{
            LogName = "Microsoft-Windows-AppLocker/MSI and Script"
            StartTime = $startTime
        } -MaxEvents 50 -ErrorAction Stop
    )
    if ($appLockerEvents.Count -eq 0) { $lines.Add("No AppLocker MSI and Script events found in the selected period.") }
    foreach ($eventRecord in $appLockerEvents) {
        $lines.Add("")
        $lines.Add("Time: " + $eventRecord.TimeCreated.ToString("o") + " | Event ID: " + $eventRecord.Id)
        if (-not [string]::IsNullOrWhiteSpace($eventRecord.Message)) { $lines.Add($eventRecord.Message) }
    }
}
catch {
    $appLockerError = $_.Exception.Message
    $lines.Add("Could not read AppLocker MSI and Script events: " + $appLockerError)
    if ($appLockerError -match "(?i)access is denied|unauthori[sz]ed|not allowed|privilege") { $adminRetryNeeded = $true }
}

Add-Section -Lines $lines -Title "NEXT STEPS"
$lines.Add("1. Review Code Integrity event 3077 for enforced App Control blocks.")
$lines.Add("2. Event 3076 indicates a file that would be blocked under an audit policy.")
$lines.Add("3. Correlate event 3077 with event 3089 for signature and publisher information.")
$lines.Add("4. Ask the device administrator to review the exact blocked file and the active policy.")
$lines.Add("5. Do not disable Smart App Control, App Control, AppLocker, antivirus, or device security.")
$lines.Add("6. LajuMirror cannot grant itself an App Control exception from a normal user prompt.")

try {
    $parent = Split-Path -Parent $OutputPath
    if (-not (Test-Path $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    $lines | Out-File -FilePath $OutputPath -Encoding utf8 -Force
    Write-Host ""
    Write-Host "Report saved to:" -ForegroundColor Green
    Write-Host $OutputPath -ForegroundColor White
}
catch {
    Write-Host ("Could not save report: " + $_.Exception.Message) -ForegroundColor Red
    exit 3
}

if ($adminRetryNeeded -and -not $isAdmin -and -not $Elevated -and -not $NoElevation) {
    Write-Host ""
    $elevate = Read-Host "Windows denied access to some event logs. Re-run this read-only diagnostic as administrator? UAC will appear. Type YES to continue"
    if ($elevate -ceq "YES") {
        $quotedScript = '"' + $PSCommandPath + '"'
        $quotedOutput = '"' + $OutputPath + '"'
        $argumentList = "-NoProfile -File $quotedScript -Hours $Hours -Elevated -OutputPath $quotedOutput"
        try { Start-Process -FilePath "powershell.exe" -Verb RunAs -ArgumentList $argumentList }
        catch { Write-Host ("Could not start the elevated diagnostic: " + $_.Exception.Message) -ForegroundColor Red }
    }
}

Write-Host ""
Write-Host "UAC consent only allows this diagnostic to read additional information. It does not authorize or unblock any executable." -ForegroundColor Yellow
