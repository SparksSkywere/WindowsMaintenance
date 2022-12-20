Clear-Host
#Checkmenting the selected drive letter, all drives for windows have been added, no real customisation is needed past this point
#Type Loader
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName PresentationFramework
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
function ExecutionCompleted () {
    [System.Windows.MessageBox]::Show('Operation Completed','Windows Maintenance','Ok','Information')
}

#Drive Letters + Check command
$A = {Repair-Volume -DriveLetter A -OfflineScanAndFix | ExecutionCompleted}
$B = {Repair-Volume -DriveLetter B -OfflineScanAndFix | ExecutionCompleted}
$C = {Repair-Volume -DriveLetter C -OfflineScanAndFix | ExecutionCompleted}
$D = {Repair-Volume -DriveLetter D -OfflineScanAndFix | ExecutionCompleted}
$E = {Repair-Volume -DriveLetter E -OfflineScanAndFix | ExecutionCompleted}
$F = {Repair-Volume -DriveLetter F -OfflineScanAndFix | ExecutionCompleted}
$G = {Repair-Volume -DriveLetter G -OfflineScanAndFix | ExecutionCompleted}
$H = {Repair-Volume -DriveLetter H -OfflineScanAndFix | ExecutionCompleted}
$I = {Repair-Volume -DriveLetter I -OfflineScanAndFix | ExecutionCompleted}
$J = {Repair-Volume -DriveLetter J -OfflineScanAndFix | ExecutionCompleted}
$K = {Repair-Volume -DriveLetter K -OfflineScanAndFix | ExecutionCompleted}
$L = {Repair-Volume -DriveLetter L -OfflineScanAndFix | ExecutionCompleted}
$M = {Repair-Volume -DriveLetter M -OfflineScanAndFix | ExecutionCompleted}
$N = {Repair-Volume -DriveLetter N -OfflineScanAndFix | ExecutionCompleted}
$O = {Repair-Volume -DriveLetter O -OfflineScanAndFix | ExecutionCompleted}
$P = {Repair-Volume -DriveLetter P -OfflineScanAndFix | ExecutionCompleted}
$Q = {Repair-Volume -DriveLetter Q -OfflineScanAndFix | ExecutionCompleted}
$R = {Repair-Volume -DriveLetter R -OfflineScanAndFix | ExecutionCompleted}
$S = {Repair-Volume -DriveLetter S -OfflineScanAndFix | ExecutionCompleted}
$T = {Repair-Volume -DriveLetter T -OfflineScanAndFix | ExecutionCompleted}
$U = {Repair-Volume -DriveLetter U -OfflineScanAndFix | ExecutionCompleted}
$V = {Repair-Volume -DriveLetter V -OfflineScanAndFix | ExecutionCompleted}
$W = {Repair-Volume -DriveLetter W -OfflineScanAndFix | ExecutionCompleted}
$X = {Repair-Volume -DriveLetter X -OfflineScanAndFix | ExecutionCompleted}
$Y = {Repair-Volume -DriveLetter Y -OfflineScanAndFix | ExecutionCompleted}
$Z = {Repair-Volume -DriveLetter Z -OfflineScanAndFix | ExecutionCompleted}

#Create form containing all the buttons to the commands set above
[System.Windows.MessageBox]::Show('When you select a drive the Scanning will run in the background or ask to reboot (If system drive has been selected), check task manager for disk usage if your worried it is not doing anything','Windows Volume Check','Ok','Warning') | Out-Null
$form = New-Object System.Windows.Forms.Form
$form.Text = 'Windows Volume Check'
$form.StartPosition = 'CenterScreen'
$form.Size = New-Object System.Drawing.Size(310,350)
$objIcon = New-Object system.drawing.icon (".\Assets\windowslogo.ico")
$form.Icon = $objIcon

    $CheckAbutton = New-Object System.Windows.Forms.Button
    $CheckAbutton.Location = New-Object System.Drawing.Size(25,15)
    $CheckAbutton.Size = New-Object System.Drawing.Size(75,23)
    $CheckAbutton.Text = "Scan A"
    $CheckAbutton.Add_Click($A)

    $CheckBbutton = New-Object System.Windows.Forms.Button
    $CheckBbutton.Location = New-Object System.Drawing.Size(105,15)
    $CheckBbutton.Size = New-Object System.Drawing.Size(75,23)
    $CheckBbutton.Text = "Scan B"
    $CheckBbutton.Add_Click($B)

    $CheckCbutton = New-Object System.Windows.Forms.Button
    $CheckCbutton.Location = New-Object System.Drawing.Size(185,15)
    $CheckCbutton.Size = New-Object System.Drawing.Size(75,23)
    $CheckCbutton.Text = "Scan C"
    $CheckCbutton.Add_Click($C)

    $CheckDbutton = New-Object System.Windows.Forms.Button
    $CheckDbutton.Location = New-Object System.Drawing.Size(25,45)
    $CheckDbutton.Size = New-Object System.Drawing.Size(75,23)
    $CheckDbutton.Text = "Scan D"
    $CheckDbutton.Add_Click($D)

    $CheckEbutton = New-Object System.Windows.Forms.Button
    $CheckEbutton.Location = New-Object System.Drawing.Size(105,45)
    $CheckEbutton.Size = New-Object System.Drawing.Size(75,23)
    $CheckEbutton.Text = "Scan E"
    $CheckEbutton.Add_Click($E)

    $CheckFbutton = New-Object System.Windows.Forms.Button
    $CheckFbutton.Location = New-Object System.Drawing.Size(185,45)
    $CheckFbutton.Size = New-Object System.Drawing.Size(75,23)
    $CheckFbutton.Text = "Scan F"
    $CheckFbutton.Add_Click($F)

    $CheckGbutton = New-Object System.Windows.Forms.Button
    $CheckGbutton.Location = New-Object System.Drawing.Size(25,75)
    $CheckGbutton.Size = New-Object System.Drawing.Size(75,23)
    $CheckGbutton.Text = "Scan G"
    $CheckGbutton.Add_Click($G)

    $CheckHbutton = New-Object System.Windows.Forms.Button
    $CheckHbutton.Location = New-Object System.Drawing.Size(105,75)
    $CheckHbutton.Size = New-Object System.Drawing.Size(75,23)
    $CheckHbutton.Text = "Scan H"
    $CheckHbutton.Add_Click($H)

    $CheckIbutton = New-Object System.Windows.Forms.Button
    $CheckIbutton.Location = New-Object System.Drawing.Size(185,75)
    $CheckIbutton.Size = New-Object System.Drawing.Size(75,23)
    $CheckIbutton.Text = "Scan I"
    $CheckIbutton.Add_Click($I)

    $CheckJbutton = New-Object System.Windows.Forms.Button
    $CheckJbutton.Location = New-Object System.Drawing.Size(25,105)
    $CheckJbutton.Size = New-Object System.Drawing.Size(75,23)
    $CheckJbutton.Text = "Scan J"
    $CheckJbutton.Add_Click($J)

    $CheckKbutton = New-Object System.Windows.Forms.Button
    $CheckKbutton.Location = New-Object System.Drawing.Size(105,105)
    $CheckKbutton.Size = New-Object System.Drawing.Size(75,23)
    $CheckKbutton.Text = "Scan K"
    $CheckKbutton.Add_Click($K)

    $CheckLbutton = New-Object System.Windows.Forms.Button
    $CheckLbutton.Location = New-Object System.Drawing.Size(185,105)
    $CheckLbutton.Size = New-Object System.Drawing.Size(75,23)
    $CheckLbutton.Text = "Scan L"
    $CheckLbutton.Add_Click($L)

    $CheckMbutton = New-Object System.Windows.Forms.Button
    $CheckMbutton.Location = New-Object System.Drawing.Size(25,135)
    $CheckMbutton.Size = New-Object System.Drawing.Size(75,23)
    $CheckMbutton.Text = "Scan M"
    $CheckMbutton.Add_Click($M)

    $CheckNbutton = New-Object System.Windows.Forms.Button
    $CheckNbutton.Location = New-Object System.Drawing.Size(105,135)
    $CheckNbutton.Size = New-Object System.Drawing.Size(75,23)
    $CheckNbutton.Text = "Scan N"
    $CheckNbutton.Add_Click($N)

    $CheckObutton = New-Object System.Windows.Forms.Button
    $CheckObutton.Location = New-Object System.Drawing.Size(185,135)
    $CheckObutton.Size = New-Object System.Drawing.Size(75,23)
    $CheckObutton.Text = "Scan O"
    $CheckObutton.Add_Click($O)

    $CheckPbutton = New-Object System.Windows.Forms.Button
    $CheckPbutton.Location = New-Object System.Drawing.Size(25,165)
    $CheckPbutton.Size = New-Object System.Drawing.Size(75,23)
    $CheckPbutton.Text = "Scan P"
    $CheckPbutton.Add_Click($P)

    $CheckQbutton = New-Object System.Windows.Forms.Button
    $CheckQbutton.Location = New-Object System.Drawing.Size(105,165)
    $CheckQbutton.Size = New-Object System.Drawing.Size(75,23)
    $CheckQbutton.Text = "Scan Q"
    $CheckQbutton.Add_Click($Q)

    $CheckRbutton = New-Object System.Windows.Forms.Button
    $CheckRbutton.Location = New-Object System.Drawing.Size(185,165)
    $CheckRbutton.Size = New-Object System.Drawing.Size(75,23)
    $CheckRbutton.Text = "Scan R"
    $CheckRbutton.Add_Click($R)

    $CheckSbutton = New-Object System.Windows.Forms.Button
    $CheckSbutton.Location = New-Object System.Drawing.Size(25,195)
    $CheckSbutton.Size = New-Object System.Drawing.Size(75,23)
    $CheckSbutton.Text = "Scan S"
    $CheckSbutton.Add_Click($S)

    $CheckTbutton = New-Object System.Windows.Forms.Button
    $CheckTbutton.Location = New-Object System.Drawing.Size(105,195)
    $CheckTbutton.Size = New-Object System.Drawing.Size(75,23)
    $CheckTbutton.Text = "Scan T"
    $CheckTbutton.Add_Click($T)

    $CheckUbutton = New-Object System.Windows.Forms.Button
    $CheckUbutton.Location = New-Object System.Drawing.Size(185,195)
    $CheckUbutton.Size = New-Object System.Drawing.Size(75,23)
    $CheckUbutton.Text = "Scan U"
    $CheckUbutton.Add_Click($U)

    $CheckVbutton = New-Object System.Windows.Forms.Button
    $CheckVbutton.Location = New-Object System.Drawing.Size(25,225)
    $CheckVbutton.Size = New-Object System.Drawing.Size(75,23)
    $CheckVbutton.Text = "Scan V"
    $CheckVbutton.Add_Click($V)

    $CheckWbutton = New-Object System.Windows.Forms.Button
    $CheckWbutton.Location = New-Object System.Drawing.Size(105,225)
    $CheckWbutton.Size = New-Object System.Drawing.Size(75,23)
    $CheckWbutton.Text = "Scan W"
    $CheckWbutton.Add_Click($W)

    $CheckXbutton = New-Object System.Windows.Forms.Button
    $CheckXbutton.Location = New-Object System.Drawing.Size(185,225)
    $CheckXbutton.Size = New-Object System.Drawing.Size(75,23)
    $CheckXbutton.Text = "Scan X"
    $CheckXbutton.Add_Click($X)

    $CheckYbutton = New-Object System.Windows.Forms.Button
    $CheckYbutton.Location = New-Object System.Drawing.Size(25,255)
    $CheckYbutton.Size = New-Object System.Drawing.Size(75,23)
    $CheckYbutton.Text = "Scan Y"
    $CheckYbutton.Add_Click($Y)

    $CheckZbutton = New-Object System.Windows.Forms.Button
    $CheckZbutton.Location = New-Object System.Drawing.Size(105,255)
    $CheckZbutton.Size = New-Object System.Drawing.Size(75,23)
    $CheckZbutton.Text = "Scan Z"
    $CheckZbutton.Add_Click($Z)

    #Template:
    #$Check**button = New-Object System.Windows.Forms.Button
    #$Check**button.Location = New-Object System.Drawing.Size(25,15)
    #$Check**button.Size = New-Object System.Drawing.Size(75,23)
    #$Check**button.Text = "Check **"
    #$Check**button.Add_Click($**)

    $Form.Controls.Add($CheckAbutton)
    $Form.Controls.Add($CheckBbutton)
    $Form.Controls.Add($CheckCbutton)
    $Form.Controls.Add($CheckDbutton)
    $Form.Controls.Add($CheckEbutton)
    $Form.Controls.Add($CheckFbutton)
    $Form.Controls.Add($CheckGbutton)
    $Form.Controls.Add($CheckHbutton)
    $Form.Controls.Add($CheckIbutton)
    $Form.Controls.Add($CheckJbutton)
    $Form.Controls.Add($CheckKbutton)
    $Form.Controls.Add($CheckLbutton)
    $Form.Controls.Add($CheckMbutton)
    $Form.Controls.Add($CheckNbutton)
    $Form.Controls.Add($CheckObutton)
    $Form.Controls.Add($CheckPbutton)
    $Form.Controls.Add($CheckQbutton)
    $Form.Controls.Add($CheckRbutton)
    $Form.Controls.Add($CheckSbutton)
    $Form.Controls.Add($CheckTbutton)
    $Form.Controls.Add($CheckUbutton)
    $Form.Controls.Add($CheckVbutton)
    $Form.Controls.Add($CheckWbutton)
    $Form.Controls.Add($CheckXbutton)
    $Form.Controls.Add($CheckYbutton)
    $Form.Controls.Add($CheckZbutton)

$form.showdialog()

Exit
#Created by Chris Masters