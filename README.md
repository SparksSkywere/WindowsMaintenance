# Windows Maintenance Powershell Script

This is a set of scripts I have made or utilities downloaded (credit at bottom), these scripts can only be ran one after another, so be patient while one script executes.

You may also take the scripts and use them in your own programs under the GNU License agreement and credit is given to me. You may also want to check out all the other repositories under my name for various programs!

# Readme.txt

Quick Readme for the exe file not loading
Make sure you are running administrator on the exe or .ps1 script

1. (If you already set execution policy skip to step 2) Run the other .ps1 script that will set execution policy to "bypass" do not worry windows will automatically restore the execution policy when the computer is next turned on
2. If you are getting an error about the Policy put in the following command with adminin privilages with Powershell: "Set-ExecutionPolicy Bypass -Force" (I have also added a seperate script that also does this command, you may run with admin on Powershell by navigating to the directory with: cd *"PATH"*)
3. Then run the WindowsMaintenance.exe

# What things this script does:

Maintenance:
1. Windows Install Cleanup (Will detect W10/W11)
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
1. Internet
2. Windows Update
3. Microsoft Store
4. Max Path length registry change
5. Windows Update Error 0x800f0922 Fix

# Custom Script

In the folder under Scripts is a file called "CustomChanges.ps1", this is for custom additions, it is an example of an older version of the troubleshooting file, you can freely edit this file for use in custom environments / testing of custom code, the panel will need to be added into the main ps1 script otherwise it will not show.

# Extra Credit

Microsoft Powershell: https://docs.microsoft.com/en-us/powershell/

Delprof 2, created by Helge Klein

Link to download: https://helgeklein.com/free-tools/delprof2-user-profile-deletion-tool/
