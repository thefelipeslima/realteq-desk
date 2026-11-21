# Sobe a versao automaticamente: 0.9.1 ... 0.9.9, 0.10, 0.11, ...
# NUNCA gera 1.0 sozinho: a 1.0 so com OK do usuario (use -Para 1.0.0 depois do OK).
param([string]$Para = '')
$raiz = Split-Path $PSScriptRoot -Parent
$dart = Join-Path $raiz 'flutter\lib\realteq\version.dart'
$yml  = Join-Path $raiz '.github\workflows\realteq-windows.yml'
$atual = ([regex]::Match((Get-Content $dart -Raw), "kRealteqVersion = '([^']+)'")).Groups[1].Value
if ($Para) { $novo = $Para }
else {
  $p = $atual.Split('.'); $maj=[int]$p[0]; $min=[int]$p[1]; $pat= if ($p.Length -gt 2) {[int]$p[2]} else {0}
  if ($maj -ne 0) { Write-Host "Versao $atual ja passou de 0.x; defina manualmente com -Para."; exit 1 }
  if ($min -ge 10) { $min++; $novo = "0.$min" }
  elseif ($pat -lt 9) { $pat++; $novo = "0.$min.$pat" }
  else { $min++; $novo = if ($min -ge 10) { "0.$min" } else { "0.$min.0" } }
}
if ($novo -eq '1.0' -or $novo -like '1.0.*') { if (-not $Para) { Write-Host 'Bloqueado: 1.0 precisa de OK do usuario.'; exit 1 } }
(Get-Content $dart -Raw) -replace "kRealteqVersion = '[^']+'", "kRealteqVersion = '$novo'" | Set-Content $dart -NoNewline
(Get-Content $yml -Raw) -replace '(?m)^  VERSION: "[^"]+"', "  VERSION: `"$novo`"" | Set-Content $yml -NoNewline
Write-Host "Versao: $atual -> $novo"
