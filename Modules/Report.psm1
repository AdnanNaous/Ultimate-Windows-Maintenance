<#
.SYNOPSIS
    Report generation module for the Ultimate Windows Maintenance Toolkit.
    Refactored to enforce proper HTML encoding to prevent layout breakage.
#>

Set-StrictMode -Version Latest

function Export-MaintenanceReport {
    [CmdletBinding()]
    param ()
    
    Invoke-SafeOperation -Description "Compiling Execution Matrix Reports" -Operation {
        $timestamp = [System.DateTime]::Now.ToString("yyyyMMdd_HHmmss")
        $reportDir = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($PSScriptRoot, "..", "Reports"))
        if (-not [System.IO.Directory]::Exists($reportDir)) {
            [void][System.IO.Directory]::CreateDirectory($reportDir)
        }
        
        $baseName = "MaintenanceReport_$timestamp"
        $jsonPath = [System.IO.Path]::Combine($reportDir, "$baseName.json")
        $txtPath  = [System.IO.Path]::Combine($reportDir, "$baseName.txt")
        $htmlPath = [System.IO.Path]::Combine($reportDir, "$baseName.html")
        
        $runTimeStr = "Unknown"
        if ($Script:StartTime) {
            $runTime = [System.DateTime]::Now - $Script:StartTime
            $runTimeStr = "{0:00} min {1:00} sec" -f $runTime.Minutes, $runTime.Seconds
        }
        
        # We must clone the list to an array for safe iteration and serialization
        $reportDataArray = $Script:ReportData.ToArray()
        
        # 1. JSON
        $reportDataArray | ConvertTo-Json -Depth 3 | Out-File -FilePath $jsonPath -Encoding utf8
        Write-Log "JSON compiled: $jsonPath" -Level Info
        
        # 2. TXT
        $sb = [System.Text.StringBuilder]::new()
        [void]$sb.AppendLine("Ultimate Windows Maintenance Report")
        [void]$sb.AppendLine("Date: $([System.DateTime]::Now)")
        [void]$sb.AppendLine("Total Duration: $runTimeStr")
        [void]$sb.AppendLine((new-object string('=', 60)))
        foreach ($item in $reportDataArray) {
            [void]$sb.AppendLine("Operation : $($item.Operation)")
            [void]$sb.AppendLine("Status    : $($item.Status)")
            if (-not [string]::IsNullOrWhiteSpace($item.Details)) {
                [void]$sb.AppendLine("Details   : $($item.Details)")
            }
            [void]$sb.AppendLine((new-object string('-', 60)))
        }
        [System.IO.File]::WriteAllText($txtPath, $sb.ToString())
        Write-Log "TXT compiled: $txtPath" -Level Info
        
        # 3. HTML (using string replacement for basic sanitization)
        $htmlStyle = @"
<style>
    body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background-color: #f4f4f9; color: #333; margin: 20px; }
    h1 { color: #005a9e; border-bottom: 2px solid #005a9e; padding-bottom: 5px; }
    table { width: 100%; border-collapse: collapse; margin-top: 20px; box-shadow: 0 4px 6px rgba(0,0,0,0.1); background-color: #fff; }
    th, td { border: 1px solid #ddd; padding: 12px; text-align: left; }
    th { background-color: #005a9e; color: white; }
    tr:nth-child(even) { background-color: #f9f9f9; }
    .success { color: #107c10; font-weight: bold; }
    .error { color: #a80000; font-weight: bold; }
    .warning { color: #d83b01; font-weight: bold; }
</style>
"@
        
        $hSb = [System.Text.StringBuilder]::new()
        [void]$hSb.AppendLine("<!DOCTYPE html><html><head><title>UWM Report</title>$htmlStyle</head><body>")
        [void]$hSb.AppendLine("<h1>Ultimate Windows Maintenance</h1>")
        [void]$hSb.AppendLine("<p><strong>Date:</strong> $([System.DateTime]::Now)</p>")
        [void]$hSb.AppendLine("<p><strong>Total Duration:</strong> $runTimeStr</p>")
        
        [void]$hSb.AppendLine("<table><tr><th>Operation</th><th>Status</th><th>Details</th></tr>")
        foreach ($item in $reportDataArray) {
            $statusClass = if ($item.Status -eq 'Success') { 'success' } elseif ($item.Status -eq 'Error') { 'error' } else { 'warning' }
            
            # Basic HTML encoding
            $det = $item.Details -replace '&', '&amp;' -replace '<', '&lt;' -replace '>', '&gt;' -replace '"', '&quot;'
            $op = $item.Operation -replace '&', '&amp;' -replace '<', '&lt;' -replace '>', '&gt;' -replace '"', '&quot;'
            
            [void]$hSb.AppendLine("<tr>")
            [void]$hSb.AppendLine("<td>$op</td>")
            [void]$hSb.AppendLine("<td class='$statusClass'>$($item.Status)</td>")
            [void]$hSb.AppendLine("<td>$det</td>")
            [void]$hSb.AppendLine("</tr>")
        }
        [void]$hSb.AppendLine("</table></body></html>")
        
        [System.IO.File]::WriteAllText($htmlPath, $hSb.ToString())
        Write-Log "HTML compiled: $htmlPath" -Level Info
    }
}

Export-ModuleMember -Function Export-MaintenanceReport
