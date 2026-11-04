# Regras obrigatórias — Ibis Rebuild Windows

## Fonte única da interface
- A interface é a implementação **já existente** em https://github.com/SrTristeSad/Ibis-Lua (submódulo fixado em ui/Ibis-Lua).
- Não redesenhe, reinvente ou substitua telas, botões, galeria, painel de camadas, biblioteca de pincéis, ícones, cores, atalhos ou geometria sem instrução explícita do autor.
- Não copie uma UI Android para completar uma interface Windows; siga os arquivos e comportamentos do Ibis-Lua.
- Preserve os arquivos originais do submódulo. A integração de eventos é aplicada exclusivamente em uma cópia temporária por tools/assemble_lua.py, com âncoras verificadas.
- Mudanças na interface original pertencem ao repositório Ibis-Lua, não a uma cópia divergente neste projeto.

## Motor e arquitetura
- O motor **ativo** de pintura, borracha, camadas e composição deve ser escrito em Lua/LuaJIT usando LÖVE 11.5. Código em bridge/ e as APIs de LÖVE são a base.
- Não adicione chamadas FFI à DLL C++, rebuild_core.dll, dependência WebView ou um mecanismo de pintura oculto em C++.
- native/, app/, CMakeLists.txt e scripts Python legados são apenas referência/histórico e não integram o build Lua ativo.
- Não afirme que tudo está funcional: documente recursos conectados, limitações e funções ainda simuladas.
- Alpha Lock preserva o alfa dos pixels; Clipping usa a máscara da camada-base
  na composição Lua/LÖVE, sem modificar os pixels salvos da camada clipada.
  Preserve testes que comparam a amostra CPU com o resultado de shader GPU.
- Formato de persistência: PNGs, layers.tsv com oito colunas (legado de quatro
  colunas aceito) e document.tsv com camada ativa/fundo. Preserve compatibilidade.
- Os nove modos do seletor existente (Normal, Multiply, Screen, Overlay,
  Darken, Lighten, Color Burn, Color Dodge, Soft Light) foram implementados
  como composição independente em Lua e no shader LÖVE: preserve a mesma
  fórmula no conta-gotas, miniaturas e canvas. Não alegue equivalência
  exata com o ibisPaint proprietário nem adicione novos controles de blend.
- Um modo diferente de Normal ou Clipping usa renderização em dois canvases
  alternados com estado de textura e transformações isoladas. Não regredir
  o caminho direto Normal nem os testes de semitransparência.
- Varinha Mágica: tolerância por obra 0..255 passos 8-bit por canal RGBA,
  com comparação a cada canal do seed e flood-fill 4-conexo.
  `Selection.magic_wand(..., tolerance)` omite argumento para zero,
  mantendo compatibilidade da seleção exata. Ctrl+Alt+Right aumenta
  16, Ctrl+Alt+Left diminui 16, Ctrl+Alt+0 zera e mostra notice existente.
  Não marca raster dirty nem cria undo de máscara ao ajustar preferência.
  Gravar valor na terceira coluna opcional de `document.tsv` e ler zero
  em obras antigas (2 colunas) ou dados inválidos. Não alterar UI.
  Testar canal alfa, regiões isoladas, histórico e persistência.
- Varinha também possui modo GLOBAL de seleção por cor, alternado via
  Ctrl+Alt+G. `Selection.magic_wand(..., tolerance, global_mode)` recebe
  booleano opcional: nil/false mantém região 4-conexa; true percorre
  todos os pixels da camada ativa, sem conexidade, comparando os mesmos
  quatro canais RGBA e a mesma tolerância. O modo global é independente
  da fonte de amostragem de cores. `project.wand_global` persiste na quarta coluna
  de `document.tsv` (1/0), é false por padrão em obras legadas com
  duas/três colunas ou valores inválidos. Toggle usa notice existente,
  não cria histórico nem modifica pixels/máscara; clique posterior
  respeita Ctrl+Shift/Alt (soma/subtração/interseção), PNG, undo/redo de
  seleção e limite 1 Mi pixels. Cobrir ilhas, diagonal, alfa, tolerância,
  arquivo legado e isolamento por obra. Nunca modificar a UI Ibis-Lua.
- Varinha com fonte composta opcional via Ctrl+Alt+T:
  `project.wand_sample_all` false por padrão; true amostra as camadas
  visíveis com `Engine.composite_pixel_source(project,model,true)`,
  respeitando opacidade, blending, clipping, alfa e fundo branco.
  A máscara resultante continua limitada a 1 Mi e a edição continua
  na camada ativa. A preferência ocupa a quinta coluna de `document.tsv`
  (0/1) e retrocede para false em arquivos anteriores/valores inválidos.
  Alternar a fonte não marca dirty nem cria histórico; Ctrl+Alt+G
  continua alternando contiguidade de forma independente.
- Seleção raster ativa fica em bridge/lua_selection.lua: Varinha Mágica,
  Laço e seleção retangular via Transformar. Transformar move apenas pixels
  selecionados da camada ativa com undo/redo; pincel e balde respeitam
  a seleção. Testar pixels não selecionados, histórico e bordas.
  Álgebra de máscaras `Selection.combine` (replace/add/subtract/
  intersect) não pode alterar máscaras de entrada ou pixels. Retângulo,
  laço e varinha: Ctrl+Shift soma, Ctrl+Alt subtrai e Ctrl+Shift+Alt
  intersecta, com modo capturado no mousepressed. Sem Ctrl, Alt/Shift
  do Transformar preservam giro/escala. Modificadores com Ctrl criam
  novo retângulo até dentro da seleção anterior. Resultado vazio
  desmarca; nenhum passo de undo raster é criado, nem em Layer Lock/
  Alpha Lock. Testar PNG e gestos mistos sem regressão.
- Expansão/contração de seleção exclusivamente BINÁRIA usa
  `Selection.morph(mask,"expand"|"contract")` (vizinhança 8-conexa,
  elemento estruturante 3×3). Ctrl+Alt+Up expande, Ctrl+Alt+Down
  contrai, um pixel por acionamento. Tratar exterior do canvas como
  desmarcado (expansão recortada e contração reduzindo a borda).
  Máscara de origem imutável; seleção contraída até zero vira nil.
  Sem pintar, dirty ou histórico raster, inclusive Layer Lock/Alpha Lock;
  persistência continua em selection.png. Testar cantos, buracos,
  ilhas, atalhos, reabertura e rejeição sem seleção.
  Feather está implementado (box blur separável com raio 1..8),
  Ctrl+Alt+F aplica raio 2 px sem alterar a UI. Não declarar feather
  gaussiano nem slider como implementados. A seleção tem `s.weights`
  opcional com cobertura 0..1, acesso por `Selection.coverage` e
  `Selection.is_soft`. Máscaras binárias legadas seguem equivalentes a
  cobertura 1. Pincel, balde, borracha, Alpha Lock, move, clipboard,
  reshape e affine usam a cobertura parcial em RGBA. GPU de prévia deve
  corresponder à CPU também com máscara semitransparente, source-over
  e origem residual preservada. Salvar/reabrir pesos no canal alfa do
  `selection.png` e PNG de histórico, sem modificar TSV ou submódulo UI.
  Clones independentes de `weights`; testar feather, undo/redo e
  compatibilidade com seleções e projetos legados.
- Histórico isolado de seleção: Ctrl+Alt+Z/Y na ponte, com 8 passos e
  orçamento de 1.048.576 pixels marcados por pilha. Registrar Ctrl+A,
  inverter, expandir, contrair, feather, Ctrl+D/Esc, laço, retângulo,
  varinha e booleanas; clonar pesos e permitir snapshots nil. Não registrar
  no-ops; nova ação após undo limpa redo. Ctrl+Z/Y seguem EXCLUSIVAMENTE
  raster. Transformar pixels e geometria reseta a timeline só de seleção;
  undo/redo raster que restaura geometria também reseta. Persistir
  as pilhas de máscara SEPARADAS em `selection_history.tsv` e PNGs por
  geração via `lua_selection_history.lua`. Publicar manifesto por último,
  validar integralmente ordem, dimensões, pesos, assinatura da máscara
  atual e de snapshots antes de carregar; máscaras nil no manifesto.
  Arquivos corrompidos ou legados não impedem abrir pintura e máscara
  atual. Limpar gerações antigas e pilhas vazias, mas NUNCA tocar em
  `history.tsv`, `selection.png` ou PNGs das camadas. O raster usa o
  manifesto existente de forma independente. Testar corrupção,
  sobrescrita, reabertura, orçamento e compatibilidade com documentos
  antigos.
- Histórico raster persiste em `history.tsv` e PNGs versionados por geração
  para documentos de até 1.048.576 pixels, com até 8 snapshots em cada
  pilha (undo e redo). Os arquivos de snapshot devem ser validados em
  conjunto: um item corrompido invalida todo o histórico, mas nunca
  impede reabrir os PNGs da obra. Descarte históricos de camadas removidas
  sem bloquear o salvamento. Teste reabertura com duas camadas e seleção.
- Seleção ativa persiste em `selection.png` por obra (máscara binária
  ou com alfa fracionário),
  sem mudar os PNGs das camadas; arquivo ausente, corrompido ou com dimensões
  incorretas não pode impedir a abertura do projeto. Desmarcar e salvar remove
  o arquivo anterior. Operações isoladas de seleção não criam histórico raster;
  a máscara fica limitada a 1.048.576 pixels. Ctrl+A seleciona tudo e
  Ctrl+Shift+I inverte a seleção em TODO o canvas, inclusive fora do bounding
  box. Inverter sem seleção seleciona tudo; inverter seleção completa desmarca.
  Não alterar pixels, dirty ou histórico com essas operações. São permitidas
  com Layer Lock ou Alpha Lock, somente dentro do editor. Testar dupla
  inversão, PNG de máscara e atalhos, sem modificar a UI.
  Copiar/recortar/colar operam em clipboard
  INTERNO do Lua, não na área de transferência do Windows. Rotação 90° e escala 50%/200% são raster nearest-neighbour,
  ancoradas no canto superior esquerdo e devem rejeitar saída fora do canvas.
- Atalhos sem novos controles: Ctrl+C/X/V (clipboard), Ctrl+Shift+R/L
  (giro horário/anti-horário), Ctrl+Shift+Up/Down (200%/50%).
  Preserve undo/redo de pixels e geometria, compatibilidade com a máscara
  de seleção e testes da transformação.
- Espelhamento de seleção H/V: Ctrl+Shift+H / Ctrl+Shift+V pela ponte;
  `Engine.reshape_selection` reflete pixels e máscara irregular nos
  limites locais da seleção, não o canvas inteiro. Deve preservar alfa
  RGBA source-over, pixels externos, Layer Lock e Alpha Lock, desfazer/
  refazer e histórico persistente. Não criar botões ou alterar Ibis-Lua.
  Testar lacunas na máscara, mistura com pixels externos, atalhos e
  recusa de flip sem deslocamento em largura/altura de um pixel.
- Rotação livre e escala X/Y independente usam `Engine.affine_selection`
  com mapeamento inverso e filtro opcional (`nearest` por padrão). Em Transformar:
  Alt+arrastar gira relativamente ao centro da seleção, Shift+arrastar
  redimensiona nos dois eixos, sem alterar o layout/controles visuais.
  Os gestos Alt/Shift agora usam prévia bilinear GPU e camada virtual
  com o compositor existente. `Engine.begin_affine_gpu_preview` cria
  máscara e Canvas uma vez; `Engine.update_affine_gpu_preview` envia
  apenas os parâmetros de rotação/escala ao shader, reutilizando recursos.
  A CPU calcula e grava a transformação ao soltar; testar paridade RGBA
  premultiplicada entre GPU e commit CPU. Nenhum gesto pode alterar
  buffers reais ou histórico antes de soltar. Liberar Canvas e máscara
  ao confirmar/cancelar, sem vazamentos. A API antiga `preview_affine`
  CPU permanece para testes, mas não deve rodar por mousemoved.
  O movimento normal mantém deslocamento inteiro, com prévia GPU
  source-over que não modifica a camada original. O motor reaproveita
  Canvas e máscara por gesto e redesenha só se o deslocamento
  quantizado mudar; o mesmo clamp/rounding controla preview e commit.
  No fim/cancelamento, liberar as texturas e validar com testes GPU/CPU.
  A bilinear deve interpolar RGB premultiplicado por alfa e não
  misturar pixels fora da seleção. Rejeitar parâmetros NaN/infinito,
  fator fora de 0,1..8 e retângulo fora do canvas SEM alterar pixels,
  máscara ou histórico. Preservar testes de undo/redo e RGBA.
- Não alegue movimento bilinear, interpolação bicúbica,
  transformação vetorial ou clipboard do SO como concluídos.
- Não alegue paridade visual ou técnica 1:1 com ibisPaint Windows 14.1.4 sem medições verificáveis.

## Critérios de mudança
1. Antes de editar, confira o estado mais recente de ambos os repositórios e as assinaturas reais do código.
2. Priorize conectar funcionalidades à interface pronta em vez de criar novos controles.
3. Não altere funcionalidades existentes que não tenham relação com o pedido.
4. Garanta que o build e os testes são executáveis com fontes originais pinadas, sem exigir DLL C++ da aplicação.
5. Mantenha o código legível, modular e editável. Use testes para conversão de coordenadas, pixels, histórico, camadas e persistência.
6. Execute ou disponibilize testes reais do LÖVE no Windows e registre precisamente o que foi e não foi validado.
7. Se a funcionalidade não tiver backend, mantenha-a explícita como não implementada: não simule êxito de pintura/salvamento.
8. O autor decide o escopo. Não mude a identidade visual por iniciativa própria.

## Construção
- git submodule update --init
- python tools/assemble_lua.py
- .\run.ps1 com LÖVE 11.5 instalado
- .\build.ps1 para criar um pacote .love de fontes Lua
- GitHub Actions: .github/workflows/windows-x64.yml
