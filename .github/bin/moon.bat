@echo off
setlocal enabledelayedexpansion

rem Find the real moon executable
set "REAL_MOON=%USERPROFILE%\.moon\bin\moon.exe"

set "ARGS="
set "CMD_NAME=%1"

:loop
if "%~1"=="" goto end_loop
set "arg=%~1"
if "%arg%"=="--deny-warn" (
    if "%CMD_NAME%"=="check" (
        set "ARGS=!ARGS! %1"
    ) else if "%CMD_NAME%"=="test" (
        set "ARGS=!ARGS! %1"
    ) else if "%CMD_NAME%"=="build" (
        set "ARGS=!ARGS! %1"
    ) else if "%CMD_NAME%"=="fmt" (
        set "ARGS=!ARGS! --check"
    )
) else (
    set "ARGS=!ARGS! %1"
)
shift
goto loop
:end_loop

"%REAL_MOON%" %ARGS%
