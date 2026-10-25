# Check if called from main script (automated mode)
$AutomatedMode = $args -contains "--automated"
$OptimisationProfile = "optimal"
$OptimisationAction = ""

for ($argIndex = 0; $argIndex -lt $args.Count; $argIndex++) {
    $argValue = [string]$args[$argIndex]

    if ($argValue -eq "--profile" -and ($argIndex + 1) -lt $args.Count) {
        $OptimisationProfile = [string]$args[$argIndex + 1]
        $argIndex++
        continue
    }

    if ($argValue -like "--profile=*") {
        $OptimisationProfile = $argValue.Substring(10)
        continue
    }

    if ($argValue -eq "--action" -and ($argIndex + 1) -lt $args.Count) {
        $OptimisationAction = [string]$args[$argIndex + 1]
        $argIndex++
        continue
    }

    if ($argValue -like "--action=*") {
        $OptimisationAction = $argValue.Substring(9)
    }
}

if ([string]::IsNullOrWhiteSpace($OptimisationProfile)) {
    $OptimisationProfile = "optimal"
} else {
    $OptimisationProfile = $OptimisationProfile.ToLowerInvariant()
}

if ($OptimisationProfile -notin @("minimal", "optimal", "aggressive")) {
    $OptimisationProfile = "optimal"
}

$VisualOptimisationScript = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) "VisualOptimisation.ps1"

# Progress reporting functions for integration with main script
function Show-Progress {
    param([string]$Status, [int]$Percent = -1)
    
    # When showing the optimisation form, don't show progress dialogue - just write to console
    Write-Host $Status -ForegroundColor Cyan
}

function Update-Ui {
    param([System.Windows.Forms.Control]$Control = $null)

    if ($Control) {
        $Control.Refresh()
    }

    [System.Windows.Forms.Application]::DoEvents()
}

function Enable-DoubleBuffering {
    param([Parameter(Mandatory)][object]$Control)

    try {
        $doubleBufferedProperty = $Control.GetType().GetProperty(
            'DoubleBuffered',
            [System.Reflection.BindingFlags]'Instance, NonPublic'
        )

        if ($doubleBufferedProperty) {
            $doubleBufferedProperty.SetValue($Control, $true, $null)
        }
    } catch {
        Write-Host "Could not enable double buffering: $($_.Exception.Message)" -ForegroundColor DarkGray
    }
}

function ExecutionCompleted {
    if ($Global:MainProgressForm) {
        Show-Progress "System optimisation completed successfully!" 100
        Start-Sleep -Seconds 2
    }
}

# Function to log errors and validate objects
function Validate-Object {
    param (
        [Parameter(Mandatory)]
        [Object]$Object,
        [string]$ObjectName
    )

    if ($null -eq $Object) {
        Write-Host "Error: $ObjectName is null." -ForegroundColor Red
        return $false
    }
    return $true
}

# Safe execution wrapper to provide specific debug output for each action
function Safe-Execute {
    param (
        [scriptblock]$Block,
        [string]$Description = "Executing script block"
    )
    
    try {
        Show-Progress "Applying: $Description..."
        & $Block
        Write-Host "Completed: $Description" -ForegroundColor Green
    } catch {
        Write-Host "Error during $Description : $_" -ForegroundColor Red
    }
}

# Telemetry and background services optimisation functions - Modern Windows 10/11
function DisableDiagtrack {
    Safe-Execute { 
        $diagService = Get-Service -Name "DiagTrack" -ErrorAction SilentlyContinue
        if ($diagService) {
            Stop-Service -Name "DiagTrack" -Force -ErrorAction SilentlyContinue
            Set-Service -Name "DiagTrack" -StartupType Disabled -ErrorAction SilentlyContinue
        }
    } "DisableDiagtrack"
}

function DisableDiagtrack2 {
    Safe-Execute { 
        $dmwService = Get-Service -Name "dmwappushservice" -ErrorAction SilentlyContinue
        if ($dmwService) {
            Stop-Service -Name "dmwappushservice" -Force -ErrorAction SilentlyContinue
            Set-Service -Name "dmwappushservice" -StartupType Disabled -ErrorAction SilentlyContinue
        }
    } "DisableDiagtrack2"
}

function DisableAdvertisingID {
    Safe-Execute { 
        # Modern registry path for advertising ID
        $regPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo"
        if (-not (Test-Path $regPath)) { New-Item -Path $regPath -Force | Out-Null }
        Set-ItemProperty -Path $regPath -Name "DisabledByGroupPolicy" -Value 1 -Force 
        
        # User-level setting
        $userRegPath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\AdvertisingInfo"
        if (-not (Test-Path $userRegPath)) { New-Item -Path $userRegPath -Force | Out-Null }
        Set-ItemProperty -Path $userRegPath -Name "Enabled" -Value 0 -Force
    } "DisableAdvertisingID"
}

function DisableTelemetry {
    Safe-Execute { 
        $regPaths = @(
            "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection",
            "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection"
        )
        
        foreach ($regPath in $regPaths) {
            if (-not (Test-Path $regPath)) { New-Item -Path $regPath -Force | Out-Null }
            Set-ItemProperty -Path $regPath -Name "AllowTelemetry" -Value 0 -Force
        }
        
        # Additional Windows 11 telemetry settings
        $win11TelemetryPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search"
        if (-not (Test-Path $win11TelemetryPath)) { New-Item -Path $win11TelemetryPath -Force | Out-Null }
        Set-ItemProperty -Path $win11TelemetryPath -Name "AllowCortana" -Value 0 -Force
        
    } "DisableTelemetry"
}

function DisableDataUsage {
    Safe-Execute { 
        $dusmService = Get-Service -Name "DusmSvc" -ErrorAction SilentlyContinue
        if ($dusmService) {
            Set-Service -Name "DusmSvc" -StartupType Disabled -ErrorAction SilentlyContinue
        }
    } "DisableDataUsage"
}

function DisableFax {
    Safe-Execute { 
        $faxService = Get-Service -Name "Fax" -ErrorAction SilentlyContinue
        if ($faxService) {
            Set-Service -Name "Fax" -StartupType Disabled -ErrorAction SilentlyContinue
        }
    } "DisableFax"
}

function DisableParentalControls {
    Safe-Execute { 
        $wpcService = Get-Service -Name "WpcMonSvc" -ErrorAction SilentlyContinue
        if ($wpcService) {
            Set-Service -Name "WpcMonSvc" -StartupType Disabled -ErrorAction SilentlyContinue
        }
    } "DisableParentalControls"
}

function DisableGeoLocation {
    Safe-Execute { 
        $lfsvcService = Get-Service -Name "lfsvc" -ErrorAction SilentlyContinue
        if ($lfsvcService) {
            Set-Service -Name "lfsvc" -StartupType Disabled -ErrorAction SilentlyContinue
        }
        
        # Registry setting for location services
        $locationRegPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors"
        if (-not (Test-Path $locationRegPath)) { New-Item -Path $locationRegPath -Force | Out-Null }
        Set-ItemProperty -Path $locationRegPath -Name "DisableLocation" -Value 1 -Force
        
    } "DisableGeoLocation"
}

function DisableNFCPayments {
    Safe-Execute { 
        $semgrService = Get-Service -Name "SEMgrSvc" -ErrorAction SilentlyContinue
        if ($semgrService) {
            Set-Service -Name "SEMgrSvc" -StartupType Disabled -ErrorAction SilentlyContinue
        }
    } "DisableNFCPayments"
}

function DisableRetailDemo {
    Safe-Execute { 
        $retailDemoService = Get-Service -Name "RetailDemo" -ErrorAction SilentlyContinue
        if ($retailDemoService) {
            Set-Service -Name "RetailDemo" -StartupType Disabled -ErrorAction SilentlyContinue
        }
    } "DisableRetailDemo"
}

function DisableWindowsInside {
    Safe-Execute { 
        $wisvcService = Get-Service -Name "wisvc" -ErrorAction SilentlyContinue
        if ($wisvcService) {
            Set-Service -Name "wisvc" -StartupType Disabled -ErrorAction SilentlyContinue
        }
    } "DisableWindowsInside"
}

function DisableMapsManager {
    Safe-Execute { 
        $mapsBrokerService = Get-Service -Name "MapsBroker" -ErrorAction SilentlyContinue
        if ($mapsBrokerService) {
            Set-Service -Name "MapsBroker" -StartupType Disabled -ErrorAction SilentlyContinue
        }
    } "DisableMapsManager"
}

function DisableBackgroundApps {
    Safe-Execute { 
        # Modern Windows 10/11 background app settings
        $regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications"
        if (-not (Test-Path $regPath)) { New-Item -Path $regPath -Force | Out-Null }
        Set-ItemProperty -Path $regPath -Name "GlobalUserDisabled" -Value 1 -Force
        
        # System-wide policy
        $policyPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy"
        if (-not (Test-Path $policyPath)) { New-Item -Path $policyPath -Force | Out-Null }
        Set-ItemProperty -Path $policyPath -Name "LetAppsRunInBackground" -Value 2 -Force
        
    } "DisableBackgroundApps"
}

function DisableBackgroundAccess {
    Safe-Execute { 
        $regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications"
        if (-not (Test-Path $regPath)) { New-Item -Path $regPath -Force | Out-Null }
        Set-ItemProperty -Path $regPath -Name "GlobalUserDisabled" -Value 1 -Force
    } "DisableBackgroundAccess"
}

function DisableBackgroundAppsPerApp {
    Safe-Execute {
        # Disable ALL background apps (Windows 11 24H2+ method)
        $regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications"
        New-Item -Path $regPath -Force | Out-Null
        Set-ItemProperty -Path $regPath -Name "GlobalUserDisabled" -Value 1 -Type DWord -Force

        # Per-app "Never" via advanced options (more aggressive)
        Get-AppxPackage | ForEach-Object {
            $appPath = "$regPath\$($_.PackageFullName)"
            if (-not (Test-Path $appPath)) { New-Item -Path $appPath -Force | Out-Null }
            Set-ItemProperty -Path $appPath -Name "BackgroundAccess" -Value 0 -Type DWord -ErrorAction SilentlyContinue
        }
        Write-Host "All background apps forced to Never" -ForegroundColor Green
    } "DisableBackgroundAppsPerApp"
}

# Add new optimisation functions for Windows 10/11
function Set-CurrentSchemeValue {
    param(
        [Parameter(Mandatory)][string]$Subgroup,
        [Parameter(Mandatory)][string]$Setting,
        [Parameter(Mandatory)][int]$Value
    )

    powercfg -setacvalueindex SCHEME_CURRENT $Subgroup $Setting $Value 2>$null | Out-Null
    powercfg -setdcvalueindex SCHEME_CURRENT $Subgroup $Setting $Value 2>$null | Out-Null
}

function Disable-AttachedDevicePowerSaving {
    # Uncheck "Allow the computer to turn off this device to save power" for attached
    # network, USB, Bluetooth, audio, HID, mouse, and keyboard devices.
    $classIds = @(
        '{4d36e972-e325-11ce-bfc1-08002be10318}', # Network adapters
        '{36fc9e60-c465-11cf-8056-444553540000}', # USB
        '{88bae032-5a81-49f0-bc3d-a4ff138216d6}', # USB devices
        '{e0cbf06c-cd8b-4647-bb8a-263b43f0f974}', # Bluetooth
        '{4d36e96c-e325-11ce-bfc1-08002be10318}', # Sound and media
        '{745a17a0-74d3-11d0-b6fe-00a0c90f57da}', # HID
        '{4d36e96f-e325-11ce-bfc1-08002be10318}', # Mice
        '{4d36e96b-e325-11ce-bfc1-08002be10318}'  # Keyboards
    )

    $updated = 0
    foreach ($classId in $classIds) {
        $classPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Class\$classId"
        if (-not (Test-Path -LiteralPath $classPath)) { continue }
        $instances = @(Get-ChildItem -LiteralPath $classPath -ErrorAction SilentlyContinue | Where-Object { $_.PSChildName -match '^\d{4}$' })
        foreach ($instance in $instances) {
            if (-not $instance) { continue }
            Set-ItemProperty -LiteralPath $instance.PSPath -Name 'PnPCapabilities' -Value 24 -Type DWord -Force -ErrorAction SilentlyContinue
            $updated++
        }
    }
    Write-Host "  Device power saving disabled for $updated attached-device entries." -ForegroundColor Green

    $wmiChanged = 0
    try {
        $powerDevices = @(Get-CimInstance -Namespace 'root\wmi' -ClassName 'MSPower_DeviceEnable' -ErrorAction Stop)
        foreach ($powerDevice in $powerDevices) {
            try {
                if (-not $powerDevice.Enable) { continue }
                Set-CimInstance -InputObject $powerDevice -Property @{ Enable = $false } -ErrorAction Stop | Out-Null
                $wmiChanged++
            } catch {
                # Some firmware devices reject the write. The registry change above still covers the class.
            }
        }
        Write-Host "  Cleared device sleep on $wmiChanged power-managed devices." -ForegroundColor Green
    } catch {
        Write-Host "  Device power list was not available: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

function Enable-AttachedDevicePowerSaving {
    $classIds = @(
        '{4d36e972-e325-11ce-bfc1-08002be10318}',
        '{36fc9e60-c465-11cf-8056-444553540000}',
        '{88bae032-5a81-49f0-bc3d-a4ff138216d6}',
        '{e0cbf06c-cd8b-4647-bb8a-263b43f0f974}',
        '{4d36e96c-e325-11ce-bfc1-08002be10318}',
        '{745a17a0-74d3-11d0-b6fe-00a0c90f57da}',
        '{4d36e96f-e325-11ce-bfc1-08002be10318}',
        '{4d36e96b-e325-11ce-bfc1-08002be10318}'
    )

    foreach ($classId in $classIds) {
        $classPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Class\$classId"
        if (-not (Test-Path -LiteralPath $classPath)) { continue }
        Get-ChildItem -LiteralPath $classPath -ErrorAction SilentlyContinue | Where-Object { $_.PSChildName -match '^\d{4}$' } | ForEach-Object {
            Remove-ItemProperty -LiteralPath $_.PSPath -Name 'PnPCapabilities' -Force -ErrorAction SilentlyContinue
        }
    }

    try {
        $powerDevices = @(Get-CimInstance -Namespace 'root\wmi' -ClassName 'MSPower_DeviceEnable' -ErrorAction Stop)
        foreach ($powerDevice in $powerDevices) {
            try {
                Set-CimInstance -InputObject $powerDevice -Property @{ Enable = $true } -ErrorAction Stop | Out-Null
            } catch {}
        }
    } catch {}
}

function Optimise-PowerSettings {
    Safe-Execute {
        $ultimateGuid = 'e9a42b02-d5df-448d-aa00-03f14749eb61'
        $highPerfGuid = '8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c'
        $schemes = (powercfg -list 2>$null | Out-String)

        if ($schemes -notmatch $ultimateGuid) {
            $null = powercfg -duplicatescheme $ultimateGuid 2>&1
            $schemes = (powercfg -list 2>$null | Out-String)
        }

        if ($schemes -match $ultimateGuid) {
            powercfg -setactive $ultimateGuid 2>$null | Out-Null
            Write-Host "  Active power scheme: Ultimate Performance" -ForegroundColor Green
        } elseif ($schemes -match $highPerfGuid) {
            powercfg -setactive $highPerfGuid 2>$null | Out-Null
            Write-Host "  Active power scheme: High Performance" -ForegroundColor Green
        } else {
            $null = powercfg -duplicatescheme $highPerfGuid 2>&1
            powercfg -setactive $highPerfGuid 2>$null | Out-Null
            Write-Host "  Active power scheme: High Performance" -ForegroundColor Green
        }

        # USB selective suspend and USB 3 link power management off.
        Set-CurrentSchemeValue -Subgroup '2a737441-1930-4402-8d77-b2bebba308a3' -Setting '48e6b7a6-50f5-4782-a5d4-53bb8f07e226' -Value 0
        Set-CurrentSchemeValue -Subgroup '2a737441-1930-4402-8d77-b2bebba308a3' -Setting 'd4e98f31-5ffe-4ce1-be31-1b38b384c009' -Value 0

        # PCI Express link-state power management off. This belongs to the PCI Express group, not USB.
        Set-CurrentSchemeValue -Subgroup '501a4d13-42af-4429-9fd1-a8218c268e20' -Setting 'ee12f906-d277-404b-b6da-e5fa1a576df5' -Value 0

        # Never spin disks down while the scheme is active.
        Set-CurrentSchemeValue -Subgroup '0012ee47-9041-4b5d-9b77-535fba8b1442' -Setting '6738e2c4-e8a5-4a42-b16a-e040e769756e' -Value 0

        # Processor stays at full range, cores stay unparked, boost stays aggressive.
        Set-CurrentSchemeValue -Subgroup '54533251-82be-4824-96c1-47b60b740d00' -Setting '893dee8e-2bef-41e0-89c6-b55d0929964c' -Value 100
        Set-CurrentSchemeValue -Subgroup '54533251-82be-4824-96c1-47b60b740d00' -Setting 'bc5038f7-23e0-4960-96da-33abaf5935ec' -Value 100
        Set-CurrentSchemeValue -Subgroup '54533251-82be-4824-96c1-47b60b740d00' -Setting '0cc5b647-c1df-4637-891a-dec35c318583' -Value 100
        Set-CurrentSchemeValue -Subgroup '54533251-82be-4824-96c1-47b60b740d00' -Setting '94d3a615-a899-4ac5-ae2b-e4d8f634367f' -Value 1
        Set-CurrentSchemeValue -Subgroup '54533251-82be-4824-96c1-47b60b740d00' -Setting 'be337238-0d82-4146-a960-4f3749d470c7' -Value 2
        Set-CurrentSchemeValue -Subgroup '54533251-82be-4824-96c1-47b60b740d00' -Setting '45bcc044-d885-43e2-8605-ee0ec6e96b59' -Value 100
        Set-CurrentSchemeValue -Subgroup '54533251-82be-4824-96c1-47b60b740d00' -Setting '36687f9e-e3a5-4dbf-b1dc-15eb381c6863' -Value 0

        # Do not let idle sleep park the machine. The display timeout is left as the user set it.
        Set-CurrentSchemeValue -Subgroup '238c9fa8-0aad-41ed-83f4-97be242c8f20' -Setting '29f6c1db-86da-48c5-9fdb-f2b67b1f44da' -Value 0
        Set-CurrentSchemeValue -Subgroup '238c9fa8-0aad-41ed-83f4-97be242c8f20' -Setting '9d7815a6-7ee4-497e-8888-515a05f02364' -Value 0
        Set-CurrentSchemeValue -Subgroup '238c9fa8-0aad-41ed-83f4-97be242c8f20' -Setting '94ac6d29-73ce-41a6-809f-6363ba21b47e' -Value 0

        # Wireless adapter power saving off.
        Set-CurrentSchemeValue -Subgroup '19cbb8fa-5279-450e-9fac-8a3d5fedd0c1' -Setting '12bbebe6-58d6-4636-95bb-3217ef867c1a' -Value 0

        powercfg -setactive SCHEME_CURRENT 2>$null | Out-Null
        Write-Host "  Power scheme tuned for maximum performance on mains and battery." -ForegroundColor Green
        Write-Host "  Laptops will use more battery. Sleep can still be started from the Start menu." -ForegroundColor Yellow

        Disable-AttachedDevicePowerSaving

        $throttlePath = 'HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling'
        if (-not (Test-Path $throttlePath)) { New-Item -Path $throttlePath -Force | Out-Null }
        Set-ItemProperty -Path $throttlePath -Name 'PowerThrottlingOff' -Value 1 -Type DWord -Force
        Write-Host "  Windows power throttling disabled so background work is not capped." -ForegroundColor Green
    } "Optimise-PowerSettings"
}

function Optimise-NetworkSettings {
    Safe-Execute {
        # Disable network throttling for multimedia/games
        $regPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"
        if (-not (Test-Path $regPath)) { New-Item -Path $regPath -Force | Out-Null }
        Set-ItemProperty -Path $regPath -Name "NetworkThrottlingIndex" -Value 0xffffffff -Force

        # TCP optimisations
        netsh int tcp set global autotuninglevel=normal 2>$null | Out-Null
        netsh int tcp set global chimney=enabled 2>$null | Out-Null
        netsh int tcp set global rss=enabled 2>$null | Out-Null
        netsh int tcp set global netdma=enabled 2>$null | Out-Null

        # Enable ECN (Explicit Congestion Notification) for better throughput
        netsh int tcp set global ecncapability=enabled 2>$null | Out-Null

        # Disable Nagle algorithm for lower latency (better for gaming/real-time apps)
        $tcpParams = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"
        Set-ItemProperty -Path $tcpParams -Name "TcpAckFrequency" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $tcpParams -Name "TCPNoDelay" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue

        # Increase DNS cache size for faster hostname resolution
        $dnsCache = "HKLM:\SYSTEM\CurrentControlSet\Services\Dnscache\Parameters"
        if (-not (Test-Path $dnsCache)) { New-Item -Path $dnsCache -Force | Out-Null }
        Set-ItemProperty -Path $dnsCache -Name "CacheHashTableBucketSize" -Value 1 -Type DWord -Force
        Set-ItemProperty -Path $dnsCache -Name "CacheHashTableSize" -Value 384 -Type DWord -Force
        Set-ItemProperty -Path $dnsCache -Name "MaxCacheEntryTtlLimit" -Value 64000 -Type DWord -Force
        Set-ItemProperty -Path $dnsCache -Name "MaxSOACacheEntryTtlLimit" -Value 301 -Type DWord -Force

        # Disable LMHOSTS lookup (legacy NetBIOS name resolution, not needed on modern networks)
        $lmhostsPath = "HKLM:\SYSTEM\CurrentControlSet\Services\NetBT\Parameters"
        if (Test-Path $lmhostsPath) {
            Set-ItemProperty -Path $lmhostsPath -Name "EnableLMHOSTS" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
        }

        # Disable QoS bandwidth reservation (Windows reserves 20% by default)
        $qosPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Psched"
        if (-not (Test-Path $qosPath)) { New-Item -Path $qosPath -Force | Out-Null }
        Set-ItemProperty -Path $qosPath -Name "NonBestEffortLimit" -Value 0 -Type DWord -Force

        # Enable TCP timestamps for better RTT calculation (improves throughput on busy networks)
        netsh int tcp set global timestamps=enabled 2>$null | Out-Null

    } "Optimise-NetworkSettings"
}

function Optimise-MemoryManagement {
    Safe-Execute {
        $regPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"

        # LargeSystemCache is a file-server setting. On a desktop it holds file data in RAM
        # and pushes programs out. Keep the cache working for programs instead.
        Set-ItemProperty -Path $regPath -Name "LargeSystemCache" -Value 0 -Type DWord -Force
        Set-ItemProperty -Path $regPath -Name "ClearPageFileAtShutdown" -Value 0 -Type DWord -Force

        $totalKb = 0
        try {
            $os = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop
            $totalKb = [int64]$os.TotalVisibleMemorySize
        } catch {}

        # Keep the kernel resident only when the machine has 16 GB or more.
        $pinKernel = 0
        $sixteenGbInKb = 16 * 1024 * 1024
        if ($totalKb -ge $sixteenGbInKb) { $pinKernel = 1 }
        Set-ItemProperty -Path $regPath -Name "DisablePagingExecutive" -Value $pinKernel -Type DWord -Force

        $totalGb = [math]::Round($totalKb / 1MB, 1)
        Write-Host "  Desktop memory policy applied ($totalGb GB installed)." -ForegroundColor Green
    } "Optimise-MemoryManagement"
}

function Test-SystemDiskSolidState {
    try {
        $drive = [string]$env:SystemDrive
        if ([string]::IsNullOrWhiteSpace($drive)) { return $false }
        $letter = $drive.TrimEnd('\').TrimEnd(':')
        if ($letter.Length -ne 1) { return $false }
        $partition = Get-Partition -DriveLetter $letter -ErrorAction Stop | Select-Object -First 1
        if (-not $partition) { return $false }
        $disk = Get-Disk -Number $partition.DiskNumber -ErrorAction Stop
        $media = [string]$disk.MediaType
        $bus = [string]$disk.BusType
        if ($media -eq 'SSD' -or $media -eq 'SCM' -or $bus -eq 'NVMe') { return $true }
    } catch {}
    return $false
}

function Optimise-RuntimeFootprint {
    Safe-Execute {
        try {
            $os = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop
            $totalKb = [double]$os.TotalVisibleMemorySize
            $freeKb = [double]$os.FreePhysicalMemory
            $usedPct = 0
            if ($totalKb -gt 0) { $usedPct = [math]::Round((($totalKb - $freeKb) / $totalKb) * 100, 0) }
            $usedGb = [math]::Round(($totalKb - $freeKb) / 1MB, 1)
            $totalGb = [math]::Round($totalKb / 1MB, 1)
            Write-Host "  Memory in use now: $usedGb GB of $totalGb GB ($usedPct%)." -ForegroundColor Cyan
            Write-Host "  Largest processes:" -ForegroundColor Cyan
            Get-Process | Sort-Object WorkingSet64 -Descending | Select-Object -First 8 | ForEach-Object {
                $mb = [math]::Round($_.WorkingSet64 / 1MB, 0)
                Write-Host ("    {0,-28} {1,5} MB" -f $_.ProcessName, $mb)
            }
        } catch {
            Write-Host "  Could not read the current memory snapshot." -ForegroundColor Yellow
        }

        # Reserve less CPU for background multimedia so the foreground stays responsive.
        $profilePath = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile'
        if (-not (Test-Path $profilePath)) { New-Item -Path $profilePath -Force | Out-Null }
        Set-ItemProperty -Path $profilePath -Name 'SystemResponsiveness' -Value 10 -Type DWord -Force
        Set-ItemProperty -Path $profilePath -Name 'NetworkThrottlingIndex' -Value 0xffffffff -Type DWord -Force

        $gamesPath = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games'
        if (-not (Test-Path $gamesPath)) { New-Item -Path $gamesPath -Force | Out-Null }
        Set-ItemProperty -Path $gamesPath -Name 'GPU Priority' -Value 8 -Type DWord -Force
        Set-ItemProperty -Path $gamesPath -Name 'Priority' -Value 6 -Type DWord -Force
        Set-ItemProperty -Path $gamesPath -Name 'Scheduling Category' -Value 'High' -Type String -Force
        Set-ItemProperty -Path $gamesPath -Name 'SFIO Priority' -Value 'High' -Type String -Force

        Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl' -Name 'Win32PrioritySeparation' -Value 38 -Type DWord -Force
        Set-ItemProperty -Path 'HKCU:\Control Panel\Desktop' -Name 'MenuShowDelay' -Value '0' -Type String -Force

        # Game DVR records in the background and holds memory. Game Mode stays on.
        $gameBarPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR'
        if (-not (Test-Path $gameBarPath)) { New-Item -Path $gameBarPath -Force | Out-Null }
        Set-ItemProperty -Path $gameBarPath -Name 'AppCaptureEnabled' -Value 0 -Type DWord -Force
        $gameBarPolicy = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR'
        if (-not (Test-Path $gameBarPolicy)) { New-Item -Path $gameBarPolicy -Force | Out-Null }
        Set-ItemProperty -Path $gameBarPolicy -Name 'AllowGameDVR' -Value 0 -Type DWord -Force
        $gameBarUser = 'HKCU:\Software\Microsoft\GameBar'
        if (-not (Test-Path $gameBarUser)) { New-Item -Path $gameBarUser -Force | Out-Null }
        Set-ItemProperty -Path $gameBarUser -Name 'AutoGameModeEnabled' -Value 1 -Type DWord -Force
        Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers' -Name 'HwSchMode' -Value 2 -Type DWord -Force -ErrorAction SilentlyContinue

        # Edge startup boost and background mode are a common idle-RAM cost. Browsing still works.
        foreach ($edgePolicy in @(
            'HKLM:\SOFTWARE\Policies\Microsoft\Edge',
            'HKCU:\SOFTWARE\Policies\Microsoft\Edge'
        )) {
            if (-not (Test-Path $edgePolicy)) { New-Item -Path $edgePolicy -Force | Out-Null }
            Set-ItemProperty -Path $edgePolicy -Name 'StartupBoostEnabled' -Value 0 -Type DWord -Force
            Set-ItemProperty -Path $edgePolicy -Name 'BackgroundModeEnabled' -Value 0 -Type DWord -Force
            Set-ItemProperty -Path $edgePolicy -Name 'SleepingTabsEnabled' -Value 1 -Type DWord -Force
        }

        # Store and inbox apps stop running while they are closed. Settings, Start, and Explorer still open normally.
        DisableBackgroundApps
        DisableBackgroundAppsPerApp

        # Widgets and the feed board stay resident after they are closed. The shell still opens normally.
        Disable-WindowsWidgets

        # Windows holds startup programs for about 10 seconds. Remove that wait.
        $startupDelayPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Serialize'
        if (-not (Test-Path $startupDelayPath)) { New-Item -Path $startupDelayPath -Force | Out-Null }
        Set-ItemProperty -Path $startupDelayPath -Name 'StartupDelayInMSec' -Value 0 -Type DWord -Force

        # NDU tracks per-app network use and can pin a service host in memory. Networking itself stays up.
        $nduPath = 'HKLM:\SYSTEM\CurrentControlSet\Services\Ndu'
        if (Test-Path $nduPath) {
            Set-ItemProperty -Path $nduPath -Name 'Start' -Value 4 -Type DWord -Force
        }

        if (Test-SystemDiskSolidState) {
            $prefetchPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\PrefetchParameters'
            if (Test-Path $prefetchPath) {
                Set-ItemProperty -Path $prefetchPath -Name 'EnablePrefetcher' -Value 0 -Type DWord -Force
                Set-ItemProperty -Path $prefetchPath -Name 'EnableSuperfetch' -Value 0 -Type DWord -Force
                Write-Host "  Prefetch disabled because the system disk is solid-state." -ForegroundColor Green
            }
            fsutil behavior set disablelastaccess 1 2>$null | Out-Null
        } else {
            Write-Host "  Prefetch left on because the system disk is not a detected SSD." -ForegroundColor Yellow
        }

        # Legacy peer-name services are not used for normal internet or file sharing.
        foreach ($legacyService in @('PNRPsvc', 'p2psvc', 'p2pimsvc', 'Fax', 'RetailDemo', 'MapsBroker', 'RemoteRegistry')) {
            $service = Get-Service -Name $legacyService -ErrorAction SilentlyContinue
            if ($service) {
                Stop-Service -Name $legacyService -Force -ErrorAction SilentlyContinue
                Set-Service -Name $legacyService -StartupType Disabled -ErrorAction SilentlyContinue
            }
        }

        Write-Host "  Runtime footprint applied. Restart so service and device changes finish loading." -ForegroundColor Yellow
        Write-Host "  Idle memory stays higher than the open programs suggest. Windows compresses unused pages and keeps a standby cache so programs reopen faster. Both are released when an app needs the RAM, so this pass does not empty that cache." -ForegroundColor Yellow
    } "Optimise-RuntimeFootprint"
}

function Disable-WindowsDefenderRealTime {
    Safe-Execute {
        # Disable Windows Defender real-time protection (user choice)
        # Note: This reduces security - use with caution
        $regPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection"
        if (-not (Test-Path $regPath)) { New-Item -Path $regPath -Force | Out-Null }
        Set-ItemProperty -Path $regPath -Name "DisableRealtimeMonitoring" -Value 1 -Force
        
    } "Disable-WindowsDefenderRealTime"
}

function Optimise-Gaming {
    Safe-Execute {
        # Disable Xbox Game Bar and Game DVR (reduces background overhead)
        $gameBarPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR"
        if (-not (Test-Path $gameBarPath)) { New-Item -Path $gameBarPath -Force | Out-Null }
        Set-ItemProperty -Path $gameBarPath -Name "AppCaptureEnabled" -Value 0 -Force

        $gameBarPolicy = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR"
        if (-not (Test-Path $gameBarPolicy)) { New-Item -Path $gameBarPolicy -Force | Out-Null }
        Set-ItemProperty -Path $gameBarPolicy -Name "AllowGameDVR" -Value 0 -Force

        $gameBarPath2 = "HKCU:\Software\Microsoft\GameBar"
        if (-not (Test-Path $gameBarPath2)) { New-Item -Path $gameBarPath2 -Force | Out-Null }
        Set-ItemProperty -Path $gameBarPath2 -Name "UseNexusForGameBarEnabled" -Value 0 -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $gameBarPath2 -Name "ShowStartupPanel" -Value 0 -Force -ErrorAction SilentlyContinue

        # Enable Game Mode for better CPU/GPU prioritisation
        Set-ItemProperty -Path $gameBarPath2 -Name "AutoGameModeEnabled" -Value 1 -Force

        # Enable Hardware-Accelerated GPU Scheduling (Windows 10 2004+)
        Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" -Name "HwSchMode" -Value 2 -Force -ErrorAction SilentlyContinue

        # Disable mouse pointer acceleration (enhance pointer precision)
        Set-ItemProperty -Path "HKCU:\Control Panel\Mouse" -Name "MouseSpeed" -Value "0" -Force
        Set-ItemProperty -Path "HKCU:\Control Panel\Mouse" -Name "MouseThreshold1" -Value "0" -Force
        Set-ItemProperty -Path "HKCU:\Control Panel\Mouse" -Name "MouseThreshold2" -Value "0" -Force

        # Disable fullscreen optimisations globally
        $gameConfigPath = "HKCU:\System\GameConfigStore"
        if (-not (Test-Path $gameConfigPath)) { New-Item -Path $gameConfigPath -Force | Out-Null }
        Set-ItemProperty -Path $gameConfigPath -Name "GameDVR_FSEBehaviorMode" -Value 2 -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $gameConfigPath -Name "GameDVR_HonorUserFSEBehaviorMode" -Value 1 -Force -ErrorAction SilentlyContinue

    } "Gaming Performance Optimisations"
}

function Optimise-Storage {
    Safe-Execute {
        # Disable NTFS 8.3 filename creation (reduces metadata overhead)
        fsutil behavior set disable8dot3 1 2>$null

        # Disable NTFS last access timestamp (reduces disk writes on every file read)
        fsutil behavior set disablelastaccess 1 2>$null

        # Disable Delivery Optimisation (prevents Windows using your bandwidth to seed updates to others)
        $doRegPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization"
        if (-not (Test-Path $doRegPath)) { New-Item -Path $doRegPath -Force | Out-Null }
        Set-ItemProperty -Path $doRegPath -Name "DODownloadMode" -Value 0 -Force

        $doService = Get-Service "DoSvc" -ErrorAction SilentlyContinue
        if ($doService) {
            Stop-Service "DoSvc" -Force -ErrorAction SilentlyContinue
            Set-Service "DoSvc" -StartupType Manual -ErrorAction SilentlyContinue
        }

        # Disable hibernation to reclaim disk space equal to installed RAM
        powercfg -h off 2>$null

        # Disable Storage Sense auto-cleanup to prevent unexpected file deletions
        $storageSensePath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\StorageSense\Parameters\StoragePolicy"
        if (-not (Test-Path $storageSensePath)) { New-Item -Path $storageSensePath -Force | Out-Null }
        Set-ItemProperty -Path $storageSensePath -Name "01" -Value 0 -Force

    } "Storage & File System Optimisations"
}

function Optimise-Startup {
    Safe-Execute {
        # Remove startup delay for apps (Windows adds a 10-second delay by default)
        $startupDelayPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Serialize"
        if (-not (Test-Path $startupDelayPath)) { New-Item -Path $startupDelayPath -Force | Out-Null }
        Set-ItemProperty -Path $startupDelayPath -Name "StartupDelayInMSec" -Value 0 -Force

        # Set boot menu timeout to 5 seconds (default is 30)
        bcdedit /timeout 5 2>$null | Out-Null

        # Disable AutoRun/AutoPlay for all drive types
        $autoRunPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer"
        if (-not (Test-Path $autoRunPath)) { New-Item -Path $autoRunPath -Force | Out-Null }
        Set-ItemProperty -Path $autoRunPath -Name "NoDriveTypeAutoRun" -Value 255 -Force

        $autoRunPath2 = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer"
        if (-not (Test-Path $autoRunPath2)) { New-Item -Path $autoRunPath2 -Force | Out-Null }
        Set-ItemProperty -Path $autoRunPath2 -Name "NoDriveTypeAutoRun" -Value 255 -Force

        # Disable Remote Assistance (security + reduces background listener overhead)
        $raPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Remote Assistance"
        if (Test-Path $raPath) {
            Set-ItemProperty -Path $raPath -Name "fAllowToGetHelp" -Value 0 -Force -ErrorAction SilentlyContinue
        }

        # Increase processor scheduling priority for foreground applications
        Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl" -Name "Win32PrioritySeparation" -Value 38 -Force

    } "Startup & Boot Optimisations"
}

function Optimise-ScheduledTasks {
    Safe-Execute {
        Write-Host "Disabling unnecessary scheduled tasks..." -ForegroundColor Cyan

        $tasks = @(
            "\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser",
            "\Microsoft\Windows\Application Experience\ProgramDataUpdater",
            "\Microsoft\Windows\Application Experience\MareBackup",
            "\Microsoft\Windows\Application Experience\StartupAppTask",
            "\Microsoft\Windows\Customer Experience Improvement Program\Consolidator",
            "\Microsoft\Windows\Customer Experience Improvement Program\KernelCeipTask",
            "\Microsoft\Windows\Customer Experience Improvement Program\UsbCeip",
            "\Microsoft\Windows\Autochk\Proxy",
            "\Microsoft\Windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticDataCollector",
            "\Microsoft\Windows\DiskFootprint\Diagnostics",
            "\Microsoft\Windows\Maintenance\WinSAT",
            "\Microsoft\Windows\Feedback\Siuf\DmClient",
            "\Microsoft\Windows\Feedback\Siuf\DmClientOnScenarioDownload",
            "\Microsoft\Windows\Windows Error Reporting\QueueReporting",
            "\Microsoft\Windows\Power Efficiency Diagnostics\AnalyzeSystem",
            "\Microsoft\Windows\CloudExperienceHost\CreateObjectTask",
            "\Microsoft\Windows\PushToInstall\LoginCheck",
            "\Microsoft\Windows\PushToInstall\Registration",
            "\Microsoft\Windows\License Manager\TempSignedLicenseExchange",
            "\Microsoft\Windows\Clip\License Validation",
            "\Microsoft\Windows\Shell\FamilySafetyMonitor",
            "\Microsoft\Windows\Shell\FamilySafetyRefreshTask",
            "\Microsoft\Windows\ApplicationData\DsSvcCleanup"
        )

        foreach ($task in $tasks) {
            $result = schtasks /Change /TN $task /Disable 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-Host "  Disabled: $task" -ForegroundColor Green
            } else {
                Write-Host "  Skipped (not found): $task" -ForegroundColor DarkGray
            }
        }

        Write-Host "Scheduled task cleanup complete." -ForegroundColor Green
    } "Optimise-ScheduledTasks"
}

function Disable-WindowsWidgets {
    Safe-Execute {
        Write-Host "Disabling Windows Widgets and feed surfaces..." -ForegroundColor Cyan

        $explorerAdvancedPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
        if (-not (Test-Path $explorerAdvancedPath)) { New-Item -Path $explorerAdvancedPath -Force | Out-Null }
        Set-ItemProperty -Path $explorerAdvancedPath -Name "TaskbarDa" -Value 0 -Force -ErrorAction SilentlyContinue

        $widgetsPolicyPath = "HKLM:\SOFTWARE\Policies\Microsoft\Dsh"
        if (-not (Test-Path $widgetsPolicyPath)) { New-Item -Path $widgetsPolicyPath -Force | Out-Null }
        Set-ItemProperty -Path $widgetsPolicyPath -Name "AllowNewsAndInterests" -Value 0 -Force

        $feedsPolicyPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Feeds"
        if (-not (Test-Path $feedsPolicyPath)) { New-Item -Path $feedsPolicyPath -Force | Out-Null }
        Set-ItemProperty -Path $feedsPolicyPath -Name "EnableFeeds" -Value 0 -Force

        $feedsUserPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Feeds"
        if (-not (Test-Path $feedsUserPath)) { New-Item -Path $feedsUserPath -Force | Out-Null }
        Set-ItemProperty -Path $feedsUserPath -Name "ShellFeedsTaskbarViewMode" -Value 2 -Force -ErrorAction SilentlyContinue

        Stop-Process -Name Widgets -Force -ErrorAction SilentlyContinue
        Stop-Process -Name WidgetService -Force -ErrorAction SilentlyContinue
    } "Disable-WindowsWidgets"
}


function Optimise-UICleanup {
    Safe-Execute {
        # Disable transparency effects
        $personalisePath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize"
        if (-not (Test-Path $personalisePath)) { New-Item -Path $personalisePath -Force | Out-Null }
        Set-ItemProperty -Path $personalisePath -Name "EnableTransparency" -Value 0 -Force

        # Disable Windows Spotlight, lock screen ads, Start menu suggestions, and Windows Tips
        $cdmPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
        if (-not (Test-Path $cdmPath)) { New-Item -Path $cdmPath -Force | Out-Null }
        Set-ItemProperty -Path $cdmPath -Name "RotatingLockScreenEnabled" -Value 0 -Force
        Set-ItemProperty -Path $cdmPath -Name "SubscribedContent-338387Enabled" -Value 0 -Force  # Windows tips
        Set-ItemProperty -Path $cdmPath -Name "SubscribedContent-338388Enabled" -Value 0 -Force  # Start suggestions
        Set-ItemProperty -Path $cdmPath -Name "SubscribedContent-338389Enabled" -Value 0 -Force  # Lock screen tips
        Set-ItemProperty -Path $cdmPath -Name "SubscribedContent-353698Enabled" -Value 0 -Force  # Timeline suggestions
        Set-ItemProperty -Path $cdmPath -Name "SoftLandingEnabled" -Value 0 -Force
        Set-ItemProperty -Path $cdmPath -Name "SystemPaneSuggestionsEnabled" -Value 0 -Force

        # Disable Timeline / Activity History
        $activityPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System"
        if (-not (Test-Path $activityPath)) { New-Item -Path $activityPath -Force | Out-Null }
        Set-ItemProperty -Path $activityPath -Name "EnableActivityFeed" -Value 0 -Force
        Set-ItemProperty -Path $activityPath -Name "PublishUserActivities" -Value 0 -Force
        Set-ItemProperty -Path $activityPath -Name "UploadUserActivities" -Value 0 -Force

        # Disable Widgets and feed surfaces.
        Disable-WindowsWidgets

        # Disable Sticky Keys prompt (avoids accidental trigger interruptions)
        Set-ItemProperty -Path "HKCU:\Control Panel\Accessibility\StickyKeys" -Name "Flags" -Value "506" -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path "HKCU:\Control Panel\Accessibility\ToggleKeys" -Name "Flags" -Value "58" -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path "HKCU:\Control Panel\Accessibility\Keyboard Response" -Name "Flags" -Value "122" -Force -ErrorAction SilentlyContinue

        # Disable search highlights in taskbar search
        $searchPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\SearchSettings"
        if (-not (Test-Path $searchPath)) { New-Item -Path $searchPath -Force | Out-Null }
        Set-ItemProperty -Path $searchPath -Name "IsDynamicSearchBoxEnabled" -Value 0 -Force -ErrorAction SilentlyContinue

    } "UI & Notification Cleanup"
}

function Optimise-Privacy {
    Safe-Execute {
        # Disable Windows Feedback / SIUF prompts
        $siufPath = "HKCU:\SOFTWARE\Microsoft\Siuf\Rules"
        if (-not (Test-Path $siufPath)) { New-Item -Path $siufPath -Force | Out-Null }
        Set-ItemProperty -Path $siufPath -Name "NumberOfSIUFInPeriod" -Value 0 -Force
        Set-ItemProperty -Path $siufPath -Name "PeriodInNanoSeconds" -Value 0 -Force

        # Disable tailored experiences with diagnostic data
        $privacyPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Privacy"
        if (-not (Test-Path $privacyPath)) { New-Item -Path $privacyPath -Force | Out-Null }
        Set-ItemProperty -Path $privacyPath -Name "TailoredExperiencesWithDiagnosticDataEnabled" -Value 0 -Force

        # Disable inking and typing personalisation (prevents sending keystrokes to Microsoft)
        $inkPath = "HKCU:\Software\Microsoft\InputPersonalization"
        if (-not (Test-Path $inkPath)) { New-Item -Path $inkPath -Force | Out-Null }
        Set-ItemProperty -Path $inkPath -Name "RestrictImplicitInkCollection" -Value 1 -Force
        Set-ItemProperty -Path $inkPath -Name "RestrictImplicitTextCollection" -Value 1 -Force

        $inkStorePath = "HKCU:\Software\Microsoft\InputPersonalization\TrainedDataStore"
        if (-not (Test-Path $inkStorePath)) { New-Item -Path $inkStorePath -Force | Out-Null }
        Set-ItemProperty -Path $inkStorePath -Name "HarvestContacts" -Value 0 -Force

        # Disable speech and Cortana voice activation and personalisation
        $speechPath = "HKCU:\Software\Microsoft\Speech_OneCore\Settings\VoiceActivation\UserPreferenceForAllApps"
        if (-not (Test-Path $speechPath)) { New-Item -Path $speechPath -Force | Out-Null }
        Set-ItemProperty -Path $speechPath -Name "AgentActivationEnabled" -Value 0 -Force

        $personalisationPath = "HKCU:\Software\Microsoft\Personalization\Settings"
        if (-not (Test-Path $personalisationPath)) { New-Item -Path $personalisationPath -Force | Out-Null }
        Set-ItemProperty -Path $personalisationPath -Name "AcceptedPrivacyPolicy" -Value 0 -Force

        # Disable sending handwriting data to Microsoft
        $handwritingPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\TabletPC"
        if (-not (Test-Path $handwritingPath)) { New-Item -Path $handwritingPath -Force | Out-Null }
        Set-ItemProperty -Path $handwritingPath -Name "PreventHandwritingDataSharing" -Value 1 -Force

        # Tighten Windows Error Reporting - disable submissions entirely via policy
        $werPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Error Reporting"
        if (-not (Test-Path $werPath)) { New-Item -Path $werPath -Force | Out-Null }
        Set-ItemProperty -Path $werPath -Name "Disabled" -Value 1 -Force
        Set-ItemProperty -Path $werPath -Name "DontSendAdditionalData" -Value 1 -Force
        Set-ItemProperty -Path $werPath -Name "LoggingDisabled" -Value 1 -Force

        # Disable AutoLogger-Diagtrack-Listener (a persistent telemetry session)
        $autologgerPath = "HKLM:\SYSTEM\CurrentControlSet\Control\WMI\Autologger\AutoLogger-Diagtrack-Listener"
        if (Test-Path $autologgerPath) {
            Set-ItemProperty -Path $autologgerPath -Name "Start" -Value 0 -Force -ErrorAction SilentlyContinue
        }

        # Tighten DataCollection policy: Security level (0), disable one-settings downloads
        $dcPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection"
        if (-not (Test-Path $dcPath)) { New-Item -Path $dcPath -Force | Out-Null }
        Set-ItemProperty -Path $dcPath -Name "AllowTelemetry" -Value 0 -Force
        Set-ItemProperty -Path $dcPath -Name "MaxTelemetryAllowed" -Value 0 -Force
        Set-ItemProperty -Path $dcPath -Name "DisableOneSettingsDownloads" -Value 1 -Force
        Set-ItemProperty -Path $dcPath -Name "DoNotShowFeedbackNotifications" -Value 1 -Force

        # Disable app diagnostic data access via policy
        $appPrivPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy"
        if (-not (Test-Path $appPrivPath)) { New-Item -Path $appPrivPath -Force | Out-Null }
        Set-ItemProperty -Path $appPrivPath -Name "LetAppsGetDiagnosticInfo" -Value 2 -Force

        # Disable access to account info, calendar, call history, contacts by apps
        Set-ItemProperty -Path $appPrivPath -Name "LetAppsAccessAccountInfo" -Value 2 -Force
        Set-ItemProperty -Path $appPrivPath -Name "LetAppsAccessCalendar" -Value 2 -Force
        Set-ItemProperty -Path $appPrivPath -Name "LetAppsAccessCallHistory" -Value 2 -Force
        Set-ItemProperty -Path $appPrivPath -Name "LetAppsAccessContacts" -Value 2 -Force
        Set-ItemProperty -Path $appPrivPath -Name "LetAppsAccessEmail" -Value 2 -Force
        Set-ItemProperty -Path $appPrivPath -Name "LetAppsAccessMessaging" -Value 2 -Force
        Set-ItemProperty -Path $appPrivPath -Name "LetAppsAccessTasks" -Value 2 -Force

        # Disable "Find My Device" / device tracking
        $findMyPath = "HKLM:\SOFTWARE\Policies\Microsoft\FindMyDevice"
        if (-not (Test-Path $findMyPath)) { New-Item -Path $findMyPath -Force | Out-Null }
        Set-ItemProperty -Path $findMyPath -Name "AllowFindMyDevice" -Value 0 -Force

        Write-Host "Privacy hardening complete." -ForegroundColor Green
    } "Optimise-Privacy"
}

function Apply-ProfileBasedDebloat {
    param([string]$Profile = "optimal")

    Safe-Execute {
        Write-Host "Applying profile-based deep tweaks: $Profile" -ForegroundColor Cyan

        $systemPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System"
        if (-not (Test-Path $systemPath)) { New-Item -Path $systemPath -Force | Out-Null }

        $cloudContentMachinePath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent"
        if (-not (Test-Path $cloudContentMachinePath)) { New-Item -Path $cloudContentMachinePath -Force | Out-Null }

        $cloudContentUserPath = "HKCU:\SOFTWARE\Policies\Microsoft\Windows\CloudContent"
        if (-not (Test-Path $cloudContentUserPath)) { New-Item -Path $cloudContentUserPath -Force | Out-Null }

        # Baseline recommendation and cloud-content suppression for all profiles.
        Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "Start_TrackDocs" -Value 0 -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $cloudContentMachinePath -Name "DisableWindowsConsumerFeatures" -Value 1 -Force
        Set-ItemProperty -Path $cloudContentUserPath -Name "DisableTailoredExperiencesWithDiagnosticData" -Value 1 -Force

        if ($Profile -in @("optimal", "aggressive")) {
            # Deeper search and cloud-sync restrictions.
            $searchPolicyPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search"
            if (-not (Test-Path $searchPolicyPath)) { New-Item -Path $searchPolicyPath -Force | Out-Null }
            Set-ItemProperty -Path $searchPolicyPath -Name "AllowCloudSearch" -Value 0 -Force
            Set-ItemProperty -Path $searchPolicyPath -Name "AllowSearchToUseLocation" -Value 0 -Force
            Set-ItemProperty -Path $searchPolicyPath -Name "DisableWebSearch" -Value 1 -Force
            Set-ItemProperty -Path $searchPolicyPath -Name "ConnectedSearchUseWeb" -Value 0 -Force
            Set-ItemProperty -Path $searchPolicyPath -Name "EnableDynamicContentInWSB" -Value 0 -Force -ErrorAction SilentlyContinue

            Set-ItemProperty -Path $systemPath -Name "EnableAppUriHandlers" -Value 0 -Force -ErrorAction SilentlyContinue
            Set-ItemProperty -Path $systemPath -Name "AllowCrossDeviceClipboard" -Value 0 -Force -ErrorAction SilentlyContinue

            $doPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization"
            if (-not (Test-Path $doPath)) { New-Item -Path $doPath -Force | Out-Null }
            Set-ItemProperty -Path $doPath -Name "DODownloadMode" -Value 99 -Force
        }

        if ($Profile -eq "aggressive") {
            # Aggressive profile: block additional app privacy categories and cross-device surfaces.
            $appPrivacyPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy"
            if (-not (Test-Path $appPrivacyPath)) { New-Item -Path $appPrivacyPath -Force | Out-Null }

            $forceDenyValues = @(
                "LetAppsAccessLocation",
                "LetAppsAccessCamera",
                "LetAppsAccessMicrophone",
                "LetAppsAccessNotifications",
                "LetAppsAccessMotion",
                "LetAppsAccessRadios",
                "LetAppsAccessPhone",
                "LetAppsActivateWithVoice",
                "LetAppsActivateWithVoiceAboveLock",
                "LetAppsSyncWithDevices",
                "LetAppsAccessTrustedDevices",
                "LetAppsRunInBackground"
            )

            foreach ($valueName in $forceDenyValues) {
                Set-ItemProperty -Path $appPrivacyPath -Name $valueName -Value 2 -Force -ErrorAction SilentlyContinue
            }

            $settingSyncPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\SettingSync"
            if (-not (Test-Path $settingSyncPath)) { New-Item -Path $settingSyncPath -Force | Out-Null }
            Set-ItemProperty -Path $settingSyncPath -Name "DisableSettingSync" -Value 2 -Force
            Set-ItemProperty -Path $settingSyncPath -Name "DisableSettingSyncUserOverride" -Value 1 -Force

            $ncsiPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\NetworkConnectivityStatusIndicator"
            if (-not (Test-Path $ncsiPath)) { New-Item -Path $ncsiPath -Force | Out-Null }
            Set-ItemProperty -Path $ncsiPath -Name "NoActiveProbe" -Value 1 -Force -ErrorAction SilentlyContinue

            $messagingPath = "HKCU:\SOFTWARE\Microsoft\Messaging"
            if (-not (Test-Path $messagingPath)) { New-Item -Path $messagingPath -Force | Out-Null }
            Set-ItemProperty -Path $messagingPath -Name "CloudServiceSyncEnabled" -Value 0 -Force -ErrorAction SilentlyContinue
        }

        Write-Host "Profile-based deep tweaks completed for: $Profile" -ForegroundColor Green
    } "Apply-ProfileBasedDebloat"
}

function Optimise-AdditionalServices {
    Safe-Execute {
        # Services that are safe to disable on most desktop/laptop systems
        $servicesToDisable = @(
            @{ Name = "RemoteRegistry";  Label = "Remote Registry (security risk - allows remote registry edits)" },
            @{ Name = "AJRouter";        Label = "AllJoyn Router (IoT protocol, not needed on desktops)" },
            @{ Name = "ALG";             Label = "Application Layer Gateway (legacy ICS helper)" },
            @{ Name = "TrkWks";          Label = "Distributed Link Tracking Client (makes network calls)" },
            @{ Name = "SharedAccess";    Label = "Internet Connection Sharing" },
            @{ Name = "PhoneSvc";        Label = "Phone Service (mobile hotspot integration)" },
            @{ Name = "PcaSvc";          Label = "Program Compatibility Assistant" },
            @{ Name = "WerSvc";          Label = "Windows Error Reporting (diagnostic data)" },
            @{ Name = "wercplsupport";   Label = "WER Control Panel Support (diagnostic)" },
            @{ Name = "stisvc";          Label = "Windows Image Acquisition (scanner/camera)" },
            @{ Name = "WiaRpc";          Label = "Windows Image Acquisition RPC" },
            @{ Name = "SCardSvr";        Label = "Smart Card (disable if no smart card reader)" },
            @{ Name = "ScDeviceEnum";    Label = "Smart Card Device Enumeration" },
            @{ Name = "icssvc";          Label = "Wi-Fi Tethering/Hotspot service" },
            @{ Name = "WbioSrvc";        Label = "Windows Biometric (disable if no fingerprint/Hello)" },
            @{ Name = "WMPNetworkSvc";   Label = "Windows Media Player Network Sharing" },
            @{ Name = "DoSvc";           Label = "Delivery Optimisation (peer-to-peer updates - not needed on single PC)" },
            @{ Name = "InventorySvc";    Label = "Inventory and Compatibility Appraisal (telemetry)" },
            @{ Name = "NPSMSvc";         Label = "Now Playing Session Manager (media telemetry)" },
            @{ Name = "whesvc";          Label = "Windows Health and Optimised Experiences (telemetry/diagnostics)" }
        )

        foreach ($svc in $servicesToDisable) {
            $service = Get-Service -Name $svc.Name -ErrorAction SilentlyContinue
            if ($service) {
                Stop-Service -Name $svc.Name -Force -ErrorAction SilentlyContinue
                Set-Service -Name $svc.Name -StartupType Disabled -ErrorAction SilentlyContinue
                Write-Host "  Disabled: $($svc.Label)" -ForegroundColor Green
            } else {
                Write-Host "  Not found: $($svc.Label)" -ForegroundColor DarkGray
            }
        }

        # Disable user-suffixed services (cloud sync and notification services)
        # These services have SID-based suffixes and need wildcard matching
        $userSuffixedServices = @(
            @{ Pattern = "OneSyncSvc*";      Label = "Sync Host (cloud sync services)" },
            @{ Pattern = "cbdhsvc*";         Label = "Clipboard User Service (cloud clipboard sync)" },
            @{ Pattern = "NPSMSvc*";         Label = "Now Playing Session Manager (media telemetry)" },
            @{ Pattern = "WpnUserService*";  Label = "Windows Push Notifications User Service" }
        )

        foreach ($svcPattern in $userSuffixedServices) {
            $matchedServices = Get-Service -Name $svcPattern.Pattern -ErrorAction SilentlyContinue
            if ($matchedServices) {
                foreach ($svc in $matchedServices) {
                    Stop-Service -Name $svc.Name -Force -ErrorAction SilentlyContinue
                    Set-Service -Name $svc.Name -StartupType Disabled -ErrorAction SilentlyContinue
                    Write-Host "  Disabled: $($svcPattern.Label) [$($svc.Name)]" -ForegroundColor Green
                }
            }
        }

        # Xbox Live services (disable if not using Xbox app / Game Pass)
        # Note: Game Mode and HAGS do NOT require these services
        $xboxServices = @("XblAuthManager", "XblGameSave", "XboxNetApiSvc", "XboxGipSvc", "BcastDVRUserService")
        foreach ($xbSvc in $xboxServices) {
            $service = Get-Service -Name $xbSvc -ErrorAction SilentlyContinue
            if ($service) {
                Stop-Service -Name $xbSvc -Force -ErrorAction SilentlyContinue
                Set-Service -Name $xbSvc -StartupType Disabled -ErrorAction SilentlyContinue
                Write-Host "  Disabled Xbox service: $xbSvc" -ForegroundColor Green
            }
        }

        # Disable Connected Devices Platform (CDP) - reduces idle network chatter
        $cdpServices = @("CDPSvc", "CDPUserSvc")
        foreach ($cdpSvc in $cdpServices) {
            $service = Get-Service -Name $cdpSvc -ErrorAction SilentlyContinue
            if ($service) {
                Stop-Service -Name $cdpSvc -Force -ErrorAction SilentlyContinue
                Set-Service -Name $cdpSvc -StartupType Disabled -ErrorAction SilentlyContinue
                Write-Host "  Disabled CDP service: $cdpSvc" -ForegroundColor Green
            }
        }

        Write-Host "Additional service cleanup complete." -ForegroundColor Green
    } "Optimise-AdditionalServices"
}

function Optimise-RAMFootprint {
    Safe-Execute {
        # Consolidate service host groups to reduce idle RAM usage (requires reboot).
        # On systems with large memory, Windows often splits many svchost processes.
        Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control" -Name "SvcHostSplitThresholdInKB" -Type DWord -Value 4294967295 -Force

        # Keep Windows Search disabled to reduce memory pressure when idle.
        $wsearchService = Get-Service "WSearch" -ErrorAction SilentlyContinue
        if ($wsearchService) {
            Stop-Service "WSearch" -Force -ErrorAction SilentlyContinue
            Set-Service "WSearch" -StartupType Disabled -ErrorAction SilentlyContinue
        }

        # Disable additional always-on services that commonly consume RAM on idle systems.
        $extraServices = @("DiagTrack", "dmwappushservice", "MapsBroker", "lfsvc", "WMPNetworkSvc", "DoSvc", "InventorySvc", "whesvc", "DPS", "WdiSystemHost")
        foreach ($svc in $extraServices) {
            $service = Get-Service -Name $svc -ErrorAction SilentlyContinue
            if ($service) {
                Stop-Service -Name $svc -Force -ErrorAction SilentlyContinue
                Set-Service -Name $svc -StartupType Disabled -ErrorAction SilentlyContinue
            }
        }

        # Disable user-suffixed cloud/notification services that consume RAM
        $userSuffixedRAMServices = @("OneSyncSvc*", "cbdhsvc*", "WpnUserService*")
        foreach ($svcPattern in $userSuffixedRAMServices) {
            $matchedServices = Get-Service -Name $svcPattern -ErrorAction SilentlyContinue
            if ($matchedServices) {
                foreach ($svc in $matchedServices) {
                    Stop-Service -Name $svc.Name -Force -ErrorAction SilentlyContinue
                    Set-Service -Name $svc.Name -StartupType Disabled -ErrorAction SilentlyContinue
                }
            }
        }

        Write-Host "RAM footprint optimisations applied. Restart recommended for full effect." -ForegroundColor Yellow
    } "RAM Footprint Optimisations"
}

function Optimise-RAMDeep {
    Safe-Execute {
        # Deep memory mode: disables virtualisation and VBS features that reserve RAM.
        # This improves idle RAM usage but impacts Hyper-V, WSL2, Sandbox, and VBS security features.
        $deepFeatures = @(
            "Microsoft-Hyper-V-All",
            "VirtualMachinePlatform",
            "Microsoft-Windows-Subsystem-Linux",
            "Containers-DisposableClientVM"
        )

        foreach ($feature in $deepFeatures) {
            Disable-WindowsOptionalFeature -Online -FeatureName $feature -NoRestart -ErrorAction SilentlyContinue | Out-Null
        }

        $deviceGuardPath = "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard"
        if (-not (Test-Path $deviceGuardPath)) { New-Item -Path $deviceGuardPath -Force | Out-Null }
        Set-ItemProperty -Path $deviceGuardPath -Name "EnableVirtualizationBasedSecurity" -Value 0 -Force

        $hvciPath = "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity"
        if (-not (Test-Path $hvciPath)) { New-Item -Path $hvciPath -Force | Out-Null }
        Set-ItemProperty -Path $hvciPath -Name "Enabled" -Value 0 -Force

        $lsaPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa"
        if (Test-Path $lsaPath) {
            Set-ItemProperty -Path $lsaPath -Name "LsaCfgFlags" -Value 0 -Force -ErrorAction SilentlyContinue
        }

        bcdedit /set hypervisorlaunchtype off 2>$null | Out-Null

        Write-Host "Deep RAM mode applied. REBOOT required. Hyper-V/WSL2/Sandbox/VBS will be disabled." -ForegroundColor Yellow
    } "Deep RAM Optimisations"
}

function Revert-Optimisations {
    Safe-Execute {
        # Remove policy-enforced settings so Windows can return to defaults.
        $policyValuesToRemove = @(
            @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo"; Name = "DisabledByGroupPolicy" },
            @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection"; Name = "AllowTelemetry" },
            @{ Path = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection"; Name = "AllowTelemetry" },
            @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search"; Name = "AllowCortana" },
            @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors"; Name = "DisableLocation" },
            @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy"; Name = "LetAppsRunInBackground" },
            @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Dsh"; Name = "AllowNewsAndInterests" },
            @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Feeds"; Name = "EnableFeeds" },
            @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR"; Name = "AllowGameDVR" }
        )

        foreach ($entry in $policyValuesToRemove) {
            if (Test-Path $entry.Path) {
                Remove-ItemProperty -Path $entry.Path -Name $entry.Name -ErrorAction SilentlyContinue
            }
        }

        # Restore user-facing defaults for UI and gaming behaviour.
        $userDefaults = @(
            @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects"; Name = "VisualFXSetting"; Value = 0 },
            @{ Path = "HKCU:\Control Panel\Desktop\WindowMetrics"; Name = "MinAnimate"; Value = 1 },
            @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"; Name = "TaskbarAnimations"; Value = 1 },
            @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"; Name = "ListviewAlphaSelect"; Value = 1 },
            @{ Path = "HKCU:\Control Panel\Desktop"; Name = "DragFullWindows"; Value = 1 },
            @{ Path = "HKCU:\Control Panel\Desktop"; Name = "FontSmoothing"; Value = 2 },
            @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\ThemeManager"; Name = "ThemeActive"; Value = 1 },
            @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo"; Name = "Enabled"; Value = 1 },
            @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications"; Name = "GlobalUserDisabled"; Value = 0 },
            @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR"; Name = "AppCaptureEnabled"; Value = 1 },
            @{ Path = "HKCU:\Software\Microsoft\GameBar"; Name = "AutoGameModeEnabled"; Value = 1 },
            @{ Path = "HKCU:\Software\Microsoft\GameBar"; Name = "UseNexusForGameBarEnabled"; Value = 1 },
            @{ Path = "HKCU:\Software\Microsoft\GameBar"; Name = "ShowStartupPanel"; Value = 1 },
            @{ Path = "HKCU:\System\GameConfigStore"; Name = "GameDVR_FSEBehaviorMode"; Value = 0 },
            @{ Path = "HKCU:\System\GameConfigStore"; Name = "GameDVR_HonorUserFSEBehaviorMode"; Value = 0 },
            @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize"; Name = "EnableTransparency"; Value = 1 },
            @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"; Name = "RotatingLockScreenEnabled"; Value = 1 },
            @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"; Name = "SubscribedContent-338387Enabled"; Value = 1 },
            @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"; Name = "SubscribedContent-338388Enabled"; Value = 1 },
            @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"; Name = "SubscribedContent-338389Enabled"; Value = 1 },
            @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"; Name = "SubscribedContent-353698Enabled"; Value = 1 },
            @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"; Name = "SoftLandingEnabled"; Value = 1 },
            @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"; Name = "SystemPaneSuggestionsEnabled"; Value = 1 },
            @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\SearchSettings"; Name = "IsDynamicSearchBoxEnabled"; Value = 1 },
            @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"; Name = "TaskbarDa"; Value = 1 },
            @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Feeds"; Name = "ShellFeedsTaskbarViewMode"; Value = 0 },
            @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search"; Name = "AllowSearchToUseLocation"; Value = 1 },
            @{ Path = "HKCU:\Control Panel\Mouse"; Name = "MouseSpeed"; Value = "1" },
            @{ Path = "HKCU:\Control Panel\Mouse"; Name = "MouseThreshold1"; Value = "6" },
            @{ Path = "HKCU:\Control Panel\Mouse"; Name = "MouseThreshold2"; Value = "10" },
            @{ Path = "HKCU:\Control Panel\Accessibility\StickyKeys"; Name = "Flags"; Value = "510" },
            @{ Path = "HKCU:\Control Panel\Accessibility\ToggleKeys"; Name = "Flags"; Value = "62" },
            @{ Path = "HKCU:\Control Panel\Accessibility\Keyboard Response"; Name = "Flags"; Value = "126" }
        )

        foreach ($entry in $userDefaults) {
            if (-not (Test-Path $entry.Path)) { New-Item -Path $entry.Path -Force | Out-Null }
            Set-ItemProperty -Path $entry.Path -Name $entry.Name -Value $entry.Value -Force -ErrorAction SilentlyContinue
        }

        $backgroundRoot = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications'
        if (Test-Path $backgroundRoot) {
            Get-ChildItem -Path $backgroundRoot -ErrorAction SilentlyContinue | ForEach-Object {
                Remove-ItemProperty -LiteralPath $_.PSPath -Name 'BackgroundAccess' -Force -ErrorAction SilentlyContinue
            }
        }

        # Restore machine defaults for performance and startup related tweaks.
        $machineDefaults = @(
            @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Control"; Name = "SvcHostSplitThresholdInKB"; Value = 3670016 },
            @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers"; Name = "HwSchMode"; Value = 1 },
            @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl"; Name = "Win32PrioritySeparation"; Value = 2 },
            @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard"; Name = "EnableVirtualizationBasedSecurity"; Value = 1 },
            @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity"; Name = "Enabled"; Value = 1 },
            @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa"; Name = "LsaCfgFlags"; Value = 1 },
            @{ Path = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"; Name = "NetworkThrottlingIndex"; Value = 10 },
            @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"; Name = "DisablePagingExecutive"; Value = 0 },
            @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"; Name = "LargeSystemCache"; Value = 0 },
            @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"; Name = "ClearPageFileAtShutdown"; Value = 0 },
            @{ Path = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer"; Name = "NoDriveTypeAutoRun"; Value = 145 },
            @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer"; Name = "NoDriveTypeAutoRun"; Value = 145 },
            @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Control\Remote Assistance"; Name = "fAllowToGetHelp"; Value = 1 }
        )

        foreach ($entry in $machineDefaults) {
            if (-not (Test-Path $entry.Path)) { New-Item -Path $entry.Path -Force | Out-Null }
            Set-ItemProperty -Path $entry.Path -Name $entry.Name -Value $entry.Value -Force -ErrorAction SilentlyContinue
        }

        # Remove specific startup delay override and restore hibernation/hypervisor defaults.
        Remove-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Serialize" -Name "StartupDelayInMSec" -ErrorAction SilentlyContinue
        powercfg -setactive 381b4222-f694-41f0-9685-ff5bb260df2e 2>$null | Out-Null
        Enable-AttachedDevicePowerSaving
        Remove-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling' -Name 'PowerThrottlingOff' -ErrorAction SilentlyContinue
        Set-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile' -Name 'SystemResponsiveness' -Value 20 -Type DWord -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path 'HKCU:\Control Panel\Desktop' -Name 'MenuShowDelay' -Value '400' -Type String -Force -ErrorAction SilentlyContinue
        foreach ($edgePolicy in @('HKLM:\SOFTWARE\Policies\Microsoft\Edge', 'HKCU:\SOFTWARE\Policies\Microsoft\Edge')) {
            if (Test-Path $edgePolicy) {
                foreach ($edgeName in @('StartupBoostEnabled', 'BackgroundModeEnabled', 'SleepingTabsEnabled')) {
                    Remove-ItemProperty -Path $edgePolicy -Name $edgeName -Force -ErrorAction SilentlyContinue
                }
            }
        }
        $nduPath = 'HKLM:\SYSTEM\CurrentControlSet\Services\Ndu'
        if (Test-Path $nduPath) {
            Set-ItemProperty -Path $nduPath -Name 'Start' -Value 2 -Type DWord -Force -ErrorAction SilentlyContinue
        }
        $prefetchPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\PrefetchParameters'
        if (Test-Path $prefetchPath) {
            Set-ItemProperty -Path $prefetchPath -Name 'EnablePrefetcher' -Value 3 -Type DWord -Force -ErrorAction SilentlyContinue
            Set-ItemProperty -Path $prefetchPath -Name 'EnableSuperfetch' -Value 3 -Type DWord -Force -ErrorAction SilentlyContinue
        }
        $gamesPath = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games'
        if (Test-Path $gamesPath) {
            Set-ItemProperty -Path $gamesPath -Name 'Priority' -Value 2 -Type DWord -Force -ErrorAction SilentlyContinue
            Set-ItemProperty -Path $gamesPath -Name 'Scheduling Category' -Value 'Medium' -Type String -Force -ErrorAction SilentlyContinue
            Set-ItemProperty -Path $gamesPath -Name 'SFIO Priority' -Value 'Normal' -Type String -Force -ErrorAction SilentlyContinue
        }

        powercfg -h on 2>$null | Out-Null
        bcdedit /set hypervisorlaunchtype auto 2>$null | Out-Null
        bcdedit /timeout 30 2>$null | Out-Null

        # Re-enable virtualisation-related features disabled by deep RAM mode.
        $deepFeatures = @(
            "Microsoft-Hyper-V-All",
            "VirtualMachinePlatform",
            "Microsoft-Windows-Subsystem-Linux",
            "Containers-DisposableClientVM"
        )

        foreach ($feature in $deepFeatures) {
            Enable-WindowsOptionalFeature -Online -FeatureName $feature -All -NoRestart -ErrorAction SilentlyContinue | Out-Null
        }

        # Restore service startup types to balanced defaults.
        $serviceStartupDefaults = @{
            "SysMain" = "Automatic"
            "WSearch" = "Automatic"
            "Spooler" = "Automatic"
            "WerSvc" = "Manual"
            "DiagTrack" = "Manual"
            "dmwappushservice" = "Manual"
            "MapsBroker" = "Manual"
            "lfsvc" = "Manual"
            "DoSvc" = "Automatic"
            "Fax" = "Manual"
            "WpcMonSvc" = "Manual"
            "SEMgrSvc" = "Manual"
            "RetailDemo" = "Manual"
            "wisvc" = "Manual"
            "WMPNetworkSvc" = "Manual"
            "PNRPsvc" = "Manual"
            "p2psvc" = "Manual"
            "p2pimsvc" = "Manual"
            "RemoteRegistry" = "Disabled"
            "AJRouter" = "Manual"
            "ALG" = "Manual"
            "TrkWks" = "Automatic"
            "SharedAccess" = "Manual"
            "PhoneSvc" = "Manual"
            "PcaSvc" = "Automatic"
            "wercplsupport" = "Manual"
            "stisvc" = "Manual"
            "SCardSvr" = "Manual"
            "ScDeviceEnum" = "Manual"
            "icssvc" = "Manual"
            "WbioSrvc" = "Manual"
            "InventorySvc" = "Manual"
            "NPSMSvc" = "Manual"
            "whesvc" = "Manual"
            "DPS" = "Automatic"
            "WdiSystemHost" = "Manual"
            "XblAuthManager" = "Manual"
            "XblGameSave" = "Manual"
            "XboxNetApiSvc" = "Manual"
            "XboxGipSvc" = "Manual"
            "CDPSvc" = "Automatic"
        }

        foreach ($svcName in $serviceStartupDefaults.Keys) {
            $service = Get-Service -Name $svcName -ErrorAction SilentlyContinue
            if ($service) {
                Set-Service -Name $svcName -StartupType $serviceStartupDefaults[$svcName] -ErrorAction SilentlyContinue
                if ($serviceStartupDefaults[$svcName] -ne 'Disabled') {
                    Start-Service -Name $svcName -ErrorAction SilentlyContinue
                }
            }
        }

        $servicePatterns = @{
            'OneSyncSvc*' = 'Automatic'
            'cbdhsvc*' = 'Automatic'
            'WpnUserService*' = 'Automatic'
            'CDPUserSvc*' = 'Automatic'
            'BcastDVRUserService*' = 'Manual'
        }
        foreach ($pattern in @($servicePatterns.Keys)) {
            $matched = @(Get-Service -Name $pattern -ErrorAction SilentlyContinue)
            foreach ($svc in $matched) {
                if (-not $svc) { continue }
                Set-Service -Name $svc.Name -StartupType $servicePatterns[$pattern] -ErrorAction SilentlyContinue
            }
        }

        Write-Host "Revert optimisations completed. Reboot recommended to fully restore defaults." -ForegroundColor Yellow
    } "Revert Optimisations"
}

if ($AutomatedMode -and [string]::IsNullOrWhiteSpace($OptimisationAction)) {
    # Run all optimisations automatically with progress reporting
    Show-Progress "Starting system optimisation..." 0
    Show-Progress "Starting automated profile without visual optimisation..." 10
    
    # Performance optimisations
    Show-Progress "Applying performance optimisations..." 60
    Optimise-PowerSettings
    Optimise-NetworkSettings
    Optimise-MemoryManagement
    Optimise-RuntimeFootprint
    Optimise-ScheduledTasks
    
    # Service optimisations
    Show-Progress "Optimising system services..." 80
    $sysmainService = Get-Service "SysMain" -ErrorAction SilentlyContinue
    if ($sysmainService -and (Test-SystemDiskSolidState)) {
        Stop-Service "SysMain" -Force -ErrorAction SilentlyContinue
        Set-Service "SysMain" -StartupType Disabled -ErrorAction SilentlyContinue
    }
    
    # Windows Search to Manual
    $wsearchService = Get-Service "WSearch" -ErrorAction SilentlyContinue
    if ($wsearchService) {
        Set-Service "WSearch" -StartupType Manual -ErrorAction SilentlyContinue
    }
    
    # Disable Windows Error Reporting
    $werService = Get-Service "WerSvc" -ErrorAction SilentlyContinue
    if ($werService) {
        Set-Service "WerSvc" -StartupType Disabled -ErrorAction SilentlyContinue
    }

    # Additional service cleanup
    Show-Progress "Disabling additional services..." 90
    Optimise-AdditionalServices

    # RAM footprint optimisation (safe mode)
    Show-Progress "Optimising RAM footprint..." 94
    Optimise-RAMFootprint
    
    ExecutionCompleted
    exit 0
}

# Scripts to optimise Windows with detailed action descriptions
$VisualOptimisation = {
    try {
        Write-Host "Starting Visual Optimisation..." -ForegroundColor Cyan
        if (Test-Path $VisualOptimisationScript) {
            & $VisualOptimisationScript --automated
        } else {
            throw "Visual optimisation script not found at $VisualOptimisationScript"
        }
        ExecutionCompleted
    } catch {
        Write-Host "Error during Visual Optimisation: $_" -ForegroundColor Red
    }
}

$Turnoffbackgroundapps = {
    try {
        Write-Host "Disabling background apps..." -ForegroundColor Cyan
        DisableBackgroundAccess
        DisableBackgroundApps
        DisableBackgroundAppsPerApp
        ExecutionCompleted
    } catch {
        Write-Host "Error during background app disablement: $_" -ForegroundColor Red
    }
}

$DisableServices = {
    try {
        Write-Host "Disabling unnecessary services..." -ForegroundColor Cyan
        DisableDataUsage
        DisableFax
        DisableParentalControls
        DisableGeoLocation
        DisableNFCPayments
        DisableRetailDemo
        DisableWindowsInside
        DisableMapsManager
        ExecutionCompleted
    } catch {
        Write-Host "Error during service disablement: $_" -ForegroundColor Red
    }
}

$DisableTelemetry = {
    try {
        Write-Host "Disabling telemetry..." -ForegroundColor Cyan
        DisableDiagtrack
        DisableDiagtrack2
        DisableAdvertisingID
        DisableTelemetry
        ExecutionCompleted
    } catch {
        Write-Host "Error during telemetry disablement: $_" -ForegroundColor Red
    }
}

$PerformanceOptimisations = {
    try {
        Write-Host "Starting Performance Optimisations..." -ForegroundColor Cyan
        Optimise-PowerSettings
        Optimise-NetworkSettings
        Optimise-MemoryManagement
        Optimise-RuntimeFootprint
        Optimise-ScheduledTasks
        
        # SysMain helps a hard disk. On an SSD it mostly holds RAM, so turn it off there only.
        $sysmainService = Get-Service "SysMain" -ErrorAction SilentlyContinue
        if ($sysmainService) {
            if (Test-SystemDiskSolidState) {
                Stop-Service "SysMain" -Force -ErrorAction SilentlyContinue
                Set-Service "SysMain" -StartupType Disabled -ErrorAction SilentlyContinue
                Write-Host "SysMain (Superfetch) disabled because the system disk is solid-state" -ForegroundColor Green
            } else {
                Write-Host "SysMain (Superfetch) left enabled because the system disk is not a detected SSD" -ForegroundColor Yellow
            }
        }
        
        # Disable Windows Search Indexing for better performance (optional)
        $wsearchService = Get-Service "WSearch" -ErrorAction SilentlyContinue
        if ($wsearchService) {
            Stop-Service "WSearch" -Force -ErrorAction SilentlyContinue
            Set-Service "WSearch" -StartupType Manual -ErrorAction SilentlyContinue
            Write-Host "Windows Search set to Manual startup" -ForegroundColor Green
        }
        
        # Disable Print Spooler (safer to disable by default, can be re-enabled if needed)
        $spoolerService = Get-Service "Spooler" -ErrorAction SilentlyContinue
        if ($spoolerService) {
            Stop-Service "Spooler" -Force -ErrorAction SilentlyContinue
            Set-Service "Spooler" -StartupType Disabled -ErrorAction SilentlyContinue
            Write-Host "Print Spooler disabled" -ForegroundColor Green
        }
        
        # Disable Windows Error Reporting
        $werService = Get-Service "WerSvc" -ErrorAction SilentlyContinue
        if ($werService) {
            Set-Service "WerSvc" -StartupType Disabled -ErrorAction SilentlyContinue
            Write-Host "Windows Error Reporting disabled" -ForegroundColor Green
        }
        
        ExecutionCompleted
    } catch {
        Write-Host "Error during Performance Optimisations: $_" -ForegroundColor Red
    }
}

$GamingOptimisations = {
    try {
        Write-Host "Applying gaming performance optimisations..." -ForegroundColor Cyan
        Optimise-Gaming
        ExecutionCompleted
    } catch {
        Write-Host "Error during gaming optimisations: $_" -ForegroundColor Red
    }
}

$StorageOptimisations = {
    try {
        Write-Host "Applying storage and file system optimisations..." -ForegroundColor Cyan
        Optimise-Storage
        ExecutionCompleted
    } catch {
        Write-Host "Error during storage optimisations: $_" -ForegroundColor Red
    }
}

$StartupOptimisations = {
    try {
        Write-Host "Applying startup and boot optimisations..." -ForegroundColor Cyan
        Optimise-Startup
        ExecutionCompleted
    } catch {
        Write-Host "Error during startup optimisations: $_" -ForegroundColor Red
    }
}

$ScheduledTasksOptimisations = {
    try {
        Write-Host "Cleaning up scheduled tasks..." -ForegroundColor Cyan
        Optimise-ScheduledTasks
        ExecutionCompleted
    } catch {
        Write-Host "Error during scheduled task cleanup: $_" -ForegroundColor Red
    }
}

$PrivacyOptimisations = {
    try {
        Write-Host "Applying privacy hardening..." -ForegroundColor Cyan
        Optimise-Privacy
        ExecutionCompleted
    } catch {
        Write-Host "Error during privacy hardening: $_" -ForegroundColor Red
    }
}

$AdditionalServicesOptimisations = {
    try {
        Write-Host "Disabling additional unnecessary services..." -ForegroundColor Cyan
        Optimise-AdditionalServices
        ExecutionCompleted
    } catch {
        Write-Host "Error during additional service cleanup: $_" -ForegroundColor Red
    }
}

$UICleanup = {
    try {
        Write-Host "Cleaning up UI and notifications..." -ForegroundColor Cyan
        Optimise-UICleanup
        ExecutionCompleted
    } catch {
        Write-Host "Error during UI cleanup: $_" -ForegroundColor Red
    }
}

$RAMOptimisations = {
    try {
        Write-Host "Applying RAM footprint optimisations..." -ForegroundColor Cyan
        Optimise-RAMFootprint
        Optimise-RuntimeFootprint
        ExecutionCompleted
    } catch {
        Write-Host "Error during RAM optimisations: $_" -ForegroundColor Red
    }
}

$DeepRamOptimisations = {
    try {
        $confirmDeep = [System.Windows.Forms.MessageBox]::Show(
            "Deep RAM mode applies aggressive memory-footprint changes and disables Hyper-V, WSL2, Windows Sandbox, and VBS features.`n`nThis can affect developer tooling, virtual machines, and security hardening.`n`nA reboot is required.`n`nContinue?",
            "Deep RAM Optimisation",
            "YesNo",
            "Warning"
        )

        if ($confirmDeep -ne [System.Windows.Forms.DialogResult]::Yes) {
            Write-Host "Deep RAM optimisation cancelled by user." -ForegroundColor Yellow
            return
        }

        Write-Host "Applying deep RAM optimisations..." -ForegroundColor Cyan
        Optimise-RAMDeep
        ExecutionCompleted
    } catch {
        Write-Host "Error during deep RAM optimisations: $_" -ForegroundColor Red
    }
}

$RevertOptimisations = {
    try {
        $confirmRevert = [System.Windows.Forms.MessageBox]::Show(
            "This will revert optimisation settings towards Windows defaults.`n`nIt includes service startup types, UI/privacy policies, RAM footprint tuning, and virtualisation-related adjustments.`n`nA reboot is strongly recommended afterwards.`n`nContinue?",
            "Revert Optimisations",
            "YesNo",
            "Warning"
        )

        if ($confirmRevert -ne [System.Windows.Forms.DialogResult]::Yes) {
            Write-Host "Revert optimisations cancelled by user." -ForegroundColor Yellow
            return
        }

        Write-Host "Reverting optimisations..." -ForegroundColor Cyan
        Revert-Optimisations
        ExecutionCompleted
    } catch {
        Write-Host "Error during optimisation revert: $_" -ForegroundColor Red
    }
}

if (-not [string]::IsNullOrWhiteSpace($OptimisationAction)) {
    $actionKey = $OptimisationAction.ToLowerInvariant()
    Write-Host "Running optimisation action: $actionKey" -ForegroundColor Cyan
    switch ($actionKey) {
        'backgroundapps' { & $Turnoffbackgroundapps }
        'services' { & $DisableServices }
        'telemetry' { & $DisableTelemetry }
        'performance' { & $PerformanceOptimisations }
        'scheduledtasks' { & $ScheduledTasksOptimisations }
        'gaming' { & $GamingOptimisations }
        'storage' { & $StorageOptimisations }
        'startup' { & $StartupOptimisations }
        'uicleanup' { & $UICleanup }
        'privacy' { & $PrivacyOptimisations }
        'additionalservices' { & $AdditionalServicesOptimisations }
        'ramfootprint' { & $RAMOptimisations }
        'deepram' {
            Write-Host "Deep RAM disables Hyper-V, WSL, Windows Sandbox, and virtualisation-based security. Restart when it finishes." -ForegroundColor Yellow
            Optimise-RAMDeep
        }
        default {
            Write-Host "Unknown optimisation action: $OptimisationAction" -ForegroundColor Red
            exit 1
        }
    }
    exit 0
}

# Calculate paths for assets
$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$ParentRoot = Split-Path -Parent $ScriptRoot
$IconPath = "$ParentRoot\Assets\windowslogo.ico"

# Get OS version for display
$osVersion = (Get-WmiObject -Class Win32_OperatingSystem).Caption -replace "Microsoft Windows ", ""

# Calculate optimal form size based on screen resolution
$screen = [System.Windows.Forms.Screen]::PrimaryScreen
$screenWidth = $screen.Bounds.Width
$screenHeight = $screen.Bounds.Height

# Responsive sizing: use 60% of screen width but cap at 500px for better layout
$UiPalette = @{
    FormBack = [System.Drawing.Color]::FromArgb(245, 248, 252)
    CardBack = [System.Drawing.Color]::White
    Accent = [System.Drawing.Color]::FromArgb(27, 92, 153)
    AccentSoft = [System.Drawing.Color]::FromArgb(230, 240, 250)
    TextPrimary = [System.Drawing.Color]::FromArgb(34, 42, 53)
    TextMuted = [System.Drawing.Color]::FromArgb(95, 105, 120)
    Border = [System.Drawing.Color]::FromArgb(211, 219, 228)
    Visual = [System.Drawing.Color]::FromArgb(231, 242, 255)
    Services = [System.Drawing.Color]::FromArgb(231, 247, 237)
    Performance = [System.Drawing.Color]::FromArgb(255, 245, 228)
    Privacy = [System.Drawing.Color]::FromArgb(237, 241, 249)
}

$formWidth = [Math]::Min([Math]::Max(450, $screenWidth * 0.62), 560)
$formHeight = [Math]::Min(980, [Math]::Max(700, ($screenHeight - 70)))

# Calculate button width for 2 columns with symmetrical padding
$buttonWidth = [Math]::Floor(($formWidth - 60) / 2)  # 2 columns with 30px padding on each side

# Form Creation with modern UI
$Form = New-Object System.Windows.Forms.Form -Property @{
    Text = "System Optimisation - Windows $osVersion"
    Size = New-Object System.Drawing.Size($formWidth, $formHeight)
    StartPosition = 'CenterScreen'
    FormBorderStyle = 'FixedDialog'
    MaximizeBox = $false
    MinimizeBox = $true
    BackColor = $UiPalette.FormBack
    Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Regular)
    MinimumSize = New-Object System.Drawing.Size(450, 700)
    MaximumSize = New-Object System.Drawing.Size(560, 1040)
    ShowInTaskbar = $true
    TopMost = $true
}
Enable-DoubleBuffering -Control $Form
$Form.AutoScroll = $true

# Try to set icon if available
try {
    if (Test-Path $IconPath) {
        $Form.Icon = [System.Drawing.Icon]::ExtractAssociatedIcon($IconPath)
    }
} catch {
    # Icon not critical, continue without it
}

# Header section with title and OS info
$headerPanel = New-Object System.Windows.Forms.Panel
$headerPanel.Size = New-Object System.Drawing.Size(($formWidth - 20), 60)
$headerPanel.Location = New-Object System.Drawing.Point(10, 10)
$headerPanel.BackColor = $UiPalette.Accent
$headerPanel.BorderStyle = 'FixedSingle'

$titleLabel = New-Object System.Windows.Forms.Label
$titleLabel.Text = "System Optimisation"
$titleLabel.Size = New-Object System.Drawing.Size(300, 25)
$titleLabel.Location = New-Object System.Drawing.Point(15, 10)
$titleLabel.Font = New-Object System.Drawing.Font("Segoe UI", 14, [System.Drawing.FontStyle]::Bold)
$titleLabel.ForeColor = [System.Drawing.Color]::White
$titleLabel.BackColor = [System.Drawing.Color]::Transparent

$osLabel = New-Object System.Windows.Forms.Label
$osLabel.Text = "Windows $osVersion"
$osLabel.Size = New-Object System.Drawing.Size(200, 20)
$osLabel.Location = New-Object System.Drawing.Point(15, 35)
$osLabel.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Regular)
$osLabel.ForeColor = [System.Drawing.Color]::FromArgb(220, 232, 244)
$osLabel.BackColor = [System.Drawing.Color]::Transparent

$subTitleLabel = New-Object System.Windows.Forms.Label
$subTitleLabel.Text = "Professional, balanced tuning for performance, privacy, and lower idle RAM while keeping core Windows experience intact."
$subTitleLabel.Size = New-Object System.Drawing.Size(220, 34)
$subTitleLabel.Location = New-Object System.Drawing.Point(($formWidth - 245), 14)
$subTitleLabel.Font = New-Object System.Drawing.Font("Segoe UI", 8.5)
$subTitleLabel.ForeColor = [System.Drawing.Color]::FromArgb(220, 232, 244)
$subTitleLabel.TextAlign = [System.Drawing.ContentAlignment]::MiddleRight
$subTitleLabel.BackColor = [System.Drawing.Color]::Transparent

$headerPanel.Controls.AddRange(@($titleLabel, $osLabel, $subTitleLabel))
$Form.Controls.Add($headerPanel)

# Instructions label
$instructionsLabel = New-Object System.Windows.Forms.Label
$instructionsLabel.Text = "Use the recommended actions for a safe baseline, or run targeted controls for specific issues. Advanced items are separated to reduce accidental over-tuning."
$instructionsLabel.Size = New-Object System.Drawing.Size(($formWidth - 40), 30)
$instructionsLabel.Location = New-Object System.Drawing.Point(20, 80)
$instructionsLabel.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Italic)
$instructionsLabel.ForeColor = $UiPalette.TextMuted
$instructionsLabel.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
$Form.Controls.Add($instructionsLabel)

$summaryPanel = New-Object System.Windows.Forms.Panel
$summaryPanel.Size = New-Object System.Drawing.Size(($formWidth - 40), 56)
$summaryPanel.Location = New-Object System.Drawing.Point(20, 112)
$summaryPanel.BackColor = $UiPalette.CardBack
$summaryPanel.BorderStyle = 'FixedSingle'

$summaryLabel = New-Object System.Windows.Forms.Label
$summaryLabel.Text = "Recommended sequence: Performance Optimisations, Privacy Hardening, Additional Services, RAM Footprint, then UI and notifications cleanup. Performance now includes the max power plan and device power-saving off. Leave Deep RAM off unless virtualisation features are definitely not required."
$summaryLabel.Size = New-Object System.Drawing.Size(($formWidth - 60), 40)
$summaryLabel.Location = New-Object System.Drawing.Point(10, 8)
$summaryLabel.ForeColor = $UiPalette.TextMuted
$summaryLabel.BackColor = [System.Drawing.Color]::Transparent

$summaryPanel.Controls.Add($summaryLabel)
$Form.Controls.Add($summaryPanel)

function Add-OptimisationSection {
    param(
        [string]$Text,
        [System.Drawing.Point]$Location
    )

    $sectionLabel = New-Object System.Windows.Forms.Label -Property @{
        Text = "> $Text"
        Location = $Location
        Size = New-Object System.Drawing.Size(($formWidth - 40), 24)
        Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
        ForeColor = $UiPalette.TextPrimary
        BackColor = [System.Drawing.Color]::Transparent
    }

    $Form.Controls.Add($sectionLabel)
    return $sectionLabel
}

# Enhanced button creation with modern styling
function Add-OptimisationButton {
    param (
        [string]$Text,
        [System.Drawing.Point]$Location,
        [scriptblock]$Action,
        [string]$Category = "Default",
        [string]$Description = ""
    )

    $Button = New-Object System.Windows.Forms.Button -Property @{
        Text = $Text
        Location = $Location
        Size = New-Object System.Drawing.Size($buttonWidth, 42)
        Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Regular)
        FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
        Cursor = [System.Windows.Forms.Cursors]::Hand
        TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
        Padding = New-Object System.Windows.Forms.Padding(10, 0, 0, 0)
        ForeColor = $UiPalette.TextPrimary
    }
    $Button.FlatAppearance.BorderSize = 1

    # Category-based colour coding
    switch ($Category) {
        "Visual" {
            $Button.BackColor = $UiPalette.Visual
            $Button.FlatAppearance.BorderColor = $UiPalette.Border
        }
        "Services" {
            $Button.BackColor = $UiPalette.Services
            $Button.FlatAppearance.BorderColor = $UiPalette.Border
        }
        "Performance" {
            $Button.BackColor = $UiPalette.Performance
            $Button.FlatAppearance.BorderColor = $UiPalette.Border
        }
        "Privacy" {
            $Button.BackColor = $UiPalette.Privacy
            $Button.FlatAppearance.BorderColor = $UiPalette.Border
        }
        default {
            $Button.BackColor = $UiPalette.CardBack
            $Button.FlatAppearance.BorderColor = $UiPalette.Border
        }
    }

    # Enhanced hover effects
    $Button.FlatAppearance.MouseOverBackColor = [System.Drawing.Color]::FromArgb(223, 233, 244)
    $Button.FlatAppearance.MouseDownBackColor = [System.Drawing.Color]::FromArgb(208, 220, 234)

    # Add click handler with proper error handling
    # Use GetNewClosure() to capture function-local variables ($Action, $buttonText, $Button).
    # Script-level controls ($statusLabel, $statusBar, $Form) are accessed via $script: so they
    # are resolved at runtime rather than captured (they may not exist yet at closure creation).
    $buttonText = $Text
    $clickHandler = {
        try {
            # Disable button to prevent multiple clicks
            $Button.Enabled = $false
            if ($script:Form) { $script:Form.UseWaitCursor = $true }

            # Update status bar
            if ($script:statusLabel) { $script:statusLabel.Text = "Running: $buttonText (please wait)..." }
            if ($script:statusBar) { $script:statusBar.Refresh() }
            Update-Ui -Control $script:Form

            Write-Host "Starting optimisation: $buttonText" -ForegroundColor Cyan
            & $Action
            Write-Host "Completed optimisation: $buttonText" -ForegroundColor Green

            # Update status bar
            if ($script:statusLabel) { $script:statusLabel.Text = "Completed successfully: $buttonText" }
            if ($script:statusBar) { $script:statusBar.Refresh() }
            Update-Ui -Control $script:Form

            # Keep form focused
            if ($script:Form) { $script:Form.Activate() }
        } catch {
            Write-Host "Error during $buttonText`: $($_.Exception.Message)" -ForegroundColor Red

            # Update status bar with error
            if ($script:statusLabel) { $script:statusLabel.Text = "Error: $buttonText did not complete" }
            if ($script:statusBar) { $script:statusBar.Refresh() }
            Update-Ui -Control $script:Form

            # Keep form focused
            if ($script:Form) { $script:Form.Activate() }
        } finally {
            # Re-enable button
            $Button.Enabled = $true
            if ($script:Form) { $script:Form.UseWaitCursor = $false }
            Update-Ui -Control $script:Form
        }
    }.GetNewClosure()
    $Button.Add_Click($clickHandler)

    # Add tooltip if description is provided
    if ($Description) {
        $tooltip = New-Object System.Windows.Forms.ToolTip
        $tooltip.SetToolTip($Button, $Description)
    }

    $Form.Controls.Add($Button)
    return $Button
}

# Calculate button positions for 2-column layout
$leftButtonX = 20
$rightButtonX = $leftButtonX + $buttonWidth + 20
$currentY = 185

# Add optimisation buttons with modern styling
Add-OptimisationSection "Balanced Defaults" (New-Object System.Drawing.Point(20, $currentY))
$currentY += 28

Add-OptimisationButton "Visual Optimisation" (New-Object System.Drawing.Point($leftButtonX, $currentY)) $VisualOptimisation "Visual" "Apply all visual performance changes in one pass (animations, effects, and theme responsiveness tweaks)."
Add-OptimisationButton "Disable Background Apps" (New-Object System.Drawing.Point($rightButtonX, $currentY)) $Turnoffbackgroundapps "Services" "Restrict background app activity to lower idle CPU/RAM usage and reduce passive network traffic."
$currentY += 50

Add-OptimisationButton "Disable Services" (New-Object System.Drawing.Point($leftButtonX, $currentY)) $DisableServices "Services" "Disable selected non-essential services to reduce background overhead and startup load."
Add-OptimisationButton "Disable Telemetry" (New-Object System.Drawing.Point($rightButtonX, $currentY)) $DisableTelemetry "Privacy" "Apply policy and service-level telemetry reductions for stronger privacy defaults."
$currentY += 50

Add-OptimisationButton "Performance Optimisations" (New-Object System.Drawing.Point($leftButtonX, $currentY)) $PerformanceOptimisations "Performance" "Sets Ultimate Performance, stops attached devices from sleeping, and trims idle background RAM use."
Add-OptimisationButton "Task Scheduler Cleanup" (New-Object System.Drawing.Point($rightButtonX, $currentY)) $ScheduledTasksOptimisations "Services" "Disable selected telemetry/diagnostic scheduled tasks that are not required on most personal systems."
$currentY += 50

Add-OptimisationSection "Performance and Privacy Extras" (New-Object System.Drawing.Point(20, $currentY))
$currentY += 28

Add-OptimisationButton "Gaming Performance" (New-Object System.Drawing.Point($leftButtonX, $currentY)) $GamingOptimisations "Performance" "Tune gaming-related settings (Game Bar/DVR, Game Mode, HAGS, mouse behaviour) for lower input and capture overhead."
Add-OptimisationButton "Storage & File System" (New-Object System.Drawing.Point($rightButtonX, $currentY)) $StorageOptimisations "Performance" "Optimise storage/file-system behaviour, including delivery and indexing-related overhead where applicable."
$currentY += 50

Add-OptimisationButton "Startup & Boot" (New-Object System.Drawing.Point($leftButtonX, $currentY)) $StartupOptimisations "Performance" "Adjust startup and boot behaviour to reduce delay and streamline sign-in readiness."
Add-OptimisationButton "UI & Notifications" (New-Object System.Drawing.Point($rightButtonX, $currentY)) $UICleanup "Privacy" "Reduce distracting UI surfaces and promotional notifications (including Widgets/feeds-style elements)."
$currentY += 50

Add-OptimisationButton "Privacy Hardening" (New-Object System.Drawing.Point($leftButtonX, $currentY)) $PrivacyOptimisations "Privacy" "Apply additional privacy controls for feedback, tailored experiences, and selected diagnostic data paths."
Add-OptimisationButton "Additional Services" (New-Object System.Drawing.Point($rightButtonX, $currentY)) $AdditionalServicesOptimisations "Services" "Disable extra optional services (for example Xbox/CDP-related components) where they are not needed."
$currentY += 50

Add-OptimisationSection "Advanced and Recovery" (New-Object System.Drawing.Point(20, $currentY))
$currentY += 28

Add-OptimisationButton "RAM Footprint" (New-Object System.Drawing.Point($leftButtonX, $currentY)) $RAMOptimisations "Performance" "Lowers idle RAM from services, Edge, widgets, and Store apps. Leaves the standby cache in place."
Add-OptimisationButton "Deep RAM (Advanced)" (New-Object System.Drawing.Point($rightButtonX, $currentY)) $DeepRamOptimisations "Privacy" "Aggressive memory reduction that disables Hyper-V/WSL2/Sandbox/VBS features (reboot required)."
$currentY += 50

Add-OptimisationButton "Revert Optimisations" (New-Object System.Drawing.Point($leftButtonX, $currentY)) $RevertOptimisations "Services" "Roll back optimisation changes towards default Windows behaviour where supported."
$currentY += 60

# Enhanced Exit button with better positioning
$ExitButton = New-Object System.Windows.Forms.Button -Property @{
    Text = 'Close'
    Location = New-Object System.Drawing.Point((($formWidth - 100) / 2), $currentY)
    Size = New-Object System.Drawing.Size(100, 35)
    DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Regular)
    FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    Cursor = [System.Windows.Forms.Cursors]::Hand
    BackColor = [System.Drawing.Color]::FromArgb(245, 245, 245)
}

$ExitButton.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(180, 180, 180)
$ExitButton.FlatAppearance.MouseOverBackColor = [System.Drawing.Color]::FromArgb(220, 220, 220)
$Form.Controls.Add($ExitButton)
$Form.CancelButton = $ExitButton

# Status bar for additional information
$statusBar = New-Object System.Windows.Forms.StatusStrip
$statusLabel = New-Object System.Windows.Forms.ToolStripStatusLabel
$statusLabel.Text = "Ready: select an optimisation action to begin."
$statusLabel.Spring = $true
$statusBar.Items.Add($statusLabel)
$Form.Controls.Add($statusBar)

# Keep bottom controls reachable on smaller displays.
$Form.AutoScrollMinSize = New-Object System.Drawing.Size(($formWidth - 20), ($currentY + 120))

# Show the form
$Form.ShowDialog() | Out-Null
