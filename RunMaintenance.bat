@echo off
REM Windows Maintenance Tool Launcher
REM This batch file runs the PowerShell script with administrator privileges

echo Windows Maintenance Tool
echo ========================
echo Requesting administrator privileges...

powershell -Command "Start-Process powershell -ArgumentList '-ExecutionPolicy Bypass -File \"%~dp0WindowsMaintenance.ps1\"' -Verb RunAs"

echo If the script doesn't start, please run this batch file as Administrator.
Exit