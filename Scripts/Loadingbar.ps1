# Windows Maintenance Loading Bar Component
# Provides progress bar functionality for integration with other scripts

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

function Show-LoadingBar {
    param(
        [string]$Title = "Processing...",
        [string]$Message = "Please wait...",
        [int]$Duration = 3000,  # milliseconds
        [switch]$Indeterminate
    )

    try {
        $loadingForm = New-Object System.Windows.Forms.Form
        $loadingForm.Text = $Title
        $loadingForm.Size = New-Object System.Drawing.Size(400, 120)
        $loadingForm.StartPosition = "CenterScreen"
        $loadingForm.FormBorderStyle = "FixedDialog"
        $loadingForm.ControlBox = $false
        $loadingForm.TopMost = $true

        $label = New-Object System.Windows.Forms.Label
        $label.Text = $Message
        $label.Size = New-Object System.Drawing.Size(360, 20)
        $label.Location = New-Object System.Drawing.Point(20, 20)
        $label.TextAlign = "MiddleCenter"
        $loadingForm.Controls.Add($label)

        $progressBar = New-Object System.Windows.Forms.ProgressBar
        $progressBar.Size = New-Object System.Drawing.Size(360, 25)
        $progressBar.Location = New-Object System.Drawing.Point(20, 50)

        if ($Indeterminate) {
            $progressBar.Style = "Marquee"
            $progressBar.MarqueeAnimationSpeed = 30
        } else {
            $progressBar.Style = "Continuous"
            $progressBar.Value = 0
        }

        $loadingForm.Controls.Add($progressBar)
        $loadingForm.Show()

        # Force UI update
        [System.Windows.Forms.Application]::DoEvents()

        if (-not $Indeterminate) {
            # Simulate progress for determinate bar
            $steps = 20
            $stepDuration = $Duration / $steps

            for ($i = 1; $i -le $steps; $i++) {
                $progressBar.Value = [Math]::Min(($i / $steps) * 100, 100)
                $loadingForm.Refresh()
                [System.Windows.Forms.Application]::DoEvents()
                Start-Sleep -Milliseconds $stepDuration
            }
        } else {
            Start-Sleep -Milliseconds $Duration
        }

        $loadingForm.Close()
        $loadingForm.Dispose()

    } catch {
        Write-Host "Error displaying loading bar: $_" -ForegroundColor Red
    }
}

function Update-ProgressBar {
    param(
        [System.Windows.Forms.ProgressBar]$ProgressBar,
        [System.Windows.Forms.Form]$Form,
        [int]$PercentComplete,
        [string]$StatusMessage = ""
    )

    if ($ProgressBar) {
        $ProgressBar.Value = [Math]::Min([Math]::Max($PercentComplete, 0), 100)
        if ($Form) {
            $Form.Refresh()
            [System.Windows.Forms.Application]::DoEvents()
        }
    }

    if ($StatusMessage) {
        Write-Host $StatusMessage -ForegroundColor Cyan
    }
}

# Export functions for use in other scripts
Export-ModuleMember -Function Show-LoadingBar, Update-ProgressBar