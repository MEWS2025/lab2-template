@echo off
setlocal EnableExtensions EnableDelayedExpansion

rem ==========================================
rem save_state.cmd  — create seed bundle here
rem ==========================================

rem ----- CONFIG (edit if needed) -----
set "CONTAINER_NAME=sirius-web-postgres"
set "DB_USER=dbuser"
set "DB_NAME=sirius-web-db"
set "PG_MAJOR=17"
set "PORT_FOR_FRIENDS=5433"
set "BUNDLE_BASENAME=sirius-db-seed"
rem -----------------------------------

rem ----- Preconditions -----
where docker >nul 2>nul || (echo [ERROR] docker not found in PATH & exit /b 1)
where tar    >nul 2>nul || (echo [ERROR] tar.exe not found; on Win10/11 it is built-in. & exit /b 1)

rem ----- Timestamp (locale-proof) -----
rem --- Get ISO-style timestamp (yyyyMMdd_HHmmss) using PowerShell ---
for /f %%a in ('powershell -NoProfile -Command "Get-Date -Format yyyyMMdd_HHmmss"') do set "TIMESTAMP=%%a"

rem ----- Paths in CURRENT DIR -----
set "WORKDIR=%cd%"
set "BUNDLE_DIR=%BUNDLE_BASENAME%-%TIMESTAMP%"
set "BUNDLE_ROOT=%WORKDIR%\%BUNDLE_DIR%"
set "INIT_DIR=%BUNDLE_ROOT%\init"
set "OUTPUT_TGZ=%WORKDIR%\%BUNDLE_DIR%.tar.gz"

echo [INFO] Creating bundle: %BUNDLE_DIR%
mkdir "%BUNDLE_ROOT%" >nul 2>nul
mkdir "%INIT_DIR%"    >nul 2>nul

rem ----- Dump DB from container -----
echo [INFO] Dumping database from "%CONTAINER_NAME%" ...
docker exec -t "%CONTAINER_NAME%" pg_dump -U "%DB_USER%" -d "%DB_NAME%" -F c -f /tmp/seed.dump
if errorlevel 1 (
  echo [ERROR] pg_dump failed. Is the container running?
  exit /b 1
)

rem ----- Copy dump out -----
docker cp "%CONTAINER_NAME%:/tmp/seed.dump" "%WORKDIR%\seed.dump"
if errorlevel 1 (
  echo [ERROR] docker cp failed.
  exit /b 1
)
copy /y "%WORKDIR%\seed.dump" "%INIT_DIR%\15-seed.dump" >nul
del /q "%WORKDIR%\seed.dump" >nul 2>nul

rem ----- init restore script (runs inside container at first init) -----
(
  echo @echo off
  echo setlocal
  echo echo Restoring seed into %%POSTGRES_DB%% ...
  echo pg_restore -U %%POSTGRES_USER%% -d %%POSTGRES_DB%% --no-owner --no-privileges /docker-entrypoint-initdb.d/15-seed.dump
  echo if errorlevel 1 ^( echo Restore failed^^! ^& exit /b 1 ^)
  echo echo Restore complete.
  echo endlocal
) > "%INIT_DIR%\16-restore.cmd"

rem ----- run_with_seed.cmd for friends -----
(
  echo @echo off
  echo setlocal EnableExtensions
  echo set "CONTAINER_NAME=sirius-web-postgres-seeded"
  echo set "IMAGE=postgres:%PG_MAJOR%"
  echo set "PORT=%PORT_FOR_FRIENDS%"
  echo set "DB_USER=%DB_USER%"
  echo set "DB_PASS=dbpwd"
  echo set "DB_NAME=%DB_NAME%"
  echo set "SCRIPT_DIR=%%~dp0"
  echo set "INIT_DIR=%%SCRIPT_DIR%%init"
  echo echo Pulling %%IMAGE%% ...
  echo docker pull %%IMAGE%%
  echo docker rm -f %%CONTAINER_NAME%% 2^>nul
  echo echo Starting seeded Postgres on port %%PORT%% ...
  echo docker run -p %%PORT%%:5432 --rm --name %%CONTAINER_NAME%% ^
   -e POSTGRES_USER=%%DB_USER%% -e POSTGRES_PASSWORD=%%DB_PASS%% -e POSTGRES_DB=%%DB_NAME%% ^
   -v "%%INIT_DIR%%":/docker-entrypoint-initdb.d:ro ^
   -d %%IMAGE%%
  echo if errorlevel 1 ^( echo [ERROR] docker run failed. ^& exit /b 1 ^)
  echo echo Waiting for Postgres to become ready ...
  echo :wait_pg
  echo docker exec %%CONTAINER_NAME%% pg_isready -U %%DB_USER%% -d %%DB_NAME%% ^>nul 2^>^&1
  echo if errorlevel 1 ^(
  echo   timeout /t 1 ^>nul
  echo   goto wait_pg
  echo ^)
  echo echo ✅ Postgres ready at jdbc:postgresql://localhost:%%PORT%%/%%DB_NAME%%
  echo endlocal
) > "%BUNDLE_ROOT%\run_with_seed.cmd"

rem ----- README -----
(
  echo # %BUNDLE_DIR%
  echo.
  echo Portable snapshot of Postgres %PG_MAJOR% from container "%CONTAINER_NAME%".
  echo.
  echo ## Quick start
  echo run_with_seed.cmd
  echo.
  echo Port: %PORT_FOR_FRIENDS%
  echo JDBC: jdbc:postgresql://localhost:%PORT_FOR_FRIENDS%/%DB_NAME%
  echo User: %DB_USER%   Password: dbpwd
) > "%BUNDLE_ROOT%\README.txt"

rem ----- Pack to .tar.gz -----
echo [INFO] Packaging into "%OUTPUT_TGZ%"
pushd "%WORKDIR%" >nul
tar -czf "%OUTPUT_TGZ%" "%BUNDLE_DIR%"
set "TAR_EXIT=%ERRORLEVEL%"
popd >nul
if not "%TAR_EXIT%"=="0" (
  echo [ERROR] tar compression failed.
  exit /b 1
)

rem ----- SHA256 and cleanup -----
for /f "tokens=1" %%A in ('certutil -hashfile "%OUTPUT_TGZ%" SHA256 ^| findstr /i /v "SHA256\|certutil"') do set "SHA256=%%A"
echo [INFO] ✅ Seed bundle created: %OUTPUT_TGZ%
echo [INFO] 🔐 SHA256: %SHA256%

echo [INFO] Cleaning up "%BUNDLE_DIR%" (leaving only the .tar.gz) ...
rmdir /s /q "%BUNDLE_DIR%" >nul 2>nul

echo [INFO] Done.
endlocal
exit /b 0
