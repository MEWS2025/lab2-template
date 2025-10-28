@echo off
setlocal EnableExtensions
set "CONTAINER_NAME=sirius-web-postgres-seeded"
set "IMAGE=postgres:17"
set "PORT=5433"
set "DB_USER=dbuser"
set "DB_PASS=dbpwd"
set "DB_NAME=sirius-web-db"
set "SCRIPT_DIR=%~dp0"
set "INIT_DIR=%SCRIPT_DIR%init"
echo Pulling %IMAGE% ...
docker pull %IMAGE%
docker rm -f %CONTAINER_NAME% 2>nul
echo Starting seeded Postgres on port %PORT% ...
docker run -p %PORT%:5432 --rm --name %CONTAINER_NAME%    -e POSTGRES_USER=%DB_USER% -e POSTGRES_PASSWORD=%DB_PASS% -e POSTGRES_DB=%DB_NAME%    -v "%INIT_DIR%":/docker-entrypoint-initdb.d:ro    -d %IMAGE%
if errorlevel 1 ( echo [ERROR] docker run failed. & exit /b 1 )
echo Waiting for Postgres to become ready ...
:wait_pg
docker exec %CONTAINER_NAME% pg_isready -U %DB_USER% -d %DB_NAME% >nul 2>&1
if errorlevel 1 (
  timeout /t 1 >nul
  goto wait_pg
)
echo ✅ Postgres ready at jdbc:postgresql://localhost:%PORT%/%DB_NAME%
endlocal
