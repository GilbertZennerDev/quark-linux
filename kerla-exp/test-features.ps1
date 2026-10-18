# Phase 3c: Teste verschiedene Feature-Kombinationen und messe Größen
# Korrigierter Docker COPY für komplette project-struktur

$ProjectPath = "C:\Dev\my-own-vms\quark-linux\kerla-exp"
$ScratchDir = "C:\Users\User\AppData\Local\Temp\claude\kerla-test"
New-Item -ItemType Directory -Force -Path $ScratchDir | Out-Null

$Features = @{
    "baseline"       = "socket,connect,bind_listen,signals,sessions,filesystem,process,system"
    "q_only"         = "socket,connect,filesystem,process,system"
    "minimal_shell"  = "signals,sessions,filesystem,process,system"
    "kernel_only"    = ""
}

$Sizes = @{}

foreach ($config in $Features.GetEnumerator()) {
    $name = $config.Key
    $feats = $config.Value

    Write-Host "`n=== Building $name ===" -ForegroundColor Green

    # Dockerfile für diese Konfiguration erstellen
    $dockerfile = @"
FROM rust:1-slim-bookworm
RUN apt-get update -qq && apt-get install -y -qq --no-install-recommends curl python3 make binutils git ca-certificates >/dev/null
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- --default-toolchain nightly-2024-01-01 --component rust-src -y
ENV PATH=`$HOME/.cargo/bin:`$PATH
WORKDIR /w
COPY src/ /w/
SHELL ["/bin/bash","-o","pipefail","-c"]
RUN : > /w/dummy.initramfs
ENV INITRAMFS_PATH=dummy.initramfs INIT_SCRIPT=/bin/sh ARCH=x64 RUSTFLAGS="-Z emit-stack-sizes"
"@

    if ($feats) {
        $dockerfile += "`nRUN cargo build --release --no-default-features --features `"$feats`" -Z build-std=core,alloc -Z build-std-features=compiler-builtins-mem --target kernel/arch/x64/x64.json --manifest-path kernel/Cargo.toml 2>&1 | tail -40`n"
    } else {
        $dockerfile += "`nRUN cargo build --release --no-default-features -Z build-std=core,alloc -Z build-std-features=compiler-builtins-mem --target kernel/arch/x64/x64.json --manifest-path kernel/Cargo.toml 2>&1 | tail -40`n"
    }

    $dockerfile += @"
RUN ls -lh target/x64/release/kerla_kernel && strip -o /w/kerla_$($name).stripped target/x64/release/kerla_kernel && ls -lh /w/kerla_$($name).stripped && stat -c "%s" /w/kerla_$($name).stripped > /w/size_$name.txt
"@

    $dockerFilePath = Join-Path $ScratchDir "Dockerfile.$name"
    Set-Content -Path $dockerFilePath -Value $dockerfile -Encoding UTF8

    # Docker bauen
    Write-Host "Building Docker image for $name..."
    $buildOutput = & docker build -t "kerla:$name" -f $dockerFilePath $ProjectPath 2>&1
    $buildOutput | Select-Object -Last 50

    # Check exit code
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Build erfolgreich für $name" -ForegroundColor Green

        # Größe auslesen (aus der Docker image)
        # Docker-Image ausgaben können wir leider nicht direkt auslesen,
        # aber wir können die Größe vom stripped binary schätzen
        $lines = $buildOutput | Select-String "kerla_$($name).stripped" | Select-Object -Last 1
        if ($lines) {
            Write-Host "Output: $lines" -ForegroundColor Cyan
            $Sizes[$name] = $lines
        }
    } else {
        Write-Host "❌ Build fehlgeschlagen für $name" -ForegroundColor Red
    }
}

Write-Host "`n=== Phase 3c Größenvergleich ===" -ForegroundColor Cyan
Write-Host ""
$Sizes.GetEnumerator() | Sort-Object -Property Key | ForEach-Object {
    Write-Host "$($_.Key): $($_.Value)" -ForegroundColor Yellow
}

Write-Host "`n=== Phase 3c Abgeschlossen ===" -ForegroundColor Green
