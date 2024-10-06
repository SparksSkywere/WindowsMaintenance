Clear-Host
# Uninstall OneDrive for Windows
[System.Windows.MessageBox]::Show('Windows OneDrive Removal, click Ok to close', 'Windows Install Cleaner', 'Ok', 'Information')

# Function to disable OneDrive startup for current user
Function Disable-OneDriveStartup {
    $regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run"
    if (Test-Path $regPath) {
        Set-ItemProperty -Path $regPath -Name "OneDrive" -Value ([byte[]](0x03, 0x00, 0x00, 0x00, 0x21, 0xB9, 0xDE, 0xB3, 0x96, 0xD7, 0xD0, 0x01))
        Write-Output "Disabled OneDrive startup."
    }
}

# Kill OneDrive and Explorer processes
Function Stop-Process {
    Write-Output "Stopping OneDrive and Explorer processes..."
    taskkill /F /IM "OneDrive.exe" /T
    taskkill /F /IM "explorer.exe" /T
}

# Uninstall OneDrive
Function Uninstall-OneDrive {
    $oneDriveSetupPaths = @(
        "$env:systemroot\System32\OneDriveSetup.exe",
        "$env:systemroot\SysWOW64\OneDriveSetup.exe"
    )
    foreach ($path in $oneDriveSetupPaths) {
        if (Test-Path $path) {
            Write-Output "Uninstalling OneDrive..."
            & $path /uninstall
        }
    }
}

# Remove OneDrive leftovers
Function Remove-OneDriveLeftovers {
    Write-Output "Removing OneDrive leftovers..."
    $paths = @(
        "$env:localappdata\Microsoft\OneDrive",
        "$env:programdata\Microsoft OneDrive",
        "C:\OneDriveTemp"
    )
    foreach ($path in $paths) {
        Remove-Item -Recurse -Force -ErrorAction SilentlyContinue $path
    }
}

# Remove OneDrive from Explorer sidebar
Function Remove-OneDriveFromSidebar {
    Write-Output "Removing OneDrive from Explorer sidebar..."
    New-PSDrive -PSProvider "Registry" -Root "HKEY_CLASSES_ROOT" -Name "HKCR"
    $clsidPath = "HKCR:\CLSID\{018D5C66-4533-4307-9B53-224DE2ED1FE6}"
    $clsidWowPath = "HKCR:\Wow6432Node\CLSID\{018D5C66-4533-4307-9B53-224DE2ED1FE6}"
    
    mkdir -Force $clsidPath
    Set-ItemProperty -Path $clsidPath -Name "System.IsPinnedToNameSpaceTree" -Value 0
    mkdir -Force $clsidWowPath
    Set-ItemProperty -Path $clsidWowPath -Name "System.IsPinnedToNameSpaceTree" -Value 0
    
    Remove-PSDrive "HKCR"
}

# Remove OneDrive for new users
Function Remove-OneDriveForNewUsers {
    Write-Output "Removing OneDrive from new user profiles..."
    reg load "hku\Default" "C:\Users\Default\NTUSER.DAT" | Out-Null
    reg delete "HKEY_USERS\Default\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" /v "OneDriveSetup" /f | Out-Null
    reg unload "hku\Default" | Out-Null
}

# Remove Start Menu entry
Function Remove-StartMenuEntry {
    Write-Output "Removing OneDrive Start Menu entry..."
    Remove-Item -Force -ErrorAction SilentlyContinue "$env:userprofile\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\OneDrive.lnk"
}

# Restart explorer
Function Restart-Explorer {
    Write-Output "Restarting Explorer..."
    Start-Process "explorer.exe"
    Start-Sleep 5  # Allow time for Explorer to reload
}

# Main execution
Disable-OneDriveStartup
Stop-Process
Uninstall-OneDrive
Remove-OneDriveLeftovers
Remove-OneDriveFromSidebar
Remove-OneDriveForNewUsers
Remove-StartMenuEntry
Restart-Explorer

# Final message
[System.Windows.MessageBox]::Show('OneDrive Uninstalled', 'Windows Troubleshooting', 'Ok', 'Information')

Exit
# Created by Chris Masters