# Baut dist\quark-demo.zip aus dem Kernel, den Python-Paketen und den Plugins.
$ErrorActionPreference = 'Stop'
$here = $PSScriptRoot
$cli = Join-Path $here '..\quark-cli\out'
$dist = Join-Path $here 'dist\quark-demo'
if (Test-Path $dist) { Remove-Item $dist -Recurse -Force }
New-Item -ItemType Directory -Force "$dist\kernel", "$dist\packages", "$dist\plugins", "$dist\lib" | Out-Null
Copy-Item (Join-Path $cli 'cli-net.elf') "$dist\kernel\quark.elf"
Copy-Item (Join-Path $cli 'q.pipe') "$dist\q"
# Pakete: python3 und seine Abhaengigkeiten laut idx
$idx = Get-Content (Join-Path $cli 'srv-gross\idx')
$line = $idx | Where-Object { $_ -match '^python3="' }
$deps = (($line -replace '^python3="', '') -replace '"$', '') -split '\s+' | Where-Object { $_ } | Select-Object -Skip 1
$names = @($deps) + 'python3'
foreach ($n in $names) { Copy-Item (Join-Path $cli "srv-gross\$n.apk") "$dist\packages\" }
$keep = $idx | Where-Object { $n = ($_ -split '=')[0]; $names -contains $n }
[IO.File]::WriteAllText("$dist\packages\idx", (($keep -join "`n") + "`n"))
Copy-Item "$here\plugins\fraktal.py", "$here\plugins\bericht.py" "$dist\plugins\"
Copy-Item "$here\lib\vm.ps1", "$here\lib\pkgserver.ps1" "$dist\lib\"
Copy-Item "$here\start-demo.ps1" "$dist\"
Copy-Item "$here\README-demo.txt" "$dist\README.txt"
$zip = Join-Path $here 'dist\quark-demo.zip'
if (Test-Path $zip) { Remove-Item $zip }
Compress-Archive -Path "$dist\*" -DestinationPath $zip
"{0}: {1:N1} MB, {2} Pakete" -f $zip, ((Get-Item $zip).Length / 1MB), $names.Count
