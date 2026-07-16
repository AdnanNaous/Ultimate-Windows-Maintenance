<#
.SYNOPSIS
    G-Helper module for the Ultimate Windows Maintenance Toolkit.
    Refactored to handle direct file streams and prevent process handle locks.
#>

Set-StrictMode -Version Latest

function Get-GHelperStatus {
    [CmdletBinding()]
    param ()
    
    Invoke-SafeOperation -Description "Auditing System Power Profiles" -Operation {
        $gProcesses = [System.Diagnostics.Process]::GetProcessesByName("GHelper")
        if ($gProcesses -and $gProcesses.Count -gt 0) {
            Write-Log "G-Helper active [PID: $($gProcesses[0].Id)]" -Level Info
            foreach ($p in $gProcesses) { $p.Dispose() }
        } else {
            Write-Log "G-Helper background service not found." -Level Warning
        }
        
        $mProcesses = [System.Diagnostics.Process]::GetProcessesByName("MyASUS")
        if ($mProcesses -and $mProcesses.Count -gt 0) {
            Write-Log "Conflict Warning: MyASUS running simultaneously with G-Helper." -Level Warning
            foreach ($p in $mProcesses) { $p.Dispose() }
        }
    }
}

function Backup-GHelperConfig {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param ()
    
    if ($PSCmdlet.ShouldProcess("Local Computer", "Backup G-Helper Configurations")) {
        Invoke-SafeOperation -Description "Securing G-Helper Settings" -Operation {
            $gData = [System.IO.Path]::Combine($env:APPDATA, "GHelper")
            
            if ([System.IO.Directory]::Exists($gData)) {
                $bDir = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($PSScriptRoot, "..", "Logs", "GHelper_Backups"))
                if (-not [System.IO.Directory]::Exists($bDir)) {
                    [void][System.IO.Directory]::CreateDirectory($bDir)
                }
                
                $tStamp = [System.DateTime]::Now.ToString("yyyyMMdd_HHmmss")
                $bFile = [System.IO.Path]::Combine($bDir, "GHelper_Config_$tStamp.zip")
                
                # Robust archive execution via Compress-Archive, wrapping in try/catch to handle locked config files
                try {
                    Compress-Archive -Path "$gData\*" -DestinationPath $bFile -Force -ErrorAction Stop
                    Write-Log "Configuration securely archived to $bFile" -Level Success
                } catch {
                    Write-Log "Failed to archive G-Helper data (Files may be in use): $($_.Exception.Message)" -Level Warning
                }
                
                $cFile = [System.IO.Path]::Combine($gData, "config.json")
                if ([System.IO.File]::Exists($cFile)) {
                    try {
                        # Fast stream reader for config parsing
                        $stream = [System.IO.StreamReader]::new($cFile)
                        $jsonRaw = $stream.ReadToEnd()
                        $stream.Dispose()
                        
                        $json = $jsonRaw | ConvertFrom-Json
                        if ($null -ne $json -and $null -ne $json.mode) {
                            Write-Log "Current Performance Mode ID: $($json.mode)" -Level Info
                        }
                    } catch {
                        Write-Log "Config format analysis failed (Non-fatal)." -Level Warning
                    }
                }
            } else {
                Write-Log "G-Helper AppData namespace absent." -Level Warning
            }
        }
    }
}

Export-ModuleMember -Function Get-GHelperStatus, Backup-GHelperConfig
