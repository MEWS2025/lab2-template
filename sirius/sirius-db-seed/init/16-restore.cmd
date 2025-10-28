@echo off
setlocal
echo Restoring seed into %POSTGRES_DB% ...
pg_restore -U %POSTGRES_USER% -d %POSTGRES_DB% --no-owner --no-privileges /docker-entrypoint-initdb.d/15-seed.dump
if errorlevel 1 ( echo Restore failed! & exit /b 1 )
echo Restore complete.
endlocal
