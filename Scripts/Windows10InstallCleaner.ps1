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
[System.Windows.MessageBox]::Show('Operation Completed','Windows Troubleshooting','Ok','Information')
Exit
#Created By Chris Masters