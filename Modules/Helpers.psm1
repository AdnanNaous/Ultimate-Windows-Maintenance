<#
.SYNOPSIS
    Core helper functions for the Ultimate Windows Maintenance Toolkit.
    Refactored for strict security, memory management, and robust error handling.
#>

Set-StrictMode -Version Latest

$Script:LogPath = [System.IO.Path]::Combine($PSScriptRoot, "..", "Logs", "Maintenance_$([System.DateTime]::Now.ToString('yyyyMMdd_HHmmss')).log")
$Script:ReportData = [System.Collections.Generic.List[PSCustomObject]]::new()

# Create log directory if it doesn't exist
$logDir = [System.IO.Path]::GetDirectoryName($Script:LogPath)
if (-not [System.IO.Directory]::Exists($logDir)) {
    [void][System.IO.Directory]::CreateDirectory($logDir)
}

function Write-Log {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Message,
        
        [Parameter(Mandatory = $false)]
        [ValidateSet('Info', 'Warning', 'Error', 'Success')]
        [string]$Level = 'Info',
        
        [Parameter(Mandatory = $false)]
        [switch]$NoConsole
    )

    $timestamp = [System.DateTime]::Now.ToString('yyyy-MM-dd HH:mm:ss')
    $logEntry = "[$timestamp] [$Level] $Message"

    try {
        # Robust file writing avoiding pipeline overhead and handling locks
        $stream = [System.IO.File]::AppendText($Script:LogPath)
        $stream.WriteLine($logEntry)
        $stream.Dispose()
    }
    catch {
        # Fallback to Out-File if Stream throws, though Stream is generally more robust
        $logEntry | Out-File -FilePath $Script:LogPath -Append -Encoding utf8 -ErrorAction SilentlyContinue
    }

    if (-not $NoConsole) {
        $color = switch ($Level) {
            'Info' { [System.ConsoleColor]::Cyan }
            'Warning' { [System.ConsoleColor]::Yellow }
            'Error' { [System.ConsoleColor]::Red }
            'Success' { [System.ConsoleColor]::Green }
        }
        Write-Host "[$timestamp] " -NoNewline -ForegroundColor DarkGray
        Write-Host "[$Level] " -NoNewline -ForegroundColor $color
        Write-Host $Message
    }
}

function Write-Header {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Title
    )
    $line = new-object string('=', 60)
    Write-Host "`n$line" -ForegroundColor Magenta
    Write-Host "  $Title" -ForegroundColor White
    Write-Host $line -ForegroundColor Magenta
    Write-Log -Message "--- SECTION: $Title ---" -NoConsole
}

function Test-IsAdmin {
    [CmdletBinding()]
    param ()
    try {
        $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = [Security.Principal.WindowsPrincipal]::new($identity)
        $isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
        
        if (-not $isAdmin) {
            Write-Log -Message "Administrator privileges are strictly required." -Level Error
        }
        return $isAdmin
    }
    finally {
        if ($identity -ne $null) { $identity.Dispose() }
    }
}

function Test-IsWindows11 {
    [CmdletBinding()]
    param ()
    
    $cimSession = $null
    try {
        $cimSession = New-CimSession
        $os = Get-CimInstance -ClassName Win32_OperatingSystem -CimSession $cimSession -ErrorAction Stop
        $isWin11 = [version]$os.Version -ge [version]'10.0.22000'
        
        if (-not $isWin11) {
            Write-Log -Message "This toolkit requires Windows 11 kernel architecture." -Level Error
        }
        return $isWin11
    }
    catch {
        Write-Log -Message "Failed to verify OS version: $($_.Exception.Message)" -Level Error
        return $false
    }
    finally {
        if ($cimSession) { Remove-CimSession $cimSession }
    }
}

function Checkpoint-System {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param ()
    
    if ($PSCmdlet.ShouldProcess("Local Computer", "Create System Restore Point")) {
        try {
            Write-Log -Message "Creating System Restore Point..." -Level Info
            [void](Enable-ComputerRestore -Drive "$env:SystemDrive\" -ErrorAction SilentlyContinue)
            Checkpoint-Computer -Description "UWT_$( [System.DateTime]::Now.ToString('yyyyMMdd') )" -RestorePointType "MODIFY_SETTINGS" -ErrorAction Stop
            Write-Log -Message "System Restore Point secured." -Level Success
            return $true
        }
        catch {
            Write-Log -Message "Restore Point creation failed: $($_.Exception.Message)" -Level Warning
            return $false
        }
    }
}

function Invoke-SafeOperation {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [scriptblock]$Operation,
        
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Description
    )
    
    Write-Log -Message "Executing: $Description" -Level Info
    try {
        $localErrorAction = $ErrorActionPreference
        $ErrorActionPreference = 'Stop'
        
        [void](& $Operation)
        
        Write-Log -Message "Completed: $Description" -Level Success
        $Script:ReportData.Add([PSCustomObject]@{
            Operation = $Description
            Status = 'Success'
            Details = ''
        })
    }
    catch {
        Write-Log -Message "Exception in '$Description': $($_.Exception.Message)" -Level Error
        $Script:ReportData.Add([PSCustomObject]@{
            Operation = $Description
            Status = 'Error'
            Details = $_.Exception.Message
        })
    }
    finally {
        $ErrorActionPreference = $localErrorAction
    }
}

Export-ModuleMember -Function Write-Log, Write-Header, Test-IsAdmin, Test-IsWindows11, Checkpoint-System, Invoke-SafeOperation -Variable ReportData, LogPath
