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

function Enable-MicrosoftAccountNags {
    Invoke-RevertStep {
        # Re-allow Microsoft accounts (removes the block; users can still choose local)
        $sysPath = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System'
        if (Test-Path $sysPath) {
            try { Remove-ItemProperty -Path $sysPath -Name 'NoConnectedUser' -Force -ErrorAction SilentlyContinue } catch {}
        }

        # Re-enable account integration prompts via PolicyManager (best effort)
        $pmPaths = @(
            'HKLM:\SOFTWARE\Microsoft\PolicyManager\current\device\Settings',
            'HKLM:\SOFTWARE\Microsoft\PolicyManager\default\Settings\AllowYourAccount'
        )
        foreach ($p in $pmPaths) {
            if (Test-Path $p) {
                try { Remove-ItemProperty -Path $p -Name 'AllowYourAccount' -Force -ErrorAction SilentlyContinue } catch {}
                try { Remove-ItemProperty -Path $p -Name 'AllowSignInOptions' -Force -ErrorAction SilentlyContinue } catch {}
                try { Remove-ItemProperty -Path $p -Name 'Value' -Force -ErrorAction SilentlyContinue } catch {}
            }
        }
    } 'Microsoft account policy blocks'

    Invoke-RevertStep {
        # Re-enable Scoobe / "finish setting up" engagement
        $engagementPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\UserProfileEngagement'
        if (Test-Path $engagementPath) {
            try { Remove-ItemProperty -Path $engagementPath -Name 'ScoobeSystemSettingEnabled' -Force -ErrorAction SilentlyContinue } catch {}
        }

        # Re-enable account-related notifications / badges in Start & Settings
        $advExplorerPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
        if (Test-Path $advExplorerPath) {
            try { Remove-ItemProperty -Path $advExplorerPath -Name 'Start_AccountNotifications' -Force -ErrorAction SilentlyContinue } catch {}
        }

        # Re-enable Windows consumer features / tailored experiences / backup-style nags
        $cloudMachine = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent'
        if (Test-Path $cloudMachine) {
            try { Remove-ItemProperty -Path $cloudMachine -Name 'DisableWindowsConsumerFeatures' -Force -ErrorAction SilentlyContinue } catch {}
        }
        $cloudUser = 'HKCU:\SOFTWARE\Policies\Microsoft\Windows\CloudContent'
        if (Test-Path $cloudUser) {
            try { Remove-ItemProperty -Path $cloudUser -Name 'DisableTailoredExperiencesWithDiagnosticData' -Force -ErrorAction SilentlyContinue } catch {}
        }

        # Re-enable many ContentDelivery suggestion/offer surfaces (reverses the suppression)
        $cdmPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'
        if (Test-Path $cdmPath) {
            $cdmRestore = @(
                'RotatingLockScreenEnabled',
                'RotatingLockScreenOverlayEnabled',
                'SubscribedContent-338387Enabled',
                'SubscribedContent-338388Enabled',
                'SubscribedContent-338389Enabled',
                'SubscribedContent-338393Enabled',
                'SubscribedContent-353694Enabled',
                'SubscribedContent-353696Enabled',
                'SubscribedContent-353698Enabled',
                'SoftLandingEnabled',
                'SystemPaneSuggestionsEnabled',
                'SubscribedContent-310091Enabled',
                'SubscribedContent-314563Enabled',
                'ContentDeliveryAllowed',
                'OemPreInstalledAppsEnabled',
                'PreInstalledAppsEnabled',
                'PreInstalledAppsEverEnabled',
                'SilentInstalledAppsEnabled'
            )
            foreach ($name in $cdmRestore) {
                try { Set-ItemProperty -Path $cdmPath -Name $name -Value 1 -Force -ErrorAction SilentlyContinue } catch {}
            }
        }

        # Re-enable backup reminder surfaces
        $backupReminder = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\SettingSync'
        if (Test-Path $backupReminder) {
            try { Remove-ItemProperty -Path $backupReminder -Name 'BackupReminder' -Force -ErrorAction SilentlyContinue } catch {}
        }

        # Re-enable suggested / account toasts
        $notifSettings = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Notifications\Settings'
        if (Test-Path $notifSettings) {
            $suggestedPaths = @(
                "$notifSettings\Windows.SystemToast.Suggested",
                "$notifSettings\Windows.SystemToast.Account"
            )
            foreach ($p in $suggestedPaths) {
                if (Test-Path $p) {
                    try { Remove-ItemProperty -Path $p -Name 'Enabled' -Force -ErrorAction SilentlyContinue } catch {}
                }
            }
        }
    } 'Account nags, backup prompts, banners, and notification badging'
}

try {
    Write-RevertStatus 'Starting reversal of Microsoft Account / online prompt suppression...'

    Enable-MicrosoftAccountNags

    Write-RevertStatus 'Reversal complete. Microsoft account prompts, backup reminders, and related banners may now appear again in Settings and Start (sign out/in or restart recommended).'

    if (-not $AutomatedMode) {
        Add-Type -AssemblyName System.Windows.Forms
        [System.Windows.Forms.MessageBox]::Show(
            'Microsoft account prompts and online nags have been re-enabled (stock behavior restored for local + potential MS accounts).`n`nSome banners require sign-out or restart to reappear.',
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
