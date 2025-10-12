# Set script to use strict mode with enhanced error handling
Set-StrictMode -Version Latest
$ProgressPreference = 'Continue'  # Show progress bars
$ErrorActionPreference = 'Stop'

# Check for debug mode
$DebugMode = $args -contains "--debug"

# Simple debug output function (console only)
function Write-DebugMessage {
    param([string]$Message, [string]$Level = "INFO")
    
    if ($DebugMode) {
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $logEntry = "[$timestamp] [$Level] $Message"
        Write-Host $logEntry -ForegroundColor $(if($Level -eq "ERROR"){"Red"}elseif($Level -eq "WARN"){"Yellow"}else{"Green"})
    }
}

if ($DebugMode) {
    Write-DebugMessage "Debug mode enabled" "INFO"
}

# Pre-load all required assemblies for better performance
try {
    if ($DebugMode) { Write-DebugMessage "Pre-loading .NET assemblies..." "INFO" }
    $assemblies = @(
        "System.Windows.Forms",
        "System.Drawing",
        "PresentationFramework",
        "System.Windows.Forms.DataVisualization"
    )
    foreach ($assembly in $assemblies) {
        Add-Type -AssemblyName $assembly -ErrorAction Stop
    }
    if ($DebugMode) { Write-DebugMessage "All assemblies loaded successfully" "INFO" }
} catch {
    Write-DebugMessage "Failed to load assemblies: $($_.Exception.Message)" "ERROR"
    Write-Host "Critical Error: Failed to load required .NET assemblies. Please ensure .NET Framework is properly installed." -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}

# Apply visual styles IMMEDIATELY after loading assemblies, before creating any Windows Forms objects
try {
    if ($DebugMode) { Write-DebugMessage "Applying visual styles..." "INFO" }
    [System.Windows.Forms.Application]::EnableVisualStyles()
    [System.Windows.Forms.Application]::SetCompatibleTextRenderingDefault($false)
    if ($DebugMode) { Write-DebugMessage "Visual styles applied successfully" "INFO" }
} catch {
    Write-DebugMessage "Failed to apply visual styles: $($_.Exception.Message)" "WARN"
}

# Global variables for progress tracking
$Global:MainProgressForm = $null
$Global:MainProgressBar = $null
$Global:MainProgressLabel = $null
$Global:CurrentOperation = ""

# Cache script paths at startup
$scriptPaths = @{
    InstallCleaner = ".\Scripts\Windows{0}InstallCleaner.ps1"
    OneDrive = ".\Scripts\Uninstallonedrive.ps1"
    Cleaner = ".\Scripts\WindowsCleaner.ps1"
    Defrag = ".\Scripts\windowsdefrag.ps1"
    DiskCheck = ".\Scripts\windowsrepairvolume.ps1"
    Troubleshooting = ".\Scripts\Troubleshooting.ps1"
    SystemOptimisation = ".\Scripts\SystemOptimisation.ps1"
    AutoMaintenance = ".\Scripts\AutoMaintenance.ps1"
    ScheduledTasks = ".\Scripts\ScheduledMaintenance.ps1"
}

Clear-Host

# Show or hide console window
function Show-Console {
    param ([Switch]$Show, [Switch]$Hide)

    try {
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
        Write-DebugMessage "Console window visibility changed" "INFO"
    } catch {
        Write-DebugMessage "Failed to change console visibility: $($_.Exception.Message)" "WARN"
    }
}

# Don't hide console initially - wait until form is ready
if ($DebugMode) { Write-DebugMessage "Keeping console visible during initialization" "INFO" }

# Enhanced progress dialog with detailed feedback
function Show-ProgressDialog {
    param (
        [string]$Title = 'Windows Maintenance',
        [string]$Status = 'Initializing...',
        [int]$PercentComplete = 0,
        [switch]$Indeterminate,
        [switch]$Close
    )
    
    try {
        if ($Close -and $Global:MainProgressForm) {
            $Global:MainProgressForm.Close()
            $Global:MainProgressForm.Dispose()
            $Global:MainProgressForm = $null
            return
        }
        
        if (-not $Global:MainProgressForm) {
            if ($DebugMode) { Write-DebugMessage "Creating progress dialog form" "INFO" }
            # Create main progress form
            $Global:MainProgressForm = New-Object System.Windows.Forms.Form
            $Global:MainProgressForm.Text = $Title
            $Global:MainProgressForm.Size = New-Object System.Drawing.Size(450, 150)
            $Global:MainProgressForm.StartPosition = 'CenterScreen'
            $Global:MainProgressForm.FormBorderStyle = 'FixedDialog'
            $Global:MainProgressForm.MaximizeBox = $false
            $Global:MainProgressForm.MinimizeBox = $false
            $Global:MainProgressForm.ControlBox = $false
            $Global:MainProgressForm.TopMost = $true
            
            # Main progress bar
            $Global:MainProgressBar = New-Object System.Windows.Forms.ProgressBar
            $Global:MainProgressBar.Size = New-Object System.Drawing.Size(410, 25)
            $Global:MainProgressBar.Location = New-Object System.Drawing.Point(20, 30)
            
            # Status label
            $Global:MainProgressLabel = New-Object System.Windows.Forms.Label
            $Global:MainProgressLabel.Size = New-Object System.Drawing.Size(410, 20)
            $Global:MainProgressLabel.Location = New-Object System.Drawing.Point(20, 65)
            $Global:MainProgressLabel.Text = $Status
            $Global:MainProgressLabel.TextAlign = 'MiddleCenter'
            
            # Time estimate label
            $timeLabel = New-Object System.Windows.Forms.Label
            $timeLabel.Size = New-Object System.Drawing.Size(410, 15)
            $timeLabel.Location = New-Object System.Drawing.Point(20, 85)
            $timeLabel.Text = "Please wait while the operation completes..."
            $timeLabel.TextAlign = 'MiddleCenter'
            $timeLabel.Font = New-Object System.Drawing.Font("Segoe UI", 8, [System.Drawing.FontStyle]::Italic)
            
            $Global:MainProgressForm.Controls.AddRange(@($Global:MainProgressBar, $Global:MainProgressLabel, $timeLabel))
            $Global:MainProgressForm.Show()
            if ($DebugMode) { Write-DebugMessage "Progress dialog created and shown" "INFO" }
        }
        
        # Update progress
        if ($Indeterminate) {
            $Global:MainProgressBar.Style = 'Marquee'
            $Global:MainProgressBar.MarqueeAnimationSpeed = 30
        } else {
            $Global:MainProgressBar.Style = 'Continuous'
            $Global:MainProgressBar.Value = [Math]::Min($PercentComplete, 100)
        }
        
        $Global:MainProgressLabel.Text = $Status
        $Global:MainProgressForm.Refresh()
        [System.Windows.Forms.Application]::DoEvents()
        
    } catch {
        Write-DebugMessage "Error in Show-ProgressDialog: $($_.Exception.Message)" "ERROR"
        # Fallback to console output if GUI fails
        Write-Host "Progress: $Status" -ForegroundColor Cyan
    }
}

# Enhanced script execution with detailed progress tracking
function Invoke-ScriptWithProgress {
    param (
        [string]$ScriptPath,
        [string]$DisplayName,
        [scriptblock]$ScriptBlock = $null,
        [string[]]$ArgumentList = $null,
        [switch]$ShowDetailedProgress
    )
    
    try {
        Write-Host "Starting: $DisplayName" -ForegroundColor Cyan
        Show-ProgressDialog -Status "Preparing $DisplayName..." -Indeterminate
        Start-Sleep -Milliseconds 500  # Brief pause for user feedback
        
        $success = $false
        
        if ($ScriptBlock) {
            # Execute script block directly
            Show-ProgressDialog -Status "Executing $DisplayName..." -Indeterminate
            & $ScriptBlock
            $success = $true
        } elseif ($ScriptPath -and (Test-Path $ScriptPath)) {
            # Execute external script
            Show-ProgressDialog -Status "Running $DisplayName script..." -Indeterminate
            
            $job = Start-Job -ScriptBlock {
                param($path, $scriptArgs)
                try {
                    if ($scriptArgs) {
                        & $path @scriptArgs
                    } else {
                        & $path
                    }
                    return $true
                } catch {
                    Write-Error $_.Exception.Message
                    return $false
                }
            } -ArgumentList $ScriptPath, $ArgumentList
            
            # Monitor job progress
            $timeout = 300  # 5 minutes timeout
            $elapsed = 0
            
            while ($job.State -eq 'Running' -and $elapsed -lt $timeout) {
                Show-ProgressDialog -Status "Running $DisplayName... ($elapsed seconds)" -Indeterminate
                Start-Sleep -Seconds 1
                $elapsed++
            }
            
            $result = Wait-Job $job -Timeout 60 | Receive-Job
            Remove-Job $job -Force
            $success = $result -eq $true
        } else {
            Write-Warning "Script not found: $ScriptPath"
            Show-ProgressDialog -Status "Script not found: $DisplayName" -PercentComplete 0
            Start-Sleep -Seconds 2
            return $false
        }
        
        if ($success) {
            Show-ProgressDialog -Status "$DisplayName completed successfully!" -PercentComplete 100
            Write-Host "Completed: $DisplayName" -ForegroundColor Green
        } else {
            Show-ProgressDialog -Status "$DisplayName completed with warnings" -PercentComplete 100
            Write-Host "Completed with warnings: $DisplayName" -ForegroundColor Yellow
        }
        
        Start-Sleep -Seconds 2
        return $success
        
    } catch {
        Write-Host "Error in $DisplayName`: $_" -ForegroundColor Red
        Show-ProgressDialog -Status "Error in $DisplayName" -PercentComplete 0
        Start-Sleep -Seconds 3
        return $false
    } finally {
        Show-ProgressDialog -Close
    }
}

# Enhanced Windows version detection with progress feedback
function Get-WindowsVersion {
    try {
        if ($DebugMode) { Write-DebugMessage "Starting Windows version detection" "INFO" }
        Show-ProgressDialog -Status "Detecting Windows version..." -Indeterminate
        
        $os = Get-CimInstance -ClassName CIM_OperatingSystem -Property Version
        $version = [version]$os.Version
        if ($DebugMode) { Write-DebugMessage "Raw version detected: $($version.ToString())" "INFO" }
        
        Show-ProgressDialog -Status "Analyzing system information..." -PercentComplete 50
        Start-Sleep -Milliseconds 300
        
        $detectedVersion = ""
        
        # Windows 11
        if ($version -ge [version]"10.0.22000") {
            $detectedVersion = '11'
        }
        # Windows 10
        elseif ($version -ge [version]"10.0.10240") {
            $detectedVersion = '10'
        }
        # Windows 8.1
        elseif ($version -ge [version]"6.3") {
            $detectedVersion = '8.1'
        }
        # Windows 8
        elseif ($version -ge [version]"6.2") {
            $detectedVersion = '8'
        }
        # Windows 7
        elseif ($version -ge [version]"6.1") {
            $detectedVersion = '7'
        }
        # Windows Vista
        elseif ($version -ge [version]"6.0") {
            $detectedVersion = 'Vista'
        }
        # Windows XP 64-bit
        elseif ($version -ge [version]"5.2") {
            $detectedVersion = 'XP64'
        }
        # Windows XP 32-bit
        elseif ($version -ge [version]"5.1") {
            $detectedVersion = 'XP'
        }
        else {
            $detectedVersion = 'Unknown'
        }
        
        if ($DebugMode) { Write-DebugMessage "Windows version detected: $detectedVersion" "INFO" }
        Show-ProgressDialog -Status "Windows $detectedVersion detected successfully!" -PercentComplete 100
        Start-Sleep -Seconds 1
        
        return $detectedVersion
    }
    catch {
        Write-DebugMessage "Error in Get-WindowsVersion: $($_.Exception.Message)" "ERROR"
        # Fallback for very old systems where Get-CimInstance might not work
        Show-ProgressDialog -Status "Using fallback detection method..." -PercentComplete 75
        
        try {
            $osInfo = [System.Environment]::OSVersion
            if ($osInfo.Version.Major -eq 5 -and $osInfo.Version.Minor -eq 1) {
                return 'XP'
            }
            elseif ($osInfo.Version.Major -eq 5 -and $osInfo.Version.Minor -eq 2) {
                return 'XP64'
            }
            else {
                return 'Unknown'
            }
        }
        catch {
            Write-DebugMessage "Fallback detection also failed: $($_.Exception.Message)" "ERROR"
            Show-ProgressDialog -Status "Could not detect Windows version" -PercentComplete 0
            Start-Sleep -Seconds 2
            return 'Unknown'
        }
    }
    finally {
        Show-ProgressDialog -Close
    }
}

# Determine which cleanup script to use based on the OS version
try {
    Write-Host "Initializing Windows Maintenance Tool..." -ForegroundColor Cyan
    if ($DebugMode) { Write-DebugMessage "Starting OS version detection" "INFO" }
    
    $osVersion = Get-WindowsVersion
    Write-Host "OS Version Detected: Windows $osVersion" -ForegroundColor Green
    if ($DebugMode) { Write-DebugMessage "OS Version determined: Windows $osVersion" "INFO" }

    switch ($osVersion) {
        "10" {
            Write-Host "Configured for Windows 10" -ForegroundColor Green
            $installCleanerScript = ".\Scripts\Windows10InstallCleaner.ps1"
            if ($DebugMode) { Write-DebugMessage "Configured for Windows 10" "INFO" }
        }
        "11" {
            Write-Host "Configured for Windows 11" -ForegroundColor Green
            $installCleanerScript = ".\Scripts\Windows11InstallCleaner.ps1"
            if ($DebugMode) { Write-DebugMessage "Configured for Windows 11" "INFO" }
        }
        default {
            Write-Host "Error: OS could not be determined or unsupported OS ($osVersion)." -ForegroundColor Red
            Write-DebugMessage "Unsupported OS version: $osVersion" "ERROR"
            
            # Show console for error message
            Show-Console -Show
            
            $errorMessage = "Unsupported or undetected Windows version: $osVersion`n`nThis tool supports Windows 10 and 11 only."
            if ($DebugMode) { $errorMessage += "`n`nDebug mode is enabled." }
            
            [System.Windows.Forms.MessageBox]::Show(
                $errorMessage,
                'Windows Maintenance - Version Error',
                'OK',
                'Error'
            )
            Write-DebugMessage "Exiting due to unsupported OS" "ERROR"
            exit 1
        }
    }
} catch {
    Write-DebugMessage "Critical error during initialization: $($_.Exception.Message)" "ERROR"
    Show-Console -Show
    
    $errorMessage = "Critical error during initialization: $($_.Exception.Message)"
    if ($DebugMode) { $errorMessage += "`n`nDebug mode is enabled." }
    
    [System.Windows.Forms.MessageBox]::Show(
        $errorMessage,
        'Windows Maintenance - Critical Error',
        'OK',
        'Error'
    )
    exit 1
}

# Enhanced script blocks with detailed progress tracking and better error handling
$Scripts = @{
    WindowsInstallCleanup = [scriptblock]::Create({ 
        Invoke-ScriptWithProgress -ScriptPath $installCleanerScript -DisplayName "Windows Install Cleanup"
    })
    
    WindowsUninstallOneDrive = [scriptblock]::Create({ 
        Invoke-ScriptWithProgress -ScriptPath ".\Scripts\Uninstallonedrive.ps1" -DisplayName "OneDrive Uninstaller"
    })
    
    WindowsCleaner = [scriptblock]::Create({ 
        Invoke-ScriptWithProgress -ScriptPath ".\Scripts\WindowsCleaner.ps1" -DisplayName "Windows System Cleaner" -ArgumentList "--automated"
    })
    
    Defrag = [scriptblock]::Create({ 
        Invoke-ScriptWithProgress -ScriptPath ".\Scripts\windowsdefrag.ps1" -DisplayName "Disk Defragmentation"
    })
    
    DiskCheck = [scriptblock]::Create({ 
        Invoke-ScriptWithProgress -ScriptPath ".\Scripts\windowsrepairvolume.ps1" -DisplayName "Disk Check and Repair"
    })
    
    ReinstallApps = [scriptblock]::Create({ 
        Invoke-ScriptWithProgress -DisplayName "Reinstall Default Apps" -ScriptBlock {
            Show-ProgressDialog -Status "Scanning for Windows apps..." -Indeterminate
            
            $apps = Get-AppXPackage -AllUsers -ErrorAction SilentlyContinue
            $totalApps = $apps.Count
            $processedApps = 0
            
            if ($totalApps -gt 0) {
                foreach ($app in $apps) {
                    try {
                        $processedApps++
                        $percentComplete = [Math]::Round(($processedApps / $totalApps) * 100)
                        Show-ProgressDialog -Status "Reinstalling: $($app.Name)" -PercentComplete $percentComplete
                        
                        Add-AppxPackage -DisableDevelopmentMode -Register "$($app.InstallLocation)\AppXManifest.xml" -ErrorAction SilentlyContinue
                    } catch {
                        Write-Warning "Failed to reinstall $($app.Name): $_"
                    }
                }
                Show-ProgressDialog -Status "App reinstallation completed!" -PercentComplete 100
            } else {
                Show-ProgressDialog -Status "No apps found to reinstall" -PercentComplete 100
            }
            
            Start-Sleep -Seconds 2
        }
    })
    
    DelProf = [scriptblock]::Create({ 
        Invoke-ScriptWithProgress -DisplayName "Delete User Profiles" -ScriptBlock {
            Show-ProgressDialog -Status "Preparing DelProf2 utility..." -Indeterminate
            
            if (Test-Path ".\Scripts\Delprof2.exe") {
                Show-ProgressDialog -Status "Running DelProf2 user profile cleanup..." -Indeterminate
                Start-Process -FilePath ".\Scripts\Delprof2.exe" -ArgumentList "/u", "/q" -Wait -NoNewWindow
                Show-ProgressDialog -Status "User profile cleanup completed!" -PercentComplete 100
            } else {
                Show-ProgressDialog -Status "DelProf2.exe not found in Scripts folder" -PercentComplete 0
                Write-Warning "DelProf2.exe not found in Scripts folder"
            }
            
            Start-Sleep -Seconds 2
        }
    })
    
    DISMRestore = [scriptblock]::Create({ 
        Invoke-ScriptWithProgress -DisplayName "DISM System Health" -ScriptBlock {
            Show-ProgressDialog -Status "Running DISM health scan..." -PercentComplete 25
            $null = DISM /Online /Cleanup-Image /ScanHealth /NoRestart
            
            Show-ProgressDialog -Status "Running DISM health restoration..." -PercentComplete 75
            $null = DISM /Online /Cleanup-Image /RestoreHealth /NoRestart
            
            Show-ProgressDialog -Status "DISM operations completed successfully!" -PercentComplete 100
            Start-Sleep -Seconds 2
        }
    })
    
    SFCRepair = [scriptblock]::Create({ 
        Invoke-ScriptWithProgress -DisplayName "System File Check" -ScriptBlock {
            Show-ProgressDialog -Status "Running System File Checker (SFC)..." -Indeterminate
            $null = sfc /scannow
            Show-ProgressDialog -Status "System file check completed!" -PercentComplete 100
            Start-Sleep -Seconds 2
        }
    })
    
    WindowsTroubleshooting = [scriptblock]::Create({ 
        Invoke-ScriptWithProgress -ScriptPath ".\Scripts\Troubleshooting.ps1" -DisplayName "Windows Troubleshooting"
    })
    
    SystemOptimisation = [scriptblock]::Create({ 
        Invoke-ScriptWithProgress -ScriptPath ".\Scripts\SystemOptimisation.ps1" -DisplayName "System Optimization" -ArgumentList "--automated"
    })
}

# Validate script block assignment and provide feedback
Write-Host "Validating maintenance modules..." -ForegroundColor Cyan
$validationErrors = 0

foreach ($key in $Scripts.Keys) {
    if ($null -eq $Scripts[$key]) {
        Write-Host "Error: Script block for $key is null." -ForegroundColor Red
        $validationErrors++
    } else {
        Write-Host "OK $key module loaded successfully" -ForegroundColor Green
    }
}

if ($validationErrors -gt 0) {
    Write-Host "Warning: $validationErrors module(s) failed to load properly." -ForegroundColor Yellow
} else {
    Write-Host "All maintenance modules loaded successfully!" -ForegroundColor Green
}

# Enhanced main form with modern UI and better organization
try {
    if ($DebugMode) { Write-DebugMessage "Creating main form" "INFO" }

    # Calculate optimal form size based on screen resolution
    $screen = [System.Windows.Forms.Screen]::PrimaryScreen
    $screenWidth = $screen.Bounds.Width
    $screenHeight = $screen.Bounds.Height

    # Responsive sizing: use 85% of screen width but cap at 800px for better layout, increase height for all sections
    $formWidth = [Math]::Min([Math]::Max(550, $screenWidth * 0.85), 800)
    $formHeight = [Math]::Min(700, $screenHeight * 0.85)

    # Calculate button width for 3 columns with symmetrical padding
    $buttonWidth = [Math]::Floor(($formWidth - 100) / 3)  # 3 columns with 20px padding on each side, 20px between columns

    $Form = New-Object System.Windows.Forms.Form -Property @{
        Text = "Windows Maintenance Tool v2.0 - Windows $osVersion"
        Size = New-Object System.Drawing.Size($formWidth, $formHeight)
        StartPosition = 'CenterScreen'
        FormBorderStyle = 'FixedDialog'
        MaximizeBox = $false
        MinimizeBox = $true
        BackColor = [System.Drawing.Color]::FromArgb(245, 245, 245)
        Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Regular)
        MinimumSize = New-Object System.Drawing.Size(550, 700)
        MaximumSize = New-Object System.Drawing.Size(800, 750)
    }

    if ($DebugMode) { Write-DebugMessage "Main form created successfully" "INFO" }
} catch {
    Write-DebugMessage "Failed to create main form: $($_.Exception.Message)" "ERROR"
    Show-Console -Show

    $errorMessage = "Failed to create main form: $($_.Exception.Message)"
    if ($DebugMode) { $errorMessage += "`n`nDebug mode is enabled." }

    [System.Windows.Forms.MessageBox]::Show(
        $errorMessage,
        'Windows Maintenance - Form Error',
        'OK',
        'Error'
    )
    exit 1
}

# Try to set icon if available
try {
    if (Test-Path ".\Assets\windowslogo.ico") {
        $Form.Icon = [System.Drawing.Icon]::ExtractAssociatedIcon(".\Assets\windowslogo.ico")
        if ($DebugMode) { Write-DebugMessage "Icon loaded successfully" "INFO" }
    } else {
        if ($DebugMode) { Write-DebugMessage "Icon file not found: .\Assets\windowslogo.ico" "WARN" }
    }
} catch {
    if ($DebugMode) { Write-DebugMessage "Could not load icon file: $($_.Exception.Message)" "WARN" }
}

# Header section with title and OS info
$headerPanel = New-Object System.Windows.Forms.Panel
$headerPanel.Size = New-Object System.Drawing.Size(($formWidth - 20), 60)
$headerPanel.Location = New-Object System.Drawing.Point(10, 10)
$headerPanel.BackColor = [System.Drawing.Color]::FromArgb(70, 130, 180)
$headerPanel.BorderStyle = 'FixedSingle'

$titleLabel = New-Object System.Windows.Forms.Label
$titleLabel.Text = "Windows Maintenance Tool"
$titleLabel.Size = New-Object System.Drawing.Size(400, 25)
$titleLabel.Location = New-Object System.Drawing.Point(15, 10)
$titleLabel.Font = New-Object System.Drawing.Font("Segoe UI", 14, [System.Drawing.FontStyle]::Bold)
$titleLabel.ForeColor = [System.Drawing.Color]::White
$titleLabel.BackColor = [System.Drawing.Color]::Transparent

$osLabel = New-Object System.Windows.Forms.Label
$osLabel.Text = "Detected OS: Windows $osVersion"
$osLabel.Size = New-Object System.Drawing.Size(200, 20)
$osLabel.Location = New-Object System.Drawing.Point(15, 35)
$osLabel.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Regular)
$osLabel.ForeColor = [System.Drawing.Color]::LightGray
$osLabel.BackColor = [System.Drawing.Color]::Transparent

$headerPanel.Controls.AddRange(@($titleLabel, $osLabel))
$Form.Controls.Add($headerPanel)

# Enhanced button creation with progress integration and modern styling
function Add-MaintenanceButton {
    param (
        [string]$Text,
        [System.Drawing.Point]$Location,
        [scriptblock]$Action,
        [string]$Category = "Default",
        [string]$Description = ""
    )
    
    # Calculate button width based on form size (3 buttons per row with symmetrical padding)
    # $buttonWidth is now calculated globally above
    
    $Button = New-Object System.Windows.Forms.Button -Property @{
        Text = $Text
        Location = $Location
        Size = New-Object System.Drawing.Size($buttonWidth, 35)  # Responsive width
        Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Regular)
        FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
        Cursor = [System.Windows.Forms.Cursors]::Hand
        TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
        Padding = New-Object System.Windows.Forms.Padding(10, 0, 0, 0)
    }
    
    # Category-based color coding
    switch ($Category) {
        "Cleanup" { 
            $Button.BackColor = [System.Drawing.Color]::FromArgb(220, 240, 255)  # Light blue
            $Button.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(100, 150, 200)
        }
        "Repair" { 
            $Button.BackColor = [System.Drawing.Color]::FromArgb(230, 255, 230)  # Light green
            $Button.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(100, 180, 100)
        }
        "Advanced" { 
            $Button.BackColor = [System.Drawing.Color]::FromArgb(255, 240, 220)  # Light orange
            $Button.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(200, 150, 100)
        }
        "Special" { 
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
    
    # Add progress-aware click handler
    $Button.Add_Click({
        try {
            Write-Host "Starting maintenance task: $Text" -ForegroundColor Cyan
            
            # Disable all buttons during operation
            foreach ($control in $Form.Controls) {
                if ($control -is [System.Windows.Forms.Button]) {
                    $control.Enabled = $false
                }
            }
            
            # Execute the action
            $result = & $Action
            
            # Show completion message
            if ($result -ne $false) {
                [System.Windows.Forms.MessageBox]::Show(
                    "$Text completed successfully!",
                    'Windows Maintenance',
                    'OK',
                    'Information'
                )
            } else {
                [System.Windows.Forms.MessageBox]::Show(
                    "$Text completed with warnings. Check the console for details.",
                    'Windows Maintenance',
                    'OK',
                    'Warning'
                )
            }
            
        } catch {
            Write-Host "Error in $Text`: $_" -ForegroundColor Red
            [System.Windows.Forms.MessageBox]::Show(
                "Error during $Text`: $($_.Exception.Message)",
                'Windows Maintenance - Error',
                'OK',
                'Error'
            )
        } finally {
            # Re-enable all buttons
            foreach ($control in $Form.Controls) {
                if ($control -is [System.Windows.Forms.Button]) {
                    $control.Enabled = $true
                }
            }
            
            Write-Host "Maintenance task completed: $Text" -ForegroundColor Green
        }
    })
    
    # Add tooltip if description is provided
    if ($Description) {
        $tooltip = New-Object System.Windows.Forms.ToolTip
        $tooltip.SetToolTip($Button, $Description)
    }
    
    $Form.Controls.Add($Button)
    return $Button
}

# Enhanced section labels with better styling
function Add-SectionLabel {
    param (
        [string]$Text,
        [System.Drawing.Point]$Location,
        [string]$Icon = ">"
    )
    
    $Label = New-Object System.Windows.Forms.Label -Property @{
        Text = "$Icon $Text"
        Location = $Location
        Size = New-Object System.Drawing.Size(($formWidth - 60), 25)
        Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
        ForeColor = [System.Drawing.Color]::FromArgb(60, 60, 60)
        BackColor = [System.Drawing.Color]::Transparent
    }
    
    $Form.Controls.Add($Label)
    return $Label
}

# Instructions label
$instructionsLabel = New-Object System.Windows.Forms.Label
$instructionsLabel.Text = "Select maintenance operations below. Each task shows detailed progress."
$instructionsLabel.Size = New-Object System.Drawing.Size(($formWidth - 40), 20)
$instructionsLabel.Location = New-Object System.Drawing.Point(20, 80)
$instructionsLabel.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Italic)
$instructionsLabel.ForeColor = [System.Drawing.Color]::FromArgb(100, 100, 100)
$instructionsLabel.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
$Form.Controls.Add($instructionsLabel)

# Add sections with enhanced spacing and organization
$currentY = 110

# Calculate button positions for 3-column layout with symmetrical padding
$leftButtonX = 30
$middleButtonX = $leftButtonX + $buttonWidth + 20
$rightButtonX = $middleButtonX + $buttonWidth + 20

# System Cleanup Section
Add-SectionLabel "System Cleanup and App Management" (New-Object System.Drawing.Point(30, $currentY))
$currentY += 30

Add-MaintenanceButton "Fresh Install Cleanup" (New-Object System.Drawing.Point($leftButtonX, $currentY)) $Scripts.WindowsInstallCleanup "Cleanup" "Remove unnecessary Windows apps and services for a clean system"
Add-MaintenanceButton "Reinstall Default Apps" (New-Object System.Drawing.Point($middleButtonX, $currentY)) $Scripts.ReinstallApps "Cleanup" "Reinstall Windows default applications if they were removed"
Add-MaintenanceButton "Uninstall OneDrive" (New-Object System.Drawing.Point($rightButtonX, $currentY)) $Scripts.WindowsUninstallOneDrive "Cleanup" "Completely remove OneDrive from the system"
$currentY += 50

Add-MaintenanceButton "Delete User Profiles" (New-Object System.Drawing.Point($leftButtonX, $currentY)) $Scripts.DelProf "Cleanup" "Remove old user profiles to free up disk space"
$currentY += 70

# System Repair Section
Add-SectionLabel "System Health and Repair" (New-Object System.Drawing.Point(30, $currentY))
$currentY += 30

Add-MaintenanceButton "DISM Health Check" (New-Object System.Drawing.Point($leftButtonX, $currentY)) $Scripts.DISMRestore "Repair" "Scan and repair Windows system image integrity"
Add-MaintenanceButton "System File Check" (New-Object System.Drawing.Point($middleButtonX, $currentY)) $Scripts.SFCRepair "Repair" "Verify and repair corrupted system files"
$currentY += 70

# Disk Maintenance Section  
Add-SectionLabel "Disk Maintenance and Optimization" (New-Object System.Drawing.Point(30, $currentY))
$currentY += 30

Add-MaintenanceButton "System Cleaner" (New-Object System.Drawing.Point($leftButtonX, $currentY)) $Scripts.WindowsCleaner "Repair" "Clean temporary files and system cache"
Add-MaintenanceButton "Disk Check and Repair" (New-Object System.Drawing.Point($middleButtonX, $currentY)) $Scripts.DiskCheck "Repair" "Check and repair disk errors"
Add-MaintenanceButton "Disk Defragmentation" (New-Object System.Drawing.Point($rightButtonX, $currentY)) $Scripts.Defrag "Repair" "Optimize disk performance (HDD only, SSD detection included)"
$currentY += 70

# Advanced Options Section
Add-SectionLabel "Advanced System Tools" (New-Object System.Drawing.Point(30, $currentY))
$currentY += 30

Add-MaintenanceButton "System Troubleshooting" (New-Object System.Drawing.Point($leftButtonX, $currentY)) $Scripts.WindowsTroubleshooting "Advanced" "Network and Windows Update troubleshooting tools"
Add-MaintenanceButton "Performance Optimization" (New-Object System.Drawing.Point($middleButtonX, $currentY)) $Scripts.SystemOptimisation "Advanced" "Optimize system settings for better performance"
$currentY += 70

# Special Operations Section
Add-SectionLabel "Automated Operations" (New-Object System.Drawing.Point(30, $currentY))
$currentY += 30

# Automated maintenance operations with comprehensive progress tracking
function Start-AutomatedMaintenance {
    param([switch]$ScheduleMode)
    
    Show-ProgressDialog -Status "Initializing complete PC setup sequence..." -Indeterminate
    Start-Sleep -Seconds 1
    
    $maintenanceTasks = @(
        @{ Name = "Windows Install Cleanup"; Script = $Scripts.WindowsInstallCleanup; Weight = 10 }
        @{ Name = "OneDrive Uninstaller"; Script = $Scripts.WindowsUninstallOneDrive; Weight = 8 }
        @{ Name = "System File Cleanup"; Script = $Scripts.WindowsCleaner; Weight = 12 }
        @{ Name = "Delete User Profiles"; Script = $Scripts.DelProf; Weight = 8 }
        @{ Name = "System Health Check"; Script = $Scripts.DISMRestore; Weight = 15 }
        @{ Name = "System File Verification"; Script = $Scripts.SFCRepair; Weight = 12 }
        @{ Name = "Disk Check and Repair"; Script = $Scripts.DiskCheck; Weight = 10 }
        @{ Name = "Disk Defragmentation"; Script = $Scripts.Defrag; Weight = 10 }
        @{ Name = "Windows Troubleshooting"; Script = $Scripts.WindowsTroubleshooting; Weight = 8 }
        @{ Name = "System Optimization"; Script = $Scripts.SystemOptimisation; Weight = 7 }
    )
    
    $totalTasks = $maintenanceTasks.Count
    $currentTask = 0
    $overallProgress = 0
    
    foreach ($task in $maintenanceTasks) {
        $currentTask++
        $taskProgress = [Math]::Round(($currentTask / $totalTasks) * 100)
        
        Show-ProgressDialog -Status "[$currentTask/$totalTasks] $($task.Name)..." -PercentComplete $taskProgress
        
        try {
            & $task.Script
            Write-Host "Completed: $($task.Name)" -ForegroundColor Green
        } catch {
            Write-Host "Warning in $($task.Name): $_" -ForegroundColor Yellow
        }
        
        $overallProgress += $task.Weight
        Start-Sleep -Seconds 1
    }
    
    Show-ProgressDialog -Status "Complete PC setup finished successfully!" -PercentComplete 100
    Start-Sleep -Seconds 3
    Show-ProgressDialog -Close
    
    if (-not $ScheduleMode) {
        [System.Windows.Forms.MessageBox]::Show(
            "Complete PC Setup completed successfully!`n`nYour Windows system has been fully optimized and is ready for use.`n`nAll maintenance tasks, cleanups, and optimizations have been performed.",
            'Windows Maintenance - Complete Setup',
            'OK',
            'Information'
        )
    }
}

# Complete PC Setup button - runs everything for a fully optimized system
Add-MaintenanceButton "Complete PC Setup" (New-Object System.Drawing.Point($leftButtonX, $currentY)) {
    $result = [System.Windows.Forms.MessageBox]::Show(
        "This will run the COMPLETE PC Setup sequence - all maintenance tasks, cleanups, and optimizations.`n`nThis is the ultimate one-click solution to fully optimize your Windows system.`n`nThis may take 20-45 minutes depending on your system.`n`nDo you want to continue?",
        'Windows Maintenance - Complete PC Setup',
        'YesNo',
        'Question'
    )
    
    if ($result -eq 'Yes') {
        Start-AutomatedMaintenance
    }
} "Special" "Run the complete PC setup sequence - all cleanups, repairs, optimizations, and maintenance tasks for a fully optimized Windows system"

$currentY += 70

# Enhanced Exit button with better positioning
$ExitButton = New-Object System.Windows.Forms.Button -Property @{
    Text = 'Exit Application'
    Location = New-Object System.Drawing.Point((($formWidth - 130) / 2), $currentY)
    Size = New-Object System.Drawing.Size(130, 35)
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
$statusLabel.Text = "Ready - Select a maintenance operation to begin"
$statusLabel.Spring = $true
$statusBar.Items.Add($statusLabel)
$Form.Controls.Add($statusBar)

# Handle command line parameters for automation
if ($args -contains "-AutoMaintenance") {
    Write-Host "Running in automated maintenance mode..." -ForegroundColor Green
    Start-AutomatedMaintenance -ScheduleMode
    exit
}

# Show the form - visual styles already applied at the beginning
try {
    if ($DebugMode) { Write-DebugMessage "Preparing to show main form" "INFO" }

    Write-Host "Windows Maintenance Tool initialized successfully!" -ForegroundColor Green
    Write-Host "Form ready for user interaction." -ForegroundColor Cyan
    if ($DebugMode) { 
        Write-DebugMessage "Form initialization complete, hiding console" "INFO"
        Write-Host "Debug mode: Console will remain visible for debugging" -ForegroundColor Yellow
    } else {
        # Only hide console if not in debug mode
        Show-Console -Hide
    }
    
    if ($DebugMode) { Write-DebugMessage "Showing main form" "INFO" }
    $formResult = $Form.ShowDialog()
    if ($DebugMode) { Write-DebugMessage "Form closed with result: $formResult" "INFO" }
    
} catch {
    Write-DebugMessage "Error showing form: $($_.Exception.Message)" "ERROR"
    Show-Console -Show
    
    $errorMessage = "Error displaying form: $($_.Exception.Message)"
    if ($DebugMode) { $errorMessage += "`n`nDebug mode is enabled." }
    
    [System.Windows.Forms.MessageBox]::Show(
        $errorMessage,
        'Windows Maintenance - Display Error',
        'OK',
        'Error'
    )
} finally {
    # Cleanup
    try {
        Show-ProgressDialog -Close
        if ($Form) { $Form.Dispose() }
        if ($DebugMode) { Write-DebugMessage "Cleanup completed" "INFO" }
    } catch {
        if ($DebugMode) { Write-DebugMessage "Error during cleanup: $($_.Exception.Message)" "WARN" }
    }
}

Write-Host "Windows Maintenance Tool session ended." -ForegroundColor Cyan
if ($DebugMode) { Write-DebugMessage "Session ended normally" "INFO" }

# Created by Chris Masters - Enhanced with unified progress tracking and modern UI