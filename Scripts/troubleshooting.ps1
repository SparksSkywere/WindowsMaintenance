#Set Powershell Attribute
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

#Functions
function RestartNeeded () {
    [System.Windows.MessageBox]::Show('Please restart the computer','Windows Troubleshooting','Ok','Information')
}

function ExecutionCompleted () {
    [System.Windows.MessageBox]::Show('Operation Completed','Windows Troubleshooting','Ok','Information')
}

#$scriptPath = split-path -parent $MyInvocation.MyCommand.Definition
#Functions to split lots of the work up into more readable bits / easier to configure
#MaxReg
function Maxpathreg () {Set-ItemProperty 'HKLM:\System\CurrentControlSet\Control\FileSystem' -Name 'LongPathsEnabled' -value 1}
#Troubleshooting Internet
function AdvFirewallReset () {netsh advfirewall reset}
function netshipreset () {netsh int ip reset}
function netshipresetipv6 () {netsh int ipv6 reset}
function netwinsockreset () {netsh winsock reset}
function flushdns () {IPconfig /flushdns}
function iprelease () {IPconfig /release}
function iprenew () {IPConfig /Renew}
#Troubleshooting Windows Updates
function netstopbits () {net stop bits}
function netstopwuauserv () {net stop wuauserv}
function netstopappidsvc () {net stop appidsvc}
function netstopcryptsvc () {net stop cryptsvc}
function DeleteSoftwareDistribution () {Get-ChildItem -Path '%systemroot%\SoftwareDistribution' * -Recurse | Remove-Item}
function Deletecatroot2 () {Get-ChildItem -Path '%systemroot%\system32\catroot2' * -Recurse | Remove-Item}
function associateatl () {regsvr32.exe /s atl.dll}
function associateurlmon () {regsvr32.exe /s urlmon.dll}
function associatemshtml () {regsvr32.exe /s mshtml.dll}
function associateshdocvw () {regsvr32.exe /s shdocvw.dll}
function associatebrowseui () {regsvr32.exe /s browseui.dll}
function associatejscript () {regsvr32.exe /s jscript.dll}
function associatevbscript () {regsvr32.exe /s vbscript.dll}
function associatescrrun () {regsvr32.exe /s scrrun.dll}
function associatemsxml () {regsvr32.exe /s msxml.dll}
function associatemsxml3 () {regsvr32.exe /s msxml3.dll}
function associatemsxm16 () {regsvr32.exe /s msxml6.dll}
function associateactxprxy () {regsvr32.exe /s actxprxy.dll}
function associatesoftpub () {regsvr32.exe /s softpub.dll}
function associatewintrust () {regsvr32.exe /s wintrust.dll}
function associatedssenh () {regsvr32.exe /s dssenh.dll}
function associatersaenh () {regsvr32.exe /s rsaenh.dll}
function associategpkcsp () {regsvr32.exe /s gpkcsp.dll}
function associatesccbase () {regsvr32.exe /s sccbase.dll}
function associateslbcsp () {regsvr32.exe /s slbcsp.dll}
function associatecryptdlg () {regsvr32.exe /s cryptdlg.dll}
function associateoleaut32 () {regsvr32.exe /s oleaut32.dll}
function associateole32 () {regsvr32.exe /s ole32.dll}
function associateshell32 () {regsvr32.exe /s shell32.dll}
function associateinitpki () {regsvr32.exe /s initpki.dll}
function associatewuapi () {regsvr32.exe /s wuapi.dll}
function associatewuaueng () {regsvr32.exe /s wuaueng.dll}
function associatewuaueng1 () {regsvr32.exe /s wuaueng1.dll}
function associatewucltui () {regsvr32.exe /s wucltui.dll}
function associatewups () {regsvr32.exe /s wups.dll}
function associatewups2 () {regsvr32.exe /s wups2.dll}
function associatewuweb () {regsvr32.exe /s wuweb.dll}
function associateqmgr () {regsvr32.exe /s qmgr.dll}
function associateqmgrprxy () {regsvr32.exe /s qmgrprxy.dll}
function associatewucltux () {regsvr32.exe /s wucltux.dll}
function associatemuweb () {regsvr32.exe /s muweb.dll}
function associatewuwebv () {regsvr32.exe /s wuwebv.dll}
function netwinsockreset () {netsh winsock reset}
function netwinsockproxyreset () {netsh winsock reset proxy}
function netstartbits () {net start bits}
function netstartwuauserv () {net start wuauserv}
function netstartappidsvc () {net start appidsvc}
function netstartcryptsvc () {net start cryptsvc}
function wsusscan () {wuauclt /resetauthorization /detectnow}
#Update 0x800f0922 Fix
function lodctrsync () {lodctr /R | winmgmt.exe /RESYNCPERF}
function trustedinstallerauto () {Get-Service -Name "trustedinstaller" | Set-Service -StartupType Automatic}
function trustedinstallerstart () {net start trustedinstaller}
function DISMRestore () {Dism /Online /Cleanup-Image /RestoreHealth | ExecutionCompleted}

#Commands for the buttons
    #$Commandname = {Command}
    $TroubleInternet = {AdvFirewallReset | netshipreset | netshipresetipv6 | netwinsockreset | flushdns | iprelease | iprenew | ExecutionCompleted}
    $TroubleWindowsUpdates = {netstopbits | netstopwuauserv | netstopappidsvc | netstopcryptsvc | DeleteSoftwareDistribution | Deletecatroot2 | associateatl | associateurlmon | associatemshtml | associateshdocvw | associatebrowseui | associatejscript | associatevbscript | associatescrrun | associatemsxml | associatemsxml3 | associatemsxm16 | associateactxprxy | associatesoftpub | associatewintrust | associatedssenh | associatersaenh | associategpkcsp | associatesccbase | associateslbcsp | associatecryptdlg | associateoleaut32 | associateole32 | associateshell32 | associateinitpki | associatewuapi | associatewuaueng | associatewuaueng1 | associatewucltui | associatewups | associatewups2 | associatewuweb | associateqmgr | associateqmgrprxy | associatewucltux | associatemuweb | associatewuwebv | netwinsockreset | netwinsockproxyreset | netstartbits | netstartwuauserv | netstartappidsvc | netstartcryptsvc | wsusscan | ExecutionCompleted}
    $TroubleStore = {WSReset.exe | ExecutionCompleted}
    $Maxpathreg = {Maxpathreg | ExecutionCompleted}
    $Updateerror0x800f0922fix = {lodctrsync | trustedinstallerauto | trustedinstallerstart | DISMRestore | ExecutionCompleted}
    #$HardwareDeviceTroubleshooter = {msdt.exe -id DeviceDiagnostic}
    #DISM /imageC:\ /Cleanup-Image /RestoreHealth /Source:C:\Windows10\Sources\install.esd /Scratchdir:C:\Scratch

    #$Writeverify = {.\Write-Outputverify.ps1}

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
#Internet Fix
 $TroubleInternetbutton = New-Object System.Windows.Forms.Button
 $TroubleInternetbutton.Location = New-Object System.Drawing.Size(35,35)
 $TroubleInternetbutton.Size = New-Object System.Drawing.Size(120,23)
 $TroubleInternetbutton.Text = "Internet Connection"
 $TroubleInternetbutton.Add_Click($TroubleInternet)
#Windows Update
 $TroubleWindowsUpdatesbutton = New-Object System.Windows.Forms.Button
 $TroubleWindowsUpdatesbutton.Location = New-Object System.Drawing.Size(165,35)
 $TroubleWindowsUpdatesbutton.Size = New-Object System.Drawing.Size(120,23)
 $TroubleWindowsUpdatesbutton.Text = "Windows Updates"
 $TroubleWindowsUpdatesbutton.Add_Click($TroubleWindowsUpdates)
#Microsoft Store
 $TroubleStorebutton = New-Object System.Windows.Forms.Button
 $TroubleStorebutton.Location = New-Object System.Drawing.Size(35,65)
 $TroubleStorebutton.Size = New-Object System.Drawing.Size(120,23)
 $TroubleStorebutton.Text = "Microsoft Store"
 $TroubleStorebutton.Add_Click($TroubleStore)
#Max Path registry edit
 $Maxpathregbutton = New-Object System.Windows.Forms.Button
 $Maxpathregbutton.Location = New-Object System.Drawing.Size(165,65)
 $Maxpathregbutton.Size = New-Object System.Drawing.Size(120,23)
 $Maxpathregbutton.Text = "Max_Path Regedit"
 $Maxpathregbutton.Add_Click($Maxpathreg)
#Windows Update Error 0x800f0922 Fix
 $Updateerror0x800f0922fixbutton = New-Object System.Windows.Forms.Button
 $Updateerror0x800f0922fixbutton.Location = New-Object System.Drawing.Size(35,95)
 $Updateerror0x800f0922fixbutton.Size = New-Object System.Drawing.Size(120,23)
 $Updateerror0x800f0922fixbutton.Text = "Error_F0922 Fix"
 $Updateerror0x800f0922fixbutton.Add_Click($Updateerror0x800f0922fix)
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
 $Form.Controls.Add($TroubleWindowsUpdatesButton)
 $Form.Controls.Add($TroubleStorebutton)
 $Form.Controls.Add($Maxpathregbutton)
 $Form.Controls.Add($Updateerror0x800f0922fixButton)
#Null command to stop console spam
 $Form.ShowDialog() > $null

Exit
#Made by Chris Masters