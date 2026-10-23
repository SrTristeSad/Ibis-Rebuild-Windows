# Etapa 4 — Borracha C++ e histórico raster de sessão

Funcionalidades **próprias**, reconstruídas para Windows x64 e **não equivalentes** aos mecanismos do ibisPaint Android 14.1.2. O aplicativo Inkora não participa deste projeto.

## Borracha

O núcleo C++ exporta \`rb_erase_basic_stroke\`: cápsula redonda contínua de contorno rígido, com os mesmos limites de coordenadas e diâmetro do pincel inicial. O efeito é **destination-out** na **camada ativa**, reduzindo alfa; se um pixel atingir alfa zero, seus componentes RGB são zerados. Opacidade 0 não altera o buffer e 1 apaga inteiramente a cobertura. Erros de argumento são detectados antes de escrever.

A área composta é recalculada usando \`rb_compose_normal\`. Ao apagar a camada de cima, a de baixo reaparece. Não há borracha com textura, estabilização, pressão real ou reprodução visual testada contra o Android.

## Desfazer e refazer

Os traços executam \`Layers:beginEdit()\` ao pressionar, vários segmentos com o botão pressionado e \`Layers:finishEdit()\` ao liberar/finalizar a ferramenta. Uma pincelada contínua é **um único passo** no histórico. Cliques na ferramenta de pixel também são reversíveis.

As entradas registram somente RGBA8 da camada editada, antes e depois, e ID estável da camada. A memória total das entradas é limitada a **48 MiB** e **24 passos**, expulsando os mais antigos conforme necessário; esse orçamento comporta um passo de 2048×2048. Novo traço após desfazer elimina a ramificação de refazer. Desfazer seleciona novamente a camada correta por ID.

O histórico existe **só na sessão em memória**: não faz parte do formato RBD2 e não sobrevive a fechar/reabrir. Mudanças estruturais e de visibilidade, ordem ou opacidade invalidam as entradas de pincel, porque essas operações ainda não integram uma transação de edição combinada. Selecionar outra camada por si só não invalida o histórico.

## Controles

- Barra superior: **Pincel básico** e **Borracha**.
- Barra lateral: **↶** para desfazer, **↷** para refazer.
- Teclado: **Ctrl+Z** desfaz; **Ctrl+Y** ou **Ctrl+Shift+Z** refaz.

## Validação

\`tests/test_core.py\`: geometria, transparência parcial, rejeição de parâmetros e revelação da camada inferior, todos sobre a DLL real.

\`tests/test_edit_history.lua\`: sequências de pintar, apagar, desfazer, refazer, seleção de outra camada, descarte de refazer, limites de 24 passos e 48 MiB, alteração estrutural e salvamento/reabertura RBD2. Essas chamadas usam o LuaJIT FFI da DLL real.

Os dois percursos LÖVE executam integração de botões concretos e persistência, além do self-test do núcleo. O CI Windows valida apenas seu ambiente; execução na estação do usuário ainda requer teste.
