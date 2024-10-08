Clear-Host
# A real basic script going to locations and then deleting, then going to the next in the line and deleting

# Function to show or hide the console
function Show-Console {
    param ([Switch]$Show, [Switch]$Hide)

    if (-not ("Console.Window" -as [type])) {
        Add-Type -Name Window -Namespace Console -MemberDefinition '
        [DllImport("Kernel32.dll")]
        public static extern IntPtr GetConsoleWindow();
        [DllImport("user32.dll")]
        public static extern bool ShowWindow(IntPtr hWnd, Int32 nCmdShow);
        '
    }
    
    $consolePtr = [Console.Window]::GetConsoleWindow()
    if ($Show) {
        [Console.Window]::ShowWindow($consolePtr, 5)
    } elseif ($Hide) {
        [Console.Window]::ShowWindow($consolePtr, 0)
    }
}

# Hide the console
Show-Console -Hide

# Function to show completion message
function ExecutionCompleted {
    [System.Windows.Forms.MessageBox]::Show('Operation Completed', 'Windows Maintenance', [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
}

# Cleanup commands and locations
function UserCleaner {
    try {
        Get-ChildItem -Path 'C:\Windows\Temp' -Recurse -Force | Remove-Item -Force -Recurse
        Get-ChildItem -Path 'C:\Windows\Prefetch' -Recurse -Force | Remove-Item -Force -Recurse
        Get-ChildItem -Path 'C:\Users\*\AppData\Local\Temp' -Recurse -Force | Remove-Item -Force -Recurse
        ExecutionCompleted
    } catch {
        Write-Host "Error during UserCleaner execution: $_" -ForegroundColor Red
    }
}

function CleanupSystem {
    try {
        # Declare variables for the folders we want to clean up
        $tempFolder = "$env:TEMP"
        $appData = "$env:APPDATA"
        $localAppData = "$env:LOCALAPPDATA"

        # Delete temporary files
        Get-ChildItem -Path $tempFolder -File -Recurse -Force | Remove-Item -Force

        # Delete temporary internet files
        if (Test-Path "$appData\Microsoft\Windows\INetCache") {
            Get-ChildItem "$appData\Microsoft\Windows\INetCache" -Recurse -Force | Remove-Item -Force
        }

        # Clear the event logs
        Clear-EventLog -LogName Application, Security, System

        # Delete files in the temporary AppData folders that are older than 30 days
        Get-ChildItem -Path $appData -File -Recurse -Force | Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-30) } | Remove-Item -Force
        Get-ChildItem -Path $localAppData -File -Recurse -Force | Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-30) } | Remove-Item -Force

        ExecutionCompleted
    } catch {
        Write-Host "Error during CleanupSystem execution: $_" -ForegroundColor Red
    }
}

# Function to clean temporary or deleted files, including Windows updates
function TempAndDeletedFilesCleaner {
    try {
        # Delete temporary files and Windows Update cleanup
        Remove-Item "C:\Windows\SoftwareDistribution\Download\*" -Recurse -Force
        Get-ChildItem -Path 'C:\Windows\Temp' -Recurse -Force | Remove-Item -Force
        Get-ChildItem -Path "$env:TEMP" -Recurse -Force | Remove-Item -Force
        ExecutionCompleted
    } catch {
        Write-Host "Error during TempAndDeletedFilesCleaner execution: $_" -ForegroundColor Red
    }
}

# Function to clean broken shortcuts
function BrokenShortcutsCleaner {
    try {
        Get-ChildItem -Path "$env:PUBLIC\Desktop" -Filter "*.lnk" -Recurse | Where-Object { -not (Test-Path $_.Target) } | Remove-Item -Force
        ExecutionCompleted
    } catch {
        Write-Host "Error during BrokenShortcutsCleaner execution: $_" -ForegroundColor Red
    }
}

# Function to clean unneeded registry entries
function UnneededRegistryEntriesCleaner {
    try {
        reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\RunMRU" /f
        ExecutionCompleted
    } catch {
        Write-Host "Error during UnneededRegistryEntriesCleaner execution: $_" -ForegroundColor Red
    }
}

# Function to uninstall unused or unnecessary programs
function UnusedProgramsCleaner {
    try {
        Get-WmiObject -Query "SELECT * FROM Win32_Product" | Where-Object { $null -eq $_.InstallDate } | ForEach-Object { $_.Uninstall() }
        ExecutionCompleted
    } catch {
        Write-Host "Error during UnusedProgramsCleaner execution: $_" -ForegroundColor Red
    }
}

# Function to clear browsing history (selective)
function BrowsingHistoryCleaner {
    try {
        RunDll32.exe InetCpl.cpl,ClearMyTracksByProcess 255
        ExecutionCompleted
    } catch {
        Write-Host "Error during BrowsingHistoryCleaner execution: $_" -ForegroundColor Red
    }
}

# Function to find and remove duplicate files
function DuplicateFilesCleaner {
    try {
        Get-ChildItem -Path 'C:\' -Recurse -Force -File | Group-Object -Property Length, Hash | Where-Object { $_.Count -gt 1 } | ForEach-Object { $_.Group | Select-Object -Skip 1 | Remove-Item -Force }
        ExecutionCompleted
    } catch {
        Write-Host "Error during DuplicateFilesCleaner execution: $_" -ForegroundColor Red
    }
}

# Create form with buttons for cleanup
$form = New-Object System.Windows.Forms.Form
$form.Text = 'Windows User Cleanup'
$form.StartPosition = 'CenterScreen'
$form.Size = New-Object System.Drawing.Size(310, 450)
$form.Icon = [System.Drawing.Icon]::ExtractAssociatedIcon((Get-Item ".\Assets\windowslogo.ico").FullName)

# System Cleaner button
$CleanupSystemButton = New-Object System.Windows.Forms.Button
$CleanupSystemButton.Location = New-Object System.Drawing.Size(25, 135)
$CleanupSystemButton.Size = New-Object System.Drawing.Size(135, 23)
$CleanupSystemButton.Text = "System Cleaner"
$CleanupSystemButton.Add_Click({ CleanupSystem })
$form.Controls.Add($CleanupSystemButton)

# User Cleaner button
$UserCleanerButton = New-Object System.Windows.Forms.Button
$UserCleanerButton.Location = New-Object System.Drawing.Size(25, 165)
$UserCleanerButton.Size = New-Object System.Drawing.Size(135, 23)
$UserCleanerButton.Text = "User Cleaner"
$UserCleanerButton.Add_Click({ UserCleaner })
$form.Controls.Add($UserCleanerButton)

# Temporary or Deleted Files Cleaner button
$TempFilesCleanerButton = New-Object System.Windows.Forms.Button
$TempFilesCleanerButton.Location = New-Object System.Drawing.Size(25, 195)
$TempFilesCleanerButton.Size = New-Object System.Drawing.Size(135, 23)
$TempFilesCleanerButton.Text = "Temp Files Cleaner"
$TempFilesCleanerButton.Add_Click({ TempAndDeletedFilesCleaner })
$form.Controls.Add($TempFilesCleanerButton)

# Broken Shortcuts Cleaner button
$BrokenShortcutsButton = New-Object System.Windows.Forms.Button
$BrokenShortcutsButton.Location = New-Object System.Drawing.Size(25, 225)
$BrokenShortcutsButton.Size = New-Object System.Drawing.Size(135, 23)
$BrokenShortcutsButton.Text = "Broken Shortcuts"
$BrokenShortcutsButton.Add_Click({ BrokenShortcutsCleaner })
$form.Controls.Add($BrokenShortcutsButton)

# Unneeded Registry Entries Cleaner button
$RegistryEntriesButton = New-Object System.Windows.Forms.Button
$RegistryEntriesButton.Location = New-Object System.Drawing.Size(25, 255)
$RegistryEntriesButton.Size = New-Object System.Drawing.Size(135, 23)
$RegistryEntriesButton.Text = "Registry Cleaner"
$RegistryEntriesButton.Add_Click({ UnneededRegistryEntriesCleaner })
$form.Controls.Add($RegistryEntriesButton)

# Unused Programs Cleaner button
$UnusedProgramsButton = New-Object System.Windows.Forms.Button
$UnusedProgramsButton.Location = New-Object System.Drawing.Size(25, 285)
$UnusedProgramsButton.Size = New-Object System.Drawing.Size(135, 23)
$UnusedProgramsButton.Text = "Unused Programs"
$UnusedProgramsButton.Add_Click({ UnusedProgramsCleaner })
$form.Controls.Add($UnusedProgramsButton)

# Browsing History Cleaner button
$BrowsingHistoryButton = New-Object System.Windows.Forms.Button
$BrowsingHistoryButton.Location = New-Object System.Drawing.Size(25, 315)
$BrowsingHistoryButton.Size = New-Object System.Drawing.Size(135, 23)
$BrowsingHistoryButton.Text = "Browsing History"
$BrowsingHistoryButton.Add_Click({ BrowsingHistoryCleaner })
$form.Controls.Add($BrowsingHistoryButton)

# Duplicate Files Cleaner button
$DuplicateFilesButton = New-Object System.Windows.Forms.Button
$DuplicateFilesButton.Location = New-Object System.Drawing.Size(25, 345)
$DuplicateFilesButton.Size = New-Object System.Drawing.Size(135, 23)
$DuplicateFilesButton.Text = "Duplicate Files"
$DuplicateFilesButton.Add_Click({ DuplicateFilesCleaner })
$form.Controls.Add($DuplicateFilesButton)

# Show the form
$form.ShowDialog() | Out-Null

# Exit script
Exit
# Created by Chris Masters