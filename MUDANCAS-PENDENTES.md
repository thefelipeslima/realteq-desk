# Mudanças pendentes (não enviadas ao GitHub)

Regra: só enviar ao GitHub e compilar quando o usuário der o OK. Antes de enviar, revisar tudo (flutter analyze, ver se as mudanças fazem sentido).

## Já feito localmente, ainda sem build
- Status do servidor na tela inicial corrigido (estava sempre "sem conexão").
- Tema escuro aplicado como padrão na primeira abertura.
- Fechar/minimizar a janela principal volta a chamar mainOnMainWindowClose.

## A fazer (conforme o usuário for pedindo)
- Arrastar a janela, sol/lua, senha das configurações (rt6603), coroa no menu: feitos.
- Versão exibida 0.9.1 (nome do exe e tela Sobre); script de versionamento em scripts/bump-versao.ps1.
- Barra da sessão (remote_toolbar.dart): hoje só encaixa nas 4 bordas e recolhe pela setinha. Pedido: arrastar livremente pela barra inteira, encaixar ao chegar no topo, e setinha para recolher/mostrar. Ainda não feito.
- Barra da sessão enxugada (escolha do usuário): Controle = Ctrl+Alt+Del, reiniciar, atualizar vídeo, captura de tela (+ transferir arquivo, colar teclas, elevação); ocultos: senha do SO, bloquear tela, bloquear entrada, anotação, trocar lados. Exibição: escala, qualidade, codec, resolução, cursor, privacidade. Mantidos: teclado, chat, voz, gravação (reativada), copiar/colar arquivos.
- Alça de arrastar da barra maior, amarela e com cursor de mão; encaixa nas 4 bordas (topo incluído), setinha recolhe/mostra. Posição 100% livre no meio da tela NÃO feita (exigiria reescrever a lógica de encaixe).
