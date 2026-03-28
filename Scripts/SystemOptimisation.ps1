# Check if called from main script (automated mode)
$AutomatedMode = $args -contains "--automated"

# Progress reporting functions for integration with main script
function Show-Progress {
    param([string]$Status, [int]$Percent = -1)
    
    # When showing the optimization form, don't show progress dialog - just write to console
    Write-Host $Status -ForegroundColor Cyan
}

function ExecutionCompleted {
    if ($Global:MainProgressForm) {
        Show-Progress "System optimization completed successfully!" 100
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

# Functions for various optimizations with error handling
function VisualFXSetting {
    Safe-Execute { Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" -Name "VisualFXSetting" -Value 2 -Force } "VisualFXSetting"
}

function MinAnimate {
    Safe-Execute {
        if (-not (Test-Path "HKCU:\Control Panel\Desktop\WindowMetrics")) {
            Write-Host "Error: Path HKCU:\Control Panel\Desktop\WindowMetrics does not exist." -ForegroundColor Red
            return
        }
        Set-ItemProperty -Path "HKCU:\Control Panel\Desktop\WindowMetrics" -Name "MinAnimate" -Value 0 -Force
    } "MinAnimate"
}

function TaskbarAnimations {
    Safe-Execute { Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarAnimations" -Value 0 -Force } "TaskbarAnimations"
}

function TaskbarAnimations2 {
    Safe-Execute { Set-ItemProperty -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarAnimations" -Value 0 -Force } "TaskbarAnimations2"
}

function CompositionPolicy {
    Safe-Execute { Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\DWM" -Name "CompositionPolicy" -Value 0 -Force } "CompositionPolicy"
}

function ColorizationOpaqueBlend {
    Safe-Execute { Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\DWM" -Name "ColorizationOpaqueBlend" -Value 0 -Force } "ColorizationOpaqueBlend"
}

function AlwaysHibernateThumbnails {
    Safe-Execute { Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\DWM" -Name "AlwaysHibernateThumbnails" -Value 0 -Force } "AlwaysHibernateThumbnails"
}

function DisableThumbnails {
    Safe-Execute { Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\DWM" -Name "DisableThumbnails" -Value 1 -Force } "DisableThumbnails"
}

function ListviewAlphaSelect {
    Safe-Execute { Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "ListviewAlphaSelect" -Value 0 -Force } "ListviewAlphaSelect"
}

function DragFullWindows {
    Safe-Execute { Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "DragFullWindows" -Value 0 -Force } "DragFullWindows"
}

function FontSmoothing {
    Safe-Execute { Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "FontSmoothing" -Value 0 -Force } "FontSmoothing"
}

function ThemeManager {
    Safe-Execute { Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\ThemeManager" -Name "ThemeActive" -Value 0 -Force } "ThemeManager"
}

function ThemeManager2 {
    Safe-Execute { Set-ItemProperty -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\ThemeManager" -Name "ThemeActive" -Value 0 -Force } "ThemeManager2"
}

function UserPreferencesMask {
    Safe-Execute { Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "UserPreferencesMask" -Value ([byte[]](0x90,0x12,0x01,0x80,0x10,0x00,0x00,0x00)) -Force } "UserPreferencesMask"
}

function RestartThemeService {
    Safe-Execute { Restart-Service Themes -Force } "RestartThemeService"
}

# Telemetry and background services optimization functions - Modern Windows 10/11
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

# Add new optimization functions for Windows 10/11
function Optimize-PowerSettings {
    Safe-Execute {
        # Check if High Performance power scheme exists
        $highPerfGuid = "8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c"
        $schemes = powercfg -list 2>$null
        
        if ($schemes -match $highPerfGuid) {
            # High Performance scheme exists, set it active
            powercfg -setactive $highPerfGuid 2>$null
            Write-Host "  Set power scheme to High Performance" -ForegroundColor Green
        } else {
            # High Performance scheme doesn't exist, try to create it
            try {
                powercfg -duplicatescheme $highPerfGuid 2>$null
                if ($LASTEXITCODE -eq 0) {
                    powercfg -setactive $highPerfGuid 2>$null
                    Write-Host "  Created and set High Performance power scheme" -ForegroundColor Green
                } else {
                    Write-Host "  Could not create High Performance scheme, using current scheme" -ForegroundColor Yellow
                }
            } catch {
                Write-Host "  High Performance scheme not available, using current scheme" -ForegroundColor Yellow
            }
        }
        
        # Configure power settings regardless of scheme
        try {
            # Disable USB selective suspend
            powercfg -setacvalueindex SCHEME_CURRENT 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0 2>$null
            powercfg -setdcvalueindex SCHEME_CURRENT 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0 2>$null
            
            # Disable link state power management
            powercfg -setacvalueindex SCHEME_CURRENT 2a737441-1930-4402-8d77-b2bebba308a3 ee12f906-d277-404b-b6da-e5fa1a576df5 0 2>$null
            powercfg -setdcvalueindex SCHEME_CURRENT 2a737441-1930-4402-8d77-b2bebba308a3 ee12f906-d277-404b-b6da-e5fa1a576df5 0 2>$null
            
            powercfg -setactive SCHEME_CURRENT 2>$null
            Write-Host "  Configured power settings for performance" -ForegroundColor Green
        } catch {
            Write-Host "  Could not configure advanced power settings" -ForegroundColor Yellow
        }
    } "Optimize-PowerSettings"
}

function Optimize-NetworkSettings {
    Safe-Execute {
        # Disable network throttling
        $regPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"
        if (-not (Test-Path $regPath)) { New-Item -Path $regPath -Force | Out-Null }
        Set-ItemProperty -Path $regPath -Name "NetworkThrottlingIndex" -Value 0xffffffff -Force
        
        # TCP optimizations
        netsh int tcp set global autotuninglevel=normal
        netsh int tcp set global chimney=enabled
        netsh int tcp set global rss=enabled
        netsh int tcp set global netdma=enabled
        
    } "Optimize-NetworkSettings"
}

function Optimize-MemoryManagement {
    Safe-Execute {
        # Disable paging executive
        $regPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"
        Set-ItemProperty -Path $regPath -Name "DisablePagingExecutive" -Value 1 -Force
        
        # Large system cache
        Set-ItemProperty -Path $regPath -Name "LargeSystemCache" -Value 1 -Force
        
        # Clear pagefile at shutdown (optional)
        Set-ItemProperty -Path $regPath -Name "ClearPageFileAtShutdown" -Value 0 -Force
        
    } "Optimize-MemoryManagement"
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

function Optimize-VisualEffectsAdvanced {
    Safe-Execute {
        # Additional visual effects optimizations
        $regPath = "HKCU:\Control Panel\Desktop"
        Set-ItemProperty -Path $regPath -Name "MenuShowDelay" -Value "0" -Force
        
        # Disable window animations
        $regPath2 = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
        Set-ItemProperty -Path $regPath2 -Name "TaskbarAnimations" -Value 0 -Force
        Set-ItemProperty -Path $regPath2 -Name "ListviewAlphaSelect" -Value 0 -Force
        
        # System-wide performance settings
        $regPath3 = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects"
        if (-not (Test-Path $regPath3)) { New-Item -Path $regPath3 -Force | Out-Null }
        Set-ItemProperty -Path $regPath3 -Name "VisualFXSetting" -Value 2 -Force
        
    } "Optimize-VisualEffectsAdvanced"
}

function Disable-Copilot {
    Safe-Execute {
        Write-Host "Disabling Windows Copilot and related AI features..." -ForegroundColor Yellow

        # 1. Hide Copilot button from taskbar (user preference)
        $explorerAdvancedPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
        Set-ItemProperty -Path $explorerAdvancedPath -Name "ShowCopilotButton" -Value 0 -Force

        # 2. Disable Copilot in Windows Search settings
        $searchSettingsPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\SearchSettings"
        if (-not (Test-Path $searchSettingsPath)) { New-Item -Path $searchSettingsPath -Force | Out-Null }
        Set-ItemProperty -Path $searchSettingsPath -Name "IsCopilotEnabled" -Value 0 -Force
        Set-ItemProperty -Path $searchSettingsPath -Name "IsCopilotAvailable" -Value 0 -Force

        # 3. Disable Copilot system-wide via Group Policy (most effective)
        $copilotPolicyPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot"
        if (-not (Test-Path $copilotPolicyPath)) { New-Item -Path $copilotPolicyPath -Force | Out-Null }
        Set-ItemProperty -Path $copilotPolicyPath -Name "TurnOffWindowsCopilot" -Value 1 -Force

        # 4. Disable Windows AI features (includes Copilot dependencies)
        $windowsAIPolicyPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI"
        if (-not (Test-Path $windowsAIPolicyPath)) { New-Item -Path $windowsAIPolicyPath -Force | Out-Null }
        Set-ItemProperty -Path $windowsAIPolicyPath -Name "DisableAIDataAnalysis" -Value 1 -Force  # Disables Recall
        Set-ItemProperty -Path $windowsAIPolicyPath -Name "DisableSettingsAgent" -Value 1 -Force  # Disables AI in Settings

        # 5. Disable Click to Do (AI screenshot analysis)
        $clickToDoPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
        Set-ItemProperty -Path $clickToDoPath -Name "DisabledHotkeys" -Value 1 -Force

        # 6. Disable Bing Chat integration (legacy but still present)
        $bingChatPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search"
        if (Test-Path $bingChatPath) {
            Set-ItemProperty -Path $bingChatPath -Name "BingSearchEnabled" -Value 0 -Force
        }

        # 7. Remove any Copilot app packages if they exist
        try {
            $copilotPackages = Get-AppxPackage -AllUsers | Where-Object { $_.Name -like "*Copilot*" -or $_.Name -like "*WindowsAI*" }
            foreach ($package in $copilotPackages) {
                Write-Host "Removing Copilot-related package: $($package.Name)" -ForegroundColor Cyan
                Remove-AppxPackage -Package $package.PackageFullName -AllUsers -ErrorAction SilentlyContinue
            }
        } catch {
            Write-Host "No removable Copilot packages found or removal failed: $($_.Exception.Message)" -ForegroundColor Yellow
        }

        # 8. Disable Copilot keyboard shortcut (Win+C) via registry
        $keyboardPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
        Set-ItemProperty -Path $keyboardPath -Name "DisabledHotkeys" -Value "C" -Force

        # 9. Restart Explorer and related processes to apply changes (with better handling)
        Write-Host "Restarting Explorer and related processes..." -ForegroundColor Cyan
        
        # Store form state
        $formWasTopMost = $Form.TopMost
        $Form.TopMost = $false  # Temporarily disable to avoid conflicts
        
        Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
        Stop-Process -Name SearchApp -Force -ErrorAction SilentlyContinue
        Stop-Process -Name StartMenuExperienceHost -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 3  # Give more time for processes to restart
        Start-Process explorer
        
        # Wait a bit more and restore form focus
        Start-Sleep -Seconds 2
        $Form.TopMost = $formWasTopMost
        $Form.Activate()
        $Form.BringToFront()

        Write-Host "Windows Copilot and related AI features have been disabled." -ForegroundColor Green
        Write-Host "Note: A restart may be required for all changes to take effect." -ForegroundColor Yellow

    } "Disable-Copilot"
}

function Optimize-Gaming {
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

        # Enable Game Mode for better CPU/GPU prioritization
        Set-ItemProperty -Path $gameBarPath2 -Name "AutoGameModeEnabled" -Value 1 -Force

        # Enable Hardware-Accelerated GPU Scheduling (Windows 10 2004+)
        Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" -Name "HwSchMode" -Value 2 -Force -ErrorAction SilentlyContinue

        # Disable mouse pointer acceleration (enhance pointer precision)
        Set-ItemProperty -Path "HKCU:\Control Panel\Mouse" -Name "MouseSpeed" -Value "0" -Force
        Set-ItemProperty -Path "HKCU:\Control Panel\Mouse" -Name "MouseThreshold1" -Value "0" -Force
        Set-ItemProperty -Path "HKCU:\Control Panel\Mouse" -Name "MouseThreshold2" -Value "0" -Force

        # Disable fullscreen optimizations globally
        $gameConfigPath = "HKCU:\System\GameConfigStore"
        if (-not (Test-Path $gameConfigPath)) { New-Item -Path $gameConfigPath -Force | Out-Null }
        Set-ItemProperty -Path $gameConfigPath -Name "GameDVR_FSEBehaviorMode" -Value 2 -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $gameConfigPath -Name "GameDVR_HonorUserFSEBehaviorMode" -Value 1 -Force -ErrorAction SilentlyContinue

    } "Gaming Performance Optimizations"
}

function Optimize-Storage {
    Safe-Execute {
        # Disable NTFS 8.3 filename creation (reduces metadata overhead)
        fsutil behavior set disable8dot3 1 2>$null

        # Disable NTFS last access timestamp (reduces disk writes on every file read)
        fsutil behavior set disablelastaccess 1 2>$null

        # Disable Delivery Optimization (prevents Windows using your bandwidth to seed updates to others)
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

    } "Storage & File System Optimizations"
}

function Optimize-Startup {
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

    } "Startup & Boot Optimizations"
}

function Optimize-UICleanup {
    Safe-Execute {
        # Disable transparency effects
        $personalizePath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize"
        if (-not (Test-Path $personalizePath)) { New-Item -Path $personalizePath -Force | Out-Null }
        Set-ItemProperty -Path $personalizePath -Name "EnableTransparency" -Value 0 -Force

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

        # Disable Windows 11 Widgets / News and Interests
        $widgetsPath = "HKLM:\SOFTWARE\Policies\Microsoft\Dsh"
        if (-not (Test-Path $widgetsPath)) { New-Item -Path $widgetsPath -Force | Out-Null }
        Set-ItemProperty -Path $widgetsPath -Name "AllowNewsAndInterests" -Value 0 -Force

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

function Optimize-RAMFootprint {
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
        $extraServices = @("DiagTrack", "dmwappushservice", "MapsBroker", "lfsvc", "WMPNetworkSvc")
        foreach ($svc in $extraServices) {
            $service = Get-Service -Name $svc -ErrorAction SilentlyContinue
            if ($service) {
                Stop-Service -Name $svc -Force -ErrorAction SilentlyContinue
                Set-Service -Name $svc -StartupType Disabled -ErrorAction SilentlyContinue
            }
        }

        Write-Host "RAM footprint optimizations applied. Restart recommended for full effect." -ForegroundColor Yellow
    } "RAM Footprint Optimizations"
}

function Optimize-RAMDeep {
    Safe-Execute {
        # Deep memory mode: disables virtualization/VBS features that reserve RAM.
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
    } "Deep RAM Optimizations"
}

function Revert-Optimizations {
    Safe-Execute {
        # Remove policy-enforced settings so Windows can return to defaults.
        $policyValuesToRemove = @(
            @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo"; Name = "DisabledByGroupPolicy" },
            @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection"; Name = "AllowTelemetry" },
            @{ Path = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection"; Name = "AllowTelemetry" },
            @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search"; Name = "AllowCortana" },
            @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors"; Name = "DisableLocation" },
            @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy"; Name = "LetAppsRunInBackground" },
            @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot"; Name = "TurnOffWindowsCopilot" },
            @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI"; Name = "DisableAIDataAnalysis" },
            @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI"; Name = "DisableSettingsAgent" },
            @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Dsh"; Name = "AllowNewsAndInterests" },
            @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR"; Name = "AllowGameDVR" }
        )

        foreach ($entry in $policyValuesToRemove) {
            if (Test-Path $entry.Path) {
                Remove-ItemProperty -Path $entry.Path -Name $entry.Name -ErrorAction SilentlyContinue
            }
        }

        # Restore user-facing defaults for UI and gaming behavior.
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
            @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\SearchSettings"; Name = "IsCopilotEnabled"; Value = 1 },
            @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\SearchSettings"; Name = "IsCopilotAvailable"; Value = 1 },
            @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"; Name = "ShowCopilotButton"; Value = 1 },
            @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"; Name = "DisabledHotkeys"; Value = 0 },
            @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search"; Name = "BingSearchEnabled"; Value = 1 },
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
        powercfg -h on 2>$null | Out-Null
        bcdedit /set hypervisorlaunchtype auto 2>$null | Out-Null
        bcdedit /timeout 30 2>$null | Out-Null

        # Re-enable virtualization-related features disabled by deep RAM mode.
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
        }

        foreach ($svcName in $serviceStartupDefaults.Keys) {
            $service = Get-Service -Name $svcName -ErrorAction SilentlyContinue
            if ($service) {
                Set-Service -Name $svcName -StartupType $serviceStartupDefaults[$svcName] -ErrorAction SilentlyContinue
                Start-Service -Name $svcName -ErrorAction SilentlyContinue
            }
        }

        Write-Host "Revert optimizations completed. Reboot recommended to fully restore defaults." -ForegroundColor Yellow
    } "Revert Optimizations"
}

if ($AutomatedMode) {
    # Run all optimizations automatically with progress reporting
    Show-Progress "Starting system optimization..." 0
    
    # Visual effects optimizations
    Show-Progress "Optimizing visual effects..." 10
    VisualFXSetting
    MinAnimate
    TaskbarAnimations
    TaskbarAnimations2
    CompositionPolicy
    ColorizationOpaqueBlend
    AlwaysHibernateThumbnails
    DisableThumbnails
    ListviewAlphaSelect
    DragFullWindows
    FontSmoothing
    ThemeManager
    ThemeManager2
    UserPreferencesMask
    RestartThemeService
    
    # Telemetry and services
    Show-Progress "Disabling telemetry and unnecessary services..." 30
    DisableDiagtrack
    DisableDiagtrack2
    DisableAdvertisingID
    DisableTelemetry
    DisableDataUsage
    DisableFax
    DisableParentalControls
    DisableGeoLocation
    DisableNFCPayments
    DisableRetailDemo
    DisableWindowsInside
    DisableMapsManager
    DisableBackgroundApps
    DisableBackgroundAccess
    
    # Performance optimizations
    Show-Progress "Applying performance optimizations..." 60
    Optimize-PowerSettings
    Optimize-NetworkSettings
    Optimize-MemoryManagement
    Optimize-VisualEffectsAdvanced
    
    # Service optimizations
    Show-Progress "Optimizing system services..." 80
    $sysmainService = Get-Service "SysMain" -ErrorAction SilentlyContinue
    if ($sysmainService) {
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

    # RAM footprint optimization (safe mode)
    Show-Progress "Optimizing RAM footprint..." 90
    Optimize-RAMFootprint
    
    ExecutionCompleted
    exit 0
}

# Scripts to optimize Windows with detailed action descriptions
$ReducedTheme = {
    try {
        Write-Host "Starting Reduced Theme Optimization..." -ForegroundColor Cyan
        VisualFXSetting
        MinAnimate
        TaskbarAnimations
        TaskbarAnimations2
        CompositionPolicy
        ColorizationOpaqueBlend
        AlwaysHibernateThumbnails
        DisableThumbnails
        ListviewAlphaSelect
        DragFullWindows
        FontSmoothing
        ThemeManager
        ThemeManager2
        UserPreferencesMask
        RestartThemeService
        ExecutionCompleted
    } catch {
        Write-Host "Error during Reduced Theme Optimization: $_" -ForegroundColor Red
    }
}

$Turnoffbackgroundapps = {
    try {
        Write-Host "Disabling background apps..." -ForegroundColor Cyan
        DisableBackgroundAccess
        DisableBackgroundApps
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

$PerformanceOptimizations = {
    try {
        Write-Host "Starting Performance Optimizations..." -ForegroundColor Cyan
        Optimize-PowerSettings
        Optimize-NetworkSettings
        Optimize-MemoryManagement
        Optimize-VisualEffectsAdvanced
        
        # Disable Superfetch/SysMain (Windows 10/11)
        $sysmainService = Get-Service "SysMain" -ErrorAction SilentlyContinue
        if ($sysmainService) {
            Stop-Service "SysMain" -Force -ErrorAction SilentlyContinue
            Set-Service "SysMain" -StartupType Disabled -ErrorAction SilentlyContinue
            Write-Host "SysMain (Superfetch) disabled" -ForegroundColor Green
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
        Write-Host "Error during Performance Optimizations: $_" -ForegroundColor Red
    }
}

$DisableCopilot = {
    try {
        Write-Host "Disabling Microsoft Copilot..." -ForegroundColor Cyan
        Disable-Copilot
        ExecutionCompleted
    } catch {
        Write-Host "Error disabling Copilot: $_" -ForegroundColor Red
    }
}

$GamingOptimizations = {
    try {
        Write-Host "Applying gaming performance optimizations..." -ForegroundColor Cyan
        Optimize-Gaming
        ExecutionCompleted
    } catch {
        Write-Host "Error during gaming optimizations: $_" -ForegroundColor Red
    }
}

$StorageOptimizations = {
    try {
        Write-Host "Applying storage and file system optimizations..." -ForegroundColor Cyan
        Optimize-Storage
        ExecutionCompleted
    } catch {
        Write-Host "Error during storage optimizations: $_" -ForegroundColor Red
    }
}

$StartupOptimizations = {
    try {
        Write-Host "Applying startup and boot optimizations..." -ForegroundColor Cyan
        Optimize-Startup
        ExecutionCompleted
    } catch {
        Write-Host "Error during startup optimizations: $_" -ForegroundColor Red
    }
}

$UICleanup = {
    try {
        Write-Host "Cleaning up UI and notifications..." -ForegroundColor Cyan
        Optimize-UICleanup
        ExecutionCompleted
    } catch {
        Write-Host "Error during UI cleanup: $_" -ForegroundColor Red
    }
}

$RAMOptimizations = {
    try {
        Write-Host "Applying RAM footprint optimizations..." -ForegroundColor Cyan
        Optimize-RAMFootprint
        ExecutionCompleted
    } catch {
        Write-Host "Error during RAM optimizations: $_" -ForegroundColor Red
    }
}

$DeepRamOptimizations = {
    try {
        $confirmDeep = [System.Windows.Forms.MessageBox]::Show(
            "Deep RAM mode will disable Hyper-V, WSL2, Windows Sandbox, and VBS features.`n`nA reboot is required.`n`nContinue?",
            "Deep RAM Optimization",
            "YesNo",
            "Warning"
        )

        if ($confirmDeep -ne [System.Windows.Forms.DialogResult]::Yes) {
            Write-Host "Deep RAM optimization cancelled by user." -ForegroundColor Yellow
            return
        }

        Write-Host "Applying deep RAM optimizations..." -ForegroundColor Cyan
        Optimize-RAMDeep
        ExecutionCompleted
    } catch {
        Write-Host "Error during deep RAM optimizations: $_" -ForegroundColor Red
    }
}

$RevertOptimizations = {
    try {
        $confirmRevert = [System.Windows.Forms.MessageBox]::Show(
            "This will revert optimization settings back toward Windows defaults.`n`nThis includes RAM, services, UI, and virtualization settings.`n`nA reboot is recommended.`n`nContinue?",
            "Revert Optimizations",
            "YesNo",
            "Warning"
        )

        if ($confirmRevert -ne [System.Windows.Forms.DialogResult]::Yes) {
            Write-Host "Revert optimizations cancelled by user." -ForegroundColor Yellow
            return
        }

        Write-Host "Reverting optimizations..." -ForegroundColor Cyan
        Revert-Optimizations
        ExecutionCompleted
    } catch {
        Write-Host "Error during optimization revert: $_" -ForegroundColor Red
    }
}

$DoallAbove = {
    try {
        Write-Host "Executing all optimizations..." -ForegroundColor Cyan
        & $ReducedTheme
        & $Turnoffbackgroundapps
        & $DisableServices
        & $DisableTelemetry
        & $PerformanceOptimizations
        & $DisableCopilot
        & $GamingOptimizations
        & $StorageOptimizations
        & $StartupOptimizations
        & $UICleanup
        & $RAMOptimizations
        ExecutionCompleted
    } catch {
        Write-Host "Error during full optimization: $_" -ForegroundColor Red
    }
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
$formWidth = [Math]::Min([Math]::Max(400, $screenWidth * 0.6), 500)
$formHeight = [Math]::Min(780, $screenHeight * 0.9)

# Calculate button width for 2 columns with symmetrical padding
$buttonWidth = [Math]::Floor(($formWidth - 60) / 2)  # 2 columns with 30px padding on each side

# Form Creation with modern UI
$Form = New-Object System.Windows.Forms.Form -Property @{
    Text = "System Optimization - Windows $osVersion"
    Size = New-Object System.Drawing.Size($formWidth, $formHeight)
    StartPosition = 'CenterScreen'
    FormBorderStyle = 'FixedDialog'
    MaximizeBox = $false
    MinimizeBox = $true
    BackColor = [System.Drawing.Color]::FromArgb(245, 245, 245)
    Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Regular)
    MinimumSize = New-Object System.Drawing.Size(400, 700)
    MaximumSize = New-Object System.Drawing.Size(500, 830)
    ShowInTaskbar = $true
    TopMost = $true
}

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
$headerPanel.BackColor = [System.Drawing.Color]::FromArgb(70, 130, 180)
$headerPanel.BorderStyle = 'FixedSingle'

$titleLabel = New-Object System.Windows.Forms.Label
$titleLabel.Text = "System Optimization"
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
$osLabel.ForeColor = [System.Drawing.Color]::LightGray
$osLabel.BackColor = [System.Drawing.Color]::Transparent

$headerPanel.Controls.AddRange(@($titleLabel, $osLabel))
$Form.Controls.Add($headerPanel)

# Instructions label
$instructionsLabel = New-Object System.Windows.Forms.Label
$instructionsLabel.Text = "Select optimization categories below. Changes will be applied immediately."
$instructionsLabel.Size = New-Object System.Drawing.Size(($formWidth - 40), 30)
$instructionsLabel.Location = New-Object System.Drawing.Point(20, 80)
$instructionsLabel.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Italic)
$instructionsLabel.ForeColor = [System.Drawing.Color]::FromArgb(100, 100, 100)
$instructionsLabel.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
$Form.Controls.Add($instructionsLabel)

# Enhanced button creation with modern styling
function Add-OptimizationButton {
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
        Size = New-Object System.Drawing.Size($buttonWidth, 35)
        Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Regular)
        FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
        Cursor = [System.Windows.Forms.Cursors]::Hand
        TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
        Padding = New-Object System.Windows.Forms.Padding(10, 0, 0, 0)
    }

    # Category-based color coding
    switch ($Category) {
        "Visual" {
            $Button.BackColor = [System.Drawing.Color]::FromArgb(220, 240, 255)  # Light blue
            $Button.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(100, 150, 200)
        }
        "Services" {
            $Button.BackColor = [System.Drawing.Color]::FromArgb(230, 255, 230)  # Light green
            $Button.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(100, 180, 100)
        }
        "Performance" {
            $Button.BackColor = [System.Drawing.Color]::FromArgb(255, 240, 220)  # Light orange
            $Button.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(200, 150, 100)
        }
        "Privacy" {
            $Button.BackColor = [System.Drawing.Color]::FromArgb(240, 230, 255)  # Light purple
            $Button.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(150, 100, 200)
        }
        default {
            $Button.BackColor = [System.Drawing.Color]::FromArgb(240, 240, 240)  # Light gray
            $Button.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(180, 180, 180)
        }
    }

    # Enhanced hover effects
    $Button.FlatAppearance.MouseOverBackColor = [System.Drawing.Color]::FromArgb(200, 220, 240)
    $Button.FlatAppearance.MouseDownBackColor = [System.Drawing.Color]::FromArgb(180, 200, 220)

    # Add click handler with proper error handling
    # Use GetNewClosure() to capture function-local variables ($Action, $buttonText, $Button).
    # Script-level controls ($statusLabel, $statusBar, $Form) are accessed via $script: so they
    # are resolved at runtime rather than captured (they may not exist yet at closure creation).
    $buttonText = $Text
    $clickHandler = {
        try {
            # Disable button to prevent multiple clicks
            $Button.Enabled = $false

            # Update status bar
            if ($script:statusLabel) { $script:statusLabel.Text = "Running: $buttonText..." }
            if ($script:statusBar) { $script:statusBar.Refresh() }

            Write-Host "Starting optimization: $buttonText" -ForegroundColor Cyan
            & $Action
            Write-Host "Completed optimization: $buttonText" -ForegroundColor Green

            # Update status bar
            if ($script:statusLabel) { $script:statusLabel.Text = "Completed: $buttonText" }
            if ($script:statusBar) { $script:statusBar.Refresh() }

            # Keep form focused
            if ($script:Form) { $script:Form.Activate() }
        } catch {
            Write-Host "Error during $buttonText`: $($_.Exception.Message)" -ForegroundColor Red

            # Update status bar with error
            if ($script:statusLabel) { $script:statusLabel.Text = "Error: $buttonText failed" }
            if ($script:statusBar) { $script:statusBar.Refresh() }

            # Keep form focused
            if ($script:Form) { $script:Form.Activate() }
        } finally {
            # Re-enable button
            $Button.Enabled = $true
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
$currentY = 120

# Add optimization buttons with modern styling
Add-OptimizationButton "Performance Theme" (New-Object System.Drawing.Point($leftButtonX, $currentY)) $ReducedTheme "Visual" "Optimize visual effects for better performance"
Add-OptimizationButton "Disable Background Apps" (New-Object System.Drawing.Point($rightButtonX, $currentY)) $Turnoffbackgroundapps "Services" "Prevent apps from running in background"
$currentY += 50

Add-OptimizationButton "Disable Services" (New-Object System.Drawing.Point($leftButtonX, $currentY)) $DisableServices "Services" "Disable unnecessary Windows services"
Add-OptimizationButton "Disable Telemetry" (New-Object System.Drawing.Point($rightButtonX, $currentY)) $DisableTelemetry "Privacy" "Disable data collection and telemetry"
$currentY += 50

Add-OptimizationButton "Performance Optimizations" (New-Object System.Drawing.Point($leftButtonX, $currentY)) $PerformanceOptimizations "Performance" "Apply comprehensive performance tweaks"
Add-OptimizationButton "Disable Copilot" (New-Object System.Drawing.Point($rightButtonX, $currentY)) $DisableCopilot "Privacy" "Disable Microsoft Copilot features"
$currentY += 50

Add-OptimizationButton "Gaming Performance" (New-Object System.Drawing.Point($leftButtonX, $currentY)) $GamingOptimizations "Performance" "Disable Game Bar/DVR, enable Game Mode and HAGS, remove mouse acceleration"
Add-OptimizationButton "Storage & File System" (New-Object System.Drawing.Point($rightButtonX, $currentY)) $StorageOptimizations "Performance" "Disable NTFS timestamps, Delivery Optimization, and hibernation"
$currentY += 50

Add-OptimizationButton "Startup & Boot" (New-Object System.Drawing.Point($leftButtonX, $currentY)) $StartupOptimizations "Performance" "Remove startup delay, shorten boot timeout, disable AutoRun"
Add-OptimizationButton "UI & Notifications" (New-Object System.Drawing.Point($rightButtonX, $currentY)) $UICleanup "Privacy" "Disable transparency, Spotlight ads, Widgets, Sticky Keys prompt"
$currentY += 50

Add-OptimizationButton "RAM Footprint" (New-Object System.Drawing.Point($leftButtonX, $currentY)) $RAMOptimizations "Performance" "Lower idle RAM: service host consolidation + extra service trimming"
Add-OptimizationButton "Deep RAM (Advanced)" (New-Object System.Drawing.Point($rightButtonX, $currentY)) $DeepRamOptimizations "Privacy" "Disable Hyper-V/WSL2/VBS memory overhead (reboot required)"
$currentY += 50

Add-OptimizationButton "Revert Optimizations" (New-Object System.Drawing.Point($leftButtonX, $currentY)) $RevertOptimizations "Services" "Restore optimization changes toward Windows defaults"
Add-OptimizationButton "Do All Optimizations" (New-Object System.Drawing.Point($rightButtonX, $currentY)) $DoallAbove "Performance" "Apply all optimizations at once"
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
$statusLabel.Text = "Ready - Select optimizations to apply"
$statusLabel.Spring = $true
$statusBar.Items.Add($statusLabel)
$Form.Controls.Add($statusBar)

# Show the form
$Form.ShowDialog() | Out-Null
