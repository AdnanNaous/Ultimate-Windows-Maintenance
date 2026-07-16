<#
.SYNOPSIS
    Main orchestrator script for the Ultimate Windows Maintenance Toolkit.
    Kernel-Level Refactored Release.
#>
#Requires -Version 7.0
#Requires -RunAsAdministrator

[CmdletBinding(SupportsShouldProcess=$true)]
param (
    [switch]$SkipRestorePoint
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$Script:StartTime = [System.DateTime]::Now

try {
    # Ensure strict workspace pathing
    $scriptDir = [System.IO.Path]::GetFullPath($PSScriptRoot)
    Set-Location -Path $scriptDir

    # Core Module Loading via strict .NET path resolution
    Write-Host "Initializing Kernel-Level Maintenance Framework..." -ForegroundColor Cyan
    $modulesDir = [System.IO.Path]::Combine($scriptDir, "Modules")
    
    if (-not [System.IO.Directory]::Exists($modulesDir)) {
        throw "Module namespace violation: '$modulesDir' not found."
    }
    
    $modules = [System.IO.Directory]::EnumerateFiles($modulesDir, "*.psm1")
    foreach ($mod in $modules) {
        Import-Module $mod -Force
    }

    # Strict Architecture Constraints
    if (-not (Test-IsAdmin)) { throw "Security Violation: Administrator ring required." }
    if (-not (Test-IsWindows11)) { throw "Platform Violation: Windows 11 target required." }

    # Configuration Binding
    $configPath = [System.IO.Path]::Combine($scriptDir, "Config.json")
    if (-not [System.IO.File]::Exists($configPath)) {
        throw "Configuration File Missing: $configPath"
    }
    
    # Use robust file stream reader for config parsing
    $configStream = [System.IO.StreamReader]::new($configPath)
    $configJson = $configStream.ReadToEnd()
    $configStream.Dispose()
    $config = $configJson | ConvertFrom-Json

    Write-Header -Title "Ultimate Windows 11 Maintenance Toolkit"
    Write-Log -Message "Execution Matrix started at $($Script:StartTime.ToString('O'))" -Level Info

    # System Restore Point Logic
    if ($config.Safety.CreateRestorePoint -and -not $SkipRestorePoint) {
        Write-Header -Title "System Safety Checkpoint"
        $rpCreated = Checkpoint-System
        if (-not $rpCreated) {
            Write-Log -Message "Proceeding without rollback checkpoint." -Level Warning
        }
    }

    # Task Execution Array Definition
    $maintenanceTasks = @(
        @{ Name = "Health & Diagnostics"; Action = {
            Write-Header -Title "Health & Diagnostics"
            Get-SystemHealth
            Test-DiskHealth
            Test-SystemMemory
            Analyze-EventLog
            Invoke-ChkdskScan
        }}
        @{ Name = "System Cleanup"; Action = {
            Write-Header -Title "System Cleanup"
            Clear-SystemCache -Config $config.Cleanup
            if ($config.Cleanup.EmptyRecycleBin) { Clear-RecycleBinSafely }
        }}
        @{ Name = "System Repair"; Action = {
            Write-Header -Title "System Repair"
            if ($config.Repair.RunSFC) { Repair-SystemFiles }
            if ($config.Repair.RunDISM) { Repair-WindowsImage }
            if ($config.Repair.OptimizeComponentStore) { Optimize-ComponentStore }
        }}
        @{ Name = "Updates & Packages"; Action = {
            Write-Header -Title "Updates & Packages"
            if ($config.Updates.WingetUpgrade) { Update-WingetPackages }
            if ($config.Updates.PowerShellModules) { Update-PSModules }
            if ($config.Updates.WindowsUpdate) { Update-Windows }
        }}
        @{ Name = "Drivers Detection"; Action = {
            Write-Header -Title "Drivers Detection"
            if ($config.Drivers.CheckUpdates) { 
                Get-DriverStatus 
                Show-DriverUpdateInstructions
            }
        }}
        @{ Name = "Security Operations"; Action = {
            Write-Header -Title "Security Operations"
            if ($config.Security.UpdateDefender) { Update-DefenderSignatures }
            Start-SecurityScan -Config $config.Security
            Get-SecurityThreats
        }}
        @{ Name = "G-Helper Backup"; Action = {
            Write-Header -Title "G-Helper Management"
            Get-GHelperStatus
            if ($config.GHelper.BackupConfig) { Backup-GHelperConfig }
        }}
        @{ Name = "Post-Maintenance Restart"; Action = {
            if ($config.Repair.RestartExplorer) { Restart-Explorer }
        }}
    )

    $totalTasks = $maintenanceTasks.Count
    $currentTaskIndex = 0

    foreach ($task in $maintenanceTasks) {
        $currentTaskIndex++
        $percentComplete = [math]::Round(($currentTaskIndex / $totalTasks) * 100)
        
        $elapsed = [System.DateTime]::Now - $Script:StartTime
        $avgTimePerTask = $elapsed.TotalSeconds / $currentTaskIndex
        $remainingTasks = $totalTasks - $currentTaskIndex
        $estimatedRemainingSeconds = [int][math]::Round($avgTimePerTask * $remainingTasks)
        
        Write-Progress -Activity "Executing Windows Maintenance" -Status "Running: $($task.Name) ($currentTaskIndex of $totalTasks)" -PercentComplete $percentComplete -SecondsRemaining $estimatedRemainingSeconds
        
        # Execute mapped block
        & $task.Action
    }

    Write-Progress -Activity "Executing Windows Maintenance" -Completed

    Write-Header -Title "Maintenance Execution Concluded"
    Export-MaintenanceReport

    Write-Log -Message "Matrix execution finished gracefully." -Level Success

    if ($config.Safety.ForceRebootCountdown) {
        Write-Host "`nSystem state requires reboot to flush memory pages." -ForegroundColor Yellow
        for ($i = 30; $i -gt 0; $i--) {
            Write-Host "`rRebooting in $i seconds... (Ctrl+C to abort)" -NoNewline -ForegroundColor Yellow
            [System.Threading.Thread]::Sleep(1000)
        }
        Write-Host ""
        Write-Log -Message "Issuing reboot command." -Level Info
        Restart-Computer -Force
    } else {
        Write-Log -Message "Reboot deferred by configuration." -Level Info
    }

} catch {
    Write-Host "FATAL KERNEL-LEVEL FAULT: $($_.Exception.Message)" -ForegroundColor Red
} finally {
    # Perform strict environment teardown
    [System.GC]::Collect()
}
