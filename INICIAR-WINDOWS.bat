@echo off
cd /d "%~dp0"
echo ========================================================
echo SECAP - Portal de Gestao (Supabase Local)
echo ========================================================
echo Certifique-se de que o Supabase CLI local esta ativo (supabase start).
echo Apos iniciar, acesse o portal em: http://127.0.0.1:8080
echo ========================================================
where py >nul 2>nul
if %errorlevel% equ 0 (
 py -3 server.py
) else (
 python server.py
)
pause
