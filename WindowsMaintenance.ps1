# Windows Maintenance Tool - Requires Administrator Privileges
# Auto-elevate if not running as administrator

# Check if running as administrator
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
$isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "Windows Maintenance Tool requires Administrator privileges." -ForegroundColor Yellow
    Write-Host "Requesting elevation..." -ForegroundColor Cyan
    
    # Get the full path to the script
    $scriptPath = $MyInvocation.MyCommand.Path
    
    # Prepare arguments
    $arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`""
    if ($args) {
        $arguments += " " + ($args -join " ")
    }
    
    try {
        # Start new elevated process
        Start-Process powershell.exe -ArgumentList $arguments -Verb RunAs
        exit
    } catch {
        Write-Host "Failed to elevate privileges. Please run as Administrator manually." -ForegroundColor Red
        Read-Host "Press Enter to exit"
        exit 1
    }
}

Write-Host "Running with Administrator privileges" -ForegroundColor Green

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
$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$scriptPaths = @{
    InstallCleaner = Join-Path $ScriptRoot "Scripts\Windows{0}InstallCleaner.ps1"
    OneDrive = Join-Path $ScriptRoot "Scripts\Uninstallonedrive.ps1"
    Cleaner = Join-Path $ScriptRoot "Scripts\WindowsCleaner.ps1"
    Defrag = Join-Path $ScriptRoot "Scripts\windowsdefrag.ps1"
    DiskCheck = Join-Path $ScriptRoot "Scripts\windowsrepairvolume.ps1"
    Troubleshooting = Join-Path $ScriptRoot "Scripts\troubleshooting.ps1"
    SystemOptimisation = Join-Path $ScriptRoot "Scripts\SystemOptimisation.ps1"
    VisualOptimisation = Join-Path $ScriptRoot "Scripts\VisualOptimisation.ps1"
    UserCleaner = Join-Path $ScriptRoot "Scripts\UserCleaner.ps1"
    DefenderFix = Join-Path $ScriptRoot "Scripts\Fix-Windows-Defender.ps1"
    CustomChanges = Join-Path $ScriptRoot "Scripts\CustomChanges.ps1"
    AeroliteTheme = Join-Path $ScriptRoot "Scripts\aerolite.theme"
    Delprof2 = Join-Path $ScriptRoot "Scripts\Delprof2.exe"
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
        if ($Close) {
            if ($Global:MainProgressForm) {
                try {
                    $Global:MainProgressForm.Close()
                    $Global:MainProgressForm.Dispose()
                } catch {
                    # Ignore shutdown cleanup errors.
                }

                $Global:MainProgressForm = $null
                $Global:MainProgressBar = $null
                $Global:MainProgressLabel = $null
            }

            return
        }
        
        if (-not $Global:MainProgressForm) {
            if ($DebugMode) { Write-DebugMessage "Creating progress dialog form" "INFO" }
            # Create main progress form
            $Global:MainProgressForm = New-Object System.Windows.Forms.Form
            $Global:MainProgressForm.Text = $Title
            $Global:MainProgressForm.Size = New-Object System.Drawing.Size(500, 160)
            $Global:MainProgressForm.StartPosition = 'CenterScreen'
            $Global:MainProgressForm.FormBorderStyle = 'FixedDialog'
            $Global:MainProgressForm.MaximizeBox = $false
            $Global:MainProgressForm.MinimizeBox = $false
            $Global:MainProgressForm.ControlBox = $false
            $Global:MainProgressForm.TopMost = $false
            $Global:MainProgressForm.BackColor = [System.Drawing.Color]::FromArgb(248, 250, 252)
            
            # Main progress bar
            $Global:MainProgressBar = New-Object System.Windows.Forms.ProgressBar
            $Global:MainProgressBar.Size = New-Object System.Drawing.Size(450, 24)
            $Global:MainProgressBar.Location = New-Object System.Drawing.Point(25, 38)
            
            # Status label
            $Global:MainProgressLabel = New-Object System.Windows.Forms.Label
            $Global:MainProgressLabel.Size = New-Object System.Drawing.Size(450, 20)
            $Global:MainProgressLabel.Location = New-Object System.Drawing.Point(25, 72)
            $Global:MainProgressLabel.Text = $Status
            $Global:MainProgressLabel.TextAlign = 'MiddleCenter'
            $Global:MainProgressLabel.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
            
            # Time estimate label
            $timeLabel = New-Object System.Windows.Forms.Label
            $timeLabel.Size = New-Object System.Drawing.Size(450, 15)
            $timeLabel.Location = New-Object System.Drawing.Point(25, 98)
            $timeLabel.Text = "Applying changes safely. This window updates as each step completes."
            $timeLabel.TextAlign = 'MiddleCenter'
            $timeLabel.Font = New-Object System.Drawing.Font("Segoe UI", 8, [System.Drawing.FontStyle]::Italic)
            $timeLabel.ForeColor = [System.Drawing.Color]::FromArgb(95, 105, 120)
            
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

function Update-Ui {
    param([System.Windows.Forms.Control]$Control = $null)

    if ($Control) {
        $Control.Refresh()
    }

    [System.Windows.Forms.Application]::DoEvents()
}

function Invoke-UiRefresh {
    param([System.Windows.Forms.Control]$Control = $null)

    try {
        if ($Control -and -not $Control.IsDisposed) {
            $Control.Refresh()
        }

        [System.Windows.Forms.Application]::DoEvents()
    } catch {
        if ($DebugMode) { Write-DebugMessage "UI refresh failed: $($_.Exception.Message)" "WARN" }
    }
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
        if ($DebugMode) { Write-DebugMessage "Could not enable double buffering: $($_.Exception.Message)" "WARN" }
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
        $refreshUi = {
            param([System.Windows.Forms.Control]$Control = $null)

            try {
                if ($Control -and -not $Control.IsDisposed) {
                    $Control.Refresh()
                }

                [System.Windows.Forms.Application]::DoEvents()
            } catch {
                # Ignore UI refresh exceptions in script execution wrapper.
            }
        }

        Write-Host "Starting: $DisplayName" -ForegroundColor Cyan
        Show-ProgressDialog -Status "Preparing $DisplayName..." -Indeterminate
        & $refreshUi -Control $Global:MainProgressForm
        
        $success = $false
        
        if ($ScriptBlock) {
            # Execute script block directly
            Show-ProgressDialog -Status "Executing $DisplayName..." -Indeterminate
            & $ScriptBlock
            $success = $true
        } elseif ($ScriptPath -and (Test-Path $ScriptPath)) {
            # Execute external script
            Show-ProgressDialog -Status "Running $DisplayName script..." -Indeterminate
            
            # Convert relative path to absolute path
            $absoluteScriptPath = (Resolve-Path $ScriptPath).Path

            # Run in a separate interactive process so child dialogs can be displayed safely.
            # This also prevents child script Exit statements from closing the main UI.
            $psArguments = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $absoluteScriptPath)
            if ($ArgumentList) {
                $psArguments += $ArgumentList
            }

            $childProcess = Start-Process -FilePath powershell.exe -ArgumentList $psArguments -Wait -PassThru -WindowStyle Hidden
            $success = $childProcess.ExitCode -eq 0
        } else {
            Write-Warning "Script not found: $ScriptPath"
            Show-ProgressDialog -Status "Script not found: $DisplayName" -PercentComplete 0
            & $refreshUi -Control $Global:MainProgressForm
            return $false
        }
        
        if ($success) {
            Show-ProgressDialog -Status "$DisplayName completed successfully!" -PercentComplete 100
            Write-Host "Completed: $DisplayName" -ForegroundColor Green
        } else {
            Show-ProgressDialog -Status "$DisplayName completed with warnings" -PercentComplete 100
            Write-Host "Completed with warnings: $DisplayName" -ForegroundColor Yellow
        }

        & $refreshUi -Control $Global:MainProgressForm
        return $success
        
    } catch {
        Write-Host "Error in $DisplayName`: $_" -ForegroundColor Red
        Show-ProgressDialog -Status "Error in $DisplayName" -PercentComplete 0
        & $refreshUi -Control $Global:MainProgressForm
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
            if ($DebugMode) { Write-DebugMessage "Configured for Windows 10" "INFO" }
        }
        "11" {
            Write-Host "Configured for Windows 11" -ForegroundColor Green
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
        Invoke-ScriptWithProgress -DisplayName "Windows Install Cleanup" -ScriptBlock {
            Show-ProgressDialog -Status "Scanning installed Windows apps..." -Indeterminate
            
            # Get all installed AppX packages for the current user
            Write-Host "Scanning installed Windows apps..." -ForegroundColor Cyan
            $installedApps = Get-AppxPackage -ErrorAction SilentlyContinue | Where-Object { 
                $_.Name -notlike "Microsoft.Windows.ShellExperienceHost" -and
                $_.Name -notlike "Microsoft.Windows.Cortana" -and
                $_.Name -notlike "Microsoft.WindowsStore"
            } | Sort-Object -Property Name
            
            if (-not $installedApps -or $installedApps.Count -eq 0) {
                Show-ProgressDialog -Status "No removable apps found" -PercentComplete 100
                Write-Host "No removable Windows apps found" -ForegroundColor Yellow
                [System.Windows.Forms.MessageBox]::Show(
                    "No removable Windows apps found on this system.",
                    'Remove Apps',
                    'OK',
                    'Information'
                )
                return
            }
            
            # Create selection dialog
            Show-ProgressDialog -Status "Building app selection dialog..." -Indeterminate

            $workArea = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea
            $dialogWidth = [Math]::Min(920, [Math]::Max(760, [int]($workArea.Width * 0.72)))
            $dialogHeight = [Math]::Min(860, [Math]::Max(680, [int]($workArea.Height * 0.82)))
            
            $selectionForm = New-Object System.Windows.Forms.Form
            $selectionForm.Text = "Select Apps to Remove"
            $selectionForm.Size = New-Object System.Drawing.Size($dialogWidth, $dialogHeight)
            $selectionForm.StartPosition = "CenterScreen"
            $selectionForm.FormBorderStyle = "Sizable"
            $selectionForm.MaximizeBox = $true
            $selectionForm.MinimizeBox = $false
            $selectionForm.Font = New-Object System.Drawing.Font("Segoe UI", 9)
            $selectionForm.TopMost = $true
            $selectionForm.MinimumSize = New-Object System.Drawing.Size(760, 680)
            $selectionForm.AutoScaleMode = [System.Windows.Forms.AutoScaleMode]::Dpi
            
            # Header label
            $headerLabel = New-Object System.Windows.Forms.Label
            $headerLabel.Location = New-Object System.Drawing.Point(10, 10)
            $headerLabel.Size = New-Object System.Drawing.Size(($selectionForm.ClientSize.Width - 20), 40)
            $headerLabel.Text = "Select Microsoft apps to remove from this profile. Core Windows shell and security components are excluded from this list for safety."
            $headerLabel.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
            $headerLabel.ForeColor = [System.Drawing.Color]::DarkRed
            $headerLabel.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right
            $selectionForm.Controls.Add($headerLabel)
            
            # Select All / Deselect All buttons
            $selectAllBtn = New-Object System.Windows.Forms.Button
            $selectAllBtn.Location = New-Object System.Drawing.Point(10, 55)
            $selectAllBtn.Size = New-Object System.Drawing.Size(100, 30)
            $selectAllBtn.Text = "Select All"
            $selectionForm.Controls.Add($selectAllBtn)
            
            $deselectAllBtn = New-Object System.Windows.Forms.Button
            $deselectAllBtn.Location = New-Object System.Drawing.Point(120, 55)
            $deselectAllBtn.Size = New-Object System.Drawing.Size(100, 30)
            $deselectAllBtn.Text = "Deselect All"
            $selectionForm.Controls.Add($deselectAllBtn)

            $optimizedBtn = New-Object System.Windows.Forms.Button
            $optimizedBtn.Location = New-Object System.Drawing.Point(230, 55)
            $optimizedBtn.Size = New-Object System.Drawing.Size(120, 30)
            $optimizedBtn.Text = "Recommended Debloat"
            $selectionForm.Controls.Add($optimizedBtn)
            
            # Search box
            $searchLabel = New-Object System.Windows.Forms.Label
            $searchLabel.Location = New-Object System.Drawing.Point(450, 60)
            $searchLabel.Size = New-Object System.Drawing.Size(50, 20)
            $searchLabel.Text = "Search:"
            $selectionForm.Controls.Add($searchLabel)
            
            $searchBox = New-Object System.Windows.Forms.TextBox
            $searchBox.Location = New-Object System.Drawing.Point(500, 57)
            $searchBox.Size = New-Object System.Drawing.Size(180, 25)
            $searchBox.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Right
            $selectionForm.Controls.Add($searchBox)

            $coreAppxLegend = New-Object System.Windows.Forms.Label
            $coreAppxLegend.Location = New-Object System.Drawing.Point(360, 60)
            $coreAppxLegend.Size = New-Object System.Drawing.Size(220, 20)
            $coreAppxLegend.Text = "[CORE APPX - USE CAUTION]"
            $coreAppxLegend.ForeColor = [System.Drawing.Color]::FromArgb(185, 28, 28)
            $coreAppxLegend.Font = New-Object System.Drawing.Font("Segoe UI", 8.5, [System.Drawing.FontStyle]::Bold)
            $coreAppxLegend.TextAlign = [System.Drawing.ContentAlignment]::MiddleRight
            $coreAppxLegend.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Right
            $selectionForm.Controls.Add($coreAppxLegend)
            
            # CheckedListBox for apps
            $checkedListBox = New-Object System.Windows.Forms.CheckedListBox
            $checkedListBox.Location = New-Object System.Drawing.Point(10, 95)
            $checkedListBox.Size = New-Object System.Drawing.Size(($selectionForm.ClientSize.Width - 20), ($selectionForm.ClientSize.Height - 190))
            $checkedListBox.CheckOnClick = $true
            $checkedListBox.HorizontalScrollbar = $true
            $checkedListBox.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right
            $selectionForm.Controls.Add($checkedListBox)

            $coreWarningPatterns = @(
                "MicrosoftWindows.Client.CBS",
                "Windows.CBSPreview",
                "MicrosoftWindows.Client.Core",
                "Microsoft.Windows.ShellExperienceHost",
                "Microsoft.Windows.StartMenuExperienceHost",
                "MicrosoftWindows.Client.OOBE",
                "MicrosoftWindows.Client.Photon",
                "MicrosoftWindows.Client.CoreAI"
            )

            function Test-CoreAppxCandidate {
                param(
                    [string]$AppName,
                    [string]$PackageFamilyName
                )

                foreach ($pattern in $coreWarningPatterns) {
                    if ($AppName -like "$pattern*" -or $PackageFamilyName -like "$pattern*") {
                        return $true
                    }
                }

                return $false
            }
            
            # Add apps to the list
            $allApps = @()
            foreach ($app in $installedApps) {
                $isCoreWarning = Test-CoreAppxCandidate -AppName $app.Name -PackageFamilyName $app.PackageFamilyName
                $baseDisplay = "$($app.Name) - v$($app.Version)"
                $displayText = if ($isCoreWarning) {
                    "$baseDisplay    [CORE APPX - USE CAUTION]"
                } else {
                    $baseDisplay
                }

                $appInfo = @{
                    DisplayText = $displayText
                    App = $app
                    IsCoreWarning = $isCoreWarning
                }
                $allApps += $appInfo
                [void]$checkedListBox.Items.Add($appInfo.DisplayText, $false)  # Unchecked by default for safety
            }

            $optimizedAppPatterns = @(
                'Microsoft.Bing*'
                'Microsoft.GetHelp'
                'Microsoft.Getstarted'
                'Microsoft.MicrosoftOfficeHub'
                'Microsoft.MicrosoftTeams'
                'Microsoft.People'
                'Microsoft.PowerAutomateDesktop'
                'Microsoft.SkypeApp'
                'Microsoft.Todos'
                'Microsoft.ZuneMusic'
                'Microsoft.ZuneVideo'
                'Microsoft.WindowsMaps'
                'Microsoft.WindowsFeedbackHub'
                'Microsoft.Wallet'
                'Microsoft.MixedReality.Portal'
                'Microsoft.GamingApp'
                'Microsoft.Xbox*'
                'Microsoft.YourPhone'
                'Microsoft.PowerAutomateDesktop'
                'Microsoft.Windows.DevHome*'
                'Microsoft.MicrosoftSolitaireCollection'
                'Microsoft.OutlookForWindows'
                'Microsoft.Windows.CallingShellApp'
                'Microsoft.PeopleExperienceHost'
                'Microsoft.BingSearch'
                'Clipchamp.Clipchamp'
                'MicrosoftTeams'
                'MicrosoftCorporationII.QuickAssist'
                'MSTeams'
                'Microsoft.549981C3F5F10'
            )

            function Test-OptimizedRemovalCandidate {
                param([string]$AppName)

                foreach ($pattern in $optimizedAppPatterns) {
                    if ($AppName -like $pattern) {
                        return $true
                    }
                }

                return $false
            }
            
            # Select All button click event
            $selectAllBtn.Add_Click({
                for ($i = 0; $i -lt $checkedListBox.Items.Count; $i++) {
                    $checkedListBox.SetItemChecked($i, $true)
                }
            })
            
            # Deselect All button click event
            $deselectAllBtn.Add_Click({
                for ($i = 0; $i -lt $checkedListBox.Items.Count; $i++) {
                    $checkedListBox.SetItemChecked($i, $false)
                }
            })

            # Optimised button click event: selects only known non-core consumer apps.
            $optimizedBtn.Add_Click({
                for ($i = 0; $i -lt $checkedListBox.Items.Count; $i++) {
                    $displayText = [string]$checkedListBox.Items[$i]
                    $appInfo = $allApps | Where-Object { $_.DisplayText -eq $displayText } | Select-Object -First 1

                    if ($appInfo) {
                        $shouldSelect = Test-OptimizedRemovalCandidate -AppName $appInfo.App.Name
                        $checkedListBox.SetItemChecked($i, $shouldSelect)
                    } else {
                        $checkedListBox.SetItemChecked($i, $false)
                    }
                }
            })
            
            # Search box text changed event
            $searchBox.Add_TextChanged({
                $searchText = $searchBox.Text.ToLower()
                $checkedListBox.Items.Clear()
                
                foreach ($appInfo in $allApps) {
                    if ([string]::IsNullOrWhiteSpace($searchText) -or $appInfo.DisplayText.ToLower().Contains($searchText)) {
                        [void]$checkedListBox.Items.Add($appInfo.DisplayText, $false)
                    }
                }
            })
            
            # Info label
            $infoLabel = New-Object System.Windows.Forms.Label
            $infoLabel.Location = New-Object System.Drawing.Point(10, ($selectionForm.ClientSize.Height - 95))
            $infoLabel.Size = New-Object System.Drawing.Size(($selectionForm.ClientSize.Width - 20), 20)
            $infoLabel.Text = "Found $($installedApps.Count) removable app packages on this device"
            $infoLabel.ForeColor = [System.Drawing.Color]::Gray
            $infoLabel.Anchor = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right
            $selectionForm.Controls.Add($infoLabel)
            
            # Warning label
            $warningLabel = New-Object System.Windows.Forms.Label
            $warningLabel.Location = New-Object System.Drawing.Point(10, ($selectionForm.ClientSize.Height - 75))
            $warningLabel.Size = New-Object System.Drawing.Size(($selectionForm.ClientSize.Width - 20), 20)
            $warningLabel.Text = "WARNING: [CORE APPX - USE CAUTION] entries may affect shell features. Removal is still allowed and can be restored later."
            $warningLabel.ForeColor = [System.Drawing.Color]::OrangeRed
            $warningLabel.Font = New-Object System.Drawing.Font("Segoe UI", 8, [System.Drawing.FontStyle]::Bold)
            $warningLabel.Anchor = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right
            $selectionForm.Controls.Add($warningLabel)
            
            # Remove button
            $removeBtn = New-Object System.Windows.Forms.Button
            $removeBtn.Location = New-Object System.Drawing.Point(($selectionForm.ClientSize.Width - 210), ($selectionForm.ClientSize.Height - 40))
            $removeBtn.Size = New-Object System.Drawing.Size(100, 35)
            $removeBtn.Text = "Remove"
            $removeBtn.BackColor = [System.Drawing.Color]::IndianRed
            $removeBtn.ForeColor = [System.Drawing.Color]::White
            $removeBtn.DialogResult = [System.Windows.Forms.DialogResult]::OK
            $removeBtn.Anchor = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Right
            $selectionForm.Controls.Add($removeBtn)
            $selectionForm.AcceptButton = $removeBtn
            
            # Cancel button
            $cancelBtn = New-Object System.Windows.Forms.Button
            $cancelBtn.Location = New-Object System.Drawing.Point(($selectionForm.ClientSize.Width - 100), ($selectionForm.ClientSize.Height - 40))
            $cancelBtn.Size = New-Object System.Drawing.Size(100, 35)
            $cancelBtn.Text = "Cancel"
            $cancelBtn.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
            $cancelBtn.Anchor = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Right
            $selectionForm.Controls.Add($cancelBtn)
            $selectionForm.CancelButton = $cancelBtn

            $selectionForm.Add_Resize({
                $searchLabel.Location = New-Object System.Drawing.Point(($selectionForm.ClientSize.Width - 240), 60)
                $searchBox.Location = New-Object System.Drawing.Point(($selectionForm.ClientSize.Width - 180), 57)
                $coreAppxLegend.Location = New-Object System.Drawing.Point(($selectionForm.ClientSize.Width - 420), 60)
                $coreAppxLegend.Size = New-Object System.Drawing.Size(220, 20)
            })
            
            # Show the selection dialog (modal dialog will be on top)
            $dialogResult = $selectionForm.ShowDialog()
            
            if ($dialogResult -ne [System.Windows.Forms.DialogResult]::OK) {
                Show-ProgressDialog -Status "App removal cancelled by user" -PercentComplete 0
                Write-Host "App removal cancelled by user" -ForegroundColor Yellow
                Start-Sleep -Seconds 2
                return
            }
            
            # Get selected apps
            $selectedApps = @()
            for ($i = 0; $i -lt $checkedListBox.Items.Count; $i++) {
                if ($checkedListBox.GetItemChecked($i)) {
                    $displayText = $checkedListBox.Items[$i]
                    $appInfo = $allApps | Where-Object { $_.DisplayText -eq $displayText }
                    if ($appInfo) {
                        $selectedApps += $appInfo.App
                    }
                }
            }
            
            if ($selectedApps.Count -eq 0) {
                Show-ProgressDialog -Status "No apps selected for removal" -PercentComplete 0
                Write-Host "No apps selected for removal" -ForegroundColor Yellow
                Start-Sleep -Seconds 2
                return
            }
            
            # Confirm removal
            $confirmResult = [System.Windows.Forms.MessageBox]::Show(
                "You are about to remove $($selectedApps.Count) selected apps from the current Windows profile.`n`nThis action is intended for debloating and can be reversed later via 'Reinstall Default Apps'.`n`nDo you want to continue?",
                'Confirm App Removal',
                'YesNo',
                'Warning'
            )
            
            if ($confirmResult -ne [System.Windows.Forms.DialogResult]::Yes) {
                Show-ProgressDialog -Status "App removal cancelled" -PercentComplete 0
                Write-Host "App removal cancelled" -ForegroundColor Yellow
                Start-Sleep -Seconds 2
                return
            }
            
            # Remove selected apps
            $totalApps = $selectedApps.Count
            $processedApps = 0
            $successCount = 0
            $failedCount = 0

            function Restart-ExplorerIfMissing {
                $explorerProcess = Get-Process -Name explorer -ErrorAction SilentlyContinue
                if (-not $explorerProcess) {
                    Write-Host "Explorer was not running; restarting shell..." -ForegroundColor Yellow
                    Start-Process explorer.exe
                    Start-Sleep -Seconds 2
                }
            }
            
            Write-Host "`nRemoving $totalApps selected apps..." -ForegroundColor Cyan
            
            foreach ($app in $selectedApps) {
                $processedApps++
                $percentComplete = [Math]::Round(($processedApps / $totalApps) * 100)
                
                try {
                    Show-ProgressDialog -Status "Removing: $($app.Name) ($processedApps/$totalApps)" -PercentComplete $percentComplete
                    
                    Remove-AppxPackage -Package $app.PackageFullName -ErrorAction Stop
                    
                    $successCount++
                    Write-Host "  [OK] Removed: $($app.Name)" -ForegroundColor Green
                } catch {
                    $failedCount++
                    Write-Host "  [FAIL] Failed to remove: $($app.Name) - $($_.Exception.Message)" -ForegroundColor Red
                }
            }
            
            Write-Host "`nRemoval Summary:" -ForegroundColor Cyan
            Write-Host "  Total processed: $totalApps" -ForegroundColor White
            Write-Host "  Successfully removed: $successCount" -ForegroundColor Green
            Write-Host "  Failed: $failedCount" -ForegroundColor Red

            Restart-ExplorerIfMissing
            
            Show-ProgressDialog -Status "Completed! $successCount removed, $failedCount failed" -PercentComplete 100
            Start-Sleep -Seconds 3
        }
    })
    
    WindowsUninstallOneDrive = [scriptblock]::Create("Invoke-ScriptWithProgress -ScriptPath '$($scriptPaths.OneDrive)' -DisplayName 'OneDrive Uninstaller'")
    
    WindowsCleaner = [scriptblock]::Create("Invoke-ScriptWithProgress -ScriptPath '$($scriptPaths.Cleaner)' -DisplayName 'Windows System Cleaner' -ArgumentList '--automated'")
    
    Defrag = [scriptblock]::Create("Invoke-ScriptWithProgress -ScriptPath '$($scriptPaths.Defrag)' -DisplayName 'Disk Defragmentation'")
    
    DiskCheck = [scriptblock]::Create("Invoke-ScriptWithProgress -ScriptPath '$($scriptPaths.DiskCheck)' -DisplayName 'Disk Check and Repair'")
    
    ReinstallApps = [scriptblock]::Create({ 
        Invoke-ScriptWithProgress -DisplayName "Reinstall Default Apps" -ScriptBlock {
            Show-ProgressDialog -Status "Scanning for available Windows apps..." -Indeterminate
            
            # Get currently installed apps for the current user
            Write-Host "Checking currently installed apps..." -ForegroundColor Cyan
            $installedApps = Get-AppxPackage -ErrorAction SilentlyContinue
            $installedAppNames = $installedApps | ForEach-Object { $_.Name }
            
            # Get all provisioned packages still in the system image
            Write-Host "Scanning provisioned packages in Windows image..." -ForegroundColor Cyan
            $provisionedPackages = Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue
            
            if (-not $provisionedPackages) {
                Show-ProgressDialog -Status "No provisioned packages found to reinstall" -PercentComplete 100
                Write-Host "No provisioned packages found in the Windows image" -ForegroundColor Yellow
                Write-Host "Apps may have been permanently removed by the cleanup script" -ForegroundColor Yellow
                Start-Sleep -Seconds 3
                return
            }
            
            # Find apps that are provisioned but NOT currently installed
            $appsToInstall = $provisionedPackages | Where-Object { 
                $provisionedName = $_.DisplayName
                # Check if this provisioned app is NOT in the installed apps list
                -not ($installedAppNames | Where-Object { $_ -eq $provisionedName })
            }
            
            if ($appsToInstall.Count -eq 0) {
                Show-ProgressDialog -Status "All provisioned apps are already installed" -PercentComplete 100
                Write-Host "All provisioned apps are already installed on this system" -ForegroundColor Green
                [System.Windows.Forms.MessageBox]::Show(
                    "All provisioned apps are already installed on this system.`n`nNo apps need to be reinstalled.",
                    'Reinstall Apps',
                    'OK',
                    'Information'
                )
                return
            }
            
            # Create selection dialog
            Show-ProgressDialog -Status "Building app selection dialog..." -Indeterminate
            
            $selectionForm = New-Object System.Windows.Forms.Form
            $selectionForm.Text = "Select Apps to Reinstall"
            $selectionForm.Size = New-Object System.Drawing.Size(600, 700)
            $selectionForm.StartPosition = "CenterScreen"
            $selectionForm.FormBorderStyle = "FixedDialog"
            $selectionForm.MaximizeBox = $false
            $selectionForm.MinimizeBox = $false
            $selectionForm.Font = New-Object System.Drawing.Font("Segoe UI", 9)
            $selectionForm.TopMost = $true
            
            # Header label
            $headerLabel = New-Object System.Windows.Forms.Label
            $headerLabel.Location = New-Object System.Drawing.Point(10, 10)
            $headerLabel.Size = New-Object System.Drawing.Size(560, 40)
            $headerLabel.Text = "Select the apps you want to restore. Items with local manifests install directly; others are restored through Microsoft Store where available."
            $headerLabel.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
            $selectionForm.Controls.Add($headerLabel)
            
            # Select All / Deselect All buttons
            $selectAllBtn = New-Object System.Windows.Forms.Button
            $selectAllBtn.Location = New-Object System.Drawing.Point(10, 55)
            $selectAllBtn.Size = New-Object System.Drawing.Size(100, 30)
            $selectAllBtn.Text = "Select All"
            $selectionForm.Controls.Add($selectAllBtn)
            
            $deselectAllBtn = New-Object System.Windows.Forms.Button
            $deselectAllBtn.Location = New-Object System.Drawing.Point(120, 55)
            $deselectAllBtn.Size = New-Object System.Drawing.Size(100, 30)
            $deselectAllBtn.Text = "Deselect All"
            $selectionForm.Controls.Add($deselectAllBtn)
            
            # CheckedListBox for apps
            $checkedListBox = New-Object System.Windows.Forms.CheckedListBox
            $checkedListBox.Location = New-Object System.Drawing.Point(10, 95)
            $checkedListBox.Size = New-Object System.Drawing.Size(560, 480)
            $checkedListBox.CheckOnClick = $true
            $selectionForm.Controls.Add($checkedListBox)
            
            # Add apps to the list (sorted alphabetically)
            $sortedApps = $appsToInstall | Sort-Object -Property DisplayName
            foreach ($app in $sortedApps) {
                $manifestPath = "$($app.InstallLocation)\AppxManifest.xml"
                $hasManifest = Test-Path $manifestPath
                $displayText = if ($hasManifest) {
                    "$($app.DisplayName) [Local]"
                } else {
                    "$($app.DisplayName) [Microsoft Store]"
                }
                [void]$checkedListBox.Items.Add($displayText, $true)  # Check all by default
            }
            
            # Select All button click event
            $selectAllBtn.Add_Click({
                for ($i = 0; $i -lt $checkedListBox.Items.Count; $i++) {
                    $checkedListBox.SetItemChecked($i, $true)
                }
            })
            
            # Deselect All button click event
            $deselectAllBtn.Add_Click({
                for ($i = 0; $i -lt $checkedListBox.Items.Count; $i++) {
                    $checkedListBox.SetItemChecked($i, $false)
                }
            })
            
            # Info label
            $infoLabel = New-Object System.Windows.Forms.Label
            $infoLabel.Location = New-Object System.Drawing.Point(10, 585)
            $infoLabel.Size = New-Object System.Drawing.Size(560, 20)
            $infoLabel.Text = "Found $($appsToInstall.Count) app packages available for restoration"
            $infoLabel.ForeColor = [System.Drawing.Color]::Gray
            $selectionForm.Controls.Add($infoLabel)
            
            # Install button
            $installBtn = New-Object System.Windows.Forms.Button
            $installBtn.Location = New-Object System.Drawing.Point(370, 615)
            $installBtn.Size = New-Object System.Drawing.Size(100, 35)
            $installBtn.Text = "Install"
            $installBtn.DialogResult = [System.Windows.Forms.DialogResult]::OK
            $selectionForm.Controls.Add($installBtn)
            $selectionForm.AcceptButton = $installBtn
            
            # Cancel button
            $cancelBtn = New-Object System.Windows.Forms.Button
            $cancelBtn.Location = New-Object System.Drawing.Point(480, 615)
            $cancelBtn.Size = New-Object System.Drawing.Size(100, 35)
            $cancelBtn.Text = "Cancel"
            $cancelBtn.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
            $selectionForm.Controls.Add($cancelBtn)
            $selectionForm.CancelButton = $cancelBtn
            
            # Show the selection dialog (modal dialog will be on top)
            $dialogResult = $selectionForm.ShowDialog()
            
            if ($dialogResult -ne [System.Windows.Forms.DialogResult]::OK) {
                Show-ProgressDialog -Status "Installation cancelled by user" -PercentComplete 0
                Write-Host "Installation cancelled by user" -ForegroundColor Yellow
                Start-Sleep -Seconds 2
                return
            }
            
            # Get selected apps
            $selectedApps = @()
            for ($i = 0; $i -lt $checkedListBox.Items.Count; $i++) {
                if ($checkedListBox.GetItemChecked($i)) {
                    $selectedApps += $sortedApps[$i]
                }
            }
            
            if ($selectedApps.Count -eq 0) {
                Show-ProgressDialog -Status "No apps selected for installation" -PercentComplete 0
                Write-Host "No apps selected for installation" -ForegroundColor Yellow
                Start-Sleep -Seconds 2
                return
            }
            
            # Process selected apps
            $totalApps = $selectedApps.Count
            $processedApps = 0
            $successCount = 0
            $failedCount = 0
            $skippedForStore = 0
            $storeApps = @()
            
            Write-Host "`nInstalling $totalApps selected apps..." -ForegroundColor Cyan
            Write-Host "Total provisioned packages available: $($provisionedPackages.Count)" -ForegroundColor Gray
            
            # Check if winget is available for Store installations
            $wingetAvailable = $null -ne (Get-Command winget -ErrorAction SilentlyContinue)
            if ($wingetAvailable) {
                Write-Host "Windows Package Manager (winget) detected - will use for apps without manifests" -ForegroundColor Green
            }
            
            if ($totalApps -gt 0) {
                foreach ($package in $selectedApps) {
                    $processedApps++
                    $percentComplete = [Math]::Round(($processedApps / $totalApps) * 100)
                    
                    # Check if manifest file exists
                    $manifestPath = "$($package.InstallLocation)\AppxManifest.xml"
                    if (-not (Test-Path $manifestPath)) {
                        # Save for Store installation attempt
                        $storeApps += $package
                        $skippedForStore++
                        Write-Host "  [STORE] $($package.DisplayName) - Will attempt Store installation" -ForegroundColor Yellow
                        continue
                    }
                    
                    try {
                        Show-ProgressDialog -Status "Installing: $($package.DisplayName) ($processedApps/$totalApps)" -PercentComplete $percentComplete
                        
                        # Install the app for the current user from the provisioned package
                        Add-AppxPackage -Register $manifestPath -DisableDevelopmentMode -ErrorAction Stop
                        
                        $successCount++
                        Write-Host "  [OK] Installed: $($package.DisplayName)" -ForegroundColor Green
                    } catch {
                        $failedCount++
                        Write-Host "  [FAIL] $($package.DisplayName) - $($_.Exception.Message)" -ForegroundColor Red
                    }
                }
                
                # Attempt to install apps via Microsoft Store using winget
                if ($storeApps.Count -gt 0 -and $wingetAvailable) {
                    Write-Host "`n--- Attempting Microsoft Store Installation ---" -ForegroundColor Cyan
                    $storeSuccess = 0
                    $storeFailed = 0
                    
                    # Map of package names to Microsoft Store IDs
                    $storeIdMap = @{
                        "Microsoft.WindowsCalculator" = "9WZDNCRFHVN5"
                        "Microsoft.Windows.Photos" = "9WZDNCRFJBH4"
                        "Microsoft.WindowsCamera" = "9WZDNCRFJBBG"
                        "Microsoft.WindowsAlarms" = "9WZDNCRFJ3PR"
                        "Microsoft.WindowsMaps" = "9WZDNCRDTBVB"
                        "Microsoft.WindowsSoundRecorder" = "9WZDNCRFHWKN"
                        "Microsoft.MicrosoftStickyNotes" = "9NBLGGH4QGHW"
                        "Microsoft.People" = "9NBLGGH10PG8"
                        "Microsoft.MicrosoftSolitaireCollection" = "9WZDNCRFHWD2"
                        "Microsoft.BingWeather" = "9WZDNCRFJ3Q2"
                        "Microsoft.BingNews" = "9WZDNCRFHVFW"
                        "Microsoft.MicrosoftOfficeHub" = "9WZDNCRD29V9"
                        "Microsoft.Getstarted" = "9WZDNCRDTBJJ"
                        "microsoft.windowscommunicationsapps" = "9WZDNCRFHVQM"
                        "Microsoft.ZuneMusic" = "9WZDNCRFJ3PT"
                        "Microsoft.ZuneVideo" = "9WZDNCRFJ3P2"
                        "Microsoft.YourPhone" = "9NMPJ99VJBWV"
                        "Microsoft.WindowsFeedbackHub" = "9NBLGGH4R32N"
                        "Microsoft.GetHelp" = "9PKDZBMV1H3T"
                        "Microsoft.Xbox.TCUI" = "9NZKPSTSNW4P"
                        "Microsoft.XboxGameOverlay" = "9NZKPSTSNW4P"
                        "Microsoft.XboxGamingOverlay" = "9NZKPSTSNW4P"
                        "Microsoft.XboxIdentityProvider" = "9WZDNCRD1HKW"
                        "Microsoft.GamingApp" = "9NZKPSTSNW4P"
                        "Clipchamp.Clipchamp" = "9P1J8S7CCWWT"
                    }
                    
                    foreach ($package in $storeApps) {
                        $appName = $package.DisplayName
                        $storeId = $storeIdMap[$appName]
                        
                        if (-not $storeId) {
                            $storeFailed++
                            Write-Host "  [SKIP] $appName - No Store ID mapping available" -ForegroundColor Gray
                            continue
                        }
                        
                        try {
                            Show-ProgressDialog -Status "Installing from Store: $appName" -Indeterminate
                            Write-Host "  [STORE] Installing $appName (ID: $storeId)..." -ForegroundColor Cyan
                            
                            # Install using winget with the Microsoft Store ID
                            $null = winget install --id $storeId --source msstore --accept-package-agreements --accept-source-agreements --silent 2>&1
                            
                            if ($LASTEXITCODE -eq 0) {
                                $storeSuccess++
                                $successCount++
                                Write-Host "  [OK] Installed from Store: $appName" -ForegroundColor Green
                            } else {
                                $storeFailed++
                                Write-Host "  [SKIP] Store installation issue: $appName" -ForegroundColor Gray
                            }
                        } catch {
                            $storeFailed++
                            Write-Host "  [SKIP] Store installation failed: $appName" -ForegroundColor Gray
                        }
                    }
                    
                    Write-Host "`nStore Installation Results:" -ForegroundColor Cyan
                    Write-Host "  Successfully installed from Store: $storeSuccess" -ForegroundColor Green
                    Write-Host "  Not available/Failed: $storeFailed" -ForegroundColor Gray
                }
                
                Write-Host "`n=== Final Summary ===" -ForegroundColor Cyan
                Write-Host "  Apps available to reinstall: $totalApps" -ForegroundColor White
                Write-Host "  Successfully installed (total): $successCount" -ForegroundColor Green
                Write-Host "  Failed: $failedCount" -ForegroundColor Red
                Write-Host "  Attempted via Store: $skippedForStore" -ForegroundColor Yellow
                
                if ($successCount -gt 0) {
                    Write-Host "`nIMPORTANT: Restart your PC or sign out/in for apps to appear in Start Menu" -ForegroundColor Yellow
                }
                
                if (-not $wingetAvailable -and $skippedForStore -gt 0) {
                    Write-Host "`nNOTE: $skippedForStore apps need manifests. Install 'App Installer' from Microsoft Store to enable winget." -ForegroundColor Yellow
                }
                
                Show-ProgressDialog -Status "Completed! $successCount installed, $failedCount failed" -PercentComplete 100
            } else {
                Show-ProgressDialog -Status "All provisioned apps are already installed" -PercentComplete 100
                Write-Host "All provisioned apps are already installed on this system" -ForegroundColor Green
                Write-Host "No apps need to be reinstalled" -ForegroundColor Gray
            }
            
            Start-Sleep -Seconds 3
        }
    })
    
    DelProf = [scriptblock]::Create(@"
        Invoke-ScriptWithProgress -DisplayName 'Delete User Profiles' -ScriptBlock {
            Show-ProgressDialog -Status 'Preparing DelProf2 utility...' -Indeterminate
            
            if (Test-Path '$($scriptPaths.Delprof2)') {
                Show-ProgressDialog -Status 'Running DelProf2 user profile cleanup...' -Indeterminate
                Start-Process -FilePath '$($scriptPaths.Delprof2)' -ArgumentList '/u', '/q' -Wait -NoNewWindow
                Show-ProgressDialog -Status 'User profile cleanup completed!' -PercentComplete 100
            } else {
                Show-ProgressDialog -Status 'DelProf2.exe not found in Scripts folder' -PercentComplete 0
                Write-Warning 'DelProf2.exe not found in Scripts folder'
            }
            
            Start-Sleep -Seconds 2
        }
"@)
    
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
    
    WindowsTroubleshooting = [scriptblock]::Create("Invoke-ScriptWithProgress -ScriptPath '$($scriptPaths.Troubleshooting)' -DisplayName 'Windows Troubleshooting'")

    UserCleaner = [scriptblock]::Create("Invoke-ScriptWithProgress -ScriptPath '$($scriptPaths.UserCleaner)' -DisplayName 'Windows User Cleaner'")

    FixWindowsDefender = [scriptblock]::Create("Invoke-ScriptWithProgress -ScriptPath '$($scriptPaths.DefenderFix)' -DisplayName 'Fix Windows Defender'")

    CustomChanges = [scriptblock]::Create("Invoke-ScriptWithProgress -ScriptPath '$($scriptPaths.CustomChanges)' -DisplayName 'Custom Changes Panel'")

    ApplyAeroliteTheme = [scriptblock]::Create(@"
        if (Test-Path '$($scriptPaths.AeroliteTheme)') {
            Start-Process -FilePath '$($scriptPaths.AeroliteTheme)' | Out-Null
            Write-Host 'Aerolite theme launched. Apply prompt may appear in Windows Personalization.' -ForegroundColor Green
        } else {
            Write-Warning 'Aerolite theme file was not found in Scripts folder.'
        }
"@)
    
    VisualOptimisation = [scriptblock]::Create({
        $visualScriptPath = Join-Path $ScriptRoot "Scripts\VisualOptimisation.ps1"
        if (Test-Path $visualScriptPath) {
            & $visualScriptPath --automated
        } else {
            Write-Host "Visual Optimisation script not found: $visualScriptPath" -ForegroundColor Red
            [System.Windows.Forms.MessageBox]::Show(
                "Visual Optimisation script not found: $visualScriptPath",
                'Windows Maintenance - Error',
                'OK',
                'Error'
            )
        }
    })

    SystemOptimisation = [scriptblock]::Create({
        # Run the System Optimization script directly
        $scriptPath = $scriptPaths.SystemOptimisation
        if (Test-Path $scriptPath) {
            & $scriptPath
        } else {
            Write-Host "System Optimization script not found: $scriptPath" -ForegroundColor Red
            [System.Windows.Forms.MessageBox]::Show(
                "System Optimization script not found: $scriptPath",
                'Windows Maintenance - Error',
                'OK',
                'Error'
            )
        }
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
$UiPalette = @{
    FormBack = [System.Drawing.Color]::FromArgb(245, 248, 252)
    CardBack = [System.Drawing.Color]::White
    Accent = [System.Drawing.Color]::FromArgb(27, 92, 153)
    AccentSoft = [System.Drawing.Color]::FromArgb(230, 240, 250)
    TextPrimary = [System.Drawing.Color]::FromArgb(34, 42, 53)
    TextMuted = [System.Drawing.Color]::FromArgb(95, 105, 120)
    Border = [System.Drawing.Color]::FromArgb(211, 219, 228)
    Cleanup = [System.Drawing.Color]::FromArgb(231, 242, 255)
    Repair = [System.Drawing.Color]::FromArgb(231, 247, 237)
    Advanced = [System.Drawing.Color]::FromArgb(255, 245, 228)
    Special = [System.Drawing.Color]::FromArgb(237, 241, 249)
}

try {
    if ($DebugMode) { Write-DebugMessage "Creating main form" "INFO" }

    # Calculate optimal form size based on screen resolution
    $screen = [System.Windows.Forms.Screen]::PrimaryScreen
    $screenWidth = $screen.Bounds.Width
    $screenHeight = $screen.Bounds.Height

    # Responsive sizing with low-resolution safety. Auto-scroll handles overflow.
    $formWidth = [Math]::Min([Math]::Max(640, $screenWidth * 0.86), 920)
    $formHeight = [Math]::Min(860, [Math]::Max(680, ($screenHeight - 70)))

    # Calculate button width for 3 columns with symmetrical padding
    $buttonWidth = [Math]::Floor(($formWidth - 110) / 3)

    $Form = New-Object System.Windows.Forms.Form -Property @{
        Text = "Windows Maintenance Tool v2.0 - Windows $osVersion"
        Size = New-Object System.Drawing.Size($formWidth, $formHeight)
        StartPosition = 'CenterScreen'
        FormBorderStyle = 'Sizable'
        MaximizeBox = $true
        MinimizeBox = $true
        BackColor = $UiPalette.FormBack
        Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Regular)
        MinimumSize = New-Object System.Drawing.Size(640, 680)
        AutoScaleMode = [System.Windows.Forms.AutoScaleMode]::Dpi
    }

    Enable-DoubleBuffering -Control $Form
    $Form.Padding = New-Object System.Windows.Forms.Padding(0)
    $Form.AutoScroll = $true

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
    $iconPath = Join-Path $ScriptRoot "Assets\windowslogo.ico"
    if (Test-Path $iconPath) {
        $Form.Icon = [System.Drawing.Icon]::ExtractAssociatedIcon($iconPath)
        if ($DebugMode) { Write-DebugMessage "Icon loaded successfully" "INFO" }
    } else {
        if ($DebugMode) { Write-DebugMessage "Icon file not found: $iconPath" "WARN" }
    }
} catch {
    if ($DebugMode) { Write-DebugMessage "Could not load icon file: $($_.Exception.Message)" "WARN" }
}

# Header section with title and OS info
$headerPanel = New-Object System.Windows.Forms.Panel
$headerPanel.Size = New-Object System.Drawing.Size(($formWidth - 20), 60)
$headerPanel.Location = New-Object System.Drawing.Point(10, 10)
$headerPanel.BackColor = $UiPalette.Accent
$headerPanel.BorderStyle = 'FixedSingle'
$headerPanel.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right

$titleLabel = New-Object System.Windows.Forms.Label
$titleLabel.Text = "Windows Maintenance and Optimisation"
$titleLabel.Size = New-Object System.Drawing.Size(400, 25)
$titleLabel.Location = New-Object System.Drawing.Point(15, 10)
$titleLabel.Font = New-Object System.Drawing.Font("Segoe UI", 14, [System.Drawing.FontStyle]::Bold)
$titleLabel.ForeColor = [System.Drawing.Color]::White
$titleLabel.BackColor = [System.Drawing.Color]::Transparent

$osLabel = New-Object System.Windows.Forms.Label
$osLabel.Text = "Detected OS: Windows $osVersion"
$osLabel.Size = New-Object System.Drawing.Size(280, 20)
$osLabel.Location = New-Object System.Drawing.Point(15, 35)
$osLabel.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Regular)
$osLabel.ForeColor = [System.Drawing.Color]::FromArgb(220, 232, 244)
$osLabel.BackColor = [System.Drawing.Color]::Transparent

$subTitleLabel = New-Object System.Windows.Forms.Label
$subTitleLabel.Text = "Structured maintenance focused on performance, privacy, and safe debloating while preserving core Windows experience."
$subTitleLabel.Size = New-Object System.Drawing.Size(430, 20)
$subTitleLabel.Location = New-Object System.Drawing.Point(($formWidth - 460), 20)
$subTitleLabel.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Regular)
$subTitleLabel.ForeColor = [System.Drawing.Color]::FromArgb(220, 232, 244)
$subTitleLabel.TextAlign = [System.Drawing.ContentAlignment]::MiddleRight
$subTitleLabel.BackColor = [System.Drawing.Color]::Transparent
$subTitleLabel.AutoEllipsis = $true
$subTitleLabel.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Right

$headerPanel.Controls.AddRange(@($titleLabel, $osLabel, $subTitleLabel))
$Form.Controls.Add($headerPanel)

$mainActionButtons = New-Object System.Collections.ArrayList

# Enhanced button creation with progress integration and modern styling
function Add-MaintenanceButton {
    param (
        [string]$Text,
        [System.Drawing.Point]$Location,
        [scriptblock]$Action,
        [string]$Category = "Default",
        [string]$Description = "",
        [int]$Column = 0
    )

    $refreshUi = {
        param([System.Windows.Forms.Control]$Control = $null)

        try {
            if ($Control -and -not $Control.IsDisposed) {
                $Control.Refresh()
            }

            [System.Windows.Forms.Application]::DoEvents()
        } catch {
            # Ignore UI refresh exceptions in button handlers.
        }
    }
    
    # Calculate button width based on form size (3 buttons per row with symmetrical padding)
    # $buttonWidth is now calculated globally above
    
    $dynamicButtonHeight = [Math]::Max(42, [int]([Math]::Ceiling($Form.Font.GetHeight() + 24)))

    $Button = New-Object System.Windows.Forms.Button -Property @{
        Text = $Text
        Location = $Location
        Size = New-Object System.Drawing.Size($buttonWidth, $dynamicButtonHeight)
        Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Regular)
        FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
        Cursor = [System.Windows.Forms.Cursors]::Hand
        TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
        Padding = New-Object System.Windows.Forms.Padding(10, 0, 0, 0)
        ForeColor = $UiPalette.TextPrimary
    }
    $Button.AutoEllipsis = $true
    $Button.FlatAppearance.BorderSize = 1
    
    # Category-based color coding
    switch ($Category) {
        "Cleanup" { 
            $Button.BackColor = $UiPalette.Cleanup
            $Button.FlatAppearance.BorderColor = $UiPalette.Border
        }
        "Repair" { 
            $Button.BackColor = $UiPalette.Repair
            $Button.FlatAppearance.BorderColor = $UiPalette.Border
        }
        "Advanced" { 
            $Button.BackColor = $UiPalette.Advanced
            $Button.FlatAppearance.BorderColor = $UiPalette.Border
        }
        "Special" { 
            $Button.BackColor = $UiPalette.Special
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
    
    # Add click handler based on button type
    $buttonText = $Text
    $buttonAction = $Action
    if ($Text -eq "Performance Optimization") {
        # Special handler for System Optimization that shows a form
        $Button.Add_Click({
            try {
                Write-Host "Starting System Optimization..." -ForegroundColor Cyan
                # Hide the main form temporarily to avoid modal dialog conflicts
                $Form.Visible = $false
                & $refreshUi -Control $Form
                # Execute the action directly (shows modal form)
                & $buttonAction
                # Show the main form again
                $Form.Visible = $true
                $Form.Activate()
                & $refreshUi -Control $Form
            } catch {
                Write-Host "Error in System Optimization: $_" -ForegroundColor Red
                [System.Windows.Forms.MessageBox]::Show(
                    "Error during System Optimization: $($_.Exception.Message)",
                    'Windows Maintenance - Error',
                    'OK',
                    'Error'
                )
                # Make sure main form is visible in case of error
                $Form.Visible = $true
                $Form.Activate()
            }
        }.GetNewClosure())
    } else {
        # Standard handler for other buttons
        $Button.Add_Click({
            try {
                Write-Host "Starting maintenance task: $buttonText" -ForegroundColor Cyan
                
                # Disable all buttons during operation
                foreach ($control in $Form.Controls) {
                    if ($control -is [System.Windows.Forms.Button]) {
                        $control.Enabled = $false
                    }
                }
                & $refreshUi -Control $Form
                
                # Execute the action
                $result = & $buttonAction
                
                # Show completion message only for warnings
                if ($result -eq $false) {
                    [System.Windows.Forms.MessageBox]::Show(
                        "$buttonText completed with warnings. Check the console for details.",
                        'Windows Maintenance',
                        'OK',
                        'Warning'
                    )
                }
                
            } catch {
                Write-Host "Error in $buttonText`: $_" -ForegroundColor Red
                [System.Windows.Forms.MessageBox]::Show(
                    "Error during $buttonText`: $($_.Exception.Message)",
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
                & $refreshUi -Control $Form
                
                Write-Host "Maintenance task completed: $buttonText" -ForegroundColor Green
            }
        }.GetNewClosure())
    }
    
    # Add tooltip if description is provided
    if ($Description) {
        $tooltip = New-Object System.Windows.Forms.ToolTip
        $tooltip.SetToolTip($Button, $Description)
    }
    
    $Form.Controls.Add($Button)
    [void]$mainActionButtons.Add([pscustomobject]@{
        Button = $Button
        Column = $Column
    })
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
        ForeColor = $UiPalette.TextPrimary
        BackColor = [System.Drawing.Color]::Transparent
    }
    $Label.Tag = 'SectionLabel'
    $Label.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right
    
    $Form.Controls.Add($Label)
    return $Label
}

# Instructions label
$instructionsLabel = New-Object System.Windows.Forms.Label
$instructionsLabel.Text = "Run individual tools for targeted fixes, or use Complete PC Setup to follow a guided checklist with clear impact notes before anything is applied."
$instructionsLabel.Size = New-Object System.Drawing.Size(($formWidth - 40), 32)
$instructionsLabel.Location = New-Object System.Drawing.Point(20, 80)
$instructionsLabel.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Italic)
$instructionsLabel.ForeColor = $UiPalette.TextMuted
$instructionsLabel.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
$instructionsLabel.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right
$instructionsLabel.AutoEllipsis = $true
$Form.Controls.Add($instructionsLabel)

$summaryPanel = New-Object System.Windows.Forms.Panel
$summaryPanel.Size = New-Object System.Drawing.Size(($formWidth - 40), 48)
$summaryPanel.Location = New-Object System.Drawing.Point(20, 114)
$summaryPanel.BackColor = $UiPalette.CardBack
$summaryPanel.BorderStyle = 'FixedSingle'
$summaryPanel.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right

$summaryLabel = New-Object System.Windows.Forms.Label
$summaryLabel.Text = "Recommended defaults are conservative: improve responsiveness, reduce background activity and telemetry, and remove consumer bloat while keeping core Windows shell features intact."
$summaryLabel.Size = New-Object System.Drawing.Size(($formWidth - 60), 30)
$summaryLabel.Location = New-Object System.Drawing.Point(10, 9)
$summaryLabel.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$summaryLabel.ForeColor = $UiPalette.TextMuted
$summaryLabel.BackColor = [System.Drawing.Color]::Transparent
$summaryLabel.AutoEllipsis = $true
$summaryLabel.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right

$summaryPanel.Controls.Add($summaryLabel)
$Form.Controls.Add($summaryPanel)

# Add sections with enhanced spacing and organization
$currentY = 175

# Calculate button positions for 3-column layout with symmetrical padding
$leftButtonX = 30
$middleButtonX = $leftButtonX + $buttonWidth + 20
$rightButtonX = $middleButtonX + $buttonWidth + 20

# Quick Actions Section
Add-SectionLabel "Quick Optimisations" (New-Object System.Drawing.Point(30, $currentY))
$currentY += 30

Add-MaintenanceButton "Visual Optimisation" (New-Object System.Drawing.Point($leftButtonX, $currentY)) $Scripts.VisualOptimisation "Performance" "Apply all visual performance changes in one pass: disable animations, DWM effects, and theme overhead for responsiveness." -Column 0
$currentY += 50

# System Cleanup Section
Add-SectionLabel "System Cleanup and App Management" (New-Object System.Drawing.Point(30, $currentY))
$currentY += 30

Add-MaintenanceButton "Fresh Install Cleanup" (New-Object System.Drawing.Point($leftButtonX, $currentY)) $Scripts.WindowsInstallCleanup "Cleanup" "Open a selectable debloat list of preinstalled Microsoft apps while excluding core shell components for safety." -Column 0
Add-MaintenanceButton "Reinstall Default Apps" (New-Object System.Drawing.Point($middleButtonX, $currentY)) $Scripts.ReinstallApps "Cleanup" "Restore previously removed inbox apps from local manifests or Microsoft Store mappings." -Column 1
Add-MaintenanceButton "Uninstall OneDrive" (New-Object System.Drawing.Point($rightButtonX, $currentY)) $Scripts.WindowsUninstallOneDrive "Cleanup" "Remove OneDrive client integration and related background processes when cloud sync is not required." -Column 2
$currentY += 50

Add-MaintenanceButton "Delete User Profiles" (New-Object System.Drawing.Point($leftButtonX, $currentY)) $Scripts.DelProf "Cleanup" "Delete stale local profiles to recover storage; use only when you are certain those profiles are no longer needed." -Column 0
$currentY += 70

# System Repair Section
Add-SectionLabel "System Health and Repair" (New-Object System.Drawing.Point(30, $currentY))
$currentY += 30

Add-MaintenanceButton "DISM Health Check" (New-Object System.Drawing.Point($leftButtonX, $currentY)) $Scripts.DISMRestore "Repair" "Validate and repair component store health when Windows servicing or updates are unreliable." -Column 0
Add-MaintenanceButton "System File Check" (New-Object System.Drawing.Point($middleButtonX, $currentY)) $Scripts.SFCRepair "Repair" "Scan protected system files and restore known-good versions when corruption is detected." -Column 1
$currentY += 70

# Disk Maintenance Section  
Add-SectionLabel "Disk Maintenance and Optimization" (New-Object System.Drawing.Point(30, $currentY))
$currentY += 30

Add-MaintenanceButton "System Cleaner" (New-Object System.Drawing.Point($leftButtonX, $currentY)) $Scripts.WindowsCleaner "Repair" "Remove temporary files, update residue, and routine cache clutter to recover space and reduce churn." -Column 0
Add-MaintenanceButton "Disk Check and Repair" (New-Object System.Drawing.Point($middleButtonX, $currentY)) $Scripts.DiskCheck "Repair" "Run file-system integrity checks and schedule corrective actions where disk issues are detected." -Column 1
Add-MaintenanceButton "Disk Defragmentation" (New-Object System.Drawing.Point($rightButtonX, $currentY)) $Scripts.Defrag "Repair" "Optimise storage layout for HDD systems; SSD-aware checks are included before actions are applied." -Column 2
$currentY += 70

# Advanced Options Section
Add-SectionLabel "Advanced System Tools" (New-Object System.Drawing.Point(30, $currentY))
$currentY += 30

Add-MaintenanceButton "System Troubleshooting" (New-Object System.Drawing.Point($leftButtonX, $currentY)) $Scripts.WindowsTroubleshooting "Advanced" "Run guided remediation for common networking, update, Store, and policy-related faults." -Column 0
Add-MaintenanceButton "Performance Optimization" (New-Object System.Drawing.Point($middleButtonX, $currentY)) $Scripts.SystemOptimisation "Advanced" "Open the dedicated optimisation panel with grouped privacy, performance, services, and recovery controls." -Column 1
$currentY += 70

# Special Operations Section
Add-SectionLabel "Automated Operations" (New-Object System.Drawing.Point(30, $currentY))
$currentY += 30

function Show-CompleteSetupPlanner {
    $plannerHeight = [Math]::Min(720, [Math]::Max(620, ($screenHeight - 90)))

    $plannerForm = New-Object System.Windows.Forms.Form -Property @{
        Text = 'Complete PC Setup Planner'
        Size = New-Object System.Drawing.Size(880, $plannerHeight)
        StartPosition = 'CenterParent'
        FormBorderStyle = 'Sizable'
        MaximizeBox = $true
        MinimizeBox = $false
        BackColor = $UiPalette.FormBack
        Font = New-Object System.Drawing.Font("Segoe UI", 9)
        MinimumSize = New-Object System.Drawing.Size(820, 650)
        AutoScaleMode = [System.Windows.Forms.AutoScaleMode]::Dpi
        TopMost = $true
    }
    Enable-DoubleBuffering -Control $plannerForm
    $plannerForm.AutoScroll = $true
    $plannerForm.AutoScrollMinSize = New-Object System.Drawing.Size(860, 700)

    $plannerHeader = New-Object System.Windows.Forms.Panel
    $plannerHeader.Size = New-Object System.Drawing.Size(860, 72)
    $plannerHeader.Location = New-Object System.Drawing.Point(10, 10)
    $plannerHeader.BackColor = $UiPalette.Accent
    $plannerHeader.BorderStyle = 'FixedSingle'
    $plannerHeader.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right

    $plannerTitle = New-Object System.Windows.Forms.Label
    $plannerTitle.Text = 'Complete PC Setup Planner'
    $plannerTitle.Location = New-Object System.Drawing.Point(16, 12)
    $plannerTitle.Size = New-Object System.Drawing.Size(320, 24)
    $plannerTitle.Font = New-Object System.Drawing.Font("Segoe UI", 14, [System.Drawing.FontStyle]::Bold)
    $plannerTitle.ForeColor = [System.Drawing.Color]::White
    $plannerTitle.BackColor = [System.Drawing.Color]::Transparent

    $plannerSubtitle = New-Object System.Windows.Forms.Label
    $plannerSubtitle.Text = 'Choose a preset, then adjust the checklist as needed. Task details and impact guidance are shown on the right so users can make informed choices before running.'
    $plannerSubtitle.Location = New-Object System.Drawing.Point(16, 40)
    $plannerSubtitle.Size = New-Object System.Drawing.Size(830, 18)
    $plannerSubtitle.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    $plannerSubtitle.ForeColor = [System.Drawing.Color]::FromArgb(220, 232, 244)
    $plannerSubtitle.BackColor = [System.Drawing.Color]::Transparent
    $plannerSubtitle.AutoEllipsis = $true
    $plannerSubtitle.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right

    $plannerHeader.Controls.AddRange(@($plannerTitle, $plannerSubtitle))
    $plannerForm.Controls.Add($plannerHeader)

    $taskDefinitions = @(
        @{ Id = 'WindowsInstallCleanup'; Name = 'Windows Install Cleanup'; Default = $true; Description = 'Runs the balanced junk-app cleanup and disables safe non-essential services. This is the main debloat step and keeps the Windows shell, Store, and core UX intact.'; Impact = 'Best for reducing preinstalled Microsoft consumer apps and background noise.' }
        @{ Id = 'ReinstallApps'; Name = 'Reinstall Default Apps'; Default = $false; Description = 'Opens the app restore selector to reinstall Microsoft provisioned apps that may have been removed earlier.'; Impact = 'Useful when the setup should end with missing inbox apps restored instead of removed.' }
        @{ Id = 'WindowsUninstallOneDrive'; Name = 'Uninstall OneDrive'; Default = $true; Description = 'Completely removes OneDrive integration and background processes. Leave this unchecked if the user relies on OneDrive sync.'; Impact = 'Frees background resources if cloud sync is not needed.' }
        @{ Id = 'WindowsCleaner'; Name = 'System Cleaner'; Default = $true; Description = 'Cleans temp files, caches, and routine system clutter. This is low risk and usually worth leaving on.'; Impact = 'Improves free space and removes temporary junk.' }
        @{ Id = 'UserCleaner'; Name = 'User Profile Temp Cleaner'; Default = $false; Description = 'Runs the legacy user-cleaner utility for deeper user-temp locations and local profile cleanup actions.'; Impact = 'Can free extra profile space, but is more aggressive than standard cleaner routines.' }
        @{ Id = 'DelProf'; Name = 'Delete Old User Profiles'; Default = $false; Description = 'Deletes old user profiles to reclaim disk space. Keep this off on shared PCs unless you are sure the profiles are no longer needed.'; Impact = 'Useful for lab or hand-me-down machines, but not recommended on shared personal PCs.' }
        @{ Id = 'VisualOptimisation'; Name = 'Visual Optimisation'; Default = $false; Description = 'Runs the standalone visual optimisation script. This is now separate from System Optimization so visual changes are only applied when explicitly selected.'; Impact = 'Include only when you want animation/theme visual tuning applied as part of Complete PC Setup.' }
        @{ Id = 'SystemOptimisation'; Name = 'System Optimization'; Default = $true; Description = 'Applies the balanced optimization set for performance, privacy, and lower idle RAM usage without stripping core Windows functionality.'; Impact = 'This is the main tuning step for responsiveness and privacy.' }
        @{ Id = 'FixWindowsDefender'; Name = 'Fix Windows Defender'; Default = $false; Description = 'Runs Defender remediation and policy repair routines to restore core protection features when they are disabled or damaged.'; Impact = 'Helpful on systems where Defender is broken or blocked by old AV remnants.' }
        @{ Id = 'WindowsTroubleshooting'; Name = 'Windows Troubleshooting'; Default = $false; Description = 'Runs the troubleshooting module with guided fixes for common network, update, and Store problems.'; Impact = 'Useful for problem PCs, not required for a routine optimization pass.' }
        @{ Id = 'CustomChanges'; Name = 'Custom Changes Panel'; Default = $false; Description = 'Opens the custom changes panel for optional manual tweak flows beyond the standard preset path.'; Impact = 'For power users who want extra manual controls after the baseline setup.' }
        @{ Id = 'ApplyAeroliteTheme'; Name = 'Apply Aerolite Theme'; Default = $false; Description = 'Launches the bundled Aerolite theme file so you can switch visual style as part of final setup.'; Impact = 'Cosmetic change only; does not alter performance/security settings.' }
        @{ Id = 'DISMRestore'; Name = 'DISM Health Check'; Default = $false; Description = 'Checks the Windows component store and repairs corruption when found. Helpful on damaged systems, but slower than the default recommended set.'; Impact = 'Good for machines with update or image-health issues.' }
        @{ Id = 'SFCRepair'; Name = 'System File Check'; Default = $false; Description = 'Scans protected system files and repairs corruption. Useful when Windows components behave oddly, but not necessary for every setup run.'; Impact = 'Adds repair coverage at the cost of runtime.' }
        @{ Id = 'DiskCheck'; Name = 'Disk Check and Repair'; Default = $false; Description = 'Checks the file system for disk issues. This can take time and may schedule work for reboot on busy volumes.'; Impact = 'Only include when storage issues are suspected.' }
        @{ Id = 'Defrag'; Name = 'Disk Defragmentation'; Default = $false; Description = 'Runs the disk optimization script. Best for HDD systems; SSD-aware logic remains in the script, but this is still optional.'; Impact = 'Useful for older spinning disks, usually unnecessary for SSD-focused setups.' }
    )

    $taskLookup = @{}
    foreach ($taskDefinition in $taskDefinitions) {
        $taskLookup[$taskDefinition.Name] = $taskDefinition
    }

    $presetDefinitions = @(
        @{
            Name = 'Minimal'
            Description = 'Fastest and safest preset. Keeps the setup light and focuses on cleanup plus balanced optimization.'
            Disclaimer = 'Minimal selects only the core cleanup and optimization steps. It avoids extra repair scans, disk checks, and more opinionated removals so the machine stays familiar and usable.'
            Tasks = @('WindowsCleaner', 'SystemOptimisation')
            DisableAI = $false
            OptimizationProfile = 'minimal'
            AccentColor = [System.Drawing.Color]::FromArgb(231, 242, 255)
            BorderColor = [System.Drawing.Color]::FromArgb(170, 198, 228)
            TextColor = $UiPalette.TextPrimary
        },
        @{
            Name = 'Optimal'
            Description = 'Recommended balanced preset for most PCs.'
            Disclaimer = 'Optimal is the recommended preset. It includes debloat, cleaner, OneDrive removal, and balanced optimization focused on performance, lower idle RAM, and privacy without stripping core Windows UX.'
            Tasks = @('WindowsInstallCleanup', 'WindowsUninstallOneDrive', 'WindowsCleaner', 'SystemOptimisation')
            DisableAI = $false
            OptimizationProfile = 'optimal'
            AccentColor = $UiPalette.AccentSoft
            BorderColor = $UiPalette.Border
            TextColor = $UiPalette.TextPrimary
        },
        @{
            Name = 'Aggressive'
            Description = 'Broader repair and tuning preset for problem machines.'
            Disclaimer = 'Aggressive enables extra repair and maintenance steps, adds the Windows AI disable option, and may take much longer to finish. It is still kept short of destructive malware-style debloat, but it is the heaviest preset in this tool.'
            Tasks = @('WindowsInstallCleanup', 'WindowsUninstallOneDrive', 'WindowsCleaner', 'SystemOptimisation', 'DISMRestore', 'SFCRepair', 'DiskCheck', 'Defrag')
            DisableAI = $true
            OptimizationProfile = 'aggressive'
            AccentColor = [System.Drawing.Color]::FromArgb(255, 230, 230)
            BorderColor = [System.Drawing.Color]::FromArgb(210, 70, 70)
            TextColor = [System.Drawing.Color]::FromArgb(130, 18, 18)
        }
    )

    $presetLookup = @{}
    foreach ($presetDefinition in $presetDefinitions) {
        $presetLookup[$presetDefinition.Name] = $presetDefinition
    }

    $presetPanel = New-Object System.Windows.Forms.Panel
    $presetPanel.Size = New-Object System.Drawing.Size(860, 118)
    $presetPanel.Location = New-Object System.Drawing.Point(10, 95)
    $presetPanel.BackColor = $UiPalette.CardBack
    $presetPanel.BorderStyle = 'FixedSingle'
    $presetPanel.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right

    $presetPanelTitle = New-Object System.Windows.Forms.Label
    $presetPanelTitle.Text = 'Setup Preset'
    $presetPanelTitle.Location = New-Object System.Drawing.Point(14, 12)
    $presetPanelTitle.Size = New-Object System.Drawing.Size(140, 20)
    $presetPanelTitle.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $presetPanelTitle.ForeColor = $UiPalette.TextPrimary

    $presetPanelHint = New-Object System.Windows.Forms.Label
    $presetPanelHint.Text = 'Preset buttons update the recommended checklist and optimisation depth. You can still manually tick or untick any item before starting.'
    $presetPanelHint.Location = New-Object System.Drawing.Point(14, 34)
    $presetPanelHint.Size = New-Object System.Drawing.Size(830, 18)
    $presetPanelHint.ForeColor = $UiPalette.TextMuted
    $presetPanelHint.AutoEllipsis = $true
    $presetPanelHint.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right

    $presetWarningPanel = New-Object System.Windows.Forms.Panel
    $presetWarningPanel.Size = New-Object System.Drawing.Size(832, 46)
    $presetWarningPanel.Location = New-Object System.Drawing.Point(14, 58)
    $presetWarningPanel.BackColor = $UiPalette.AccentSoft
    $presetWarningPanel.BorderStyle = 'FixedSingle'
    $presetWarningPanel.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right

    $presetWarningLabel = New-Object System.Windows.Forms.Label
    $presetWarningLabel.Location = New-Object System.Drawing.Point(10, 7)
    $presetWarningLabel.Size = New-Object System.Drawing.Size(812, 30)
    $presetWarningLabel.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    $presetWarningLabel.ForeColor = $UiPalette.TextPrimary
    $presetWarningLabel.BackColor = [System.Drawing.Color]::Transparent
    $presetWarningLabel.AutoEllipsis = $true
    $presetWarningLabel.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right

    $presetWarningPanel.Controls.Add($presetWarningLabel)
    $presetPanel.Controls.AddRange(@($presetPanelTitle, $presetPanelHint, $presetWarningPanel))
    $plannerForm.Controls.Add($presetPanel)

    $taskPanel = New-Object System.Windows.Forms.Panel
    $taskPanel.Size = New-Object System.Drawing.Size(390, 455)
    $taskPanel.Location = New-Object System.Drawing.Point(10, 225)
    $taskPanel.BackColor = $UiPalette.CardBack
    $taskPanel.BorderStyle = 'FixedSingle'
    $taskPanel.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left

    $taskPanelTitle = New-Object System.Windows.Forms.Label
    $taskPanelTitle.Text = 'Tasks'
    $taskPanelTitle.Location = New-Object System.Drawing.Point(12, 12)
    $taskPanelTitle.Size = New-Object System.Drawing.Size(120, 20)
    $taskPanelTitle.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $taskPanelTitle.ForeColor = $UiPalette.TextPrimary

    $taskPanelHint = New-Object System.Windows.Forms.Label
    $taskPanelHint.Text = 'Recommended items are pre-selected. Select any task to view a fuller explanation and expected outcome.'
    $taskPanelHint.Location = New-Object System.Drawing.Point(12, 34)
    $taskPanelHint.Size = New-Object System.Drawing.Size(360, 32)
    $taskPanelHint.ForeColor = $UiPalette.TextMuted

    $checkedTasks = New-Object System.Windows.Forms.CheckedListBox
    $checkedTasks.Location = New-Object System.Drawing.Point(12, 76)
    $checkedTasks.Size = New-Object System.Drawing.Size(360, 256)
    $checkedTasks.CheckOnClick = $true
    $checkedTasks.BorderStyle = 'FixedSingle'
    $checkedTasks.BackColor = $UiPalette.FormBack
    $checkedTasks.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right

    for ($index = 0; $index -lt $taskDefinitions.Count; $index++) {
        $taskDefinition = $taskDefinitions[$index]
        [void]$checkedTasks.Items.Add($taskDefinition.Name, $taskDefinition.Default)
    }

    $aiCheckbox = New-Object System.Windows.Forms.CheckBox
    $aiCheckbox.Text = 'Include Windows AI feature disablement'
    $aiCheckbox.Location = New-Object System.Drawing.Point(12, 348)
    $aiCheckbox.Size = New-Object System.Drawing.Size(220, 22)
    $aiCheckbox.Checked = $false
    $aiCheckbox.Anchor = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left

    $aiHint = New-Object System.Windows.Forms.Label
    $aiHint.Text = 'Optional: applied during System Optimisation. Disables Copilot, cloud-assisted search, online speech AI surfaces, and related policy-driven AI features.'
    $aiHint.Location = New-Object System.Drawing.Point(12, 374)
    $aiHint.Size = New-Object System.Drawing.Size(360, 44)
    $aiHint.ForeColor = $UiPalette.TextMuted
    $aiHint.Anchor = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right

    $taskPanel.Controls.AddRange(@($taskPanelTitle, $taskPanelHint, $checkedTasks, $aiCheckbox, $aiHint))
    $plannerForm.Controls.Add($taskPanel)

    $detailPanel = New-Object System.Windows.Forms.Panel
    $detailPanel.Size = New-Object System.Drawing.Size(470, 455)
    $detailPanel.Location = New-Object System.Drawing.Point(410, 225)
    $detailPanel.BackColor = $UiPalette.CardBack
    $detailPanel.BorderStyle = 'FixedSingle'
    $detailPanel.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right

    $detailTitle = New-Object System.Windows.Forms.Label
    $detailTitle.Text = 'Task Explanation'
    $detailTitle.Location = New-Object System.Drawing.Point(16, 16)
    $detailTitle.Size = New-Object System.Drawing.Size(280, 22)
    $detailTitle.Font = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)
    $detailTitle.ForeColor = $UiPalette.TextPrimary

    $detailDescription = New-Object System.Windows.Forms.Label
    $detailDescription.Location = New-Object System.Drawing.Point(16, 52)
    $detailDescription.Size = New-Object System.Drawing.Size(435, 178)
    $detailDescription.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    $detailDescription.ForeColor = $UiPalette.TextPrimary
    $detailDescription.AutoEllipsis = $true
    $detailDescription.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right

    $detailImpactTitle = New-Object System.Windows.Forms.Label
    $detailImpactTitle.Text = 'When To Include This'
    $detailImpactTitle.Location = New-Object System.Drawing.Point(16, 252)
    $detailImpactTitle.Size = New-Object System.Drawing.Size(220, 20)
    $detailImpactTitle.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $detailImpactTitle.ForeColor = $UiPalette.TextPrimary

    $detailImpact = New-Object System.Windows.Forms.Label
    $detailImpact.Location = New-Object System.Drawing.Point(16, 278)
    $detailImpact.Size = New-Object System.Drawing.Size(435, 56)
    $detailImpact.ForeColor = $UiPalette.TextMuted
    $detailImpact.AutoEllipsis = $true
    $detailImpact.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right

    $detailRecommendationTitle = New-Object System.Windows.Forms.Label
    $detailRecommendationTitle.Text = 'Default Guidance'
    $detailRecommendationTitle.Location = New-Object System.Drawing.Point(16, 356)
    $detailRecommendationTitle.Size = New-Object System.Drawing.Size(180, 20)
    $detailRecommendationTitle.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $detailRecommendationTitle.ForeColor = $UiPalette.TextPrimary

    $detailRecommendation = New-Object System.Windows.Forms.Label
    $detailRecommendation.Location = New-Object System.Drawing.Point(16, 382)
    $detailRecommendation.Size = New-Object System.Drawing.Size(435, 48)
    $detailRecommendation.ForeColor = $UiPalette.TextMuted
    $detailRecommendation.AutoEllipsis = $true
    $detailRecommendation.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right

    $detailPanel.Controls.AddRange(@(
        $detailTitle,
        $detailDescription,
        $detailImpactTitle,
        $detailImpact,
        $detailRecommendationTitle,
        $detailRecommendation
    ))
    $plannerForm.Controls.Add($detailPanel)

    $recommendedButton = New-Object System.Windows.Forms.Button
    $recommendedButton.Text = 'Recommended'
    $recommendedButton.Location = New-Object System.Drawing.Point(10, 645)
    $recommendedButton.Size = New-Object System.Drawing.Size(110, 32)
    $recommendedButton.FlatStyle = 'Flat'
    $recommendedButton.BackColor = $UiPalette.AccentSoft
    $recommendedButton.FlatAppearance.BorderColor = $UiPalette.Border
    $recommendedButton.Anchor = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left

    $selectAllButton = New-Object System.Windows.Forms.Button
    $selectAllButton.Text = 'Select All'
    $selectAllButton.Location = New-Object System.Drawing.Point(130, 645)
    $selectAllButton.Size = New-Object System.Drawing.Size(100, 32)
    $selectAllButton.FlatStyle = 'Flat'
    $selectAllButton.BackColor = $UiPalette.CardBack
    $selectAllButton.FlatAppearance.BorderColor = $UiPalette.Border
    $selectAllButton.Anchor = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left

    $clearAllButton = New-Object System.Windows.Forms.Button
    $clearAllButton.Text = 'Clear All'
    $clearAllButton.Location = New-Object System.Drawing.Point(240, 645)
    $clearAllButton.Size = New-Object System.Drawing.Size(100, 32)
    $clearAllButton.FlatStyle = 'Flat'
    $clearAllButton.BackColor = $UiPalette.CardBack
    $clearAllButton.FlatAppearance.BorderColor = $UiPalette.Border
    $clearAllButton.Anchor = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left

    $startButton = New-Object System.Windows.Forms.Button
    $startButton.Text = 'Start Selected Tasks'
    $startButton.Location = New-Object System.Drawing.Point(650, 645)
    $startButton.Size = New-Object System.Drawing.Size(140, 32)
    $startButton.FlatStyle = 'Flat'
    $startButton.BackColor = $UiPalette.Accent
    $startButton.ForeColor = [System.Drawing.Color]::White
    $startButton.FlatAppearance.BorderColor = $UiPalette.Accent
    $startButton.Anchor = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Right

    $cancelButton = New-Object System.Windows.Forms.Button
    $cancelButton.Text = 'Cancel'
    $cancelButton.Location = New-Object System.Drawing.Point(798, 645)
    $cancelButton.Size = New-Object System.Drawing.Size(80, 32)
    $cancelButton.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $cancelButton.FlatStyle = 'Flat'
    $cancelButton.BackColor = $UiPalette.CardBack
    $cancelButton.FlatAppearance.BorderColor = $UiPalette.Border
    $cancelButton.Anchor = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Right

    $plannerForm.CancelButton = $cancelButton

    $presetButtons = @{}
    $selectedOptimizationProfile = 'optimal'

    function Apply-SetupPreset {
        param([Parameter(Mandatory)][string]$PresetName)

        if (-not $presetLookup.ContainsKey($PresetName)) {
            return
        }

        $preset = $presetLookup[$PresetName]
        $selectedOptimizationProfile = if ($preset.ContainsKey('OptimizationProfile')) { [string]$preset.OptimizationProfile } else { 'optimal' }

        for ($i = 0; $i -lt $checkedTasks.Items.Count; $i++) {
            $taskName = [string]$checkedTasks.Items[$i]
            $taskId = $taskLookup[$taskName].Id
            $checkedTasks.SetItemChecked($i, $preset.Tasks -contains $taskId)
        }

        $aiCheckbox.Checked = $preset.DisableAI
        $presetWarningPanel.BackColor = $preset.AccentColor
        $presetWarningPanel.ForeColor = $preset.TextColor
        $presetWarningLabel.ForeColor = $preset.TextColor
        $presetWarningLabel.Text = $preset.Disclaimer

        foreach ($presetButtonName in $presetButtons.Keys) {
            $presetButton = $presetButtons[$presetButtonName]
            $presetButton.FlatAppearance.BorderSize = 1
            if ($presetButtonName -eq $PresetName) {
                $presetButton.BackColor = $preset.AccentColor
                $presetButton.FlatAppearance.BorderColor = $preset.BorderColor
                $presetButton.ForeColor = $preset.TextColor
                $presetButton.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
            } else {
                $presetButton.BackColor = $UiPalette.CardBack
                $presetButton.FlatAppearance.BorderColor = $UiPalette.Border
                $presetButton.ForeColor = $UiPalette.TextPrimary
                $presetButton.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Regular)
            }
        }
    }

    $presetX = 480
    foreach ($presetDefinition in $presetDefinitions) {
        $presetButton = New-Object System.Windows.Forms.Button
        $presetButton.Text = $presetDefinition.Name
        $presetButton.Location = New-Object System.Drawing.Point($presetX, 12)
        $presetButton.Size = New-Object System.Drawing.Size(110, 30)
        $presetButton.FlatStyle = 'Flat'
        $presetButton.BackColor = $UiPalette.CardBack
        $presetButton.FlatAppearance.BorderColor = $UiPalette.Border
        $presetButton.ForeColor = $UiPalette.TextPrimary
        $presetButton.Tag = $presetDefinition.Name
        $presetButton.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Right
        $presetButton.Add_Click({
            Apply-SetupPreset -PresetName ([string]$this.Tag)
        })

        $presetButtons[$presetDefinition.Name] = $presetButton
        $presetPanel.Controls.Add($presetButton)
        $presetX += 120
    }

    function Update-PlannerDetails {
        param([string]$TaskName)

        if ([string]::IsNullOrWhiteSpace($TaskName) -or -not $taskLookup.ContainsKey($TaskName)) {
            $detailTitle.Text = 'Task Explanation'
            $detailDescription.Text = 'Select a task on the left to view exactly what it changes, where it is applied, and whether it is part of the recommended baseline.'
            $detailImpact.Text = 'The default checklist is designed for balanced results: better responsiveness, lower idle overhead, and stronger privacy without removing core Windows user experience features.'
            $detailRecommendation.Text = 'For most users, keep the default selection and only add repair-heavy tasks when a specific fault or maintenance need is known.'
            return
        }

        $taskDefinition = $taskLookup[$TaskName]
        $detailTitle.Text = $taskDefinition.Name
        $detailDescription.Text = $taskDefinition.Description
        $detailImpact.Text = $taskDefinition.Impact
        if ($taskDefinition.Default) {
            $detailRecommendation.Text = 'Enabled by default: this aligns with the tool''s balanced baseline profile for most systems.'
        } else {
            $detailRecommendation.Text = 'Optional task: leave unticked unless the machine has a specific issue or maintenance requirement this action addresses.'
        }
    }

    $checkedTasks.Add_SelectedIndexChanged({
        if ($checkedTasks.SelectedIndex -ge 0) {
            Update-PlannerDetails -TaskName ([string]$checkedTasks.Items[$checkedTasks.SelectedIndex])
        }
    })

    $recommendedButton.Add_Click({
        Apply-SetupPreset -PresetName 'Optimal'
    })

    $selectAllButton.Add_Click({
        for ($i = 0; $i -lt $checkedTasks.Items.Count; $i++) {
            $checkedTasks.SetItemChecked($i, $true)
        }
    })

    $clearAllButton.Add_Click({
        for ($i = 0; $i -lt $checkedTasks.Items.Count; $i++) {
            $checkedTasks.SetItemChecked($i, $false)
        }
        $aiCheckbox.Checked = $false
    })

    $startButton.Add_Click({
        $selectedTaskIds = @()
        foreach ($checkedItem in $checkedTasks.CheckedItems) {
            $selectedTaskIds += $taskLookup[[string]$checkedItem].Id
        }

        if ($aiCheckbox.Checked -and -not ($selectedTaskIds -contains 'SystemOptimisation')) {
            [System.Windows.Forms.MessageBox]::Show(
                'Windows AI disablement is applied inside System Optimisation. Please include System Optimisation in the checklist to use this option.',
                'Complete PC Setup Planner',
                'OK',
                'Information'
            ) | Out-Null
            return
        }

        if ($selectedTaskIds.Count -eq 0 -and -not $aiCheckbox.Checked) {
            [System.Windows.Forms.MessageBox]::Show(
                'Select at least one task before starting Complete PC Setup so the tool has an execution plan.',
                'Complete PC Setup Planner',
                'OK',
                'Information'
            ) | Out-Null
            return
        }

        $plannerForm.Tag = [pscustomobject]@{
            Confirmed = $true
            SelectedTaskIds = $selectedTaskIds
            DisableAI = $aiCheckbox.Checked
            OptimizationProfile = $selectedOptimizationProfile
        }
        $plannerForm.DialogResult = [System.Windows.Forms.DialogResult]::OK
        $plannerForm.Close()
    })

    $plannerForm.Controls.AddRange(@($recommendedButton, $selectAllButton, $clearAllButton, $startButton, $cancelButton))

    $updatePlannerLayout = {
        $margin = 10
        $clientWidth = $plannerForm.ClientSize.Width
        $clientHeight = $plannerForm.ClientSize.Height

        $plannerHeader.Size = New-Object System.Drawing.Size(($clientWidth - ($margin * 2)), 72)
        $plannerSubtitle.Size = New-Object System.Drawing.Size(($plannerHeader.Width - 30), 18)

        $presetPanel.Location = New-Object System.Drawing.Point($margin, ($plannerHeader.Bottom + 12))
        $presetPanel.Size = New-Object System.Drawing.Size(($clientWidth - ($margin * 2)), 118)
        $presetButtonWidth = 110
        $presetButtonSpacing = 10
        $presetButtonLaneWidth = (($presetButtonWidth + $presetButtonSpacing) * $presetDefinitions.Count) - $presetButtonSpacing
        $presetStartX = $presetPanel.Width - $presetButtonLaneWidth - 14
        if ($presetStartX -lt 220) {
            $presetStartX = 220
        }

        $presetHintWidth = $presetStartX - $presetPanelHint.Left - 14
        if ($presetHintWidth -lt 220) {
            $presetHintWidth = 220
        }

        $presetPanelHint.Size = New-Object System.Drawing.Size($presetHintWidth, 18)
        $presetWarningPanel.Size = New-Object System.Drawing.Size(($presetPanel.Width - 28), 46)
        $presetWarningLabel.Size = New-Object System.Drawing.Size(($presetWarningPanel.Width - 20), 30)

        $presetIndex = 0
        foreach ($presetDefinition in $presetDefinitions) {
            $presetButtons[$presetDefinition.Name].Location = New-Object System.Drawing.Point(($presetStartX + ($presetIndex * ($presetButtonWidth + $presetButtonSpacing))), 12)
            $presetIndex++
        }

        $contentTop = $presetPanel.Bottom + 12
        $bottomButtonsY = $clientHeight - 45
        $contentHeight = $bottomButtonsY - $contentTop - 10
        if ($contentHeight -lt 260) {
            $contentHeight = 260
        }

        $taskWidth = [Math]::Max(320, [Math]::Floor(($clientWidth - 30) * 0.44))
        $detailWidth = $clientWidth - ($margin * 3) - $taskWidth
        if ($detailWidth -lt 360) {
            $detailWidth = 360
            $taskWidth = $clientWidth - ($margin * 3) - $detailWidth
        }

        $taskPanel.Location = New-Object System.Drawing.Point($margin, $contentTop)
        $taskPanel.Size = New-Object System.Drawing.Size($taskWidth, $contentHeight)
        $detailPanel.Location = New-Object System.Drawing.Point(($taskPanel.Right + 10), $contentTop)
        $detailPanel.Size = New-Object System.Drawing.Size($detailWidth, $contentHeight)

        $taskPanelHint.Size = New-Object System.Drawing.Size(($taskPanel.Width - 30), 32)
        $checkedTasks.Size = New-Object System.Drawing.Size(($taskPanel.Width - 30), [Math]::Max(180, ($taskPanel.Height - 210)))
        $aiCheckbox.Location = New-Object System.Drawing.Point(12, ($checkedTasks.Bottom + 12))
        $aiHint.Location = New-Object System.Drawing.Point(12, ($aiCheckbox.Bottom + 6))
        $aiHint.Size = New-Object System.Drawing.Size(($taskPanel.Width - 30), [Math]::Max(38, ($taskPanel.Height - $aiHint.Location.Y - 12)))

        $detailDescription.Size = New-Object System.Drawing.Size(($detailPanel.Width - 35), [Math]::Max(90, [Math]::Floor(($detailPanel.Height - 120) * 0.46)))
        $detailImpactTitle.Location = New-Object System.Drawing.Point(16, ($detailDescription.Bottom + 16))
        $detailImpact.Location = New-Object System.Drawing.Point(16, ($detailImpactTitle.Bottom + 6))
        $detailImpact.Size = New-Object System.Drawing.Size(($detailPanel.Width - 35), [Math]::Max(45, [Math]::Floor(($detailPanel.Height - 120) * 0.24)))
        $detailRecommendationTitle.Location = New-Object System.Drawing.Point(16, ($detailImpact.Bottom + 12))
        $detailRecommendation.Location = New-Object System.Drawing.Point(16, ($detailRecommendationTitle.Bottom + 6))
        $detailRecommendation.Size = New-Object System.Drawing.Size(($detailPanel.Width - 35), [Math]::Max(42, ($detailPanel.Height - $detailRecommendation.Location.Y - 12)))

        $recommendedButton.Location = New-Object System.Drawing.Point($margin, $bottomButtonsY)
        $selectAllButton.Location = New-Object System.Drawing.Point(($recommendedButton.Right + 8), $bottomButtonsY)
        $clearAllButton.Location = New-Object System.Drawing.Point(($selectAllButton.Right + 8), $bottomButtonsY)
        $cancelButton.Location = New-Object System.Drawing.Point(($clientWidth - $margin - $cancelButton.Width), $bottomButtonsY)
        $startButton.Location = New-Object System.Drawing.Point(($cancelButton.Left - 8 - $startButton.Width), $bottomButtonsY)

        $plannerForm.AutoScrollMinSize = New-Object System.Drawing.Size([Math]::Max(860, $clientWidth - 20), [Math]::Max(700, $bottomButtonsY + 55))
    }

    $plannerForm.Add_Shown({ & $updatePlannerLayout })
    $plannerForm.Add_Resize({ & $updatePlannerLayout })

    Apply-SetupPreset -PresetName 'Optimal'
    Update-PlannerDetails
    $null = $plannerForm.ShowDialog($Form)

    if ($plannerForm.DialogResult -eq [System.Windows.Forms.DialogResult]::OK -and $plannerForm.Tag) {
        return $plannerForm.Tag
    }

    return $null
}

# Automated maintenance operations with comprehensive progress tracking
function Start-AutomatedMaintenance {
    param(
        [switch]$ScheduleMode,
        [string[]]$SelectedTaskIds,
        [switch]$DisableAI,
        [string]$OptimizationProfile = 'optimal'
    )

    try {
        $refreshUi = {
            param([System.Windows.Forms.Control]$Control = $null)

            try {
                if ($Control -and -not $Control.IsDisposed) {
                    $Control.Refresh()
                }

                [System.Windows.Forms.Application]::DoEvents()
            } catch {
                # Ignore UI refresh exceptions in automation flow.
            }
        }

        Show-ProgressDialog -Status "Initialising Complete PC Setup sequence..." -Indeterminate
        & $refreshUi -Control $Global:MainProgressForm

        if ([string]::IsNullOrWhiteSpace($OptimizationProfile)) {
            $OptimizationProfile = 'optimal'
        } else {
            $OptimizationProfile = $OptimizationProfile.ToLowerInvariant()
        }

        if ($OptimizationProfile -notin @('minimal', 'optimal', 'aggressive')) {
            $OptimizationProfile = 'optimal'
        }

        $resolvedScriptPaths = @{
            SystemOptimisation = $scriptPaths['SystemOptimisation']
            VisualOptimisation = $scriptPaths['VisualOptimisation']
            UserCleaner = $scriptPaths['UserCleaner']
            DefenderFix = $scriptPaths['DefenderFix']
            Troubleshooting = $scriptPaths['Troubleshooting']
            CustomChanges = $scriptPaths['CustomChanges']
            AeroliteTheme = $scriptPaths['AeroliteTheme']
        }

        $runExternalScript = {
            param(
                [string]$ScriptPath,
                [string[]]$ArgumentList = @()
            )

            if ([string]::IsNullOrWhiteSpace($ScriptPath)) {
                Write-Warning 'Task script path is empty.'
                return $false
            }

            if (-not (Test-Path -Path $ScriptPath)) {
                Write-Warning "Task script not found: $ScriptPath"
                return $false
            }

            $absoluteScriptPath = (Resolve-Path -Path $ScriptPath).Path
            $automationArguments = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $absoluteScriptPath)
            if ($ArgumentList -and $ArgumentList.Count -gt 0) {
                $automationArguments += $ArgumentList
            }

            $child = Start-Process -FilePath 'powershell.exe' -ArgumentList $automationArguments -Wait -PassThru -NoNewWindow
            return ($child.ExitCode -eq 0)
        }

        $systemOptimizationArguments = @('--automated', '--profile', $OptimizationProfile)
        if ($DisableAI) {
            $systemOptimizationArguments += '--disable-ai'
        }

        $systemOptimizationTask = {
            & $runExternalScript -ScriptPath $resolvedScriptPaths.SystemOptimisation -ArgumentList $systemOptimizationArguments
        }.GetNewClosure()

        $visualOptimizationTask = {
            & $runExternalScript -ScriptPath $resolvedScriptPaths.VisualOptimisation -ArgumentList @('--automated')
        }.GetNewClosure()

        $userCleanerTask = {
            & $runExternalScript -ScriptPath $resolvedScriptPaths.UserCleaner
        }.GetNewClosure()

        $fixDefenderTask = {
            & $runExternalScript -ScriptPath $resolvedScriptPaths.DefenderFix
        }.GetNewClosure()

        $troubleshootingTask = {
            & $runExternalScript -ScriptPath $resolvedScriptPaths.Troubleshooting
        }.GetNewClosure()

        $customChangesTask = {
            & $runExternalScript -ScriptPath $resolvedScriptPaths.CustomChanges
        }.GetNewClosure()

        $applyAeroliteThemeTask = {
            $themePath = $resolvedScriptPaths.AeroliteTheme
            if ([string]::IsNullOrWhiteSpace($themePath)) {
                Write-Warning 'Aerolite theme path is empty.'
                return $false
            }

            if (-not (Test-Path -Path $themePath)) {
                Write-Warning "Aerolite theme not found: $themePath"
                return $false
            }

            Start-Process -FilePath $themePath | Out-Null
            return $true
        }.GetNewClosure()

        $taskCatalog = @(
            @{ Id = 'WindowsInstallCleanup'; Name = 'Windows Install Cleanup'; Script = $Scripts.WindowsInstallCleanup; Weight = 12; Default = $true }
            @{ Id = 'ReinstallApps'; Name = 'Reinstall Default Apps'; Script = $Scripts.ReinstallApps; Weight = 8; Default = $false }
            @{ Id = 'WindowsUninstallOneDrive'; Name = 'OneDrive Uninstaller'; Script = $Scripts.WindowsUninstallOneDrive; Weight = 8; Default = $true }
            @{ Id = 'WindowsCleaner'; Name = 'System File Cleanup'; Script = $Scripts.WindowsCleaner; Weight = 10; Default = $true }
            @{ Id = 'UserCleaner'; Name = 'User Profile Temp Cleaner'; Script = $userCleanerTask; Weight = 8; Default = $false }
            @{ Id = 'DelProf'; Name = 'Delete User Profiles'; Script = $Scripts.DelProf; Weight = 8; Default = $false }
            @{ Id = 'VisualOptimisation'; Name = 'Visual Optimisation'; Script = $visualOptimizationTask; Weight = 8; Default = $false }
            @{ Id = 'SystemOptimisation'; Name = 'System Optimization'; Script = $systemOptimizationTask; Weight = 18; Default = $true }
            @{ Id = 'FixWindowsDefender'; Name = 'Fix Windows Defender'; Script = $fixDefenderTask; Weight = 12; Default = $false }
            @{ Id = 'WindowsTroubleshooting'; Name = 'Windows Troubleshooting'; Script = $troubleshootingTask; Weight = 8; Default = $false }
            @{ Id = 'CustomChanges'; Name = 'Custom Changes Panel'; Script = $customChangesTask; Weight = 6; Default = $false }
            @{ Id = 'ApplyAeroliteTheme'; Name = 'Apply Aerolite Theme'; Script = $applyAeroliteThemeTask; Weight = 4; Default = $false }
            @{ Id = 'DISMRestore'; Name = 'DISM Health Check'; Script = $Scripts.DISMRestore; Weight = 14; Default = $false }
            @{ Id = 'SFCRepair'; Name = 'System File Check'; Script = $Scripts.SFCRepair; Weight = 14; Default = $false }
            @{ Id = 'DiskCheck'; Name = 'Disk Check and Repair'; Script = $Scripts.DiskCheck; Weight = 12; Default = $false }
            @{ Id = 'Defrag'; Name = 'Disk Defragmentation'; Script = $Scripts.Defrag; Weight = 8; Default = $false }
        )

        if ($SelectedTaskIds -and $SelectedTaskIds.Count -gt 0) {
            $maintenanceTasks = foreach ($taskEntry in $taskCatalog) {
                if ($SelectedTaskIds -contains $taskEntry.Id) {
                    $taskEntry
                }
            }
        } else {
            $maintenanceTasks = $taskCatalog | Where-Object { $_.Default }
        }

        if (-not $maintenanceTasks -or $maintenanceTasks.Count -eq 0) {
            Show-ProgressDialog -Status "No Complete PC Setup tasks were selected." -PercentComplete 0
            & $refreshUi -Control $Global:MainProgressForm
            return
        }

        $totalTasks = $maintenanceTasks.Count
        $currentTask = 0

        foreach ($task in $maintenanceTasks) {
            $currentTask++
            $taskProgress = [Math]::Round(($currentTask / $totalTasks) * 100)

            Show-ProgressDialog -Status "[$currentTask/$totalTasks] $($task.Name)..." -PercentComplete $taskProgress

            try {
                $taskResult = & $task.Script
                if ($taskResult -eq $false) {
                    Write-Host "Warning in $($task.Name): task reported incomplete execution." -ForegroundColor Yellow
                } else {
                    Write-Host "Completed: $($task.Name)" -ForegroundColor Green
                }
            } catch {
                Write-Host "Warning in $($task.Name): $_" -ForegroundColor Yellow
            }

            & $refreshUi -Control $Global:MainProgressForm
        }

        Show-ProgressDialog -Status "Complete PC Setup finished successfully." -PercentComplete 100
        & $refreshUi -Control $Global:MainProgressForm
    } catch {
        Write-Host "Error during Complete PC Setup: $($_.Exception.Message)" -ForegroundColor Red
        [System.Windows.Forms.MessageBox]::Show(
            "Complete PC Setup encountered an error: $($_.Exception.Message)",
            'Windows Maintenance - Complete Setup Error',
            'OK',
            'Error'
        ) | Out-Null
    } finally {
        Show-ProgressDialog -Close
    }
}

# Complete PC Setup button - runs everything for a fully optimized system
Add-MaintenanceButton "Complete PC Setup" (New-Object System.Drawing.Point($leftButtonX, $currentY)) {
    $setupPlan = Show-CompleteSetupPlanner

    if ($setupPlan -and $setupPlan.Confirmed) {
        Start-AutomatedMaintenance -SelectedTaskIds $setupPlan.SelectedTaskIds -DisableAI:$setupPlan.DisableAI -OptimizationProfile $setupPlan.OptimizationProfile
    }
} "Special" "Open the guided planner to run a full setup sequence with preset profiles, detailed task explanations, and optional AI disablement." -Column 0

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
$statusLabel.Text = "Ready: select a maintenance operation to view progress and apply changes safely."
$statusLabel.Spring = $true
$statusBar.Items.Add($statusLabel)
$Form.Controls.Add($statusBar)

$updateMainLayout = {
    $mainMargin = 30
    $columnGap = 20
    $usableWidth = [Math]::Max(520, ($Form.ClientSize.Width - ($mainMargin * 2)))
    $dynamicButtonWidth = [Math]::Floor(($usableWidth - ($columnGap * 2)) / 3)
    $dynamicButtonHeight = [Math]::Max(42, [int]([Math]::Ceiling($Form.Font.GetHeight() + 24)))
    if ($dynamicButtonWidth -lt 165) {
        $dynamicButtonWidth = 165
    }

    $leftX = $mainMargin
    $middleX = $leftX + $dynamicButtonWidth + $columnGap
    $rightX = $middleX + $dynamicButtonWidth + $columnGap

    $headerPanel.Size = New-Object System.Drawing.Size(($Form.ClientSize.Width - 20), 60)
    $subTitleLabel.Size = New-Object System.Drawing.Size([Math]::Max(220, ($headerPanel.Width - 430)), 20)
    $subTitleLabel.Location = New-Object System.Drawing.Point(($headerPanel.Width - $subTitleLabel.Width - 15), 20)

    $instructionsLabel.Size = New-Object System.Drawing.Size(($Form.ClientSize.Width - 40), 32)
    $summaryPanel.Size = New-Object System.Drawing.Size(($Form.ClientSize.Width - 40), 48)
    $summaryLabel.Size = New-Object System.Drawing.Size(($summaryPanel.Width - 20), 30)

    foreach ($control in $Form.Controls) {
        if ($control -is [System.Windows.Forms.Label] -and $control.Tag -eq 'SectionLabel') {
            $control.Size = New-Object System.Drawing.Size(($Form.ClientSize.Width - 60), 25)
        }
    }

    foreach ($buttonMeta in $mainActionButtons) {
        $buttonControl = $buttonMeta.Button
        if (-not $buttonControl -or $buttonControl.IsDisposed) {
            continue
        }

        $buttonControl.Size = New-Object System.Drawing.Size($dynamicButtonWidth, $dynamicButtonHeight)

        switch ($buttonMeta.Column) {
            0 { $buttonControl.Location = New-Object System.Drawing.Point($leftX, $buttonControl.Location.Y) }
            1 { $buttonControl.Location = New-Object System.Drawing.Point($middleX, $buttonControl.Location.Y) }
            2 { $buttonControl.Location = New-Object System.Drawing.Point($rightX, $buttonControl.Location.Y) }
            default { $buttonControl.Location = New-Object System.Drawing.Point($leftX, $buttonControl.Location.Y) }
        }
    }

    $ExitButton.Location = New-Object System.Drawing.Point(([Math]::Floor(($Form.ClientSize.Width - $ExitButton.Width) / 2)), $ExitButton.Location.Y)
    $Form.AutoScrollMinSize = New-Object System.Drawing.Size(($Form.ClientSize.Width - 20), ($currentY + 120))
}

$Form.Add_Shown({ & $updateMainLayout })
$Form.Add_Resize({ & $updateMainLayout })

# Ensure no progress dialog is left open when the main form is closed.
$Form.Add_FormClosing({
    try {
        if ($Global:MainProgressForm) {
            $Global:MainProgressForm.Close()
            $Global:MainProgressForm.Dispose()
            $Global:MainProgressForm = $null
            $Global:MainProgressBar = $null
            $Global:MainProgressLabel = $null
        }
    } catch {
        # Ignore shutdown cleanup errors.
    }
})

# Ensure the full main layout remains reachable even on lower-resolution displays.
$Form.AutoScrollMinSize = New-Object System.Drawing.Size(($formWidth - 20), ($currentY + 120))

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

    $ExitButton.Location = New-Object System.Drawing.Point([Math]::Max(10, [int](($Form.ClientSize.Width - $ExitButton.Width) / 2)), $ExitButton.Location.Y)
}

Write-Host "Windows Maintenance Tool session ended." -ForegroundColor Cyan
if ($DebugMode) { Write-DebugMessage "Session ended normally" "INFO" }

# Created by Chris Masters - Enhanced with unified progress tracking and modern UI