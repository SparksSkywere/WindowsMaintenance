Set-ExecutionPolicy Bypass -Force
Clear-Host
#Troubleshooting powershell script to help with shortcut troubleshooting or general known fixes

#Type Loader
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName System.Drawing

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

#Commands for the buttons
    #$Commandname = {Command}
    $TroubleInternetbutton = {}
    $TroubleWindowsUpdatesbutton = {}
    $TroubleStorebutton = {}

#Troubleshooting form
 $Form = New-Object System.Windows.Forms.Form
 $form.Text = 'Windows Troubleshooting'
 $form.Size = New-Object System.Drawing.Size(370,350)
 $form.StartPosition = 'CenterScreen'
 $objIcon = New-Object system.drawing.icon (".\Assets\windowslogo.ico")
 $form.Icon = $objIcon

 $FormText = New-Object System.Windows.Forms.Label
 $FormText.Location = New-Object System.Drawing.Point(35,10)
 $FormText.Size = New-Object System.Drawing.Size(300,18)
 $FormText.Text = 'Troubleshooting runs in silent mode'
 
 $TroubleInternetbutton = New-Object System.Windows.Forms.Button
 $TroubleInternetbutton.Location = New-Object System.Drawing.Size(35,35)
 $TroubleInternetbutton.Size = New-Object System.Drawing.Size(120,23)
 $TroubleInternetbutton.Text = "Internet Connection"
 $TroubleInternetbutton.Add_Click($TroubleInternet)

 $TroubleWindowsUpdatesbutton = New-Object System.Windows.Forms.Button
 $TroubleWindowsUpdatesbutton.Location = New-Object System.Drawing.Size(165,35)
 $TroubleWindowsUpdatesbutton.Size = New-Object System.Drawing.Size(120,23)
 $TroubleWindowsUpdatesbutton.Text = "Windows Updates"
 $TroubleWindowsUpdatesbutton.Add_Click($TroubleWindowsUpdates)

 $TroubleStorebutton = New-Object System.Windows.Forms.Button
 $TroubleStorebutton.Location = New-Object System.Drawing.Size(35,65)
 $TroubleStorebutton.Size = New-Object System.Drawing.Size(120,23)
 $TroubleStorebutton.Text = "Microsoft Store"
 $TroubleStorebutton.Add_Click($TroubleStore)

#Exit Button
 $exitButton = New-Object System.Windows.Forms.Button
 $exitButton.Location = New-Object System.Drawing.Point(135,270)
 $exitButton.Size = New-Object System.Drawing.Size(75,23)
 $exitButton.Text = 'Exit'
 $exitButton.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
 $form.CancelButton = $exitButton
 $form.Controls.Add($exitButton)

#Add buttons
 $Form.Controls.Add($FormText)
 $Form.Controls.Add($TroubleInternetbutton)
 $Form.Controls.Add($TroubleWindowsUpdatesbutton)
 $Form.Controls.Add($TroubleStorebutton)

#Null command to stop console spam
 $Form.ShowDialog() > $null

Exit
#Made by Chris Masters