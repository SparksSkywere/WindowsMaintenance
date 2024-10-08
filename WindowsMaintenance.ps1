# Clear Host and Set Execution Policy
Set-ExecutionPolicy Bypass -Force
Clear-Host

# Load necessary .NET types
Add-Type -AssemblyName System.Windows.Forms
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

# Hide console
Show-Console -Hide

# Utility function to show messages
function Show-MessageBox {
    param (
        [string]$Message,
        [string]$Title = 'Windows Maintenance'
    )
    [System.Windows.Forms.MessageBox]::Show($Message, $Title, [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
}

# Check if the script file exists before executing
function Invoke-ScriptIfExists {
    param (
        [string]$ScriptPath
    )
    
    if (Test-Path $ScriptPath) {
        try {
            Write-Host "Executing script: $ScriptPath" -ForegroundColor Green
            . $ScriptPath
            Write-Host "Script executed successfully: $ScriptPath" -ForegroundColor Green
        } catch {
            Write-Host "Error: Script execution failed for path: $ScriptPath" -ForegroundColor Red
            Write-Host "Error details: $_" -ForegroundColor Red
        }
    } else {
        Write-Host "Error: Script not found at path: $ScriptPath" -ForegroundColor Red
    }
}

# Function to detect the Windows OS version
function Get-WindowsVersion {
    $os = Get-CimInstance -ClassName CIM_OperatingSystem
    
    # Output the OS version for debugging
    Write-Host "Detected OS Version: $($os.Version)" -ForegroundColor Cyan

    # Check version for Windows 10 or Windows 11
    if ($os.Version -like "10.0.1904*") {
        return "Windows 10"
    } elseif ($os.Version -like "10.0.22*") {
        return "Windows 11"
    } else {
        return "Unknown OS"
    }
}

# Determine which cleanup script to use based on the OS version
$osVersion = Get-WindowsVersion
Write-Host "OS Version Detected: $osVersion" -ForegroundColor Cyan

switch ($osVersion) {
    "Windows 10" {
        Write-Host "Detected OS: Windows 10" -ForegroundColor Green
        $installCleanerScript = ".\Scripts\Windows10InstallCleaner.ps1"
    }
    "Windows 11" {
        Write-Host "Detected OS: Windows 11" -ForegroundColor Green
        $installCleanerScript = ".\Scripts\Windows11InstallCleaner.ps1"
    }
    default {
        Write-Host "Error: OS could not be determined or unsupported OS." -ForegroundColor Red
        exit
    }
}

# Explicitly define each script block and validate their initialization
$Scripts = @{
    WindowsInstallCleanup    = [scriptblock]::Create({ Invoke-ScriptIfExists $installCleanerScript })
    WindowsUninstallOneDrive = [scriptblock]::Create({ Invoke-ScriptIfExists ".\Scripts\Uninstallonedrive.ps1" })
    WindowsCleaner           = [scriptblock]::Create({ Invoke-ScriptIfExists ".\Scripts\WindowsCleaner.ps1" })
    Defrag                   = [scriptblock]::Create({ Invoke-ScriptIfExists ".\Scripts\windowsdefrag.ps1" })
    DiskCheck                = [scriptblock]::Create({ Invoke-ScriptIfExists ".\Scripts\windowsrepairvolume.ps1" })
    ReinstallApps            = [scriptblock]::Create({ 
        try {
            Get-AppXPackage -AllUsers | ForEach-Object { 
                Add-AppxPackage -DisableDevelopmentMode -Register "$($_.InstallLocation)\AppXManifest.xml" 
            }
            Show-MessageBox 'Operation Completed' 
        } catch {
            Write-Host "Error executing ReinstallApps: $_" -ForegroundColor Red
        }
    })
    DelProf                  = [scriptblock]::Create({ 
        try {
            Start-Process -FilePath ".\Scripts\Delprof.exe" -ArgumentList "/u /q" -Wait
            Show-MessageBox 'Operation Completed' 
        } catch {
            Write-Host "Error executing DelProf: $_" -ForegroundColor Red
        }
    })
    DISMRestore              = [scriptblock]::Create({ 
        try {
            Start-Process -FilePath "DISM" -ArgumentList "/Online /Cleanup-Image /ScanHealth" -Wait
            Start-Process -FilePath "DISM" -ArgumentList "/Online /Cleanup-Image /RestoreHealth" -Wait
            Show-MessageBox 'DISM Scan Completed' 
        } catch {
            Write-Host "Error executing DISM Restore: $_" -ForegroundColor Red
        }
    })
    SFCRepair                = [scriptblock]::Create({ 
        try {
            Start-Process -FilePath "sfc" -ArgumentList "/scannow" -Wait
            Show-MessageBox 'SFC Scan Completed' 
        } catch {
            Write-Host "Error executing SFC Repair: $_" -ForegroundColor Red
        }
    })
    WindowsTroubleshooting   = [scriptblock]::Create({ 
        try {
            Write-Host "Executing Troubleshooting script" -ForegroundColor Cyan
            Invoke-ScriptIfExists ".\Scripts\Troubleshooting.ps1"
        } catch {
            Write-Host "Error during Troubleshooting execution: $_" -ForegroundColor Red
        }
    })
    SystemOptimisation       = [scriptblock]::Create({ 
        try {
            Write-Host "Executing System Optimisation" -ForegroundColor Cyan
            Invoke-ScriptIfExists ".\Scripts\SystemOptimisation.ps1"
        } catch {
            Write-Host "Error during System Optimisation execution: $_" -ForegroundColor Red
        }
    })
}

# Validate script block assignment
foreach ($key in $Scripts.Keys) {
    if ($null -eq $Scripts[$key]) {
        Write-Host "Error: Script block for $key is null." -ForegroundColor Red
    } else {
        Write-Host "Script block for $key is valid." -ForegroundColor Green
    }
}

# Form Creation
$Form = New-Object System.Windows.Forms.Form
$Form.Text = 'Windows Maintenance'
$Form.Size = New-Object System.Drawing.Size(370, 350)
$Form.StartPosition = 'CenterScreen'
$Form.Icon = [System.Drawing.Icon]::ExtractAssociatedIcon((Get-Item ".\Assets\windowslogo.ico").FullName)

# Label for instructions
$FormText = New-Object System.Windows.Forms.Label
$FormText.Location = New-Object System.Drawing.Point(35, 10)
$FormText.Size = New-Object System.Drawing.Size(300, 18)
$FormText.Text = 'Select Options Below, these run in silent mode'
$Form.Controls.Add($FormText)

# Create button function
function Add-Button {
    param (
        [string]$Text,
        [System.Drawing.Point]$Location,
        [scriptblock]$Action
    )

    Write-Host "Adding button: $Text" -ForegroundColor Cyan
    Write-Host "Action Type: $($Action.GetType().Name)" -ForegroundColor Yellow

    if ([string]::IsNullOrWhiteSpace($Text)) {
        Write-Host "Error: Button text is empty. Skipping this button." -ForegroundColor Red
        return
    }

    if ($null -eq $Action -or -not ($Action -is [scriptblock])) {
        Write-Host "Error: Invalid or missing action for button '$Text'" -ForegroundColor Red
        return
    }

    $Button = New-Object System.Windows.Forms.Button
    $Button.Text = $Text
    $Button.Location = $Location
    $Button.Size = New-Object System.Drawing.Size(120, 23)

    $Button.Add_Click({
        param ($sender, $eventArgs)

        Write-Host "Button clicked: $($sender.Text)" -ForegroundColor Green

        try {
            if ($null -eq $Action) {
                Write-Host "Error: Action is null for button '$($sender.Text)'" -ForegroundColor Red
            } else {
                Write-Host "Invoking action for button '$($sender.Text)'" -ForegroundColor Green
                & $Action
            }
        } catch {
            Write-Host "Error executing action for button '$($sender.Text)': $_" -ForegroundColor Red
        }
    })

    $Form.Controls.Add($Button)
}

# Adding the buttons with script blocks as before
Add-Button "Fresh Install Cleanup" (New-Object System.Drawing.Point(35, 35)) $Scripts.WindowsInstallCleanup
Add-Button "Reinstall Default Apps" (New-Object System.Drawing.Point(165, 35)) $Scripts.ReinstallApps
Add-Button "Uninstall OneDrive" (New-Object System.Drawing.Point(35, 65)) $Scripts.WindowsUninstallOneDrive
Add-Button "Delete All User Profiles" (New-Object System.Drawing.Point(165, 65)) $Scripts.DelProf
Add-Button "Windows Cleaner" (New-Object System.Drawing.Point(35, 125)) $Scripts.WindowsCleaner
Add-Button "DISM Restore Health" (New-Object System.Drawing.Point(165, 95)) $Scripts.DISMRestore
Add-Button "Defrag" (New-Object System.Drawing.Point(35, 155)) $Scripts.Defrag
Add-Button "Disk Check" (New-Object System.Drawing.Point(165, 155)) $Scripts.DiskCheck
Add-Button "System Repair Scan" (New-Object System.Drawing.Point(165, 125)) $Scripts.SFCRepair
Add-Button "Troubleshooting" (New-Object System.Drawing.Point(35, 185)) $Scripts.WindowsTroubleshooting
Add-Button "System Optimisation" (New-Object System.Drawing.Point(165, 185)) $Scripts.SystemOptimisation

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
# Created by Chris Masters