# Clear the host screen
Clear-Host

# Load necessary .NET types
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName System.Drawing

# Show or hide console window
function Show-Console {
    param ([Switch]$Show, [Switch]$Hide)
    
    if (-not ("Console.Window" -as [type])) {
        Add-Type -Name Window -Namespace Console -MemberDefinition '
            [DllImport("Kernel32.dll")]
            public static extern IntPtr GetConsoleWindow();

            [DllImport("user32.dll")]
            public static extern bool ShowWindow(IntPtr hWnd, Int32 nCmdShow);
        '
    }

    $consolePtr = [Console.Window]::GetConsoleWindow()
    if ($Show) { [Console.Window]::ShowWindow($consolePtr, 5) }
    if ($Hide) { [Console.Window]::ShowWindow($consolePtr, 0) }
}

# Hide the console window
Show-Console -Hide

# Message Box utility functions
function RestartNeeded {
    [System.Windows.MessageBox]::Show('Please restart the computer', 'Windows Troubleshooting', 'Ok', 'Information')
}

function ExecutionCompleted {
    [System.Windows.MessageBox]::Show('Operation Completed', 'Windows Maintenance', 'Ok', 'Information')
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
        Write-Host "Starting: $Description" -ForegroundColor Cyan
        & $Block
        Write-Host "Completed: $Description" -ForegroundColor Green
    } catch {
        Write-Host "Error during $Description $_" -ForegroundColor Red
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

# Telemetry and background services optimization functions
function DisableDiagtrack {
    Safe-Execute { Get-Service -Name "DiagTrack" | Set-Service -StartupType Disabled } "DisableDiagtrack"
}

function DisableDiagtrack2 {
    Safe-Execute { Get-Service -Name "dmwappushservice" | Set-Service -StartupType Disabled } "DisableDiagtrack2"
}

function DisableAdvertisingID {
    Safe-Execute { Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AdvertisingInfo" -Name "Advertising ID" -Value 0 -Force } "DisableAdvertisingID"
}

function DisableTelemetry {
    Safe-Execute { Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -Name "AllowTelemetry" -Value 0 -Force } "DisableTelemetry"
}

function DisableDataUsage {
    Safe-Execute { Get-Service -Name "DusmSvc" | Set-Service -StartupType Disabled } "DisableDataUsage"
}

function DisableFax {
    Safe-Execute { Get-Service -Name "Fax" | Set-Service -StartupType Disabled } "DisableFax"
}

function DisableParentalControls {
    Safe-Execute { Get-Service -Name "WpcMonSvc" | Set-Service -StartupType Disabled } "DisableParentalControls"
}

function DisableGeoLocation {
    Safe-Execute { Get-Service -Name "lfsvc" | Set-Service -StartupType Disabled } "DisableGeoLocation"
}

function DisableNFCPayments {
    Safe-Execute { Get-Service -Name "SEMgrSvc" | Set-Service -StartupType Disabled } "DisableNFCPayments"
}

function DisableRetailDemo {
    Safe-Execute { Get-Service -Name "RetailDemo" | Set-Service -StartupType Disabled } "DisableRetailDemo"
}

function DisableWindowsInside {
    Safe-Execute { Get-Service -Name "wisvc" | Set-Service -StartupType Disabled } "DisableWindowsInside"
}

function DisableMapsManager {
    Safe-Execute { Get-Service -Name "MapsBroker" | Set-Service -StartupType Disabled } "DisableMapsManager"
}

function DisableBackgroundApps {
    Safe-Execute { Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft" -Name "LetAppsRunInBackground" -Value 0 -Force } "DisableBackgroundApps"
}

function DisableBackgroundAccess {
    Safe-Execute { Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications" -Name GlobalUserDisabled -Value 0 -Force } "DisableBackgroundAccess"
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

$DoallAbove = {
    try {
        Write-Host "Executing all optimizations..." -ForegroundColor Cyan
        & $ReducedTheme
        & $Turnoffbackgroundapps
        & $DisableServices
        & $DisableTelemetry
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
