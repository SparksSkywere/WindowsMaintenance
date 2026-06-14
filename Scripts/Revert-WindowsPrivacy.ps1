Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Revert script for WindowsPrivacy.ps1
# Restores many default Windows 11 telemetry, advertising, background app, search, and suggestion behaviors.
# Note: Some core diagnostic data cannot be fully disabled by Microsoft policy even after this.

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
        Write-RevertStatus "Warning during revert of $Description : $($_.Exception.Message)"
    }
}

function Enable-PrivacyServices {
    Invoke-RevertStep {
        $services = @('DiagTrack', 'dmwappushservice', 'MapsBroker', 'lfsvc', 'WpcMonSvc', 'SEMgrSvc', 'RetailDemo', 'wisvc', 'DusmSvc')
        foreach ($s in $services) {
            $svc = Get-Service -Name $s -ErrorAction SilentlyContinue
            if ($svc) {
                Set-Service -Name $s -StartupType Manual -ErrorAction SilentlyContinue
                Start-Service -Name $s -ErrorAction SilentlyContinue
            }
        }
    } 'Privacy-related services'
}

function Enable-AdvertisingAndTelemetry {
    Invoke-RevertStep {
        # Re-enable advertising
        $advPolicy = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo'
        if (Test-Path $advPolicy) { try { Remove-ItemProperty -Path $advPolicy -Name 'DisabledByGroupPolicy' -Force -EA SilentlyContinue } catch {} }

        $advUser = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\AdvertisingInfo'
        if (Test-Path $advUser) { Set-ItemProperty -Path $advUser -Name 'Enabled' -Value 1 -Force -EA SilentlyContinue }

        # Telemetry back toward defaults (Required = 1 on many builds; Optional = 3 where allowed)
        $dcPaths = @('HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection', 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection')
        foreach ($p in $dcPaths) {
            if (-not (Test-Path $p)) { New-Item -Path $p -Force | Out-Null }
            Set-ItemProperty -Path $p -Name 'AllowTelemetry' -Value 1 -Force -EA SilentlyContinue
        }
        $dcPolicy = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection'
        if (Test-Path $dcPolicy) {
            try { Remove-ItemProperty -Path $dcPolicy -Name 'MaxTelemetryAllowed' -Force -EA SilentlyContinue } catch {}
            try { Remove-ItemProperty -Path $dcPolicy -Name 'DisableOneSettingsDownloads' -Force -EA SilentlyContinue } catch {}
            try { Remove-ItemProperty -Path $dcPolicy -Name 'DoNotShowFeedbackNotifications' -Force -EA SilentlyContinue } catch {}
        }

        # Search / Cortana / web search back on (where policies exist)
        $winSearch = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search'
        if (Test-Path $winSearch) {
            try { Remove-ItemProperty -Path $winSearch -Name 'AllowCortana' -Force -EA SilentlyContinue } catch {}
            try { Remove-ItemProperty -Path $winSearch -Name 'AllowCloudSearch' -Force -EA SilentlyContinue } catch {}
            try { Remove-ItemProperty -Path $winSearch -Name 'DisableWebSearch' -Force -EA SilentlyContinue } catch {}
        }

        $searchUser = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Search'
        if (Test-Path $searchUser) {
            try { Set-ItemProperty -Path $searchUser -Name 'BingSearchEnabled' -Value 1 -Force -EA SilentlyContinue } catch {}
        }

        # Re-enable AutoLogger
        $autoLog = 'HKLM:\SYSTEM\CurrentControlSet\Control\WMI\Autologger\AutoLogger-Diagtrack-Listener'
        if (Test-Path $autoLog) {
            try { Set-ItemProperty -Path $autoLog -Name 'Start' -Value 1 -Force -EA SilentlyContinue } catch {}
        }
    } 'Advertising and telemetry policies'
}

function Enable-BackgroundApps {
    Invoke-RevertStep {
        $bg = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications'
        if (Test-Path $bg) {
            try { Remove-ItemProperty -Path $bg -Name 'GlobalUserDisabled' -Force -EA SilentlyContinue } catch {}
        }

        $appPrivacy = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy'
        if (Test-Path $appPrivacy) {
            try { Remove-ItemProperty -Path $appPrivacy -Name 'LetAppsRunInBackground' -Force -EA SilentlyContinue } catch {}
        }
    } 'Background app restrictions'
}

function Revert-CorePrivacyPolicies {
    Invoke-RevertStep {
        # SIUF / feedback
        $siuf = 'HKCU:\SOFTWARE\Microsoft\Siuf\Rules'
        if (Test-Path $siuf) {
            try { Remove-ItemProperty -Path $siuf -Name 'NumberOfSIUFInPeriod' -Force -EA SilentlyContinue } catch {}
        }

        # Tailored experiences
        $privacy = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Privacy'
        if (Test-Path $privacy) {
            try { Set-ItemProperty -Path $privacy -Name 'TailoredExperiencesWithDiagnosticDataEnabled' -Value 1 -Force -EA SilentlyContinue } catch {}
        }

        # Many AppPrivacy permissions back to default (let user decide = 0 or remove policy)
        $appPrivacy = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy'
        if (Test-Path $appPrivacy) {
            $toRemove = @('LetAppsGetDiagnosticInfo','LetAppsAccessAccountInfo','LetAppsAccessCalendar','LetAppsAccessCallHistory','LetAppsAccessContacts','LetAppsAccessEmail','LetAppsAccessMessaging','LetAppsAccessTasks','LetAppsRunInBackground')
            foreach ($n in $toRemove) {
                try { Remove-ItemProperty -Path $appPrivacy -Name $n -Force -EA SilentlyContinue } catch {}
            }
        }

        # Activity feed, clipboard, cross device
        $systemPolicy = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System'
        if (Test-Path $systemPolicy) {
            try { Remove-ItemProperty -Path $systemPolicy -Name 'EnableActivityFeed' -Force -EA SilentlyContinue } catch {}
            try { Remove-ItemProperty -Path $systemPolicy -Name 'PublishUserActivities' -Force -EA SilentlyContinue } catch {}
            try { Remove-ItemProperty -Path $systemPolicy -Name 'UploadUserActivities' -Force -EA SilentlyContinue } catch {}
            try { Remove-ItemProperty -Path $systemPolicy -Name 'AllowCrossDeviceClipboard' -Force -EA SilentlyContinue } catch {}
        }

        # Cloud content consumer features
        $cloudM = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent'
        if (Test-Path $cloudM) {
            try { Remove-ItemProperty -Path $cloudM -Name 'DisableWindowsConsumerFeatures' -Force -EA SilentlyContinue } catch {}
        }
        $cloudU = 'HKCU:\SOFTWARE\Policies\Microsoft\Windows\CloudContent'
        if (Test-Path $cloudU) {
            try { Remove-ItemProperty -Path $cloudU -Name 'DisableTailoredExperiencesWithDiagnosticData' -Force -EA SilentlyContinue } catch {}
        }

        # Delivery Optimization back to default (1 = LAN + internet group, or let Windows decide)
        $do = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization'
        if (Test-Path $do) {
            try { Set-ItemProperty -Path $do -Name 'DODownloadMode' -Value 1 -Force -EA SilentlyContinue } catch {}
        }

        # Location
        $loc = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors'
        if (Test-Path $loc) {
            try { Remove-ItemProperty -Path $loc -Name 'DisableLocation' -Force -EA SilentlyContinue } catch {}
        }

        # Widgets / Feeds / Taskbar news
        $dsh = 'HKLM:\SOFTWARE\Policies\Microsoft\Dsh'
        if (Test-Path $dsh) {
            try { Remove-ItemProperty -Path $dsh -Name 'AllowNewsAndInterests' -Force -EA SilentlyContinue } catch {}
        }
        $feeds = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Feeds'
        if (Test-Path $feeds) {
            try { Remove-ItemProperty -Path $feeds -Name 'EnableFeeds' -Force -EA SilentlyContinue } catch {}
        }
        $feedsU = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Feeds'
        if (Test-Path $feedsU) {
            try { Remove-ItemProperty -Path $feedsU -Name 'ShellFeedsTaskbarViewMode' -Force -EA SilentlyContinue } catch {}
        }

        # Explorer advanced (TaskbarDa, Start_TrackDocs, ShowSyncProviderNotifications)
        $exp = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
        if (Test-Path $exp) {
            try { Remove-ItemProperty -Path $exp -Name 'TaskbarDa' -Force -EA SilentlyContinue } catch {}
            try { Remove-ItemProperty -Path $exp -Name 'Start_TrackDocs' -Force -EA SilentlyContinue } catch {}
            try { Remove-ItemProperty -Path $exp -Name 'ShowSyncProviderNotifications' -Force -EA SilentlyContinue } catch {}
        }

        # CDM suggestions back toward enabled
        $cdm = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'
        if (Test-Path $cdm) {
            $cdmOn = @('RotatingLockScreenEnabled','SubscribedContent-338387Enabled','SubscribedContent-338388Enabled','SubscribedContent-338389Enabled','SubscribedContent-353698Enabled','SoftLandingEnabled','SystemPaneSuggestionsEnabled')
            foreach ($n in $cdmOn) {
                try { Set-ItemProperty -Path $cdm -Name $n -Value 1 -Force -EA SilentlyContinue } catch {}
            }
        }
    } 'Core privacy policy hardening (re-enable)'
}

function Enable-PrivacyScheduledTasks {
    Invoke-RevertStep {
        $tasks = @(
            '\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser',
            '\Microsoft\Windows\Application Experience\ProgramDataUpdater',
            '\Microsoft\Windows\Customer Experience Improvement Program\Consolidator',
            '\Microsoft\Windows\Customer Experience Improvement Program\KernelCeipTask',
            '\Microsoft\Windows\Customer Experience Improvement Program\UsbCeip',
            '\Microsoft\Windows\Feedback\Siuf\DmClient',
            '\Microsoft\Windows\Feedback\Siuf\DmClientOnScenarioDownload'
        )
        foreach ($taskPath in $tasks) {
            try {
                $taskName = Split-Path -Leaf $taskPath
                $task = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
                if ($task) {
                    Enable-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue | Out-Null
                }
            } catch {
                # Ignore missing/protected tasks on revert
            }
        }
    } 'Privacy telemetry scheduled tasks'
}

function Remove-MicrosoftTelemetryBlocks {
    Invoke-RevertStep {
        # Remove firewall rules we created (by our WM- prefix; safe, won't touch other rules)
        $fwRules = Get-NetFirewallRule -DisplayName 'WM-BlockTelemetry-*' -ErrorAction SilentlyContinue
        if ($fwRules) {
            $fwRules | Remove-NetFirewallRule -Confirm:$false -ErrorAction SilentlyContinue
            Write-RevertStatus "  Removed $($fwRules.Count) WM-BlockTelemetry firewall rule(s)."
        }

        # Clean only our marked section from hosts file (leave any user or other custom entries intact)
        $hostsPath = Join-Path $env:SystemRoot 'System32\drivers\etc\hosts'
        if (Test-Path $hostsPath) {
            $markerStart = '# >>> WindowsMaintenance-Telemetry-Block START'
            $markerEnd   = '# >>> WindowsMaintenance-Telemetry-Block END'
            $lines = Get-Content -Path $hostsPath -ErrorAction SilentlyContinue
            $restored = @()
            $skip = $false
            foreach ($line in $lines) {
                $t = $line.Trim()
                if ($t -eq $markerStart) { $skip = $true; continue }
                if ($t -eq $markerEnd)   { $skip = $false; continue }
                if (-not $skip) { $restored += $line }
            }
            Set-Content -Path $hostsPath -Value ($restored -join [Environment]::NewLine) -Force -Encoding ASCII -ErrorAction SilentlyContinue
            Write-RevertStatus '  Cleaned WindowsMaintenance telemetry block section from hosts file (if present).'
        }
    } 'Microsoft telemetry/feedback hosts + firewall blocks'
}

function Revert-WindowsAI {
    # This is mostly a re-enable of Copilot / AI surfaces (user can still disable in Settings)
    Invoke-RevertStep {
        $expAdv = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
        if (Test-Path $expAdv) {
            try { Remove-ItemProperty -Path $expAdv -Name 'ShowCopilotButton' -Force -EA SilentlyContinue } catch {}
            try { Remove-ItemProperty -Path $expAdv -Name 'DisabledHotkeys' -Force -EA SilentlyContinue } catch {}
        }

        $searchSet = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\SearchSettings'
        if (Test-Path $searchSet) {
            try { Remove-ItemProperty -Path $searchSet -Name 'IsCopilotEnabled' -Force -EA SilentlyContinue } catch {}
            try { Remove-ItemProperty -Path $searchSet -Name 'IsCopilotAvailable' -Force -EA SilentlyContinue } catch {}
        }

        $copilot = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot'
        if (Test-Path $copilot) {
            try { Remove-ItemProperty -Path $copilot -Name 'TurnOffWindowsCopilot' -Force -EA SilentlyContinue } catch {}
        }
        $copilotU = 'HKCU:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot'
        if (Test-Path $copilotU) {
            try { Remove-ItemProperty -Path $copilotU -Name 'TurnOffWindowsCopilot' -Force -EA SilentlyContinue } catch {}
        }

        $winAI = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI'
        if (Test-Path $winAI) {
            try { Remove-ItemProperty -Path $winAI -Name 'DisableAIDataAnalysis' -Force -EA SilentlyContinue } catch {}
            try { Remove-ItemProperty -Path $winAI -Name 'DisableSettingsAgent' -Force -EA SilentlyContinue } catch {}
        }

        Write-RevertStatus 'AI / Copilot policies largely removed (features may re-appear; user Settings still control final state).'
    } 'Windows AI / Copilot disablement'
}

function Invoke-RevertWindowsPrivacy {
    Write-RevertStatus 'Starting Windows privacy / telemetry / ads reversal (restoring more default behavior)...'

    Enable-PrivacyServices
    Enable-AdvertisingAndTelemetry
    Enable-BackgroundApps
    Revert-CorePrivacyPolicies
    Enable-PrivacyScheduledTasks
    Remove-MicrosoftTelemetryBlocks

    # Note: We do not auto re-enable full AI here unless specifically requested in the caller.
    # If the original run used --disable-ai, the revert planner task can call this explicitly.

    Write-RevertStatus 'Privacy reversal completed. Many telemetry, ad, and suggestion surfaces are now closer to Windows defaults.'
}

try {
    Invoke-RevertWindowsPrivacy

    if (-not $AutomatedMode) {
        Add-Type -AssemblyName System.Windows.Forms
        [System.Windows.Forms.MessageBox]::Show(
            'Windows privacy hardening has been largely reversed. Some diagnostic data collection and suggestions are now at or near Microsoft defaults.`n`nRestart or sign out for full effect. You can re-apply privacy anytime.',
            'Revert Windows Privacy',
            'OK',
            'Information'
        ) | Out-Null
    }

    exit 0
} catch {
    Write-RevertStatus "Privacy reversal failed: $($_.Exception.Message)"
    exit 1
}
