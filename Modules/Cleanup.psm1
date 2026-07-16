<#
.SYNOPSIS
    Cleanup module for the Ultimate Windows Maintenance Toolkit.
    Refactored to strictly avoid arbitrary file deletion and handle locked files without throwing.
#>

Set-StrictMode -Version Latest

# Robust deletion logic to bypass 'File In Use' terminal errors
function Remove-LockedItem {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Path
    )
    
    if (-not [System.IO.Directory]::Exists($Path)) { return }
    
    if ($PSCmdlet.ShouldProcess($Path, "Delete contents resiliently")) {
        try {
            $files = [System.IO.Directory]::EnumerateFiles($Path, "*.*", [System.IO.SearchOption]::AllDirectories)
            foreach ($file in $files) {
                try {
                    [System.IO.File]::SetAttributes($file, [System.IO.FileAttributes]::Normal)
                    [System.IO.File]::Delete($file)
                } catch [System.IO.IOException], [System.UnauthorizedAccessException] {
                    # Silently skip locked/protected files
                }
            }
            
            # Attempt to clean empty directories, from deepest to shallowest
            $dirs = [System.IO.Directory]::EnumerateDirectories($Path, "*", [System.IO.SearchOption]::AllDirectories) | Sort-Object Length -Descending
            foreach ($dir in $dirs) {
                try {
                    [System.IO.Directory]::Delete($dir)
                } catch {
                    # Silently skip non-empty or locked directories
                }
            }
        } catch {
            # Catches traversal errors, ignore to keep running
        }
    }
}

function Clear-SystemCache {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param (
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$Config
    )
    
    if ($Config.ClearWindowsTemp) {
        Invoke-SafeOperation -Description "Purging Windows Temp" -Operation {
            Remove-LockedItem -Path "$env:WINDIR\Temp"
            Write-Log "Windows Temp directory purged." -Level Info
        }
    }
    
    if ($Config.ClearUserTemp) {
        Invoke-SafeOperation -Description "Purging User Temp" -Operation {
            Remove-LockedItem -Path "$env:TEMP"
            Write-Log "User Temp directory purged." -Level Info
        }
    }
    
    if ($Config.ClearPrefetch) {
        Invoke-SafeOperation -Description "Purging Prefetch" -Operation {
            Remove-LockedItem -Path "$env:WINDIR\Prefetch"
            Write-Log "Prefetch directory purged." -Level Info
        }
    }
    
    if ($Config.ClearDirectXCache) {
        Invoke-SafeOperation -Description "Purging DirectX Shader Caches" -Operation {
            $dxCaches = @(
                "$env:LOCALAPPDATA\D3DSCache",
                "$env:LOCALAPPDATA\AMD\DxCache",
                "$env:LOCALAPPDATA\NVIDIA\DXCache"
            )
            foreach ($cache in $dxCaches) {
                Remove-LockedItem -Path $cache
            }
            Write-Log "DirectX shader caches purged." -Level Info
        }
    }

    if ($Config.ClearDeliveryOptimization) {
        Invoke-SafeOperation -Description "Purging Delivery Optimization Cache" -Operation {
            Remove-LockedItem -Path "$env:WINDIR\SoftwareDistribution\DeliveryOptimization"
            Write-Log "Delivery Optimization cache purged." -Level Info
        }
    }

    if ($Config.ClearWindowsUpdateCache) {
        Invoke-SafeOperation -Description "Purging Windows Update Cache" -Operation {
            # Safely stop services using .NET to ensure proper state management
            $wuauserv = [System.ServiceProcess.ServiceController]::new("wuauserv")
            $bits = [System.ServiceProcess.ServiceController]::new("bits")
            
            try {
                if ($wuauserv.Status -eq [System.ServiceProcess.ServiceControllerStatus]::Running) { $wuauserv.Stop(); $wuauserv.WaitForStatus([System.ServiceProcess.ServiceControllerStatus]::Stopped, [System.TimeSpan]::FromSeconds(15)) }
                if ($bits.Status -eq [System.ServiceProcess.ServiceControllerStatus]::Running) { $bits.Stop(); $bits.WaitForStatus([System.ServiceProcess.ServiceControllerStatus]::Stopped, [System.TimeSpan]::FromSeconds(15)) }
            } catch {
                # Ignore timeout exceptions
            }

            Remove-LockedItem -Path "$env:WINDIR\SoftwareDistribution\Download"
            Write-Log "Windows Update cache purged." -Level Info

            try {
                $wuauserv.Start()
                $bits.Start()
            } catch {}
            finally {
                $wuauserv.Dispose()
                $bits.Dispose()
            }
        }
    }
}

function Clear-RecycleBinSafely {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param ()
    
    Invoke-SafeOperation -Description "Emptying Recycle Bin" -Operation {
        if ($PSCmdlet.ShouldProcess("All Drives", "Empty Recycle Bin")) {
            # Uses COM to empty bin across all drives silently
            $shell = [System.Activator]::CreateInstance([System.Type]::GetTypeFromProgID("Shell.Application"))
            [void]$shell.NameSpace(0xA).Items().InvokeVerb("empty")
            [System.Runtime.InteropServices.Marshal]::ReleaseComObject($shell) | Out-Null
            Write-Log "Recycle bin emptied safely." -Level Info
        }
    }
}

Export-ModuleMember -Function Clear-SystemCache, Clear-RecycleBinSafely
