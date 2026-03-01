# verify-tasks.ps1
# ─────────────────────────────────────────────────────────────────────────────
# Shows the current state of all Show App Task Scheduler entries.
# Run from the project folder — does NOT require Administrator.
#
# Usage:
#   scripts\verify-tasks.ps1
# ─────────────────────────────────────────────────────────────────────────────

$TaskNames = @("ShowAppServer", "ShowAppBrowser")

function Show-Task {
    param([string]$Name)

    $task = Get-ScheduledTask -TaskName $Name -ErrorAction SilentlyContinue
    if (-not $task) {
        Write-Host "  [$Name]" -ForegroundColor Yellow
        Write-Host "    NOT FOUND — run register-tasks.ps1 to create it" -ForegroundColor Red
        Write-Host ""
        return
    }

    $info = Get-ScheduledTaskInfo -TaskName $Name -ErrorAction SilentlyContinue

    # State colour
    $stateColor = switch ($task.State) {
        "Ready"    { "Green"  }
        "Running"  { "Cyan"   }
        "Disabled" { "Red"    }
        default    { "Yellow" }
    }

    Write-Host "  [$Name]" -ForegroundColor Cyan
    Write-Host "    State       : " -NoNewline
    Write-Host $task.State -ForegroundColor $stateColor

    # Trigger — who does it fire for?
    foreach ($trigger in $task.Triggers) {
        $type = $trigger.CimClass.CimClassName -replace "MSFT_Task", ""
        $user = if ($trigger.UserId) { $trigger.UserId } else { "(any user)" }
        $delay = if ($trigger.Delay) { "  delay $($trigger.Delay)" } else { "" }
        Write-Host "    Trigger     : $type — $user$delay"
    }

    # Action — show command + arguments so we can see the config file
    foreach ($action in $task.Actions) {
        Write-Host "    Command     : $($action.Execute)"
        if ($action.Arguments) {
            Write-Host "    Arguments   : $($action.Arguments)"

            # Pull out the config file from the -ArgumentList value if present
            if ($action.Arguments -match "-ArgumentList\s+'([^']+)'") {
                $configFile = $Matches[1]
                Write-Host "    Config file : " -NoNewline
                if ($configFile -eq "config.json") {
                    Write-Host $configFile -ForegroundColor Green
                } else {
                    Write-Host $configFile -ForegroundColor Cyan
                }
            }
        }
    }

    # Run history
    if ($info) {
        $lastRun  = if ($info.LastRunTime  -and $info.LastRunTime  -gt [datetime]"2000-01-01") { $info.LastRunTime.ToString("yyyy-MM-dd HH:mm:ss")  } else { "never" }
        $lastCode = $info.LastTaskResult
        $nextRun  = if ($info.NextRunTime  -and $info.NextRunTime  -gt [datetime]"2000-01-01") { $info.NextRunTime.ToString("yyyy-MM-dd HH:mm:ss")  } else { "n/a"   }

        $codeColor = if ($lastCode -eq 0) { "Green" } elseif ($lastCode -eq 267011) { "Yellow" } else { "Red" }
        $codeNote  = switch ($lastCode) {
            0       { "Success" }
            267011  { "Task has not yet run" }
            267009  { "Task is currently running" }
            default { "Error 0x{0:X}" -f $lastCode }
        }

        Write-Host "    Last run    : $lastRun  ($codeNote)" -ForegroundColor (if ($lastCode -eq 0) { "White" } else { $codeColor })
        Write-Host "    Next run    : $nextRun"
    }

    Write-Host ""
}

# ── Header ────────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "=== Show App — Task Scheduler Verification ===" -ForegroundColor Cyan
Write-Host "  Computer : $env:COMPUTERNAME"
Write-Host "  Time     : $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Write-Host ""

foreach ($name in $TaskNames) {
    Show-Task -Name $name
}

# ── Quick sanity checks ───────────────────────────────────────────────────────
Write-Host "=== Sanity Checks ===" -ForegroundColor Cyan
Write-Host ""

# Check project folder exists
$projectDir = "C:\GuysAndDollsPlaybackController"
if (Test-Path $projectDir) {
    Write-Host "  [OK] Project folder exists: $projectDir" -ForegroundColor Green
} else {
    Write-Host "  [!!] Project folder NOT found: $projectDir" -ForegroundColor Red
}

# Check start-show.bat exists in scripts/
$startBat = "$projectDir\scripts\start-show.bat"
if (Test-Path $startBat) {
    Write-Host "  [OK] start-show.bat found" -ForegroundColor Green
} else {
    Write-Host "  [!!] start-show.bat NOT found at $startBat" -ForegroundColor Red
}

# Check Node.js is available
$nodeCmd  = Get-Command node -ErrorAction SilentlyContinue
$nodePath = if ($nodeCmd) { $nodeCmd.Source } else { $null }
if ($nodePath) {
    $nodeVer = & node --version 2>&1
    Write-Host "  [OK] Node.js $nodeVer at $nodePath" -ForegroundColor Green
} else {
    Write-Host "  [!!] Node.js not found in PATH" -ForegroundColor Red
}

# Check VLC is installed at the default path
$vlcPath = "C:\Program Files\VideoLAN\VLC\vlc.exe"
if (Test-Path $vlcPath) {
    Write-Host "  [OK] VLC found at $vlcPath" -ForegroundColor Green
} else {
    Write-Host "  [!!] VLC not found at $vlcPath" -ForegroundColor Yellow
}

# Check server.log exists and show tail
$logFile = "$projectDir\server.log"
if (Test-Path $logFile) {
    $logSize = (Get-Item $logFile).Length
    Write-Host "  [OK] server.log exists ($([math]::Round($logSize/1KB, 1)) KB)" -ForegroundColor Green
    Write-Host ""
    Write-Host "--- Last 5 lines of server.log ---" -ForegroundColor DarkGray
    Get-Content $logFile -Tail 5 | ForEach-Object { Write-Host "  $_" -ForegroundColor DarkGray }
    Write-Host "---" -ForegroundColor DarkGray
} else {
    Write-Host "  [ ] server.log not found (server has not run yet)" -ForegroundColor Yellow
}

Write-Host ""
