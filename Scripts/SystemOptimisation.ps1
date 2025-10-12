# Check if called from main script (automated mode)
$AutomatedMode = $args -contains "--automated"

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
    
    ExecutionCompleted
    exit 0
}

# Progress reporting functions for integration with main script
function Show-Progress {
    param([string]$Status, [int]$Percent = -1)
    
    if ($Global:MainProgressForm -and $Global:MainProgressLabel) {
        $Global:MainProgressLabel.Text = $Status
        if ($Percent -ge 0) {
            $Global:MainProgressBar.Style = 'Continuous'
            $Global:MainProgressBar.Value = [Math]::Min($Percent, 100)
        } else {
            $Global:MainProgressBar.Style = 'Marquee'
        }
        $Global:MainProgressForm.Refresh()
        [System.Windows.Forms.Application]::DoEvents()
    } else {
        Write-Host $Status -ForegroundColor Cyan
    }
}

function ExecutionCompleted {
    if ($Global:MainProgressForm) {
        Show-Progress "System optimization completed successfully!" 100
        Start-Sleep -Seconds 2
    } else {
        [System.Windows.MessageBox]::Show('System Optimization Completed Successfully', 'Windows Maintenance', 'Ok', 'Information')
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

# Add new optimization functions
function Optimize-PowerSettings {
    powercfg /setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c # High Performance
    powercfg /change monitor-timeout-ac 10
    powercfg /change disk-timeout-ac 0
    powercfg /change standby-timeout-ac 0
    powercfg /change hibernate-timeout-ac 0
}

function Optimize-NetworkSettings {
    netsh interface tcp set global autotuninglevel=normal
    netsh interface tcp set global chimney=enabled
    netsh interface tcp set global dca=enabled
    netsh interface tcp set global netdma=enabled
}

function Optimize-MemoryManagement {
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" -Name "LargeSystemCache" -Value 1
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" -Name "IoPageLockLimit" -Value 983040
}

# Add new optimization functions for Windows 10/11
function Optimize-PowerSettings {
    Safe-Execute {
        # Set power plan to High Performance if available
        $highPerfGuid = "8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c"
        powercfg -setactive $highPerfGuid 2>$null
        
        # Disable USB selective suspend
        powercfg -setacvalueindex SCHEME_CURRENT 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0
        powercfg -setdcvalueindex SCHEME_CURRENT 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0
        
        # Disable link state power management
        powercfg -setacvalueindex SCHEME_CURRENT 2a737441-1930-4402-8d77-b2bebba308a3 ee12f906-d277-404b-b6da-e5fa1a576df5 0
        powercfg -setdcvalueindex SCHEME_CURRENT 2a737441-1930-4402-8d77-b2bebba308a3 ee12f906-d277-404b-b6da-e5fa1a576df5 0
        
        powercfg -setactive SCHEME_CURRENT
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
        
        # Disable Print Spooler if not needed
        $spoolerChoice = [System.Windows.Forms.MessageBox]::Show('Disable Print Spooler? (Choose No if you use printers)', 'Print Spooler', 'YesNo', 'Question')
        if ($spoolerChoice -eq 'Yes') {
            $spoolerService = Get-Service "Spooler" -ErrorAction SilentlyContinue
            if ($spoolerService) {
                Stop-Service "Spooler" -Force -ErrorAction SilentlyContinue
                Set-Service "Spooler" -StartupType Disabled -ErrorAction SilentlyContinue
                Write-Host "Print Spooler disabled" -ForegroundColor Green
            }
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

$DoallAbove = {
    try {
        Write-Host "Executing all optimizations..." -ForegroundColor Cyan
        & $ReducedTheme
        & $Turnoffbackgroundapps
        & $DisableServices
        & $DisableTelemetry
        & $PerformanceOptimizations
        ExecutionCompleted
    } catch {
        Write-Host "Error during full optimization: $_" -ForegroundColor Red
    }
}

# Form Creation
$Form = New-Object System.Windows.Forms.Form
$Form.Text = 'Windows Optimisation'
$Form.Size = New-Object System.Drawing.Size(370, 350)
$Form.StartPosition = 'CenterScreen'
$Form.Icon = [System.Drawing.Icon]::ExtractAssociatedIcon(".\Assets\windowslogo.ico")

# Label for instructions
$FormText = New-Object System.Windows.Forms.Label
$FormText.Location = New-Object System.Drawing.Point(35, 10)
$FormText.Size = New-Object System.Drawing.Size(300, 18)
$FormText.Text = 'Select Options Below, once done please restart'
$Form.Controls.Add($FormText)

# Button creation function with error handling
function Add-Button {
    param (
        [string]$Text,
        [System.Drawing.Point]$Location,
        [scriptblock]$Action
    )

    $Button = New-Object System.Windows.Forms.Button
    $Button.Text = $Text
    $Button.Location = $Location
    $Button.Size = New-Object System.Drawing.Size(120, 23)
    $Button.Add_Click({
        try {
            # Ensure the script block is invoked correctly
            & $Action
        } catch {
            Write-Host "Error executing action for button '$($this.Text)': $_" -ForegroundColor Red
        }
    })
    $Form.Controls.Add($Button)
}

# Usage Example of Add-Button
Add-Button "Performance Theme" (New-Object System.Drawing.Point(35, 35)) { & $ReducedTheme }
Add-Button "No Background Apps" (New-Object System.Drawing.Point(165, 35)) { & $Turnoffbackgroundapps }
Add-Button "Disable Services" (New-Object System.Drawing.Point(35, 65)) { & $DisableServices }
Add-Button "Disable Telemetry" (New-Object System.Drawing.Point(165, 65)) { & $DisableTelemetry }
Add-Button "Do All" (New-Object System.Drawing.Point(35, 95)) { & $DoallAbove }

# Exit button
$ExitButton = New-Object System.Windows.Forms.Button
$ExitButton.Text = 'Exit'
$ExitButton.Location = New-Object System.Drawing.Point(135, 270)
$ExitButton.Size = New-Object System.Drawing.Size(75, 23)
$ExitButton.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
$Form.Controls.Add($ExitButton)
$Form.CancelButton = $ExitButton

# Show the form
$Form.ShowDialog() | Out-Null
