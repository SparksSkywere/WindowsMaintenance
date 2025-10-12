Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Load assemblies efficiently
$null = [System.Reflection.Assembly]::LoadWithPartialName('System.Windows.Forms')
$null = [System.Reflection.Assembly]::LoadWithPartialName('System.Drawing')

# Cache cleanup paths
$cleanupPaths = @{
    WinTemp = 'C:\Windows\Temp'
    Prefetch = 'C:\Windows\Prefetch'
    LocalTemp = 'C:\Users\*\Appdata\Local\Temp\'
    SystemTemp = "$env:temp"
    INetCache = "$env:appdata\Microsoft\Windows\INetCache"
}

# Check if called from main script (automated mode)
$AutomatedMode = $args -contains "--automated"

if ($AutomatedMode) {
    # Run cleanup automatically with progress reporting
    CleanupSystem
    exit 0
}
{
    param ([Switch]$Show,[Switch]$Hide)
    if (-not ("Console.Window" -as [type])) { 

        Add-Type -Name Window -Namespace Console -MemberDefinition '
        [DllImport("Kernel32.dll")]
        public static extern IntPtr GetConsoleWindow();

        [DllImport("user32.dll")]
        public static extern bool ShowWindow(IntPtr hWnd, Int32 nCmdShow);
        '
    }
    if ($Show)
    {
        $consolePtr = [Console.Window]::GetConsoleWindow()
        $null = [Console.Window]::ShowWindow($consolePtr, 5)
    }
    if ($Hide)
    {
        $consolePtr = [Console.Window]::GetConsoleWindow()
        #0 hide
        $null = [Console.Window]::ShowWindow($consolePtr, 0)
    }
}
#end of powershell console hiding
#To show the console change "-hide" to "-show"
show-console -hide

#Functions
function ExecutionCompleted () {
    [System.Windows.MessageBox]::Show('Operation Completed','Windows Maintenance','Ok','Information')
}

#Cleanup commands and locations
$UserCleaner = {Invoke-Cleanup -Path $cleanupPaths.WinTemp; Invoke-Cleanup -Path $cleanupPaths.Prefetch; Invoke-Cleanup -Path $cleanupPaths.LocalTemp; ExecutionCompleted}
$CleanupSystem = {CleanupSystem | ExecutionCompleted}

# To do:
# Replace the above with just a scanner and cleaner like ccleaner, GUI?
# And do the following:
# Temporary or deleted files (include windows updates and general cleaner)
# Broken shortcuts
# Unneeded registry entries
# Unused or unnecessary programs
# Browsing history (selective window)
# Duplicate files

# Modern browser data cleanup with better error handling
function Remove-BrowserData {
    Write-Host "Cleaning browser data..." -ForegroundColor Yellow
    
    # Chrome cleanup
    try {
        $chromePaths = @(
            "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Cache",
            "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Code Cache",
            "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\GPUCache",
            "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Service Worker\CacheStorage",
            "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Service Worker\ScriptCache"
        )
        
        foreach ($path in $chromePaths) {
            if (Test-Path $path) {
                Remove-Item "$path\*" -Force -Recurse -ErrorAction SilentlyContinue
            }
        }
        
        # Chrome cookies (optional - commented for user preference)
        # if (Test-Path "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Cookies") {
        #     Remove-Item "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Cookies" -Force -ErrorAction SilentlyContinue
        # }
        
        Write-Host "  Chrome cache cleared" -ForegroundColor Green
    } catch {
        Write-Warning "Could not clean Chrome data: $_"
    }
    
    # Firefox cleanup
    try {
        $firefoxProfilesPath = "$env:APPDATA\Mozilla\Firefox\Profiles"
        if (Test-Path $firefoxProfilesPath) {
            $firefoxProfiles = Get-ChildItem $firefoxProfilesPath -Directory -ErrorAction SilentlyContinue
            foreach ($firefoxProfile in $firefoxProfiles) {
                $cachePaths = @(
                    "$($firefoxProfile.FullName)\cache2",
                    "$($firefoxProfile.FullName)\startupCache",
                    "$($firefoxProfile.FullName)\OfflineCache"
                )
                
                foreach ($cachePath in $cachePaths) {
                    if (Test-Path $cachePath) {
                        Remove-Item "$cachePath\*" -Force -Recurse -ErrorAction SilentlyContinue
                    }
                }
            }
        }
        Write-Host "  Firefox cache cleared" -ForegroundColor Green
    } catch {
        Write-Warning "Could not clean Firefox data: $_"
    }
    
    # Microsoft Edge cleanup
    try {
        $edgePaths = @(
            "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Cache",
            "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Code Cache",
            "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\GPUCache",
            "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Service Worker\CacheStorage"
        )
        
        foreach ($path in $edgePaths) {
            if (Test-Path $path) {
                Remove-Item "$path\*" -Force -Recurse -ErrorAction SilentlyContinue
            }
        }
        Write-Host "  Edge cache cleared" -ForegroundColor Green
    } catch {
        Write-Warning "Could not clean Edge data: $_"
    }
    
    # Internet Explorer cleanup (for legacy support)
    try {
        $iePaths = @(
            "$env:LOCALAPPDATA\Microsoft\Windows\INetCache",
            "$env:LOCALAPPDATA\Microsoft\Windows\Temporary Internet Files"
        )
        
        foreach ($path in $iePaths) {
            if (Test-Path $path) {
                Remove-Item "$path\*" -Force -Recurse -ErrorAction SilentlyContinue
            }
        }
        Write-Host "  Internet Explorer cache cleared" -ForegroundColor Green
    } catch {
        Write-Warning "Could not clean Internet Explorer data: $_"
    }
}

# Modern Windows Update cache cleanup with safety checks
function Remove-WindowsUpdateCache {
    try {
        Write-Host "Cleaning Windows Update cache..." -ForegroundColor Yellow
        
        # Check if Windows Update services are running
        $wuServices = @('wuauserv', 'bits', 'cryptsvc', 'appidsvc')
        $runningServices = @()
        
        foreach ($service in $wuServices) {
            $svc = Get-Service -Name $service -ErrorAction SilentlyContinue
            if ($svc -and $svc.Status -eq 'Running') {
                $runningServices += $service
                Write-Host "  Stopping $service..." -ForegroundColor Cyan
                Stop-Service -Name $service -Force -ErrorAction SilentlyContinue
            }
        }
        
        # Wait a moment for services to stop
        Start-Sleep -Seconds 2
        
        # Clear Windows Update download cache
        $downloadPath = "$env:SystemRoot\SoftwareDistribution\Download"
        if (Test-Path $downloadPath) {
            Remove-Item "$downloadPath\*" -Force -Recurse -ErrorAction SilentlyContinue
            Write-Host "  SoftwareDistribution download cache cleared" -ForegroundColor Green
        }
        
        # Clear Windows Update database cache (more aggressive - optional)
        $dbPath = "$env:SystemRoot\SoftwareDistribution\DataStore"
        if (Test-Path $dbPath) {
            Remove-Item "$dbPath\*" -Force -Recurse -ErrorAction SilentlyContinue
            Write-Host "  SoftwareDistribution database cleared" -ForegroundColor Green
        }
        
        # Clear catroot2 (cryptographic services cache)
        $catroot2Path = "$env:SystemRoot\System32\catroot2"
        if (Test-Path $catroot2Path) {
            # Only clear contents, not the folder itself
            Get-ChildItem $catroot2Path -Recurse -Force -ErrorAction SilentlyContinue | 
                Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
            Write-Host "  Catroot2 cache cleared" -ForegroundColor Green
        }
        
        # Restart the services that were running
        foreach ($service in $runningServices) {
            Write-Host "  Starting $service..." -ForegroundColor Cyan
            Start-Service -Name $service -ErrorAction SilentlyContinue
        }
        
        Write-Host "Windows Update cache cleanup completed" -ForegroundColor Green
        
    } catch {
        Write-Warning "Could not clean Windows Update cache: $_"
        
        # Ensure services are restarted even if cleanup failed
        foreach ($service in $wuServices) {
            try {
                Start-Service -Name $service -ErrorAction SilentlyContinue
            } catch {
                Write-Warning "Could not restart $service"
            }
        }
    }
}

function Clear-SystemRestorePoints {
    Disable-ComputerRestore -Drive "C:\"
    vssadmin delete shadows /all /quiet
    Enable-ComputerRestore -Drive "C:\"
}

function CleanupSystem () {
    try {
        Write-Host "Starting comprehensive system cleanup..." -ForegroundColor Cyan
        
        # Declare variables for the folders we want to clean up
        $tempFolder = $env:TEMP
        $appData = $env:APPDATA
        $localAppData = $env:LOCALAPPDATA
        $windowsTemp = "$env:SystemRoot\Temp"
        
        Write-Host "Cleaning temporary files..." -ForegroundColor Yellow
        
        # Delete user temporary files with better error handling
        if (Test-Path $tempFolder) {
            Get-ChildItem $tempFolder -Recurse -Force -ErrorAction SilentlyContinue | 
                Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
        }
        
        # Delete Windows temporary files (requires admin)
        if (Test-Path $windowsTemp) {
            Get-ChildItem $windowsTemp -Recurse -Force -ErrorAction SilentlyContinue | 
                Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
        }

        # Delete temporary internet files with modern path
        Write-Host "Cleaning browser data..." -ForegroundColor Yellow
        $inetCachePath = "$localAppData\Microsoft\Windows\INetCache"
        if (Test-Path $inetCachePath) {
            Remove-Item "$inetCachePath\*" -Recurse -Force -ErrorAction SilentlyContinue
        }

        # Modern recycle bin cleanup using PowerShell 5.1+ methods
        Write-Host "Cleaning recycle bin..." -ForegroundColor Yellow
        try {
            # Use modern Clear-RecycleBin if available (Windows 10+)
            if (Get-Command "Clear-RecycleBin" -ErrorAction SilentlyContinue) {
                Clear-RecycleBin -Force -ErrorAction SilentlyContinue
            } else {
                # Fallback for older systems
                $shell = New-Object -ComObject Shell.Application
                $recycleBin = $shell.Namespace(0xA)
                $recycleBin.Items() | ForEach-Object { 
                    if ($_.ModifyDate -lt (Get-Date).AddDays(-30)) {
                        Remove-Item $_.Path -Force -ErrorAction SilentlyContinue
                    }
                }
            }
        } catch {
            Write-Warning "Could not clean recycle bin: $_"
        }

        # Clear the event logs with modern error handling
        Write-Host "Clearing event logs..." -ForegroundColor Yellow
        $logs = @("Application", "Security", "System")
        foreach ($log in $logs) {
            try {
                if (Get-EventLog -List | Where-Object {$_.Log -eq $log}) {
                    Clear-EventLog -LogName $log -ErrorAction SilentlyContinue
                }
            } catch {
                Write-Warning "Could not clear $log log: $_"
            }
        }

        # Delete old AppData files with better filtering
        Write-Host "Cleaning old AppData files..." -ForegroundColor Yellow
        $paths = @($appData, $localAppData)
        foreach ($path in $paths) {
            try {
                Get-ChildItem $path -File -Recurse -ErrorAction SilentlyContinue | 
                    Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-30) -and $_.Extension -in @('.tmp', '.log', '.cache') } | 
                    Remove-Item -Force -ErrorAction SilentlyContinue
            } catch {
                Write-Warning "Could not clean $path : $_"
            }
        }

        # Enhanced browser cleanup
        Remove-BrowserData
        
        # Windows Update cache cleanup
        Remove-WindowsUpdateCache
        
        # System restore points (optional - commented for safety)
        # Clear-SystemRestorePoints
        
        # Clean Windows Store cache safely
        try {
            Start-Process -FilePath "wsreset.exe" -WindowStyle Hidden -Wait -ErrorAction SilentlyContinue
            Write-Host "Windows Store cache cleared" -ForegroundColor Green
        } catch {
            Write-Warning "Could not reset Windows Store cache"
        }
        
        # Clean system logs more safely
        try {
            $eventLogs = wevtutil el 2>$null
            foreach ($logName in $eventLogs) {
                if ($logName -notmatch "(Security|System|Application)$") {
                    wevtutil cl $logName 2>$null
                }
            }
            Write-Host "System logs cleared" -ForegroundColor Green
        } catch {
            Write-Warning "Could not clear system logs"
        }

        # Clean font cache safely
        try {
            $fontCacheService = Get-Service -Name "FontCache" -ErrorAction SilentlyContinue
            if ($fontCacheService) {
                Stop-Service "FontCache" -Force -ErrorAction SilentlyContinue
                if (Test-Path "$env:SystemRoot\System32\FNTCACHE.DAT") {
                    Remove-Item "$env:SystemRoot\System32\FNTCACHE.DAT" -Force -ErrorAction SilentlyContinue
                }
                Start-Service "FontCache" -ErrorAction SilentlyContinue
                Write-Host "Font cache cleared" -ForegroundColor Green
            }
        } catch {
            Write-Warning "Could not clean font cache"
        }
        
        # Clean thumbnail cache
        try {
            $thumbCachePath = "$localAppData\Microsoft\Windows\Explorer"
            if (Test-Path $thumbCachePath) {
                Get-ChildItem "$thumbCachePath\thumbcache_*.db" -Force -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
                Get-ChildItem "$thumbCachePath\iconcache_*.db" -Force -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
                Write-Host "Thumbnail cache cleared" -ForegroundColor Green
            }
        } catch {
            Write-Warning "Could not clean thumbnail cache"
        }
        
        Write-Host "System cleanup completed successfully!" -ForegroundColor Green
        
    } catch {
        Write-Host "Error during comprehensive system cleanup: $_" -ForegroundColor Red
    }
} 

#Form with buttons to area's for cleanup
$form = New-Object System.Windows.Forms.Form
$form.Text = 'Windows User Cleanup'
$form.StartPosition = 'CenterScreen'
$form.Size = New-Object System.Drawing.Size(310,350)
$objIcon = New-Object system.drawing.icon (".\Assets\windowslogo.ico")
$form.Icon = $objIcon

    $CleanupSystemButton = New-Object System.Windows.Forms.Button
    $CleanupSystemButton.Location = New-Object System.Drawing.Size(25,135)
    $CleanupSystemButton.Size = New-Object System.Drawing.Size(135,23)
    $CleanupSystemButton.Text = "System Cleaner"
    $CleanupSystemButton.Add_Click($CleanupSystem)

    $UserCLeanerbutton = New-Object System.Windows.Forms.Button
    $UserCLeanerbutton.Location = New-Object System.Drawing.Size(25,165)
    $UserCLeanerbutton.Size = New-Object System.Drawing.Size(135,23)
    $UserCLeanerbutton.Text = "User Cleaner"
    $UserCLeanerbutton.Add_Click($UserCleaner)

    $Form.Controls.Add($CleanupSystemButton)
    $Form.Controls.Add($UserCLeanerbutton)

$form.showdialog()
Exit
#Created by Chris Masters