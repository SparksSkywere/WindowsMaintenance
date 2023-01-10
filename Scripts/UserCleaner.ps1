Clear-Host
#A real basic script going to locations and then deleting, then going to the next in the line and deleting
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
    [System.Windows.MessageBox]::Show('Operation Completed','Windows Maintenance','Ok','Information')
}

#Cleanup commands and locations
$Cleanup_CTemp = {Get-ChildItem -Path 'C:\Windows\Temp' * -Recurse | Remove-Item | ExecutionCompleted}
$Cleanup_Prefetch = {Get-ChildItem -Path 'C:\Windows\Prefetch' * -Recurse | Remove-Item | ExecutionCompleted}
$Cleanup_DSLocal = {Get-ChildItem -Path 'C:\Documents and Settings\*\Local Settings\temp\' * -Recurse | Remove-Item | ExecutionCompleted}
$Cleanup_Appdata = {Get-ChildItem -Path 'C:\Users\*\Appdata\Local\Temp\' * -Recurse | Remove-Item | ExecutionCompleted}
$CleanupSystem = {CleanupSystem | ExecutionCompleted}
$DoAll = {Get-ChildItem -Path 'C:\Windows\Temp' * -Recurse | Remove-Item | Get-ChildItem -Path 'C:\Windows\Prefetch' * -Recurse | Remove-Item | Get-ChildItem -Path 'C:\Documents and Settings\*\Local Settings\temp\' * -Recurse | Remove-Item | Get-ChildItem -Path 'C:\Users\*\Appdata\Local\Temp\' * -Recurse | Remove-Item | CleanupSystem |ExecutionCompleted}

function CleanupSystem () {
# Declare variables for the folders we want to clean up
$tempFolder = "$env:temp"
$appData = "$env:appdata"
$localAppData = "$env:localappdata"

# Delete temporary files
Get-ChildItem $tempFolder -Include *.* -File -Recurse | Remove-Item

# Delete temporary internet files
Remove-Item "$appData\Microsoft\Windows\INetCache\*" -Recurse -Force

# Delete files in the recycle bin that are older than 30 days
$recycleBin = [Microsoft.VisualBasic.FileIO.RecycleBin]::GetInfo()
foreach($item in $recycleBin) {
    if($item.DeletionTime -lt (Get-Date).AddDays(-30)) {
        [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteFile($item.OriginalLocation, 
            [Microsoft.VisualBasic.FileIO.UIOption]::OnlyErrorDialogs, 
            [Microsoft.VisualBasic.FileIO.RecycleOption]::SendToRecycleBin)
    }
}

# Clear the event logs
Clear-EventLog -LogName Application
Clear-EventLog -LogName Security
Clear-EventLog -LogName System

# Delete files in the temporary AppData folders that are older than 30 days
Get-ChildItem $appData -Include *.* -File -Recurse | Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-30) } | Remove-Item
Get-ChildItem $localAppData -Include *.* -File -Recurse | Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-30) } | Remove-Item
} 

#Form with buttons to area's for cleanup
$form = New-Object System.Windows.Forms.Form
$form.Text = 'Windows User Cleanup'
$form.StartPosition = 'CenterScreen'
$form.Size = New-Object System.Drawing.Size(310,350)
$objIcon = New-Object system.drawing.icon (".\Assets\windowslogo.ico")
$form.Icon = $objIcon

    $CleanupCbutton = New-Object System.Windows.Forms.Button
    $CleanupCbutton.Location = New-Object System.Drawing.Size(25,15)
    $CleanupCbutton.Size = New-Object System.Drawing.Size(135,23)
    $CleanupCbutton.Text = "Clear C Windows Temp"
    $CleanupCbutton.Add_Click($Cleanup_CTemp)

    $CleanupPrefetchbutton = New-Object System.Windows.Forms.Button
    $CleanupPrefetchbutton.Location = New-Object System.Drawing.Size(25,45)
    $CleanupPrefetchbutton.Size = New-Object System.Drawing.Size(135,23)
    $CleanupPrefetchbutton.Text = "Clear Windows Prefetch"
    $CleanupPrefetchbutton.Add_Click($Cleanup_Prefetch)

    $ClearDSbutton = New-Object System.Windows.Forms.Button
    $ClearDSbutton.Location = New-Object System.Drawing.Size(25,75)
    $ClearDSbutton.Size = New-Object System.Drawing.Size(135,23)
    $ClearDSbutton.Text = "Clear Docs and settings local"
    $ClearDSbutton.Add_Click($Cleanup_DSLocal)

    $ClearAppdatabutton = New-Object System.Windows.Forms.Button
    $ClearAppdatabutton.Location = New-Object System.Drawing.Size(25,105)
    $ClearAppdatabutton.Size = New-Object System.Drawing.Size(135,23)
    $ClearAppdatabutton.Text = "Clear Local Appdata"
    $ClearAppdatabutton.Add_Click($Cleanup_Appdata)

    $CleanupSystemButton = New-Object System.Windows.Forms.Button
    $CleanupSystemButton.Location = New-Object System.Drawing.Size(25,135)
    $CleanupSystemButton.Size = New-Object System.Drawing.Size(135,23)
    $CleanupSystemButton.Text = "Cleanup System"
    $CleanupSystemButton.Add_Click($CleanupSystem)

    $DoAllbutton = New-Object System.Windows.Forms.Button
    $DoAllbutton.Location = New-Object System.Drawing.Size(25,165)
    $DoAllbutton.Size = New-Object System.Drawing.Size(135,23)
    $DoAllbutton.Text = "Do All Above"
    $DoAllbutton.Add_Click($DoAll)

    $Form.Controls.Add($CleanupCbutton)
    $Form.Controls.Add($CleanupPrefetchbutton)
    $Form.Controls.Add($ClearDSbutton)
    $Form.Controls.Add($ClearAppdatabutton)
    $Form.Controls.Add($CleanupSystemButton)
    $Form.Controls.Add($DoAllbutton)

$form.showdialog()
Exit
#Created by Chris Masters