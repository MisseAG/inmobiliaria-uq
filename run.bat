@echo off
echo Compilando...
mix compile
if %errorlevel% neq 0 (
    echo Error en compilacion
    pause
    exit /b %errorlevel%
)
echo Iniciando Inmobiliaria Virtual...
mix run --no-halt -e "Inmobiliaria.CLI.start()"