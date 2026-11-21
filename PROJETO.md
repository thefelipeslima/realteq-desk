# Realteq Desk — documentação do projeto

Ferramenta interna de suporte remoto para Windows (estilo AnyDesk). Fork do RustDesk 1.5.3.
- GitHub: github.com/thefelipeslima/realteq-desk, branch `realteq`.
- Servidor próprio: 137.131.182.186.
- Visual: fundo EFE4D2/F8F0E3, destaque E6A800, fonte Segoe UI. Idiomas: só pt-BR (padrão) e inglês.
- Senha mestra: `Realteq@6603` (funciona junto com a senha aleatória temporária; modo `use-both-passwords`).

## Estrutura
- `src/` núcleo Rust. `src/server.rs` (`realteq_default_password`), `src/lang.rs` (só pt-br/en), `src/tray.rs` (ícone de bandeja: Abrir, Sair, Parar serviço).
- `libs/portable` empacotador do exe único (splash "Loading" removido).
- `flutter/` interface (Flutter 3.24.5):
  - `lib/desktop/pages/desktop_home_page.dart` tela inicial (cartão Realteq, botão Instalar, histórico, linhas de ID/senha com altura fixa).
  - `lib/desktop/pages/connection_page.dart` botão Conectar.
  - `lib/desktop/widgets/remote_toolbar.dart` barra da sessão (menus escuros legíveis, seletor de monitores).
  - `lib/common.dart` diálogo `realteqAskHowToConnect` (acesso direto com senha mestra + lembrete, ou aguardar aceite do cliente), nome do cliente, `realteqLogHistory`/`realteqShowHistory` (opção local `realteq-history`, máx. 200), atalho `--connect`.
  - `windows/runner/main.cpp` instância única (mutex `Local\RealteqDeskMainUI`).
- `branding/` ícone e logo. `.github/workflows/realteq-windows.yml` build do Windows.

## Build e entrega
- Build: workflow `realteq-windows.yml` (workflow_dispatch, ~35–40 min), artefato `realteq-desk-windows-x64`. `gh` em `C:\Program Files\GitHub CLI\gh.exe`.
- Análise local: `D:/dev/flutter/bin/flutter analyze --no-pub <arquivos>`.
- Entrega: exe em `dist\novo\realteq-desk-1.5.3-x86_64.exe`, cópia em `C:\Users\thefe\Meu Drive\Variados` e na pasta "Programa Final" da Área de Trabalho; atualizar atalho `Realteq Desk.lnk` (ícone `branding\icon.ico`).
- Backup: após cada build/mudança confirmada OK, rodar `backup\salvar-backup.ps1` (mantém `ultima-ok` e `anterior`).

## Notas técnicas
- Menus Material 3 (SubmenuButton) usam `menuTheme`, não `menuBarTheme`.
- `login_method: request-approval` faz o cliente ignorar senhas salvas.
- Instância única: `FindWindow` por classe+título; lista branca `--install`, `--cm`.
- Opções locais: `bind.mainSetLocalOption/mainGetLocalOption`; alias: `mainSetPeerAlias`.

## Pendências conhecidas
- Bandeja que fecha sozinha em um PC: precisa do log em `%AppData%\RealteqDesk\log` daquele PC.
- Aviso discreto ao cliente não alterado; histórico sem duração; varredura de Configurações parcial.
- Não verificado em uso real: barra/menus na sessão, instalação, "Sair" da bandeja, conexão direta com senha mestra.

## Versão
- Versão exibida: `flutter/lib/realteq/version.dart` (hoje 0.9.1) e `VERSION` do workflow (nome do exe). A versão interna do motor (1.5.3) NÃO muda, pois o protocolo compara versões entre computadores.
- A cada build nova rodar `powershell -ExecutionPolicy Bypass -File scripts/bump-versao.ps1`: 0.9.1 ... 0.9.9, 0.10, 0.11, ... Nunca vai para 1.0 sem OK do usuário.
