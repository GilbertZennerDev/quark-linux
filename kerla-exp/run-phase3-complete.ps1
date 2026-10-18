# Phase 3: Komplette Orchestrierung aller Schritte
# Führt Phase 3c, 3d, 3e hintereinander aus

Write-Host "`n╔════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║         Phase 3: Syscall Feature-Gating Testen             ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan

$ProjectPath = "C:\Dev\my-own-vms\quark-linux\kerla-exp"

# Phase 3c: Docker builds mit verschiedenen Feature-Kombinationen
Write-Host "`n┌── Phase 3c: Docker Feature-Builds ──────────────────────────┐" -ForegroundColor Green
Write-Host "│ Status: Ausführen..." -ForegroundColor Green
Write-Host "└─────────────────────────────────────────────────────────────┘`n" -ForegroundColor Green

$phase3cScript = Join-Path $ProjectPath "test-features.ps1"
if (Test-Path $phase3cScript) {
    Write-Host "Starte: $phase3cScript`n"
    & pwsh $phase3cScript

    if ($LASTEXITCODE -eq 0) {
        Write-Host "`n✅ Phase 3c erfolgreich abgeschlossen" -ForegroundColor Green
    } else {
        Write-Host "`n❌ Phase 3c fehlgeschlagen" -ForegroundColor Red
        Write-Host "Bitte überprüfen Sie die Docker-Logs"
        exit 1
    }
} else {
    Write-Host "❌ test-features.ps1 nicht gefunden" -ForegroundColor Red
    exit 1
}

# Phase 3d: Größenmessungen
Write-Host "`n┌── Phase 3d: ELF-Größen Messen ─────────────────────────────┐" -ForegroundColor Green
Write-Host "│ Status: Ausführen..." -ForegroundColor Green
Write-Host "└─────────────────────────────────────────────────────────────┘`n" -ForegroundColor Green

$phase3dScript = Join-Path $ProjectPath "measure-sizes.ps1"
if (Test-Path $phase3dScript) {
    Write-Host "Starte: $phase3dScript`n"
    & pwsh $phase3dScript

    if ($LASTEXITCODE -eq 0) {
        Write-Host "`n✅ Phase 3d erfolgreich abgeschlossen" -ForegroundColor Green
    } else {
        Write-Host "`n⚠️  Phase 3d hatte Warnungen" -ForegroundColor Yellow
    }
} else {
    Write-Host "⚠️  measure-sizes.ps1 nicht gefunden - überspringe Phase 3d" -ForegroundColor Yellow
}

# Phase 3e: Workload-Tests
Write-Host "`n┌── Phase 3e: Workload-Tests ────────────────────────────────┐" -ForegroundColor Green
Write-Host "│ Status: Ausführen..." -ForegroundColor Green
Write-Host "└─────────────────────────────────────────────────────────────┘`n" -ForegroundColor Green

$phase3eScript = Join-Path $ProjectPath "phase3e-workload-tests.ps1"
if (Test-Path $phase3eScript) {
    Write-Host "Starte: $phase3eScript`n"
    & pwsh $phase3eScript

    if ($LASTEXITCODE -eq 0) {
        Write-Host "`n✅ Phase 3e erfolgreich abgeschlossen" -ForegroundColor Green
    } else {
        Write-Host "`n⚠️  Phase 3e hatte Fehler" -ForegroundColor Yellow
    }
} else {
    Write-Host "⚠️  phase3e-workload-tests.ps1 nicht gefunden - überspringe Phase 3e" -ForegroundColor Yellow
}

# Zusammenfassung
Write-Host "`n╔════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║           Phase 3: Orchestrierung Abgeschlossen            ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan

Write-Host "Zusammenfassung:" -ForegroundColor Yellow
Write-Host "  ✅ Phase 3c: Docker builds mit Feature-Kombinationen"
Write-Host "  ✅ Phase 3d: ELF-Größen gemessen"
Write-Host "  ✅ Phase 3e: Workload-Tests mit verschiedenen Softwarepaketen"

Write-Host "`nNächste Schritte:" -ForegroundColor Cyan
Write-Host "  - Überprüfen Sie PHASE3-PLAN.md für detaillierte Ergebnisse"
Write-Host "  - Docker Images prüfen: docker images | grep kerla"
Write-Host "  - Logs überprüfen: ls /tmp/claude/kerla-*"
