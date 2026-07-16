<#
.SYNOPSIS
    Update module for the Ultimate Windows Maintenance Toolkit.
    Refactored to enforce timeouts and better module memory management.
#>

Set-StrictMode -Version Latest

function Update-Windows {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param ()
    
    if ($PSCmdlet.ShouldProcess("Local Computer", "Trigger Windows Updates")) {
        Invoke-SafeOperation -Description "Initiating Windows Update via USOClient" -Operation {
            Write-Log "Starting USOClient Update Scan..." -Level Info
            
            $wuauserv = [System.ServiceProcess.ServiceController]::new("wuauserv")
            try {
                if ($wuauserv.Status -eq [System.ServiceProcess.ServiceControllerStatus]::Stopped) {
                    $wuauserv.Start()
                    $wuauserv.WaitForStatus([System.ServiceProcess.ServiceControllerStatus]::Running, [System.TimeSpan]::FromSeconds(15))
                }
            } catch { }
            finally {
                $wuauserv.Dispose()
            }
            
            $pInfo = [System.Diagnostics.ProcessStartInfo]::new()
            $pInfo.FileName = "usoclient.exe"
            $pInfo.Arguments = "StartScan"
            $pInfo.UseShellExecute = $false
            $pInfo.CreateNoWindow = $true
            
            $process = [System.Diagnostics.Process]::Start($pInfo)
            $process.WaitForExit(60000) # 60s timeout for triggering the scan
            
            Write-Log "Windows Update scan triggered successfully." -Level Success
            if ($process -ne $null) { $process.Dispose() }
        }
    }
}

function Update-WingetPackages {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param ()
    
    if ($PSCmdlet.ShouldProcess("Local Computer", "Upgrade Winget Packages")) {
        Invoke-SafeOperation -Description "Upgrading Winget & Store Apps" -Operation {
            $wingetPath = (Get-Command "winget" -ErrorAction SilentlyContinue).Source
            if ([string]::IsNullOrWhiteSpace($wingetPath)) {
                Write-Log "Winget executable not found in PATH." -Level Warning
                return
            }

            Write-Log "Running winget package upgrade..." -Level Info
            
            $pInfo = [System.Diagnostics.ProcessStartInfo]::new()
            $pInfo.FileName = $wingetPath
            $pInfo.Arguments = "upgrade --all --include-unknown --accept-package-agreements --accept-source-agreements --silent"
            $pInfo.UseShellExecute = $false
            $pInfo.CreateNoWindow = $true
            
            $process = [System.Diagnostics.Process]::Start($pInfo)
            $process.WaitForExit(1800000) # 30 mins
            
            if (-not $process.HasExited) {
                $process.Kill()
                Write-Log "Winget upgrade timed out." -Level Error
            }
            elseif ($process.ExitCode -in @(0, 2316632065)) {
                Write-Log "Winget upgrade executed successfully." -Level Success
            } else {
                Write-Log "Winget upgrade completed with code $($process.ExitCode)." -Level Warning
            }
            $process.Dispose()
        }
    }
}

function Update-PSModules {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param ()
    
    if ($PSCmdlet.ShouldProcess("Local Computer", "Update PS Modules")) {
        Invoke-SafeOperation -Description "Updating PowerShell Modules" -Operation {
            Write-Log "Evaluating installed modules for updates..." -Level Info
            
            $modules = Get-InstalledModule -ErrorAction SilentlyContinue
            if ($null -ne $modules -and $modules.Count -gt 0) {
                foreach ($mod in $modules) {
                    Write-Log "Updating module: $($mod.Name) v$($mod.Version)" -Level Info
                    [void](Update-Module -Name $mod.Name -Force -AcceptLicense -ErrorAction SilentlyContinue)
                }
                Write-Log "PowerShell modules updated." -Level Success
            } else {
                Write-Log "No compatible PackageManagement modules found." -Level Info
            }
        }
    }
}

Export-ModuleMember -Function Update-Windows, Update-WingetPackages, Update-PSModules
