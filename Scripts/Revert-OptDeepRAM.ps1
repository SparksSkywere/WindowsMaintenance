Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Restores the virtualisation features Deep RAM turns off.
# A normal System Optimisation revert does not enable Hyper-V or VBS on its own.

$AutomatedMode = $args -contains '--automated'

function Write-Status { param([string]$m) Write-Host $m }

try {
    Write-Status 'Restoring virtualisation features turned off by Deep RAM...'

    $deviceGuardPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard'
    if (-not (Test-Path $deviceGuardPath)) { New-Item -Path $deviceGuardPath -Force | Out-Null }
    Set-ItemProperty -Path $deviceGuardPath -Name 'EnableVirtualizationBasedSecurity' -Value 1 -Type DWord -Force

    $hvciPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity'
    if (-not (Test-Path $hvciPath)) { New-Item -Path $hvciPath -Force | Out-Null }
    Set-ItemProperty -Path $hvciPath -Name 'Enabled' -Value 1 -Type DWord -Force

    $lsaPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa'
    if (Test-Path $lsaPath) {
        Set-ItemProperty -Path $lsaPath -Name 'LsaCfgFlags' -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
    }

    bcdedit /set hypervisorlaunchtype auto 2>$null | Out-Null

    $deepFeatures = @(
        'Microsoft-Hyper-V-All',
        'VirtualMachinePlatform',
        'Microsoft-Windows-Subsystem-Linux',
        'Containers-DisposableClientVM'
    )
    foreach ($feature in $deepFeatures) {
        try {
            Enable-WindowsOptionalFeature -Online -FeatureName $feature -All -NoRestart -ErrorAction SilentlyContinue | Out-Null
        } catch {}
    }

    Write-Status 'Deep RAM reversal attempted. Restart before using Hyper-V, WSL, Sandbox, or memory integrity.'

    if (-not $AutomatedMode) {
        Add-Type -AssemblyName System.Windows.Forms
        [System.Windows.Forms.MessageBox]::Show(
            'Deep RAM changes were reverted. Restart the PC before using Hyper-V, WSL, Windows Sandbox, or memory integrity.',
            'Revert Deep RAM',
            'OK',
            'Information'
        ) | Out-Null
    }

    exit 0
} catch {
    Write-Status "Deep RAM revert error: $_"
    exit 1
}
