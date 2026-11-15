Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Windows Privacy hardening module
# Supports both interactive and automated execution.

$AutomatedMode = $args -contains '--automated'
$OptimisationProfile = 'optimal'

for ($argIndex = 0; $argIndex -lt $args.Count; $argIndex++) {
    $argValue = [string]$args[$argIndex]

    if ($argValue -eq '--profile' -and ($argIndex + 1) -lt $args.Count) {
        $OptimisationProfile = [string]$args[$argIndex + 1]
        $argIndex++
        continue
    }

    if ($argValue.StartsWith('--profile=')) {
        $OptimisationProfile = $argValue.Substring(10)
    }
}

if ([string]::IsNullOrWhiteSpace($OptimisationProfile)) {
    $OptimisationProfile = 'optimal'
} else {
    $OptimisationProfile = $OptimisationProfile.ToLowerInvariant()
}

if ($OptimisationProfile -notin @('minimal', 'optimal', 'aggressive')) {
    $OptimisationProfile = 'optimal'
}

function Write-PrivacyStatus {
    param([string]$Message)
    Write-Host $Message
}

function Invoke-PrivacyStep {
    param(
        [scriptblock]$Block,
        [string]$Description
    )

    try {
        Write-PrivacyStatus "Applying: $Description..."
        & $Block
        Write-PrivacyStatus "Completed: $Description"
    } catch {
        Write-PrivacyStatus "Error during $Description : $($_.Exception.Message)"
    }
}

function Disable-PrivacyServices {
    Invoke-PrivacyStep {
        $servicesToDisable = @(
            'DiagTrack',
            'dmwappushservice',
            'MapsBroker',
            'lfsvc',
            'WpcMonSvc',
            'SEMgrSvc',
            'RetailDemo',
            'wisvc',
            'DusmSvc'
        )

        foreach ($serviceName in $servicesToDisable) {
            $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
            if ($service) {
                Stop-Service -Name $serviceName -Force -ErrorAction SilentlyContinue
                Set-Service -Name $serviceName -StartupType Disabled -ErrorAction SilentlyContinue
            }
        }
    } 'Privacy-related services'
}

function Disable-AdvertisingAndTelemetry {
    Invoke-PrivacyStep {
        $advertisingPolicyPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo'
        if (-not (Test-Path $advertisingPolicyPath)) { New-Item -Path $advertisingPolicyPath -Force | Out-Null }
        Set-ItemProperty -Path $advertisingPolicyPath -Name 'DisabledByGroupPolicy' -Value 1 -Force

        $advertisingUserPath = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\AdvertisingInfo'
        if (-not (Test-Path $advertisingUserPath)) { New-Item -Path $advertisingUserPath -Force | Out-Null }
        Set-ItemProperty -Path $advertisingUserPath -Name 'Enabled' -Value 0 -Force

        $dataCollectionPaths = @(
            'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection',
            'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection'
        )

        foreach ($path in $dataCollectionPaths) {
            if (-not (Test-Path $path)) { New-Item -Path $path -Force | Out-Null }
            Set-ItemProperty -Path $path -Name 'AllowTelemetry' -Value 0 -Force
        }

        $dcPolicyPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection'
        Set-ItemProperty -Path $dcPolicyPath -Name 'MaxTelemetryAllowed' -Value 0 -Force
        Set-ItemProperty -Path $dcPolicyPath -Name 'DisableOneSettingsDownloads' -Value 1 -Force
        Set-ItemProperty -Path $dcPolicyPath -Name 'DoNotShowFeedbackNotifications' -Value 1 -Force

        $winSearchPolicyPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search'
        if (-not (Test-Path $winSearchPolicyPath)) { New-Item -Path $winSearchPolicyPath -Force | Out-Null }
        Set-ItemProperty -Path $winSearchPolicyPath -Name 'AllowCortana' -Value 0 -Force
        Set-ItemProperty -Path $winSearchPolicyPath -Name 'AllowCloudSearch' -Value 0 -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $winSearchPolicyPath -Name 'AllowSearchToUseLocation' -Value 0 -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $winSearchPolicyPath -Name 'DisableWebSearch' -Value 1 -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $winSearchPolicyPath -Name 'ConnectedSearchUseWeb' -Value 0 -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $winSearchPolicyPath -Name 'EnableDynamicContentInWSB' -Value 0 -Force -ErrorAction SilentlyContinue

        $searchSettingsPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\SearchSettings'
        if (-not (Test-Path $searchSettingsPath)) { New-Item -Path $searchSettingsPath -Force | Out-Null }
        Set-ItemProperty -Path $searchSettingsPath -Name 'IsDynamicSearchBoxEnabled' -Value 0 -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $searchSettingsPath -Name 'IsAADCloudSearchEnabled' -Value 0 -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $searchSettingsPath -Name 'IsMSACloudSearchEnabled' -Value 0 -Force -ErrorAction SilentlyContinue

        $searchPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Search'
        if (-not (Test-Path $searchPath)) { New-Item -Path $searchPath -Force | Out-Null }
        Set-ItemProperty -Path $searchPath -Name 'BingSearchEnabled' -Value 0 -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $searchPath -Name 'CortanaConsent' -Value 0 -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $searchPath -Name 'AllowSearchToUseLocation' -Value 0 -Force -ErrorAction SilentlyContinue

        $autologgerPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\WMI\Autologger\AutoLogger-Diagtrack-Listener'
        if (Test-Path $autologgerPath) {
            Set-ItemProperty -Path $autologgerPath -Name 'Start' -Value 0 -Force -ErrorAction SilentlyContinue
        }
    } 'Advertising and telemetry policies'
}

function Disable-BackgroundApps {
    Invoke-PrivacyStep {
        $backgroundPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications'
        if (-not (Test-Path $backgroundPath)) { New-Item -Path $backgroundPath -Force | Out-Null }
        Set-ItemProperty -Path $backgroundPath -Name 'GlobalUserDisabled' -Value 1 -Type DWord -Force

        Get-AppxPackage | ForEach-Object {
            $appPath = "$backgroundPath\$($_.PackageFullName)"
            if (-not (Test-Path $appPath)) { New-Item -Path $appPath -Force | Out-Null }
            Set-ItemProperty -Path $appPath -Name 'BackgroundAccess' -Value 0 -Type DWord -ErrorAction SilentlyContinue
        }

        $appPrivacyPolicyPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy'
        if (-not (Test-Path $appPrivacyPolicyPath)) { New-Item -Path $appPrivacyPolicyPath -Force | Out-Null }
        Set-ItemProperty -Path $appPrivacyPolicyPath -Name 'LetAppsRunInBackground' -Value 2 -Force
    } 'Background app restrictions'
}

function Set-CorePrivacyPolicies {
    Invoke-PrivacyStep {
        $siufPath = 'HKCU:\SOFTWARE\Microsoft\Siuf\Rules'
        if (-not (Test-Path $siufPath)) { New-Item -Path $siufPath -Force | Out-Null }
        Set-ItemProperty -Path $siufPath -Name 'NumberOfSIUFInPeriod' -Value 0 -Force
        Set-ItemProperty -Path $siufPath -Name 'PeriodInNanoSeconds' -Value 0 -Force

        $privacyPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Privacy'
        if (-not (Test-Path $privacyPath)) { New-Item -Path $privacyPath -Force | Out-Null }
        Set-ItemProperty -Path $privacyPath -Name 'TailoredExperiencesWithDiagnosticDataEnabled' -Value 0 -Force

        $inputPath = 'HKCU:\Software\Microsoft\InputPersonalization'
        if (-not (Test-Path $inputPath)) { New-Item -Path $inputPath -Force | Out-Null }
        Set-ItemProperty -Path $inputPath -Name 'RestrictImplicitInkCollection' -Value 1 -Force
        Set-ItemProperty -Path $inputPath -Name 'RestrictImplicitTextCollection' -Value 1 -Force

        $inputStorePath = 'HKCU:\Software\Microsoft\InputPersonalization\TrainedDataStore'
        if (-not (Test-Path $inputStorePath)) { New-Item -Path $inputStorePath -Force | Out-Null }
        Set-ItemProperty -Path $inputStorePath -Name 'HarvestContacts' -Value 0 -Force

        $speechPath = 'HKCU:\Software\Microsoft\Speech_OneCore\Settings\VoiceActivation\UserPreferenceForAllApps'
        if (-not (Test-Path $speechPath)) { New-Item -Path $speechPath -Force | Out-Null }
        Set-ItemProperty -Path $speechPath -Name 'AgentActivationEnabled' -Value 0 -Force

        $speechPrivacyPath = 'HKCU:\Software\Microsoft\Speech_OneCore\Settings\OnlineSpeechPrivacy'
        if (-not (Test-Path $speechPrivacyPath)) { New-Item -Path $speechPrivacyPath -Force | Out-Null }
        Set-ItemProperty -Path $speechPrivacyPath -Name 'HasAccepted' -Value 0 -Force -ErrorAction SilentlyContinue

        $personalisationSettingsPath = 'HKCU:\Software\Microsoft\Personalization\Settings'
        if (-not (Test-Path $personalisationSettingsPath)) { New-Item -Path $personalisationSettingsPath -Force | Out-Null }
        Set-ItemProperty -Path $personalisationSettingsPath -Name 'AcceptedPrivacyPolicy' -Value 0 -Force

        $tabletPcPolicyPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\TabletPC'
        if (-not (Test-Path $tabletPcPolicyPath)) { New-Item -Path $tabletPcPolicyPath -Force | Out-Null }
        Set-ItemProperty -Path $tabletPcPolicyPath -Name 'PreventHandwritingDataSharing' -Value 1 -Force

        $werPolicyPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Error Reporting'
        if (-not (Test-Path $werPolicyPath)) { New-Item -Path $werPolicyPath -Force | Out-Null }
        Set-ItemProperty -Path $werPolicyPath -Name 'Disabled' -Value 1 -Force
        Set-ItemProperty -Path $werPolicyPath -Name 'DontSendAdditionalData' -Value 1 -Force
        Set-ItemProperty -Path $werPolicyPath -Name 'LoggingDisabled' -Value 1 -Force

        $appPrivacyPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy'
        if (-not (Test-Path $appPrivacyPath)) { New-Item -Path $appPrivacyPath -Force | Out-Null }
        Set-ItemProperty -Path $appPrivacyPath -Name 'LetAppsGetDiagnosticInfo' -Value 2 -Force
        # Never force-deny account info: Settings needs it to change the local profile picture / Your info.
        Remove-ItemProperty -Path $appPrivacyPath -Name 'LetAppsAccessAccountInfo' -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $appPrivacyPath -Name 'LetAppsAccessCalendar' -Value 2 -Force
        Set-ItemProperty -Path $appPrivacyPath -Name 'LetAppsAccessCallHistory' -Value 2 -Force
        Set-ItemProperty -Path $appPrivacyPath -Name 'LetAppsAccessContacts' -Value 2 -Force
        Set-ItemProperty -Path $appPrivacyPath -Name 'LetAppsAccessEmail' -Value 2 -Force
        Set-ItemProperty -Path $appPrivacyPath -Name 'LetAppsAccessMessaging' -Value 2 -Force
        Set-ItemProperty -Path $appPrivacyPath -Name 'LetAppsAccessTasks' -Value 2 -Force

        $findMyDevicePath = 'HKLM:\SOFTWARE\Policies\Microsoft\FindMyDevice'
        if (-not (Test-Path $findMyDevicePath)) { New-Item -Path $findMyDevicePath -Force | Out-Null }
        Set-ItemProperty -Path $findMyDevicePath -Name 'AllowFindMyDevice' -Value 0 -Force

        $systemPolicyPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System'
        if (-not (Test-Path $systemPolicyPath)) { New-Item -Path $systemPolicyPath -Force | Out-Null }
        Set-ItemProperty -Path $systemPolicyPath -Name 'EnableActivityFeed' -Value 0 -Force
        Set-ItemProperty -Path $systemPolicyPath -Name 'PublishUserActivities' -Value 0 -Force
        Set-ItemProperty -Path $systemPolicyPath -Name 'UploadUserActivities' -Value 0 -Force

        $cloudContentMachinePath = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent'
        if (-not (Test-Path $cloudContentMachinePath)) { New-Item -Path $cloudContentMachinePath -Force | Out-Null }
        Set-ItemProperty -Path $cloudContentMachinePath -Name 'DisableWindowsConsumerFeatures' -Value 1 -Force
        Set-ItemProperty -Path $cloudContentMachinePath -Name 'DisableSoftLanding' -Value 1 -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $cloudContentMachinePath -Name 'DisableCloudOptimizedContent' -Value 1 -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $cloudContentMachinePath -Name 'DisableConsumerAccountStateContent' -Value 1 -Force -ErrorAction SilentlyContinue

        $cloudContentUserPath = 'HKCU:\SOFTWARE\Policies\Microsoft\Windows\CloudContent'
        if (-not (Test-Path $cloudContentUserPath)) { New-Item -Path $cloudContentUserPath -Force | Out-Null }
        Set-ItemProperty -Path $cloudContentUserPath -Name 'DisableTailoredExperiencesWithDiagnosticData' -Value 1 -Force
        Set-ItemProperty -Path $cloudContentUserPath -Name 'DisableWindowsSpotlightFeatures' -Value 1 -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $cloudContentUserPath -Name 'DisableSpotlightCollectionOnDesktop' -Value 1 -Force -ErrorAction SilentlyContinue

        Set-ItemProperty -Path $systemPolicyPath -Name 'EnableAppUriHandlers' -Value 0 -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $systemPolicyPath -Name 'AllowCrossDeviceClipboard' -Value 0 -Force -ErrorAction SilentlyContinue

        $doPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization'
        if (-not (Test-Path $doPath)) { New-Item -Path $doPath -Force | Out-Null }
        Set-ItemProperty -Path $doPath -Name 'DODownloadMode' -Value 99 -Force

        $locationPolicyPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors'
        if (-not (Test-Path $locationPolicyPath)) { New-Item -Path $locationPolicyPath -Force | Out-Null }
        Set-ItemProperty -Path $locationPolicyPath -Name 'DisableLocation' -Value 1 -Force

        $widgetsPolicyPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Dsh'
        if (-not (Test-Path $widgetsPolicyPath)) { New-Item -Path $widgetsPolicyPath -Force | Out-Null }
        Set-ItemProperty -Path $widgetsPolicyPath -Name 'AllowNewsAndInterests' -Value 0 -Force

        $feedsPolicyPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Feeds'
        if (-not (Test-Path $feedsPolicyPath)) { New-Item -Path $feedsPolicyPath -Force | Out-Null }
        Set-ItemProperty -Path $feedsPolicyPath -Name 'EnableFeeds' -Value 0 -Force

        $feedsUserPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Feeds'
        if (-not (Test-Path $feedsUserPath)) { New-Item -Path $feedsUserPath -Force | Out-Null }
        Set-ItemProperty -Path $feedsUserPath -Name 'ShellFeedsTaskbarViewMode' -Value 2 -Force -ErrorAction SilentlyContinue

        $explorerAdvancedPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
        if (-not (Test-Path $explorerAdvancedPath)) { New-Item -Path $explorerAdvancedPath -Force | Out-Null }
        Set-ItemProperty -Path $explorerAdvancedPath -Name 'TaskbarDa' -Value 0 -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $explorerAdvancedPath -Name 'Start_TrackDocs' -Value 0 -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $explorerAdvancedPath -Name 'Start_IrisRecommendations' -Value 0 -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $explorerAdvancedPath -Name 'Start_AccountNotifications' -Value 0 -Force -ErrorAction SilentlyContinue
        # Disable File Explorer "sync provider" ads / OneDrive / Microsoft 365 upsells (common W11 privacy annoyance)
        Set-ItemProperty -Path $explorerAdvancedPath -Name 'ShowSyncProviderNotifications' -Value 0 -Force -ErrorAction SilentlyContinue

        # Stop Start feed provider / Widgets / Cross-device resume that stay resident after Close
        $bgRoot = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications'
        if (-not (Test-Path $bgRoot)) { New-Item -Path $bgRoot -Force | Out-Null }
        foreach ($pkgName in @('Microsoft.StartExperiencesApp', 'MicrosoftWindows.Client.WebExperience', 'MicrosoftWindows.CrossDevice')) {
            foreach ($pkg in @(Get-AppxPackage -Name $pkgName -ErrorAction SilentlyContinue)) {
                if (-not $pkg) { continue }
                $appPath = Join-Path $bgRoot $pkg.PackageFullName
                if (-not (Test-Path $appPath)) { New-Item -Path $appPath -Force | Out-Null }
                Set-ItemProperty -Path $appPath -Name 'BackgroundAccess' -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
                Set-ItemProperty -Path $appPath -Name 'Disabled' -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
            }
        }
        foreach ($procName in @('Widgets', 'WidgetBoard', 'WidgetService', 'MicrosoftStartFeedProvider', 'CrossDeviceResume')) {
            Stop-Process -Name $procName -Force -ErrorAction SilentlyContinue
        }

        $cdmPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'
        if (-not (Test-Path $cdmPath)) { New-Item -Path $cdmPath -Force | Out-Null }
        Set-ItemProperty -Path $cdmPath -Name 'RotatingLockScreenEnabled' -Value 0 -Force
        Set-ItemProperty -Path $cdmPath -Name 'RotatingLockScreenOverlayEnabled' -Value 0 -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $cdmPath -Name 'SubscribedContent-338387Enabled' -Value 0 -Force
        Set-ItemProperty -Path $cdmPath -Name 'SubscribedContent-338388Enabled' -Value 0 -Force
        Set-ItemProperty -Path $cdmPath -Name 'SubscribedContent-338389Enabled' -Value 0 -Force
        Set-ItemProperty -Path $cdmPath -Name 'SubscribedContent-338393Enabled' -Value 0 -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $cdmPath -Name 'SubscribedContent-353694Enabled' -Value 0 -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $cdmPath -Name 'SubscribedContent-353696Enabled' -Value 0 -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $cdmPath -Name 'SubscribedContent-353698Enabled' -Value 0 -Force
        Set-ItemProperty -Path $cdmPath -Name 'SoftLandingEnabled' -Value 0 -Force
        Set-ItemProperty -Path $cdmPath -Name 'SystemPaneSuggestionsEnabled' -Value 0 -Force
        # Additional W11 ad / offer surfaces (Start recommendations, tips, lockscreen, offers)
        Set-ItemProperty -Path $cdmPath -Name 'SubscribedContent-310091Enabled' -Value 0 -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $cdmPath -Name 'SubscribedContent-314563Enabled' -Value 0 -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $cdmPath -Name 'SubscribedContent-314568Enabled' -Value 0 -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $cdmPath -Name 'ContentDeliveryAllowed' -Value 0 -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $cdmPath -Name 'OemPreInstalledAppsEnabled' -Value 0 -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $cdmPath -Name 'PreInstalledAppsEnabled' -Value 0 -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $cdmPath -Name 'PreInstalledAppsEverEnabled' -Value 0 -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $cdmPath -Name 'SilentInstalledAppsEnabled' -Value 0 -Force -ErrorAction SilentlyContinue
    } 'Core privacy policy hardening'
}

function Set-ProfilePrivacyPolicies {
    param([string]$HardeningDepth = 'optimal')

    Invoke-PrivacyStep {
        if ($HardeningDepth -eq 'aggressive') {
            $appPrivacyPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy'
            if (-not (Test-Path $appPrivacyPath)) { New-Item -Path $appPrivacyPath -Force | Out-Null }

            $forceDenyValues = @(
                'LetAppsAccessLocation',
                'LetAppsAccessNotifications',
                'LetAppsAccessMotion',
                'LetAppsAccessRadios',
                'LetAppsActivateWithVoice',
                'LetAppsActivateWithVoiceAboveLock',
                'LetAppsSyncWithDevices',
                'LetAppsAccessTrustedDevices',
                'LetAppsRunInBackground'
            )

            foreach ($valueName in $forceDenyValues) {
                Set-ItemProperty -Path $appPrivacyPath -Name $valueName -Value 2 -Force -ErrorAction SilentlyContinue
            }

            $settingSyncPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\SettingSync'
            if (-not (Test-Path $settingSyncPath)) { New-Item -Path $settingSyncPath -Force | Out-Null }
            Set-ItemProperty -Path $settingSyncPath -Name 'DisableSettingSync' -Value 2 -Force
            Set-ItemProperty -Path $settingSyncPath -Name 'DisableSettingSyncUserOverride' -Value 1 -Force

            $ncsiPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\NetworkConnectivityStatusIndicator'
            if (-not (Test-Path $ncsiPath)) { New-Item -Path $ncsiPath -Force | Out-Null }
            Set-ItemProperty -Path $ncsiPath -Name 'NoActiveProbe' -Value 1 -Force -ErrorAction SilentlyContinue

            $messagingPath = 'HKCU:\SOFTWARE\Microsoft\Messaging'
            if (-not (Test-Path $messagingPath)) { New-Item -Path $messagingPath -Force | Out-Null }
            Set-ItemProperty -Path $messagingPath -Name 'CloudServiceSyncEnabled' -Value 0 -Force -ErrorAction SilentlyContinue
        }
    } "Profile privacy policies ($HardeningDepth)"
}

function Disable-PrivacyScheduledTasks {
    Invoke-PrivacyStep {
        $tasks = @(
            '\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser',
            '\Microsoft\Windows\Application Experience\ProgramDataUpdater',
            '\Microsoft\Windows\Customer Experience Improvement Program\Consolidator',
            '\Microsoft\Windows\Customer Experience Improvement Program\KernelCeipTask',
            '\Microsoft\Windows\Customer Experience Improvement Program\UsbCeip',
            '\Microsoft\Windows\Feedback\Siuf\DmClient',
            '\Microsoft\Windows\Feedback\Siuf\DmClientOnScenarioDownload',
            '\Microsoft\Windows\PerformanceTrace\ShowFeedbackToast'
        )

        foreach ($taskPath in $tasks) {
            try {
                # Use modern cmdlet for reliability and to avoid "does not exist" console spam on some builds
                $taskName = Split-Path -Leaf $taskPath
                $task = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
                if ($task) {
                    Disable-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue | Out-Null
                }
            } catch {
                # Ignore individual missing or protected tasks (common on some Windows 11 SKUs)
            }
        }
    } 'Privacy telemetry scheduled tasks'
}

function Disable-AdsAndRecommendations {
    Invoke-PrivacyStep {
        # Explicit File Explorer ad suppression (sync provider / OneDrive upsell notifications)
        $explorerAdvancedPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
        if (-not (Test-Path $explorerAdvancedPath)) { New-Item -Path $explorerAdvancedPath -Force | Out-Null }
        Set-ItemProperty -Path $explorerAdvancedPath -Name 'ShowSyncProviderNotifications' -Value 0 -Force -ErrorAction SilentlyContinue

        # Start menu recommendations / tips (the prominent "Show recommendations for tips, shortcuts, new apps, and more")
        $startPersonalisation = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
        if (-not (Test-Path $startPersonalisation)) { New-Item -Path $startPersonalisation -Force | Out-Null }
        # Multiple values help cover different Start surfaces on 24H2+
        Set-ItemProperty -Path $startPersonalisation -Name 'Start_Recommendations' -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $startPersonalisation -Name 'Start_IrisRecommendations' -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue

        # Notification centre / system suggested tips and ads
        $notifRoot = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Notifications\Settings'
        if (Test-Path $notifRoot) {
            $suggested = "$notifRoot\Windows.SystemToast.Suggested"
            if (-not (Test-Path $suggested)) { New-Item -Path $suggested -Force | Out-Null }
            Set-ItemProperty -Path $suggested -Name 'Enabled' -Value 0 -Force -ErrorAction SilentlyContinue
        }

        # Additional notification suppression for tips/suggestions
        $sysNotif = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
        if (-not (Test-Path $sysNotif)) { New-Item -Path $sysNotif -Force | Out-Null }
        # These reduce "Get tips and suggestions" style surfaces
        Set-ItemProperty -Path $sysNotif -Name 'ShowSyncProviderNotifications' -Value 0 -Force -ErrorAction SilentlyContinue

        # Lock screen / spotlight ads and consumer offers (supplements CDM values)
        $lockPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'
        if (-not (Test-Path $lockPath)) { New-Item -Path $lockPath -Force | Out-Null }
        Set-ItemProperty -Path $lockPath -Name 'RotatingLockScreenOverlayEnabled' -Value 0 -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $lockPath -Name 'SubscribedContent-338393Enabled' -Value 0 -Force -ErrorAction SilentlyContinue

        Write-PrivacyStatus 'Shell ads, Start recommendations, Explorer sync ads, and notification suggestions suppressed.'
    } 'Current Windows 11 ads, recommendations, and notification surfaces'
}

function Remove-LegacyTelemetryHostsBlock {
    # Older builds rewrote the hosts file. That rewrite is what Defender reports as hosts injection.
    # Strip only the marked block this tool wrote. Do nothing when the marker is absent, so later runs never touch hosts.
    $hostsPath = Join-Path $env:SystemRoot 'System32\drivers\etc\hosts'
    $markerStart = '# >>> WindowsMaintenance-Telemetry-Block START'
    $markerEnd = '# >>> WindowsMaintenance-Telemetry-Block END'
    if (-not (Test-Path -LiteralPath $hostsPath)) { return }

    $lines = @(Get-Content -LiteralPath $hostsPath -ErrorAction SilentlyContinue)
    $found = $false
    foreach ($line in $lines) {
        if ($null -ne $line -and $line.Trim() -eq $markerStart) { $found = $true; break }
    }
    if (-not $found) { return }

    $kept = New-Object System.Collections.Generic.List[string]
    $skip = $false
    foreach ($line in $lines) {
        if ($null -eq $line) { continue }
        $trim = $line.Trim()
        if ($trim -eq $markerStart) { $skip = $true; continue }
        if ($trim -eq $markerEnd) { $skip = $false; continue }
        if (-not $skip) { [void]$kept.Add($line) }
    }

    if ($kept.Count -eq 0) {
        Set-Content -LiteralPath $hostsPath -Value '' -Force -Encoding ASCII
    } else {
        Set-Content -LiteralPath $hostsPath -Value $kept.ToArray() -Force -Encoding ASCII
    }
    Write-PrivacyStatus 'Removed the previous hosts-file telemetry block. Later runs leave the hosts file alone.'
}

function Block-MicrosoftTelemetryAndFeedback {
    Invoke-PrivacyStep {
        # Domain blocks use the Name Resolution Policy Table (supported DNS policy) plus firewall rules.
        # The hosts file is not used. Defender treats scripted hosts rewrites as hosts injection.

        $telemetryDomains = @(
            # Core Connected User Experiences / Telemetry (DiagTrack / CEIP)
            'vortex.data.microsoft.com',
            'vortex-win.data.microsoft.com',
            'v10.events.data.microsoft.com',
            'v10c.events.data.microsoft.com',
            'v10.vortex-win.data.microsoft.com',
            'settings-win.data.microsoft.com',
            # Watson / error & diagnostic telemetry
            'watson.telemetry.microsoft.com',
            'telecommand.telemetry.microsoft.com',
            'sqm.telemetry.microsoft.com',
            'oca.telemetry.microsoft.com',
            'vortex-sandbox.data.microsoft.com',
            # Feedback surfaces (search, Windows) - explicit user request: even "basic" must send nothing
            'feedback.search.microsoft.com',
            'feedback.windows.com'   # feedback endpoints - block even basic level per request
        )

        try {
            Remove-LegacyTelemetryHostsBlock
        } catch {
            Write-PrivacyStatus "Previous hosts block was left in place: $($_.Exception.Message)"
        }

        $nrptComment = 'WindowsMaintenance telemetry block'
        try {
            $existingRules = @(Get-DnsClientNrptRule -ErrorAction SilentlyContinue)
        } catch {
            $existingRules = @()
        }

        foreach ($rule in $existingRules) {
            $comment = ''
            $displayName = ''
            if ($rule.PSObject.Properties.Match('Comment').Count -gt 0 -and $rule.Comment) {
                $comment = [string]$rule.Comment
            }
            if ($rule.PSObject.Properties.Match('DisplayName').Count -gt 0 -and $rule.DisplayName) {
                $displayName = [string]$rule.DisplayName
            }
            if ($comment -eq $nrptComment -or $displayName -like 'WM-Telemetry-*') {
                try {
                    Remove-DnsClientNrptRule -Name $rule.Name -Force -ErrorAction Stop
                } catch {
                    Write-PrivacyStatus "NRPT rule removal skipped: $($_.Exception.Message)"
                }
            }
        }

        # Flush before firewall resolution so a previous NRPT rule cannot hide the real addresses.
        try { Clear-DnsClientCache -ErrorAction SilentlyContinue } catch {}

        # --- Windows Firewall outbound block rules (supplemental layer on resolved IPs for TCP 443) ---
        # Named with WM-BlockTelemetry- prefix so revert can cleanly remove them without touching user rules.
        foreach ($domain in $telemetryDomains) {
            try {
                $dnsResults = Resolve-DnsName -Name $domain -Type A_AAAA -ErrorAction Stop
                $rawIps = @($dnsResults | ForEach-Object {
                    if ($_.PSObject.Properties.Match('IPAddress').Count -gt 0 -and $_.IPAddress) {
                        $_.IPAddress
                    }
                } | Select-Object -Unique)
                # Filter out unspecified, loopback, link-local, multicast, and other unsuitable addresses
                # that cause "An unspecified, multicast, broadcast or loopback IPv6 address was specified" errors.
                $ipList = @($rawIps | Where-Object {
                    $ip = [string]$_
                    if (-not $ip) { return $false }
                    if ($ip -eq '0.0.0.0' -or $ip -eq '::' -or $ip -eq '::1') { return $false }
                    if ($ip -match '^fe[89ab]:' -or $ip -match '^ff[0-9a-f]:') { return $false }  # link-local / multicast v6
                    if ($ip -match '^127\.|^169\.254\.|^224\.|^239\.|^::ffff:') { return $false }
                    $true
                })
                if ($ipList.Count -gt 0) {
                    $ruleName = "WM-BlockTelemetry-$domain"
                    # Remove any stale rule with same name first (idempotent re-apply)
                    Get-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue |
                        Remove-NetFirewallRule -Confirm:$false -ErrorAction SilentlyContinue

                    New-NetFirewallRule -DisplayName $ruleName `
                        -Direction Outbound `
                        -Action Block `
                        -RemoteAddress $ipList `
                        -Protocol TCP `
                        -RemotePort 443 `
                        -Enabled True `
                        -Profile Any `
                        -Group 'Windows Maintenance - Privacy' `
                        -Description "Block outbound Microsoft telemetry/feedback traffic to $domain. Prevents data exfiltration even at 'basic' diagnostic level. (Auto-created by WindowsMaintenance privacy task)" `
                        -ErrorAction Stop | Out-Null

                    # The step progress reports the outcome.
                }
            } catch {
                # Non-fatal (duplicate rule, permission, or unusable address). NRPT still covers the name.
            }
        }

        foreach ($domain in $telemetryDomains) {
            try {
                Add-DnsClientNrptRule -Namespace $domain -NameServers '127.0.0.1' -Comment $nrptComment -DisplayName "WM-Telemetry-$domain" -ErrorAction Stop | Out-Null
            } catch {
                Write-PrivacyStatus "NRPT rule for $domain was not added: $($_.Exception.Message)"
            }
        }

        try { Clear-DnsClientCache -ErrorAction SilentlyContinue } catch {}

        Write-PrivacyStatus 'Microsoft telemetry, diagnostic events, Watson, and feedback names are blocked with NRPT rules and outbound firewall rules.'
    } 'Hard block Microsoft telemetry and feedback (NRPT + outbound firewall rules)'
}

function Invoke-WindowsPrivacy {
    Write-PrivacyStatus 'Starting Windows privacy hardening...'

    Disable-PrivacyServices
    Disable-AdvertisingAndTelemetry
    Disable-BackgroundApps
    Set-CorePrivacyPolicies
    Disable-PrivacyScheduledTasks
    Set-ProfilePrivacyPolicies -HardeningDepth $OptimisationProfile
    Disable-AdsAndRecommendations
    Block-MicrosoftTelemetryAndFeedback

    Write-PrivacyStatus 'Windows privacy hardening completed.'
}

try {
    Invoke-WindowsPrivacy

    if (-not $AutomatedMode) {
        Add-Type -AssemblyName System.Windows.Forms
        [System.Windows.Forms.MessageBox]::Show(
            'Windows privacy hardening completed. Some changes may require sign-out or restart to fully apply.',
            'Windows Privacy',
            'OK',
            'Information'
        ) | Out-Null
    }

    exit 0
} catch {
    Write-PrivacyStatus "Windows privacy hardening failed: $($_.Exception.Message)"
    exit 1
}
