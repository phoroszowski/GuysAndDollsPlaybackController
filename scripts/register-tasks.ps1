# register-tasks.ps1
# ─────────────────────────────────────────────────────────────────────────────
# Run ONCE on each machine after setup-autologin.ps1, as Administrator.
# Registers Task Scheduler entries to auto-start the show server at login.
#
# On Machine A (master) pass -Master to also register the browser task.
#
# Usage:
#   scripts\register-tasks.ps1 -ConfigFile config.worker-B.json   (machine B)
#   scripts\register-tasks.ps1 -ConfigFile config.worker-C.json   (machine C)
#   scripts\register-tasks.ps1 -Master                             (machine A)
#   scripts\register-tasks.ps1 -Master -Username MyUser            (override account name)
# ─────────────────────────────────────────────────────────────────────────────

param(
    [string]$Username   = $env:USERNAME,
    [string]$ConfigFile = "config.json",
    [switch]$Master
)

# ── Guard: must be Administrator ─────────────────────────────────────────────
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "This script must be run as Administrator."
    exit 1
}

$Computer   = $env:COMPUTERNAME
$StartBat   = "$PSScriptRoot\start-show.bat"
$BrowserBat = "$PSScriptRoot\open-controller.bat"
$UserId     = "$Computer\$Username"

Write-Host ""
Write-Host "Registering tasks for user: $UserId" -ForegroundColor Cyan
Write-Host ""

# ─────────────────────────────────────────────────────────────────────────────
# Task 1: ShowAppServer — launches Node.js server at login (all machines)
# ─────────────────────────────────────────────────────────────────────────────
Write-Host "Registering task: ShowAppServer..." -NoNewline

$serverArgument = "-WindowStyle Hidden -NonInteractive -ExecutionPolicy Bypass -Command `"Start-Process '$StartBat' -ArgumentList '$ConfigFile' -WindowStyle Hidden`""

$serverAction   = New-ScheduledTaskAction `
                      -Execute  "powershell.exe" `
                      -Argument $serverArgument

$serverTrigger  = New-ScheduledTaskTrigger -AtLogOn -User $UserId

$serverSettings = New-ScheduledTaskSettingsSet `
                      -Hidden `
                      -AllowStartIfOnBatteries `
                      -DontStopIfGoingOnBatteries `
                      -ExecutionTimeLimit (New-TimeSpan -Seconds 0) `
                      -MultipleInstances IgnoreNew

$serverPrincipal = New-ScheduledTaskPrincipal `
                       -UserId   $UserId `
                       -LogonType Interactive `
                       -RunLevel Limited

Register-ScheduledTask `
    -TaskName  "ShowAppServer" `
    -Action    $serverAction `
    -Trigger   $serverTrigger `
    -Settings  $serverSettings `
    -Principal $serverPrincipal `
    -Force | Out-Null

Write-Host " OK" -ForegroundColor Green

# ─────────────────────────────────────────────────────────────────────────────
# Task 2: ShowAppBrowser — opens Chrome kiosk on master only
# ─────────────────────────────────────────────────────────────────────────────
if ($Master) {
    Write-Host "Registering task: ShowAppBrowser (master only)..." -NoNewline

    $browserAction   = New-ScheduledTaskAction -Execute $BrowserBat

    $browserTrigger  = New-ScheduledTaskTrigger -AtLogOn -User $UserId

    $browserSettings = New-ScheduledTaskSettingsSet `
                           -AllowStartIfOnBatteries `
                           -DontStopIfGoingOnBatteries `
                           -ExecutionTimeLimit (New-TimeSpan -Seconds 0) `
                           -MultipleInstances IgnoreNew

    $browserPrincipal = New-ScheduledTaskPrincipal `
                            -UserId   $UserId `
                            -LogonType Interactive `
                            -RunLevel Limited

    Register-ScheduledTask `
        -TaskName  "ShowAppBrowser" `
        -Action    $browserAction `
        -Trigger   $browserTrigger `
        -Settings  $browserSettings `
        -Principal $browserPrincipal `
        -Force | Out-Null

    Write-Host " OK" -ForegroundColor Green
}

Write-Host ""
Write-Host "======================================================" -ForegroundColor Cyan
Write-Host "  Tasks registered. Verify in Task Scheduler:" -ForegroundColor Yellow
Write-Host "   - ShowAppServer (all machines)"
if ($Master) { Write-Host "   - ShowAppBrowser (master)" }
Write-Host ""
Write-Host "  Reboot and confirm the server starts."
Write-Host "======================================================" -ForegroundColor Cyan
Write-Host ""
