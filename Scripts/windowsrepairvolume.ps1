Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Clear-Host
#Scan and repair the selected drive letter, all drives for windows have been added, no real customisation is needed past this point
#Type Loader
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName PresentationFramework
function Show-Console
{
    param ([Switch]$Show,[Switch]$Hide)
    if (-not ("Console.Window" -as [type])) { 

        Add-Type -Name Window -Namespace Console -MemberDefinition '
        [DllImport("Kernel32.dll")]
        public static extern IntPtr GetConsoleWindow();

        [DllImport("user32.dll")]
        public static extern bool ShowWindow(IntPtr hWnd, Int32 nCmdShow);
        '
    }
    if ($Show)
    {
        $consolePtr = [Console.Window]::GetConsoleWindow()
        $null = [Console.Window]::ShowWindow($consolePtr, 5)
    }
    if ($Hide)
    {
        $consolePtr = [Console.Window]::GetConsoleWindow()
        #0 hide
        $null = [Console.Window]::ShowWindow($consolePtr, 0)
    }
}
#end of powershell console hiding
#To show the console change "-hide" to "-show"
show-console -hide

#Functions

# Modern volume repair function for Windows 10/11
function Start-VolumeRepair {
    param([string]$DriveLetter)
    
    try {
        Write-Host "Starting volume scan and repair for drive $DriveLetter..." -ForegroundColor Cyan
        
        # Verify the drive exists
        $drive = Get-Volume -DriveLetter $DriveLetter -ErrorAction SilentlyContinue
        if (-not $drive) {
            [System.Windows.Forms.MessageBox]::Show("Drive $DriveLetter not found or inaccessible.", "Error", 'OK', 'Error')
            return
        }
        
        # Check if it's the system drive
        $systemDrive = $env:SystemDrive.TrimEnd(':')
        $isSystemDrive = ($DriveLetter -eq $systemDrive)
        
        if ($isSystemDrive) {
            $choice = [System.Windows.Forms.MessageBox]::Show(
                "You selected the system drive ($DriveLetter). This may require a reboot to complete the scan. Continue?", 
                "System Drive Detected", 
                'YesNo', 
                'Warning'
            )
            
            if ($choice -eq 'No') {
                Write-Host "Operation cancelled for system drive" -ForegroundColor Yellow
                return
            }
        }
        
        # Create progress dialog
        $progressForm = New-Object System.Windows.Forms.Form
        $progressForm.Text = "Volume Repair - Drive $DriveLetter"
        $progressForm.Size = New-Object System.Drawing.Size(450, 150)
        $progressForm.StartPosition = 'CenterScreen'
        $progressForm.FormBorderStyle = 'FixedDialog'
        $progressForm.MaximizeBox = $false
        $progressForm.MinimizeBox = $false
        
        $progressLabel = New-Object System.Windows.Forms.Label
        $progressLabel.Text = "Scanning and repairing drive $DriveLetter - Please wait..."
        $progressLabel.Location = New-Object System.Drawing.Point(20, 20)
        $progressLabel.Size = New-Object System.Drawing.Size(400, 20)
        $progressForm.Controls.Add($progressLabel)
        
        $progressBar = New-Object System.Windows.Forms.ProgressBar
        $progressBar.Location = New-Object System.Drawing.Point(20, 50)
        $progressBar.Size = New-Object System.Drawing.Size(400, 20)
        $progressBar.Style = 'Marquee'
        $progressBar.MarqueeAnimationSpeed = 50
        $progressForm.Controls.Add($progressBar)
        
        $statusLabel = New-Object System.Windows.Forms.Label
        $statusLabel.Text = "Initializing scan..."
        $statusLabel.Location = New-Object System.Drawing.Point(20, 80)
        $statusLabel.Size = New-Object System.Drawing.Size(400, 20)
        $progressForm.Controls.Add($statusLabel)
        
        $progressForm.Show()
        $progressForm.Update()
        
        # Use modern PowerShell cmdlets for volume repair
        if ($isSystemDrive) {
            # For system drive, schedule check on next reboot
            $statusLabel.Text = "Scheduling system drive check for next reboot..."
            $progressForm.Update()
            
            $job = Start-Job -ScriptBlock {
                param($letter)
                # Use chkdsk with modern parameters
                $result = chkdsk "${letter}:" /f /r /x
                return $result
            } -ArgumentList $DriveLetter
            
            # Wait a bit to show the scheduling message
            Start-Sleep -Seconds 2
            
            $choice2 = [System.Windows.Forms.MessageBox]::Show(
                "System drive check has been scheduled. Would you like to reboot now to run the check?", 
                "Reboot Required", 
                'YesNo', 
                'Question'
            )
            
            if ($choice2 -eq 'Yes') {
                Restart-Computer -Force
            }
            
        } else {
            # For non-system drives, run immediate scan
            $statusLabel.Text = "Running file system check..."
            $progressForm.Update()
            
            $job = Start-Job -ScriptBlock {
                param($letter)
                try {
                    # Use Repair-Volume cmdlet (Windows 8+)
                    if (Get-Command "Repair-Volume" -ErrorAction SilentlyContinue) {
                        $result = Repair-Volume -DriveLetter $letter -OfflineScanAndFix -Verbose
                        return $result
                    } else {
                        # Fallback to chkdsk
                        $result = chkdsk "${letter}:" /f /r /x
                        return $result
                    }
                } catch {
                    return "Error: $_"
                }
            } -ArgumentList $DriveLetter
            
            # Monitor job progress
            $timeout = 0
            while ($job.State -eq 'Running' -and $timeout -lt 1800) { # 30 minute timeout
                Start-Sleep -Seconds 5
                $timeout += 5
                $statusLabel.Text = "Scanning and repairing... ($([math]::Round($timeout/60, 1)) minutes elapsed)"
                $progressForm.Update()
                [System.Windows.Forms.Application]::DoEvents()
            }
            
            if ($job.State -eq 'Running') {
                Stop-Job $job
                Write-Warning "Volume repair timed out after 30 minutes"
                $statusLabel.Text = "Operation timed out - check may still be running in background"
            } else {
                $result = Receive-Job $job
                Write-Host "Volume repair completed for drive $DriveLetter" -ForegroundColor Green
                Write-Host "Results: $result" -ForegroundColor Cyan
            }
            
            Remove-Job $job -Force -ErrorAction SilentlyContinue
        }
        
        $progressForm.Close()
        $progressForm.Dispose()
        
    } catch {
        Write-Warning "Volume repair failed for drive $DriveLetter : $_"
        if ($progressForm) {
            $progressForm.Close()
            $progressForm.Dispose()
        }
    }
}

#Create form containing all the buttons to the commands set above
[System.Windows.Forms.MessageBox]::Show('When you select a drive the Scanning will run in the background or ask to reboot (If system drive has been selected), check task manager for disk usage if your worried it is not doing anything','Windows Volume Check','Ok','Warning') | Out-Null
$form = New-Object System.Windows.Forms.Form
$form.Text = 'Windows Volume Check'
$form.StartPosition = 'CenterScreen'
$form.Size = New-Object System.Drawing.Size(310,350)
$objIcon = New-Object system.drawing.icon (".\Assets\windowslogo.ico")
$form.Icon = $objIcon

#Create a list box to display the drive information
$listBox = New-Object System.Windows.Forms.ListBox
$listBox.Dock = "Fill"
$listBox.Font = New-Object System.Drawing.Font("Consolas", 12)
$form.Controls.Add($listBox)

#Execute code when selecting a drive
$listBox.Add_SelectedIndexChanged({
    $SelectedDrive = $listBox.SelectedItem
    Start-VolumeRepair -DriveLetter $SelectedDrive
})

#Get Connected drives information + sort via name
$ListedDrives = Get-PSDrive -PSProvider FileSystem
$DriveInformation = $ListedDrives | Select-Object Name

#Add the drive information to the list box
foreach ($Drive in $DriveInformation) {
    $listBox.Items.Add("Drive - $($Drive.Name):")
}

$form.showdialog()
Exit
#Created by Chris Masters