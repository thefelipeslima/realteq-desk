# Backup da ultima versao que deu certo. Uso: powershell -File backup\salvar-backup.ps1
# Regra: so rodar DEPOIS de build/mudanca confirmada OK. Mantem "ultima-ok" e "anterior".
$raiz = Split-Path $PSScriptRoot -Parent
$ok = Join-Path $PSScriptRoot 'ultima-ok'
$ant = Join-Path $PSScriptRoot 'anterior'
if (Test-Path $ok) {
  if (Test-Path $ant) { Remove-Item $ant -Recurse -Force }
  Rename-Item $ok $ant
}
robocopy $raiz $ok /E /XD target backup /R:2 /W:2 /NFL /NDL /NJH /NP | Out-Null
if ($LASTEXITCODE -ge 8) { Write-Host "ERRO no backup (codigo $LASTEXITCODE)"; exit 1 }
Set-Content (Join-Path $ok 'BACKUP-INFO.txt') ("Backup em " + (Get-Date) + "`ncommit: " + (git -C $raiz log --oneline -1))
Write-Host "Backup OK em $ok"
