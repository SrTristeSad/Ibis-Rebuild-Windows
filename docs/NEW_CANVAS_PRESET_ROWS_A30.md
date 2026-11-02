# A30 — Presets em lista vertical no diálogo Nova tela

## Referência e limitação de evidências
A captura oficial do tutorial ibisPaint **02. Start Creating an Artwork**
mostra uma lista de linhas empilhadas com ícones de proporção, nomes e
resoluções, abaixo dos controles de tamanho:
https://ibispaint.com/img/lecture/common/chapter_03_03.png
https://ibispaint.com/lecture/index.jsp?lang=en&no=03

A imagem é pública, mas **não foi autenticada como Android 14.1.2**.
A documentação local em docs/RESEARCH.md descreve evidências derivadas,
sem medidas de pixels obtidas por execução da versão-alvo.

## Defeito do rebuild A29
A captura 70-nova-tela-tamanhos-basicos.png exibe quatro botões
horizontais, alinhados como atalhos desktop, e uma grande prévia à
direita. A referência apresenta os presets numa lista vertical.

## Implementação Lua/LÖVE
- `app/ibis_gallery_ui.lua`: campos nome/largura/altura, prévia menor,
  abas e quatro linhas de 584×36 px. Sem modificar PRESETS,
  OFFICIAL_PRESETS, limites de 2048 px nem aspectViewport.
- `app/ibis_canvas_preset_rows.lua`: novo módulo **apenas de
  desenho**, com ícones vetoriais de proporção e texto de resolução
  à direita. Não tem acesso ao Store nem aos motores.
- `app/main.lua`: substitui quatro botões horizontais por linhas
  verticais; as áreas de clique usam a geometria de cada linha.
  Os mesmos callbacks atualizam `m.values[2]`, `m.values[3]`
  e `m.focus`. Cancelar, Criar e X continuam operacionais.
- `tests/test_ibis_gallery_ui.lua`: colisões de campos, abas,
  linhas e prévia, em 960×640, 1220×800 e 1920×1080, além de
  orientação correta dos pictogramas de proporção.
- As cenas 70–74 do showcase continuam exercitando as abas e os
  presets, inclusive o formato 3:4 e o A4 existente.

## Fora do escopo
A tela continua como adaptação Windows: não há importação de foto,
slider de qualidade, DPI operacional ou grade completa de formatos.
Nenhuma dessas funções será simulada como funcional.
Não houve alteração em RBD2, motor raster, pincéis, camadas,
histórico, Windows Ink ou branch main.

## Validação
A confirmar por workflows Linux/Windows e capturas reais do LÖVE
correspondentes ao commit, antes de declarar a fase aprovada.
