<# =====================================================================
 Rapid7 Insight Agent Deployment Script
 Fully self-contained, PowerShell 5.1 compatible

 Requirements:
 - Server list picker (txt)
 - MSI picker (any name, preserved)
 - Pre-checks with color output
 - Remote file copy with single-line progress
 - Remote installation with actual msiexec wait and exit code
 - Detailed log analysis
 - TXT + CSV logging
 - Failure classification
 - Single-threaded
 - Placeholder token only: YOUR_PLACEHOLDER_TOKEN_HERE
 ======================================================================#>

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# ---------------------------- GLOBAL VARIABLES -----------------------------
$Global:Results = @()
$Global:TxtLog = "C:\Temp\r7logs.txt"
$Global:CsvLog = "C:\Temp\r7logs.csv"

New-Item -ItemType Directory -Force -Path "C:\Temp" | Out-Null

# ---------------------------- COLOR OUTPUT HELPERS -------------------------
function Write-Green($msg){ Write-Host $msg -ForegroundColor Green }
function Write-Yellow($msg){ Write-Host $msg -ForegroundColor Yellow }
function Write-Red($msg){ Write-Host $msg -ForegroundColor Red }
function Write-Separator(){ Write-Host ("="*72) -ForegroundColor Cyan }

# ---------------------------- FILE PICKER -----------------------------------
function Show-FilePicker([string]$Title, [string]$Filter) {
    $dialog = New-Object System.Windows.Forms.OpenFileDialog
    $dialog.Title = $Title
    $dialog.Filter = $Filter

    if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        return $dialog.FileName
    }
    else {
        throw "File selection cancelled."
    }
}

# ---------------------------- PORT CHECK ------------------------------------
function Test-Ports($Server, $Port){
    try {
        $result = Test-NetConnection -ComputerName $Server -Port $Port -WarningAction SilentlyContinue
        return $result.TcpTestSucceeded
    }
    catch {
        return $false
    }
}

# ---------------------------- SERVER PRECHECKS ------------------------------
function Test-ServerConnectivity($Server) {

    $Ping = $false
    $WinRM = $false
    $SMB = $false
    $RPC = $false
    $CShare = $false
    $PSRemoting = $false

    Write-Separator
    Write-Host "[Pre-Checks] $Server" -ForegroundColor Cyan

    # Ping
    if (Test-Connection -ComputerName $Server -Count 1 -Quiet) {
        $Ping = $true
        Write-Green "Ping: OK"
    }
    else {
        Write-Red "Ping: FAILED"
    }

    # WinRM
    try {
        Test-WSMan $Server -ErrorAction Stop | Out-Null
        $WinRM = $true
        Write-Green "WinRM: OK"
    }
    catch {
        Write-Yellow "WinRM: FAILED"
    }

    # SMB 445
    if (Test-Ports $Server 445) {
        $SMB = $true
        Write-Green "SMB Port 445: OK"
    }
    else {
        Write-Yellow "SMB Port 445: BLOCKED"
    }

    # RPC 135
    if (Test-Ports $Server 135) {
        $RPC = $true
        Write-Green "RPC Port 135: OK"
    }
    else {
        Write-Yellow "RPC Port 135: BLOCKED"
    }

    # C$ Share
    try {
        if (Test-Path "\\$Server\C$") {
            $CShare = $true
            Write-Green "C$ Admin Share Access: OK"
        }
        else {
            Write-Yellow "C$ Access: FAILED"
        }
    }
    catch {
        Write-Yellow "C$ Access: FAILED"
    }

    # Remote PowerShell
    try {
        Invoke-Command -ComputerName $Server -ScriptBlock { "OK" } -ErrorAction Stop | Out-Null
        $PSRemoting = $true
        Write-Green "PowerShell Remoting: OK"
    }
    catch {
        Write-Yellow "PowerShell Remoting: FAILED"
    }

    return [PSCustomObject]@{
        Server      = $Server
        Ping        = $Ping
        SMB         = $SMB
        WinRM       = $WinRM
        RPC         = $RPC
        CShare      = $CShare
        PSRemoting  = $PSRemoting
    }
}

# ---------------------------- MSI COPY WITH SINGLE-LINE PROGRESS ------------
function Copy-MSIWithProgress($Server, $LocalFile, $RemoteFilePath){

    Write-Host "[Copy] $Server -> $RemoteFilePath" -ForegroundColor Cyan

    $sourceStream = $null
    $destStream = $null

    try {
        # Ensure remote directory exists
        Invoke-Command -ComputerName $Server -ScriptBlock {
            param($path)

            if (-not (Test-Path $path)) {
                New-Item -ItemType Directory -Force -Path $path | Out-Null
            }
        } -ArgumentList (Split-Path $RemoteFilePath) -ErrorAction Stop

        $uncPath = "\\$Server\" + $RemoteFilePath.Replace("C:\", "C$\")

        $sourceStream = [System.IO.File]::OpenRead($LocalFile)
        $destStream = [System.IO.File]::Open(
            $uncPath,
            [System.IO.FileMode]::Create,
            [System.IO.FileAccess]::Write
        )

        $buffer = New-Object byte[] (1024 * 1024)
        $totalBytes = $sourceStream.Length
        $bytesCopied = 0
        $lastPercent = -1

        while (($read = $sourceStream.Read($buffer, 0, $buffer.Length)) -gt 0) {
            $destStream.Write($buffer, 0, $read)
            $bytesCopied += $read

            $percent = [math]::Round(($bytesCopied / $totalBytes) * 100, 0)

            if ($percent -ne $lastPercent) {
                Write-Progress -Id 1 `
                    -Activity "Copying Rapid7 MSI to $Server" `
                    -Status "$percent% complete" `
                    -PercentComplete $percent

                $lastPercent = $percent
            }
        }

        Write-Progress -Id 1 -Activity "Copying Rapid7 MSI to $Server" -Completed
        Write-Green "[${Server}] MSI Copy Completed."

        return $true
    }
    catch {
        Write-Progress -Id 1 -Activity "Copying Rapid7 MSI to $Server" -Completed
        Write-Red "[${Server}] MSI Copy FAILED: $($_.Exception.Message)"
        return $false
    }
    finally {
        if ($sourceStream) { $sourceStream.Close() }
        if ($destStream) { $destStream.Close() }
    }
}

# ---------------------------- REMOTE INSTALL WITH REAL WAIT -----------------
function Invoke-RemoteInstall($Server, $RemoteMsiPath){

    Write-Host "[${Server}] Starting installation..." -ForegroundColor Cyan

    try {
        $job = Invoke-Command -ComputerName $Server -AsJob -ScriptBlock {
            param($RemoteMsiPath)

            $LogDir = "C:\Temp\Rapid7"
            $LogPath = "$LogDir\insight_agent_install_log.log"

            if (-not (Test-Path $LogDir)) {
                New-Item -ItemType Directory -Force -Path $LogDir | Out-Null
            }

            if (-not (Test-Path $RemoteMsiPath)) {
                return @{
                    Status   = "Failed"
                    ExitCode = 998
                    Failure  = "MSI file not found on remote server: $RemoteMsiPath"
                    LogPath  = $LogPath
                }
            }

            if (Test-Path $LogPath) {
                Remove-Item $LogPath -Force -ErrorAction SilentlyContinue
            }

            $Arguments = "/i `"$RemoteMsiPath`" /qn /norestart /L*v `"$LogPath`" CUSTOMATTRIBUTES=`"GTM-Win-servers`" CUSTOMTOKEN=`"us:1bbb6e7c-848d-4b30-88d3-c7844d5ede86`""


            $process = Start-Process -FilePath "msiexec.exe" `
                                     -ArgumentList $Arguments `
                                     -Wait `
                                     -PassThru `
                                     -WindowStyle Hidden

            $exitCode = $process.ExitCode

            if ($exitCode -eq 0 -or $exitCode -eq 3010) {
                $status = "Success"
                $failure = "None"
            }
            else {
                $status = "Failed"
                $failure = "MSI returned exit code $exitCode"
            }

            return @{
                Status    = $status
                ExitCode  = $exitCode
                Failure   = $failure
                LogPath   = $LogPath
                LogExists = Test-Path $LogPath
            }

        } -ArgumentList $RemoteMsiPath -ErrorAction Stop

        $progress = 0

        while ($job.State -eq "Running") {
            if ($progress -lt 95) {
                $progress += 5
            }

            Write-Progress -Id 2 `
                -Activity "Installing Rapid7 Agent on $Server" `
                -Status "Installation in progress..." `
                -PercentComplete $progress

            Start-Sleep -Seconds 3
        }

        Write-Progress -Id 2 -Activity "Installing Rapid7 Agent on $Server" -Completed

        $result = Receive-Job -Job $job -ErrorAction Stop
        Remove-Job -Job $job -Force -ErrorAction SilentlyContinue

        return $result
    }
    catch {
        Write-Progress -Id 2 -Activity "Installing Rapid7 Agent on $Server" -Completed
        Write-Red "[${Server}] Failed to run MSI installation: $($_.Exception.Message)"

        return @{
            Status   = "Failed"
            ExitCode = -1
            Failure  = $_.Exception.Message
        }
    }
}

# ---------------------------- MSI LOG ANALYSIS ------------------------------
function Analyze-MSIInstallLog($Server, $MSIExitCode){

    $LogPath = "\\$Server\C$\Temp\Rapid7\insight_agent_install_log.log"

    $FailureReason = "None"
    $InstallStatus = "Success"

    if (-not (Test-Path $LogPath)) {

        if ($MSIExitCode -eq 0 -or $MSIExitCode -eq 3010) {
            return @{
                Status   = "Success"
                ExitCode = $MSIExitCode
                Failure  = "None - MSI returned success but log file was not found"
            }
        }
        else {
            return @{
                Status   = "Failed"
                ExitCode = $MSIExitCode
                Failure  = "No log file found"
            }
        }
    }

    $log = Get-Content $LogPath -Raw

    if ($MSIExitCode -ne 0 -and $MSIExitCode -ne 3010) {
        $FailureReason = "MSI failed with exit code $MSIExitCode"
        $InstallStatus = "Failed"
    }
    elseif ($log -match "Error 1603") {
        $FailureReason = "MSI Fatal Error 1603"
        $InstallStatus = "Failed"
    }
    elseif ($log -match "Rolling back installation") {
        $FailureReason = "Rollback detected"
        $InstallStatus = "Failed"
    }
    elseif ($log -match "Token invalid") {
        $FailureReason = "Token failure"
        $InstallStatus = "Failed"
    }
    elseif ($log -match "Connectivity Result: FAIL") {
        $FailureReason = "Connectivity issue"
        $InstallStatus = "Failed"
    }
    elseif ($log -match "config.json doesn't exist") {
        $FailureReason = "config.json generation failure"
        $InstallStatus = "Failed"
    }

    return @{
        Status   = $InstallStatus
        ExitCode = $MSIExitCode
        Failure  = $FailureReason
    }
}

# ---------------------------- LOG WRITERS -----------------------------------
function Write-ResultsToTxt($Results){
    $Results | Format-List | Out-File -FilePath $Global:TxtLog -Force
}

function Write-ResultsToCsv($Results){
    $Results | Export-Csv -Path $Global:CsvLog -NoTypeInformation -Force
}

# ---------------------------- MAIN SCRIPT -----------------------------------
function Main {

    Write-Host ">>> Rapid7 Deployment Script Starting <<<" -ForegroundColor Cyan

    # Pick server list file
    $ServerListFile = Show-FilePicker "Select TXT file containing server names" "Text Files (*.txt)|*.txt"

    # Pick MSI file
    $MsiFile = Show-FilePicker "Select Rapid7 Agent MSI" "MSI (*.msi)|*.msi"

    $Servers = Get-Content $ServerListFile |
        ForEach-Object { $_.Trim() } |
        Where-Object { $_ -ne "" } |
        Sort-Object -Unique

    Write-Host "Loaded $($Servers.Count) servers."

    # ---------------- PRE-CHECKS ----------------
    foreach ($S in $Servers) {

        $chk = Test-ServerConnectivity $S

        $Global:Results += [PSCustomObject]@{
            Server        = $S
            Ping          = $chk.Ping
            SMB           = $chk.SMB
            WinRM         = $chk.WinRM
            CopyStatus    = "Pending"
            InstallStatus = "Pending"
            MSIExitCode   = ""
            FailureReason = ""
        }
    }

    Write-Host "`nPre-check complete." -ForegroundColor Cyan

    $answer = Read-Host "Continue with installation? (Y/N)"

    if ($answer -ne "Y") {
        Write-Red "Installation aborted."
        return
    }

    # ---------------- MSI COPY + INSTALL ----------------
    foreach ($entry in $Global:Results) {

        $server = $entry.Server
        Write-Separator

        # Skip if required connectivity is missing
        if (-not $entry.SMB) {
            $entry.CopyStatus = "Skipped"
            $entry.InstallStatus = "Skipped"
            $entry.FailureReason = "SMB unavailable"
            Write-Yellow "[${server}] Skipping because SMB is unavailable."
            continue
        }

        if (-not $entry.WinRM) {
            $entry.CopyStatus = "Skipped"
            $entry.InstallStatus = "Skipped"
            $entry.FailureReason = "WinRM unavailable"
            Write-Yellow "[${server}] Skipping because WinRM is unavailable."
            continue
        }

        # Define remote path based on preserved MSI filename
        $remotePath = "C:\Temp\Rapid7\" + (Split-Path $MsiFile -Leaf)

        # COPY
        $copyOK = Copy-MSIWithProgress $server $MsiFile $remotePath

        if (-not $copyOK) {
            $entry.CopyStatus = "Failed"
            $entry.InstallStatus = "Skipped"
            $entry.FailureReason = "MSI copy failure"
            continue
        }

        $entry.CopyStatus = "Success"

        # INSTALL
        $InstallData = Invoke-RemoteInstall $server $remotePath

        $entry.InstallStatus = $InstallData.Status
        $entry.MSIExitCode = $InstallData.ExitCode

        # LOG ANALYSIS
        $analysis = Analyze-MSIInstallLog $server $InstallData.ExitCode

        $entry.InstallStatus = $analysis.Status
        $entry.MSIExitCode = $analysis.ExitCode
        $entry.FailureReason = $analysis.Failure

        if ($entry.InstallStatus -eq "Success") {
            Write-Green "[${server}] Installation completed successfully. ExitCode: $($entry.MSIExitCode)"
        }
        else {
            Write-Red "[${server}] Installation failed. ExitCode: $($entry.MSIExitCode). Reason: $($entry.FailureReason)"
        }
    }

    Write-ResultsToTxt $Global:Results
    Write-ResultsToCsv $Global:Results

    # ---------------- SUMMARY ----------------
    Write-Separator
    Write-Host "========= SUMMARY =========" -ForegroundColor Cyan
    Write-Host "Reachable servers: " (($Global:Results | Where-Object { $_.Ping -eq $true }).Count)
    Write-Host "Copied successfully: " (($Global:Results | Where-Object { $_.CopyStatus -eq "Success" }).Count)
    Write-Host "Successfully installed: " (($Global:Results | Where-Object { $_.InstallStatus -eq "Success" }).Count)
    Write-Host "Failed: " (($Global:Results | Where-Object { $_.InstallStatus -eq "Failed" }).Count)
    Write-Host "Skipped: " (($Global:Results | Where-Object { $_.InstallStatus -eq "Skipped" }).Count)
    Write-Host "TXT Log: $Global:TxtLog"
    Write-Host "CSV Log: $Global:CsvLog"
    Write-Host "==========================="
}

# ---------------------------- RUN MAIN --------------------------------------
Main
