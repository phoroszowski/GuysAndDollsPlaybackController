# setup-autologin.ps1
# ─────────────────────────────────────────────────────────────────────────────
# Run ONCE on each machine, as Administrator.
# Configures Windows 11 for automatic login to a local "Show" account.
# Handles all Windows 11 24H2 quirks (Credential Guard, Windows Hello, etc.)
#
# Usage:
#   1. Edit USERNAME and PASSWORD below
#   2. Right-click this file → "Run with PowerShell" (as Administrator)
#   3. Reboot when prompted
# ─────────────────────────────────────────────────────────────────────────────

param(
    [string]$Username = "Show",
    [string]$Password = "PHS"
)

# ── Guard: must be Administrator ─────────────────────────────────────────────
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "This script must be run as Administrator. Right-click → Run with PowerShell (Admin)."
    exit 1
}

Write-Host ""
Write-Host "=== Show Machine Auto-Login Setup ===" -ForegroundColor Cyan
Write-Host "  Username : $Username"
Write-Host "  Computer : $env:COMPUTERNAME"
Write-Host ""

# ── 1. Disable lock screen ────────────────────────────────────────────────────
Write-Host "[ 1/6 ] Disabling lock screen..." -NoNewline
$LockPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Personalization'
if (-not (Test-Path $LockPath)) { New-Item -Path $LockPath -Force | Out-Null }
Set-ItemProperty -Path $LockPath -Name 'NoLockScreen' -Value 1 -Type DWord -Force
Write-Host " OK" -ForegroundColor Green

# ── 2. Disable Ctrl+Alt+Delete requirement ────────────────────────────────────
Write-Host "[ 2/6 ] Disabling Ctrl+Alt+Delete..." -NoNewline
Set-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon' `
    -Name 'EnableCAD' -Value 0 -Type DWord -Force
$SysPolPath = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System'
if (-not (Test-Path $SysPolPath)) { New-Item -Path $SysPolPath -Force | Out-Null }
Set-ItemProperty -Path $SysPolPath -Name 'DisableCAD' -Value 1 -Type DWord -Force
Write-Host " OK" -ForegroundColor Green

# ── 3. Disable Windows Hello passwordless mode (reveals netplwiz checkbox) ───
Write-Host "[ 3/6 ] Disabling Windows Hello enforcement..." -NoNewline
$PLPath = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\PasswordLess\Device'
if (-not (Test-Path $PLPath)) { New-Item -Path $PLPath -Force | Out-Null }
Set-ItemProperty -Path $PLPath -Name 'DevicePasswordLessBuildVersion' -Value 0 -Type DWord -Force
Write-Host " OK" -ForegroundColor Green

# ── 4. Disable Credential Guard (REQUIRED on Windows 11 24H2) ────────────────
# Without this, Windows deletes the auto-login password from registry on every logoff.
Write-Host "[ 4/6 ] Disabling Credential Guard (24H2 fix)..." -NoNewline
$DGPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard'
if (-not (Test-Path $DGPath)) { New-Item -Path $DGPath -Force | Out-Null }
Set-ItemProperty -Path $DGPath -Name 'EnableVirtualizationBasedSecurity' -Value 0 -Type DWord -Force
Set-ItemProperty -Path $DGPath -Name 'RequirePlatformSecurityFeatures'    -Value 0 -Type DWord -Force
Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa' `
    -Name 'LsaCfgFlags' -Value 0 -Type DWord -Force
Write-Host " OK" -ForegroundColor Green

# ── 5. Write AutoAdminLogon registry keys ────────────────────────────────────
Write-Host "[ 5/6 ] Writing auto-login registry keys..." -NoNewline
$WLPath = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon'
Set-ItemProperty -Path $WLPath -Name 'AutoAdminLogon'    -Value '1'              -Type String -Force
Set-ItemProperty -Path $WLPath -Name 'DefaultUserName'   -Value $Username        -Type String -Force
Set-ItemProperty -Path $WLPath -Name 'DefaultPassword'   -Value $Password        -Type String -Force
Set-ItemProperty -Path $WLPath -Name 'DefaultDomainName' -Value $env:COMPUTERNAME -Type String -Force
Set-ItemProperty -Path $WLPath -Name 'ForceAutoLogon'    -Value '1'              -Type String -Force
Write-Host " OK" -ForegroundColor Green

# ── 6. Remove stale counter values that can override and disable auto-login ──
Write-Host "[ 6/6 ] Removing stale counter keys..." -NoNewline
foreach ($key in @('AutoLogonCount', 'AutoLogonChecked')) {
    if (Get-ItemProperty -Path $WLPath -Name $key -ErrorAction SilentlyContinue) {
        Remove-ItemProperty -Path $WLPath -Name $key -Force
    }
}
Write-Host " OK" -ForegroundColor Green

Write-Host ""
Write-Host "======================================================" -ForegroundColor Cyan
Write-Host "  All done. Reboot now to apply settings." -ForegroundColor Yellow
Write-Host "  After reboot, run scripts\register-tasks.ps1 next."
Write-Host "======================================================" -ForegroundColor Cyan
Write-Host ""
