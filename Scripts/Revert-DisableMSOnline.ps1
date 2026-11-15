Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Revert script for DisableMSOnline.ps1
# Re-enables Microsoft account prompts, backup reminders, "It's all here..." banners,
# account badging, and related consumer nags so the system behaves closer to stock for signed-in or new users.

$AutomatedMode = $args -contains '--automated'

function Write-RevertStatus {
    param([string]$Message)
    Write-Host $Message
}

function Invoke-RevertStep {
    param([scriptblock]$Block, [string]$Description)
    try {
        Write-RevertStatus "Reverting: $Description..."
        & $Block
        Write-RevertStatus "Reverted: $Description"
    } catch {
        Write-RevertStatus "Warning reverting $Description : $($_.Exception.Message)"
    }
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
        Write-RevertStatus "Loaded user hives could not be enumerated: $($_.Exception.Message)"
    }
    return $hives
}

function Remove-HiveValue {
    param(
        [Parameter(Mandatory)][string]$Root,
        [Parameter(Mandatory)][string]$SubPath,
        [Parameter(Mandatory)][string]$Name
    )

    $full = if ($Root -eq 'HKCU:') { "HKCU:\$SubPath" } else { "$Root\$SubPath" }
    if (Test-Path -LiteralPath $full) {
        Remove-ItemProperty -LiteralPath $full -Name $Name -Force -ErrorAction SilentlyContinue
    }
}

function Set-HiveDword {
    param(
        [Parameter(Mandatory)][string]$Root,
        [Parameter(Mandatory)][string]$SubPath,
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][int]$Value
    )

    $full = if ($Root -eq 'HKCU:') { "HKCU:\$SubPath" } else { "$Root\$SubPath" }
    if (-not (Test-Path -LiteralPath $full)) { return }
    Set-ItemProperty -LiteralPath $full -Name $Name -Value $Value -Type DWord -Force -ErrorAction SilentlyContinue
}

function Restore-ReminderSettingsForHive {
    param([Parameter(Mandatory)][string]$Root)

    Remove-HiveValue -Root $Root -SubPath 'Software\Microsoft\Windows\CurrentVersion\UserProfileEngagement' -Name 'ScoobeSystemSettingEnabled'
    Remove-HiveValue -Root $Root -SubPath 'SOFTWARE\Policies\Microsoft\Windows\CurrentVersion\AccountNotifications' -Name 'DisableAccountNotifications'
    Remove-HiveValue -Root $Root -SubPath 'Software\Microsoft\Windows\CurrentVersion\SystemSettings\AccountNotifications' -Name 'EnableAccountNotifications'
    Remove-HiveValue -Root $Root -SubPath 'Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'Start_AccountNotifications'
    Remove-HiveValue -Root $Root -SubPath 'SOFTWARE\Policies\Microsoft\Windows\CloudContent' -Name 'DisableTailoredExperiencesWithDiagnosticData'
    Remove-HiveValue -Root $Root -SubPath 'SOFTWARE\Policies\Microsoft\Windows\CloudContent' -Name 'DisableSoftLanding'
    Remove-HiveValue -Root $Root -SubPath 'Software\Microsoft\Windows\CurrentVersion\SettingSync' -Name 'BackupReminder'

    $cdmRestore = @(
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
        'SubscribedContent-314563Enabled',
        'OemPreInstalledAppsEnabled',
        'PreInstalledAppsEnabled',
        'PreInstalledAppsEverEnabled',
        'SilentInstalledAppsEnabled'
    )
    foreach ($name in $cdmRestore) {
        Set-HiveDword -Root $Root -SubPath 'Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' -Name $name -Value 1
    }

    $toastNames = @(
        'Windows.SystemToast.BackupReminder',
        'Windows.SystemToast.Suggested',
        'Windows.SystemToast.Account'
    )
    foreach ($toastName in $toastNames) {
        Set-HiveDword -Root $Root -SubPath "Software\Microsoft\Windows\CurrentVersion\Notifications\Settings\$toastName" -Name 'Enabled' -Value 1
    }

    $notifSub = 'Software\Microsoft\Windows\CurrentVersion\Notifications\Settings'
    $notifFull = if ($Root -eq 'HKCU:') { "HKCU:\$notifSub" } else { "$Root\$notifSub" }
    if (Test-Path -LiteralPath $notifFull) {
        $pattern = 'BackupReminder|WindowsBackup|MicrosoftOfficeHub|OfficeHub|Microsoft365|OutlookForWindows|CloudExperienceHost|SystemToast\.Suggested|SystemToast\.Account|ActionsServer'
        Get-ChildItem -LiteralPath $notifFull -ErrorAction SilentlyContinue | Where-Object {
            $_.PSChildName -match $pattern
        } | ForEach-Object {
            Set-ItemProperty -LiteralPath $_.PSPath -Name 'Enabled' -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
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
        }
    } catch {
        Write-RevertStatus "Default user hive skipped: $($_.Exception.Message)"
    } finally {
        if ($loaded) {
            [gc]::Collect()
            [gc]::WaitForPendingFinalizers()
            & reg.exe unload "HKU\$mountName" | Out-Null
        }
    }
}

function Enable-MicrosoftAccountNags {
    Invoke-RevertStep {
        # Re-allow Microsoft accounts (removes the block; users can still choose local)
        $sysPath = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System'
        if (Test-Path $sysPath) {
            try { Remove-ItemProperty -Path $sysPath -Name 'NoConnectedUser' -Force -ErrorAction SilentlyContinue } catch {}
        }

        # Clear any device overrides that locked Settings > Accounts > Your info / sign-in options
        $pmDevicePath = 'HKLM:\SOFTWARE\Microsoft\PolicyManager\current\device\Settings'
        if (Test-Path $pmDevicePath) {
            try { Remove-ItemProperty -Path $pmDevicePath -Name 'AllowYourAccount' -Force -ErrorAction SilentlyContinue } catch {}
            try { Remove-ItemProperty -Path $pmDevicePath -Name 'AllowSignInOptions' -Force -ErrorAction SilentlyContinue } catch {}
        }

        # PolicyManager schema defaults must stay at 1 (Allowed). Never delete Value on these keys.
        foreach ($name in @('AllowYourAccount', 'AllowSignInOptions')) {
            $defaultPath = "HKLM:\SOFTWARE\Microsoft\PolicyManager\default\Settings\$name"
            if (Test-Path $defaultPath) {
                try { Set-ItemProperty -Path $defaultPath -Name 'Value' -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue } catch {}
            }
        }

        $explorerPolicy = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer'
        if (Test-Path $explorerPolicy) {
            try { Remove-ItemProperty -Path $explorerPolicy -Name 'UseDefaultTile' -Force -ErrorAction SilentlyContinue } catch {}
            try { Remove-ItemProperty -Path $explorerPolicy -Name 'NoChangingAccountPicture' -Force -ErrorAction SilentlyContinue } catch {}
        }

        # Leave LetAppsAccessAccountInfo unset so local profile pictures stay changeable.
        $appPrivacy = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy'
        if (Test-Path $appPrivacy) {
            try { Remove-ItemProperty -Path $appPrivacy -Name 'LetAppsAccessAccountInfo' -Force -ErrorAction SilentlyContinue } catch {}
        }
    } 'Microsoft account policy blocks'

    Invoke-RevertStep {
        foreach ($hive in (Get-TargetUserHives)) {
            Restore-ReminderSettingsForHive -Root $hive
        }

        Invoke-DefaultUserHive -Action {
            param($root)
            Restore-ReminderSettingsForHive -Root $root
        }

        $cloudMachine = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent'
        if (Test-Path $cloudMachine) {
            foreach ($name in @('DisableWindowsConsumerFeatures', 'DisableSoftLanding', 'DisableCloudOptimizedContent', 'DisableConsumerAccountStateContent')) {
                try { Remove-ItemProperty -Path $cloudMachine -Name $name -Force -ErrorAction SilentlyContinue } catch {}
            }
        }

        $windowsBackup = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsBackup'
        if (Test-Path $windowsBackup) {
            try { Remove-ItemProperty -Path $windowsBackup -Name 'DisableMonitoring' -Force -ErrorAction SilentlyContinue } catch {}
        }
    } 'Account, Windows Backup, and Microsoft 365 reminders'
}

try {
    Write-RevertStatus 'Starting reversal of Microsoft Account / online prompt suppression...'

    Enable-MicrosoftAccountNags

    Write-RevertStatus 'Reversal complete. Microsoft account prompts, backup reminders, and related banners may now appear again in Settings and Start (sign out/in or restart recommended).'

    if (-not $AutomatedMode) {
        Add-Type -AssemblyName System.Windows.Forms
        [System.Windows.Forms.MessageBox]::Show(
            'Microsoft account prompts and online nags have been re-enabled (stock behaviour restored for local + potential MS accounts).`n`nSome banners require sign-out or restart to reappear.',
            'Revert MS Account Prompts',
            'OK',
            'Information'
        ) | Out-Null
    }

    exit 0
} catch {
    Write-RevertStatus "Reversal encountered issues: $($_.Exception.Message)"
    if (-not $AutomatedMode) {
        try {
            Add-Type -AssemblyName System.Windows.Forms
            [System.Windows.Forms.MessageBox]::Show("Some reversals may not have applied fully. See console.", 'Revert Warning', 'OK', 'Warning') | Out-Null
        } catch {}
    }
    exit 1
}
