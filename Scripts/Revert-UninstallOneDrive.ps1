Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Revert / Re-enable OneDrive after Uninstallonedrive.ps1
# Best effort: attempts to re-register the OneDrive per-machine or per-user package and starts the client.
# Full reinstall may still require the user to run the official OneDrive installer or Microsoft Store.

$AutomatedMode = $args -contains '--automated'

function Write-Status { param([string]$m) Write-Host $m }

try {
    Write-Status 'Attempting to restore OneDrive integration...'

    # Common locations for the OneDrive installer / package after uninstall
    $odPaths = @(
        "$env:LOCALAPPDATA\Microsoft\OneDrive\OneDrive.exe",
        "$env:ProgramFiles\Microsoft OneDrive\OneDrive.exe",
        "$env:ProgramFiles (x86)\Microsoft OneDrive\OneDrive.exe"
    )

    $found = $false
    foreach ($p in $odPaths) {
        if (Test-Path $p) {
            Write-Status "Found OneDrive at $p - launching..."
            Start-Process -FilePath $p -ArgumentList '/client=auto' -ErrorAction SilentlyContinue
            $found = $true
            break
        }
    }

    if (-not $found) {
        # Try to re-register the AppX / provisioned package if still in the image
        Write-Status 'OneDrive executable not found in common locations. Attempting AppX re-registration (may require internet / Store)...'
        try {
            Get-AppxPackage -AllUsers *OneDrive* -ErrorAction SilentlyContinue | ForEach-Object {
                Add-AppxPackage -Register "$($_.InstallLocation)\AppxManifest.xml" -DisableDevelopmentMode -ErrorAction SilentlyContinue
            }
        } catch { Write-Status "AppX re-register attempt: $_" }
    }

    # Restart explorer so tray / shell integration can appear
    try {
        Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 1
        Start-Process explorer.exe
    } catch {}

    Write-Status 'OneDrive restore attempted. You may still need to sign in or run the official OneDrive setup for full functionality.'

    if (-not $AutomatedMode) {
        Add-Type -AssemblyName System.Windows.Forms
        [System.Windows.Forms.MessageBox]::Show('OneDrive revert attempted. Check the system tray or run the OneDrive installer from Microsoft if it does not appear.', 'Revert OneDrive Uninstall', 'OK', 'Information') | Out-Null
    }

    exit 0
} catch {
    Write-Status "OneDrive revert error: $_"
    exit 1
}
