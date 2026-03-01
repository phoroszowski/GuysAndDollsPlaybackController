# register-tasks.ps1
# ─────────────────────────────────────────────────────────────────────────────
# Run ONCE on each machine after setup-autologin.ps1, as Administrator.
# Registers Task Scheduler entries to auto-start the show server at login.
#
# On Machine A (master) pass -Master to also register the browser task.
#
# Usage:
#   scripts\register-tasks.ps1                  (workers B and C)
#   scripts\register-tasks.ps1 -Master          (machine A)
#   scripts\register-tasks.ps1 -Username MyUser (override account name)
# ─────────────────────────────────────────────────────────────────────────────

param(
    [string]$Username  = "GuysAndDollsPlaybackController",
    [string]$AppDir    = "C:\GuysAndDollsPlaybackController\",
    [switch]$Master
)

# ── Guard: must be Administrator ─────────────────────────────────────────────
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "This script must be run as Administrator."
    exit 1
}

$Computer = $env:COMPUTERNAME
$StartBat = "C:\GuysAndDollsPlaybackController\scripts\start-show.bat"
$BrowserBat = "C:\GuysAndDollsPlaybackController\scripts\open-controller.bat"

# ─────────────────────────────────────────────────────────────────────────────
# Task 1: ShowAppServer — launches Node.js server at login (all machines)
# ─────────────────────────────────────────────────────────────────────────────
Write-Host "Registering task: ShowAppServer..." -NoNewline

$ServerXml = @"
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.2" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <RegistrationInfo>
    <Description>Starts the Guys and Dolls Playback Controller at login</Description>
  </RegistrationInfo>
  <Triggers>
    <LogonTrigger>
      <Enabled>true</Enabled>
      <UserId>$Computer\$Username</UserId>
      <Delay>PT5S</Delay>
    </LogonTrigger>
  </Triggers>
  <Settings>
    <Hidden>true</Hidden>
    <DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries>
    <StopIfGoingOnBatteries>false</StopIfGoingOnBatteries>
    <ExecutionTimeLimit>PT0S</ExecutionTimeLimit>
    <MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy>
  </Settings>
  <Actions>
    <Exec>
      <Command>powershell.exe</Command>
      <Arguments>-WindowStyle Hidden -NonInteractive -ExecutionPolicy Bypass -Command "Start-Process '$StartBat' -WindowStyle Hidden"</Arguments>
    </Exec>
  </Actions>
</Task>
"@

$TempXml = "$env:TEMP\ShowAppServer.xml"
$ServerXml | Out-File -FilePath $TempXml -Encoding Unicode
schtasks /create /tn "ShowAppServer" /xml $TempXml /f | Out-Null
Remove-Item $TempXml
Write-Host " OK" -ForegroundColor Green

# ─────────────────────────────────────────────────────────────────────────────
# Task 2: ShowAppBrowser — opens Chrome kiosk on master only
# ─────────────────────────────────────────────────────────────────────────────
if ($Master) {
    Write-Host "Registering task: ShowAppBrowser (master only)..." -NoNewline

    $BrowserXml = @"
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.2" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <RegistrationInfo>
    <Description>Opens Chrome to the show controller UI after the server starts</Description>
  </RegistrationInfo>
  <Triggers>
    <LogonTrigger>
      <Enabled>true</Enabled>
      <UserId>$Computer\$Username</UserId>
      <Delay>PT5S</Delay>
    </LogonTrigger>
  </Triggers>
  <Settings>
    <Hidden>false</Hidden>
    <DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries>
    <StopIfGoingOnBatteries>false</StopIfGoingOnBatteries>
    <ExecutionTimeLimit>PT0S</ExecutionTimeLimit>
    <MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy>
  </Settings>
  <Actions>
    <Exec>
      <Command>$BrowserBat</Command>
    </Exec>
  </Actions>
</Task>
"@

    $TempXml = "$env:TEMP\ShowAppBrowser.xml"
    $BrowserXml | Out-File -FilePath $TempXml -Encoding Unicode
    schtasks /create /tn "ShowAppBrowser" /xml $TempXml /f | Out-Null
    Remove-Item $TempXml
    Write-Host " OK" -ForegroundColor Green
}

Write-Host ""
Write-Host "======================================================" -ForegroundColor Cyan
Write-Host "  Tasks registered. Verify in Task Scheduler:" -ForegroundColor Yellow
Write-Host "   - ShowAppServer (all machines)"
if ($Master) { Write-Host "   - ShowAppBrowser (master)" }
Write-Host ""
Write-Host "  Next: copy start-show.bat to C:\ShowApp\"
Write-Host "  Then reboot and confirm the server starts."
Write-Host "======================================================" -ForegroundColor Cyan
Write-Host ""
