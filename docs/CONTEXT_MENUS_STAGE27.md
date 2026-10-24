# Etapa 27 — Menus contextuais para camadas e ferramentas

Continuação da reconstrução independente do editor Windows. **Não altera Inkora, raster C++, serialização RBD2 ou algoritmos de pintura.** As ações utilizam as funções existentes do editor.

## Uso

- **Botão direito em uma linha de camada:** seleciona a camada dessa linha e apresenta Renomear, Duplicar, Ocultar/Mostrar, Limpar pixels, Espelhar H/V, Mesclar abaixo, Mover acima/abaixo e Excluir. Comandos impossíveis na estrutura atual aparecem desabilitados (por exemplo, excluir a única camada, mesclar a camada inferior, duplicar quando já existem oito).
- **Botão direito em um dos oito ícones de ferramentas:** abre opções da ferramenta indicada, sem começar a desenhar. Pincel/Borracha permitem ajustar tamanho e opacidade; Balde ajusta tolerância; Formas escolhe contorno/preenchimento; Conta-gotas escolhe a origem da amostra; Seleção oferece desmarcar. Também há acesso a cor RGBA (quando aplicável), seleção de ferramenta e ajuda.
- **Esc** fecha o menu. **Setas ↑/↓ + Enter** permitem navegar e executar opções habilitadas. Clique fora fecha o menu sem repassar o clique para o canvas.
- **Botão direito no canvas continua movendo a visualização**, sem abrir menus nem escrever pixels. Não há menu de camadas enquanto o painel está recolhido pelo modo foco.

A estrutura, lista de opções, restrições e geometria de cliques são centralizadas em `app/context_menus.lua`. O overlay tem hit-map exclusivo: os botões que ficam atrás dele não recebem cliques até fechar.

## Testes

- `tests/test_context_menus.lua` testa seleção de ícones/linhas, limites da janela, estados habilitados/desabilitados e configurações de cada ferramenta em LuaJIT.
- Autoteste LÖVE interage com os menus reais via mouse/teclado, altera ferramenta, tamanho, preenchimento e fonte do conta-gotas, testa Esc e clique externo, verifica que o botão direito do canvas ainda entra em pan, altera visibilidade e duplica uma camada pelo menu, desfaz as operações e confere os bytes RGBA compostos e o número de camadas.
- O CI Windows x64 deve aprovar testes LuaJIT, C++ e GUI nas rotas `love.exe` e executável empacotado.

## Limite declarado

Menus adaptados para desktop; **a aparência e o fluxo 1:1 do ibisPaint Android 14.1.2 não foram comprovados** por comparação dinâmica com o original.
