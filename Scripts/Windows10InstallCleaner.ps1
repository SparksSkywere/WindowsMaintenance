#Windows 10 Install cleaner for MDT,SCCM or Home Install
#The cleaner will affect the computer not user so do bare that in mind if someone else wants to use the pc
#This script is safe and does not cause irreversable damage (unlike the other "decrapifier" scripts I have dealt with)

#Sets name and sets the current switch + parameters for applications
[cmdletbinding(DefaultParameterSetName="Windows10Cleaner")]
param (
	[switch]$allusers,
	[switch]$allapps,
    [switch]$leavetasks,
    [switch]$leaveservices,
    [switch]$clearstart,
    [Parameter(ParameterSetName="AppsOnly")]
    [switch]$appsonly,
    [Parameter(ParameterSetName="SettingsOnly")]
    [switch]$settingsonly
    )

[System.Windows.MessageBox]::Show('Windows App removal, click Ok to close','Windows Install Cleaner','Ok','Information')
#Applications in a list using package names, feel free to add custom names
$ProvisionedAppPackageNames = @(
    "Microsoft.BingFinance"
    "Microsoft.BingNews"
    "Microsoft.BingSports"
    "Microsoft.BingWeather"
    "Microsoft.MicrosoftOfficeHub"
    "Microsoft.Getstarted"
    "microsoft.windowscommunicationsapps"
    "Microsoft.Office.OneNote"
    "Microsoft.People"
    "Microsoft.SkypeApp"
    "Microsoft.XboxApp"
    "Microsoft.ZuneMusic"
    "Microsoft.ZuneVideo"
    "Microsoft.WindowsMaps"
    "Microsoft.WindowsFeedbackHub"
    "Microsoft.Wallet"
    "Microsoft.People"
    "Microsoft.MixedReality.Portal"
    "Microsoft.GetHelp"
)

#delete all that is named
foreach ($ProvisionedAppName in $ProvisionedAppPackageNames) {
    Get-AppxPackage -Name $ProvisionedAppName -AllUsers | Remove-AppxPackage
    Get-AppXProvisionedPackage -Online | Where-Object DisplayName -EQ $ProvisionedAppName | Remove-AppxProvisionedPackage -Online
}

#Disable services
Function DisService {
    If ($leaveservices) {
        Write-Host "***Leaveservices switch set - leaving services enabled...***"
    }
    Else {
        Write-Host "***Stopping and disabling diagnostics tracking services, Onesync service (syncs contacts, mail, etc, needed for OneDrive), various Xbox services, and Windows Media Player network sharing (you can turn this back on if you share your media libraries with WMP)...***"
        #Diagnostics tracking and xbox services
		Get-Service Diagtrack,OneSyncSvc,XblAuthManager,XblGameSave,XboxNetApiSvc,WMPNetworkSvc -erroraction silentlycontinue | stop-service -passthru | set-service -startuptype disabled
		#WAP Push Message Routing  NOTE Sysprep w/ Generalize WILL FAIL if you disable the DmwApPushService.  Commented out by default.
		#Get-Service DmwApPushService -erroraction silentlycontinue | stop-service -passthru | set-service -startuptype disabled
    }
}

#Registry change functions

#Load default user hive
Function loaddefaulthive {
    reg load "$reglocation" c:\users\default\ntuser.dat
}
#unload default user hive
Function unloaddefaulthive {
    [gc]::collect()
    reg unload "$reglocation"
}

#Set default user settings
Function RegSetUser {
       
    #Disabling Onedrive startup run user settings
    Reg Add "$reglocation\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run" /T REG_BINARY /V "OneDrive" /D 0300000021B9DEB396D7D001 /F
       
}
[System.Windows.MessageBox]::Show('Windows OneDrive Removal, click Ok to close','Windows Install Cleaner','Ok','Information')
#remove OneDrive

Write-Output "OneDrive process and explorer"
taskkill.exe /F /IM "OneDrive.exe"
taskkill.exe /F /IM "explorer.exe"

Write-Output "Remove OneDrive"
if (Test-Path "$env:systemroot\System32\OneDriveSetup.exe") {
    & "$env:systemroot\System32\OneDriveSetup.exe" /uninstall
}
if (Test-Path "$env:systemroot\SysWOW64\OneDriveSetup.exe") {
    & "$env:systemroot\SysWOW64\OneDriveSetup.exe" /uninstall
}

Write-Output "Removing OneDrive leftovers trash"
Remove-Item -Recurse -Force -ErrorAction SilentlyContinue "$env:localappdata\Microsoft\OneDrive"
Remove-Item -Recurse -Force -ErrorAction SilentlyContinue "$env:programdata\Microsoft OneDrive"
Remove-Item -Recurse -Force -ErrorAction SilentlyContinue "C:\OneDriveTemp"

Write-Output "Remove Onedrive from explorer sidebar"
New-PSDrive -PSProvider "Registry" -Root "HKEY_CLASSES_ROOT" -Name "HKCR"
mkdir -Force "HKCR:\CLSID\{018D5C66-4533-4307-9B53-224DE2ED1FE6}"
Set-ItemProperty "HKCR:\CLSID\{018D5C66-4533-4307-9B53-224DE2ED1FE6}" "System.IsPinnedToNameSpaceTree" 0
mkdir -Force "HKCR:\Wow6432Node\CLSID\{018D5C66-4533-4307-9B53-224DE2ED1FE6}"
Set-ItemProperty "HKCR:\Wow6432Node\CLSID\{018D5C66-4533-4307-9B53-224DE2ED1FE6}" "System.IsPinnedToNameSpaceTree" 0
Remove-PSDrive "HKCR"

Write-Output "Removing run option for new users"
reg load "hku\Default" "C:\Users\Default\NTUSER.DAT"
reg delete "HKEY_USERS\Default\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" /v "OneDriveSetup" /f
reg unload "hku\Default"

Write-Output "Removing startmenu junk entry"
Remove-Item -Force -ErrorAction SilentlyContinue "$env:userprofile\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\OneDrive.lnk"

Write-Output "Restarting explorer..."
Start-Process "explorer.exe"

Write-Output "Wait for EX reload.."
Start-Sleep 15

Write-Host ""
If ($appsonly) {
        If ($allapps) {
            RemAllApps

}        Else {
}

}Elseif ($settingsonly) {
         Remtasks
         DisService

}Else {
        If ($allapps) {
            RemAllApps
            DisService
            ClearStartMenu

}        Else {
            DisService
}
}

Exit
#Created By Chris Masters