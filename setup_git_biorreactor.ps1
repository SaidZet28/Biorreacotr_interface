# ================================================================
# setup_git_biorreactor.ps1
#
# INSTRUCCIONES:
#   1. Copia este archivo a: D:\Escuela\TT\TT2\Programas\Interfaz\Prototipo\
#   2. Tambien copia el archivo .gitignore al mismo lugar
#   3. Abre Git Bash o PowerShell en esa carpeta
#   4. Ejecuta: powershell -ExecutionPolicy Bypass -File setup_git_biorreactor.ps1
# ================================================================

$PROJECT_ROOT = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $PROJECT_ROOT
Write-Host "== Directorio: $PROJECT_ROOT" -ForegroundColor Cyan

# ----------------------------------------------------------------
# 1. Verificar / inicializar git
# ----------------------------------------------------------------
Write-Host "`n== Verificando repositorio git..." -ForegroundColor Yellow

if (Test-Path ".git") {
    Write-Host "   Repo git ya existe." -ForegroundColor Green
} else {
    git init
    Write-Host "   Repo git inicializado." -ForegroundColor Green
}

# Configuracion basica si no esta configurada
$userName = git config user.name 2>$null
if (-not $userName) {
    $name = Read-Host "   Tu nombre para git (e.g. Said)"
    git config user.name $name
}
$userEmail = git config user.email 2>$null
if (-not $userEmail) {
    $email = Read-Host "   Tu email para git (e.g. said.mqz@gmail.com)"
    git config user.email $email
}

# ----------------------------------------------------------------
# 2. Limpiar build/ del tracking si ya estaba siendo seguido
# ----------------------------------------------------------------
Write-Host "`n== Limpiando artefactos de build del cache git..." -ForegroundColor Yellow
git rm -r --cached build/ 2>$null
git rm -r --cached .claude/ 2>$null
Write-Host "   Listo." -ForegroundColor Green

# ----------------------------------------------------------------
# 3. Agregar archivos fuente
# ----------------------------------------------------------------
Write-Host "`n== Agregando archivos fuente al staging..." -ForegroundColor Yellow

git add .gitignore
git add CMakeLists.txt
git add main.cpp

# Fuentes C++
if (Test-Path "src")         { git add src/ }
if (Test-Path "tests")       { git add tests/ }
if (Test-Path "herramientas"){ git add herramientas/ }

# Script Python de audio (el generador, no los .wav)
if (Test-Path "audio/generar_sonidos.py") { git add audio/generar_sonidos.py }

# Recursos QML / assets / traducciones
foreach ($dir in @("resources","qml","assets","i18n","translations","images","icons")) {
    if (Test-Path $dir) { git add "$dir/" }
}

Write-Host "   Archivos agregados." -ForegroundColor Green

# ----------------------------------------------------------------
# 4. Verificacion de seguridad: build/ NO debe estar en staging
# ----------------------------------------------------------------
$buildStaged = git diff --cached --name-only | Where-Object { $_ -like "build/*" }
if ($buildStaged) {
    Write-Host "`n[ADVERTENCIA] build/ esta en staging. Removiendo..." -ForegroundColor Red
    git rm -r --cached build/
}

# ----------------------------------------------------------------
# 5. Mostrar resumen y confirmar commit
# ----------------------------------------------------------------
Write-Host "`n== Estado final (archivos que entran al commit):" -ForegroundColor Yellow
git diff --cached --stat

$doCommit = Read-Host "`nHacer commit con estos archivos? (s/n)"
if ($doCommit -eq "s" -or $doCommit -eq "S") {
    git commit -m "feat: commit inicial - interfaz Qt6 para biorreactor

Incluye:
- Controladores: PID, Fuzzy, Histeresis
- Drivers: XM125 (radar), PCA9685 (PWM)
- Backend: GestorBiorreactor, GestorAudio, TranslationManager
- Tests unitarios (tst_pid, tst_fuzzy, tst_histeresis, tst_parseartrama)
- Herramientas: simulador serial, generador de sonidos
- UI QML: pantallas de proceso, configuracion, proyectos guardados

Excluye: build/, binarios, .dll, .claude/, datos de runtime"

    Write-Host "`n== Commit realizado!" -ForegroundColor Green
    git log --oneline -5
} else {
    Write-Host "   Commit cancelado. Archivos siguen en staging." -ForegroundColor Yellow
    Write-Host "   Puedes hacer: git commit -m 'tu mensaje'" -ForegroundColor Gray
}

# ----------------------------------------------------------------
# 6. Instrucciones para subir a GitHub
# ----------------------------------------------------------------
Write-Host "`n================================================================" -ForegroundColor Cyan
Write-Host " Para subir a GitHub (si ya tienes el repo creado ahi):" -ForegroundColor Cyan
Write-Host "   git remote add origin https://github.com/TU_USUARIO/biorreactor.git"
Write-Host "   git branch -M main"
Write-Host "   git push -u origin main"
Write-Host "================================================================`n" -ForegroundColor Cyan
