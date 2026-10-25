Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Revert for SystemOptimisation.ps1
# Attempts to restore common performance, service, RAM, and power settings changed by the optimiser.
# This is best-effort; not every tweak has a perfect one-click reverse, and some Windows defaults vary by build/edition.

$AutomatedMode = $args -contains '--automated'

function Write-Status { param([string]$m) Write-Host $m }

try {
    Write-Status 'Reverting System Optimisation changes...'

    # Power plan back to Balanced (common default)
    try {
        powercfg -setactive 381b4222-f694-41f0-9685-ff5bb260df2e 2>$null | Out-Null
    } catch {}

    # Let attached devices use their normal power-saving checkbox again.
    $deviceClasses = @(
        '{4d36e972-e325-11ce-bfc1-08002be10318}',
        '{36fc9e60-c465-11cf-8056-444553540000}',
        '{88bae032-5a81-49f0-bc3d-a4ff138216d6}',
        '{e0cbf06c-cd8b-4647-bb8a-263b43f0f974}',
        '{4d36e96c-e325-11ce-bfc1-08002be10318}',
        '{745a17a0-74d3-11d0-b6fe-00a0c90f57da}',
        '{4d36e96f-e325-11ce-bfc1-08002be10318}',
        '{4d36e96b-e325-11ce-bfc1-08002be10318}'
    )
    foreach ($classId in $deviceClasses) {
        $classPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Class\$classId"
        if (-not (Test-Path -LiteralPath $classPath)) { continue }
        Get-ChildItem -LiteralPath $classPath -ErrorAction SilentlyContinue | Where-Object { $_.PSChildName -match '^\d{4}$' } | ForEach-Object {
            Remove-ItemProperty -LiteralPath $_.PSPath -Name 'PnPCapabilities' -Force -ErrorAction SilentlyContinue
        }
    }
    try {
        $powerDevices = @(Get-CimInstance -Namespace 'root\wmi' -ClassName 'MSPower_DeviceEnable' -ErrorAction Stop)
        foreach ($powerDevice in $powerDevices) {
            try { Set-CimInstance -InputObject $powerDevice -Property @{ Enable = $true } -ErrorAction Stop | Out-Null } catch {}
        }
    } catch {}

    Remove-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling' -Name 'PowerThrottlingOff' -ErrorAction SilentlyContinue
    Set-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile' -Name 'SystemResponsiveness' -Value 20 -Type DWord -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path 'HKCU:\Control Panel\Desktop' -Name 'MenuShowDelay' -Value '400' -Type String -Force -ErrorAction SilentlyContinue
    foreach ($edgePolicy in @('HKLM:\SOFTWARE\Policies\Microsoft\Edge', 'HKCU:\SOFTWARE\Policies\Microsoft\Edge')) {
        if (Test-Path $edgePolicy) {
            foreach ($edgeName in @('StartupBoostEnabled', 'BackgroundModeEnabled', 'SleepingTabsEnabled')) {
                Remove-ItemProperty -Path $edgePolicy -Name $edgeName -Force -ErrorAction SilentlyContinue
            }
        }
    }
    $nduPath = 'HKLM:\SYSTEM\CurrentControlSet\Services\Ndu'
    if (Test-Path $nduPath) {
        Set-ItemProperty -Path $nduPath -Name 'Start' -Value 2 -Type DWord -Force -ErrorAction SilentlyContinue
    }
    $prefetchPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\PrefetchParameters'
    if (Test-Path $prefetchPath) {
        Set-ItemProperty -Path $prefetchPath -Name 'EnablePrefetcher' -Value 3 -Type DWord -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $prefetchPath -Name 'EnableSuperfetch' -Value 3 -Type DWord -Force -ErrorAction SilentlyContinue
    }

    # Foreground scheduling, graphics scheduling, and the service-host split go back to the usual client values.
    Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl' -Name 'Win32PrioritySeparation' -Value 2 -Type DWord -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers' -Name 'HwSchMode' -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control' -Name 'SvcHostSplitThresholdInKB' -Value 3670016 -Type DWord -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile' -Name 'NetworkThrottlingIndex' -Value 10 -Type DWord -Force -ErrorAction SilentlyContinue
    $memoryPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management'
    if (Test-Path $memoryPath) {
        Set-ItemProperty -Path $memoryPath -Name 'LargeSystemCache' -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $memoryPath -Name 'DisablePagingExecutive' -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $memoryPath -Name 'ClearPageFileAtShutdown' -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
    }
    $gamesPath = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games'
    if (Test-Path $gamesPath) {
        Set-ItemProperty -Path $gamesPath -Name 'GPU Priority' -Value 8 -Type DWord -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $gamesPath -Name 'Priority' -Value 2 -Type DWord -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $gamesPath -Name 'Scheduling Category' -Value 'Medium' -Type String -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $gamesPath -Name 'SFIO Priority' -Value 'Normal' -Type String -Force -ErrorAction SilentlyContinue
    }
    Remove-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Serialize' -Name 'StartupDelayInMSec' -ErrorAction SilentlyContinue

    $backgroundRoot = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications'
    if (Test-Path $backgroundRoot) {
        Set-ItemProperty -Path $backgroundRoot -Name 'GlobalUserDisabled' -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
        $backgroundApps = @(Get-ChildItem -Path $backgroundRoot -ErrorAction SilentlyContinue)
        foreach ($backgroundApp in $backgroundApps) {
            if (-not $backgroundApp) { continue }
            Remove-ItemProperty -LiteralPath $backgroundApp.PSPath -Name 'BackgroundAccess' -Force -ErrorAction SilentlyContinue
        }
    }
    $appPrivacy = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy'
    if (Test-Path $appPrivacy) {
        Remove-ItemProperty -Path $appPrivacy -Name 'LetAppsRunInBackground' -ErrorAction SilentlyContinue
    }

    $explorerAdvanced = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
    if (Test-Path $explorerAdvanced) {
        Set-ItemProperty -Path $explorerAdvanced -Name 'TaskbarAnimations' -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $explorerAdvanced -Name 'TaskbarDa' -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
    }
    foreach ($policyEntry in @(
        @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Dsh'; Name = 'AllowNewsAndInterests' },
        @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Feeds'; Name = 'EnableFeeds' },
        @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR'; Name = 'AllowGameDVR' }
    )) {
        if (Test-Path $policyEntry.Path) {
            Remove-ItemProperty -Path $policyEntry.Path -Name $policyEntry.Name -Force -ErrorAction SilentlyContinue
        }
    }
    $feedsUser = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Feeds'
    if (Test-Path $feedsUser) {
        Set-ItemProperty -Path $feedsUser -Name 'ShellFeedsTaskbarViewMode' -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
    }

    # DiagTrack stays Manual so this revert does not turn telemetry back on ahead of the privacy task.
    $serviceDefaults = @{
        'SysMain' = 'Automatic'
        'WSearch' = 'Automatic'
        'WerSvc' = 'Manual'
        'DiagTrack' = 'Manual'
        'dmwappushservice' = 'Manual'
        'MapsBroker' = 'Automatic'
        'lfsvc' = 'Manual'
        'DoSvc' = 'Automatic'
        'Fax' = 'Manual'
        'RetailDemo' = 'Manual'
        'WMPNetworkSvc' = 'Manual'
        'PNRPsvc' = 'Manual'
        'p2psvc' = 'Manual'
        'p2pimsvc' = 'Manual'
        'RemoteRegistry' = 'Disabled'
        'AJRouter' = 'Manual'
        'ALG' = 'Manual'
        'TrkWks' = 'Automatic'
        'SharedAccess' = 'Manual'
        'PhoneSvc' = 'Manual'
        'PcaSvc' = 'Automatic'
        'wercplsupport' = 'Manual'
        'stisvc' = 'Manual'
        'SCardSvr' = 'Manual'
        'ScDeviceEnum' = 'Manual'
        'icssvc' = 'Manual'
        'WbioSrvc' = 'Manual'
        'InventorySvc' = 'Manual'
        'NPSMSvc' = 'Manual'
        'whesvc' = 'Manual'
        'DPS' = 'Automatic'
        'WdiSystemHost' = 'Manual'
        'XblAuthManager' = 'Manual'
        'XblGameSave' = 'Manual'
        'XboxNetApiSvc' = 'Manual'
        'XboxGipSvc' = 'Manual'
        'CDPSvc' = 'Automatic'
        'WpcMonSvc' = 'Manual'
        'SEMgrSvc' = 'Manual'
        'wisvc' = 'Manual'
        'DusmSvc' = 'Manual'
    }
    foreach ($svcName in @($serviceDefaults.Keys)) {
        $service = Get-Service -Name $svcName -ErrorAction SilentlyContinue
        if ($service) {
            try { Set-Service -Name $svcName -StartupType $serviceDefaults[$svcName] -ErrorAction SilentlyContinue } catch {}
        }
    }
    $servicePatterns = @{
        'OneSyncSvc*' = 'Automatic'
        'cbdhsvc*' = 'Automatic'
        'WpnUserService*' = 'Automatic'
        'CDPUserSvc*' = 'Automatic'
        'BcastDVRUserService*' = 'Manual'
    }
    foreach ($pattern in @($servicePatterns.Keys)) {
        $matched = @(Get-Service -Name $pattern -ErrorAction SilentlyContinue)
        foreach ($svc in $matched) {
            if (-not $svc) { continue }
            try { Set-Service -Name $svc.Name -StartupType $servicePatterns[$pattern] -ErrorAction SilentlyContinue } catch {}
        }
    }

    $scheduledTasks = @(
        '\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser',
        '\Microsoft\Windows\Application Experience\ProgramDataUpdater',
        '\Microsoft\Windows\Application Experience\MareBackup',
        '\Microsoft\Windows\Application Experience\StartupAppTask',
        '\Microsoft\Windows\Customer Experience Improvement Program\Consolidator',
        '\Microsoft\Windows\Customer Experience Improvement Program\KernelCeipTask',
        '\Microsoft\Windows\Customer Experience Improvement Program\UsbCeip',
        '\Microsoft\Windows\Autochk\Proxy',
        '\Microsoft\Windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticDataCollector',
        '\Microsoft\Windows\DiskFootprint\Diagnostics',
        '\Microsoft\Windows\Maintenance\WinSAT',
        '\Microsoft\Windows\Feedback\Siuf\DmClient',
        '\Microsoft\Windows\Feedback\Siuf\DmClientOnScenarioDownload',
        '\Microsoft\Windows\Windows Error Reporting\QueueReporting',
        '\Microsoft\Windows\Power Efficiency Diagnostics\AnalyzeSystem',
        '\Microsoft\Windows\CloudExperienceHost\CreateObjectTask',
        '\Microsoft\Windows\PushToInstall\LoginCheck',
        '\Microsoft\Windows\PushToInstall\Registration',
        '\Microsoft\Windows\License Manager\TempSignedLicenseExchange',
        '\Microsoft\Windows\Clip\License Validation',
        '\Microsoft\Windows\Shell\FamilySafetyMonitor',
        '\Microsoft\Windows\Shell\FamilySafetyRefreshTask',
        '\Microsoft\Windows\ApplicationData\DsSvcCleanup'
    )
    foreach ($scheduledTask in $scheduledTasks) {
        schtasks /Change /TN $scheduledTask /Enable 2>$null | Out-Null
    }

    Write-Status 'System Optimisation reversal attempted. Restart recommended for service and power changes to take full effect.'

    if (-not $AutomatedMode) {
        Add-Type -AssemblyName System.Windows.Forms
        [System.Windows.Forms.MessageBox]::Show('System Optimisation changes have been reverted where a default is known. That includes the power plan, device power saving, background apps, and service startup types. Restart the PC.', 'Revert System Optimisation', 'OK', 'Information') | Out-Null
    }

    exit 0
} catch {
    Write-Status "System Optimisation revert error: $_"
    exit 1
}
