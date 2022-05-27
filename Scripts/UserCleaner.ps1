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

#Cleanup commands and locations
$Cleanup_CTemp = {Get-ChildItem -Path 'C:\Windows\Temp' * -Recurse | Remove-Item}
$Cleanup_Prefetch = {Get-ChildItem -Path 'C:\Windows\Prefetch' * -Recurse | Remove-Item}
$Cleanup_DSLocal = {Get-ChildItem -Path 'C:\Documents and Settings\*\Local Settings\temp\' * -Recurse | Remove-Item}
$Cleanup_Appdata = {Get-ChildItem -Path 'C:\Users\*\Appdata\Local\Temp\' * -Recurse | Remove-Item}

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

    $Form.Controls.Add($CleanupCbutton)
    $Form.Controls.Add($CleanupPrefetchbutton)
    $Form.Controls.Add($ClearDSbutton)
    $Form.Controls.Add($ClearAppdatabutton)

$form.showdialog()

Exit
#Created by Chris Masters