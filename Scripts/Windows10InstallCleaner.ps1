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

#Applications in a list using package names, feel free to add custom names
$OptimizedAppPackagePatterns = @(
    "Microsoft.BingFinance"
    "Microsoft.BingNews"
    "Microsoft.BingSearch"
    "Microsoft.BingSports"
    "Microsoft.BingWeather"
    "Microsoft.GetHelp"
    "Microsoft.Getstarted"
    "Microsoft.MicrosoftOfficeHub"
    "Microsoft.MicrosoftSolitaireCollection"
    "Microsoft.MicrosoftTeams"
    "Microsoft.MixedReality.Portal"
    "Microsoft.Office.OneNote"
    "Microsoft.OutlookForWindows"
    "Microsoft.People"
    "Microsoft.PowerAutomateDesktop"
    "Microsoft.SkypeApp"
    "Microsoft.Todos"
    "Microsoft.Wallet"
    "Microsoft.Windows.DevHome*"
    "Microsoft.Windows.FeedbackHub"
    "Microsoft.WindowsMaps"
    "Microsoft.WindowsSoundRecorder"
    "Microsoft.Xbox*"
    "Microsoft.YourPhone"
    "Microsoft.ZuneMusic"
    "Microsoft.ZuneVideo"
    "Microsoft.549981C3F5F10"
    "microsoft.windowscommunicationsapps"
    "Clipchamp.Clipchamp"
    "MicrosoftCorporationII.QuickAssist"
    "MSTeams"
)

function Remove-AppPackagesByPattern {
    param([Parameter(Mandatory)][string]$Pattern)

    Write-Host "Processing app pattern: $Pattern" -ForegroundColor Yellow

    try {
        $currentUserApps = Get-AppxPackage -Name $Pattern -ErrorAction SilentlyContinue
        if ($currentUserApps) {
            foreach ($app in $currentUserApps) {
                Write-Host "Removing $($app.Name) for current user..." -ForegroundColor Cyan
                Remove-AppxPackage -Package $app.PackageFullName -ErrorAction SilentlyContinue
            }
        }

        $allUserApps = Get-AppxPackage -Name $Pattern -AllUsers -ErrorAction SilentlyContinue
        if ($allUserApps) {
            foreach ($app in $allUserApps) {
                Write-Host "Removing $($app.Name) for all users..." -ForegroundColor Cyan
                Remove-AppxPackage -Package $app.PackageFullName -AllUsers -ErrorAction SilentlyContinue
            }
        }
    } catch {
        Write-Warning "Failed to process $Pattern`: $_"
    }
}

foreach ($appPattern in $OptimizedAppPackagePatterns) {
    Remove-AppPackagesByPattern -Pattern $appPattern
}

function Get-TargetServices {
    param([Parameter(Mandatory)][string]$ServiceName)

    @(Get-Service -Name $ServiceName, "$ServiceName*" -ErrorAction SilentlyContinue | Sort-Object Name -Unique)
}

#Disable services for Windows 10
Function DisService {
    If ($leaveservices) {
        Write-Host "***Leaveservices switch set - leaving services enabled...***"
    }
    Else {
        Write-Host "***Stopping and disabling diagnostics tracking services, telemetry, Xbox services, and other unnecessary services for Windows 10...***"
        
        # Windows 10 services to disable
        $servicesToDisable = @(
            'DiagTrack',                    # Connected User Experiences and Telemetry
            'dmwappushservice',             # WAP Push Message Routing Service
            'OneSyncSvc',                   # Sync Host (can break mail sync if used)
            'CDPSvc',                       # Connected Devices Platform Service
            'CDPUserSvc',                   # Connected Devices Platform User Service
            'DoSvc',                        # Delivery Optimization
            'XblAuthManager',               # Xbox Live Auth Manager
            'XblGameSave',                  # Xbox Live Game Save Service
            'XboxNetApiSvc',                # Xbox Live Networking Service
            'XboxGipSvc',                   # Xbox Accessory Management Service
            'BcastDVRUserService',          # Game DVR and broadcast
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
            'PhoneSvc',                     # Phone Service / Phone Link backend
            'PcaSvc',                       # Program Compatibility Assistant
            'RemoteRegistry',               # Remote Registry
            'AJRouter',                     # AllJoyn Router Service
            'Fax',                          # Fax Service
            'DusmSvc'                       # Data Usage
        )
        
        foreach ($service in $servicesToDisable) {
            try {
                $matchedServices = Get-TargetServices -ServiceName $service
                if ($matchedServices) {
                    foreach ($svc in $matchedServices) {
                        Write-Host "Processing service: $($svc.Name)" -ForegroundColor Yellow
                        if ($svc.Status -eq 'Running') {
                            Stop-Service -Name $svc.Name -Force -ErrorAction SilentlyContinue
                            Write-Host "  Stopped $($svc.Name)" -ForegroundColor Green
                        }
                        Set-Service -Name $svc.Name -StartupType Disabled -ErrorAction SilentlyContinue
                        Write-Host "  Disabled $($svc.Name)" -ForegroundColor Green
                    }
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