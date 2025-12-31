@echo off
REM Build script for docker-compose.custom.yml
REM Usage: build-custom.bat

echo Building Langfuse services from docker-compose.custom.yml...

REM Set build ID if not provided
if "%NEXT_PUBLIC_BUILD_ID%"=="" (
    set NEXT_PUBLIC_BUILD_ID=local
    echo Using default BUILD_ID: local
)

REM Build using docker compose
echo.
echo Building worker and web services...
docker compose -f docker-compose.custom.yml build

if %ERRORLEVEL% EQU 0 (
    echo.
    echo Build completed successfully!
) else (
    echo.
    echo Build failed with exit code: %ERRORLEVEL%
    echo Check the error messages above for details.
    exit /b %ERRORLEVEL%
)

