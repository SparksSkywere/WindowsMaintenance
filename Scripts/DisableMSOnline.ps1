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

function Disable-MicrosoftAccountPolicies {
    Invoke-MSOnlineStep {
        # Block new Microsoft account sign-ins / additions (helps hide sign-in tabs and some forced prompts)
        $sysPath = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System'
        if (-not (Test-Path $sysPath)) { New-Item -Path $sysPath -Force | Out-Null }
        Set-ItemProperty -Path $sysPath -Name 'NoConnectedUser' -Value 1 -Force

        # PolicyManager device settings to suppress account integration prompts (common on 24H2+)
        $pmDevicePath = 'HKLM:\SOFTWARE\Microsoft\PolicyManager\current\device\Settings'
        if (-not (Test-Path $pmDevicePath)) { New-Item -Path $pmDevicePath -Force | Out-Null }
        Set-ItemProperty -Path $pmDevicePath -Name 'AllowYourAccount' -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $pmDevicePath -Name 'AllowSignInOptions' -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue

        # Default/Settings policy location sometimes used
        $pmDefaultPath = 'HKLM:\SOFTWARE\Microsoft\PolicyManager\default\Settings\AllowYourAccount'
        if (-not (Test-Path $pmDefaultPath)) { New-Item -Path $pmDefaultPath -Force | Out-Null }
        Set-ItemProperty -Path $pmDefaultPath -Name 'Value' -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
    } 'Microsoft account policy blocks (NoConnectedUser + PolicyManager)'
}

function Disable-AccountNagsAndBackupPrompts {
    Invoke-MSOnlineStep {
        # Disable "Let's finish setting up your device" / Scoobe engagement (reduces initial and ongoing MS account pressure)
        $engagementPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\UserProfileEngagement'
        if (-not (Test-Path $engagementPath)) { New-Item -Path $engagementPath -Force | Out-Null }
        Set-ItemProperty -Path $engagementPath -Name 'ScoobeSystemSettingEnabled' -Value 0 -Force

        # Suppress account-related notifications and badges in Start and Settings (directly targets "account" nags/badging)
        # This affects "Show account-related notifications" surface used for backup and sign-in reminders
        $advExplorerPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
        if (-not (Test-Path $advExplorerPath)) { New-Item -Path $advExplorerPath -Force | Out-Null }
        # Common community-mapped value for account notification visibility (0 = hide)
        Set-ItemProperty -Path $advExplorerPath -Name 'Start_AccountNotifications' -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue

        # Also ensure no MS account sign-in badging in Start (complements the above)
        Set-ItemProperty -Path $advExplorerPath -Name 'Start_TrackDocs' -Value 0 -Force -ErrorAction SilentlyContinue

        # Disable Windows consumer features / backup and "get more out of your device" style nags
        $cloudMachine = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent'
        if (-not (Test-Path $cloudMachine)) { New-Item -Path $cloudMachine -Force | Out-Null }
        Set-ItemProperty -Path $cloudMachine -Name 'DisableWindowsConsumerFeatures' -Value 1 -Force

        $cloudUser = 'HKCU:\SOFTWARE\Policies\Microsoft\Windows\CloudContent'
        if (-not (Test-Path $cloudUser)) { New-Item -Path $cloudUser -Force | Out-Null }
        Set-ItemProperty -Path $cloudUser -Name 'DisableTailoredExperiencesWithDiagnosticData' -Value 1 -Force

        # Extra Content Delivery for "backup / account / offer" surfaces
        $cdmPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'
        if (-not (Test-Path $cdmPath)) { New-Item -Path $cdmPath -Force | Out-Null }
        # These cover lockscreen, suggestions, offers, and account/backup style promotions
        $cdmValues = @(
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
            'SubscribedContent-314563Enabled'
        )
        foreach ($name in $cdmValues) {
            Set-ItemProperty -Path $cdmPath -Name $name -Value 0 -Force -ErrorAction SilentlyContinue
        }

        # Disable Windows Backup promotion reminders where surfaced in Accounts/Settings
        # (These do not block actual backup if user enables OneDrive/Windows Backup later)
        $backupReminder = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\SettingSync'
        if (-not (Test-Path $backupReminder)) { New-Item -Path $backupReminder -Force | Out-Null }
        Set-ItemProperty -Path $backupReminder -Name 'BackupReminder' -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue

        # Additional notification suppression for suggested / tips that often carry MS account upsell
        $notifSettings = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Notifications\Settings'
        if (Test-Path $notifSettings) {
            # Suppress Windows suggested toasts that promote account features
            $suggestedPaths = @(
                "$notifSettings\Windows.SystemToast.Suggested",
                "$notifSettings\Windows.SystemToast.Account"
            )
            foreach ($p in $suggestedPaths) {
                if (-not (Test-Path $p)) { New-Item -Path $p -Force | Out-Null }
                Set-ItemProperty -Path $p -Name 'Enabled' -Value 0 -Force -ErrorAction SilentlyContinue
            }
        }
    } 'Account nags, backup prompts, "It''s all here", and notification badging'
}

function Invoke-DisableMSOnline {
    Write-MSOnlineStatus 'Starting Microsoft Account nag / online prompt suppression for local profiles...'

    Disable-MicrosoftAccountPolicies
    Disable-AccountNagsAndBackupPrompts

    Write-MSOnlineStatus 'Microsoft Account online prompts and nags have been suppressed.'
    Write-MSOnlineStatus 'Note: Sign-out / restart recommended for Settings surfaces to refresh. You can still sign into a Microsoft account manually later.'
}

try {
    Invoke-DisableMSOnline

    if (-not $AutomatedMode) {
        Add-Type -AssemblyName System.Windows.Forms
        [System.Windows.Forms.MessageBox]::Show(
            'Microsoft account prompts and online nags have been disabled for local accounts (backup reminders, "It''s all here with a Microsoft account", sign-in tabs, account badges, and many suggestion surfaces).`n`nRestart or sign out/in for full effect in Settings and Start menu.',
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
