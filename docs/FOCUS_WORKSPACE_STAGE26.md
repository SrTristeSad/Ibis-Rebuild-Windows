# Etapa 26 — Modo foco e espaço de trabalho adaptativo

A partir da Etapa 25, o editor Windows ganhou uma área de desenho ampliável, sem tocar no Inkora, no raster C++, no formato RBD2, no histórico ou nos dados do projeto.

## Como funciona

O novo botão **Modo foco · Tab**, no cabeçalho, recolhe o painel direito de 268 px. Pressionar **Tab** ou clicar em **Mostrar painel** o restaura. Os oito ícones de ferramentas continuam visíveis e funcionais; todos os atalhos de desenho e navegação seguem ativos. O modo de foco não é um modo de edição separado: ele apenas modifica o layout.

Enquanto o painel está oculto, as ferramentas **Pincel** e **Borracha** mantêm controles rápidos de tamanho e opacidade no rodapé do espaço de trabalho. Salvar, exportar e gerenciar camadas continuam no painel restaurável; Ctrl+S, Ctrl+Z, Ctrl+Y e outras teclas permanecem disponíveis em foco.

O módulo `app/workspace_layout.lua` centraliza limites de clique, recorte e largura de painel. `canvas_view.lua` utiliza a largura de painel apropriada para recentralização e `Encaixar`; Zoom e rotação seguem ancorados no cursor. Alternar o modo não reseta zoom, rotação ou deslocamento. O canto direito, antes ocupado pelo painel, passa a aceitar interação no canvas, sem mudar os pixels por si só.

## Testes

- `tests/test_workspace_layout.lua`: valida os layouts em 960×640, 1220×800 e 1920×1080, compatibilidade com a posição anterior, novos limites, transformação de coordenadas, âncora do zoom e fitting.
- `tools/test_lua.py`: executa a suíte pelo LuaJIT integrado aos testes Windows.
- Autoteste gráfico: clica no botão verdadeiro, alterna com Tab, assegura que os botões ocultos não fiquem ativos, envia clique à área expandida, opera os botões rápidos do pincel e compara raster RGBA, camadas e histórico antes/depois.

## Limitações

Não recria a disposição do ibisPaint Android de maneira validada 1:1. O foco é uma adaptação útil para telas Windows e não deve ser apresentado como equivalência à interface Android. Alguns ajustes específicos permanecem disponíveis apenas com o painel expandido.
