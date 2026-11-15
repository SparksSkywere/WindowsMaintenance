Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Revert for FirewallPrivacy.ps1

$AutomatedMode = $args -contains '--automated'
$StoreRoot = 'HKLM:\SOFTWARE\WindowsMaintenance\FirewallPrivacy'
$RuleGroup = 'Windows Maintenance - Firewall Privacy'
$RulePrefix = 'WM-FirewallPrivacy-'

function Write-RevertStatus {
    param([string]$Message)
    Write-Host $Message
}

function Invoke-RevertStep {
    param([scriptblock]$Block, [string]$Description)
    try {
        Write-RevertStatus "Reverting: $Description..."
        & $Block
        Write-RevertStatus "Reverted: $Description"
    } catch {
        Write-RevertStatus "Warning reverting $Description : $($_.Exception.Message)"
    }
}

function Remove-FirewallPrivacyRules {
    Invoke-RevertStep {
        $existing = @(Get-NetFirewallRule -ErrorAction SilentlyContinue | Where-Object {
            $_.DisplayName -like "$RulePrefix*" -or $_.Group -eq $RuleGroup
        })
        $count = 0
        foreach ($rule in $existing) {
            try {
                Remove-NetFirewallRule -Name $rule.Name -Confirm:$false -ErrorAction SilentlyContinue
                $count++
            } catch {
                try { $rule | Remove-NetFirewallRule -Confirm:$false -ErrorAction SilentlyContinue; $count++ } catch {}
            }
        }
        Write-RevertStatus "  Removed $count firewall privacy rule(s)."
    } 'Firewall privacy outbound rules'
}

function Restore-NetworkCategories {
    Invoke-RevertStep {
        if (-not (Test-Path -LiteralPath $StoreRoot)) {
            Write-RevertStatus '  No saved network categories were found.'
            return
        }

        $saved = @((Get-ItemProperty -LiteralPath $StoreRoot -Name 'PreviousNetworkCategories' -ErrorAction SilentlyContinue).PreviousNetworkCategories)
        if (-not $saved -or $saved.Count -eq 0) {
            Write-RevertStatus '  Saved network category list was empty.'
            return
        }

        foreach ($entry in $saved) {
            if ([string]::IsNullOrWhiteSpace($entry)) { continue }
            $parts = $entry.Split('|')
            if ($parts.Count -lt 2) { continue }

            $ifIndexText = $parts[0]
            $category = $parts[1]
            $name = if ($parts.Count -ge 3) { $parts[2] } else { $ifIndexText }

            if ($category -eq 'DomainAuthenticated') {
                Write-RevertStatus "  Domain/business network left alone: $name"
                continue
            }
            if ($category -notin @('Public', 'Private')) {
                Write-RevertStatus "  Skip unknown saved category for $name : $category"
                continue
            }

            try {
                $ifIndex = [int]$ifIndexText
                $current = Get-NetConnectionProfile -InterfaceIndex $ifIndex -ErrorAction SilentlyContinue
                if (-not $current) {
                    Write-RevertStatus "  Interface $ifIndex no longer present ($name)"
                    continue
                }
                if ([string]$current.NetworkCategory -eq 'DomainAuthenticated') {
                    Write-RevertStatus "  Now domain-authenticated; left alone: $name"
                    continue
                }
                Set-NetConnectionProfile -InterfaceIndex $ifIndex -NetworkCategory $category -ErrorAction Stop
                Write-RevertStatus "  Restored $name to $category"
            } catch {
                Write-RevertStatus "  Could not restore $name : $($_.Exception.Message)"
            }
        }

        Remove-ItemProperty -LiteralPath $StoreRoot -Name 'PreviousNetworkCategories' -Force -ErrorAction SilentlyContinue
    } 'Saved network categories'
}

try {
    Write-RevertStatus 'Starting Firewall Privacy reversal...'
    Remove-FirewallPrivacyRules
    Restore-NetworkCategories
    Write-RevertStatus 'Firewall Privacy reversal completed.'

    if (-not $AutomatedMode) {
        Add-Type -AssemblyName System.Windows.Forms
        [System.Windows.Forms.MessageBox]::Show(
            'Firewall Privacy rules were removed and saved network categories were restored where possible. Domain/business networks were never changed.',
            'Revert Firewall Privacy',
            'OK',
            'Information'
        ) | Out-Null
    }

    exit 0
} catch {
    Write-RevertStatus "Firewall Privacy revert failed: $($_.Exception.Message)"
    exit 1
}
