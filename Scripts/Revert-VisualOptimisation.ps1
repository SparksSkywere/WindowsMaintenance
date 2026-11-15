Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Revert for VisualOptimisation.ps1
# Restores animations/effects and undoes classic-grey old-school mode (ThemeActive + system colours).

$AutomatedMode = $args -contains '--automated'
$MarkerPath = 'HKCU:\Software\WindowsMaintenance\VisualOptimisation'

function Write-Status { param([string]$m) Write-Host $m }

function Ensure-Key {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -Path $Path -Force | Out-Null
    }
}

function Close-SettingsIfOpened {
    param([int]$TimeoutSeconds = 6)

    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    while ((Get-Date) -lt $deadline) {
        $settings = @(Get-Process -Name 'SystemSettings' -ErrorAction SilentlyContinue)
        if ($settings.Count -gt 0) {
            Start-Sleep -Milliseconds 500
            foreach ($proc in $settings) {
                try { Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue } catch {}
            }
            return
        }
        Start-Sleep -Milliseconds 200
    }
}

try {
    Write-Status 'Reverting visual optimisations...'

    Ensure-Key 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects'
    Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects' -Name 'VisualFXSetting' -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue

    Ensure-Key 'HKCU:\Control Panel\Desktop\WindowMetrics'
    Set-ItemProperty -Path 'HKCU:\Control Panel\Desktop\WindowMetrics' -Name 'MinAnimate' -Value '1' -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path 'HKCU:\Control Panel\Desktop\WindowMetrics' -Name 'PaddedBorderWidth' -Value '-60' -Force -ErrorAction SilentlyContinue

    Ensure-Key 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
    Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'TaskbarAnimations' -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'ListviewAlphaSelect' -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'ListviewShadow' -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue

    Ensure-Key 'HKCU:\Control Panel\Desktop'
    Set-ItemProperty -Path 'HKCU:\Control Panel\Desktop' -Name 'DragFullWindows' -Value '1' -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path 'HKCU:\Control Panel\Desktop' -Name 'FontSmoothing' -Value '2' -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path 'HKCU:\Control Panel\Desktop' -Name 'MenuShowDelay' -Value '400' -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path 'HKCU:\Control Panel\Desktop' -Name 'UserPreferencesMask' -Value ([byte[]](0x9E, 0x3E, 0x07, 0x80, 0x12, 0x00, 0x00, 0x00)) -Force -ErrorAction SilentlyContinue

    Ensure-Key 'HKCU:\Software\Microsoft\Windows\DWM'
    Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\DWM' -Name 'EnableAeroPeek' -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\DWM' -Name 'CompositionPolicy' -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\DWM' -Name 'ColorizationOpaqueBlend' -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue

    Ensure-Key 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'
    Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' -Name 'EnableTransparency' -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue

    # Re-enable visual styles (undo classic grey ThemeActive=0)
    Ensure-Key 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ThemeManager'
    Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ThemeManager' -Name 'ThemeActive' -Value 1 -Force -ErrorAction SilentlyContinue
    Ensure-Key 'HKLM:\Software\Microsoft\Windows\CurrentVersion\ThemeManager'
    Set-ItemProperty -Path 'HKLM:\Software\Microsoft\Windows\CurrentVersion\ThemeManager' -Name 'ThemeActive' -Value 1 -Force -ErrorAction SilentlyContinue

    $oldSchool = 0
    if (Test-Path -LiteralPath $MarkerPath) {
        try { $oldSchool = [int](Get-ItemProperty -LiteralPath $MarkerPath -Name 'OldSchoolTheme' -ErrorAction SilentlyContinue).OldSchoolTheme } catch { $oldSchool = 0 }
    }

    if ($oldSchool -eq 1) {
        Write-Status 'Restoring default Windows theme and colours (undoing classic grey)...'
        $defaultTheme = Join-Path $env:SystemRoot 'Resources\Themes\aero.theme'
        if (Test-Path -LiteralPath $defaultTheme) {
            Start-Process -FilePath $defaultTheme | Out-Null
            Close-SettingsIfOpened
        }
        Set-ItemProperty -Path $MarkerPath -Name 'OldSchoolTheme' -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
    }

    Write-Status 'Visual effects restored. Sign out if classic grey controls are still showing.'

    if (-not $AutomatedMode) {
        Add-Type -AssemblyName System.Windows.Forms
        [System.Windows.Forms.MessageBox]::Show(
            'Visual optimisations have been reverted. Animations, visual styles, and the default theme are restored.',
            'Revert Visual Optimisation',
            'OK',
            'Information'
        ) | Out-Null
    }

    exit 0
} catch {
    Write-Status "Visual revert error: $_"
    exit 1
}
