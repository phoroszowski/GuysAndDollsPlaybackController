# disable-sleep.ps1
# ─────────────────────────────────────────────────────────────────────────────
# Run ONCE on each machine as Administrator.
# Prevents the machine from sleeping, hibernating, or turning off the display
# while plugged in — required for unattended show operation.
# ─────────────────────────────────────────────────────────────────────────────

if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "This script must be run as Administrator."
    exit 1
}

Write-Host "Configuring power settings for unattended show operation..." -ForegroundColor Cyan
Write-Host ""

# Disable sleep (AC power)
powercfg /change standby-timeout-ac 0
Write-Host "[OK] Sleep timeout (AC) disabled"

# Disable hibernate (AC power)
powercfg /change hibernate-timeout-ac 0
Write-Host "[OK] Hibernate timeout (AC) disabled"

# Disable display turn-off (AC power)
powercfg /change monitor-timeout-ac 0
Write-Host "[OK] Display timeout (AC) disabled"

# Disable hibernate entirely (removes hiberfil.sys, frees disk space)
powercfg /hibernate off
Write-Host "[OK] Hibernate disabled system-wide"

# Disable fast startup (can interfere with BIOS AC recovery settings)
$FastStartupPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power'
Set-ItemProperty -Path $FastStartupPath -Name 'HiberbootEnabled' -Value 0 -Type DWord -Force
Write-Host "[OK] Fast startup disabled"

Write-Host ""
Write-Host "======================================================" -ForegroundColor Cyan
Write-Host "  Power settings applied. No reboot required." -ForegroundColor Yellow
Write-Host "  Remember to pause Windows Update before show week."
Write-Host "======================================================" -ForegroundColor Cyan
Write-Host ""
