# Beschreibt ein Bild ueber den lokalen Qwen-Captioner (Pinokio, Port 7860). Aufruf: pwsh caption.ps1 <Bild> [Frage]
param([Parameter(Mandatory)][string]$File, [string]$Question = 'Describe this image briefly: shapes, colors, background, any text.')
$q = 'http://127.0.0.1:7860'
$up = & curl.exe -s -F "files=@$File" "$q/gradio_api/upload"
$remote = @($up | ConvertFrom-Json)[0]
$payload = @{ data = @(@{ path = $remote; meta = @{ _type = 'gradio.FileData' } }, 'Custom', $Question, 512) } | ConvertTo-Json -Depth 6
$ev = Invoke-RestMethod "$q/gradio_api/call/caption_image" -Method Post -ContentType 'application/json' -Body $payload
$raw = & curl.exe -s -N "$q/gradio_api/call/caption_image/$($ev.event_id)"
$line = ($raw -split "`n" | Where-Object { $_ -like 'data:*' } | Select-Object -Last 1) -replace '^data:\s*', ''
($line | ConvertFrom-Json) -join "`n"
