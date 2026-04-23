# --- 1. PRE-FLIGHT ---
Start-Sleep -Seconds 25

# Registry fixes to stop the flashing highlight
Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "ForegroundFlashCount" -Value 0
Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "ForegroundLockTimeout" -Value 0

Add-Type @'
using System;
using System.Runtime.InteropServices;
public class UserInput {
    [DllImport("user32.dll")]
    public static extern bool GetLastInputInfo(ref LASTINPUTINFO plii);
    public struct LASTINPUTINFO { public uint cbSize; public uint dwTime; }
    public static uint GetIdleTime() {
        LASTINPUTINFO lastInputInfo = new LASTINPUTINFO();
        lastInputInfo.cbSize = (uint)Marshal.SizeOf(lastInputInfo);
        GetLastInputInfo(ref lastInputInfo);
        return ((uint)Environment.TickCount - lastInputInfo.dwTime);
    }
}
public class WindowUtils {
    [DllImport("user32.dll")]
    public static extern bool SetForegroundWindow(IntPtr hWnd);
    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
    [DllImport("user32.dll")]
    public static extern bool IsIconic(IntPtr hWnd);
}
'@

$chromePath = "C:\Program Files (x86)\Google\Chrome\Application\chrome.exe"
$url = "https://mckinneylibrary.github.io/CatalogJJG.html"
$wshell = New-Object -ComObject WScript.Shell
$app = New-Object -ComObject Shell.Application

# --- 2. REFRESH FUNCTION ---
function Restart-Kiosk {
    # Kill Chrome
    Get-Process "chrome" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 3

    # STEP A: Clear the desktop and taskbar focus BEFORE launching Chrome
    $app.MinimizeAll()
    Start-Sleep -Milliseconds 500
    $wshell.SendKeys('^{ESC}') 
    Start-Sleep -Milliseconds 300
    $wshell.SendKeys('^{ESC}')
    Start-Sleep -Seconds 1

    # STEP B: Launch Chrome
    $args = @(
        "$url",
        "--kiosk",
        "--no-first-run",
        "--test-type",
        "--disable-session-crashed-bubble",
        "--no-default-browser-check",
        "--start-maximized",
        "--no-proxy-server",
        "--disable-notifications"
    )
    Start-Process $chromePath -ArgumentList $args
    
    # STEP C: Persistent Focus Loop (to fight the auto-minimize behavior)
    for ($i = 0; $i -lt 15; $i++) {
        Start-Sleep -Seconds 1
        $p = Get-Process "chrome" -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1
        if ($p) {
            $handle = $p.MainWindowHandle
            # If Windows forced it to minimize, Pop it back up (3 = Maximize/Show)
            if ([WindowUtils]::IsIconic($handle)) {
                [WindowUtils]::ShowWindow($handle, 3)
            }
            # Force Chrome to the very front
            [WindowUtils]::SetForegroundWindow($handle)
        }
    }
}

# --- 3. STARTUP & IDLE LOOP ---
Restart-Kiosk
$hasBeenUsed = $false

while($true) {
    Start-Sleep -Seconds 5

# 1. Try to find any chrome processes
    $allChrome = Get-Process "chrome" -ErrorAction SilentlyContinue

    # 2. If none exist, OR if they exist but none have a window title, trigger restart
    if (-not $allChrome -or -not ($allChrome | Where-Object { $_.MainWindowTitle -ne "" })) {
        Restart-Kiosk
        $hasBeenUsed = $false
        continue
    }

    $idleTimeMS = [UserInput]::GetIdleTime()
    if ($idleTimeMS -lt 5000) { $hasBeenUsed = $true }
    if ($hasBeenUsed -and ($idleTimeMS -gt 180000)) {
        Restart-Kiosk
        $hasBeenUsed = $false
    }
}