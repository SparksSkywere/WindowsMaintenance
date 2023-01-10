Clear-Host
#Script used for optimisations for windows
#Type Loader
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName System.Drawing
function Show-Console
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
function RestartNeeded () {
    [System.Windows.MessageBox]::Show('Please restart the computer','Windows Troubleshooting','Ok','Information')
}
function ExecutionCompleted () {
    [System.Windows.MessageBox]::Show('Operation Completed','Windows Maintenance','Ok','Information')

}

#Setting Theme Functions, this is to help split up the services without creating a massive line of code
function VisualFXSetting () {Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" -Name "VisualFXSetting" -Value 2 -Force}
function MinAnimate () {Set-ItemProperty -Path "HKCU:\Control Panel\Desktop\WindowMetrics" -Name "MinAnimate" -Value 0 -Force}
function TaskbarAnimations () {Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarAnimations" -Value 0 -Force}
function TaskbarAnimations2 () {Set-ItemProperty -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarAnimations" -Value - -Force}
function CompositionPolicy () {Set-ItemProperty -Path "HKLU:\Software\Microsoft\Windows\DWM" -Name "CompositionPolicy" -Value 0 -Force}
function ColorizationOpaqueBlend () {Set-ItemProperty -Path "HKLU:\Software\Microsoft\Windows\DWM" -Name "ColorizationOpaqueBlend" -Value 0 -Force}
function AlwaysHibernateThumbnails () {Set-ItemProperty -Path "HKLU:\Software\Microsoft\Windows\DWM" -Name "AlwaysHibernateThumbnails" -Value 0 -Force}
function DisableThumbnails () {Set-ItemProperty -Path "HKLU:\Software\Microsoft\Windows\DWM" -Name "DisableThumbnails" -Value 1 -Force}
function ListviewAlphaSelect () {Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "ListviewAlphaSelect" -Value 0 -Force}
function DragFullWindows () {Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "DragFullWindows" -Value 0 -Force}
function FontSmoothing () {Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "FontSmoothing" -Value 0 -Force}
function ThemeManager () {Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\ThemeManager" -Name "ThemeActive" -Value 0 -Force}
function ThemeManager2 () {Set-ItemProperty -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\ThemeManager" -Name "ThemeActive" -Value - -Force}
function UserPreferencesMask () {Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "UserPreferencesMask" -Value hex:90,12,01,80,10,00,00,00 -Force}
function RestartThemeService () {Restart-Service Themes -Force}

#Disable Telemetry functions
function DisableDiagtrack () {Get-Service -Name "DiagTrack" | Set-Service -StartupType Disabled}
function DisableDiagtrack2 () {Get-Service -Name "dmwappushservice" | Set-Service -StartupType Disabled}
function DisableAdvertisingID () {Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AdvertisingInfo" -Name "Advertising ID" -Value 0 -Force}
function DisableTelemetry () {Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -Name "AllowTelemetry" -Value 0 -Force}

#Disable Services Functions
function DisableDataUsage () {Get-Service -Name "DusmSvc" | Set-Service -StartupType Disabled}
function DisableFax () {Get-Service -Name "Fax" | Set-Service -StartupType Disabled}
function DisableParentalControls () {Get-Service -Name "WpcMonSvc" | Set-Service -StartupType Disabled}
function DisableGeoLocation () {Get-Service -Name "lfsvc" | Set-Service -StartupType Disabled}
function DisableNFCPayments () {Get-Service -Name "SEMgrSvc" | Set-Service -StartupType Disabled}
function DisableRetailDemo () {Get-Service -Name "RetailDemo" | Set-Service -StartupType Disabled}
function DisableWindowsInside () {Get-Service -Name "wisvc" | Set-Service -StartupType Disabled}
function DisableMapsManager () {Get-Service -Name "MapsBroker" | Set-Service -StartupType Disabled}

#Background Apps Disable Functions
function DisableBackgroundApps () {Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft" -Name "LetAppsRunInBackground" -Value 0 -Force}
function DisableBackgroundAccess () {Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications" -Name GlobalUserDisabled -Value 0 -Force}

#Scripts to help Optimise windows, most are found on the OS already + some registry changes
    #Optimising!
    #Set your pc to the performance theme, helps with graphical performance
    $ReducedTheme = {VisualFXSetting | MinAnimate | TaskbarAnimations | TaskbarAnimations2 | CompositionPolicy | ColorizationOpaqueBlend | AlwaysHibernateThumbnails | DisableThumbnails | ListviewAlphaSelect | DragFullWindows | FontSmoothing | ThemeManager | ThemeManager2 | UserPreferencesMask | RestartThemeService | ExecutionCompleted}
    #Turn off background applications, helps with perfomance as nothing is sat in the background eating up resources
    $Turnoffbackgroundapps = {DisableBackgroundAccess | DisableBackgroundApps | ExecutionCompleted}
    #Stops services to boost performance, these services are not heavily used as much but you may re-enable the services in "services.msc"
    $DisableServices = {DisableDataUsage | DisableFax | DisableParentalControls | DisableGeoLocation | DisableNFCPayments | DisableRetailDemo | DisableWindowsInside | DisableMapsManager |ExecutionCompleted}
    #Disable Telemetry, this stops information being sent to Microsoft, can help with keeping internet usage down
    $DisableTelemetry = {DisableDiagtrack | DisableDiagtrack2 | DisableAdvertisingID | DisableTelemetry | ExecutionCompleted}

#Form GUI for loading
 #Create Form to show selection of cleanup
 $Form = New-Object System.Windows.Forms.Form
 $form.Text = 'Windows Optimisation'
 $form.Size = New-Object System.Drawing.Size(370,350)
 $form.StartPosition = 'CenterScreen'
 $objIcon = New-Object system.drawing.icon (".\Assets\windowslogo.ico")
 $form.Icon = $objIcon

 $FormText = New-Object System.Windows.Forms.Label
 $FormText.Location = New-Object System.Drawing.Point(35,10)
 $FormText.Size = New-Object System.Drawing.Size(300,18)
 $FormText.Text = 'Select Options Below, once done please restart'
#Performance Theme options button
 $ReducedThemeButton = New-Object System.Windows.Forms.Button
 $ReducedThemeButton.Location = New-Object System.Drawing.Size(35,35)
 $ReducedThemeButton.Size = New-Object System.Drawing.Size(120,23)
 $ReducedThemeButton.Text = "Performance Theme"
 $ReducedThemeButton.Add_Click($ReducedTheme)
#Turn off background apps
 $TurnoffbackgroundappsButton = New-Object System.Windows.Forms.Button
 $TurnoffbackgroundappsButton.Location = New-Object System.Drawing.Size(165,35)
 $TurnoffbackgroundappsButton.Size = New-Object System.Drawing.Size(130,23)
 $TurnoffbackgroundappsButton.Text = "No Background Apps"
 $TurnoffbackgroundappsButton.Add_Click($Turnoffbackgroundapps)
#Disable Un-used Services
 $DisableServicesbutton = New-Object System.Windows.Forms.Button
 $DisableServicesbutton.Location = New-Object System.Drawing.Size(35,65)
 $DisableServicesbutton.Size = New-Object System.Drawing.Size(120,23)
 $DisableServicesbutton.Text = "Disable Services"
 $DisableServicesbutton.Add_Click($DisableServices)
#Disable Telemetry
 $DisableTelemetrybutton = New-Object System.Windows.Forms.Button
 $DisableTelemetrybutton.Location = New-Object System.Drawing.Size(165,65)
 $DisableTelemetrybutton.Size = New-Object System.Drawing.Size(130,23)
 $DisableTelemetrybutton.Text = "Disable Telemetry"
 $DisableTelemetrybutton.Add_Click($DisableTelemetry)
#Custom Changes
 #$Customchangesbutton = New-Object System.Windows.Forms.Button
 #$Customchangesbutton.Location = New-Object System.Drawing.Size(165,155)
 #$Customchangesbutton.Size = New-Object System.Drawing.Size(130,23)
 #$Customchangesbutton.Text = "Custom Changes"
 #$Customchangesbutton.Add_Click($CustomChanges)
#Exit Button
 $exitButton = New-Object System.Windows.Forms.Button
 $exitButton.Location = New-Object System.Drawing.Point(135,270)
 $exitButton.Size = New-Object System.Drawing.Size(75,23)
 $exitButton.Text = 'Exit'
 $exitButton.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
 $form.CancelButton = $exitButton
 $form.Controls.Add($exitButton)
#Add buttons
 $Form.Controls.Add($FormText)
 $Form.Controls.Add($ReducedThemeButton)
 $Form.Controls.Add($TurnoffbackgroundappsButton)
 $Form.Controls.Add($DisableServicesbutton)
 $Form.Controls.Add($DisableTelemetrybutton)
 #$Form.Controls.Add($Customchangesbutton)
#Null command to stop console spam
$Form.ShowDialog() > $null