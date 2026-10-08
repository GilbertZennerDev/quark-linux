#requires -Version 7
<#
.SYNOPSIS
    Boots quark-linux headless in QEMU and proves in the terminal that it is usable.

.DESCRIPTION
    Drives the VM through its serial console (stdin/stdout pipes), runs a series
    of checks, shows the guest's live output in grey, and prints a pass/fail
    report. Checks: image size, boot, kernel, RAM, DHCP network, SSH banner on
    the forwarded port, and the on-demand `q` flow (install, run, remove).

.PARAMETER SkipNetwork
    Skip the checks that need internet access (the `q` install/run/remove test).

.PARAMETER Package
    Package used for the `q` test, as pkg[:bin]. Default jq:jq.

.PARAMETER SshPort
    Host port forwarded to the guest's SSH (default 2222).

.PARAMETER KeepOpen
    After the tests, leave the VM running and drop into the interactive run.ps1
    style console instead of shutting it down.
#>
[CmdletBinding()]
param(
    [switch]$SkipNetwork,
    [string]$Package = 'jq:jq',
    [int]$SshPort = 2222,
    [switch]$KeepOpen
)

$ErrorActionPreference = 'Stop'
$Qemu = 'C:\Program Files\qemu\qemu-system-x86_64.exe'
$Dir  = $PSScriptRoot
$Kernel = Join-Path $Dir 'dist/vmlinuz'
$Initrd = Join-Path $Dir 'dist/initramfs.cpio.xz'

$script:Results = [System.Collections.Generic.List[object]]::new()
$script:Acc     = ''          # guest text received but not yet consumed
$script:Partial = ''          # incomplete trailing line, not yet printed
$script:Readers = @()
$script:Proc    = $null

function Write-Rule([string]$Text) {
    $line = '─' * 66
    Write-Host ''
    Write-Host $line -ForegroundColor DarkCyan
    Write-Host "  $Text" -ForegroundColor Cyan
    Write-Host $line -ForegroundColor DarkCyan
}

function Show-GuestLine([string]$Line) {
    $clean = ($Line -replace '\x1b\[[0-9;?]*[A-Za-z]', '') -replace '\r', ''
    if ($clean.Trim().Length -eq 0) { return }
    Write-Host "    │ $clean" -ForegroundColor DarkGray
}

# Pull queued guest output into $script:Acc and echo whole lines in grey.
function Update-Guest {
    # Async reads polled from this thread (no background runspace needed).
    foreach ($rd in $script:Readers) {
        while ($true) {
            if (-not $rd.T) { $rd.T = $rd.R.ReadAsync($rd.B, 0, $rd.B.Length) }
            if (-not $rd.T.IsCompleted) { break }
            $n = $rd.T.IsFaulted ? 0 : $rd.T.Result
            $rd.T = $null
            if ($n -le 0) { break }
            $chunk = [string]::new($rd.B, 0, $n)
            $script:Acc     += $chunk
            $script:Partial += $chunk
        }
    }
    while (($i = $script:Partial.IndexOf("`n")) -ge 0) {
        Show-GuestLine $script:Partial.Substring(0, $i)
        $script:Partial = $script:Partial.Substring($i + 1)
    }
}

function Wait-Guest([string]$Pattern, [int]$TimeoutSec = 30) {
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt $TimeoutSec) {
        Update-Guest
        $m = [regex]::Match($script:Acc, $Pattern)
        if ($m.Success) {
            $before = $script:Acc.Substring(0, $m.Index)
            $script:Acc = $script:Acc.Substring($m.Index + $m.Length)
            return [pscustomobject]@{ Match = $m; Before = $before }
        }
        if ($script:Proc.HasExited) { throw 'QEMU exited unexpectedly.' }
        Start-Sleep -Milliseconds 25
    }
    throw "Timed out after ${TimeoutSec}s waiting for /$Pattern/"
}

function Send-Guest([string]$Text) {
    # The emulated 16550 has no flow control; feeding it a char at a time keeps it from dropping input.
    foreach ($ch in $Text.ToCharArray()) {
        $script:Proc.StandardInput.Write($ch)
        $script:Proc.StandardInput.Flush()
        Start-Sleep -Milliseconds 4
        Update-Guest
    }
}

# Run a shell command in the guest; returns exit code and its output lines.
function Invoke-Guest([string]$Command, [int]$TimeoutSec = 30) {
    Send-Guest "$Command; echo QDONE`$?`n"
    $r = Wait-Guest 'QDONE(\d+)' $TimeoutSec
    # Drop the echoed command line (everything up to our marker echo) and stray kernel messages.
    $out = $r.Before
    $k = $out.IndexOf('QDONE$?')
    if ($k -ge 0) { $out = $out.Substring($k + 7) }
    $lines = $out -split "`r?`n" |
        Where-Object { $_.Trim() -and $_ -notmatch 'QDONE|^quark# |^(e1000|random|clocksource|input):' } |
        ForEach-Object { ($_ -replace '\x1b\[[0-9;?]*[A-Za-z]', '').Trim() }
    [pscustomobject]@{ Code = [int]$r.Match.Groups[1].Value; Lines = @($lines); Text = ($lines -join "`n") }
}

# Run one check with a header, timing, and a ✓/✗ line.
function Step([string]$Name, [scriptblock]$Body) {
    Write-Host ''
    Write-Host "  ▶ $Name" -ForegroundColor White
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        $r = & $Body
        $ok = [bool]$r.Ok; $detail = $r.Detail
    } catch {
        $ok = $false; $detail = $_.Exception.Message
    }
    $sw.Stop()
    $secs = '{0:N1}s' -f $sw.Elapsed.TotalSeconds
    if ($ok) { Write-Host "  ✓ $Name" -ForegroundColor Green -NoNewline }
    else     { Write-Host "  ✗ $Name" -ForegroundColor Red   -NoNewline }
    Write-Host "  $detail  ($secs)" -ForegroundColor DarkYellow
    $script:Results.Add([pscustomobject]@{ Name = $Name; Ok = $ok; Detail = $detail; Secs = $secs })
}

function Stop-Vm {
    try {
        if ($script:Proc -and -not $script:Proc.HasExited) {
            $script:Proc.Kill($true)
            $script:Proc.WaitForExit(5000) | Out-Null
        }
    } catch {}
}

# ---------------------------------------------------------------- preflight
Write-Rule 'quark-linux  ·  VM self-test'

foreach ($f in @($Qemu, $Kernel, $Initrd)) {
    if (-not (Test-Path $f)) { Write-Host "Missing: $f" -ForegroundColor Red; exit 1 }
}
$busy = Get-NetTCPConnection -LocalPort $SshPort -State Listen -ErrorAction SilentlyContinue
if ($busy) {
    Write-Host "Port $SshPort is already in use (another VM running?). Use -SshPort or stop it." -ForegroundColor Red
    exit 1
}

$results = $script:Results
$totalWatch = [System.Diagnostics.Stopwatch]::StartNew()

try {
    Step 'Image size' {
        $k = (Get-Item $Kernel).Length; $i = (Get-Item $Initrd).Length
        $total = $k + $i
        [pscustomobject]@{
            Ok     = $total -lt 5MB
            Detail = ('kernel {0:N0} KB + initramfs {1:N0} KB = {2:N2} MB' -f ($k/1KB), ($i/1KB), ($total/1MB))
        }
    }

    # ------------------------------------------------------------------ boot
    $psi = [System.Diagnostics.ProcessStartInfo]::new()
    $psi.FileName = $Qemu
    foreach ($a in @('-kernel', $Kernel, '-initrd', $Initrd, '-machine', 'microvm,acpi=off', '-nodefaults', '-append', 'console=ttyS0',
                     '-m', '128', '-netdev', "user,id=n,hostfwd=tcp:127.0.0.1:${SshPort}-:22", '-device', 'virtio-net-device,netdev=n',
                     '-no-reboot', '-display', 'none', '-serial', 'stdio')) { $psi.ArgumentList.Add($a) }
    $psi.RedirectStandardInput = $psi.RedirectStandardOutput = $psi.RedirectStandardError = $true
    $psi.UseShellExecute = $false
    $script:Proc = [System.Diagnostics.Process]::new()
    $script:Proc.StartInfo = $psi

    Step 'Boot to shell (128 MB RAM)' {
        $script:Proc.Start() | Out-Null
        $script:Readers = @(
            @{ R = $script:Proc.StandardOutput; B = [char[]]::new(512); T = $null },
            @{ R = $script:Proc.StandardError;  B = [char[]]::new(512); T = $null }
        )

        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        Wait-Guest 'quark# ' 60 | Out-Null          # wait for the prompt, send nothing while booting
        Start-Sleep -Milliseconds 700               # let late boot messages settle
        Update-Guest
        Send-Guest "echo QRE''ADY`n"
        Wait-Guest 'QREADY' 10 | Out-Null
        [pscustomobject]@{ Ok = $true; Detail = ('shell answered after {0:N1}s' -f $sw.Elapsed.TotalSeconds) }
    }

    if ($script:Results[-1].Ok) {
        Step 'Kernel' {
            $r = Invoke-Guest 'uname -srm'
            [pscustomobject]@{ Ok = ($r.Code -eq 0 -and $r.Text -match 'Linux'); Detail = $r.Text }
        }

        Step 'Memory' {
            $r = Invoke-Guest "grep -E '^(MemTotal|MemAvailable)' /proc/meminfo"
            $mb = $r.Lines | ForEach-Object { if ($_ -match '^(\w+):\s+(\d+)') { '{0} {1:N0} MB' -f $Matches[1], ($Matches[2] / 1024) } }
            [pscustomobject]@{ Ok = ($r.Code -eq 0 -and $r.Text -match 'MemTotal'); Detail = ($mb -join ' · ') }
        }

        Step 'Userland (BusyBox)' {
            $r = Invoke-Guest 'busybox | head -n 1; ls /bin | wc -l'
            [pscustomobject]@{ Ok = ($r.Code -eq 0 -and $r.Text -match 'BusyBox'); Detail = ($r.Lines -join ' · ') }
        }

        Step 'Network (DHCP address)' {
            $r = Invoke-Guest "ip -4 addr show 2>/dev/null | grep -o 'inet [0-9.]*' | grep -v ' 127\.'" 20
            [pscustomobject]@{ Ok = ($r.Code -eq 0 -and $r.Text -match 'inet \d'); Detail = ($r.Text -replace "`n", ', ') }
        }

        Step "SSH banner via 127.0.0.1:$SshPort" {
            $banner = $null
            for ($try = 0; $try -lt 10 -and -not $banner; $try++) {
                try {
                    $c = [System.Net.Sockets.TcpClient]::new()
                    $c.ReceiveTimeout = 2000
                    $c.Connect('127.0.0.1', $SshPort)
                    $rd = [System.IO.StreamReader]::new($c.GetStream())
                    $banner = $rd.ReadLine()
                    $c.Dispose()
                } catch { Start-Sleep -Milliseconds 500 }
                Update-Guest
            }
            [pscustomobject]@{ Ok = ($banner -match '^SSH-2\.0'); Detail = "$banner" }
        }

        if ($SkipNetwork) {
            Write-Host "`n  – skipped internet tests (-SkipNetwork)" -ForegroundColor DarkYellow
        } else {
            $bin = ($Package -split ':')[-1]
            $cmd = "q $Package --version"

            Step 'On-demand program: apk starts absent' {
                $r = Invoke-Guest 'command -v apk || echo none'
                [pscustomobject]@{ Ok = ($r.Text -match 'none'); Detail = 'fresh boot has no package manager' }
            }

            Step "q $Package  (install → run → remove)" {
                $r = Invoke-Guest $cmd 180
                $ver = $r.Lines | Select-Object -Last 1
                [pscustomobject]@{ Ok = ($r.Code -eq 0); Detail = "program said: $ver" }
            }

            Step 'Clean-up: nothing left installed' {
                $r = Invoke-Guest "command -v $bin || echo gone; command -v apk || echo apkgone"
                [pscustomobject]@{
                    Ok     = ($r.Text -match 'gone' -and $r.Text -match 'apkgone')
                    Detail = "$bin removed, apk deleted again after q"
                }
            }
        }
    }
}
catch {
    Write-Host "`n  Test run aborted: $($_.Exception.Message)" -ForegroundColor Red
    $script:Results.Add([pscustomobject]@{ Name = 'Run'; Ok = $false; Detail = $_.Exception.Message; Secs = '' })
}
finally {
    Update-Guest
    if (-not $KeepOpen) { Stop-Vm }
}

# ------------------------------------------------------------------ report
Write-Rule 'Report'
foreach ($r in $script:Results) {
    $mark  = $r.Ok ? '✓' : '✗'
    $color = $r.Ok ? 'Green' : 'Red'
    Write-Host ("  {0} {1,-40} {2,6}" -f $mark, $r.Name, $r.Secs) -ForegroundColor $color
}
$pass = @($script:Results | Where-Object Ok).Count
$all  = $script:Results.Count
$totalWatch.Stop()
Write-Host ''
$final = $pass -eq $all ? 'Green' : 'Red'
Write-Host ("  {0}/{1} checks passed in {2:N1}s" -f $pass, $all, $totalWatch.Elapsed.TotalSeconds) -ForegroundColor $final
if ($pass -eq $all) { Write-Host '  quark-linux is usable. ✔' -ForegroundColor Green }
Write-Host ''

if ($KeepOpen -and $script:Proc -and -not $script:Proc.HasExited) {
    Write-Host "  VM still running (ssh -p $SshPort root@127.0.0.1). Press Enter to stop it." -ForegroundColor Cyan
    try { Read-Host | Out-Null } finally { Stop-Vm }
}
exit ($pass -eq $all ? 0 : 1)
