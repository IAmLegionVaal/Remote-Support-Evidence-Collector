#requires -Version 5.1
<#
.SYNOPSIS
    Remote Support Evidence Collector.
.DESCRIPTION
    Diagnostic-only toolkit for collecting ticket-ready Windows endpoint evidence.
    It avoids passwords, browser data, Wi-Fi keys, documents, and personal files.
#>
[CmdletBinding()]
param([string]$OutputPath)

$RunStamp = Get-Date -Format 'yyyyMMdd_HHmmss'
if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    $OutputPath = Join-Path ([Environment]::GetFolderPath('Desktop')) 'Remote_Support_Evidence'
}
$ReportRoot = Join-Path $OutputPath "Evidence_$env:COMPUTERNAME`_$RunStamp"
New-Item -Path $ReportRoot -ItemType Directory -Force | Out-Null
$LogFile = Join-Path $ReportRoot 'collector.log'

function Write-Log {
    param([string]$Message)
    $line = '{0} {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Message
    Add-Content -Path $LogFile -Value $line -Encoding UTF8
    Write-Host $Message
}
function Export-Data {
    param([string]$Name,[object]$Data)
    $csv = Join-Path $ReportRoot "$Name.csv"
    $json = Join-Path $ReportRoot "$Name.json"
    $Data | Export-Csv -Path $csv -NoTypeInformation -Encoding UTF8
    $Data | ConvertTo-Json -Depth 6 | Set-Content -Path $json -Encoding UTF8
}

Write-Log 'Starting remote support evidence collection.'

try {
    $os = Get-CimInstance Win32_OperatingSystem
    $cs = Get-CimInstance Win32_ComputerSystem
    $bios = Get-CimInstance Win32_BIOS
    $summary = [PSCustomObject]@{
        ComputerName = $env:COMPUTERNAME
        UserName = "$env:USERDOMAIN\$env:USERNAME"
        OS = $os.Caption
        Version = $os.Version
        Build = $os.BuildNumber
        LastBoot = $os.LastBootUpTime
        Manufacturer = $cs.Manufacturer
        Model = $cs.Model
        MemoryGB = [math]::Round($cs.TotalPhysicalMemory / 1GB, 2)
        BiosVersion = $bios.SMBIOSBIOSVersion
        Generated = Get-Date
    }
    Export-Data -Name 'system_summary' -Data @($summary)
} catch { Write-Log "System summary failed: $($_.Exception.Message)" }

try { Export-Data -Name 'disk_summary' -Data (Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" | Select-Object DeviceID,VolumeName,Size,FreeSpace,FileSystem) } catch { Write-Log "Disk summary failed: $($_.Exception.Message)" }
try { Export-Data -Name 'network_adapters' -Data (Get-NetAdapter | Select-Object Name,Status,LinkSpeed,MacAddress,InterfaceDescription) } catch { Write-Log "Adapter export failed: $($_.Exception.Message)" }
try { Export-Data -Name 'ip_configuration' -Data (Get-NetIPConfiguration | Select-Object InterfaceAlias,InterfaceDescription,IPv4Address,IPv4DefaultGateway,DNSServer) } catch { Write-Log "IP config export failed: $($_.Exception.Message)" }
try { Export-Data -Name 'services_key' -Data (Get-Service | Where-Object {$_.Name -in @('wuauserv','BITS','Winmgmt','EventLog','Spooler','Dhcp','Dnscache')} | Select-Object Name,DisplayName,Status,StartType) } catch { Write-Log "Service export failed: $($_.Exception.Message)" }
try { Export-Data -Name 'startup_items' -Data (Get-CimInstance Win32_StartupCommand | Select-Object Name,Command,Location,User) } catch { Write-Log "Startup export failed: $($_.Exception.Message)" }
try {
    $apps = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*','HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*' -ErrorAction SilentlyContinue | Where-Object DisplayName | Select-Object DisplayName,DisplayVersion,Publisher,InstallDate
    Export-Data -Name 'installed_apps' -Data $apps
} catch { Write-Log "App inventory failed: $($_.Exception.Message)" }
try { Export-Data -Name 'local_admins' -Data (Get-LocalGroupMember -Group 'Administrators' | Select-Object Name,ObjectClass,PrincipalSource) } catch { Write-Log "Local admin export failed: $($_.Exception.Message)" }
try {
    $start = (Get-Date).AddHours(-24)
    Export-Data -Name 'recent_system_events' -Data (Get-WinEvent -FilterHashtable @{LogName='System';Level=1,2,3;StartTime=$start} -ErrorAction SilentlyContinue | Select-Object -First 100 TimeCreated,Id,ProviderName,LevelDisplayName,Message)
    Export-Data -Name 'recent_application_events' -Data (Get-WinEvent -FilterHashtable @{LogName='Application';Level=1,2,3;StartTime=$start} -ErrorAction SilentlyContinue | Select-Object -First 100 TimeCreated,Id,ProviderName,LevelDisplayName,Message)
} catch { Write-Log "Event export failed: $($_.Exception.Message)" }

$index = Get-ChildItem -Path $ReportRoot -File | Select-Object Name,Length,LastWriteTime
$index | ConvertTo-Html -Title 'Remote Support Evidence' -PreContent "<h1>Remote Support Evidence - $env:COMPUTERNAME</h1><p>Generated $(Get-Date)</p>" | Set-Content -Path (Join-Path $ReportRoot 'index.html') -Encoding UTF8
Write-Log "Evidence collection completed: $ReportRoot"
Start-Process explorer.exe -ArgumentList "`"$ReportRoot`"" -ErrorAction SilentlyContinue
