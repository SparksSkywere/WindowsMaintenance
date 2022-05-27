Clear-Host
#Defragmenting the selected drive letter, all drives for windows have been added, no real customisation is needed past this point
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

#Drive Letters + Defrag command
$A = {Optimize-Volume A -Defrag}
$B = {Optimize-Volume B -Defrag}
$C = {Optimize-Volume C -Defrag}
$D = {Optimize-Volume D -Defrag}
$E = {Optimize-Volume E -Defrag}
$F = {Optimize-Volume F -Defrag}
$G = {Optimize-Volume G -Defrag}
$H = {Optimize-Volume H -Defrag}
$I = {Optimize-Volume I -Defrag}
$J = {Optimize-Volume J -Defrag}
$K = {Optimize-Volume K -Defrag}
$L = {Optimize-Volume L -Defrag}
$M = {Optimize-Volume M -Defrag}
$N = {Optimize-Volume N -Defrag}
$O = {Optimize-Volume O -Defrag}
$P = {Optimize-Volume P -Defrag}
$Q = {Optimize-Volume Q -Defrag}
$R = {Optimize-Volume R -Defrag}
$S = {Optimize-Volume S -Defrag}
$T = {Optimize-Volume T -Defrag}
$U = {Optimize-Volume U -Defrag}
$V = {Optimize-Volume V -Defrag}
$W = {Optimize-Volume W -Defrag}
$X = {Optimize-Volume X -Defrag}
$Y = {Optimize-Volume Y -Defrag}
$Z = {Optimize-Volume Z -Defrag}

#Create form containing all the buttons to the commands set above
[System.Windows.MessageBox]::Show('When you select a drive the defrag will run in the background, check task manager for disk usage','Windows Quick Defrag','Ok','Warning') | Out-Null
$form = New-Object System.Windows.Forms.Form
$form.Text = 'Windows Quick Defrag'
$form.StartPosition = 'CenterScreen'
$form.Size = New-Object System.Drawing.Size(310,350)
$objIcon = New-Object system.drawing.icon (".\Assets\windowslogo.ico")
$form.Icon = $objIcon

    $defragAbutton = New-Object System.Windows.Forms.Button
    $defragAbutton.Location = New-Object System.Drawing.Size(25,15)
    $defragAbutton.Size = New-Object System.Drawing.Size(75,23)
    $defragAbutton.Text = "Defrag A"
    $defragAbutton.Add_Click($A)

    $defragBbutton = New-Object System.Windows.Forms.Button
    $defragBbutton.Location = New-Object System.Drawing.Size(105,15)
    $defragBbutton.Size = New-Object System.Drawing.Size(75,23)
    $defragBbutton.Text = "Defrag B"
    $defragBbutton.Add_Click($B)

    $defragCbutton = New-Object System.Windows.Forms.Button
    $defragCbutton.Location = New-Object System.Drawing.Size(185,15)
    $defragCbutton.Size = New-Object System.Drawing.Size(75,23)
    $defragCbutton.Text = "Defrag C"
    $defragCbutton.Add_Click($C)

    $defragDbutton = New-Object System.Windows.Forms.Button
    $defragDbutton.Location = New-Object System.Drawing.Size(25,45)
    $defragDbutton.Size = New-Object System.Drawing.Size(75,23)
    $defragDbutton.Text = "Defrag D"
    $defragDbutton.Add_Click($D)

    $defragEbutton = New-Object System.Windows.Forms.Button
    $defragEbutton.Location = New-Object System.Drawing.Size(105,45)
    $defragEbutton.Size = New-Object System.Drawing.Size(75,23)
    $defragEbutton.Text = "Defrag E"
    $defragEbutton.Add_Click($E)

    $defragFbutton = New-Object System.Windows.Forms.Button
    $defragFbutton.Location = New-Object System.Drawing.Size(185,45)
    $defragFbutton.Size = New-Object System.Drawing.Size(75,23)
    $defragFbutton.Text = "Defrag F"
    $defragFbutton.Add_Click($F)

    $defragGbutton = New-Object System.Windows.Forms.Button
    $defragGbutton.Location = New-Object System.Drawing.Size(25,75)
    $defragGbutton.Size = New-Object System.Drawing.Size(75,23)
    $defragGbutton.Text = "Defrag G"
    $defragGbutton.Add_Click($G)

    $defragHbutton = New-Object System.Windows.Forms.Button
    $defragHbutton.Location = New-Object System.Drawing.Size(105,75)
    $defragHbutton.Size = New-Object System.Drawing.Size(75,23)
    $defragHbutton.Text = "Defrag H"
    $defragHbutton.Add_Click($H)

    $defragIbutton = New-Object System.Windows.Forms.Button
    $defragIbutton.Location = New-Object System.Drawing.Size(185,75)
    $defragIbutton.Size = New-Object System.Drawing.Size(75,23)
    $defragIbutton.Text = "Defrag I"
    $defragIbutton.Add_Click($I)

    $defragJbutton = New-Object System.Windows.Forms.Button
    $defragJbutton.Location = New-Object System.Drawing.Size(25,105)
    $defragJbutton.Size = New-Object System.Drawing.Size(75,23)
    $defragJbutton.Text = "Defrag J"
    $defragJbutton.Add_Click($J)

    $defragKbutton = New-Object System.Windows.Forms.Button
    $defragKbutton.Location = New-Object System.Drawing.Size(105,105)
    $defragKbutton.Size = New-Object System.Drawing.Size(75,23)
    $defragKbutton.Text = "Defrag K"
    $defragKbutton.Add_Click($K)

    $defragLbutton = New-Object System.Windows.Forms.Button
    $defragLbutton.Location = New-Object System.Drawing.Size(185,105)
    $defragLbutton.Size = New-Object System.Drawing.Size(75,23)
    $defragLbutton.Text = "Defrag L"
    $defragLbutton.Add_Click($L)

    $defragMbutton = New-Object System.Windows.Forms.Button
    $defragMbutton.Location = New-Object System.Drawing.Size(25,135)
    $defragMbutton.Size = New-Object System.Drawing.Size(75,23)
    $defragMbutton.Text = "Defrag M"
    $defragMbutton.Add_Click($M)

    $defragNbutton = New-Object System.Windows.Forms.Button
    $defragNbutton.Location = New-Object System.Drawing.Size(105,135)
    $defragNbutton.Size = New-Object System.Drawing.Size(75,23)
    $defragNbutton.Text = "Defrag N"
    $defragNbutton.Add_Click($N)

    $defragObutton = New-Object System.Windows.Forms.Button
    $defragObutton.Location = New-Object System.Drawing.Size(185,135)
    $defragObutton.Size = New-Object System.Drawing.Size(75,23)
    $defragObutton.Text = "Defrag O"
    $defragObutton.Add_Click($O)

    $defragPbutton = New-Object System.Windows.Forms.Button
    $defragPbutton.Location = New-Object System.Drawing.Size(25,165)
    $defragPbutton.Size = New-Object System.Drawing.Size(75,23)
    $defragPbutton.Text = "Defrag P"
    $defragPbutton.Add_Click($P)

    $defragQbutton = New-Object System.Windows.Forms.Button
    $defragQbutton.Location = New-Object System.Drawing.Size(105,165)
    $defragQbutton.Size = New-Object System.Drawing.Size(75,23)
    $defragQbutton.Text = "Defrag Q"
    $defragQbutton.Add_Click($Q)

    $defragRbutton = New-Object System.Windows.Forms.Button
    $defragRbutton.Location = New-Object System.Drawing.Size(185,165)
    $defragRbutton.Size = New-Object System.Drawing.Size(75,23)
    $defragRbutton.Text = "Defrag R"
    $defragRbutton.Add_Click($R)

    $defragSbutton = New-Object System.Windows.Forms.Button
    $defragSbutton.Location = New-Object System.Drawing.Size(25,195)
    $defragSbutton.Size = New-Object System.Drawing.Size(75,23)
    $defragSbutton.Text = "Defrag S"
    $defragSbutton.Add_Click($S)

    $defragTbutton = New-Object System.Windows.Forms.Button
    $defragTbutton.Location = New-Object System.Drawing.Size(105,195)
    $defragTbutton.Size = New-Object System.Drawing.Size(75,23)
    $defragTbutton.Text = "Defrag T"
    $defragTbutton.Add_Click($T)

    $defragUbutton = New-Object System.Windows.Forms.Button
    $defragUbutton.Location = New-Object System.Drawing.Size(185,195)
    $defragUbutton.Size = New-Object System.Drawing.Size(75,23)
    $defragUbutton.Text = "Defrag U"
    $defragUbutton.Add_Click($U)

    $defragVbutton = New-Object System.Windows.Forms.Button
    $defragVbutton.Location = New-Object System.Drawing.Size(25,225)
    $defragVbutton.Size = New-Object System.Drawing.Size(75,23)
    $defragVbutton.Text = "Defrag V"
    $defragVbutton.Add_Click($V)

    $defragWbutton = New-Object System.Windows.Forms.Button
    $defragWbutton.Location = New-Object System.Drawing.Size(105,225)
    $defragWbutton.Size = New-Object System.Drawing.Size(75,23)
    $defragWbutton.Text = "Defrag W"
    $defragWbutton.Add_Click($W)

    $defragXbutton = New-Object System.Windows.Forms.Button
    $defragXbutton.Location = New-Object System.Drawing.Size(185,225)
    $defragXbutton.Size = New-Object System.Drawing.Size(75,23)
    $defragXbutton.Text = "Defrag X"
    $defragXbutton.Add_Click($X)

    $defragYbutton = New-Object System.Windows.Forms.Button
    $defragYbutton.Location = New-Object System.Drawing.Size(25,255)
    $defragYbutton.Size = New-Object System.Drawing.Size(75,23)
    $defragYbutton.Text = "Defrag Y"
    $defragYbutton.Add_Click($Y)

    $defragZbutton = New-Object System.Windows.Forms.Button
    $defragZbutton.Location = New-Object System.Drawing.Size(105,255)
    $defragZbutton.Size = New-Object System.Drawing.Size(75,23)
    $defragZbutton.Text = "Defrag Z"
    $defragZbutton.Add_Click($Z)

    #Template:
    #$defrag**button = New-Object System.Windows.Forms.Button
    #$defrag**button.Location = New-Object System.Drawing.Size(25,15)
    #$defrag**button.Size = New-Object System.Drawing.Size(75,23)
    #$defrag**button.Text = "Defrag **"
    #$defrag**button.Add_Click($**)

    $Form.Controls.Add($defragAbutton)
    $Form.Controls.Add($defragBbutton)
    $Form.Controls.Add($defragCbutton)
    $Form.Controls.Add($defragDbutton)
    $Form.Controls.Add($defragEbutton)
    $Form.Controls.Add($defragFbutton)
    $Form.Controls.Add($defragGbutton)
    $Form.Controls.Add($defragHbutton)
    $Form.Controls.Add($defragIbutton)
    $Form.Controls.Add($defragJbutton)
    $Form.Controls.Add($defragKbutton)
    $Form.Controls.Add($defragLbutton)
    $Form.Controls.Add($defragMbutton)
    $Form.Controls.Add($defragNbutton)
    $Form.Controls.Add($defragObutton)
    $Form.Controls.Add($defragPbutton)
    $Form.Controls.Add($defragQbutton)
    $Form.Controls.Add($defragRbutton)
    $Form.Controls.Add($defragSbutton)
    $Form.Controls.Add($defragTbutton)
    $Form.Controls.Add($defragUbutton)
    $Form.Controls.Add($defragVbutton)
    $Form.Controls.Add($defragWbutton)
    $Form.Controls.Add($defragXbutton)
    $Form.Controls.Add($defragYbutton)
    $Form.Controls.Add($defragZbutton)

$form.showdialog()

Exit
#Created by Chris Masters