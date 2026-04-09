# Fix Windows Defender Issues - Full Feature Enablement
#Requires -RunAsAdministrator

# Logging
function Write-Log {
    param([string]$Message)
    Write-Host "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss'): $Message"
}

# Prerequisites
Import-Module Defender -ErrorAction SilentlyContinue

if (-not (Get-Command Get-MpComputerStatus -ErrorAction SilentlyContinue)) {
    Write-Log "Windows Defender cmdlets are not available. Defender may not be installed or accessible."
    exit 1
}

# Third-Party AV Detection and Removal
function Remove-ThirdPartyAV {
    Write-Log "Scanning for third-party antivirus products..."

    $avPatterns = @(
        'McAfee', 'Trellix',
        'Norton', 'Symantec', 'NortonLifeLock',
        'Kaspersky',
        'Trend Micro', 'OfficeScan', 'Worry-Free',
        'Sophos',
        'Webroot',
        'ESET',
        'Bitdefender',
        'Avast',
        '\bAVG\b',
        'Malwarebytes',
        'F-Secure', 'WithSecure',
        'Cylance',
        'Carbon Black',
        'Panda Antivirus', 'Panda Dome', 'Panda Security',
        'Comodo Antivirus', 'Comodo Internet Security',
        'BullGuard',
        'G Data', 'GDATA',
        'Vipre',
        'SentinelOne'
    )

    $uninstallPaths = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )

    # Collect and deduplicate by DisplayName
    $seen  = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $found = [System.Collections.Generic.List[object]]::new()

    foreach ($path in $uninstallPaths) {
        $entries = Get-ItemProperty -Path $path -ErrorAction SilentlyContinue
        foreach ($entry in $entries) {
            $name = $entry.DisplayName
            if (-not $name) { continue }
            if (-not $seen.Add($name)) { continue }   # skip duplicate
            foreach ($pattern in $avPatterns) {
                if ($name -match $pattern) {
                    $found.Add($entry)
                    break
                }
            }
        }
    }

    if ($found.Count -eq 0) {
        Write-Log "  No third-party AV products detected."
        return
    }

    Write-Log "  Found $($found.Count) third-party AV product(s):"
    foreach ($product in $found) {
        Write-Log "  - $($product.DisplayName) [$($product.DisplayVersion)]"
    }

    foreach ($product in $found) {
        Write-Log "  Attempting to remove: $($product.DisplayName)..."

        # Prefer QuietUninstallString; fall back to UninstallString
        $uninstallCmd = if ($product.QuietUninstallString) {
            $product.QuietUninstallString
        } else {
            $product.UninstallString
        }

        if (-not $uninstallCmd) {
            Write-Log "  [WARN] No uninstall string found for $($product.DisplayName). Manual removal may be required."
            continue
        }

        try {
            if ($uninstallCmd -match 'msiexec') {
                # MSI-based: extract GUID and run silently
                if ($uninstallCmd -match '(\{[0-9A-Fa-f\-]+\})') {
                    $guid = $Matches[1]
                    $proc = Start-Process -FilePath 'msiexec.exe' \
                                         -ArgumentList "/x $guid /qn /norestart" \
                                         -Wait -PassThru -ErrorAction Stop
                    if ($proc.ExitCode -in @(0, 3010)) {
                        Write-Log "  [OK] Removed: $($product.DisplayName) (exit: $($proc.ExitCode))"
                    } else {
                        Write-Log "  [WARN] Removal may have failed for $($product.DisplayName) (exit: $($proc.ExitCode))"
                    }
                } else {
                    Write-Log "  [WARN] Could not extract MSI product code for $($product.DisplayName)."
                }
            } else {
                # EXE-based: parse the command line
                if ($uninstallCmd -match '^"([^"]+)"\s*(.*)$') {
                    $exe  = $Matches[1]
                    $args = $Matches[2]
                } elseif ($uninstallCmd -match '^(\S+)\s*(.*)$') {
                    $exe  = $Matches[1]
                    $args = $Matches[2]
                } else {
                    Write-Log "  [WARN] Cannot parse uninstall string for $($product.DisplayName): $uninstallCmd"
                    continue
                }

                # Append silent flags only when not already using QuietUninstallString
                if (-not $product.QuietUninstallString) {
                    $args = "$args /S /SILENT /NORESTART".Trim()
                }

                $proc = Start-Process -FilePath $exe -ArgumentList $args -Wait -PassThru -ErrorAction Stop
                if ($proc.ExitCode -in @(0, 3010)) {
                    Write-Log "  [OK] Removed: $($product.DisplayName) (exit: $($proc.ExitCode))"
                } else {
                    Write-Log "  [WARN] Removal may have failed for $($product.DisplayName) (exit: $($proc.ExitCode))"
                }
            }
        } catch {
            Write-Log "  [ERROR] Failed to remove $($product.DisplayName): $($_)"
        }
    }
}

# Hardware / Feature Capability Detection
function Get-HardwareCapabilities {
    $caps = [PSCustomObject]@{
        VirtualizationEnabled   = $false
        SlatSupported           = $false
        TpmPresent              = $false
        TpmReady                = $false
        SecureBootEnabled       = $false
        UefiEnabled             = $false
        HvciCapable             = $false
        CredentialGuardCapable  = $false
        Win10OrLater            = $false
        Win11OrLater            = $false
    }

    # OS version
    $osVer = [System.Environment]::OSVersion.Version
    $caps.Win10OrLater  = ($osVer.Major -ge 10)
    $caps.Win11OrLater  = ($osVer.Major -ge 10 -and $osVer.Build -ge 22000)

    # Virtualisation (VT-x / AMD-V)
    try {
        $cs = Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction Stop
        $caps.VirtualizationEnabled = [bool]$cs.HypervisorPresent
    } catch {
        Write-Log "Could not query virtualisation support: $_"
    }

    # SLAT (Second Level Address Translation) — required for HVCI
    try {
        $proc = Get-CimInstance -ClassName Win32_Processor -ErrorAction Stop | Select-Object -First 1
        # SecondLevelAddressTranslationExtensions property exists on Win10+
        if ($null -ne $proc.PSObject.Properties['SecondLevelAddressTranslationExtensions']) {
            $caps.SlatSupported = [bool]$proc.SecondLevelAddressTranslationExtensions
        } else {
            # Fall back: assume SLAT on modern hardware if virtualisation is present
            $caps.SlatSupported = $caps.VirtualizationEnabled
        }
    } catch {
        Write-Log "Could not query SLAT support: $_"
    }

    # TPM
    try {
        $tpm = Get-CimInstance -Namespace root\CIMv2\Security\MicrosoftTpm -ClassName Win32_Tpm -ErrorAction Stop
        if ($tpm) {
            $caps.TpmPresent = $true
            $caps.TpmReady   = [bool]$tpm.IsEnabled_InitialValue -and [bool]$tpm.IsActivated_InitialValue
        }
    } catch {
        Write-Log "TPM information not accessible (may require admin on older OS): $_"
    }

    # Secure Boot
    try {
        $sb = Confirm-SecureBootUEFI -ErrorAction Stop
        $caps.SecureBootEnabled = $sb
        $caps.UefiEnabled       = $true
    } catch [System.PlatformNotSupportedException] {
        Write-Log "Secure Boot / UEFI: Not supported on this platform (likely BIOS/Legacy boot)."
    } catch {
        Write-Log "Could not query Secure Boot status: $_"
    }

    # HVCI capability = virtualisation + SLAT + UEFI + TPM (TPM optional but recommended)
    $caps.HvciCapable = $caps.VirtualizationEnabled -and $caps.SlatSupported -and $caps.UefiEnabled

    # Credential Guard = same requirements + TPM recommended
    $caps.CredentialGuardCapable = $caps.HvciCapable -and $caps.Win10OrLater

    return $caps
}

# Tamper Protection helper
function Test-TamperProtectionEnabled {
    try {
        $t = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows Defender\Features" -Name "TamperProtection" -ErrorAction Stop
        return ($t.TamperProtection -ne 0)
    } catch {
        return $false
    }
}

# Core Defender Components
function Enable-DefenderComponents {
    Write-Log "Checking and enabling core Defender components..."

    if (Test-TamperProtectionEnabled) {
        Write-Log "  [WARN] Tamper Protection is enabled. Some settings may be blocked. Disable it in Windows Security > Virus & threat protection settings if changes fail."
    }

    try {
        $status = Get-MpComputerStatus -ErrorAction Stop
    } catch {
        Write-Log "  [ERROR] Failed to get Defender status: $_"
        return
    }

    $prefs = @{
        DisableRealtimeMonitoring       = $false   # Real-Time Protection
        DisableBehaviorMonitoring       = $false   # Behaviour Monitor
        DisableIOAVProtection           = $false   # IOAV (downloaded files & attachments)
        DisableScriptScanning           = $false   # Script scanning
        DisableArchiveScanning          = $false   # Archive scanning
        DisableEmailScanning            = $false   # Email scanning
        DisableRemovableDriveScanning   = $false   # Removable drive scanning
        DisableScanningMappedNetworkDrivesForFullScan = $false
        MAPSReporting                   = 2        # Advanced MAPS (Cloud protection) — 0=Disabled,1=Basic,2=Advanced
        SubmitSamplesConsent            = 3        # Automatically send safe samples (3 = Send all samples)
        CloudBlockLevel                 = 6        # High+ cloud block level (0=Default … 6=High+)
        CloudExtendedTimeout            = 50       # Extra seconds for cloud analysis (0-50)
        EnableNetworkProtection         = 1        # Network Protection: 1=Enabled,2=AuditMode
        PUAProtection                   = 1        # Potentially Unwanted Application: 1=Enabled,2=AuditMode
        EnableControlledFolderAccess    = 1        # Controlled Folder Access: 1=Enabled,2=AuditMode
        EnableLowCpuPriority            = $false   # Do not throttle scans
        ScanAvgCPULoadFactor            = 50       # Default CPU load cap
        CheckForSignaturesBeforeRunningScan = $true
        SignatureDisableUpdateOnStartupWithoutEngine = $false
        DisableRealtimeMonitoringForChildProcesses   = $false
    }

    foreach ($pref in $prefs.GetEnumerator()) {
        try {
            $setParams = @{ $pref.Key = $pref.Value; ErrorAction = 'Stop' }
            Set-MpPreference @setParams
            Write-Log "  [OK] Set $($pref.Key) = $($pref.Value)"
        } catch {
            Write-Log "  [WARN] Could not set $($pref.Key): $_"
        }
    }
}

# Attack Surface Reduction (ASR) Rules
function Enable-AsrRules {
    Write-Log "Enabling Attack Surface Reduction (ASR) rules..."

    # Full set of published ASR GUIDs (as of 2025/2026)
    # Action: 1=Block, 2=Audit, 6=Warn
    $asrRules = [ordered]@{
        # Office / macro rules
        "3B576869-A4EC-4529-8536-B80A7769E899" = 1  # Block Office apps from creating executable content
        "75668C1F-73B5-4CF0-BB93-3ECF5CB7CC84" = 1  # Block Office apps from injecting code into other processes
        "D3E037E1-3EB8-44C8-A917-57927947596D" = 1  # Block Office macros from Win32 API calls
        "92E97FA1-2EDF-4476-BDD6-9DD0B4DDDC7B" = 1  # Block Win32 API calls from Office macros
        "26190899-1602-49E8-8B27-EB1D0A1CE869" = 1  # Block Office comms app from creating child processes
        "BE9BA2D9-53EA-4CDC-84E5-9B1EEEE46550" = 1  # Block executable content from email client and webmail

        # Scripts / downloads
        "5BEB7EFE-FD9A-4556-801D-275E5FFC04CC" = 1  # Block execution of potentially obfuscated scripts
        "D1E49AAC-8F56-4280-B9BA-993A6D77406C" = 1  # Block execution of scripts downloaded from internet
        "01443614-CD74-433A-B99E-2ECDC07BFC25" = 1  # Block lsass credential stealing

        # Process / credential / lateral
        "9E6C4E1F-7D60-472F-BA1A-A39EF669E4B2" = 1  # Block credential stealing from LSASS (enhanced)
        "D4F940AB-401B-4EFC-AADC-AD5F3C50688A" = 1  # Block all Office apps from creating child processes
        "B2B3F03D-6A65-4F7B-A9C7-1C7EF74A9BA4" = 1  # Block untrusted and unsigned processes from USB
        "C1DB55AB-C21A-4637-BB3F-A12568109D35" = 1  # Use advanced protection against ransomware
        "56A863A9-875E-4185-98A7-B882C64B5CE5" = 1  # Block abuse of exploited vulnerable signed drivers
        "7674BA52-37EB-4A4F-A9A1-F0F9A1619A2C" = 1  # Block Adobe Reader from creating child processes
        "E6DB77E5-3DF2-4CF1-B95A-636979351E5B" = 1  # Block persistence through WMI event subscription
        "33DDEDF1-C6E0-47CB-833E-DE6133960387" = 1  # Block rebooting machine in Safe Mode
        "C0033C00-D16D-4114-A5A0-DC9B3A7D2CEB" = 1  # Block use of copied or impersonated system tools
        "A8F5898E-1DC8-49A9-9878-85004B8A61E6" = 1  # Block Webshell creation for Servers

        # Network
        "2000B89C-6C96-4F1E-9B0A-3B9D1F8E6A9F" = 1  # Block network connections from low reputation processes (if available)
    }

    foreach ($rule in $asrRules.GetEnumerator()) {
        try {
            Add-MpPreference -AttackSurfaceReductionRules_Ids $rule.Key `
                             -AttackSurfaceReductionRules_Actions $rule.Value `
                             -ErrorAction Stop
            Write-Log "  [OK] ASR rule $($rule.Key) set to action $($rule.Value)"
        } catch {
            Write-Log "  [WARN] Could not set ASR rule $($rule.Key): $_"
        }
    }
}

# Exploit Protection (EMET replacement) 
function Enable-ExploitProtection {
    Write-Log "Enabling Exploit Protection (system-wide defaults)..."

    # System-wide settings via ProcessMitigation
    $mitigations = @(
        @{ Name = "DEP";   Enable = $true;  Settings = @{ Enable = $true; EmulateAtlThunks = $false } }
        @{ Name = "SEHOP"; Enable = $true;  Settings = @{ Enable = $true } }
        @{ Name = "ASLR";  Enable = $true;  Settings = @{ BottomUpRandomization = $true; ForceRelocateImages = $true; HighEntropyRandomization = $true } }
        @{ Name = "CFG";   Enable = $true;  Settings = @{ Enable = $true; SuppressExports = $false } }
        @{ Name = "Heap";  Enable = $true;  Settings = @{ TerminateOnError = $true } }
    )

    foreach ($mit in $mitigations) {
        try {
            Set-ProcessMitigation -System -Enable $mit.Name -ErrorAction Stop
            Write-Log "  [OK] Exploit protection mitigation enabled: $($mit.Name)"
        } catch {
            Write-Log "  [WARN] Could not enable $($mit.Name) mitigation: $_"
        }
    }
}

# Memory Integrity / HVCI
function Enable-MemoryIntegrity {
    param([PSCustomObject]$HwCaps)

    Write-Log "Checking Memory Integrity (HVCI / Hypervisor-Protected Code Integrity)..."

    if (-not $HwCaps.HvciCapable) {
        Write-Log "  [SKIP] Hardware requirements not met for Memory Integrity."
        Write-Log "         Requires: Virtualisation (VT-x/AMD-V) + SLAT + UEFI."
        Write-Log "         Current: VT=$($HwCaps.VirtualizationEnabled) SLAT=$($HwCaps.SlatSupported) UEFI=$($HwCaps.UefiEnabled)"
        return
    }

    # Check current HVCI state via DeviceGuard CIM class
    try {
        $dg = Get-CimInstance -ClassName Win32_DeviceGuard -Namespace root\Microsoft\Windows\DeviceGuard -ErrorAction Stop
        $hvciRunning = ($dg.VirtualizationBasedSecurityStatus -eq 2) -and
                       ($dg.SecurityServicesRunning -contains 2)
        if ($hvciRunning) {
            Write-Log "  [OK] Memory Integrity is already running."
            return
        }
    } catch {
        Write-Log "  [INFO] Cannot query DeviceGuard CIM class directly; will attempt to enable via registry."
    }

    # Enable HVCI via registry (takes effect after reboot)
    #   HKLM\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity
    try {
        $hvciPath = "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity"
        if (-not (Test-Path $hvciPath)) {
            New-Item -Path $hvciPath -Force | Out-Null
        }
        Set-ItemProperty -Path $hvciPath -Name "Enabled" -Value 1 -Type DWord -Force
        Set-ItemProperty -Path $hvciPath -Name "Locked"  -Value 0 -Type DWord -Force
        Write-Log "  [OK] Memory Integrity (HVCI) enabled via registry. A reboot is required to take effect."
    } catch {
        Write-Log "  [ERROR] Failed to enable Memory Integrity via registry: $_"
    }
}

# Credential Guard
function Enable-CredentialGuard {
    param([PSCustomObject]$HwCaps)

    Write-Log "Checking Credential Guard..."

    if (-not $HwCaps.CredentialGuardCapable) {
        Write-Log "  [SKIP] Hardware requirements not met for Credential Guard."
        Write-Log "         Requires: Virtualisation + SLAT + UEFI + Windows 10/11 Enterprise or Pro."
        return
    }

    # Check Windows edition (Credential Guard fully supported on Enterprise)
    $edition = (Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue).OperatingSystemSKU
    # SKU 4 = Enterprise, 48 = Pro, etc. — we attempt regardless but warn on unsupported editions
    if ($edition -notin @(4, 27, 125, 161)) {
        Write-Log "  [INFO] Credential Guard is fully supported on Enterprise editions. Attempting anyway on SKU $edition."
    }

    try {
        $cgPath = "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard"
        if (-not (Test-Path $cgPath)) { New-Item -Path $cgPath -Force | Out-Null }

        # EnableVirtualizationBasedSecurity = 1
        Set-ItemProperty -Path $cgPath -Name "EnableVirtualizationBasedSecurity" -Value 1 -Type DWord -Force
        # RequirePlatformSecurityFeatures: 1=Secure Boot, 3=Secure Boot + DMA protection
        $secFeature = if ($HwCaps.SecureBootEnabled) { 3 } else { 1 }
        Set-ItemProperty -Path $cgPath -Name "RequirePlatformSecurityFeatures" -Value $secFeature -Type DWord -Force

        $lsaCfgPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa"
        Set-ItemProperty -Path $lsaCfgPath -Name "LsaCfgFlags" -Value 1 -Type DWord -Force

        Write-Log "  [OK] Credential Guard enabled (RequirePlatformSecurityFeatures=$secFeature). A reboot is required."
    } catch {
        Write-Log "  [ERROR] Failed to enable Credential Guard: $_"
    }
}

# SmartScreen
function Enable-SmartScreen {
    Write-Log "Enabling SmartScreen..."

    # SmartScreen for Explorer (apps and files)
    try {
        $ssPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer"
        Set-ItemProperty -Path $ssPath -Name "SmartScreenEnabled" -Value "RequireAdmin" -Type String -Force
        Write-Log "  [OK] SmartScreen for Explorer enabled (RequireAdmin)."
    } catch {
        Write-Log "  [WARN] Could not set SmartScreen for Explorer: $_"
    }

    # SmartScreen policy via AppInstaller / Defender — additional registry keys
    try {
        $ssDefPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System"
        if (-not (Test-Path $ssDefPath)) { New-Item -Path $ssDefPath -Force | Out-Null }
        Set-ItemProperty -Path $ssDefPath -Name "EnableSmartScreen" -Value 1 -Type DWord -Force
        Set-ItemProperty -Path $ssDefPath -Name "ShellSmartScreenLevel" -Value "RequireAdmin" -Type String -Force
        Write-Log "  [OK] SmartScreen policy keys set."
    } catch {
        Write-Log "  [WARN] Could not set SmartScreen policy keys: $_"
    }

    # SmartScreen for Microsoft Edge (Chromium) — HKLM policy
    try {
        $edgePath = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"
        if (-not (Test-Path $edgePath)) { New-Item -Path $edgePath -Force | Out-Null }
        Set-ItemProperty -Path $edgePath -Name "SmartScreenEnabled" -Value 1 -Type DWord -Force
        Set-ItemProperty -Path $edgePath -Name "PreventSmartScreenPromptOverride" -Value 1 -Type DWord -Force
        Set-ItemProperty -Path $edgePath -Name "PreventSmartScreenPromptOverrideForFiles" -Value 1 -Type DWord -Force
        Write-Log "  [OK] SmartScreen for Microsoft Edge enabled."
    } catch {
        Write-Log "  [WARN] Could not set SmartScreen for Edge: $_"
    }
}

# Windows Firewall
function Enable-WindowsFirewall {
    Write-Log "Enabling Windows Firewall on all profiles..."

    $profiles = @('Domain', 'Private', 'Public')
    foreach ($profile in $profiles) {
        try {
            Set-NetFirewallProfile -Profile $profile -Enabled True -ErrorAction Stop
            Write-Log "  [OK] Firewall enabled: $profile"
        } catch {
            Write-Log "  [WARN] Could not enable firewall profile $($profile): $($_)"
        }
    }
}

# Defender Services
function Start-DefenderServices {
    Write-Log "Checking Defender services..."
    $services = @(
        "WinDefend",            # Windows Defender Antivirus
        "SecurityHealthSvc",    # Windows Security Health Service
        "wscsvc",               # Windows Security Center
        "Sense",                # Windows Defender Advanced Threat Protection
        "WdNisSvc",             # Windows Defender Network Inspection Service
        "WdFilter",             # Windows Defender Mini-Filter Driver (kernel, start via sc)
        "mpssvc"                # Windows Firewall
    )

    foreach ($service in $services) {
        $svc = Get-Service -Name $service -ErrorAction SilentlyContinue
        if (-not $svc) {
            Write-Log "  [INFO] Service not present (may not apply to this edition): $service"
            continue
        }
        if ($svc.StartType -eq 'Disabled') {
            try {
                Set-Service -Name $service -StartupType Automatic -ErrorAction Stop
                Write-Log "  [OK] Service startup type set to Automatic: $service"
            } catch {
                Write-Log "  [WARN] Could not change startup type for $($service): $($_)"
            }
        }
        if ($svc.Status -ne 'Running') {
            try {
                Start-Service -Name $service -ErrorAction Stop
                Write-Log "  [OK] Started service: $service"
            } catch {
                Write-Log "  [WARN] Could not start service $service (may start after reboot): $_"
            }
        } else {
            Write-Log "  [OK] Service already running: $service"
        }
    }
}

# Signature Update
function Update-DefenderSignatures {
    Write-Log "Updating Defender signatures..."
    try {
        Update-MpSignature -UpdateSource MicrosoftUpdate -ErrorAction Stop
        Write-Log "  [OK] Signatures updated successfully."
    } catch {
        Write-Log "  [WARN] MicrosoftUpdate source failed, trying FileShares fallback: $_"
        try {
            Update-MpSignature -ErrorAction Stop
            Write-Log "  [OK] Signatures updated via default source."
        } catch {
            Write-Log "  [ERROR] Signature update failed: $_"
        }
    }
}

# Event Log Analysis
function Get-DefenderEvents {
    Write-Log "Checking event logs for Defender issues..."
    try {
        $events = Get-WinEvent -LogName 'Microsoft-Windows-Windows Defender/Operational' -MaxEvents 100 -ErrorAction Stop |
                  Where-Object { $_.Level -ge 2 }
    } catch {
        Write-Log "  [WARN] Failed to retrieve Defender events: $_"
        return @()
    }

    $issues = @()
    foreach ($evt in $events) {
        switch ($evt.Id) {
            1002 { $issues += "Definitions update failed (Event ID: $($evt.Id))" }
            1116 { $issues += "Malware detected but not removed (Event ID: $($evt.Id))" }
            1117 { $issues += "Malware remediation action taken (Event ID: $($evt.Id))" }
            1118 { $issues += "Malware action failed (Event ID: $($evt.Id))" }
            1119 { $issues += "Malware remediation critical failure (Event ID: $($evt.Id))" }
            2000 { $issues += "Real-time protection disabled (Event ID: $($evt.Id))" }
            2001 { $issues += "Real-time protection encountered error (Event ID: $($evt.Id))" }
            3002 { $issues += "Sample submission failed (Event ID: $($evt.Id))" }
            5001 { $issues += "Real-time protection disabled via policy (Event ID: $($evt.Id))" }
            5007 { $issues += "Defender configuration changed (Event ID: $($evt.Id))" }
            default {
                if ($evt.Level -eq 2) { $issues += "Warning — $($evt.Message) (Event ID: $($evt.Id))" }
            }
        }
    }
    return $issues
}

function Repair-KnownIssues {
    param([array]$Issues)

    Write-Log "Attempting to fix known event-log issues..."

    foreach ($issue in $Issues) {
        if ($issue -like "*Definitions update failed*") {
            Write-Log "  Retrying signature update..."
            Update-DefenderSignatures
        }
        if ($issue -like "*Real-time protection disabled*") {
            Write-Log "  Re-enabling real-time protection..."
            try { Set-MpPreference -DisableRealtimeMonitoring $false } catch { Write-Log "  [WARN] $_" }
        }
        if ($issue -like "*Malware*") {
            Write-Log "  Running full scan to address detected malware..."
            try { Start-MpScan -ScanType FullScan } catch { Write-Log "  [WARN] $_" }
        }
    }
}

# Pre-flight Issue Detection
function Get-DefenderIssues {
    Write-Log "Checking for common Defender issues..."
    $issues = @()

    # Tamper Protection
    try {
        $tp = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows Defender\Features" -Name "TamperProtection" -ErrorAction Stop
        Write-Log "  Tamper Protection registry value: $($tp.TamperProtection)"
        if ($tp.TamperProtection -ne 0) {
            $issues += "Tamper Protection is enabled (value: $($tp.TamperProtection)), which may block configuration changes. Disable via Windows Security if needed."
        }
    } catch {
        Write-Log "  Could not read Tamper Protection: $_"
    }

    # Defender service startup type
    $svc = Get-Service -Name WinDefend -ErrorAction SilentlyContinue
    if ($svc) {
        Write-Log "  WinDefend StartType: $($svc.StartType)"
        if ($svc.StartType -eq 'Disabled') { $issues += "Windows Defender service is disabled." }
    } else {
        Write-Log "  WinDefend service not found."
    }

    # Group Policy: DisableAntiSpyware
    try {
        $gp = Get-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender" -ErrorAction SilentlyContinue
        if ($gp -and $gp.DisableAntiSpyware -eq 1) {
            $issues += "Group Policy has disabled Windows Defender (DisableAntiSpyware=1). Update GPO to allow Defender."
        }
        if ($gp -and $gp.DisableRoutinelyTakingAction -eq 1) {
            $issues += "Group Policy is disabling Defender routine actions."
        }
    } catch {
        Write-Log "  Could not check Defender GP keys: $_"
    }

    return $issues
}

function Repair-CommonIssues {
    param([array]$Issues)

    Write-Log "Attempting to remediate pre-flight issues..."

    foreach ($issue in $Issues) {
        if ($issue -like "*Tamper Protection is enabled*") {
            Write-Log "  [ACTION REQUIRED] Disable Tamper Protection manually in Windows Security > Virus & threat protection settings."
        }
        if ($issue -like "*Windows Defender service is disabled*") {
            try {
                Set-Service -Name WinDefend -StartupType Automatic
                Start-Service -Name WinDefend
                Write-Log "  [OK] Defender service enabled and started."
            } catch {
                Write-Log "  [ERROR] Failed to enable/start Defender service: $_"
            }
        }
        if ($issue -like "*Group Policy*") {
            Write-Log "  [INFO] Group Policy is restricting Defender. Check Local Group Policy Editor (gpedit.msc) or domain GPO."
        }
    }
}

# Quick Scan
function Start-QuickScan {
    Write-Log "Running quick scan..."
    try {
        Start-MpScan -ScanType QuickScan -ErrorAction Stop
        Write-Log "  [OK] Quick scan completed."
    } catch {
        Write-Log "  [WARN] Quick scan failed: $_"
    }
}

# MAIN EXECUTION
Write-Log "========================================================"
Write-Log "  Microsoft Defender Full Remediation & Hardening Script"
Write-Log "========================================================"

# 0. Third-party AV removal
Write-Log "--- Third-Party AV Detection & Removal ---"
Remove-ThirdPartyAV

# 1. Hardware capability check
Write-Log "--- Hardware & Platform Capability Check ---"
$hwCaps = Get-HardwareCapabilities
Write-Log "  Virtualisation (VT-x/AMD-V) : $($hwCaps.VirtualizationEnabled)"
Write-Log "  SLAT supported              : $($hwCaps.SlatSupported)"
Write-Log "  TPM present / ready         : $($hwCaps.TpmPresent) / $($hwCaps.TpmReady)"
Write-Log "  Secure Boot enabled         : $($hwCaps.SecureBootEnabled)"
Write-Log "  UEFI firmware               : $($hwCaps.UefiEnabled)"
Write-Log "  HVCI (Memory Integrity) cap : $($hwCaps.HvciCapable)"
Write-Log "  Credential Guard capable    : $($hwCaps.CredentialGuardCapable)"
Write-Log "  Windows 10+                 : $($hwCaps.Win10OrLater)"
Write-Log "  Windows 11+                 : $($hwCaps.Win11OrLater)"

# 2. Pre-flight checks
Write-Log "--- Pre-flight Issue Detection ---"
$commonIssues = Get-DefenderIssues
if ($commonIssues.Count -gt 0) {
    Write-Log "Found $($commonIssues.Count) potential issue(s):"
    foreach ($i in $commonIssues) { Write-Log "  - $i" }
    Repair-CommonIssues -Issues $commonIssues
} else {
    Write-Log "  No pre-flight issues detected."
}

# 3. Core Defender components
Write-Log "--- Core Defender Components ---"
Enable-DefenderComponents

# 4. Attack Surface Reduction
Write-Log "--- Attack Surface Reduction (ASR) Rules ---"
Enable-AsrRules

# 5. Exploit Protection
Write-Log "--- Exploit Protection ---"
Enable-ExploitProtection

# 6. Memory Integrity (HVCI)
Write-Log "--- Memory Integrity (HVCI) ---"
Enable-MemoryIntegrity -HwCaps $hwCaps

# 7. Credential Guard
Write-Log "--- Credential Guard ---"
Enable-CredentialGuard -HwCaps $hwCaps

# 8. SmartScreen
Write-Log "--- SmartScreen ---"
Enable-SmartScreen

# 9. Windows Firewall
Write-Log "--- Windows Firewall ---"
Enable-WindowsFirewall

# 10. Ensure all Defender services are running
Write-Log "--- Defender Services ---"
Start-DefenderServices

# 11. Update signatures
Write-Log "--- Signature Update ---"
Update-DefenderSignatures

# 12. Event log analysis and auto-repair
Write-Log "--- Event Log Analysis ---"
$defenderIssues = Get-DefenderEvents
if ($defenderIssues.Count -gt 0) {
    Write-Log "Found $($defenderIssues.Count) issue(s) in event logs:"
    foreach ($i in $defenderIssues) { Write-Log "  - $i" }
    Repair-KnownIssues -Issues $defenderIssues
} else {
    Write-Log "  No issues found in recent event logs."
}

# 13. Quick scan
Write-Log "--- Quick Scan ---"
Start-QuickScan

# Final Status Report
Write-Log "--- Final Status Report ---"
try {
    $finalStatus = Get-MpComputerStatus -ErrorAction Stop

    $overallHealth = if ($finalStatus.AntispywareEnabled -and
                         $finalStatus.AntivirusEnabled -and
                         $finalStatus.RealTimeProtectionEnabled -and
                         $finalStatus.BehaviorMonitorEnabled -and
                         $finalStatus.IoavProtectionEnabled -and
                         $finalStatus.NISEnabled) { "Normal" } else { "Warning" }

    $output = @"
Antivirus Enabled                : $($finalStatus.AntivirusEnabled)
Antispyware Enabled              : $($finalStatus.AntispywareEnabled)
Real-Time Protection Enabled     : $($finalStatus.RealTimeProtectionEnabled)
Behaviour Monitor Enabled        : $($finalStatus.BehaviorMonitorEnabled)
IoAV Protection Enabled          : $($finalStatus.IoavProtectionEnabled)
On-Access Protection Enabled     : $($finalStatus.OnAccessProtectionEnabled)
Network Inspection Service       : $($finalStatus.NISEnabled)
Cloud Protection (MAPS)          : $($finalStatus.IsTamperProtected)
Tamper Protection                : $($finalStatus.IsTamperProtected)
Antivirus Signature Version      : $($finalStatus.AntivirusSignatureVersion)
Antispyware Signature Version    : $($finalStatus.AntispywareSignatureVersion)
NIS Signature Version            : $($finalStatus.NISSignatureVersion)
Memory Integrity (HVCI) Capable  : $($hwCaps.HvciCapable)
Credential Guard Capable         : $($hwCaps.CredentialGuardCapable)
"@
} catch {
    Write-Log "  [ERROR] Failed to get final Defender status: $_"
    $overallHealth = "Unknown"
    $output = "Unable to retrieve Defender status. This may be due to Tamper Protection or other restrictions. Check Windows Security settings."
}

Write-Log "Overall health: $overallHealth"
Write-Log $output

# NinjaRMM / RMM Property Output
if (Get-Command Ninja-Property-Set -ErrorAction SilentlyContinue) {
    Ninja-Property-Set msDefenderStatus $output
    $alertStatus = switch ($overallHealth) {
        "Normal"  { "Healthy" }
        "Warning" { "Failure" }
        default   { "Unknown" }
    }
    Ninja-Property-Set msDefenderAlert $alertStatus
}

Write-Log "  Defender fixes completed."
if ($hwCaps.HvciCapable -or $hwCaps.CredentialGuardCapable) {
    Write-Log "  NOTE: Memory Integrity and/or Credential Guard changes require a REBOOT to take effect."
}