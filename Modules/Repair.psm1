<#
.SYNOPSIS
    Repair module for the Ultimate Windows Maintenance Toolkit.
    Refactored to implement process timeouts and resilient UI restarts.
#>

Set-StrictMode -Version Latest

function Repair-WindowsImage {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param ()
    
    if ($PSCmdlet.ShouldProcess("Local Computer", "Run DISM RestoreHealth")) {
        Invoke-SafeOperation -Description "Running DISM RestoreHealth" -Operation {
            Write-Log "Initializing DISM /Online /Cleanup-Image /RestoreHealth..." -Level Info
            
            $pInfo = [System.Diagnostics.ProcessStartInfo]::new()
            $pInfo.FileName = "dism.exe"
            $pInfo.Arguments = "/Online /Cleanup-Image /RestoreHealth"
            $pInfo.UseShellExecute = $false
            $pInfo.CreateNoWindow = $true
            
            $process = [System.Diagnostics.Process]::Start($pInfo)
            $process.WaitForExit(3600000) # 1 hour timeout
            
            if (-not $process.HasExited) {
                $process.Kill()
                Write-Log "DISM process timed out after 1 hour." -Level Error
            }
            elseif ($process.ExitCode -eq 0) {
                Write-Log "DISM RestoreHealth completed cleanly." -Level Success
            } else {
                Write-Log "DISM RestoreHealth exit code $($process.ExitCode)." -Level Warning
            }
            $process.Dispose()
        }
    }
}

function Repair-SystemFiles {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param ()
    
    if ($PSCmdlet.ShouldProcess("Local Computer", "Run SFC ScanNow")) {
        Invoke-SafeOperation -Description "Running SFC ScanNow" -Operation {
            Write-Log "Initializing SFC /scannow..." -Level Info
            
            $pInfo = [System.Diagnostics.ProcessStartInfo]::new()
            $pInfo.FileName = "sfc.exe"
            $pInfo.Arguments = "/scannow"
            $pInfo.UseShellExecute = $false
            $pInfo.CreateNoWindow = $true
            
            $process = [System.Diagnostics.Process]::Start($pInfo)
            $process.WaitForExit(3600000) # 1 hour timeout
            
            if (-not $process.HasExited) {
                $process.Kill()
                Write-Log "SFC process timed out after 1 hour." -Level Error
            }
            elseif ($process.ExitCode -eq 0) {
                Write-Log "SFC ScanNow found zero integrity violations." -Level Success
            } else {
                Write-Log "SFC ScanNow exit code $($process.ExitCode). Manual log review may be required." -Level Warning
            }
            $process.Dispose()
        }
    }
}

function Optimize-ComponentStore {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param ()
    
    if ($PSCmdlet.ShouldProcess("Local Computer", "Optimize WinSxS")) {
        Invoke-SafeOperation -Description "Optimizing Component Store" -Operation {
            Write-Log "Initializing DISM Component Cleanup..." -Level Info
            
            $pInfo = [System.Diagnostics.ProcessStartInfo]::new()
            $pInfo.FileName = "dism.exe"
            $pInfo.Arguments = "/Online /Cleanup-Image /StartComponentCleanup"
            $pInfo.UseShellExecute = $false
            $pInfo.CreateNoWindow = $true
            
            $process = [System.Diagnostics.Process]::Start($pInfo)
            $process.WaitForExit(1800000) # 30 min timeout
            
            if (-not $process.HasExited) {
                $process.Kill()
                Write-Log "DISM Component Cleanup timed out." -Level Error
            }
            elseif ($process.ExitCode -eq 0) {
                Write-Log "Component Store optimized." -Level Success
            } else {
                Write-Log "Component Store cleanup exit code $($process.ExitCode)." -Level Warning
            }
            $process.Dispose()
        }
    }
}

function Restart-Explorer {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param ()
    
    if ($PSCmdlet.ShouldProcess("Local Computer", "Restart Explorer")) {
        Invoke-SafeOperation -Description "Restarting Windows UI (Explorer)" -Operation {
            Write-Log "Gracefully restarting Windows Explorer..." -Level Info
            
            # Request graceful exit using COM shell to prevent data loss in open windows
            $shell = [System.Activator]::CreateInstance([System.Type]::GetTypeFromProgID("Shell.Application"))
            try {
                $shell.TrayProperties() # Triggers the UI to wake up if suspended
                [void]$shell.ShutdownWindows() # This is just a prep step, we still need to kill process safely
            } catch {}
            finally {
                [System.Runtime.InteropServices.Marshal]::ReleaseComObject($shell) | Out-Null
            }
            
            $explorers = [System.Diagnostics.Process]::GetProcessesByName("explorer")
            foreach ($exp in $explorers) {
                try {
                    if (-not $exp.CloseMainWindow()) {
                        $exp.Kill()
                    }
                    $exp.WaitForExit(5000)
                } catch {}
                finally {
                    $exp.Dispose()
                }
            }
            
            [System.Threading.Thread]::Sleep(1000)
            [void][System.Diagnostics.Process]::Start("explorer.exe")
            Write-Log "Explorer successfully restarted." -Level Success
        }
    }
}

Export-ModuleMember -Function Repair-WindowsImage, Repair-SystemFiles, Optimize-ComponentStore, Restart-Explorer
