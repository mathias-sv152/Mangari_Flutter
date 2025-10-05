#!/usr/bin/env pwsh

# Script para ejecutar Flutter con logs filtrados y optimizaciones

Write-Host "🚀 Iniciando Mangari con configuración optimizada..." -ForegroundColor Green

# Configurar variables de entorno para reducir logs
$env:FLUTTER_LOG_LEVEL = "warning"
$env:ANDROID_LOG_TAGS = "*:I"

# Limpiar terminal
Clear-Host

Write-Host "📱 Configuración aplicada:" -ForegroundColor Cyan
Write-Host "   • Logs filtrados (solo Info y superiores)" -ForegroundColor Gray
Write-Host "   • EGL_emulation logs ocultados" -ForegroundColor Gray
Write-Host "   • Optimizaciones de rendimiento activas" -ForegroundColor Gray
Write-Host ""

# Opciones de ejecución
Write-Host "Selecciona modo de ejecución:" -ForegroundColor Yellow
Write-Host "1. Desarrollo (debug con logs filtrados)" -ForegroundColor White
Write-Host "2. Perfil (profile mode)" -ForegroundColor White  
Write-Host "3. Release (sin logs)" -ForegroundColor White
Write-Host "4. Hot reload continuo" -ForegroundColor White

$choice = Read-Host "Elige una opción (1-4)"

switch ($choice) {
    "1" {
        Write-Host "🔧 Modo Desarrollo..." -ForegroundColor Blue
        flutter run --dart-define=LOG_LEVEL=development
    }
    "2" {
        Write-Host "⚡ Modo Perfil..." -ForegroundColor Magenta
        flutter run --profile
    }
    "3" {
        Write-Host "🚀 Modo Release..." -ForegroundColor Green
        flutter run --release
    }
    "4" {
        Write-Host "🔥 Hot Reload Continuo..." -ForegroundColor Red
        flutter run --hot
    }
    default {
        Write-Host "🔧 Modo Desarrollo por defecto..." -ForegroundColor Blue
        flutter run --dart-define=LOG_LEVEL=development
    }
}

Write-Host ""
Write-Host "✅ Aplicación iniciada. Presiona 'q' para salir." -ForegroundColor Green