Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Generic "cannot automatically revert" script.
# Used by the new selection-driven automated workflow for actions that are one-way, destructive,
# or not practical to reverse without user intervention or full system restore.

$AutomatedMode = $args -contains '--automated'
$TaskName = if ($args.Count -gt 1) { $args[1] } else { 'the selected maintenance task' }

function Write-Status { param([string]$m) Write-Host $m }

Write-Status "Reversal requested for: $TaskName"
Write-Status 'This action cannot be automatically reversed by the tool.'
Write-Status 'Reasons may include: deleted files/profiles, applied disk repairs, removed inbox apps (use Reinstall Default Apps), defragmentation, or one-time cleanups.'
Write-Status 'Recommendations:'
Write-Status '  - Use System Restore or a recent backup if available.'
Write-Status '  - For removed apps: run the "Reinstall Default Apps" task from the selector.'
Write-Status '  - For privacy / setting changes: re-apply the opposite (Apply) privacy or MS account prompt tasks.'
Write-Status '  - For OneDrive: use the dedicated Revert-UninstallOneDrive task if it was the action taken.'

if (-not $AutomatedMode) {
    try {
        Add-Type -AssemblyName System.Windows.Forms
        [System.Windows.Forms.MessageBox]::Show(
            "Reversal for '$TaskName' is not automatically supported.`n`nSee the console for guidance. Use System Restore, the Reinstall Apps task, or manually re-apply opposite settings where applicable.",
            'Revert Not Available',
            'OK',
            'Information'
        ) | Out-Null
    } catch {}
}

exit 0
