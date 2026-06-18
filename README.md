# Remote Support Evidence Collector

A diagnostic PowerShell toolkit for L1/L2 remote support and ticket escalation.

It collects safe endpoint evidence into timestamped CSV, JSON, TXT, and HTML reports. It does not collect passwords, browser data, Wi-Fi keys, documents, or user personal files.

## Features

- System and OS summary
- Hardware and uptime details
- Disk capacity summary
- Network adapter and IP configuration export
- Installed application inventory
- Startup item inventory
- Key Windows service status
- Recent System and Application event log summary
- Local administrator membership summary
- Report folder with ticket-ready evidence

## How to run

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\Remote_Support_Evidence_Collector.ps1
```

Run with a custom output path:

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\Remote_Support_Evidence_Collector.ps1 -OutputPath C:\Temp\SupportEvidence
```

## Safety

This script is diagnostic-only. It is designed for helpdesk evidence collection and does not perform repairs or destructive actions.

## Suggested topics

```text
powershell
windows
helpdesk
it-support
remote-support
troubleshooting
sysadmin
endpoint-management
```
