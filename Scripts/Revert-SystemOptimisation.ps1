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

    # Re-enable a few common services that optimisers disable (examples; adjust as needed)
    $servicesToManual = @('SysMain', 'WSearch', 'DiagTrack')  # DiagTrack may be intentionally left off in privacy
    foreach ($svcName in $servicesToManual) {
        $s = Get-Service -Name $svcName -ErrorAction SilentlyContinue
        if ($s) {
            try { Set-Service -Name $svcName -StartupType Manual -ErrorAction SilentlyContinue } catch {}
        }
    }

    # Re-enable Superfetch / SysMain if it was fully disabled
    $sysMain = Get-Service -Name 'SysMain' -ErrorAction SilentlyContinue
    if ($sysMain) {
        try { Set-Service -Name 'SysMain' -StartupType Manual -ErrorAction SilentlyContinue } catch {}
    }

    # Common visual / UI perf keys that system opt often touches (re-enable)
    $adv = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
    if (Test-Path $adv) {
        try { Set-ItemProperty -Path $adv -Name 'TaskbarAnimations' -Value 1 -Force -EA SilentlyContinue } catch {}
    }

    # Re-enable some background / maintenance tasks that may have been reduced
    # (Many are covered better by the Privacy revert; this is supplementary)

    # RAM / Svchost tuning is hard to perfectly reverse without knowing the exact original state.
    # We can at least remove some aggressive host process split limits if they were set.
    $ramKeys = @(
        'HKLM:\SYSTEM\CurrentControlSet\Control',
        'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile'
    )
    # Best effort - do not force delete; just note.
    Write-Status 'Note: Some low-level RAM / process host split tunings are difficult to perfectly auto-revert without a full baseline snapshot.'

    # Power throttling / background activity
    try {
        $power = 'HKLM:\SYSTEM\CurrentControlSet\Control\Power'
        if (Test-Path $power) {
            # Leave most alone; the optimiser often sets some QoS or throttling.
        }
    } catch {}

    Write-Status 'System Optimisation reversal attempted. Restart recommended for service and power changes to take full effect.'

    if (-not $AutomatedMode) {
        Add-Type -AssemblyName System.Windows.Forms
        [System.Windows.Forms.MessageBox]::Show('System Optimisation changes have been reverted where easily reversible (power plan, some services, visual effects). A restart is recommended.', 'Revert System Optimisation', 'OK', 'Information') | Out-Null
    }

    exit 0
} catch {
    Write-Status "System Optimisation revert error: $_"
    exit 1
}
