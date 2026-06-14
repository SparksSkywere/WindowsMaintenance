# Windows Maintenance (PowerShell)

Windows Maintenance is a PowerShell-based graphical tool that provides a single resizable Windows Forms interface for executing maintenance, cleanup, optimization, privacy hardening, and repair operations on Windows 10 and Windows 11 systems. The tool initializes by detecting the Windows version and validating supporting script modules before presenting its primary user interface. All system-modifying operations are designed to run under administrator privileges.

## Prerequisites

The tool requires a system running Windows 10 or Windows 11. Administrator privileges are necessary because many operations modify registry keys, services, scheduled tasks, firewall rules, and the system hosts file. PowerShell must be allowed to execute scripts in the current session. The .NET Framework components required for Windows Forms must be present, along with the scheduled task and Windows Firewall cmdlets used by the privacy and reversion modules.

## Launching the tool

Launch the tool by running the supplied `RunMaintenance.bat` file or by invoking `WindowsMaintenance.ps1` directly from an elevated PowerShell console. The script performs environment checks, loads task definitions, and displays the main window. The console window is hidden by default during normal operation unless debug mode is enabled. Execution policy changes, if required, should be applied with `Set-ExecutionPolicy Bypass -Force` for the current session only.

## The task selector interface

The main window functions as a single unified interface. A header displays the application title. Below the header is a mode selector strip followed by the preset area and task checklist.

The interface consists of:
- A mode toggle that switches between Apply and Revert behavior.
- Preset buttons that populate the task checklist with predefined selections.
- A scrollable checklist of available tasks on the left.
- A detail panel on the right that shows the description, expected impact, and guidance for the currently selected task in the checklist.

Users can manually check or uncheck individual tasks before starting execution. The interface supports resizing, and layout elements adjust automatically.

## Presets

Four presets are provided to quickly configure the task checklist:

- Minimal applies a lightweight set of cleanup and baseline optimization tasks.
- Optimal applies a balanced collection of debloat, cleaning, OneDrive removal, system optimization, privacy hardening, and Microsoft account prompt suppression tasks.
- Aggressive extends the Optimal set with additional repair operations and enables deeper policy changes, including optional Windows AI feature disablement.
- Fix selects a comprehensive set of repair and health restoration tasks, including DISM, SFC, disk checks, Defender remediation, and troubleshooting routines, combined with core optimization and privacy steps.

Presets may be used as starting points. The checklist remains fully editable after a preset is applied.

## Operation modes

The mode selector determines how selected tasks are executed.

In Apply mode, checked tasks perform their forward operations. These include application removal, service and registry changes for performance and privacy, file cleaning, and repair actions.

In Revert mode, the same task entries in the checklist cause execution of the corresponding Revert-*.ps1 scripts. Tasks that lack a dedicated revert implementation fall back to a generic no-op script that reports the limitation. When Revert mode is activated, the checklist is automatically adjusted to prioritize tasks that have explicit reversal support. After execution completes, the selector returns to the interface so additional operations can be performed.

## Task execution

When execution is started, a modal progress dialog appears. The dialog displays the current task name, a progress bar, and status text. Tasks execute sequentially.

Some tasks run as inline script blocks that directly update the progress dialog. Most tasks launch their associated script file (or the Revert variant) in a separate PowerShell process. Child processes are started with the arguments `-NoProfile -ExecutionPolicy Bypass -File <script> --automated`. Output from child processes appears in the console window from which the tool was launched. When the batch completes, the progress dialog closes and the selector reappears.

## Privacy hardening

The Windows Privacy task applies registry policies under both HKLM and HKCU paths to restrict telemetry, advertising information, background app access, search web integration, and tailored experiences. It disables or stops diagnostic and consumer-experience services and disables scheduled tasks associated with the Application Experience and Customer Experience Improvement Program.

The task also suppresses multiple notification, Start menu recommendation, lock screen, and File Explorer surfaces that display suggestions or upsell prompts. In addition, it adds entries to the system hosts file for known Microsoft telemetry and feedback domains and creates outbound Windows Firewall rules that block TCP 443 traffic to the IP addresses resolved for those domains at the time of application. These network-level blocks are intended to prevent diagnostic and feedback data from leaving the system even when the Windows Diagnostics & feedback setting is configured for the Required (basic) level.

## Other task categories

Additional tasks address application and OneDrive removal, temporary file and profile cache cleaning, power plan and memory management tuning, non-essential service reduction, visual effects and theme changes, DISM component store repair, System File Checker scans, disk error checking and repair, and defragmentation for mechanical drives. Defender remediation and general troubleshooting routines are also available. Several of these tasks have matching Revert scripts that restore default service startup types, registry values, and scheduled task states where reversal is supported.

## Reverting changes

Revert support is provided for many operations through dedicated Revert-*.ps1 scripts. These scripts attempt to restore default Windows behavior for services, scheduled tasks, registry policies, and other settings modified by the forward tasks. Reversion is not guaranteed for all actions, particularly one-way cleanup or repair operations. Users should review task descriptions in the detail panel before running revert operations.

## Technical notes

The tool maintains no persistent configuration between runs beyond the actual changes written to the system. Re-executing the same preset reapplies the same set of changes. The selector always initializes with a default preset that can be changed by the user or overridden by Revert mode logic.

The supporting scripts reside in the Scripts subdirectory. This directory contains both forward and revert implementations, utility executables such as DelProf2.exe, and CustomChanges.ps1 as an extension point for site-specific additions. CustomChanges.ps1 is not included in the default presets.

The application targets Windows 10 and Windows 11. No compatibility is provided for earlier Windows releases. The interface assumes the presence of the Windows Forms assemblies and the PowerShell cmdlets for scheduled tasks and firewall management.

## License

This repository is licensed under the GPL-3.0 License as provided in the LICENSE file included with the project. 

## Credits

PowerShell documentation is available at https://learn.microsoft.com/powershell/. DelProf2 is provided by Helge Klein at https://helgeklein.com/free-tools/delprof2-user-profile-deletion-tool/.