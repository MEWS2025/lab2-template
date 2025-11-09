@echo off
setlocal EnableExtensions EnableDelayedExpansion

rem ============================================================
rem load_db_data_and_run.cmd (safe v3)
rem - Extract sirius-db-seed*.tar.gz (or given archive)
rem - Start Postgres :17 on port 5433
rem - Wait until ready, then pg_restore the dump
rem - Run sirius-web.jar against it
rem ============================================================

rem ----- CONFIG -----
set "CONTAINER_NAME=sirius-web-postgres"
set "PG_IMAGE=postgres:17"
set "PORT=5433"
set "DB_USER=dbuser"
set "DB_PASS=dbpwd"
set "DB_NAME=sirius-web-db"
set "JAR_FILE=sirius-web.jar"
set "SEED_PATTERN=sirius-db-seed*.tar.gz"
set "EXTRACT_DIR=sirius-db-seed"
rem -------------------

rem ----- Preconditions -----
where docker >nul 2>nul || (echo [ERROR] docker not found in PATH & exit /b 1)
where tar    >nul 2>nul || (echo [ERROR] tar.exe not found ^(Win10/11 include it^). & exit /b 1)
if not exist "%JAR_FILE%" (echo [ERROR] JAR "%JAR_FILE%" not found in current directory & exit /b 1)

rem ----- Pick the bundle -----
if not "%~1"=="" (
  set "BUNDLE_TAR=%~1"
) else (
  set "BUNDLE_TAR="
  dir /b /a:-d /o:-d "%SEED_PATTERN%" > "__seed_list__.txt" 2>nul
  if exist "__seed_list__.txt" (
    set /p BUNDLE_TAR=<"__seed_list__.txt"
    del /q "__seed_list__.txt" >nul 2>nul
  )
)
if not defined BUNDLE_TAR (
  echo [ERROR] No archive provided and none found matching %SEED_PATTERN% in the current directory
  exit /b 1
)
if not exist "%BUNDLE_TAR%" (
  echo [ERROR] Provided archive not found.
  exit /b 1
)
echo [INFO] Using seed bundle: "%BUNDLE_TAR%"

rem ----- Prepare extract dir -----
if exist "%EXTRACT_DIR%" rmdir /s /q "%EXTRACT_DIR%"
mkdir "%EXTRACT_DIR%" >nul 2>nul

echo [INFO] Extracting into ".\%EXTRACT_DIR%\" ...
tar --strip-components=1 -xzf "%BUNDLE_TAR%" -C "%EXTRACT_DIR%"
if errorlevel 1 (echo [ERROR] tar extraction failed. & exit /b 1)

set "INIT_DIR=%cd%\%EXTRACT_DIR%\init"
if not exist "%INIT_DIR%" (
  echo [ERROR] init folder missing in extracted seed.
  exit /b 1
)

rem ----- Locate dump file -----
set "DUMP_FILE=%INIT_DIR%\15-seed.dump"
if not exist "%DUMP_FILE%" (
  set "DUMP_FILE="
  dir /b /a:-d "%INIT_DIR%\*.dump" > "__dump_list__.txt" 2>nul
  if exist "__dump_list__.txt" (
    set /p DUMP_FILE_NAME=<"__dump_list__.txt"
    del /q "__dump_list__.txt" >nul 2>nul
    if defined DUMP_FILE_NAME set "DUMP_FILE=%INIT_DIR%\%DUMP_FILE_NAME%"
  )
)
if not defined DUMP_FILE (
  echo [ERROR] No *.dump file found in extracted init folder.
  exit /b 1
)
echo [INFO] Found dump: "%DUMP_FILE%"

rem ----- Start Postgres (fresh container) -----
echo [INFO] Pulling image %PG_IMAGE% ...
docker pull "%PG_IMAGE%" >nul
if errorlevel 1 (echo [ERROR] docker pull failed. & exit /b 1)

echo [INFO] Removing old container (if any) ...
docker rm -f "%CONTAINER_NAME%" >nul 2>nul

echo [INFO] Starting Postgres on port %PORT% ...
docker run -p %PORT%:5432 --rm --name "%CONTAINER_NAME%" -e POSTGRES_USER=%DB_USER% -e POSTGRES_PASSWORD=%DB_PASS% -e POSTGRES_DB=%DB_NAME% -d "%PG_IMAGE%" >nul
if errorlevel 1 (echo [ERROR] docker run failed. & exit /b 1)

rem ----- Wait for DB readiness -----
echo [INFO] Waiting for Postgres to be ready ...
set /a COUNT=0
:wait_pg
docker exec "%CONTAINER_NAME%" pg_isready -U "%DB_USER%" -d "%DB_NAME%" >nul 2>nul
if errorlevel 1 (
  set /a COUNT+=1
  if !COUNT! GEQ 90 (
    echo [ERROR] Postgres did not become ready in time.
    docker logs "%CONTAINER_NAME%"
    docker stop "%CONTAINER_NAME%" >nul 2>nul
    exit /b 1
  )
  timeout /t 1 >nul
  goto wait_pg
)
echo [INFO] DB is accepting connections.

rem ----- Restore dump into running DB -----
echo [INFO] Copying dump and restoring ...
docker cp "%DUMP_FILE%" "%CONTAINER_NAME%:/tmp/seed.dump"
if errorlevel 1 (
  echo [ERROR] docker cp failed.
  docker stop "%CONTAINER_NAME%" >nul 2>nul
  exit /b 1
)
docker exec -e PGPASSWORD=%DB_PASS% "%CONTAINER_NAME%" pg_restore -U "%DB_USER%" -d "%DB_NAME%" --no-owner --no-privileges /tmp/seed.dump
if errorlevel 1 (
  echo [ERROR] pg_restore failed. Container logs:
  docker logs "%CONTAINER_NAME%"
  docker stop "%CONTAINER_NAME%" >nul 2>nul
  exit /b 1
)
echo [INFO] ✅ Restore completed.

rem ----- Run the Java app -----
echo [INFO] Launching "%JAR_FILE%" ...
java -jar "%JAR_FILE%" --spring.datasource.url=jdbc:postgresql://localhost:%PORT%/%DB_NAME% --spring.datasource.username=%DB_USER% --spring.datasource.password=%DB_PASS%
set "JAVA_EXIT=%ERRORLEVEL%"

rem ----- Cleanup -----
echo.
echo [INFO] Stopping Postgres container...
docker stop "%CONTAINER_NAME%" >nul 2>nul

rem Optional: keep extracted files; comment out next two lines to keep them
echo [INFO] Cleaning extracted folder ".\%EXTRACT_DIR%\" ...
rmdir /s /q "%EXTRACT_DIR%" >nul 2>nul

if not "%JAVA_EXIT%"=="0" (
  echo [WARN] Java exited with code %JAVA_EXIT%.
  exit /b %JAVA_EXIT%
)

echo [INFO] Done.
endlocal
exit /b 0