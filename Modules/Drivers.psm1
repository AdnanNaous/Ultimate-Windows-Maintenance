<#
.SYNOPSIS
    Driver module for the Ultimate Windows Maintenance Toolkit.
    Refactored to manage CIM sessions strictly and execute faster WMI polling.
#>

Set-StrictMode -Version Latest

function Get-DriverStatus {
    [CmdletBinding()]
    param ()
    
    Invoke-SafeOperation -Description "Detecting Display Adapters and Drivers" -Operation {
        $cimSession = $null
        try {
            $cimSession = New-CimSession
            $videoControllers = Get-CimInstance -ClassName Win32_VideoController -CimSession $cimSession -ErrorAction SilentlyContinue
            
            $nvidiaFound = $false
            $amdFound = $false
            
            if ($videoControllers) {
                foreach ($vc in $videoControllers) {
                    if (-not [string]::IsNullOrWhiteSpace($vc.Name)) {
                        if ($vc.Name.Contains("NVIDIA", [System.StringComparison]::OrdinalIgnoreCase)) {
                            $nvidiaFound = $true
                            Write-Log "Detected NVIDIA GPU: $($vc.Name) [Driver: $($vc.DriverVersion)]" -Level Info
                        }
                        elseif ($vc.Name.Contains("AMD", [System.StringComparison]::OrdinalIgnoreCase)) {
                            $amdFound = $true
                            Write-Log "Detected AMD GPU: $($vc.Name) [Driver: $($vc.DriverVersion)]" -Level Info
                        }
                    }
                }
            }
            
            if (-not $nvidiaFound -and -not $amdFound) {
                Write-Log "No discrete NVIDIA or AMD adapters identified." -Level Warning
            }
        }
        finally {
            if ($cimSession) { Remove-CimSession $cimSession }
        }
    }
}

function Show-DriverUpdateInstructions {
    [CmdletBinding()]
    param ()
    
    Write-Log "Driver maintenance operates in Notify-Only mode to preserve system stability." -Level Info
    Write-Log "For NVIDIA: Recommend 'NVCleanstall' or Official Custom 'Clean Install' option." -Level Info
    Write-Log "For AMD: Recommend Adrenalin installer 'Factory Reset' option." -Level Info
}

Export-ModuleMember -Function Get-DriverStatus, Show-DriverUpdateInstructions
