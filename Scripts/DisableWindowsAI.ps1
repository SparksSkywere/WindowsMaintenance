Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Disable Windows AI features and the scheduled tasks that keep them active.
# Standalone from Windows Privacy and System Optimisation.
# Does not remove inbox apps. Policies and tasks can be reversed by Revert-DisableWindowsAI.ps1.

$AutomatedMode = $args -contains '--automated'

function Write-AIStatus {
    param([string]$Message)
    Write-Host $Message
}

function Invoke-AIStep {
    param(
        [scriptblock]$Block,
        [string]$Description
    )

    try {
        Write-AIStatus "Applying: $Description..."
        & $Block
        Write-AIStatus "Completed: $Description"
    } catch {
        Write-AIStatus "Warning during $Description : $($_.Exception.Message)"
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
        Write-AIStatus "Loaded user hives could not be enumerated: $($_.Exception.Message)"
    }
    return $hives
}

function Set-HiveDword {
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

function Set-MachineDword {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][int]$Value
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -Path $Path -Force | Out-Null
    }
    Set-ItemProperty -LiteralPath $Path -Name $Name -Value $Value -Type DWord -Force
}

function Disable-WindowsAIPolicies {
    Invoke-AIStep {
        Set-MachineDword -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot' -Name 'TurnOffWindowsCopilot' -Value 1

        $windowsAI = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI'
        Set-MachineDword -Path $windowsAI -Name 'DisableAIDataAnalysis' -Value 1
        Set-MachineDword -Path $windowsAI -Name 'AllowRecallEnablement' -Value 0
        Set-MachineDword -Path $windowsAI -Name 'DisableSettingsAgent' -Value 1
        Set-MachineDword -Path $windowsAI -Name 'DisableClickToDo' -Value 1

        Set-MachineDword -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer' -Name 'DisableSearchBoxSuggestions' -Value 1
        Set-MachineDword -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Speech' -Name 'AllowOnlineSpeechRecognition' -Value 0
        Set-MachineDword -Path 'HKLM:\SOFTWARE\Policies\Microsoft\InputPersonalization' -Name 'AllowInputPersonalization' -Value 0

        foreach ($hive in (Get-TargetUserHives)) {
            Set-HiveDword -Root $hive -SubPath 'SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot' -Name 'TurnOffWindowsCopilot' -Value 1
            Set-HiveDword -Root $hive -SubPath 'SOFTWARE\Policies\Microsoft\Windows\WindowsAI' -Name 'DisableAIDataAnalysis' -Value 1
            Set-HiveDword -Root $hive -SubPath 'SOFTWARE\Policies\Microsoft\Windows\WindowsAI' -Name 'AllowRecallEnablement' -Value 0

            Set-HiveDword -Root $hive -SubPath 'Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'ShowCopilotButton' -Value 0

            Set-HiveDword -Root $hive -SubPath 'Software\Microsoft\Windows\CurrentVersion\SearchSettings' -Name 'IsCopilotEnabled' -Value 0
            Set-HiveDword -Root $hive -SubPath 'Software\Microsoft\Windows\CurrentVersion\SearchSettings' -Name 'IsCopilotAvailable' -Value 0
            Set-HiveDword -Root $hive -SubPath 'Software\Microsoft\Windows\CurrentVersion\SearchSettings' -Name 'IsDynamicSearchBoxEnabled' -Value 0
            Set-HiveDword -Root $hive -SubPath 'Software\Microsoft\Windows\CurrentVersion\SearchSettings' -Name 'IsAADCloudSearchEnabled' -Value 0
            Set-HiveDword -Root $hive -SubPath 'Software\Microsoft\Windows\CurrentVersion\SearchSettings' -Name 'IsMSACloudSearchEnabled' -Value 0

            Set-HiveDword -Root $hive -SubPath 'Software\Microsoft\InputPersonalization' -Name 'RestrictImplicitInkCollection' -Value 1
            Set-HiveDword -Root $hive -SubPath 'Software\Microsoft\InputPersonalization' -Name 'RestrictImplicitTextCollection' -Value 1
            Set-HiveDword -Root $hive -SubPath 'Software\Microsoft\InputPersonalization\TrainedDataStore' -Name 'HarvestContacts' -Value 0
            Set-HiveDword -Root $hive -SubPath 'Software\Microsoft\Speech_OneCore\Settings\OnlineSpeechPrivacy' -Name 'HasAccepted' -Value 0
            Set-HiveDword -Root $hive -SubPath 'Software\Microsoft\Speech_OneCore\Settings\VoiceActivation\UserPreferenceForAllApps' -Name 'AgentActivationEnabled' -Value 0
        }

        Stop-Process -Name 'Copilot' -Force -ErrorAction SilentlyContinue
        Write-AIStatus 'Copilot, Recall, Click to Do, online speech, and cloud-assisted search policies are off. Sign out so the taskbar button updates.'
    } 'Windows AI policies'
}

function Disable-WindowsAIScheduledTasks {
    Invoke-AIStep {
        $tasks = @(Get-ScheduledTask -ErrorAction SilentlyContinue | Where-Object {
            $taskPath = [string]$_.TaskPath
            $taskName = [string]$_.TaskName
            $underWindows = $taskPath -like '\Microsoft\Windows\*'
            $aiPath = (
                $taskPath -like '\Microsoft\Windows\WindowsAI\*' -or
                $taskPath -like '\Microsoft\Windows\Copilot\*' -or
                $taskPath -like '\Microsoft\Windows\*Copilot*'
            )
            $aiName = $underWindows -and ($taskName -like '*Recall*' -or $taskName -like '*Copilot*')
            $aiPath -or $aiName
        })

        if ($tasks.Count -eq 0) {
            Write-AIStatus 'No Windows AI scheduled tasks were present on this machine.'
            return
        }

        foreach ($task in $tasks) {
            $fullName = "$($task.TaskPath)$($task.TaskName)"
            try {
                Disable-ScheduledTask -TaskName $task.TaskName -TaskPath $task.TaskPath -ErrorAction Stop | Out-Null
                Write-AIStatus "Disabled task: $fullName"
            } catch {
                Write-AIStatus "Task left unchanged ($fullName): $($_.Exception.Message)"
            }
        }
    } 'Windows AI scheduled tasks'
}

function Invoke-DisableWindowsAI {
    Write-AIStatus 'Starting Windows AI disablement...'
    Disable-WindowsAIPolicies
    Disable-WindowsAIScheduledTasks
    Write-AIStatus 'Windows AI disablement finished. Inbox AI apps are left installed and are turned off by policy.'
}

try {
    Invoke-DisableWindowsAI

    if (-not $AutomatedMode) {
        Add-Type -AssemblyName System.Windows.Forms
        [System.Windows.Forms.MessageBox]::Show(
            'Windows AI features are disabled by policy, and Windows AI scheduled tasks that were present have been disabled. Copilot, Recall, Click to Do, online speech, and cloud-assisted search are covered. Installed inbox apps were not removed.`n`nSign out or restart so the Copilot button and search surfaces update.',
            'Disable Windows AI',
            'OK',
            'Information'
        ) | Out-Null
    }

    exit 0
} catch {
    Write-AIStatus "Failed to disable Windows AI: $($_.Exception.Message)"
    if (-not $AutomatedMode) {
        try {
            Add-Type -AssemblyName System.Windows.Forms
            [System.Windows.Forms.MessageBox]::Show(
                "Some AI changes may have failed. Check console output.`nError: $($_.Exception.Message)",
                'Disable Windows AI - Warning',
                'OK',
                'Warning'
            ) | Out-Null
        } catch {}
    }
    exit 1
}
