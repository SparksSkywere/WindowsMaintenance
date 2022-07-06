# Windows Maintenance Powershell Script

This is a set of scripts I have made or utilities downloaded (credit below), these scripts can only be ran one after another, so be patient while one script runs after another.

You may also take the scripts and use them in your own programs under the GNU License agreement and credit is given to me.

# From Readme.txt

Quick Readme for the exe file not loading
Make sure you are running administrator on the exe or .ps1 script

1. Run the other ps1 script that will set execution policy to "bypass" do not worry windows will automatically restore the execution policy when the computer is next turned on
2. Then run the WindowsMaintenance exe 

# What things this script does:

Maintenance
1. Windows Install Cleanup (There is another script I made which JUST contains this if you want that specifically)
2. Re-install Windows default Apps
3. Uninstall One-Drive
4. Disk Cleanup Utility
5. Delprof
6. User Cleanup Utility
7. DISM Restore Health
8. Defragmentation Utility

TroubleShooting

1. Internet Fix
2. Windows Update
3. Microsoft Store
4. Max Path registry fix

# Extra Documentation

In the folder under Scripts is a file called "CustomChanges.ps1", this is for custom additions, it is an example of an older version of the troubleshooting file, you can freely edit this file for use in custom environments / testing of custom code, the panel will need to be added into the main ps1 script otherwise it will not show.

# Credit

Delprof 2, created by Helge Klein

Link to download: https://helgeklein.com/free-tools/delprof2-user-profile-deletion-tool/
