# ==============================================================================
# UniAssist — Physical Kiosk 3:00 AM Automated Maintenance Watchdog
# Lead Architect: Abhishek Shrivastava
# Scheduled via Windows Task Scheduler: Daily at 03:00 AM
# ==============================================================================
$AppPath = "C:\UniAssist\UniAssist.exe"
$KioskUrl = "https://uniassist.university.edu"
$LogFile = "C:\UniAssist\logs\kiosk_maintenance.log"

Function Log-Message ($msg) {
    $time = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -Path $LogFile -Value "[$time] $msg"
    Write-Host "[$time] $msg"
}

Log-Message "=== Starting Daily Zero-Touch Kiosk Maintenance ==="

# 1. Gracefully terminate active kiosk window
Log-Message "Terminating active kiosk process..."
Stop-Process -Name "UniAssist" -Force -ErrorAction SilentlyContinue
Stop-Process -Name "chrome" -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 3

# 2. Clear browser cache and stale session cookies
Log-Message "Purging temporary browser cache and session artifacts..."
$CachePath = "$env:LOCALAPPDATA\UniAssist\Cache"
If (Test-Path $CachePath) {
    Remove-Item -Path "$CachePath\*" -Recurse -Force -ErrorAction SilentlyContinue
}

# 3. Pull latest production bundle from intranet server
Log-Message "Checking for latest production build from university server..."
Try {
    Invoke-WebRequest -Uri "$KioskUrl/dist/UniAssist.exe" -OutFile "C:\UniAssist\UniAssist_new.exe" -TimeoutSec 30
    If (Test-Path "C:\UniAssist\UniAssist_new.exe") {
        Move-Item -Path "C:\UniAssist\UniAssist_new.exe" -Destination $AppPath -Force
        Log-Message "UniAssist executable successfully updated to latest build."
    }
} Catch {
    Log-Message "No network update or server offline. Keeping existing binary."
}

# 4. Relaunch in Fullscreen Kiosk Mode (Assigned Access Shell)
Log-Message "Relaunching UniAssist in locked fullscreen kiosk mode..."
Start-Process -FilePath $AppPath -ArgumentList "--kiosk", "--fullscreen", "--disable-pinch"
Log-Message "=== Kiosk Maintenance Complete. Terminal Ready for 08:00 AM Walk-ins ==="

