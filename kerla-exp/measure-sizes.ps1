# Phase 3d: Größenmessungen der verschiedenen Feature-Kombinationen
# Extrahiert die stripped binary-Größen aus den Docker-Builds

Write-Host "`n=== Phase 3d: ELF-Größenmessungen ===" -ForegroundColor Cyan

$Configurations = @("baseline", "q_only", "minimal_shell", "kernel_only")
$Sizes = @{}

# Größen von den Docker Images extrahieren
foreach ($config in $Configurations) {
    $imageName = "kerla:$config"
    
    Write-Host "`nMessung für $config..." -ForegroundColor Green
    
    # Versuche, den Container auszuführen und die Größe zu messen
    $output = & docker run --rm $imageName sh -c "ls -lh /w/kerla_$($config).stripped 2>/dev/null || echo 'Not found'" 2>&1
    
    if ($output -match "(\d+)\s+(\w+)\s+(\w+)\s+(\w+)\s+(\d+)\s+") {
        $sizeBytes = $Matches[5]
        $sizeKB = [math]::Round($sizeBytes / 1024, 2)
        $sizeMB = [math]::Round($sizeBytes / (1024 * 1024), 3)
        
        $Sizes[$config] = @{
            Bytes = $sizeBytes
            KB = $sizeKB
            MB = $sizeMB
        }
        
        Write-Host "  ✅ $config: $sizeMB MB ($sizeKB KB)" -ForegroundColor Cyan
    } else {
        Write-Host "  ❌ Größe konnte nicht gemessen werden" -ForegroundColor Red
    }
}

# Größenvergleiche
Write-Host "`n╔════════════════════════════════════════════════════════╗" -ForegroundColor Yellow
Write-Host "║              ELF-Größenvergleich                       ║" -ForegroundColor Yellow
Write-Host "╚════════════════════════════════════════════════════════╝`n" -ForegroundColor Yellow

if ($Sizes.Count -gt 0) {
    $baselineSize = $Sizes["baseline"].Bytes
    
    # Tabelle mit Größen und Einsparungen
    Write-Host "Configuration        | Bytes      | KB       | MB     | Einsparung" -ForegroundColor Cyan
    Write-Host "─────────────────────┼────────────┼──────────┼────────┼────────────" -ForegroundColor Cyan
    
    $Sizes.GetEnumerator() | Sort-Object -Property {$_.Value.Bytes} -Descending | ForEach-Object {
        $config = $_.Key
        $bytes = $_.Value.Bytes
        $kb = $_.Value.KB
        $mb = $_.Value.MB
        
        if ($config -ne "baseline" -and $baselineSize -gt 0) {
            $savings = [math]::Round(($baselineSize - $bytes) / $baselineSize * 100, 1)
            $savingsStr = "$savings%"
        } else {
            $savingsStr = "─ (baseline)"
        }
        
        Write-Host "$config".PadRight(20) "| $bytes".PadRight(11) "| $kb".PadRight(9) "| $mb".PadRight(7) "| $savingsStr" -ForegroundColor White
    }
    
    Write-Host "`nZusammenfassung:" -ForegroundColor Yellow
    Write-Host "  • baseline (alle Features): $(($Sizes['baseline'].MB)) MB"
    
    if ($Sizes["q_only"]) {
        $q_only_saving = [math]::Round(($baselineSize - $Sizes["q_only"].Bytes) / $baselineSize * 100, 1)
        Write-Host "  • q_only (socket,connect,filesystem,process,system): $($Sizes['q_only'].MB) MB (-$q_only_saving%)"
    }
    
    if ($Sizes["minimal_shell"]) {
        $minimal_saving = [math]::Round(($baselineSize - $Sizes["minimal_shell"].Bytes) / $baselineSize * 100, 1)
        Write-Host "  • minimal_shell (signals,sessions,filesystem,process,system): $($Sizes['minimal_shell'].MB) MB (-$minimal_saving%)"
    }
    
    if ($Sizes["kernel_only"]) {
        $kernel_saving = [math]::Round(($baselineSize - $Sizes["kernel_only"].Bytes) / $baselineSize * 100, 1)
        Write-Host "  • kernel_only (no optional features): $($Sizes['kernel_only'].MB) MB (-$kernel_saving%)"
    }
    
} else {
    Write-Host "⚠️  Keine Größenmessungen verfügbar. Docker-Builds bitte zuerst ausführen." -ForegroundColor Yellow
}

Write-Host "`n=== Phase 3d Abgeschlossen ===" -ForegroundColor Green
