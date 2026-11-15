Clear-Host

# Modern test script for Windows Maintenance Tool
Write-Host "Windows Maintenance Tool - Test Script" -ForegroundColor Cyan
Write-Host "=======================================" -ForegroundColor Cyan

# Get system information
$osInfo = Get-CimInstance -ClassName Win32_OperatingSystem
$computerInfo = Get-CimInstance -ClassName Win32_ComputerSystem

Write-Host "System Information:" -ForegroundColor Yellow
Write-Host "  OS: $($osInfo.Caption) (Build $($osInfo.BuildNumber))" -ForegroundColor White
Write-Host "  Computer: $($computerInfo.Manufacturer) $($computerInfo.Model)" -ForegroundColor White
Write-Host "  Total RAM: $([math]::Round($computerInfo.TotalPhysicalMemory / 1GB, 2)) GB" -ForegroundColor White
Write-Host "  User: $($env:USERNAME)" -ForegroundColor White
Write-Host "  Script executed at: $(Get-Date)" -ForegroundColor White

# Test PowerShell execution policy
$executionPolicy = Get-ExecutionPolicy
Write-Host "`nPowerShell Execution Policy: $executionPolicy" -ForegroundColor $(if ($executionPolicy -eq 'Bypass' -or $executionPolicy -eq 'Unrestricted') { 'Green' } else { 'Yellow' })

# Test admin privileges
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
Write-Host "Running as Administrator: $isAdmin" -ForegroundColor $(if ($isAdmin) { 'Green' } else { 'Red' })

if (-not $isAdmin) {
    Write-Host "  Note: Some functions require administrator privileges" -ForegroundColor Yellow
}

Exit
#Created by Chris Masters - Updated for Windows 10/11 compatibility