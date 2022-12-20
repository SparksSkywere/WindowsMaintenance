#Set Powershell Attribute
Set-ExecutionPolicy Bypass -Force
Clear-Host
#Windows Cleaner Launcher of my other PS1 scripts to create a large form of options

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

#Functions
function RestartNeeded () {
    [System.Windows.MessageBox]::Show('Please restart the computer','Windows Maintenance','Ok','Information')
}
function ExecutionCompleted () {
    [System.Windows.MessageBox]::Show('Operation Completed','Windows Maintenance','Ok','Information')
}

#Script path locations for loading
    #Scriptname = {filename+path/command}
    $WindowsInstallCleanup = {.\Scripts\Windows10InstallCleaner.ps1}
    $WindowsUninstallOneDrive = {.\Scripts\Uninstallonedrive.ps1}
    $WindowsDiskCleanup = {cleanmgr /tuneup:1 | ExecutionCompleted}
    $Usercleanup = {.\Scripts\UserCleaner.ps1}
    $Defrag = {.\Scripts\windowsdefrag.ps1}
    $DiskCheck = {.\Scripts\windowsrepairvolume.ps1}
    $ReinstallApps = {Get-AppXPackage -AllUsers | ForEach-Object {Add-AppxPackage -DisableDevelopmentMode -Register "$($_.InstallLocation)\AppXManifest.xml"} | ExecutionCompleted}
    $DelProf = {.\Scripts\Delprof.exe /u /q | ExecutionCompleted}
    $DISMRestore = {DISM /Online /Cleanup-Image /ScanHealth | DISM /Online /cleanup-Image /Restorehealth | ExecutionCompleted}
    $SFCRepair = {sfc /scannow | ExecutionCompleted}
    $WindowsTroubleshooting = {.\Scripts\Troubleshooting.ps1}
    $SystemOptimisation = {.\Scripts\SystemOptimisation.ps1}
    #$CustomChanges = {.\Scripts\CustomChanges.ps1}

#Form GUI for loading
 #Create Form to show selection of cleanup
    $Form = New-Object System.Windows.Forms.Form
    $form.Text = 'Windows Maintenance'
    $form.Size = New-Object System.Drawing.Size(370,350)
    $form.StartPosition = 'CenterScreen'
    $objIcon = New-Object system.drawing.icon (".\Assets\windowslogo.ico")
    $form.Icon = $objIcon

    $FormText = New-Object System.Windows.Forms.Label
    $FormText.Location = New-Object System.Drawing.Point(35,10)
    $FormText.Size = New-Object System.Drawing.Size(300,18)
    $FormText.Text = 'Select Options Below, these do run in silent mode'
#Cleanup Install button
    $Cleanupinstallbutton = New-Object System.Windows.Forms.Button
    $Cleanupinstallbutton.Location = New-Object System.Drawing.Size(35,35)
    $Cleanupinstallbutton.Size = New-Object System.Drawing.Size(120,23)
    $Cleanupinstallbutton.Text = "Fresh Install Cleanup"
    $Cleanupinstallbutton.Add_Click($WindowsInstallCleanup)
#Re-Install Default Apps button
    $ReinstallDefaultAppsbutton = New-Object System.Windows.Forms.Button
    $ReinstallDefaultAppsbutton.Location = New-Object System.Drawing.Size(165,35)
    $ReinstallDefaultAppsbutton.Size = New-Object System.Drawing.Size(130,23)
    $ReinstallDefaultAppsbutton.Text = "Reinstall Default Apps"
    $ReinstallDefaultAppsbutton.Add_Click($ReinstallApps)
#Uninstall OneDrive
    $OneDriveUninstallbutton = New-Object System.Windows.Forms.Button
    $OneDriveUninstallbutton.Location = New-Object System.Drawing.Size(35,65)
    $OneDriveUninstallbutton.Size = New-Object System.Drawing.Size(120,23)
    $OneDriveUninstallbutton.Text = "Uninstall OneDrive"
    $OneDriveUninstallbutton.Add_Click($WindowsUninstallOneDrive)
#Disk Cleanup Utility Button
    $Diskcleanupbutton = New-Object System.Windows.Forms.Button
    $Diskcleanupbutton.Location = New-Object System.Drawing.Size(35,95)
    $Diskcleanupbutton.Size = New-Object System.Drawing.Size(120,23)
    $Diskcleanupbutton.Text = "Disk Cleanup Silent"
    $Diskcleanupbutton.Add_Click($WindowsDiskCleanup)
#Delprof Cleanup Button
    $Delprofbutton = New-Object System.Windows.Forms.Button
    $Delprofbutton.Location = New-Object System.Drawing.Size(165,65)
    $Delprofbutton.Size = New-Object System.Drawing.Size(130,23)
    $Delprofbutton.Text = "Delete All user profiles"
    $Delprofbutton.Add_Click($DelProf)
#User Cleanup Utility
    $usercleanupbutton = New-Object System.Windows.Forms.Button
    $usercleanupbutton.Location = New-Object System.Drawing.Size(35,125)
    $usercleanupbutton.Size = New-Object System.Drawing.Size(120,23)
    $usercleanupbutton.Text = "User Cleanup"
    $usercleanupbutton.Add_Click($Usercleanup)
#DISM Restore
    $Restorehealthbutton = New-Object System.Windows.Forms.Button
    $Restorehealthbutton.Location = New-Object System.Drawing.Size(165,95)
    $Restorehealthbutton.Size = New-Object System.Drawing.Size(130,23)
    $Restorehealthbutton.Text = "DISM Restore Health"
    $Restorehealthbutton.Add_Click($DISMRestore)
#Defragmentation Utility
    $Defragbutton = New-Object System.Windows.Forms.Button
    $Defragbutton.Location = New-Object System.Drawing.Size(35,155)
    $Defragbutton.Size = New-Object System.Drawing.Size(120,23)
    $Defragbutton.Text = "Defrag"
    $Defragbutton.Add_Click($Defrag)
#Disk Check Utility
    $DiskCheckbutton = New-Object System.Windows.Forms.Button
    $DiskCheckbutton.Location = New-Object System.Drawing.Size(165,155)
    $DiskCheckbutton.Size = New-Object System.Drawing.Size(130,23)
    $DiskCheckbutton.Text = "Disk Check"
    $DiskCheckbutton.Add_Click($DiskCheck)
#System Repair Utility
    $SFCRepairbutton = New-Object System.Windows.Forms.Button
    $SFCRepairbutton.Location = New-Object System.Drawing.Size(165,125)
    $SFCRepairbutton.Size = New-Object System.Drawing.Size(130,23)
    $SFCRepairbutton.Text = "System Repair Scan"
    $SFCRepairbutton.Add_Click($SFCRepair)
#Troubleshooting Issues
    $Troubleshootbutton = New-Object System.Windows.Forms.Button
    $Troubleshootbutton.Location = New-Object System.Drawing.Size(35,185)
    $Troubleshootbutton.Size = New-Object System.Drawing.Size(120,23)
    $Troubleshootbutton.Text = "Troubleshooting"
    $Troubleshootbutton.Add_Click($WindowsTroubleshooting)
#Windows Optimisation
    $OptimisationButton = New-Object System.Windows.Forms.Button
    $OptimisationButton.Location = New-Object System.Drawing.Size(165,185)
    $OptimisationButton.Size = New-Object System.Drawing.Size(130,23)
    $OptimisationButton.Text = "System Optimisation"
    $OptimisationButton.Add_Click($SystemOptimisation)
#Custom Changes
    #$Customchangesbutton = New-Object System.Windows.Forms.Button
    #$Customchangesbutton.Location = New-Object System.Drawing.Size(165,155)
    #$Customchangesbutton.Size = New-Object System.Drawing.Size(130,23)
    #$Customchangesbutton.Text = "Custom Changes"
    #$Customchangesbutton.Add_Click($CustomChanges)
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
    $Form.Controls.Add($Cleanupinstallbutton)
    $Form.Controls.Add($OneDriveUninstallbutton)
    $Form.Controls.Add($ReinstallDefaultAppsbutton)
    $Form.Controls.Add($Diskcleanupbutton)
    $Form.Controls.Add($Delprofbutton)
    $Form.Controls.Add($usercleanupbutton)
    $Form.Controls.Add($Restorehealthbutton)
    $Form.Controls.Add($Defragbutton)
    $Form.Controls.Add($DiskCheckbutton)
    $Form.Controls.Add($SFCRepairbutton)
    $Form.Controls.Add($Troubleshootbutton)
    $Form.Controls.Add($OptimisationButton)
    #$Form.Controls.Add($Customchangesbutton)
#Null command to stop console spam
    $Form.ShowDialog() > $null

#Created By Chris Masters