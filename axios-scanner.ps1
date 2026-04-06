<#
.SYNOPSIS
    Axios Supply Chain Attack Scanner
    Checks if your computer was affected by the axios npm hack (March 31, 2026).

.DESCRIPTION
    Scans for compromised axios versions (1.14.1 / 0.30.4), the plain-crypto-js
    RAT dropper, backdoor files, network connections to the attacker's server,
    and persistence mechanisms. Generates a log file and a final report.

.AUTHOR
    Ahmed Taha (@SufficientDaikon)
#>

param(
    [switch]$Fix,
    [string]$ScanPath
)

# --- Setup ---

$ErrorActionPreference = "SilentlyContinue"

$scriptDir  = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $scriptDir) { $scriptDir = Get-Location }

$timestamp  = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$logFile    = Join-Path $scriptDir "axios-scan-log_$timestamp.txt"
$reportFile = Join-Path $scriptDir "axios-scan-report_$timestamp.txt"

$MALICIOUS  = @("1.14.1", "0.30.4")
$C2_DOMAIN  = "sfrclak.com"
$C2_IP      = "142.11.206.73"
$DROPPER    = "plain-crypto-js"

$totalChecks    = 0
$passedChecks   = 0
$failedChecks   = 0
$warningChecks  = 0
$compromised    = $false
$allFindings    = [System.Collections.ArrayList]::new()

# --- Logging ---

function Log {
    param([string]$Message, [string]$Level = "INFO")

    $time = Get-Date -Format "HH:mm:ss"
    $line = "[$time] [$Level] $Message"

    # Write to log file
    Add-Content -Path $logFile -Value $line -ErrorAction SilentlyContinue

    # Write to console with color
    switch ($Level) {
        "PASS" {
            Write-Host "  [" -NoNewline -ForegroundColor DarkGray
            Write-Host "PASS" -NoNewline -ForegroundColor Green
            Write-Host "] " -NoNewline -ForegroundColor DarkGray
            Write-Host $Message -ForegroundColor Green
        }
        "FAIL" {
            Write-Host "  [" -NoNewline -ForegroundColor DarkGray
            Write-Host "FAIL" -NoNewline -ForegroundColor Red
            Write-Host "] " -NoNewline -ForegroundColor DarkGray
            Write-Host $Message -ForegroundColor Red
        }
        "WARN" {
            Write-Host "  [" -NoNewline -ForegroundColor DarkGray
            Write-Host "WARN" -NoNewline -ForegroundColor Yellow
            Write-Host "] " -NoNewline -ForegroundColor DarkGray
            Write-Host $Message -ForegroundColor Yellow
        }
        "STEP" {
            Write-Host "  [ .. ] " -NoNewline -ForegroundColor DarkGray
            Write-Host $Message -ForegroundColor White
        }
        "HEAD" {
            Write-Host ""
            Write-Host "  $Message" -ForegroundColor Cyan
            Write-Host "  $('-' * $Message.Length)" -ForegroundColor DarkCyan
        }
        default {
            Write-Host "  [" -NoNewline -ForegroundColor DarkGray
            Write-Host "INFO" -NoNewline -ForegroundColor Gray
            Write-Host "] " -NoNewline -ForegroundColor DarkGray
            Write-Host $Message -ForegroundColor Gray
        }
    }
}

function Record {
    param([string]$Category, [string]$Result, [string]$Detail)

    $script:totalChecks++
    switch ($Result) {
        "PASS" { $script:passedChecks++ }
        "FAIL" { $script:failedChecks++; $script:compromised = $true }
        "WARN" { $script:warningChecks++ }
    }

    $allFindings.Add([PSCustomObject]@{
        Category = $Category
        Result   = $Result
        Detail   = $Detail
    }) | Out-Null

    Log $Detail $Result
}

# --- Banner ---

function Show-Banner {
    Write-Host ""
    Write-Host "  ============================================================" -ForegroundColor Cyan
    Write-Host "  |                                                          |" -ForegroundColor Cyan
    Write-Host "  |         AXIOS SUPPLY CHAIN ATTACK SCANNER               |" -ForegroundColor Cyan
    Write-Host "  |                                                          |" -ForegroundColor Cyan
    Write-Host "  |  Checks if your computer was affected by the axios      |" -ForegroundColor Cyan
    Write-Host "  |  npm package hack that happened on March 31, 2026.      |" -ForegroundColor Cyan
    Write-Host "  |                                                          |" -ForegroundColor Cyan
    Write-Host "  |  This scanner is safe to run. It only READS your        |" -ForegroundColor Cyan
    Write-Host "  |  files and checks your system. Nothing is changed       |" -ForegroundColor Cyan
    Write-Host "  |  unless you use the -Fix flag.                          |" -ForegroundColor Cyan
    Write-Host "  |                                                          |" -ForegroundColor Cyan
    Write-Host "  |  NOTE: You do NOT need Node.js or npm installed.        |" -ForegroundColor Cyan
    Write-Host "  |  This scanner works on any Windows computer.            |" -ForegroundColor Cyan
    Write-Host "  |                                                          |" -ForegroundColor Cyan
    Write-Host "  ============================================================" -ForegroundColor Cyan
    Write-Host ""
    Log "Scanner started"
    Log "Log file: $logFile"
    Log "Scan target: $(if ($ScanPath) { $ScanPath } else { $env:USERPROFILE })"
    Write-Host ""
}

# --- Phase 1: Axios Versions ---

function Phase1-AxiosVersions {
    Log "PHASE 1 of 6: Looking for axios installations on your computer..." "HEAD"
    Log "This finds every copy of the axios library and checks its version number." "STEP"

    $searchRoot = if ($ScanPath) { $ScanPath } else { $env:USERPROFILE }
    $axiosCount = 0
    $badCount   = 0

    # Search user profile
    Log "Searching your user folder..." "STEP"
    $pkgs = @(Get-ChildItem -Path $searchRoot -Filter "package.json" -Recurse -ErrorAction SilentlyContinue |
        Where-Object { $_.Directory.Name -eq "axios" })

    foreach ($pkg in $pkgs) {
        try {
            $json = Get-Content $pkg.FullName -Raw -ErrorAction Stop | ConvertFrom-Json
            if ($json.name -eq "axios") {
                $axiosCount++
                $ver = $json.version
                $loc = $pkg.DirectoryName

                if ($MALICIOUS -contains $ver) {
                    $badCount++
                    Record "AXIOS" "FAIL" "COMPROMISED: axios version $ver found at $loc"
                    if ($Fix) {
                        Remove-Item -Path $loc -Recurse -Force -ErrorAction SilentlyContinue
                        Log "REMOVED compromised axios at: $loc" "WARN"
                    }
                }
                else {
                    Record "AXIOS" "PASS" "Safe: axios $ver at $loc"
                }
            }
        }
        catch { }
    }

    # Search npm global (only if npm is installed)
    $hasNpm = $null
    try { $hasNpm = Get-Command npm -ErrorAction Stop } catch { }

    if ($hasNpm) {
        Log "Checking global npm packages..." "STEP"
        try {
            $npmRoot = & npm root -g 2>$null
            if ($npmRoot -and (Test-Path $npmRoot)) {
                $globalPkgs = @(Get-ChildItem -Path $npmRoot -Filter "package.json" -Recurse -ErrorAction SilentlyContinue |
                    Where-Object { $_.Directory.Name -eq "axios" })
                foreach ($pkg in $globalPkgs) {
                    try {
                        $json = Get-Content $pkg.FullName -Raw -ErrorAction Stop | ConvertFrom-Json
                        if ($json.name -eq "axios") {
                            $axiosCount++
                            $ver = $json.version
                            if ($MALICIOUS -contains $ver) {
                                $badCount++
                                Record "AXIOS" "FAIL" "COMPROMISED: axios $ver in global npm ($($pkg.DirectoryName))"
                            }
                            else {
                                Record "AXIOS" "PASS" "Safe: axios $ver (global npm)"
                            }
                        }
                    }
                    catch { }
                }
            }
        }
        catch { }
    }
    else {
        Log "Node.js/npm is not installed (skipping global npm check -- this is fine)" "INFO"
    }

    # Search npm cache
    Log "Checking npm download cache..." "STEP"
    $npmCachePath = Join-Path $env:LOCALAPPDATA "npm-cache"
    if (Test-Path $npmCachePath) {
        $cachePkgs = @(Get-ChildItem -Path $npmCachePath -Filter "package.json" -Recurse -ErrorAction SilentlyContinue |
            Where-Object { $_.Directory.Name -eq "axios" })
        foreach ($pkg in $cachePkgs) {
            try {
                $json = Get-Content $pkg.FullName -Raw -ErrorAction Stop | ConvertFrom-Json
                if ($json.name -eq "axios") {
                    $axiosCount++
                    $ver = $json.version
                    if ($MALICIOUS -contains $ver) {
                        $badCount++
                        Record "AXIOS" "FAIL" "COMPROMISED: axios $ver in npm cache"
                    }
                    else {
                        Record "AXIOS" "PASS" "Safe: axios $ver (npm cache)"
                    }
                }
            }
            catch { }
        }
    }
    else {
        Log "No npm cache found (this is fine)" "INFO"
    }

    # Summary
    if ($axiosCount -eq 0) {
        Log "No axios installations found. If you don't use Node.js, this is normal." "INFO"
    }
    else {
        if ($badCount -gt 0) {
            Record "AXIOS" "FAIL" "RESULT: Found $badCount COMPROMISED out of $axiosCount total axios installations"
        }
        else {
            Record "AXIOS" "PASS" "RESULT: All $axiosCount axios installations are safe versions"
        }
    }
}

# --- Phase 2: Dropper Package ---

function Phase2-DropperPackage {
    Log "PHASE 2 of 6: Looking for the malicious dropper package..." "HEAD"
    Log "The attacker used a fake package called 'plain-crypto-js' to deliver the virus." "STEP"

    $searchRoot = if ($ScanPath) { $ScanPath } else { $env:USERPROFILE }

    Log "Searching for 'plain-crypto-js' in all your project folders..." "STEP"
    $dropperDirs = @(Get-ChildItem -Path $searchRoot -Filter $DROPPER -Directory -Recurse -ErrorAction SilentlyContinue)

    if ($dropperDirs.Count -gt 0) {
        foreach ($dir in $dropperDirs) {
            Record "DROPPER" "FAIL" "FOUND malicious package at: $($dir.FullName)"
            if ($Fix) {
                Remove-Item -Path $dir.FullName -Recurse -Force -ErrorAction SilentlyContinue
                Log "REMOVED malicious package at: $($dir.FullName)" "WARN"
            }
        }
    }
    else {
        Record "DROPPER" "PASS" "Malicious 'plain-crypto-js' package was NOT found anywhere"
    }

    # Check for setup.js in axios folders (the actual payload trigger)
    Log "Checking for suspicious postinstall scripts inside axios folders..." "STEP"
    $setupFiles = @(Get-ChildItem -Path $searchRoot -Filter "setup.js" -Recurse -ErrorAction SilentlyContinue |
        Where-Object { $_.DirectoryName -match '[/\\]axios$' })

    if ($setupFiles.Count -gt 0) {
        foreach ($f in $setupFiles) {
            Record "DROPPER" "FAIL" "SUSPICIOUS setup.js found inside axios folder: $($f.FullName)"
        }
    }
    else {
        Record "DROPPER" "PASS" "No suspicious scripts found inside axios folders"
    }
}

# --- Phase 3: RAT Artifacts ---

function Phase3-RATFiles {
    Log "PHASE 3 of 6: Checking for backdoor files on your system..." "HEAD"
    Log "The attacker's virus drops specific files. We check if any exist." "STEP"

    $ratPaths = @(
        @{ Path = (Join-Path $env:ProgramData "wt.exe");     Desc = "Disguised PowerShell copy (wt.exe in ProgramData)" },
        @{ Path = (Join-Path $env:TEMP "6202033.vbs");        Desc = "VBScript launcher (6202033.vbs in Temp)" },
        @{ Path = (Join-Path $env:TEMP "6202033.ps1");        Desc = "PowerShell payload (6202033.ps1 in Temp)" }
    )

    foreach ($rat in $ratPaths) {
        Log "Checking: $($rat.Desc)..." "STEP"
        if (Test-Path $rat.Path) {
            Record "RAT" "FAIL" "BACKDOOR FILE FOUND: $($rat.Path)"
            if ($Fix) {
                Remove-Item -Path $rat.Path -Force -ErrorAction SilentlyContinue
                Log "REMOVED backdoor file: $($rat.Path)" "WARN"
            }
        }
        else {
            Record "RAT" "PASS" "Not found: $($rat.Desc)"
        }
    }

    # Extra: check if wt.exe exists and is actually a renamed PowerShell
    $wtPath = Join-Path $env:ProgramData "wt.exe"
    if (Test-Path $wtPath) {
        Log "Checking if wt.exe is a disguised copy of PowerShell..." "STEP"
        try {
            $wtHash = (Get-FileHash $wtPath -Algorithm SHA256).Hash
            $psHash = (Get-FileHash "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -Algorithm SHA256).Hash
            if ($wtHash -eq $psHash) {
                Record "RAT" "FAIL" "wt.exe IS a renamed copy of PowerShell (confirmed backdoor)"
            }
        }
        catch { }
    }
}

# --- Phase 4: Network ---

function Phase4-Network {
    Log "PHASE 4 of 6: Checking if your computer contacted the attacker's server..." "HEAD"
    Log "We check your DNS cache, hosts file, and active network connections." "STEP"

    # DNS cache
    Log "Checking DNS cache for attacker's domain ($C2_DOMAIN)..." "STEP"
    try {
        $dns = @(Get-DnsClientCache -ErrorAction Stop | Where-Object { $_.Entry -like "*$C2_DOMAIN*" })
        if ($dns.Count -gt 0) {
            Record "NETWORK" "FAIL" "Your computer recently looked up the attacker's domain: $C2_DOMAIN"
        }
        else {
            Record "NETWORK" "PASS" "Attacker's domain NOT in your DNS cache"
        }
    }
    catch {
        Log "Could not check DNS cache (you may need to run as Administrator)" "INFO"
    }

    # Active connections
    Log "Checking for active connections to attacker's server ($C2_IP)..." "STEP"
    try {
        $netstatOutput = netstat -ano 2>$null | Out-String
        if ($netstatOutput -match [regex]::Escape($C2_IP)) {
            Record "NETWORK" "FAIL" "ACTIVE CONNECTION to attacker's server detected! IP: $C2_IP"
        }
        else {
            Record "NETWORK" "PASS" "No active connections to attacker's server"
        }
    }
    catch {
        Log "Could not check network connections" "INFO"
    }

    # Hosts file
    Log "Checking hosts file for attacker's domain..." "STEP"
    $hostsPath = Join-Path $env:SystemRoot "System32\drivers\etc\hosts"
    if (Test-Path $hostsPath) {
        try {
            $hostsText = Get-Content $hostsPath -Raw -ErrorAction Stop
            if ($hostsText -and $hostsText.Contains($C2_DOMAIN)) {
                Record "NETWORK" "WARN" "Attacker's domain found in hosts file (may be a block entry -- check manually)"
            }
            else {
                Record "NETWORK" "PASS" "Attacker's domain NOT in hosts file"
            }
        }
        catch {
            Log "Could not read hosts file (limited permissions)" "INFO"
        }
    }
}

# --- Phase 5: Persistence ---

function Phase5-Persistence {
    Log "PHASE 5 of 6: Checking if the attacker set anything to run on startup..." "HEAD"
    Log "We check scheduled tasks, startup programs, and registry entries." "STEP"

    # Scheduled tasks
    Log "Checking scheduled tasks..." "STEP"
    try {
        $tasks = @(Get-ScheduledTask -ErrorAction Stop | Where-Object {
            $combined = $_.TaskName
            try {
                $_.Actions | ForEach-Object {
                    $combined += " " + $_.Execute + " " + $_.Arguments
                }
            }
            catch { }
            $combined -match "6202033|plain-crypto|sfrclak"
        })
        if ($tasks.Count -gt 0) {
            foreach ($t in $tasks) {
                Record "PERSIST" "FAIL" "SUSPICIOUS scheduled task: $($t.TaskName)"
                if ($Fix) {
                    Unregister-ScheduledTask -TaskName $t.TaskName -Confirm:$false -ErrorAction SilentlyContinue
                    Log "REMOVED scheduled task: $($t.TaskName)" "WARN"
                }
            }
        }
        else {
            Record "PERSIST" "PASS" "No suspicious scheduled tasks found"
        }
    }
    catch {
        Log "Could not check all scheduled tasks (some need admin access)" "INFO"
    }

    # Registry run keys
    Log "Checking startup registry entries..." "STEP"
    $regClean = $true
    $runKeys = @(
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run",
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce"
    )
    foreach ($key in $runKeys) {
        try {
            $entries = Get-ItemProperty -Path $key -ErrorAction SilentlyContinue
            if ($entries) {
                $entries.PSObject.Properties | Where-Object { $_.Name -notmatch '^PS' } | ForEach-Object {
                    if ($_.Value -match "6202033|plain-crypto|sfrclak") {
                        $regClean = $false
                        Record "PERSIST" "FAIL" "SUSPICIOUS startup entry: $($_.Name) = $($_.Value)"
                        if ($Fix) {
                            Remove-ItemProperty -Path $key -Name $_.Name -ErrorAction SilentlyContinue
                            Log "REMOVED registry entry: $($_.Name)" "WARN"
                        }
                    }
                }
            }
        }
        catch { }
    }
    if ($regClean) {
        Record "PERSIST" "PASS" "Startup registry entries are clean"
    }

    # Startup folder
    Log "Checking startup folder..." "STEP"
    $startupDir = Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs\Startup"
    if (Test-Path $startupDir) {
        $badStartup = @(Get-ChildItem -Path $startupDir -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -match "6202033|plain-crypto|sfrclak" })
        if ($badStartup.Count -gt 0) {
            foreach ($item in $badStartup) {
                Record "PERSIST" "FAIL" "SUSPICIOUS file in startup folder: $($item.FullName)"
            }
        }
        else {
            Record "PERSIST" "PASS" "Startup folder is clean"
        }
    }
}

# --- Phase 6: Lockfiles ---

function Phase6-Lockfiles {
    Log "PHASE 6 of 6: Scanning project dependency files..." "HEAD"
    Log "Lockfiles record exact versions of packages used in your projects." "STEP"

    $searchRoot = if ($ScanPath) { $ScanPath } else { $env:USERPROFILE }
    $checked  = 0
    $badLocks = 0

    Log "Searching for lockfiles (this may take a moment)..." "STEP"
    $lockfiles = @(Get-ChildItem -Path $searchRoot -Include @("package-lock.json", "yarn.lock", "pnpm-lock.yaml") -Recurse -ErrorAction SilentlyContinue |
        Where-Object { $_.DirectoryName -notmatch 'node_modules' })

    foreach ($lock in $lockfiles) {
        try {
            $content = Get-Content $lock.FullName -Raw -ErrorAction Stop
            if (-not $content) { continue }
            $checked++

            $isBad = $false
            foreach ($ver in $MALICIOUS) {
                if ($content -match "axios.*$ver") {
                    $isBad = $true
                    $badLocks++
                    Record "LOCKFILE" "FAIL" "Compromised axios $ver referenced in: $($lock.FullName)"
                }
            }
            if ($content -match $DROPPER) {
                $isBad = $true
                $badLocks++
                Record "LOCKFILE" "FAIL" "Dropper package referenced in: $($lock.FullName)"
            }
        }
        catch { }
    }

    if ($checked -eq 0) {
        Log "No project lockfiles found (normal if you don't have Node.js projects)" "INFO"
    }
    elseif ($badLocks -eq 0) {
        Record "LOCKFILE" "PASS" "Scanned $checked lockfiles -- all clean"
    }
}

# --- Report Generation ---

function Write-Report {
    $report = @()
    $report += "========================================================"
    $report += "  AXIOS SUPPLY CHAIN ATTACK - SCAN REPORT"
    $report += "  Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    $report += "  Computer:  $env:COMPUTERNAME"
    $report += "  User:      $env:USERNAME"
    $report += "  Scanner:   axios-scanner.ps1"
    $report += "========================================================"
    $report += ""

    if ($compromised) {
        $report += "  VERDICT:  *** COMPROMISED ***"
        $report += ""
        $report += "  Your computer shows signs of the axios supply chain attack."
        $report += "  Follow the steps below immediately."
    }
    else {
        $report += "  VERDICT:  CLEAN"
        $report += ""
        $report += "  No signs of compromise were found on your computer."
    }

    $report += ""
    $report += "  Summary: $totalChecks checks run, $passedChecks passed, $failedChecks failed, $warningChecks warnings"
    $report += ""
    $report += "--------------------------------------------------------"
    $report += "  DETAILED FINDINGS"
    $report += "--------------------------------------------------------"
    $report += ""

    foreach ($f in $allFindings) {
        $icon = switch ($f.Result) {
            "PASS" { "[PASS]" }
            "FAIL" { "[FAIL]" }
            "WARN" { "[WARN]" }
        }
        $report += "  $icon $($f.Category): $($f.Detail)"
    }

    if ($compromised) {
        $report += ""
        $report += "--------------------------------------------------------"
        $report += "  WHAT TO DO NOW"
        $report += "--------------------------------------------------------"
        $report += ""
        $report += "  1. DISCONNECT from the internet right now"
        $report += "  2. Re-run this scanner with -Fix to remove malicious files:"
        $report += "     powershell -ExecutionPolicy Bypass -File axios-scanner.ps1 -Fix"
        $report += "  3. CHANGE ALL YOUR PASSWORDS:"
        $report += "     - Email (Gmail, Outlook, etc.)"
        $report += "     - GitHub / GitLab"
        $report += "     - npm account"
        $report += "     - Cloud services (AWS, Azure, Vercel, etc.)"
        $report += "     - Any other developer accounts"
        $report += "  4. REGENERATE all API keys, SSH keys, and access tokens"
        $report += "  5. CHECK your git history for commits you did not make"
        $report += "  6. TELL YOUR TEAM if this is a work computer"
    }
    else {
        $report += ""
        $report += "--------------------------------------------------------"
        $report += "  HOW TO STAY SAFE"
        $report += "--------------------------------------------------------"
        $report += ""
        $report += "  - Pin dependency versions: use ""axios"": ""1.14.0"" not ""^1.14.0"""
        $report += "  - Always commit your lockfile (package-lock.json)"
        $report += "  - Use 'npm ci' instead of 'npm install'"
        $report += "  - Enable 2FA on your npm account"
    }

    $report += ""
    $report += "--------------------------------------------------------"
    $report += "  KNOWN ATTACK INDICATORS (for reference)"
    $report += "--------------------------------------------------------"
    $report += ""
    $report += "  Bad versions:  axios@1.14.1, axios@0.30.4"
    $report += "  Bad package:   plain-crypto-js@4.2.1"
    $report += "  Attacker IP:   142.11.206.73"
    $report += "  Attacker URL:  sfrclak.com:8000/6202033"
    $report += ""
    $report += "========================================================"
    $report += "  Full log saved to: $logFile"
    $report += "  This report saved to: $reportFile"
    $report += "========================================================"

    $report | Out-File -FilePath $reportFile -Encoding UTF8 -ErrorAction SilentlyContinue
}

# --- Main ---

Show-Banner

$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

Phase1-AxiosVersions
Phase2-DropperPackage
Phase3-RATFiles
Phase4-Network
Phase5-Persistence
Phase6-Lockfiles

$stopwatch.Stop()

# Generate report file
Write-Report

# --- Final Verdict ---

Write-Host ""
Write-Host "  ============================================================" -ForegroundColor DarkGray
Write-Host "  |                                                          |" -ForegroundColor DarkGray

if ($compromised) {
    Write-Host "  |   VERDICT: " -NoNewline -ForegroundColor DarkGray
    Write-Host "COMPROMISED                                  " -NoNewline -ForegroundColor Red
    Write-Host "|" -ForegroundColor DarkGray
    Write-Host "  |                                                          |" -ForegroundColor DarkGray
    Write-Host "  |   " -NoNewline -ForegroundColor DarkGray
    Write-Host "Your computer shows signs of the attack.              " -NoNewline -ForegroundColor Red
    Write-Host "|" -ForegroundColor DarkGray
    Write-Host "  |   " -NoNewline -ForegroundColor DarkGray
    Write-Host "Open the report file for what to do next.              " -NoNewline -ForegroundColor Yellow
    Write-Host "|" -ForegroundColor DarkGray
}
else {
    Write-Host "  |   VERDICT: " -NoNewline -ForegroundColor DarkGray
    Write-Host "CLEAN                                        " -NoNewline -ForegroundColor Green
    Write-Host "|" -ForegroundColor DarkGray
    Write-Host "  |                                                          |" -ForegroundColor DarkGray
    Write-Host "  |   " -NoNewline -ForegroundColor DarkGray
    Write-Host "No signs of compromise. You are safe.                  " -NoNewline -ForegroundColor Green
    Write-Host "|" -ForegroundColor DarkGray
}

Write-Host "  |                                                          |" -ForegroundColor DarkGray
Write-Host "  ============================================================" -ForegroundColor DarkGray
Write-Host ""

$elapsed = [math]::Round($stopwatch.Elapsed.TotalSeconds, 1)
Write-Host "  Checks run: $totalChecks | Passed: $passedChecks | Failed: $failedChecks | Warnings: $warningChecks" -ForegroundColor Gray
Write-Host "  Time: ${elapsed}s" -ForegroundColor DarkGray
Write-Host ""
Write-Host "  Log file:    $logFile" -ForegroundColor DarkGray
Write-Host "  Report file: $reportFile" -ForegroundColor DarkGray
Write-Host ""

if ($compromised) { exit 1 } else { exit 0 }
