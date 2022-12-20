# Windows Maintenance Powershell Script

This is a set of scripts I have made or utilities downloaded (credit at bottom), these scripts can only be ran one after another, so be patient while one script executes.

You may also take the scripts and use them in your own programs under the GNU License agreement and credit is given to me, these scripts take time to write, test and improve, I am not the best coder in the world but I try to make useful programs!

# Readme.txt

Quick Readme for the exe file not loading
Make sure you are running administrator on the exe or .ps1 script

1. (If you already set execution policy skip to step 2) Run the other ps1 script that will set execution policy to "bypass" do not worry windows will automatically restore the execution policy when the computer is next turned on
2. Then run the WindowsMaintenance.exe

# What things this script does:

Maintenance:
1. Windows Install Cleanup (Standalone: https://github.com/SparksSkywere/Windows-10-Install-Cleaner)
2. Re-install Windows default Apps
3. Uninstall One-Drive
4. Disk Cleanup Utility
5. Delprof
6. User Cleanup Utility
7. DISM Restore Health
8. Defragmentation Utility
9. Windows System Scan and repair
10. Check Disk (Volume Repair)
11. System Optimisations

TroubleShooting:
1. Internet Fix
2. Windows Update
3. Microsoft Store
4. Max Path length registry increase
5. Windows Update Error 0x800f0922 Fix

# Extra Documentation

In the folder under Scripts is a file called "CustomChanges.ps1", this is for custom additions, it is an example of an older version of the troubleshooting file, you can freely edit this file for use in custom environments / testing of custom code, the panel will need to be added into the main ps1 script otherwise it will not show.

# Extra Credit

Microsoft Powershell: https://docs.microsoft.com/en-us/powershell/

Delprof 2, created by Helge Klein

Link to download: https://helgeklein.com/free-tools/delprof2-user-profile-deletion-tool/
