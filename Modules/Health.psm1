<#
.SYNOPSIS
    Health and diagnostics module for the Ultimate Windows Maintenance Toolkit.
    Refactored to minimize pipeline overhead and explicitly manage CIM sessions.
#>

Set-StrictMode -Version Latest

function Get-SystemHealth {
    [CmdletBinding()]
    param ()
    
    Invoke-SafeOperation -Description "Gathering System Health Information" -Operation {
        $cimSession = $null
        try {
            $cimSession = New-CimSession
            $os = Get-CimInstance -ClassName Win32_OperatingSystem -CimSession $cimSession
            Write-Log "OS: $($os.Caption) [Build $($os.Version)]" -Level Info
            
            $cpu = Get-CimInstance -ClassName Win32_Processor -CimSession $cimSession
            Write-Log "CPU: $($cpu.Name)" -Level Info
            
            # Using .NET class for faster service enumeration
            $services = [System.ServiceProcess.ServiceController]::GetServices()
            $runningCount = ($services.Where({$_.Status -eq [System.ServiceProcess.ServiceControllerStatus]::Running})).Count
            Write-Log "Services: $runningCount running / $($services.Count) total" -Level Info
            
            $startupApps = Get-CimInstance -ClassName Win32_StartupCommand -CimSession $cimSession
            Write-Log "Startup Apps: $($startupApps.Count)" -Level Info
        }
        finally {
            if ($cimSession) { Remove-CimSession $cimSession }
        }
    }
}

function Test-DiskHealth {
    [CmdletBinding()]
    param ()
    
    Invoke-SafeOperation -Description "Evaluating Disk Health & Capacity" -Operation {
        $cimSession = $null
        try {
            $cimSession = New-CimSession
            
            # Use Storage API for physical disks
            $disks = Get-CimInstance -Namespace "Root\Microsoft\Windows\Storage" -ClassName MSFT_PhysicalDisk -CimSession $cimSession -ErrorAction SilentlyContinue
            foreach ($disk in $disks) {
                # 0=Healthy, 1=Warning, 2=Unhealthy
                $healthStatus = switch ($disk.HealthStatus) {
                    0 { 'Healthy' }
                    1 { 'Warning' }
                    2 { 'Unhealthy' }
                    default { 'Unknown' }
                }
                
                if ($healthStatus -ne 'Healthy') {
                    Write-Log "Disk $($disk.DeviceId) [$($disk.FriendlyName)] Health: $healthStatus" -Level Warning
                } else {
                    Write-Log "Disk $($disk.DeviceId) [$($disk.FriendlyName)] Health: Healthy." -Level Info
                }
            }
            
            $sysDrive = "$env:SystemDrive"
            $cDrive = Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DeviceID='$sysDrive'" -CimSession $cimSession
            if ($cDrive) {
                $freeSpaceGB = [math]::Round($cDrive.FreeSpace / 1GB, 2)
                $totalSpaceGB = [math]::Round($cDrive.Size / 1GB, 2)
                $percentFree = [math]::Round(($cDrive.FreeSpace / $cDrive.Size) * 100, 2)
                
                Write-Log "Drive $sysDrive Space: ${freeSpaceGB}GB free of ${totalSpaceGB}GB (${percentFree}%)" -Level Info
                if ($percentFree -lt 15) {
                    Write-Log "Drive $sysDrive is critically low on space (<15%)." -Level Warning
                }
            }
        }
        finally {
            if ($cimSession) { Remove-CimSession $cimSession }
        }
    }
}

function Test-SystemMemory {
    [CmdletBinding()]
    param ()
    
    Invoke-SafeOperation -Description "Evaluating System Memory" -Operation {
        $cimSession = $null
        try {
            # Direct event log querying using robust filtering
            $query = @"
<QueryList>
  <Query Id="0" Path="System">
    <Select Path="System">*[System[Provider[@Name='Microsoft-Windows-MemoryDiagnostics-Results'] and (EventID=1101 or EventID=1201)]]</Select>
  </Query>
</QueryList>
"@
            $memEvents = Get-WinEvent -FilterXml $query -MaxEvents 1 -ErrorAction SilentlyContinue
            if ($memEvents) {
                Write-Log "Latest Memory Diagnostic: $($memEvents[0].Message)" -Level Info
            } else {
                Write-Log "No Windows Memory Diagnostic reports found." -Level Info
            }
            
            $cimSession = New-CimSession
            $ram = Get-CimInstance -ClassName Win32_ComputerSystem -CimSession $cimSession
            $totalRAM = [math]::Round($ram.TotalPhysicalMemory / 1GB, 2)
            Write-Log "Physical Memory: ${totalRAM}GB" -Level Info
        }
        finally {
            if ($cimSession) { Remove-CimSession $cimSession }
        }
    }
}

function Analyze-EventLog {
    [CmdletBinding()]
    param ()
    
    Invoke-SafeOperation -Description "Scanning Event Logs for Critical Faults" -Operation {
        # Using FilterHashtable for performant log extraction
        $criticalEvents = Get-WinEvent -FilterHashtable @{LogName='System'; Level=1,2; StartTime=[System.DateTime]::Now.AddDays(-7)} -ErrorAction SilentlyContinue
        if ($criticalEvents -and $criticalEvents.Count -gt 0) {
            Write-Log "Found $($criticalEvents.Count) Critical/Error events in System log over 7 days." -Level Warning
        } else {
            Write-Log "No Critical/Error events found in System log recently." -Level Success
        }
    }
}

function Invoke-ChkdskScan {
    [CmdletBinding()]
    param ()
    
    Invoke-SafeOperation -Description "Running Non-Destructive File System Check" -Operation {
        Write-Log "Executing read-only CHKDSK on $env:SystemDrive..." -Level Info
        
        $processStartInfo = [System.Diagnostics.ProcessStartInfo]::new()
        $processStartInfo.FileName = "chkdsk.exe"
        $processStartInfo.Arguments = "$env:SystemDrive"
        $processStartInfo.UseShellExecute = $false
        $processStartInfo.CreateNoWindow = $true
        
        $process = [System.Diagnostics.Process]::Start($processStartInfo)
        $process.WaitForExit(300000) # 5-minute timeout
        
        if (-not $process.HasExited) {
            $process.Kill()
            Write-Log "CHKDSK scan timed out after 5 minutes." -Level Warning
        }
        elseif ($process.ExitCode -eq 0) {
            Write-Log "CHKDSK completed cleanly." -Level Success
        } else {
            Write-Log "CHKDSK exit code $($process.ExitCode): File system anomalies detected." -Level Warning
        }
        $process.Dispose()
    }
}

Export-ModuleMember -Function Get-SystemHealth, Test-DiskHealth, Test-SystemMemory, Analyze-EventLog, Invoke-ChkdskScan
