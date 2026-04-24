$AutomatedMode = $args -contains "--automated"

function Write-VisualStatus {
    param([string]$Message)

    if ($AutomatedMode) {
        Write-Host $Message -ForegroundColor Cyan
    } else {
        Write-Host $Message -ForegroundColor Cyan
    }
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

function Set-VisualFXSetting {
    Safe-Execute {
        Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" -Name "VisualFXSetting" -Value 2 -Force
    } "VisualFXSetting"
}

function Set-MinAnimate {
    Safe-Execute {
        if (-not (Test-Path "HKCU:\Control Panel\Desktop\WindowMetrics")) {
            Write-Host "Path HKCU:\Control Panel\Desktop\WindowMetrics not found." -ForegroundColor DarkGray
            return
        }

        Set-ItemProperty -Path "HKCU:\Control Panel\Desktop\WindowMetrics" -Name "MinAnimate" -Value 0 -Force
    } "MinAnimate"
}

function Set-TaskbarAnimations {
    Safe-Execute {
        Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarAnimations" -Value 0 -Force
    } "TaskbarAnimations"
}

function Set-TaskbarAnimationsMachine {
    Safe-Execute {
        Set-ItemProperty -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarAnimations" -Value 0 -Force
    } "TaskbarAnimations2"
}

function Set-CompositionPolicy {
    Safe-Execute {
        Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\DWM" -Name "CompositionPolicy" -Value 0 -Force
    } "CompositionPolicy"
}

function Set-ColorizationOpaqueBlend {
    Safe-Execute {
        Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\DWM" -Name "ColorizationOpaqueBlend" -Value 0 -Force
    } "ColorizationOpaqueBlend"
}

function Set-AlwaysHibernateThumbnails {
    Safe-Execute {
        Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\DWM" -Name "AlwaysHibernateThumbnails" -Value 0 -Force
    } "AlwaysHibernateThumbnails"
}

function Set-DisableThumbnails {
    Safe-Execute {
        Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\DWM" -Name "DisableThumbnails" -Value 1 -Force
    } "DisableThumbnails"
}

function Set-ListviewAlphaSelect {
    Safe-Execute {
        Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "ListviewAlphaSelect" -Value 0 -Force
    } "ListviewAlphaSelect"
}

function Set-DragFullWindows {
    Safe-Execute {
        Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "DragFullWindows" -Value 0 -Force
    } "DragFullWindows"
}

function Set-FontSmoothing {
    Safe-Execute {
        Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "FontSmoothing" -Value 0 -Force
    } "FontSmoothing"
}

function Set-ThemeManagerUser {
    Safe-Execute {
        Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\ThemeManager" -Name "ThemeActive" -Value 0 -Force
    } "ThemeManager"
}

function Set-ThemeManagerMachine {
    Safe-Execute {
        Set-ItemProperty -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\ThemeManager" -Name "ThemeActive" -Value 0 -Force
    } "ThemeManager2"
}

function Set-UserPreferencesMask {
    Safe-Execute {
        Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "UserPreferencesMask" -Value ([byte[]](0x90, 0x12, 0x01, 0x80, 0x10, 0x00, 0x00, 0x00)) -Force
    } "UserPreferencesMask"
}

function Restart-ThemeService {
    Safe-Execute {
        Restart-Service -Name "Themes" -Force
    } "RestartThemeService"
}

function Invoke-VisualOptimisation {
    Write-VisualStatus "Starting Visual Optimisation..."

    Set-VisualFXSetting
    Set-MinAnimate
    Set-TaskbarAnimations
    Set-TaskbarAnimationsMachine
    Set-CompositionPolicy
    Set-ColorizationOpaqueBlend
    Set-AlwaysHibernateThumbnails
    Set-DisableThumbnails
    Set-ListviewAlphaSelect
    Set-DragFullWindows
    Set-FontSmoothing
    Set-ThemeManagerUser
    Set-ThemeManagerMachine
    Set-UserPreferencesMask
    Restart-ThemeService

    Write-Host "Visual optimisation completed." -ForegroundColor Green
}

Invoke-VisualOptimisation
