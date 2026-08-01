@echo off
REM ===================================================================
REM  EduBot - reconnect the phone to the local backend (USB tunnel)
REM
REM  Run this AFTER every USB re-plug (the adb reverse tunnel does not
REM  survive unplugging, and the app then reports "cannot reach server").
REM
REM  What it does:
REM    1. checks the phone is visible to adb
REM    2. re-creates the reverse tunnel  phone:8080 -> laptop:8080
REM    3. checks the Flask backend is actually up
REM    4. restarts the app so it reconnects cleanly
REM ===================================================================

set ADB=%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe
set PKG=com.edubot.edubot_mobile

echo.
echo [1/4] Looking for the phone...
"%ADB%" devices | findstr /R /C:"device$" >nul
if errorlevel 1 (
    echo   ERROR: no phone detected.
    echo   - re-plug the USB cable
    echo   - set USB mode to "File Transfer" ^(not charging-only^)
    echo   - approve the "Allow USB debugging" prompt on the phone
    goto :end
)
echo   OK - phone detected.

echo.
echo [2/4] Re-creating the USB tunnel ^(phone:8080 -^> laptop:8080^)...
"%ADB%" reverse tcp:8080 tcp:8080 >nul
"%ADB%" reverse --list

echo.
echo [3/4] Checking the backend is running...
powershell -NoProfile -Command "try { $r = Invoke-WebRequest -Uri 'http://127.0.0.1:8080/report-template' -TimeoutSec 5 -UseBasicParsing; Write-Host '  OK - backend responded HTTP' $r.StatusCode } catch { Write-Host '  ERROR: backend is NOT running. Start it with:  python backend\app.py' }"

echo.
echo [4/4] Restarting the app...
"%ADB%" shell am force-stop %PKG%
"%ADB%" shell monkey -p %PKG% -c android.intent.category.LAUNCHER 1 >nul 2>&1
echo   OK - app relaunched.

echo.
echo Done. Sign-in should now work.

:end
echo.
pause
