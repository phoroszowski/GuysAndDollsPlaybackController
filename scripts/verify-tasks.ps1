# verify-tasks.ps1
# ─────────────────────────────────────────────────────────────────────────────
# Shows the current state of all Show App Task Scheduler entries.
# Run from the project folder — does NOT require Administrator.
# Compatible with PowerShell 5.1 and later.
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
        Write-Host "    NOT FOUND - run register-tasks.ps1 to create it" -ForegroundColor Red
        Write-Host ""
        return
    }

    $info = Get-ScheduledTaskInfo -TaskName $Name -ErrorAction SilentlyContinue

    # State colour
    if     ($task.State -eq "Ready")    { $stateColor = "Green"  }
    elseif ($task.State -eq "Running")  { $stateColor = "Cyan"   }
    elseif ($task.State -eq "Disabled") { $stateColor = "Red"    }
    else                                { $stateColor = "Yellow" }

    Write-Host "  [$Name]" -ForegroundColor Cyan
    Write-Host "    State       : " -NoNewline
    Write-Host $task.State -ForegroundColor $stateColor

    # Trigger
    foreach ($trigger in $task.Triggers) {
        $type  = $trigger.CimClass.CimClassName -replace "MSFT_Task", ""
        if ($trigger.UserId) { $user = $trigger.UserId } else { $user = "(any user)" }
        if ($trigger.Delay)  { $delay = "  delay $($trigger.Delay)" } else { $delay = "" }
        Write-Host "    Trigger     : $type - $user$delay"
    }

    # Action
    foreach ($action in $task.Actions) {
        Write-Host "    Command     : $($action.Execute)"
        if ($action.Arguments) {
            Write-Host "    Arguments   : $($action.Arguments)"

            # Extract the config file from -ArgumentList if present
            if ($action.Arguments -match "-ArgumentList\s+'([^']+)'") {
                $cfgFile = $Matches[1]
                Write-Host "    Config file : " -NoNewline
                if ($cfgFile -eq "config.json") {
                    Write-Host $cfgFile -ForegroundColor Green
                } else {
                    Write-Host $cfgFile -ForegroundColor Cyan
                }
            }
        }
    }

    # Run history
    if ($info) {
        if ($info.LastRunTime -and $info.LastRunTime -gt [datetime]"2000-01-01") {
            $lastRun = $info.LastRunTime.ToString("yyyy-MM-dd HH:mm:ss")
        } else {
            $lastRun = "never"
        }

        $lastCode = $info.LastTaskResult

        if ($info.NextRunTime -and $info.NextRunTime -gt [datetime]"2000-01-01") {
            $nextRun = $info.NextRunTime.ToString("yyyy-MM-dd HH:mm:ss")
        } else {
            $nextRun = "n/a"
        }

        if     ($lastCode -eq 0)      { $codeNote = "Success";               $codeColor = "Green"  }
        elseif ($lastCode -eq 267011) { $codeNote = "Task has not yet run";  $codeColor = "Yellow" }
        elseif ($lastCode -eq 267009) { $codeNote = "Task is currently running"; $codeColor = "Cyan" }
        else                          { $codeNote = ("Error 0x{0:X}" -f $lastCode); $codeColor = "Red" }

        Write-Host "    Last run    : $lastRun  ($codeNote)" -ForegroundColor $codeColor
        Write-Host "    Next run    : $nextRun"
    }

    Write-Host ""
}

# ── Header ────────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "=== Show App - Task Scheduler Verification ===" -ForegroundColor Cyan
Write-Host "  Computer : $env:COMPUTERNAME"
Write-Host "  Time     : $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Write-Host ""

foreach ($name in $TaskNames) {
    Show-Task -Name $name
}

# ── Quick sanity checks ───────────────────────────────────────────────────────
Write-Host "=== Sanity Checks ===" -ForegroundColor Cyan
Write-Host ""

# Project folder
$projectDir = "C:\GuysAndDollsPlaybackController"
if (Test-Path $projectDir) {
    Write-Host "  [OK] Project folder exists: $projectDir" -ForegroundColor Green
} else {
    Write-Host "  [!!] Project folder NOT found: $projectDir" -ForegroundColor Red
}

# start-show.bat
$startBat = "$projectDir\scripts\start-show.bat"
if (Test-Path $startBat) {
    Write-Host "  [OK] start-show.bat found" -ForegroundColor Green
} else {
    Write-Host "  [!!] start-show.bat NOT found at $startBat" -ForegroundColor Red
}

# Node.js
$nodeCmd = Get-Command node -ErrorAction SilentlyContinue
if ($nodeCmd) {
    $nodePath = $nodeCmd.Source
    $nodeVer  = & node --version 2>&1
    Write-Host "  [OK] Node.js $nodeVer at $nodePath" -ForegroundColor Green
} else {
    Write-Host "  [!!] Node.js not found in PATH" -ForegroundColor Red
}

# VLC
$vlcPath = "C:\Program Files\VideoLAN\VLC\vlc.exe"
if (Test-Path $vlcPath) {
    Write-Host "  [OK] VLC found at $vlcPath" -ForegroundColor Green
} else {
    Write-Host "  [!!] VLC not found at $vlcPath" -ForegroundColor Yellow
}

# server.log
$logFile = "$projectDir\server.log"
if (Test-Path $logFile) {
    $logSize = (Get-Item $logFile).Length
    $logKB   = [math]::Round($logSize / 1KB, 1)
    Write-Host "  [OK] server.log exists ($logKB KB)" -ForegroundColor Green
    Write-Host ""
    Write-Host "--- Last 5 lines of server.log ---" -ForegroundColor DarkGray
    Get-Content $logFile -Tail 5 | ForEach-Object { Write-Host "  $_" -ForegroundColor DarkGray }
    Write-Host "---" -ForegroundColor DarkGray
} else {
    Write-Host "  [ ] server.log not found (server has not run yet)" -ForegroundColor Yellow
}

Write-Host ""
