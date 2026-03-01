# remove-autologin.ps1
# ─────────────────────────────────────────────────────────────────────────────
# Run as Administrator to UNDO setup-autologin.ps1.
# Restores Windows 11 to normal password-protected sign-on.
#
# Usage:
#   Right-click this file → "Run with PowerShell" (as Administrator)
#   Reboot when prompted
# ─────────────────────────────────────────────────────────────────────────────

# ── Guard: must be Administrator ─────────────────────────────────────────────
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "This script must be run as Administrator. Right-click → Run with PowerShell (Admin)."
    exit 1
}

Write-Host ""
Write-Host "=== Show Machine Auto-Login REMOVAL ===" -ForegroundColor Cyan
Write-Host "  Computer : $env:COMPUTERNAME"
Write-Host ""

# ── 1. Re-enable lock screen ──────────────────────────────────────────────────
Write-Host "[ 1/6 ] Re-enabling lock screen..." -NoNewline
$LockPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Personalization'
if (Test-Path $LockPath) {
    Remove-ItemProperty -Path $LockPath -Name 'NoLockScreen' -Force -ErrorAction SilentlyContinue
}
Write-Host " OK" -ForegroundColor Green

# ── 2. Re-enable Ctrl+Alt+Delete requirement ──────────────────────────────────
Write-Host "[ 2/6 ] Re-enabling Ctrl+Alt+Delete..." -NoNewline
$WLPath = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon'
Set-ItemProperty -Path $WLPath -Name 'EnableCAD' -Value 1 -Type DWord -Force
$SysPolPath = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System'
if (Test-Path $SysPolPath) {
    Remove-ItemProperty -Path $SysPolPath -Name 'DisableCAD' -Force -ErrorAction SilentlyContinue
}
Write-Host " OK" -ForegroundColor Green

# ── 3. Restore Windows Hello passwordless mode ────────────────────────────────
# Windows 11 default is 2; restoring this re-enables Hello enforcement.
Write-Host "[ 3/6 ] Restoring Windows Hello enforcement..." -NoNewline
$PLPath = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\PasswordLess\Device'
if (Test-Path $PLPath) {
    Set-ItemProperty -Path $PLPath -Name 'DevicePasswordLessBuildVersion' -Value 2 -Type DWord -Force
}
Write-Host " OK" -ForegroundColor Green

# ── 4. Re-enable Credential Guard ────────────────────────────────────────────
# Restores Windows 11 24H2 defaults for VBS and LSA protection.
Write-Host "[ 4/6 ] Restoring Credential Guard settings..." -NoNewline
$DGPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard'
if (Test-Path $DGPath) {
    Set-ItemProperty -Path $DGPath -Name 'EnableVirtualizationBasedSecurity' -Value 1 -Type DWord -Force
    Set-ItemProperty -Path $DGPath -Name 'RequirePlatformSecurityFeatures'    -Value 1 -Type DWord -Force
}
Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa' `
    -Name 'LsaCfgFlags' -Value 1 -Type DWord -Force
Write-Host " OK" -ForegroundColor Green

# ── 5. Remove auto-login registry keys ───────────────────────────────────────
Write-Host "[ 5/6 ] Removing auto-login registry keys..." -NoNewline
Set-ItemProperty -Path $WLPath -Name 'AutoAdminLogon' -Value '0' -Type String -Force
foreach ($key in @('DefaultPassword', 'ForceAutoLogon')) {
    Remove-ItemProperty -Path $WLPath -Name $key -Force -ErrorAction SilentlyContinue
}
Write-Host " OK" -ForegroundColor Green

# ── 6. Confirm DefaultUserName and DefaultDomainName are cleared ─────────────
Write-Host "[ 6/6 ] Clearing cached username/domain..." -NoNewline
foreach ($key in @('DefaultUserName', 'DefaultDomainName')) {
    Remove-ItemProperty -Path $WLPath -Name $key -Force -ErrorAction SilentlyContinue
}
Write-Host " OK" -ForegroundColor Green

Write-Host ""
Write-Host "======================================================" -ForegroundColor Cyan
Write-Host "  All done. Reboot now to restore normal sign-on." -ForegroundColor Yellow
Write-Host "======================================================" -ForegroundColor Cyan
Write-Host ""
