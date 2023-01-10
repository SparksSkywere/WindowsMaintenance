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
function ExecutionCompleted () {
    [System.Windows.MessageBox]::Show('Volume Scan and Repair Completed','Windows Maintenance','Ok','Information')
}

#Create form containing all the buttons to the commands set above
[System.Windows.MessageBox]::Show('When you select a drive the Scanning will run in the background or ask to reboot (If system drive has been selected), check task manager for disk usage if your worried it is not doing anything','Windows Volume Check','Ok','Warning') | Out-Null
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
    Repair-Volume -DriveLetter $SelectedDrive -OfflineScanAndFix | ExecutionCompleted
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