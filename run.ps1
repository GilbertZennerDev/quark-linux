#requires -Version 7
<#
.SYNOPSIS
    Interactive launcher for the quark-linux VM (PowerShell 7).

.DESCRIPTION
    Runs qemu-system-x86_64 with its console fully piped through this script
    instead of sharing the host console directly. That fixes two problems
    the old one-liner had:

      1. Ctrl+C used to be swallowed by QEMU's raw serial console and sent
         straight into the guest as a literal ^C. The shell runs as PID 1
         in this image (/init execs BusyBox sh), so that SIGINTs init and
         panics the kernel ("Attempted to kill init!"). Now Ctrl+C is caught
         by PowerShell instead and cleanly kills the VM from the host side.
      2. If the terminal was closed or crashed, qemu-system-x86_64.exe could
         be left running invisibly in the background (we found over a dozen
         orphaned copies doing this). A try/finally here guarantees the
         process is killed whenever this script exits, however it exits.

    QEMU's own escape sequence still works too: press Ctrl-A then X to make
    QEMU quit itself cleanly. Note this VM has no ACPI poweroff support, so
    typing "poweroff -f"/"reboot -f" inside the guest just halts the kernel
    without actually closing the qemu-system-x86_64.exe process - use Ctrl-A
    X or Ctrl+C from here to actually end the session.
#>

$ErrorActionPreference = 'Stop'

$Qemu = 'C:\Program Files\qemu\qemu-system-x86_64.exe'
$Dir  = $PSScriptRoot

$QemuArgs = @(
    '-kernel', (Join-Path $Dir 'dist/vmlinuz'),
    '-initrd', (Join-Path $Dir 'dist/initramfs.cpio.xz'),
    '-machine', 'microvm,acpi=off', '-nodefaults', '-append', 'console=ttyS0',
    '-m', '128',
    '-netdev', "user,id=n,hostfwd=tcp:127.0.0.1:2222-:22", '-device', 'virtio-net-device,netdev=n',
    '-no-reboot',
    '-display', 'none',
    '-serial', 'stdio'
)

if (-not (Test-Path $Qemu)) {
    Write-Error "QEMU not found at '$Qemu'"
    exit 1
}

$psi = [System.Diagnostics.ProcessStartInfo]::new()
$psi.FileName = $Qemu
foreach ($a in $QemuArgs) { $psi.ArgumentList.Add($a) }
$psi.RedirectStandardInput  = $true
$psi.RedirectStandardOutput = $true
$psi.RedirectStandardError  = $true
$psi.UseShellExecute = $false

$proc = [System.Diagnostics.Process]::new()
$proc.StartInfo = $psi
$proc.Start() | Out-Null

# Stream qemu's output back to us in real time (char-by-char, not line-
# buffered, so prompts with no trailing newline still show up immediately).
$stopStreaming = [System.Threading.CancellationTokenSource]::new()
$pumpOutput = {
    param($reader, [System.Threading.CancellationToken]$token)
    $buf = New-Object char[] 256
    while (-not $token.IsCancellationRequested) {
        $n = 0
        try { $n = $reader.Read($buf, 0, $buf.Length) } catch { break }
        if ($n -le 0) { break }
        [Console]::Out.Write($buf, 0, $n)
    }
}
$outTask = [System.Threading.Tasks.Task]::Run([action]{ & $pumpOutput $proc.StandardOutput $stopStreaming.Token })
$errTask = [System.Threading.Tasks.Task]::Run([action]{ & $pumpOutput $proc.StandardError  $stopStreaming.Token })

function Stop-Vm {
    $stopStreaming.Cancel()
    try {
        if (-not $proc.HasExited) {
            $proc.Kill($true)
            $proc.WaitForExit(5000) | Out-Null
        }
    } catch {}
}

Write-Host "=== quark-linux VM starting. Ctrl+C = quit VM. Ctrl-A then X = QEMU's own quit. ===" -ForegroundColor Cyan

# Ctrl+C is host-intercepted (not forwarded to the guest) so it can no longer
# accidentally panic the kernel by killing PID 1 inside the VM.
$cancelHandler = {
    $_.Cancel = $true
    Write-Host "`n[Ctrl+C] stopping VM..." -ForegroundColor Yellow
}
$sub = Register-ObjectEvent -InputObject ([Console]) -EventName CancelKeyPress -Action $cancelHandler

try {
    while (-not $proc.HasExited) {
        if ([Console]::IsInputRedirected) {
            Start-Sleep -Milliseconds 200   # headless: no keyboard, just wait for qemu
        } elseif ([Console]::KeyAvailable) {
            $key = [Console]::ReadKey($true)
            if ($key.Modifiers -band [ConsoleModifiers]::Control -and $key.Key -eq 'C') {
                # Belt-and-braces: if CancelKeyPress didn't fire for some
                # reason, treat Ctrl+C read as a plain key the same way.
                break
            }
            $ch = switch ($key.Key) {
                'Enter'     { "`n" }
                'Backspace' { [char]0x7F }
                'Tab'       { "`t" }
                default     { $key.KeyChar }
            }
            if ($ch) {
                $proc.StandardInput.Write($ch)
                $proc.StandardInput.Flush()
            }
        } else {
            Start-Sleep -Milliseconds 20
        }
    }
}
finally {
    Unregister-Event -SourceIdentifier $sub.Name -ErrorAction SilentlyContinue
    Stop-Vm
    Write-Host "`n=== quark-linux VM stopped. ===" -ForegroundColor Cyan
}
