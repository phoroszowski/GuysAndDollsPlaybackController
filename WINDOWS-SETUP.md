# Windows 11 — Show Machine Setup Guide

Guys and Dolls Playback Controller
Three Windows 11 laptops (A = Master, B and C = Workers)

---

## Overview

Each machine needs to:
1. Boot directly into Windows without a password prompt
2. Launch the Node.js server automatically (no visible window)
3. Launch VLC automatically (the server handles this on startup)

Machine **A** also serves the web UI — you can optionally configure it to open the controller
page in the browser automatically.

### Scripts in this repo

All setup scripts live in the `scripts/` directory. Copy them to a USB stick to run on
each machine.

| Script | Purpose | Machines |
|---|---|---|
| `setup-autologin.ps1` | Configures Windows for auto-login | All |
| `register-tasks.ps1` | Registers Task Scheduler entries | All (`-Master` flag for A) |
| `start-show.bat` | Startup launcher — copy to `C:\ShowApp\` | All |
| `open-controller.bat` | Opens Chrome to the UI after boot | A only |
| `disable-sleep.ps1` | Disables sleep/hibernate | All |

---

## Prerequisites

Install on every machine before following this guide:

- **Node.js 18 or later** — https://nodejs.org (choose the LTS installer, all defaults are fine)
- **VLC media player** — https://www.videolan.org (install to the default path)
- **This application** — copy the project folder to `C:\ShowApp\` on each machine

Verify Node.js installed correctly: open a Command Prompt and run `node --version`.
You should see `v18.x.x` or higher.

---

## Step 1 — Create a Local "Show" Account

Use a local Windows account (not a Microsoft account). This avoids Windows Hello
enforcement that interferes with auto-login.

Open **PowerShell as Administrator** (right-click Start → "Terminal (Admin)") and run:

```powershell
$password = ConvertTo-SecureString "ShowPass1" -AsPlainText -Force
New-LocalUser "Show" -Password $password -FullName "Show Operator" -PasswordNeverExpires
Add-LocalGroupMember -Group "Administrators" -Member "Show"
```

Replace `ShowPass1` with whatever password you want. Keep it simple — you will need to
edit it into the setup script. Write it down somewhere.

> **Why Administrator?** The Node.js server binds to a network port and VLC launches
> sub-processes. Administrator privileges prevent permission errors.

---

## Step 2 — Configure Auto-Login

Auto-login **can be completely scripted** — no need to touch the Windows UI.

### Windows 11 24H2 Note

Windows 11 24H2 (late 2024 onwards) enables **Credential Guard** by default. Without
disabling it first, Windows silently deletes the auto-login password from the registry on
every logoff and auto-login stops working after the first reboot. The script handles this.

### Run `setup-autologin.ps1`

1. Open `scripts\setup-autologin.ps1` in a text editor
2. Edit the `$Username` and `$Password` default values at the top to match your Show account
3. Copy it to the machine (USB stick works fine)
4. Right-click the file → **Run with PowerShell** — or open an **Administrator PowerShell**
   and run: `powershell -ExecutionPolicy Bypass -File setup-autologin.ps1`
5. **Reboot the machine** when the script completes

After reboot the machine should log into the Show account automatically with no prompts.

The script performs these steps in order:
1. Disables the lock screen (the "pretty picture" before the sign-in form)
2. Disables Ctrl+Alt+Delete requirement
3. Disables Windows Hello passwordless enforcement
4. **Disables Credential Guard** (the key 24H2 fix)
5. Writes the `AutoAdminLogon` registry keys
6. Cleans up stale counter keys that can override and disable auto-login

### Manual UI Alternative (if scripting is not an option)

1. Run steps 1–4 of the script manually, OR:
   - **Lock screen:** Settings → Personalization → Lock screen → turn off lock screen options
   - **Credential Guard (24H2):** Settings → Privacy & Security → Device Security →
     Core isolation → Memory integrity → **Off** (requires reboot)
2. Press `Win + R`, type `netplwiz`, press Enter
3. Select the **Show** account
4. Uncheck **"Users must enter a user name and password to use this computer"**
   - If this checkbox is missing, the Windows Hello fix in step 3 of the script is needed
5. Click **Apply**, enter the password twice, click OK
6. Reboot

---

## Step 3 — Install the Application

Copy the project folder onto each machine. The recommended location is:

```
C:\ShowApp\GuysAndDollsPlaybackController\
```

Then install Node.js dependencies. Open an **Administrator Command Prompt** and run:

```cmd
cd C:\ShowApp\GuysAndDollsPlaybackController
npm install
```

### Per-Machine Config Files

Each machine uses its own config file. The application loads `config.json` by default.

**Machine A (Master)** — `config.json` is already the master config. Verify the IP
addresses for B and C match your network before deploying.

**Machine B** — copy the worker config over:

```cmd
copy C:\ShowApp\GuysAndDollsPlaybackController\config.worker-B.json C:\ShowApp\GuysAndDollsPlaybackController\config.json
```

**Machine C** — same using `config.worker-C.json`.

> `screenNumber: 1` means the second display (0-indexed). If VLC launches on the laptop
> screen instead of the projector, change this to match your display order.

---

## Step 4 — Copy the Startup Script

Copy `scripts\start-show.bat` from this repo to `C:\ShowApp\start-show.bat` on the machine.

This batch file starts the Node server and logs all output to `C:\ShowApp\server.log`.

> The Node server auto-starts VLC when it launches — no separate VLC startup entry needed.

**Machine A only:** also copy `scripts\open-controller.bat` to `C:\ShowApp\open-controller.bat`.
This opens Chrome in kiosk mode pointing at the show controller UI, 10 seconds after login.
To exit kiosk mode during setup: **Alt+F4**.

---

## Step 5 — Register Task Scheduler Entries

The server must run in the **user's login session** (not as a Windows service) because VLC
needs a display. Task Scheduler with an "At log on" trigger is the correct approach.

Open an **Administrator PowerShell** window and run from the project folder:

**Workers B and C:**
```powershell
powershell -ExecutionPolicy Bypass -File scripts\register-tasks.ps1
```

**Master (Machine A):**
```powershell
powershell -ExecutionPolicy Bypass -File scripts\register-tasks.ps1 -Master
```

The `-Master` flag also registers the `ShowAppBrowser` task that opens Chrome to the UI.

To override the username if your Show account has a different name:
```powershell
powershell -ExecutionPolicy Bypass -File scripts\register-tasks.ps1 -Username MyShowAccount
```

### Verify the Task Was Created

Open Task Scheduler (search "Task Scheduler" in Start) and look for **ShowAppServer**
under **Task Scheduler Library**. It should show a trigger of "At log on".

> **Why PowerShell as launcher?** Calling a `.bat` file directly from Task Scheduler opens
> a visible CMD window. The script wraps it with `powershell -WindowStyle Hidden` to
> suppress all windows.

---

## Step 6 — BIOS / Power Settings

These settings ensure the machine comes back up automatically after a power outage.

### BIOS — Power-On After AC Loss

1. Reboot into BIOS/UEFI (usually `F2`, `Delete`, or `F12` — check your laptop model)
2. Look for **"AC Power Recovery"**, **"Power On After Power Loss"**,
   or **"Restore on AC Power Loss"**
3. Set it to **Power On** (or **Last State**)
4. Save and exit

> Not all laptops expose this setting — it is more common on desktops. If unavailable,
> the machine must be powered on manually after an outage.

### Windows — Disable Sleep and Hibernate

Run `scripts\disable-sleep.ps1` as Administrator on each machine:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\disable-sleep.ps1
```

This disables sleep, hibernate, display timeout, and fast startup. No reboot required.

### Windows — Pause Automatic Updates (Show Week)

Pause updates for 5 weeks the week before the show opens so Windows Update cannot
restart the machines mid-performance.

Settings → Windows Update → **Pause updates** → Pause for 5 weeks.

Re-enable after the run.

---

## Step 7 — Open Firewall Port

If Windows Firewall blocks connections from the phone, run this on Machine A and the workers:

```powershell
New-NetFirewallRule -DisplayName "ShowApp Node" -Direction Inbound -Protocol TCP -LocalPort 3000 -Action Allow
```

---

## Step 8 — Test the Full Boot Sequence

1. Reboot the machine and step away — do not touch keyboard or mouse
2. Machine should: boot → log into Show account automatically → wait 5 seconds → start
   the Node server in the background → VLC launches (fullscreen on the projector)
3. On Machine A: open a browser on your phone and navigate to `http://<MachineA-IP>:3000`
4. Check `C:\ShowApp\server.log` if the server did not start

To find Machine A's IP address: open a Command Prompt and run `ipconfig`. Look for the
IPv4 address on your Wi-Fi or Ethernet adapter.

---

## Per-Machine Setup Checklist

```
Machine A (Master)                     Machine B (Worker)       Machine C (Worker)
─────────────────────────────────────  ───────────────────────  ───────────────────────
[ ] Node.js installed                  [ ] Node.js installed    [ ] Node.js installed
[ ] VLC installed                      [ ] VLC installed        [ ] VLC installed
[ ] Project copied to C:\ShowApp\      [ ] Project copied       [ ] Project copied
[ ] npm install run                    [ ] npm install run      [ ] npm install run
[ ] config.json (master version)       [ ] config.json (B)      [ ] config.json (C)
[ ] setup-autologin.ps1 run            [ ] autologin script     [ ] autologin script
[ ] Rebooted after autologin script    [ ] Rebooted             [ ] Rebooted
[ ] start-show.bat → C:\ShowApp\       [ ] start-show.bat       [ ] start-show.bat
[ ] open-controller.bat → C:\ShowApp\  (not needed)             (not needed)
[ ] register-tasks.ps1 -Master run     [ ] register-tasks.ps1   [ ] register-tasks.ps1
[ ] disable-sleep.ps1 run             [ ] disable-sleep.ps1    [ ] disable-sleep.ps1
[ ] Firewall rule added               [ ] Firewall rule         [ ] Firewall rule
[ ] BIOS AC recovery set              [ ] BIOS AC recovery      [ ] BIOS AC recovery
[ ] Full boot test passed             [ ] Boot test passed      [ ] Boot test passed
[ ] Phone can reach web UI at :3000
```

---

## Troubleshooting

### Auto-login not working after reboot

Check Registry Editor (`regedit`) at:
`HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon`

Confirm these values exist:
- `AutoAdminLogon` = `1`
- `DefaultUserName` = `Show`
- `DefaultPassword` = your password (visible in plain text — expected for this setup)
- `DefaultDomainName` = your computer name

If `DefaultPassword` is missing or `AutoAdminLogon` has reset to `0`, Credential Guard
is still active. Check Event Viewer → Windows Logs → Application for LogonUI entries
deleting the Winlogon keys. Re-run `setup-autologin.ps1` and verify it completes step 4.

### Server starts but VLC doesn't launch

- Check `C:\ShowApp\server.log` for VLC launch errors
- Verify the VLC path in `config.json` exactly matches the install location:
  `C:\Program Files\VideoLAN\VLC\vlc.exe`
- Confirm the Show account has read access to the video directory

### VLC launches on the wrong screen

Change `screenNumber` in `config.json`:
- `0` = primary display (laptop screen)
- `1` = second display (projector)

Restart the server after changing config.

### Videos don't play / group commands fail (400 errors on A)

- Confirm worker IPs and ports in Machine A's `config.json` match the actual network
  addresses of B and C
- Confirm B and C Node servers are running (check their `server.log`)
- Confirm the firewall rule on each machine allows inbound port 3000

### "VLC offline" badge stays red after boot

VLC's HTTP API takes ~2 seconds to become available after launch. If still red after
30 seconds, check the VLC launch entry in `server.log`.

### Reading server logs

```cmd
type C:\ShowApp\server.log
```

Live tail (PowerShell):

```powershell
Get-Content C:\ShowApp\server.log -Wait
```

---

## Network Layout

```
Wi-Fi Network (e.g. 192.168.1.x)

  Phone / Tablet (browser)
         |
         | HTTP :3000
         v
  [Laptop A — Master]   192.168.1.100
    Node server :3000
    VLC HTTP    :8081
         |               |
         | HTTP :3000     | HTTP :3000
         v               v
  [Laptop B — Worker]   [Laptop C — Worker]
  192.168.1.101         192.168.1.102
  VLC HTTP :8081        VLC HTTP :8081
```

All three machines should be on the same Wi-Fi network. Assign static IP addresses
(or DHCP reservations by MAC address on your router) so the IPs in `config.json`
don't change between rehearsals.
