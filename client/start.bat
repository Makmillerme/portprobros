@echo off
setlocal EnableDelayedExpansion
color 0A
title Port Pro Bros - Rust DS Launcher

REM Folder where Run_DS.bat, steam\, rustds\ live (change if your install moved)
set "RUST_HOME=D:\RustServer\Server"
set "RUST_LAUNCHER=%RUST_HOME%\Run_DS.bat"

echo ==========================================
echo   Port Pro Bros - Rust DS Launcher
echo   Tunnel: WireGuard ^(wg0 must be active^)
echo ==========================================
echo.

REM Check WireGuard tunnel is up before starting
ping -n 1 10.8.0.1 >nul 2>&1
if errorlevel 1 (
    echo [WARN] Cannot reach WireGuard VPS peer ^(10.8.0.1^).
    echo        Make sure WireGuard wg0 tunnel is connected before players join.
    echo        Continuing anyway...
    echo.
)

if not exist "%RUST_LAUNCHER%" (
    echo [ERROR] Rust launcher not found:
    echo %RUST_LAUNCHER%
    echo Edit RUST_HOME in this start.bat if path differs.
    echo.
    pause
    exit /b 1
)

echo [1/1] Starting Rust Dedicated Server in a new window...
REM Must cd into Rust folder first - Run_DS.bat uses relative paths ^(steam, rustds^)
start "Rust Dedicated Server" cmd /k "cd /d %RUST_HOME% && Run_DS.bat"
echo.
echo [OK] Rust DS window launched.
echo.
echo Waiting for local port 28015 to open ^(first boot may take several minutes^)...
set /a tries=0
set /a maxwait=90

:waitrust
timeout /t 10 /nobreak >nul
netstat -an | findstr ":28015" >nul 2>&1
if not errorlevel 1 goto rust_ready
set /a tries+=1
if !tries! GEQ %maxwait% goto rust_timeout
goto waitrust

:rust_timeout
echo.
echo [WARN] Port 28015 did not appear within ~15 min. Check the Rust DS window.
pause
exit /b 1

:rust_ready
echo [OK] Rust DS is listening on :28015
echo.
echo ==========================================
echo   Server is running. Players connect via:
echo   client.connect makmillerrust.duckdns.org:28015
echo ==========================================
echo.
echo To stop: close the Rust DS window ^(it will auto-restart unless you stop it^).
pause
endlocal
exit /b 0
