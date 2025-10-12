Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Clear-Host
#Defragmenting the selected drive letter, all drives for windows have been added, no real customisation is needed past this point
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

# Cache drive information at startup
$driveCache = Get-PSDrive -PSProvider FileSystem | 
    Where-Object { $_.Free -gt 0 -and $_.Used -gt 0 } |
    Select-Object Name, Root, @{N='Type';E={(Get-PhysicalDisk | Where-Object DeviceId -eq $_.Root.TrimEnd('\'))).MediaType}}

# Modern defrag function with SSD detection for Windows 10/11
function Start-OptimizedDefrag {
    param([string]$DriveLetter)
    
    try {
        Write-Host "Analyzing drive $DriveLetter..." -ForegroundColor Cyan
        
        # Get drive information using modern PowerShell cmdlets
        $drive = Get-Volume -DriveLetter $DriveLetter -ErrorAction SilentlyContinue
        if (-not $drive) {
            Show-MessageBox "Drive $DriveLetter not found or inaccessible."
            return
        }
        
        # Check if drive is SSD using Get-PhysicalDisk
        $partition = Get-Partition -DriveLetter $DriveLetter -ErrorAction SilentlyContinue
        if ($partition) {
            $disk = Get-PhysicalDisk -DeviceNumber $partition.DiskNumber -ErrorAction SilentlyContinue
            if ($disk -and $disk.MediaType -eq 'SSD') {
                $choice = [System.Windows.Forms.MessageBox]::Show(
                    "Drive $DriveLetter appears to be an SSD. SSDs don't benefit from defragmentation but can be optimized with TRIM. Would you like to optimize instead?", 
                    "SSD Detected", 
                    'YesNo', 
                    'Question'
                )
                
                if ($choice -eq 'Yes') {
                    Write-Host "Optimizing SSD drive $DriveLetter with TRIM..." -ForegroundColor Green
                    Optimize-Volume -DriveLetter $DriveLetter -ReTrim -Verbose
                } else {
                    Write-Host "Operation cancelled for SSD drive $DriveLetter" -ForegroundColor Yellow
                }
                return
            }
        }
        
        # For traditional HDDs, proceed with defragmentation
        Write-Host "Traditional HDD detected. Starting defragmentation..." -ForegroundColor Green
        
        # Check fragmentation level first
        $analysis = Optimize-Volume -DriveLetter $DriveLetter -Analyze -Verbose
        
        # Show progress dialog
        $progressForm = New-Object System.Windows.Forms.Form
        $progressForm.Text = "Defragmenting Drive $DriveLetter"
        $progressForm.Size = New-Object System.Drawing.Size(400, 120)
        $progressForm.StartPosition = 'CenterScreen'
        $progressForm.FormBorderStyle = 'FixedDialog'
        $progressForm.MaximizeBox = $false
        $progressForm.MinimizeBox = $false
        
        $progressLabel = New-Object System.Windows.Forms.Label
        $progressLabel.Text = "Defragmenting drive $DriveLetter - Please wait..."
        $progressLabel.Location = New-Object System.Drawing.Point(20, 20)
        $progressLabel.Size = New-Object System.Drawing.Size(350, 20)
        $progressForm.Controls.Add($progressLabel)
        
        $progressBar = New-Object System.Windows.Forms.ProgressBar
        $progressBar.Location = New-Object System.Drawing.Point(20, 50)
        $progressBar.Size = New-Object System.Drawing.Size(350, 20)
        $progressBar.Style = 'Marquee'
        $progressBar.MarqueeAnimationSpeed = 50
        $progressForm.Controls.Add($progressBar)
        
        $progressForm.Show()
        $progressForm.Update()
        
        # Start defragmentation as a background job for better responsiveness
        $job = Start-Job -ScriptBlock {
            param($letter)
            Optimize-Volume -DriveLetter $letter -Defrag -Verbose
        } -ArgumentList $DriveLetter
        
        # Monitor job progress
        while ($job.State -eq 'Running') {
            Start-Sleep -Seconds 2
            $progressForm.Update()
            [System.Windows.Forms.Application]::DoEvents()
        }
        
        $result = Receive-Job $job
        Remove-Job $job
        
        $progressForm.Close()
        $progressForm.Dispose()
        
        Write-Host "Defragmentation of drive $DriveLetter completed successfully!" -ForegroundColor Green
        
    } catch {
        Write-Warning "Defragmentation failed for drive $DriveLetter : $_"
        if ($progressForm) {
            $progressForm.Close()
            $progressForm.Dispose()
        }
    }
}

#Functions
function ExecutionCompleted () {
    [System.Windows.MessageBox]::Show('Defragmentation Completed','Windows Troubleshooting','Ok','Information')
}

#Create form containing all the buttons to the commands set above
[System.Windows.MessageBox]::Show('When you select a drive the defrag will run in the background, check task manager for disk usage. DO NOT USE THIS PROGRAM FOR SSD!','Windows Quick Defrag','Ok','Warning') | Out-Null
$form = New-Object System.Windows.Forms.Form
$form.Text = 'Windows Quick Defrag'
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
    Start-OptimizedDefrag -DriveLetter $SelectedDrive | ExecutionCompleted
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