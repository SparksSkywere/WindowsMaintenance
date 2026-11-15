Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Re-enable Windows AI policies and scheduled tasks disabled by DisableWindowsAI.ps1.
# Does not reinstall apps. Removed packages, if any were removed by an older run, stay removed.

$AutomatedMode = $args -contains '--automated'

function Write-RevertStatus {
    param([string]$Message)
    Write-Host $Message
}

function Invoke-RevertStep {
    param(
        [scriptblock]$Block,
        [string]$Description
    )

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

function Remove-MachineValue {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Name
    )

    if (Test-Path -LiteralPath $Path) {
        Remove-ItemProperty -LiteralPath $Path -Name $Name -Force -ErrorAction SilentlyContinue
    }
}

function Enable-WindowsAIPolicies {
    Invoke-RevertStep {
        Remove-MachineValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot' -Name 'TurnOffWindowsCopilot'
        Remove-MachineValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI' -Name 'DisableAIDataAnalysis'
        Remove-MachineValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI' -Name 'AllowRecallEnablement'
        Remove-MachineValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI' -Name 'DisableSettingsAgent'
        Remove-MachineValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI' -Name 'DisableClickToDo'
        Remove-MachineValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI' -Name 'AllowRecallExport'
        Remove-MachineValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer' -Name 'DisableSearchBoxSuggestions'
        Remove-MachineValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Speech' -Name 'AllowOnlineSpeechRecognition'
        Remove-MachineValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\InputPersonalization' -Name 'AllowInputPersonalization'
        Remove-MachineValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy' -Name 'LetAppsAccessSystemAIModels'

        foreach ($hive in (Get-TargetUserHives)) {
            Remove-HiveValue -Root $hive -SubPath 'SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot' -Name 'TurnOffWindowsCopilot'
            Remove-HiveValue -Root $hive -SubPath 'SOFTWARE\Policies\Microsoft\Windows\WindowsAI' -Name 'DisableAIDataAnalysis'
            Remove-HiveValue -Root $hive -SubPath 'SOFTWARE\Policies\Microsoft\Windows\WindowsAI' -Name 'AllowRecallEnablement'
            Remove-HiveValue -Root $hive -SubPath 'SOFTWARE\Policies\Microsoft\Windows\WindowsAI' -Name 'DisableClickToDo'
            Remove-HiveValue -Root $hive -SubPath 'Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'ShowCopilotButton'
            Remove-HiveValue -Root $hive -SubPath 'Software\Microsoft\Windows\Shell\Copilot' -Name 'CopilotDisabled'
            Remove-HiveValue -Root $hive -SubPath 'Software\Microsoft\Windows\Shell\Copilot\BingChat' -Name 'IsUserEligible'
            Remove-HiveValue -Root $hive -SubPath 'Software\Microsoft\Windows\CurrentVersion\SearchSettings' -Name 'IsCopilotEnabled'
            Remove-HiveValue -Root $hive -SubPath 'Software\Microsoft\Windows\CurrentVersion\SearchSettings' -Name 'IsCopilotAvailable'
            Remove-HiveValue -Root $hive -SubPath 'Software\Microsoft\Windows\CurrentVersion\SearchSettings' -Name 'IsDynamicSearchBoxEnabled'
            Remove-HiveValue -Root $hive -SubPath 'Software\Microsoft\Windows\CurrentVersion\SearchSettings' -Name 'IsAADCloudSearchEnabled'
            Remove-HiveValue -Root $hive -SubPath 'Software\Microsoft\Windows\CurrentVersion\SearchSettings' -Name 'IsMSACloudSearchEnabled'
            Remove-HiveValue -Root $hive -SubPath 'Software\Microsoft\InputPersonalization' -Name 'RestrictImplicitInkCollection'
            Remove-HiveValue -Root $hive -SubPath 'Software\Microsoft\InputPersonalization' -Name 'RestrictImplicitTextCollection'
            Remove-HiveValue -Root $hive -SubPath 'Software\Microsoft\InputPersonalization\TrainedDataStore' -Name 'HarvestContacts'
            Remove-HiveValue -Root $hive -SubPath 'Software\Microsoft\Speech_OneCore\Settings\OnlineSpeechPrivacy' -Name 'HasAccepted'
            Remove-HiveValue -Root $hive -SubPath 'Software\Microsoft\Speech_OneCore\Settings\VoiceActivation\UserPreferenceForAllApps' -Name 'AgentActivationEnabled'
        }

        Write-RevertStatus 'AI policies removed. Windows can show Copilot and Recall again after sign-out, subject to the user Settings toggles.'
    } 'Windows AI policies'
}

function Enable-WindowsAIScheduledTasks {
    Invoke-RevertStep {
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
            Write-RevertStatus 'No Windows AI scheduled tasks were present to re-enable.'
            return
        }

        foreach ($task in $tasks) {
            $fullName = "$($task.TaskPath)$($task.TaskName)"
            try {
                Enable-ScheduledTask -TaskName $task.TaskName -TaskPath $task.TaskPath -ErrorAction Stop | Out-Null
                Write-RevertStatus "Enabled task: $fullName"
            } catch {
                Write-RevertStatus "Task left unchanged ($fullName): $($_.Exception.Message)"
            }
        }
    } 'Windows AI scheduled tasks'
}

try {
    Write-RevertStatus 'Starting Windows AI re-enable...'
    Enable-WindowsAIPolicies
    Enable-WindowsAIScheduledTasks
    Write-RevertStatus 'Windows AI reversal finished. Sign out or restart for the Copilot button and search surfaces to return.'

    if (-not $AutomatedMode) {
        Add-Type -AssemblyName System.Windows.Forms
        [System.Windows.Forms.MessageBox]::Show(
            'Windows AI policies have been removed and matching scheduled tasks were enabled again. Sign out or restart for Copilot and Recall surfaces to return. Apps that were uninstalled by an older run are not reinstalled by this revert.',
            'Revert Windows AI',
            'OK',
            'Information'
        ) | Out-Null
    }

    exit 0
} catch {
    Write-RevertStatus "Windows AI reversal failed: $($_.Exception.Message)"
    exit 1
}
