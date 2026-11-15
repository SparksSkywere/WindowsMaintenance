Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Firewall Privacy
# - Ensures Windows Firewall is on
# - Sets non-domain network profiles to Private (DomainAuthenticated / business left alone)
# - Adds outbound block rules for telemetry clients and privacy endpoints
# Does not rewrite the hosts file. Complements Windows Privacy.

$AutomatedMode = $args -contains '--automated'
$StoreRoot = 'HKLM:\SOFTWARE\WindowsMaintenance\FirewallPrivacy'
$RuleGroup = 'Windows Maintenance - Firewall Privacy'
$RulePrefix = 'WM-FirewallPrivacy-'

function Write-FwStatus {
    param([string]$Message)
    Write-Host $Message
}

function Invoke-FwStep {
    param([scriptblock]$Block, [string]$Description)
    try {
        Write-FwStatus "Applying: $Description..."
        & $Block
        Write-FwStatus "Completed: $Description"
    } catch {
        Write-FwStatus "Warning during $Description : $($_.Exception.Message)"
    }
}

function Ensure-Key {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -Path $Path -Force | Out-Null
    }
}

function Enable-WindowsFirewallProfiles {
    Invoke-FwStep {
        foreach ($profileName in @('Domain', 'Private', 'Public')) {
            try {
                Set-NetFirewallProfile -Profile $profileName -Enabled True -ErrorAction Stop
                Write-FwStatus "  Firewall enabled: $profileName"
            } catch {
                Write-FwStatus "  Firewall profile $profileName left unchanged: $($_.Exception.Message)"
            }
        }
    } 'Windows Firewall profiles on'
}

function Set-NonDomainNetworksPrivate {
    Invoke-FwStep {
        Ensure-Key $StoreRoot
        $previous = New-Object System.Collections.Generic.List[string]

        $profiles = @(Get-NetConnectionProfile -ErrorAction Stop)
        if ($profiles.Count -eq 0) {
            Write-FwStatus '  No connection profiles were found.'
            return
        }

        foreach ($profile in $profiles) {
            $name = [string]$profile.Name
            $category = [string]$profile.NetworkCategory
            $ifIndex = [int]$profile.InterfaceIndex
            $alias = [string]$profile.InterfaceAlias

            if ($category -eq 'DomainAuthenticated') {
                Write-FwStatus "  Skipped domain/business network: $name ($alias)"
                continue
            }

            $previous.Add("$ifIndex|$category|$name|$alias")
            if ($category -eq 'Private') {
                Write-FwStatus "  Already Private: $name ($alias)"
                continue
            }

            try {
                Set-NetConnectionProfile -InterfaceIndex $ifIndex -NetworkCategory Private -ErrorAction Stop
                Write-FwStatus "  Set Private: $name ($alias) [was $category]"
            } catch {
                Write-FwStatus "  Could not set $name to Private: $($_.Exception.Message)"
            }
        }

        if ($previous.Count -gt 0) {
            Set-ItemProperty -Path $StoreRoot -Name 'PreviousNetworkCategories' -Value $previous.ToArray() -Type MultiString -Force
        }
    } 'Non-domain networks set to Private'
}

function Remove-ExistingPrivacyFirewallRules {
    $existing = @(Get-NetFirewallRule -ErrorAction SilentlyContinue | Where-Object {
        $_.DisplayName -like "$RulePrefix*" -or $_.Group -eq $RuleGroup
    })
    foreach ($rule in $existing) {
        try {
            Remove-NetFirewallRule -Name $rule.Name -Confirm:$false -ErrorAction SilentlyContinue
        } catch {
            try { $rule | Remove-NetFirewallRule -Confirm:$false -ErrorAction SilentlyContinue } catch {}
        }
    }
}

function New-ProgramOutboundBlock {
    param(
        [Parameter(Mandatory)][string]$DisplaySuffix,
        [Parameter(Mandatory)][string]$ProgramPath,
        [string]$Description = ''
    )

    if (-not (Test-Path -LiteralPath $ProgramPath)) {
        Write-FwStatus "  Skip missing program: $ProgramPath"
        return
    }

    $displayName = "$RulePrefix$DisplaySuffix"
    New-NetFirewallRule -DisplayName $displayName `
        -Direction Outbound `
        -Action Block `
        -Program $ProgramPath `
        -Enabled True `
        -Profile Any `
        -Group $RuleGroup `
        -Description $Description `
        -ErrorAction Stop | Out-Null
    Write-FwStatus "  Blocked outbound: $DisplaySuffix"
}

function New-ServiceOutboundBlock {
    param(
        [Parameter(Mandatory)][string]$DisplaySuffix,
        [Parameter(Mandatory)][string]$ServiceShortName,
        [string]$Description = ''
    )

    $svc = Get-Service -Name $ServiceShortName -ErrorAction SilentlyContinue
    if (-not $svc) {
        Write-FwStatus "  Skip missing service: $ServiceShortName"
        return
    }

    $displayName = "$RulePrefix$DisplaySuffix"
    New-NetFirewallRule -DisplayName $displayName `
        -Direction Outbound `
        -Action Block `
        -Service $ServiceShortName `
        -Enabled True `
        -Profile Any `
        -Group $RuleGroup `
        -Description $Description `
        -ErrorAction Stop | Out-Null
    Write-FwStatus "  Blocked outbound service: $ServiceShortName"
}

function New-RemoteAddressOutboundBlock {
    param(
        [Parameter(Mandatory)][string]$DisplaySuffix,
        [Parameter(Mandatory)][string[]]$RemoteAddress,
        [string]$Description = '',
        [string]$Protocol = 'Any',
        [string]$RemotePort = 'Any'
    )

    if (-not $RemoteAddress -or $RemoteAddress.Count -eq 0) { return }

    $displayName = "$RulePrefix$DisplaySuffix"
    $params = @{
        DisplayName   = $displayName
        Direction     = 'Outbound'
        Action        = 'Block'
        RemoteAddress = $RemoteAddress
        Enabled       = $true
        Profile       = 'Any'
        Group         = $RuleGroup
        Description   = $Description
        ErrorAction   = 'Stop'
    }
    if ($Protocol -ne 'Any') { $params['Protocol'] = $Protocol }
    if ($RemotePort -ne 'Any') { $params['RemotePort'] = $RemotePort }

    New-NetFirewallRule @params | Out-Null
    Write-FwStatus "  Blocked remote endpoints: $DisplaySuffix"
}

function Resolve-SafeRemoteIps {
    param([string[]]$Domains)

    $ips = New-Object System.Collections.Generic.HashSet[string]
    foreach ($domain in $Domains) {
        try {
            $dnsResults = Resolve-DnsName -Name $domain -Type A_AAAA -ErrorAction Stop
            foreach ($row in @($dnsResults)) {
                if ($row.PSObject.Properties.Match('IPAddress').Count -eq 0 -or -not $row.IPAddress) { continue }
                $ip = [string]$row.IPAddress
                if (-not $ip) { continue }
                if ($ip -eq '0.0.0.0' -or $ip -eq '::' -or $ip -eq '::1') { continue }
                if ($ip -match '^fe[89ab]:' -or $ip -match '^ff[0-9a-f]:') { continue }
                if ($ip -match '^127\.|^169\.254\.|^224\.|^239\.|^::ffff:') { continue }
                [void]$ips.Add($ip)
            }
        } catch {
            # Domain may not resolve on this network; program/service rules still apply.
        }
    }
    return @($ips)
}

function Apply-FirewallPrivacyBlocks {
    Invoke-FwStep {
        Remove-ExistingPrivacyFirewallRules

        $sys32 = Join-Path $env:SystemRoot 'System32'
        $programBlocks = @(
            @{ Suffix = 'CompatTelRunner'; Path = (Join-Path $sys32 'CompatTelRunner.exe'); Desc = 'Compatibility Telemetry runner outbound' }
            @{ Suffix = 'DeviceCensus'; Path = (Join-Path $sys32 'DeviceCensus.exe'); Desc = 'Device census / inventory outbound' }
            @{ Suffix = 'WerFault'; Path = (Join-Path $sys32 'WerFault.exe'); Desc = 'Windows Error Reporting fault outbound' }
            @{ Suffix = 'wermgr'; Path = (Join-Path $sys32 'wermgr.exe'); Desc = 'Windows Error Reporting manager outbound' }
            @{ Suffix = 'SiufDmClient'; Path = (Join-Path $sys32 'dmclient.exe'); Desc = 'Feedback / SIUF client outbound when present' }
        )
        foreach ($entry in $programBlocks) {
            try {
                New-ProgramOutboundBlock -DisplaySuffix $entry.Suffix -ProgramPath $entry.Path -Description $entry.Desc
            } catch {
                Write-FwStatus "  Program rule skipped ($($entry.Suffix)): $($_.Exception.Message)"
            }
        }

        foreach ($svcName in @('DiagTrack', 'dmwappushservice', 'wisvc')) {
            try {
                New-ServiceOutboundBlock -DisplaySuffix "Svc-$svcName" -ServiceShortName $svcName -Description "Outbound block for $svcName"
            } catch {
                Write-FwStatus "  Service rule skipped ($svcName): $($_.Exception.Message)"
            }
        }

        $privacyDomains = @(
            'vortex.data.microsoft.com',
            'vortex-win.data.microsoft.com',
            'v10.events.data.microsoft.com',
            'v10c.events.data.microsoft.com',
            'v10.vortex-win.data.microsoft.com',
            'settings-win.data.microsoft.com',
            'watson.telemetry.microsoft.com',
            'telecommand.telemetry.microsoft.com',
            'sqm.telemetry.microsoft.com',
            'oca.telemetry.microsoft.com',
            'vortex-sandbox.data.microsoft.com',
            'feedback.search.microsoft.com',
            'feedback.windows.com',
            'telemetry.microsoft.com',
            'telemetry.appex.bing.net',
            'live.rads.msn.com',
            'ads1.msads.net',
            'ads1.msn.com',
            'a.ads1.msn.com',
            'a.ads2.msads.net',
            'adnexus.net',
            'advertising.microsoft.com',
            'rad.msn.com',
            'preview.msn.com',
            'activity.windows.com',
            'ceip.microsoft.com'
        )

        try { Clear-DnsClientCache -ErrorAction SilentlyContinue } catch {}
        $resolvedIps = Resolve-SafeRemoteIps -Domains $privacyDomains
        if ($resolvedIps.Count -gt 0) {
            try {
                New-RemoteAddressOutboundBlock `
                    -DisplaySuffix 'TelemetryAdsIPs' `
                    -RemoteAddress $resolvedIps `
                    -Protocol 'TCP' `
                    -RemotePort 443 `
                    -Description 'Outbound TCP/443 block for resolved Microsoft telemetry and advertising endpoints'
            } catch {
                Write-FwStatus "  IP endpoint rule skipped: $($_.Exception.Message)"
            }
        } else {
            Write-FwStatus '  No telemetry/ad IPs resolved on this network; program/service blocks still apply.'
        }

        Write-FwStatus 'Firewall privacy rules applied. Windows Update and normal browsing are not blanket-blocked.'
    } 'Outbound privacy firewall rules'
}

function Invoke-FirewallPrivacy {
    Write-FwStatus 'Starting Firewall Privacy...'

    Enable-WindowsFirewallProfiles
    Set-NonDomainNetworksPrivate
    Apply-FirewallPrivacyBlocks

    Write-FwStatus 'Firewall Privacy completed.'
}

try {
    Invoke-FirewallPrivacy

    if (-not $AutomatedMode) {
        Add-Type -AssemblyName System.Windows.Forms
        [System.Windows.Forms.MessageBox]::Show(
            "Firewall Privacy is applied.`n`n- Windows Firewall profiles are on`n- Non-domain networks are Private (domain/business left alone)`n- Outbound blocks cover telemetry clients and resolved privacy endpoints`n`nRevert removes these rules and restores saved network categories where possible.",
            'Firewall Privacy',
            'OK',
            'Information'
        ) | Out-Null
    }

    exit 0
} catch {
    Write-FwStatus "Firewall Privacy failed: $($_.Exception.Message)"
    if (-not $AutomatedMode) {
        try {
            Add-Type -AssemblyName System.Windows.Forms
            [System.Windows.Forms.MessageBox]::Show(
                "Firewall Privacy reported an error.`n$($_.Exception.Message)",
                'Firewall Privacy - Warning',
                'OK',
                'Warning'
            ) | Out-Null
        } catch {}
    }
    exit 1
}
