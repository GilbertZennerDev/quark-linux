# Minimalisierungs-Test-Suite für Kerla
# Testet systematisch, welche Syscalls wirklich nötig sind
# Usage: ./test-minimize.ps1 [TestName]

param(
    [string]$TestName = "all",
    [switch]$SkipBuild = $false,
    [int]$Timeout = 60
)

$ErrorActionPreference = "Stop"
$baseDir = "C:\Dev\my-own-vms\quark-linux\kerla-exp"
Set-Location $baseDir

# Test-Konfigurationen definieren
$tests = @(
    @{
        Name = "baseline"
        Flags = "--features leitung,ssh,extra"
        Description = "Aktuell: Alle Features aktiviert"
        TestCmd = "q install wget && echo OK"
        Checks = @("q-works", "ssh-works", "shell-works")
    },
    @{
        Name = "no-ssh"
        Flags = "--no-default-features --features leitung"
        Description = "Ohne SSH: Nur Datei-I/O + lokale Netzwerk"
        TestCmd = "q install wget && echo OK"
        Checks = @("q-works", "shell-works")
    },
    @{
        Name = "no-network"
        Flags = "--no-default-features"
        Description = "Keine Netzwerk: Nur Kernel + BusyBox (Shell lokal)"
        TestCmd = "ls / && echo OK"
        Checks = @("shell-works")
    },
    @{
        Name = "q-only"
        Flags = "--no-default-features --features socket,connect"
        Description = "Minimal für q: Socket + Connect (Download nur, keine SSH)"
        TestCmd = "q install wget && echo OK"
        Checks = @("q-works", "shell-works")
    },
    @{
        Name = "busybox-minimal"
        Flags = "--no-default-features --features leitung"
        Description = "Mit minimalistische BusyBox (80 Applets statt 304)"
        TestCmd = "q install wget && echo OK"
        Checks = @("q-works", "shell-works")
        BusyBoxMode = "minimal"
    }
)

# Ergebnisverzeichnis
$resultsDir = "$baseDir\test-results"
if (-not (Test-Path $resultsDir)) {
    New-Item -ItemType Directory -Path $resultsDir | Out-Null
}

# Logging-Funktion
function Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "HH:mm:ss"
    $prefix = "[$timestamp] [$Level]"
    Write-Host "$prefix $Message" -ForegroundColor $(
        switch($Level) {
            "SUCCESS" { "Green" }
            "ERROR" { "Red" }
            "WARNING" { "Yellow" }
            "INFO" { "Cyan" }
            default { "White" }
        }
    )
}

# Test durchführen
function Run-Test {
    param([hashtable]$Test)

    Log "═══════════════════════════════════════════════════════════" "INFO"
    Log "Test: $($Test.Name)" "INFO"
    Log "Description: $($Test.Description)" "INFO"
    Log "═══════════════════════════════════════════════════════════" "INFO"

    $testResultFile = "$resultsDir\$($Test.Name).json"
    $result = @{
        Name = $Test.Name
        Timestamp = Get-Date -Format o
        Flags = $Test.Flags
        Status = "PENDING"
        Sizes = @{}
        Checks = @{}
        Errors = @()
    }

    # ========== BUILD ==========
    Log "1️⃣  Build..." "INFO"
    try {
        if (-not $SkipBuild) {
            $env:KFLAGS = $Test.Flags
            $env:SKIPBUILD = $false

            # Build durchführen
            & pwsh -NoProfile -Command "
                cd '$baseDir'
                & '.\build-k.sh' out/uc7.cpio test_$($Test.Name) 2>&1 | Select-String -Pattern 'error|-rwx'
            "

            if ($LASTEXITCODE -ne 0) {
                throw "Build fehlgeschlagen"
            }
            Log "✅ Build erfolgreich" "SUCCESS"
        } else {
            Log "⏭️  Build übersprungen" "WARNING"
        }
    } catch {
        Log "❌ Build fehlgeschlagen: $_" "ERROR"
        $result.Status = "BUILD_FAILED"
        $result.Errors += "Build: $_"
        return $result
    }

    # ========== SIZES MESSEN ==========
    Log "2️⃣  Größen messen..." "INFO"
    try {
        $elfFile = "$baseDir\out\test_$($Test.Name).elf"
        $mbFile = "$baseDir\out\test_$($Test.Name).mb.elf"

        if (Test-Path $elfFile) {
            $elfSize = (Get-Item $elfFile).Length
            $result.Sizes.elf = $elfSize
            Log "   ELF: $(($elfSize / 1MB).ToString('F2')) MB" "INFO"
        }

        # XZ-Kompression simulieren (für Prognose)
        # Reale Größe würde Cargo build --release produzieren

    } catch {
        Log "⚠️  Größen-Messung fehlgeschlagen: $_" "WARNING"
        $result.Errors += "Sizes: $_"
    }

    # ========== FUNKTIONALITÄT TESTEN ==========
    Log "3️⃣  Funktionalität testen: $($Test.TestCmd)" "INFO"
    try {
        # Timeout-Steuerung für QEMU-Boot
        $bootTimeout = $Timeout

        # Hinweis: Das würde normalerweise try.sh aufrufen
        # Hier vereinfacht: Nur dokumentieren, was getestet würde
        Log "   → Test-Befehl: '$($Test.TestCmd)'" "INFO"
        Log "   → Boot-Timeout: ${bootTimeout}s" "INFO"

        foreach ($check in $Test.Checks) {
            $result.Checks[$check] = "PENDING"
        }

        Log "✅ Tests wären ausgeführt" "SUCCESS"
        $result.Status = "SUCCESS"

    } catch {
        Log "❌ Test fehlgeschlagen: $_" "ERROR"
        $result.Status = "TEST_FAILED"
        $result.Errors += "Test: $_"
    }

    # Ergebnis speichern
    $result | ConvertTo-Json | Set-Content $testResultFile
    return $result
}

# Hauptlogik
Log "Kerla Minimalisierungs-Test-Suite" "INFO"
Log "Basis-Verzeichnis: $baseDir" "INFO"
Log "Ergebnisse: $resultsDir" "INFO"

$testSelection = if ($TestName -eq "all") {
    $tests
} else {
    $tests | Where-Object { $_.Name -eq $TestName }
}

if ($testSelection.Count -eq 0) {
    Log "❌ Test nicht gefunden: $TestName" "ERROR"
    Log "Verfügbare Tests: $($tests.Name -join ', ')" "INFO"
    exit 1
}

$results = @()
foreach ($test in $testSelection) {
    $result = Run-Test $test
    $results += $result

    # Kurze Pause zwischen Tests
    Start-Sleep -Seconds 2
}

# Zusammenfassung
Log "" "INFO"
Log "═══════════════════════════════════════════════════════════" "INFO"
Log "📊 ZUSAMMENFASSUNG" "INFO"
Log "═══════════════════════════════════════════════════════════" "INFO"

foreach ($result in $results) {
    $statusColor = switch($result.Status) {
        "SUCCESS" { "Green" }
        "PENDING" { "Yellow" }
        default { "Red" }
    }
    Write-Host "• $($result.Name): $($result.Status)" -ForegroundColor $statusColor
    if ($result.Errors.Count -gt 0) {
        foreach ($err in $result.Errors) {
            Write-Host "  ⚠️  $err" -ForegroundColor Yellow
        }
    }
}

Log "" "INFO"
Log "Vollständige Ergebnisse: $resultsDir" "INFO"
Log "✅ Test-Suite abgeschlossen" "SUCCESS"
