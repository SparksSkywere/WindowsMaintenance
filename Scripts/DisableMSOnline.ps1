Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Disable Microsoft Account Nags / Online Prompts for Local Account Users
# Does not remove ability to sign in with MS account later if desired.

$AutomatedMode = $args -contains '--automated'

function Write-MSOnlineStatus {
    param([string]$Message)
    Write-Host $Message
}

function Invoke-MSOnlineStep {
    param(
        [scriptblock]$Block,
        [string]$Description
    )

    try {
        Write-MSOnlineStatus "Applying: $Description..."
        & $Block
        Write-MSOnlineStatus "Completed: $Description"
    } catch {
        Write-MSOnlineStatus "Warning during $Description : $($_.Exception.Message)"
    }
}

function Repair-AccountPersonalizationPolicies {
    # Older builds of this script set AllowYourAccount / AllowSignInOptions to 0.
    # That locks Settings > Accounts > Your info (account picture / profile icons) for local users.
    # Keep those pages usable while still suppressing Microsoft-account nags below.
    $pmDevicePath = 'HKLM:\SOFTWARE\Microsoft\PolicyManager\current\device\Settings'
    if (Test-Path $pmDevicePath) {
        Remove-ItemProperty -Path $pmDevicePath -Name 'AllowYourAccount' -Force -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path $pmDevicePath -Name 'AllowSignInOptions' -Force -ErrorAction SilentlyContinue
    }

    foreach ($name in @('AllowYourAccount', 'AllowSignInOptions')) {
        $defaultPath = "HKLM:\SOFTWARE\Microsoft\PolicyManager\default\Settings\$name"
        if (Test-Path $defaultPath) {
            # Schema key: restore default allowed (1). Do not delete Value.
            Set-ItemProperty -Path $defaultPath -Name 'Value' -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
        }
    }

    # Never force the default account tile for all users.
    $explorerPolicy = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer'
    if (Test-Path $explorerPolicy) {
        Remove-ItemProperty -Path $explorerPolicy -Name 'UseDefaultTile' -Force -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path $explorerPolicy -Name 'NoChangingAccountPicture' -Force -ErrorAction SilentlyContinue
    }

    # Older privacy/optimisation passes force-denied LetAppsAccessAccountInfo (value 2).
    # That also blocks changing the local account picture in Settings.
    $appPrivacy = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy'
    if (Test-Path $appPrivacy) {
        Remove-ItemProperty -Path $appPrivacy -Name 'LetAppsAccessAccountInfo' -Force -ErrorAction SilentlyContinue
    }
}

function Disable-MicrosoftAccountPolicies {
    Invoke-MSOnlineStep {
        Repair-AccountPersonalizationPolicies

        # Block new Microsoft account additions. Does not lock local-profile picture / Your info pages.
        # 1 = Users can't add Microsoft accounts; 3 = Don't allow Microsoft accounts at all.
        $sysPath = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System'
        if (-not (Test-Path $sysPath)) { New-Item -Path $sysPath -Force | Out-Null }
        Set-ItemProperty -Path $sysPath -Name 'NoConnectedUser' -Value 1 -Type DWord -Force
    } 'Microsoft account add-block (NoConnectedUser) without locking local profile icons'
}

function Get-TargetUserHives {
    $hives = @('HKCU:')
    try {
        foreach ($key in (Get-ChildItem -Path 'Registry::HKEY_USERS' -ErrorAction Stop)) {
            if ($key.PSChildName -match '^S-1-5-21-\d+(-\d+){3}$') {
                $hives += "Registry::HKEY_USERS\$($key.PSChildName)"
            }
        }
    } catch {
        Write-MSOnlineStatus "Loaded user hives could not be enumerated: $($_.Exception.Message)"
    }
    return $hives
}

function Set-ReminderDword {
    param(
        [Parameter(Mandatory)][string]$Root,
        [Parameter(Mandatory)][string]$SubPath,
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][int]$Value
    )

    $full = if ($Root -eq 'HKCU:') { "HKCU:\$SubPath" } else { "$Root\$SubPath" }
    if (-not (Test-Path -LiteralPath $full)) {
        New-Item -Path $full -Force | Out-Null
    }
    Set-ItemProperty -LiteralPath $full -Name $Name -Value $Value -Type DWord -Force
}

function Update-ReminderSettingsForHive {
    param([Parameter(Mandatory)][string]$Root)

    # Full-screen "finish setting up" / Microsoft 365 renewal (SCOOBE)
    Set-ReminderDword -Root $Root -SubPath 'Software\Microsoft\Windows\CurrentVersion\UserProfileEngagement' -Name 'ScoobeSystemSettingEnabled' -Value 0

    # Official 24H2+ policy: Start-menu account tile reminders for backup, Microsoft 365, storage, and Xbox
    Set-ReminderDword -Root $Root -SubPath 'SOFTWARE\Policies\Microsoft\Windows\CurrentVersion\AccountNotifications' -Name 'DisableAccountNotifications' -Value 1

    # Settings toggle "Show account-related notifications"
    Set-ReminderDword -Root $Root -SubPath 'Software\Microsoft\Windows\CurrentVersion\SystemSettings\AccountNotifications' -Name 'EnableAccountNotifications' -Value 0
    Set-ReminderDword -Root $Root -SubPath 'Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'Start_AccountNotifications' -Value 0

    Set-ReminderDword -Root $Root -SubPath 'SOFTWARE\Policies\Microsoft\Windows\CloudContent' -Name 'DisableTailoredExperiencesWithDiagnosticData' -Value 1
    Set-ReminderDword -Root $Root -SubPath 'SOFTWARE\Policies\Microsoft\Windows\CloudContent' -Name 'DisableSoftLanding' -Value 1

    $cdmValues = @(
        'ContentDeliveryAllowed',
        'RotatingLockScreenEnabled',
        'RotatingLockScreenOverlayEnabled',
        'SubscribedContent-310093Enabled',
        'SubscribedContent-338387Enabled',
        'SubscribedContent-338388Enabled',
        'SubscribedContent-338389Enabled',
        'SubscribedContent-338393Enabled',
        'SubscribedContent-353694Enabled',
        'SubscribedContent-353696Enabled',
        'SubscribedContent-353698Enabled',
        'SubscribedContent-88000326Enabled',
        'SoftLandingEnabled',
        'SystemPaneSuggestionsEnabled',
        'SubscribedContent-310091Enabled',
        'SubscribedContent-314563Enabled'
    )
    foreach ($name in $cdmValues) {
        Set-ReminderDword -Root $Root -SubPath 'Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' -Name $name -Value 0
    }

    # Does not turn backup itself off. Hides the promotion reminder.
    Set-ReminderDword -Root $Root -SubPath 'Software\Microsoft\Windows\CurrentVersion\SettingSync' -Name 'BackupReminder' -Value 0

    $toastNames = @(
        'Windows.SystemToast.BackupReminder',
        'Windows.SystemToast.Suggested',
        'Windows.SystemToast.Account'
    )
    foreach ($toastName in $toastNames) {
        Set-ReminderDword -Root $Root -SubPath "Software\Microsoft\Windows\CurrentVersion\Notifications\Settings\$toastName" -Name 'Enabled' -Value 0
    }

    $notifSub = 'Software\Microsoft\Windows\CurrentVersion\Notifications\Settings'
    $notifFull = if ($Root -eq 'HKCU:') { "HKCU:\$notifSub" } else { "$Root\$notifSub" }
    if (Test-Path -LiteralPath $notifFull) {
        $pattern = 'BackupReminder|WindowsBackup|MicrosoftOfficeHub|OfficeHub|Microsoft365|OutlookForWindows|CloudExperienceHost|SystemToast\.Suggested|SystemToast\.Account|ActionsServer'
        Get-ChildItem -LiteralPath $notifFull -ErrorAction SilentlyContinue | Where-Object {
            $_.PSChildName -match $pattern
        } | ForEach-Object {
            Set-ItemProperty -LiteralPath $_.PSPath -Name 'Enabled' -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
        }
    }
}

function Invoke-DefaultUserHive {
    param([Parameter(Mandatory)][scriptblock]$Action)

    $dat = Join-Path $env:SystemDrive 'Users\Default\NTUSER.DAT'
    if (-not (Test-Path -LiteralPath $dat)) { return }

    $mountName = 'WMDefaultUser'
    $loaded = $false
    try {
        & reg.exe unload "HKU\$mountName" 2>$null | Out-Null
        & reg.exe load "HKU\$mountName" $dat | Out-Null
        if ($LASTEXITCODE -eq 0) {
            $loaded = $true
            & $Action "Registry::HKEY_USERS\$mountName"
        } else {
            Write-MSOnlineStatus 'Default user hive was not loaded. Signed-in users were still updated.'
        }
    } catch {
        Write-MSOnlineStatus "Default user hive skipped: $($_.Exception.Message)"
    } finally {
        if ($loaded) {
            [gc]::Collect()
            [gc]::WaitForPendingFinalizers()
            & reg.exe unload "HKU\$mountName" | Out-Null
        }
    }
}

function Disable-AccountNagsAndBackupPrompts {
    Invoke-MSOnlineStep {
        foreach ($hive in (Get-TargetUserHives)) {
            Update-ReminderSettingsForHive -Root $hive
        }

        Invoke-DefaultUserHive -Action {
            param($root)
            Update-ReminderSettingsForHive -Root $root
        }

        $cloudMachine = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent'
        if (-not (Test-Path $cloudMachine)) { New-Item -Path $cloudMachine -Force | Out-Null }
        Set-ItemProperty -Path $cloudMachine -Name 'DisableWindowsConsumerFeatures' -Value 1 -Type DWord -Force
        Set-ItemProperty -Path $cloudMachine -Name 'DisableSoftLanding' -Value 1 -Type DWord -Force
        Set-ItemProperty -Path $cloudMachine -Name 'DisableCloudOptimizedContent' -Value 1 -Type DWord -Force
        Set-ItemProperty -Path $cloudMachine -Name 'DisableConsumerAccountStateContent' -Value 1 -Type DWord -Force

        # Documented switch for "configure Windows Backup" monitoring reminders. Backup can still be turned on later.
        $windowsBackup = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsBackup'
        if (-not (Test-Path $windowsBackup)) { New-Item -Path $windowsBackup -Force | Out-Null }
        Set-ItemProperty -Path $windowsBackup -Name 'DisableMonitoring' -Value 1 -Type DWord -Force

        Write-MSOnlineStatus 'Backup, Microsoft 365, and account reminders are suppressed for loaded users and the default profile. Sign out for Start and Settings to refresh. An existing backup toast can linger until the next morning.'
    } 'Account, Windows Backup, and Microsoft 365 reminders'
}

function Invoke-DisableMSOnline {
    Write-MSOnlineStatus 'Starting Microsoft Account nag / online prompt suppression for local profiles...'

    Disable-MicrosoftAccountPolicies
    Disable-AccountNagsAndBackupPrompts

    Write-MSOnlineStatus 'Microsoft Account online prompts and nags have been suppressed.'
    Write-MSOnlineStatus 'Local profile account pictures and Settings > Accounts > Your info remain changeable.'
    Write-MSOnlineStatus 'Note: Sign-out / restart recommended for Settings surfaces to refresh. You can still sign into a Microsoft account manually later.'
}

try {
    Invoke-DisableMSOnline

    if (-not $AutomatedMode) {
        Add-Type -AssemblyName System.Windows.Forms
        [System.Windows.Forms.MessageBox]::Show(
            'Backup, Microsoft 365, and Microsoft account reminders are now suppressed with the Start account-notification policy, Windows Backup monitoring, and the backup/365 toast channels.`n`nThis does not turn off backup or a subscription you already use. Sign out or restart. A toast that is already on screen can remain until the next morning.',
            'Disable MS Online / Account Prompts',
            'OK',
            'Information'
        ) | Out-Null
    }

    exit 0
} catch {
    Write-MSOnlineStatus "Failed to apply Microsoft account suppression: $($_.Exception.Message)"
    if (-not $AutomatedMode) {
        try {
            Add-Type -AssemblyName System.Windows.Forms
            [System.Windows.Forms.MessageBox]::Show(
                "Some changes may have failed. Check console output.`nError: $($_.Exception.Message)",
                'Disable MS Online - Warning',
                'OK',
                'Warning'
            ) | Out-Null
        } catch {}
    }
    exit 1
}
