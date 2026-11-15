$AutomatedMode = $args -contains '--automated'
$OldSchoolTheme = ($args -contains '--old-school') -or ($args -contains '--oldschool')

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$BundledClassicTheme = Join-Path $ScriptDir 'classicgrey.theme'
$MarkerPath = 'HKCU:\Software\WindowsMaintenance\VisualOptimisation'

# Win95/98 classic grey RGB triples (R G B)
$script:ClassicGreyColors = @{
    ActiveBorder          = '192 192 192'
    ActiveTitle           = '0 0 128'
    AppWorkspace          = '128 128 128'
    Background            = '0 128 128'
    ButtonAlternateFace   = '181 181 181'
    ButtonDkShadow        = '0 0 0'
    ButtonFace            = '192 192 192'
    ButtonHilight         = '255 255 255'
    ButtonLight           = '192 192 192'
    ButtonShadow          = '128 128 128'
    ButtonText            = '0 0 0'
    GradientActiveTitle   = '0 0 128'
    GradientInactiveTitle = '128 128 128'
    GrayText              = '128 128 128'
    Hilight               = '0 0 128'
    HilightText           = '255 255 255'
    HotTrackingColor      = '0 0 128'
    InactiveBorder        = '192 192 192'
    InactiveTitle         = '128 128 128'
    InactiveTitleText     = '192 192 192'
    InfoText              = '0 0 0'
    InfoWindow            = '255 255 225'
    Menu                  = '192 192 192'
    MenuBar               = '192 192 192'
    MenuHilight           = '0 0 128'
    MenuText              = '0 0 0'
    Scrollbar             = '192 192 192'
    TitleText             = '255 255 255'
    Window                = '255 255 255'
    WindowFrame           = '0 0 0'
    WindowText            = '0 0 0'
}

# COLOR_* indices for SetSysColors (user32)
$script:SysColorMap = @{
    Scrollbar             = 0
    Background            = 1
    ActiveTitle           = 2
    InactiveTitle         = 3
    Menu                  = 4
    Window                = 5
    WindowFrame           = 6
    MenuText              = 7
    WindowText            = 8
    TitleText             = 9
    ActiveBorder          = 10
    InactiveBorder        = 11
    AppWorkspace          = 12
    Hilight               = 13
    HilightText           = 14
    ButtonFace            = 15
    ButtonShadow          = 16
    GrayText              = 17
    ButtonText            = 18
    InactiveTitleText     = 19
    ButtonHilight         = 20
    ButtonDkShadow        = 21
    ButtonLight           = 22
    InfoText              = 23
    InfoWindow            = 24
    ButtonAlternateFace   = 25
    HotTrackingColor      = 26
    GradientActiveTitle   = 27
    GradientInactiveTitle = 28
    MenuHilight           = 29
    MenuBar               = 30
}

function Write-VisualStatus {
    param([string]$Message)
    Write-Host $Message -ForegroundColor Cyan
}

function Safe-Execute {
    param(
        [scriptblock]$Block,
        [string]$Description
    )

    try {
        Write-VisualStatus "Applying: $Description..."
        & $Block
        Write-Host "Completed: $Description" -ForegroundColor Green
    } catch {
        Write-Host "Error during $Description : $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Ensure-Key {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -Path $Path -Force | Out-Null
    }
}

function ConvertTo-RgbDword {
    param([string]$RgbText)

    $parts = $RgbText.Split(' ', [System.StringSplitOptions]::RemoveEmptyEntries)
    if ($parts.Count -lt 3) { return 0 }
    $r = [int]$parts[0]; $g = [int]$parts[1]; $b = [int]$parts[2]
    return ($r -bor ($g -shl 8) -bor ($b -shl 16))
}

function Initialize-ClassicNativeHelpers {
    if ('WinClassicNative' -as [type]) { return }

    Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public static class WinClassicNative {
    [DllImport("user32.dll")]
    public static extern bool SetSysColors(int cElements, int[] lpaElements, int[] lpaRgbValues);

    [DllImport("user32.dll", SetLastError=true)]
    public static extern bool SystemParametersInfo(uint uiAction, uint uiParam, IntPtr pvParam, uint fWinIni);
}
"@
}

function Show-VisualOptionsDialog {
    Add-Type -AssemblyName System.Windows.Forms | Out-Null
    Add-Type -AssemblyName System.Drawing | Out-Null

    $form = New-Object System.Windows.Forms.Form
    $form.Text = 'Visual Optimisation'
    $form.Size = New-Object System.Drawing.Size(470, 230)
    $form.StartPosition = 'CenterScreen'
    $form.FormBorderStyle = 'FixedDialog'
    $form.MaximizeBox = $false
    $form.MinimizeBox = $false
    $form.TopMost = $true

    $label = New-Object System.Windows.Forms.Label
    $label.Location = New-Object System.Drawing.Point(16, 16)
    $label.Size = New-Object System.Drawing.Size(420, 48)
    $label.Text = 'Reduce animations and transparency for snappier UI. Optional old-school mode uses classic Windows 95/98 grey controls and flat toolbars (not Vista/7 glass).'

    $oldSchool = New-Object System.Windows.Forms.CheckBox
    $oldSchool.Location = New-Object System.Drawing.Point(20, 78)
    $oldSchool.Size = New-Object System.Drawing.Size(420, 40)
    $oldSchool.Text = 'Old school theme (classic grey Win95/98 look + max visual reduction)'
    $oldSchool.Checked = $false

    $hint = New-Object System.Windows.Forms.Label
    $hint.Location = New-Object System.Drawing.Point(40, 118)
    $hint.Size = New-Object System.Drawing.Size(400, 18)
    $hint.ForeColor = [System.Drawing.Color]::FromArgb(95, 105, 120)
    $hint.Text = 'Start/taskbar stay modern; Win32 menus, buttons, and toolbars go classic grey.'

    $ok = New-Object System.Windows.Forms.Button
    $ok.Text = 'Apply'
    $ok.Location = New-Object System.Drawing.Point(260, 155)
    $ok.Size = New-Object System.Drawing.Size(85, 28)
    $ok.DialogResult = [System.Windows.Forms.DialogResult]::OK

    $cancel = New-Object System.Windows.Forms.Button
    $cancel.Text = 'Cancel'
    $cancel.Location = New-Object System.Drawing.Point(355, 155)
    $cancel.Size = New-Object System.Drawing.Size(85, 28)
    $cancel.DialogResult = [System.Windows.Forms.DialogResult]::Cancel

    $form.Controls.AddRange(@($label, $oldSchool, $hint, $ok, $cancel))
    $form.AcceptButton = $ok
    $form.CancelButton = $cancel

    $result = $form.ShowDialog()
    if ($result -ne [System.Windows.Forms.DialogResult]::OK) {
        return $null
    }

    return [pscustomobject]@{
        OldSchoolTheme = [bool]$oldSchool.Checked
    }
}

function Set-VisualFXSetting {
    Safe-Execute {
        Ensure-Key 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects'
        Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects' -Name 'VisualFXSetting' -Value 2 -Type DWord -Force
    } 'VisualFXSetting'
}

function Set-MinAnimate {
    Safe-Execute {
        Ensure-Key 'HKCU:\Control Panel\Desktop\WindowMetrics'
        Set-ItemProperty -Path 'HKCU:\Control Panel\Desktop\WindowMetrics' -Name 'MinAnimate' -Value '0' -Force
    } 'MinAnimate'
}

function Set-TaskbarAnimations {
    Safe-Execute {
        Ensure-Key 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
        Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'TaskbarAnimations' -Value 0 -Type DWord -Force
    } 'TaskbarAnimations'
}

function Set-AlwaysHibernateThumbnails {
    Safe-Execute {
        Ensure-Key 'HKCU:\Software\Microsoft\Windows\DWM'
        Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\DWM' -Name 'AlwaysHibernateThumbnails' -Value 0 -Type DWord -Force
    } 'AlwaysHibernateThumbnails'
}

function Set-ListviewAlphaSelect {
    Safe-Execute {
        Ensure-Key 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
        Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'ListviewAlphaSelect' -Value 0 -Type DWord -Force
        Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'ListviewShadow' -Value 0 -Type DWord -Force
        Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'IconsOnly' -Value 0 -Type DWord -Force
    } 'Explorer listview effects'
}

function Set-DragFullWindows {
    Safe-Execute {
        Ensure-Key 'HKCU:\Control Panel\Desktop'
        Set-ItemProperty -Path 'HKCU:\Control Panel\Desktop' -Name 'DragFullWindows' -Value '0' -Force
    } 'DragFullWindows'
}

function Set-AnimationAndCursorTweaks {
    Safe-Execute {
        Ensure-Key 'HKCU:\Control Panel\Desktop'
        Set-ItemProperty -Path 'HKCU:\Control Panel\Desktop' -Name 'FontSmoothing' -Value '2' -Force
        Set-ItemProperty -Path 'HKCU:\Control Panel\Desktop' -Name 'MenuShowDelay' -Value '0' -Force
        Set-ItemProperty -Path 'HKCU:\Control Panel\Desktop' -Name 'CursorShadow' -Value '0' -Force -ErrorAction SilentlyContinue
        # Flat menus / reduced effects mask (keeps composition usable for the shell)
        Set-ItemProperty -Path 'HKCU:\Control Panel\Desktop' -Name 'UserPreferencesMask' -Value ([byte[]](0x90, 0x12, 0x01, 0x80, 0x10, 0x00, 0x00, 0x00)) -Force
    } 'Desktop animation / cursor tweaks'
}

function Set-DwmPerformanceTweaks {
    Safe-Execute {
        Ensure-Key 'HKCU:\Software\Microsoft\Windows\DWM'
        Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\DWM' -Name 'CompositionPolicy' -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\DWM' -Name 'DisableThumbnails' -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\DWM' -Name 'EnableAeroPeek' -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\DWM' -Name 'ColorizationOpaqueBlend' -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue

        Ensure-Key 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'
        Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' -Name 'EnableTransparency' -Value 0 -Type DWord -Force
    } 'DWM performance tweaks'
}

function Ensure-ThemesRemainActive {
    Safe-Execute {
        # Default path keeps themes on so personalization stays usable.
        # Old-school mode overrides ThemeActive to 0 afterwards for classic grey controls.
        Ensure-Key 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ThemeManager'
        Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ThemeManager' -Name 'ThemeActive' -Value 1 -Force
    } 'Keep Windows themes active (default path)'
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

function Set-ClassicGreySystemColors {
    Ensure-Key 'HKCU:\Control Panel\Colors'
    foreach ($name in $script:ClassicGreyColors.Keys) {
        Set-ItemProperty -Path 'HKCU:\Control Panel\Colors' -Name $name -Value $script:ClassicGreyColors[$name] -Force
    }

    Initialize-ClassicNativeHelpers
    $indices = New-Object System.Collections.Generic.List[int]
    $values = New-Object System.Collections.Generic.List[int]
    foreach ($name in $script:SysColorMap.Keys) {
        if (-not $script:ClassicGreyColors.ContainsKey($name)) { continue }
        $indices.Add([int]$script:SysColorMap[$name])
        $values.Add([int](ConvertTo-RgbDword -RgbText $script:ClassicGreyColors[$name]))
    }
    if ($indices.Count -gt 0) {
        [void][WinClassicNative]::SetSysColors($indices.Count, $indices.ToArray(), $values.ToArray())
    }

    # SPI_SETFLATMENU = 0x1023, SPIF_UPDATEINIFILE | SPIF_SENDCHANGE = 3
    [void][WinClassicNative]::SystemParametersInfo(0x1023, 1, [IntPtr]::Zero, 3)
}

function Apply-OldSchoolTheme {
    Safe-Execute {
        # 1) Classic grey colour scheme (Win95/98)
        Set-ClassicGreySystemColors

        if (Test-Path -LiteralPath $BundledClassicTheme) {
            Start-Process -FilePath $BundledClassicTheme | Out-Null
            Close-SettingsIfOpened
        }

        # 2) Turn off visual styles for this user so Win32 controls use classic grey 3D chrome.
        #    HKCU only — do not set HKLM ThemeActive=0 (that locked personalization machine-wide).
        Ensure-Key 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ThemeManager'
        Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ThemeManager' -Name 'ThemeActive' -Value 0 -Force

        Ensure-Key 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'
        Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' -Name 'EnableTransparency' -Value 0 -Type DWord -Force
        Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' -Name 'ColorPrevalence' -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' -Name 'AppsUseLightTheme' -Value 1 -Type DWord -Force
        Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' -Name 'SystemUsesLightTheme' -Value 1 -Type DWord -Force

        Ensure-Key 'HKCU:\Software\Microsoft\Windows\DWM'
        Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\DWM' -Name 'ColorPrevalence' -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\DWM' -Name 'EnableWindowColorization' -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\DWM' -Name 'ColorizationOpaqueBlend' -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue

        # Extra flat/classic metrics
        Ensure-Key 'HKCU:\Control Panel\Desktop\WindowMetrics'
        Set-ItemProperty -Path 'HKCU:\Control Panel\Desktop\WindowMetrics' -Name 'MinAnimate' -Value '0' -Force
        Set-ItemProperty -Path 'HKCU:\Control Panel\Desktop\WindowMetrics' -Name 'BorderWidth' -Value '-15' -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path 'HKCU:\Control Panel\Desktop\WindowMetrics' -Name 'PaddedBorderWidth' -Value '0' -Force -ErrorAction SilentlyContinue

        Ensure-Key $MarkerPath
        Set-ItemProperty -Path $MarkerPath -Name 'OldSchoolTheme' -Value 1 -Type DWord -Force
        Set-ItemProperty -Path $MarkerPath -Name 'ThemePath' -Value $BundledClassicTheme -Force

        Write-Host '  Classic grey Win95/98 colours applied; visual styles off for this user.' -ForegroundColor DarkYellow
        Write-Host '  Modern Start/taskbar stay as-is. Sign out once if some windows still look themed.' -ForegroundColor DarkYellow
    } 'Old school theme (classic grey)'
}

function Invoke-VisualOptimisation {
    param([bool]$UseOldSchoolTheme = $false)

    Write-VisualStatus 'Starting Visual Optimisation (Win10/Win11 safe)...'

    Set-VisualFXSetting
    Set-MinAnimate
    Set-TaskbarAnimations
    Set-AlwaysHibernateThumbnails
    Set-ListviewAlphaSelect
    Set-DragFullWindows
    Set-AnimationAndCursorTweaks
    Set-DwmPerformanceTweaks

    if ($UseOldSchoolTheme) {
        Apply-OldSchoolTheme
    } else {
        Ensure-ThemesRemainActive
        Ensure-Key $MarkerPath
        Set-ItemProperty -Path $MarkerPath -Name 'OldSchoolTheme' -Value 0 -Type DWord -Force
    }

    Write-Host 'Visual optimisation completed.' -ForegroundColor Green
}

if (-not $AutomatedMode) {
    $choice = Show-VisualOptionsDialog
    if ($null -eq $choice) {
        Write-Host 'Visual optimisation cancelled.' -ForegroundColor Yellow
        exit 0
    }
    $OldSchoolTheme = [bool]$choice.OldSchoolTheme
}

Invoke-VisualOptimisation -UseOldSchoolTheme:$OldSchoolTheme
exit 0
