QUARK-DEMO
==========
Eine Linux-VM, die als einzelne Datei von rund 450 KB startet (kernel\quark.elf), laedt Python nach
und rechnet zwei sichtbare Ergebnisse: ein Fraktal-Bild und einen Bericht mit Diagramm.

Ehrlich dazu: Die 450 KB gelten nur fuer die VM selbst. Die Demo bringt zusaetzlich rund 20 MB Python-Pakete
(Ordner packages) mit; die VM laedt sie beim Start von diesem Ordner nach. Das Ganze dauert etwa eine Minute.

Voraussetzungen
  - PowerShell 7 (pwsh)
  - QEMU (Windows: winget install SoftwareFreedomConservancy.QEMU)
  - 256 MB freier Arbeitsspeicher

Starten
  pwsh -ExecutionPolicy Bypass -File start-demo.ps1

Kommt eine Warnung wegen "aus dem Internet heruntergeladen"? Dann vorher einmal:
  Get-ChildItem -Recurse | Unblock-File

Ergebnis: Ordner ergebnis\ (index.html wird im Browser geoeffnet). Die Demo schreibt nur in diesen Ordner
und in den Temp-Ordner und beendet VM und Dateiserver am Ende selbst.
