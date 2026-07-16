<#
.SYNOPSIS
    Security module for the Ultimate Windows Maintenance Toolkit.
    Refactored to eliminate pipeline performance hits and add strict parameter management.
#>

Set-StrictMode -Version Latest

function Update-DefenderSignatures {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param ()
    
    if ($PSCmdlet.ShouldProcess("Local Computer", "Update Microsoft Defender Signatures")) {
        Invoke-SafeOperation -Description "Updating Defender Signatures" -Operation {
            Write-Log "Initializing Microsoft Defender signature update..." -Level Info
            [void](Update-MpSignature -ErrorAction SilentlyContinue)
            Write-Log "Signatures successfully updated." -Level Success
        }
    }
}

function Start-SecurityScan {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param (
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$Config
    )
    
    if ($Config.RunFullScan -and $PSCmdlet.ShouldProcess("Local Computer", "Full Defender Scan")) {
        Invoke-SafeOperation -Description "Executing Full Defender Scan" -Operation {
            Write-Log "Initiating Full Scan (Background processing)..." -Level Info
            [void](Start-MpScan -ScanType FullScan -ErrorAction SilentlyContinue)
            Write-Log "Full Scan request completed." -Level Success
        }
    }
    elseif ($Config.RunQuickScan -and $PSCmdlet.ShouldProcess("Local Computer", "Quick Defender Scan")) {
        Invoke-SafeOperation -Description "Executing Quick Defender Scan" -Operation {
            Write-Log "Initiating Quick Scan..." -Level Info
            [void](Start-MpScan -ScanType QuickScan -ErrorAction SilentlyContinue)
            Write-Log "Quick Scan completed." -Level Success
        }
    }
}

function Get-SecurityThreats {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param ()
    
    if ($PSCmdlet.ShouldProcess("Local Computer", "Evaluate and Quarantine Threats")) {
        Invoke-SafeOperation -Description "Evaluating Security Threat Matrix" -Operation {
            $threats = Get-MpThreat -ErrorAction SilentlyContinue
            if ($null -ne $threats -and $threats.Count -gt 0) {
                Write-Log "Critical Warning: $($threats.Count) Threat(s) detected!" -Level Warning
                foreach ($threat in $threats) {
                    Write-Log "[$($threat.Severity)] $($threat.ThreatName)" -Level Warning
                }
                
                Write-Log "Enforcing automatic quarantine..." -Level Info
                [void](Remove-MpThreat -ErrorAction SilentlyContinue)
                Write-Log "Threats successfully quarantined." -Level Success
            } else {
                Write-Log "System reports zero active threats." -Level Success
            }
        }
    }
}

Export-ModuleMember -Function Update-DefenderSignatures, Start-SecurityScan, Get-SecurityThreats
