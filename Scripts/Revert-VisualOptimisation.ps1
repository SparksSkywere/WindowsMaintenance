Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Revert for VisualOptimisation.ps1
# Re-enables common visual effects, animations, and DWM behaviors that were disabled for performance.

$AutomatedMode = $args -contains '--automated'

function Write-Status { param([string]$m) Write-Host $m }

try {
    Write-Status 'Reverting visual optimisations (re-enabling animations and effects)...'

    # VisualFXSetting back toward "Let Windows choose" (default is usually 0 or 1 in many profiles)
    try {
        Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects' -Name 'VisualFXSetting' -Value 0 -Force -EA SilentlyContinue
    } catch {}

    # MinAnimate (window minimize animation)
    $wm = 'HKCU:\Control Panel\Desktop\WindowMetrics'
    if (Test-Path $wm) {
        try { Set-ItemProperty -Path $wm -Name 'MinAnimate' -Value 1 -Force -EA SilentlyContinue } catch {}
    }

    # Taskbar animations
    try {
        Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'TaskbarAnimations' -Value 1 -Force -EA SilentlyContinue
    } catch {}

    # Common other visual keys that optimisers touch (best effort)
    $adv = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
    if (Test-Path $adv) {
        try { Set-ItemProperty -Path $adv -Name 'ListviewAlphaSelect' -Value 1 -Force -EA SilentlyContinue } catch {}
        try { Set-ItemProperty -Path $adv -Name 'ListviewShadow' -Value 1 -Force -EA SilentlyContinue } catch {}
    }

    # Re-enable transparency / Mica effects where policy exists (Windows 11)
    $dwm = 'HKCU:\Software\Microsoft\Windows\DWM'
    if (-not (Test-Path $dwm)) { New-Item -Path $dwm -Force | Out-Null }
    try { Set-ItemProperty -Path $dwm -Name 'EnableAeroPeek' -Value 1 -Force -EA SilentlyContinue } catch {}
    try { Set-ItemProperty -Path $dwm -Name 'AlwaysHibernateThumbnails' -Value 1 -Force -EA SilentlyContinue } catch {}

    Write-Status 'Visual effects largely re-enabled. A sign-out or explorer restart may be needed for some changes.'

    if (-not $AutomatedMode) {
        Add-Type -AssemblyName System.Windows.Forms
        [System.Windows.Forms.MessageBox]::Show('Visual optimisations have been reverted. Animations and effects are re-enabled.', 'Revert Visual Optimisation', 'OK', 'Information') | Out-Null
    }

    exit 0
} catch {
    Write-Status "Visual revert error: $_"
    exit 1
}
