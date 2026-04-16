# Windows Maintenance (PowerShell)

Windows Maintenance is a Windows 10/11 administrative toolkit that combines cleanup, repair, privacy hardening, debloat, and performance tuning in one guided interface.

The project is designed to be practical for real systems:
- Safe-by-default baseline actions are prioritised.
- Heavier or repair-focused tasks are available but optional.
- Complete runs are guided by a planner with preset profiles and per-task explanations.

## Requirements

- Windows 10 or Windows 11
- Administrator privileges
- PowerShell execution allowed for the session

## Quick Start

1. Run as Administrator.
2. If execution policy blocks scripts, use:
	`Set-ExecutionPolicy Bypass -Force`
3. Launch using either:
	- `RunMaintenance.bat` (easiest)
	- `WindowsMaintenance.ps1` in elevated PowerShell

Note: execution policy changes are often reverted by system policy or at reboot, depending on your environment configuration.

## What The Tool Includes

### Core Maintenance and Cleanup
1. Windows Install Cleanup (Windows 10/11 aware)
2. Reinstall Default Apps (restore removed inbox apps)
3. Uninstall OneDrive
4. System Cleaner
5. Delete Old User Profiles (DelProf2)
6. User Profile Temp Cleaner

### Repair and Health
1. DISM health scan and repair
2. System File Checker (SFC)
3. Disk check and repair
4. Disk optimisation / defragmentation workflow

### Optimisation and Privacy
1. Performance tuning controls
2. Privacy hardening controls
3. Service and scheduled task reduction
4. RAM footprint tuning (safe and advanced modes)
5. UI cleanup (including widgets/feed-style surfaces)
6. Optional Windows AI feature disablement

### Troubleshooting
The troubleshooting module includes guided routines for common issues such as:
- Internet/network faults
- Windows Update faults
- Microsoft Store faults
- Max path policy adjustments
- Selected update error remediation flows

## Complete PC Setup Planner

The `Complete PC Setup` workflow opens a planner before any actions run.

Key behaviours:
- Recommended tasks are pre-selected.
- Optional/repair-heavy tasks are left unticked by default.
- Selecting a task shows detailed explanation and expected impact.
- Optional Windows AI disablement is available and clearly described.

### Preset Profiles

1. `Minimal`
	- Light cleanup and baseline optimisation.
	- Avoids repair-heavy or broad-impact changes.

2. `Optimal` (recommended)
	- Balanced everyday profile for debloat, privacy, and responsiveness.
	- Intended for most personal systems.

3. `Aggressive`
	- Wider repair/tuning coverage and deeper policy hardening.
	- Longer runtime and stronger impact warnings.

Preset selection also sets optimisation depth (`minimal`, `optimal`, `aggressive`) for profile-driven deep tuning during automated runs.

## Windows AI Disable Option

When enabled, the tool applies policy/configuration changes to disable AI-related Windows surfaces, including Copilot- and cloud-assisted AI/search paths where supported by the host build and policy scope.

This option is explicitly optional and can be left off.

## Custom Script Area

`Scripts/CustomChanges.ps1` is provided for bespoke local changes and testing.

If you add custom workflows, ensure they are wired into the main launcher UI if you want them exposed to end users.

## Credits

- PowerShell: https://docs.microsoft.com/en-us/powershell/
- DelProf2 by Helge Klein: https://helgeklein.com/free-tools/delprof2-user-profile-deletion-tool/

## Licence

This repository is licensed under GNU terms as provided in the project licence file.