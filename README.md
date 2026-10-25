# Windows Maintenance (PowerShell)

Windows Maintenance is a PowerShell graphical tool with one resizable Windows Forms window for maintenance, cleanup, optimisation, privacy hardening, and repair on Windows 10 and Windows 11. It initialises by detecting the Windows version and checking its script modules, then opens the task selector. System changes are meant to run with administrator rights.

## Prerequisites

The PC must be running Windows 10 or Windows 11. Administrator rights are required because the tasks change the registry, services, scheduled tasks, power settings, firewall rules, and DNS policy. PowerShell must be allowed to run scripts for the session. Windows Forms must be available, along with the scheduled task and Windows Firewall cmdlets used by the privacy and revert scripts.

Launch with `RunMaintenance.bat`. That file starts Windows PowerShell 5.1 elevated. You can also run `WindowsMaintenance.ps1` from an elevated PowerShell 5.1 console. If a session blocks scripts, use `Set-ExecutionPolicy Bypass -Scope Process` for that window only.

## The task selector

The selector is the main window. A header shows the title. Under it is the Apply / Revert switch, then the preset row, then the checklist.

- Apply runs the ticked tasks. Revert runs the matching undo scripts.
- Custom is selected when the window opens, and every task starts unticked.
- Minimal, Optimal, Aggressive, and Fix fill the checklist. You can still tick or untick any task afterwards.
- The list on the left scrolls. The panel on the right describes the selected task.
- Switching from Revert back to Apply returns the checklist to Custom, with nothing ticked.

## Presets

- **Custom** leaves every task unticked so you can build the run yourself.
- **Minimal** ticks System Cleaner, System Optimisation, Windows Privacy, and Disable MS Account Prompts.
- **Optimal** adds Windows Install Cleanup and Uninstall OneDrive to the Minimal set.
- **Aggressive** adds Disable Windows AI, DISM Health Check, System File Check, Disk Check and Repair, and Disk Defragmentation.
- **Fix** ticks DISM Health Check, System File Check, Disk Check and Repair, Fix Windows Defender, Windows Troubleshooting, System Optimisation, Windows Privacy, Disable MS Account Prompts, and Visual Optimisation.

The extra optimisation tasks below are on the list and stay unticked in every preset.

## Tasks

**Cleanup.** Windows Install Cleanup removes a balanced set of inbox apps and leaves the shell and Store usable. Reinstall Default Apps can put provisioned apps back. Uninstall OneDrive removes OneDrive sync. System Cleaner clears temporary files. User Profile Temp Cleaner and Delete Old User Profiles go further and are left unticked.

**System Optimisation.** This is the balanced performance bundle. It selects Ultimate Performance when this edition of Windows can create that plan, otherwise High Performance. It turns off power saving for attached network, USB, Bluetooth, audio, mouse, keyboard, and other HID devices, and it tunes USB, PCI Express, disk, processor, sleep, and wireless settings for performance on mains and on battery. Idle sleep, hibernate, and hybrid sleep are set to never. The display timeout is left as it is, and sleep can still be started from the Start menu. It also applies a desktop memory policy, trims idle background use, disables selected scheduled tasks and optional services, and lowers the RAM footprint. On an SSD or NVMe system disk it turns SysMain and prefetch off. A hard disk keeps them. Laptops use more battery. A mouse or keyboard may no longer wake the PC. Restart after this task.

**Separate optimisation tasks.** These call the same script one action at a time:

- Performance Optimisations
- RAM Footprint
- Deep RAM
- Gaming Performance
- Storage and File System
- Startup and Boot
- Task Scheduler Cleanup
- Additional Services
- Disable Background Apps
- Disable Optional Services
- Disable Telemetry Services
- UI and Notifications
- Privacy Hardening

Deep RAM turns off Hyper-V, Virtual Machine Platform, WSL, Windows Sandbox, and virtualisation-based security. It needs a restart. Leave it unticked unless those features are not required. Storage and File System removes the hibernation file. Additional Services can stop toasts, Windows Hello, nearby sharing, and the mobile hotspot until revert.

**Visual Optimisation** is its own task. It is not part of the System Optimisation bundle. Apply Aerolite Theme only launches the bundled theme file.

**Windows Privacy** sets telemetry, advertising, background-app, and suggestion policies, stops diagnostic services, and disables selected Customer Experience tasks. Telemetry domains are blocked with DNS policy (NRPT) and outbound firewall rules on TCP 443. The hosts file is not rewritten. If an older run left a marked telemetry block in the hosts file, the next privacy run removes that block once.

**Disable Windows AI** is its own task. It turns off Copilot, Recall, Click to Do, online speech, and cloud-assisted search by policy, and it disables Windows AI scheduled tasks that are present. It does not remove inbox apps, and it does not run as part of Windows Privacy or System Optimisation. Sign out afterwards.

**Disable MS Account Prompts** suppresses backup, Microsoft 365, and account upsell reminders for each loaded user. Backup and an existing Microsoft 365 subscription keep working.

**Repair.** DISM Health Check, System File Check, Disk Check and Repair, and Disk Defragmentation are for machines with faults or mechanical disks. Fix Windows Defender repairs protection when it has been left off or damaged. Windows Troubleshooting covers common network, update, and Store problems.

**Custom Changes Panel** opens the optional manual panel. It is not part of any preset.

## Running and reverting

Apply shows a progress window and runs the ticked tasks in order. Most tasks start a child PowerShell 5.1 process with `-NoProfile -ExecutionPolicy Bypass -File <script> --automated`. Output appears in the console that launched the tool. When the run finishes, the selector opens again.

Revert runs `Scripts\Revert-<TaskId>.ps1` when that file exists. One-way tasks use `Scripts\Revert-GenericNoOp.ps1`, which reports that there is nothing to undo. Revert mode ticks the tasks that have a real undo. Deep RAM uses `Scripts\Revert-OptDeepRAM.ps1`, which turns the virtualisation features back on. The other optimisation tasks share `Scripts\Revert-SystemOptimisation.ps1`, and that script runs once even if several of them are ticked. Restart after power, service, device, or Deep RAM changes.

## Technical notes

The tool does not store a configuration between runs. The changes that remain are the ones written to Windows. Running a preset again applies that preset's tasks again.

Scripts live in the `Scripts` folder, including forward scripts, revert scripts, `DelProf2.exe`, and `CustomChanges.ps1`. The tool targets Windows 10 and Windows 11 only.

## Licence

This project is licensed under GPL-3.0. The licence text is in the `LICENSE` file.

## Credits

PowerShell documentation is at https://learn.microsoft.com/powershell/. DelProf2 is provided by Helge Klein at https://helgeklein.com/free-tools/delprof2-user-profile-deletion-tool/.
