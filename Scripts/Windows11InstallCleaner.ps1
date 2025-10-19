#Windows 11 Install cleaner for MDT,SCCM or Home Install
#The cleaner will affect the computer not user so do bare that in mind if someone else wants to use the pc
#This script is safe and does not cause irreversable damage (unlike the other "decrapifier" scripts I have dealt with)

#Sets name and sets the current switch + parameters for applications
[cmdletbinding(DefaultParameterSetName="Windows11Cleaner")]
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
    "Microsoft.GamingApp"
    "Microsoft.XboxGameOverlay"
    "Microsoft.XboxGamingOverlay"
    "Microsoft.XboxIdentityProvider"
    "Microsoft.Xbox.TCUI"
    "Microsoft.XboxSpeechToTextOverlay"
    "Microsoft.YourPhone"
    "Microsoft.Windows.DevHome"
    "Microsoft.Windows.CallingShellApp"
    "Microsoft.PowerAutomateDesktop"
    "Microsoft.WindowsAlarms"
    "Microsoft.WindowsCalculator"
    "Microsoft.WindowsSoundRecorder"
    "Microsoft.Windows.Photos"
    "Microsoft.WindowsMaps"
    "Microsoft.MicrosoftSolitaireCollection"
    "Microsoft.Windows.DevHome"
    "Microsoft.Windows.FeedbackHub"
    "Microsoft.UI.Xaml.*"
    "Clipchamp.Clipchamp"
    "Microsoft.MicrosoftEdgeDevToolsClient"
    "Microsoft.PeopleExperienceHost"
    "Microsoft.GetHelp"
    "Microsoft.Windows.StartMenuExperienceHost"
    "Microsoft.Windows.CloudExperienceHost"
    "Microsoft.Windows.ScreenSketch"
    # Windows 11 23H2 and newer apps
    "Microsoft.PowerBI"
    "Microsoft.549981C3F5F10" # Cortana
    "Microsoft.MicrosoftTeams"
)

#delete all that is named with improved error handling and logging
foreach ($ProvisionedAppName in $ProvisionedAppPackageNames) {
    Write-Host "Processing app: $ProvisionedAppName" -ForegroundColor Yellow
    
    try {
        # Remove for current user
        $currentUserApps = Get-AppxPackage -Name $ProvisionedAppName -ErrorAction SilentlyContinue
        if ($currentUserApps) {
            foreach ($app in $currentUserApps) {
                Write-Host "Removing $($app.Name) for current user..." -ForegroundColor Cyan
                Remove-AppxPackage -Package $app.PackageFullName -ErrorAction SilentlyContinue
            }
        }
        
        # Remove for all users (requires admin)
        $allUserApps = Get-AppxPackage -Name $ProvisionedAppName -AllUsers -ErrorAction SilentlyContinue
        if ($allUserApps) {
            foreach ($app in $allUserApps) {
                Write-Host "Removing $($app.Name) for all users..." -ForegroundColor Cyan
                Remove-AppxPackage -Package $app.PackageFullName -AllUsers -ErrorAction SilentlyContinue
            }
        }
        
        # NOTE: Provisioned packages are NOT removed to allow reinstallation via "Reinstall Default Apps" button
        # If you want to permanently remove apps from the system image, uncomment the lines below:
        # $provisionedApps = Get-AppXProvisionedPackage -Online | Where-Object DisplayName -Like "*$ProvisionedAppName*"
        # if ($provisionedApps) {
        #     foreach ($app in $provisionedApps) {
        #         Write-Host "Removing provisioned package: $($app.DisplayName)..." -ForegroundColor Cyan
        #         Remove-AppxProvisionedPackage -Online -PackageName $app.PackageName -ErrorAction SilentlyContinue
        #     }
        # }
        
    } catch {
        Write-Warning "Failed to process $ProvisionedAppName`: $_"
    }
}

#Disable services
Function DisService {
    If ($leaveservices) {
        Write-Host "***Leaveservices switch set - leaving services enabled...***"
    }
    Else {
        Write-Host "***Stopping and disabling diagnostics tracking services, telemetry, Xbox services, and other unnecessary services for Windows 11...***"
        
        # Modern Windows 11 services to disable
        $servicesToDisable = @(
            'DiagTrack',                    # Connected User Experiences and Telemetry
            'dmwappushservice',             # WAP Push Message Routing Service
            'OneSyncSvc',                   # Sync Host (can break mail sync if used)
            'XblAuthManager',               # Xbox Live Auth Manager
            'XblGameSave',                  # Xbox Live Game Save Service
            'XboxNetApiSvc',                # Xbox Live Networking Service
            'XboxGipSvc',                   # Xbox Accessory Management Service
            'WMPNetworkSvc',                # Windows Media Player Network Sharing Service
            'WSearch',                      # Windows Search (optional - affects search)
            'TrkWks',                       # Distributed Link Tracking Client
            'WbioSrvc',                     # Windows Biometric Service (optional)
            'WerSvc',                       # Windows Error Reporting Service
            'Themes',                       # Themes (optional for performance)
            'TabletInputService',           # Touch Keyboard and Handwriting Panel Service
            'RetailDemo',                   # Retail Demo Service
            'wisvc',                        # Windows Insider Service
            'MapsBroker',                   # Downloaded Maps Manager
            'lfsvc',                        # Geolocation Service
            'SEMgrSvc',                     # Payments and NFC/SE Manager
            'WpcMonSvc',                    # Parental Controls
            'Fax',                          # Fax Service
            'DusmSvc'                       # Data Usage
        )
        
        foreach ($service in $servicesToDisable) {
            try {
                $svc = Get-Service -Name $service -ErrorAction SilentlyContinue
                if ($svc) {
                    Write-Host "Processing service: $service" -ForegroundColor Yellow
                    if ($svc.Status -eq 'Running') {
                        Stop-Service -Name $service -Force -ErrorAction SilentlyContinue
                        Write-Host "  Stopped $service" -ForegroundColor Green
                    }
                    Set-Service -Name $service -StartupType Disabled -ErrorAction SilentlyContinue
                    Write-Host "  Disabled $service" -ForegroundColor Green
                } else {
                    Write-Host "  Service $service not found" -ForegroundColor Gray
                }
            } catch {
                Write-Warning "Failed to process service $service`: $_"
            }
        }
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
Exit
#Created By Chris Masters