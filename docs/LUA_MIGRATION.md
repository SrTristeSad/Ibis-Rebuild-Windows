# Migração ativa para Lua/LÖVE — Ibis-Lua como interface

## Decisão de arquitetura
A interface **não será recriada**. O submódulo ui/Ibis-Lua fixa a fonte original do
projeto SrTristeSad/Ibis-Lua. O comando python tools/assemble_lua.py copia a interface
para build/lua-app, preserva os assets e acrescenta apenas ganchos verificados
pelo script. Nunca modifica os arquivos do submódulo.

bridge/lua_engine.lua realiza rasterização RGBA source-over e borracha em Lua com
love.image.ImageData, renderização com love.graphics.Image, camadas separadas,
um histórico raster limitado e operações PNG. bridge/lua_bridge.lua integra
os eventos de mouse, painéis e salvamento à interface existente.

O código C++ prévio permanece como histórico, mas não é compilado, carregado nem
distribuído pelo fluxo principal. LÖVE tem suas próprias bibliotecas nativas;
"motor Lua" significa que o código de edição do projeto não depende de DLL C++.

## O que está conectado
- Criar e reabrir obras; novo canvas de 1 a 4096 pixels em cada dimensão
  sujeito também ao limite real da GPU. Dimensões superiores recebem aviso
  sem alterar os controles existentes.
- Desenho por mouse com pincel circular básico e borracha com redução de alfa.
  O registro de histórico de cada gesto agora é **tardio**: o primeiro
  pixel que muda chama a captura do snapshot antes da escrita. Gestos
  sem alteração efetiva não criam undo, não descartam redo, não marcam
  o raster como dirty e não executam upload da imagem para a GPU.
  Isso cobre borracha sobre transparência, tinta idêntica em pixels
  opacos, Alpha Lock em pixels vazios, seleção fora da pincelada e
  opacidade zero/sub-byte. O arraste pode começar sem mudanças e
  capturar somente no segmento que efetivamente pinta. Há apenas
  um snapshot por gesto. `Engine.stroke` continua aceitando chamadas
  diretas com histórico explícito via `Engine.begin_stroke`; a ponte
  fornece o callback opcional `on_first_change` e só captura quando
  ocorre alteração. A comparação usa margem de meio nível RGBA 8-bit,
  compatível com a detecção de no-op do Balde.
- Tamanho e opacidade vindos dos controles já existentes do Ibis-Lua.
- Cor RGB atualmente selecionada pelo painel já existente.
- Balde de preenchimento contíguo na camada ativa, com tolerância
  **RGBA de 0 a 255 por canal** (até 1.048.576 pixels por documento)
  e histórico raster reversível. Zero mantém a igualdade RGBA anterior,
  com margem de quantização 1/510. **Ctrl+Alt+PageUp/PageDown** ajustam
  ±16 níveis e **Ctrl+Alt+Home** restaura zero, independentemente da
  tolerância da Varinha. A preferência por obra é salva na **oitava
  coluna opcional** de `document.tsv`; arquivos de 2–7 colunas
  e valores inválidos usam zero. A região de preenchimento é determinada
  antes de modificar o raster, evitando revisitas quando a tinta ainda
  está dentro da tolerância; operações sem alteração real não criam
  dirty nem histórico. Continua contíguo 4-conexo, respeita seleção,
  Alpha Lock, opacidade e desfazer/refazer; sem novo controle visual.
  **Ctrl+Alt+B** alterna independentemente entre Balde **contíguo**
  (padrão 4-conexo) e **global por cor**, preenchendo todas as regiões
  da camada ativa semelhantes em RGBA, ainda que desconectadas.
  O modo global varre cada pixel original uma única vez, antes de
  pintar; Alpha Lock e a seleção ativa também restringem a varredura.
  O toggle não edita pixels/máscaras, não marca dirty e não cria
  histórico. `project.bucket_global` ocupa a **nona coluna opcional**
  de `document.tsv` (0/1); obras anteriores com 2–8 colunas ou
  flag inválida começam no contíguo, sem perder tolerância ou outras
  preferências. Não depende de `wand_global`, `wand_rgb_only` ou
  de `wand_sample_all`; não amostra camadas compostas.
  **Ctrl+Alt+M** alterna independentemente a comparação do Balde
  entre **RGBA** (padrão) e **somente RGB**, ignorando o canal alfa
  para encontrar pixels semelhantes em ambos os modos (contíguo/global).
  O RGB armazenado em alfa zero pode coincidir mesmo estando invisível.
  Isso altera a região encontrada, não a regra de pintura: a aplicação
  da tinta segue source-over, podendo mudar o alfa; Alpha Lock mantém
  o alfa original e impede pintar pixels transparentes. O sinalizador
  `project.bucket_rgb_only` é salvo na **décima coluna opcional**
  de `document.tsv` (0/1). Arquivos de 2–9 colunas ou sinalizador
  inválido seguem em RGBA sem perder as outras preferências.
  Alterar o modo não toca na máscara, dirty, raster ou histórico.
  **Ctrl+Alt+9** alterna a conectividade do Balde contíguo entre
  **4 vizinhos** (padrão histórico) e **8 vizinhos** (lados e cantos).
  O scanline 8-conexo pesquisa também um pixel além das extremidades
  nas linhas vizinhas; a área continua sendo identificada inteiramente
  antes da aplicação de tinta. Funciona com tolerância e RGB-only,
  máscara/feather, Alpha Lock e o mesmo undo/redo. No modo global
  a conectividade é ignorada. A preferência `bucket_diagonal`
  é false por obra por padrão e salva na **11ª coluna opcional**
  de `document.tsv` (0=4, 1=8). Arquivos de 2–10 colunas ou
  sinalizador inválido usam 4 vizinhos sem perder campos anteriores.
  Alternar não altera raster, seleção, dirty ou histórico.
  **Ctrl+Alt+V** alterna a **fonte de comparação do Balde** entre
  camada ativa (padrão) e composição visível, reutilizando
  `Engine.composite_pixel_source(project, model, true)`. A fonte
  considera visibilidade, opacidade, mesclagem, clipping e fundo
  branco; outros modos de fundo preservam alfa transparente.
  A busca de região termina antes de qualquer escrita. A tinta é
  aplicada **somente à camada ativa**, inclusive quando a referência
  deriva das camadas superiores. Alpha Lock consulta o alfa da
  camada de destino, não da composição. Compatível com global,
  conexidade 4/8, RGB-only, tolerância, máscara/feather e undo/redo,
  sem histórico para no-op. `project.bucket_sample_all` é false
  por padrão e persistido na **12ª coluna opcional** de
  `document.tsv` (0=camada ativa, 1=composição). Arquivos com
  2–11 colunas e flags inválidas mantêm a camada ativa, preservando
  outras opções. A preferência não depende de `wand_sample_all`.
  Toggle não modifica raster, seleção nem histórico.
  Sem controles visuais novos.
- Conta-gotas que lê a composição RGBA das camadas visíveis, considerando
  opacidade e fundo branco, e atualiza o seletor de cores existente.
- Miniaturas reais em PNG na galeria para obras salvas e pixels reais
  nas miniaturas das camadas, sem redesenhar os controles da interface.
- Composição visível em ordem de camadas com visibilidade e opacidade.
  Os nove modos do seletor existente — Normal, Multiply, Screen, Overlay,
  Darken, Lighten, Color Burn, Color Dodge e Soft Light — têm composição
  separável RGBA source-over em Lua e shader LÖVE. O conta-gotas e as
  miniaturas aplicam a mesma fórmula que o canvas.
  Não há equivalência garantida aos resultados do ibisPaint proprietário.
- **Alpha Lock** agora atua na pintura e no balde: modifica somente a cor dos
  pixels existentes e preserva o valor de alfa; a borracha não opera enquanto
  Alpha Lock está ativo.
- **Clipping** agora recorta a exibição das camadas usando o alfa da camada-base
  inferior não clipada, respeitando a visibilidade e a opacidade da base.
  O desenho original da camada clipada permanece intacto. A renderização usa
  shader de composição do LÖVE; o conta-gotas e a miniatura usam a mesma regra
  na CPU. Não há equivalência 1:1 com o clipping proprietário do ibisPaint.
- **Varinha Mágica** seleciona uma região contígua por RGBA da camada ativa.
  A tolerância é ajustável de **0 a 255** níveis 8-bit por canal RGBA,
  comparando cada pixel à cor do ponto inicial. **Ctrl+Alt+→** aumenta
  16 níveis, **Ctrl+Alt+←** diminui 16 e **Ctrl+Alt+0** restaura zero
  (comparação exata com margem de quantização). O limite é aplicado a
  cada canal de forma independente; a região continua conectada por
  quatro vizinhos, sem unir ilhas distantes. A configuração é própria
  de cada obra e persistida na terceira coluna opcional de `document.tsv`.
  Obras antigas de duas colunas e valores malformados usam tolerância zero.
  Alterar a tolerância não edita pixels, não cria histórico e usa o aviso
  discreto já presente na UI, sem adicionar botões nem controles.
  **Ctrl+Alt+G** alterna entre Varinha **contígua** (padrão, somente área
  4-conexa ao clique) e **global por cor** (varre a camada ativa inteira
  e seleciona todas as regiões com RGBA dentro da tolerância, mesmo ilhas
  ou pixels conectados apenas diagonalmente). O modo global reutiliza
  tolerância 0..255, combinações Ctrl+Shift/Alt, seleção com feather e
  histórico independente. A alternância é preferência, não altera pixels,
  máscara ou histórico; o aviso existente informa qual modo está ativo.
  `document.tsv` ganha uma quarta coluna opcional (0=contígua,
  1=global), com padrão contíguo para obras antigas de duas/três colunas,
  e fallback seguro em caso de campo inválido. O modo só compara os
  pixels da camada ativa, a menos que a nova opção de fonte seja ativada.
  **Ctrl+Alt+T** alterna a fonte da Varinha: **camada ativa** (padrão) ou
  **composição das camadas visíveis**. A fonte composta usa o mesmo cálculo
  RGBA do conta-gotas, incluindo opacidade, mesclagem e clipping, e
  considera o fundo branco como opaco; os fundos transparentes mantêm alfa.
  Contiguidade/global, tolerância e soma/subtração/interseção permanecem
  independentes da fonte. Somente a máscara é criada: pintar/recortar
  continua atuando na camada ativa. A quinta coluna opcional de
  `document.tsv` armazena 0=camada ativa, 1=composição; duas, três ou
  quatro colunas e campos inválidos retornam à camada ativa. A alteração
  não marca dirty, não gera histórico nem cria controles visuais.
  **Ctrl+Alt+8** alterna a conectividade da Varinha no modo contíguo:
  **4 vizinhos** (padrão/algoritmo anterior) ou **8 vizinhos**
  (lados e diagonais). Mantém a tolerância RGBA por canal, o limite de
  1.048.576 pixels e as combinações de máscara. O modo global ignora
  essa configuração, pois já percorre todos os pixels semelhantes.
  A preferência `wand_diagonal` é salva por obra na sexta coluna de
  `document.tsv` (0=4, 1=8); arquivos de duas a cinco colunas e valores
  inválidos preservam quatro vizinhos. Alternar a conectividade não
  altera a seleção atual, pixels, dirty ou histórico.
  **Ctrl+Alt+R** alterna a comparação da Varinha entre **RGBA**
  (padrão, compara R/G/B/A) e **somente RGB** (ignora o canal alfa).
  Ambos mantêm a tolerância 0..255 por canal, contiguidade 4/8,
  modo global, fonte camada ativa/composição visível, limites e álgebra
  de máscaras. A escolha muda apenas quais pixels entram na máscara:
  não modifica a transparência dos pixels, o histórico ou o dirty.
  Em pixels de alfa zero, RGB pode estar armazenado apesar de invisível
  e continua sendo considerado no modo RGB. A opção por obra
  `wand_rgb_only` usa a sétima coluna de `document.tsv` (0/1);
  arquivos com 2–6 colunas ou flag inválida seguem no RGBA padrão.
  **Laço** seleciona pixels dentro do contorno livre arrastado; **Transformar**
  cria uma seleção retangular ao arrastar sem seleção e move pixels selecionados
  ao arrastar dentro da seleção. Não foram criados controles visuais.
  **Combinar áreas** com retângulo (Transformar), Laço e Varinha Mágica:
  **Ctrl+Shift+arrastar/clicar** soma à seleção existente;
  **Ctrl+Alt+arrastar/clicar** subtrai; **Ctrl+Shift+Alt+arrastar/clicar**
  intersecta. Sem os modificadores, os gestos anteriores permanecem:
  substituir seleção, mover pixels, Alt+arrastar para girar e
  Shift+arrastar para redimensionar. A operação é definida ao iniciar
  o gesto; uma interseção vazia desmarca a seleção. Na ausência de
  seleção prévia, somar cria uma seleção, enquanto subtrair/intersectar
  mantêm a máscara vazia. Combinações alteram só geometria, não pixels
  nem histórico raster, e funcionam em camadas bloqueadas. A máscara
  combinada continua persistida em `selection.png`.
  **Expandir seleção** em 1 pixel: Ctrl+Alt+↑; **contrair seleção** em
  1 pixel: Ctrl+Alt+↓. As operações usam vizinhança binária 8-conexa
  (quadrado 3×3): expandir acrescenta pixels adjacentes; contrair
  elimina pixels que não têm todos os oito vizinhos selecionados.
  O exterior do canvas é considerado não selecionado: expandir recorta
  nas bordas, e contrair pode remover totalmente a seleção.
  São modificações apenas da máscara, sem pintar, criar undo raster ou
  exigir desbloqueio da camada. Pressionar repetidamente aumenta
  ou diminui a seleção em passos de 1 pixel. O resultado é salvo em
  `selection.png`. A máscara agora também pode ser suavizada com feather
  sem remover as operações morfológicas binárias anteriores.
- **Ctrl+Alt+F: feather da seleção com raio 2 px** (sem novos controles).
  `Selection.feather(selection, radius)` aceita raio inteiro de 1 a 8.
  Usa filtro box blur separável, exterior do canvas transparente e alfa
  de cobertura quantizado em 8 bits, compatível com `selection.png`.
  As máscaras antigas continuam binárias e são carregadas sem alteração.
  O feather altera só a seleção, não o documento nem o histórico raster.
  Pincel, borracha e balde multiplicam a intensidade por essa cobertura;
  Alpha Lock preserva o alfa original. Move/cut/copy/paste, espelhamento
  e transformações preservam o peso e dividem alfa entre origem e destino
  sem apagar totalmente a borda. As prévias GPU de movimento/giro/escala
  também usam o canal alfa real da máscara, não um teste binário.
  Undo/redo dos passos de edição mantém a geometria e os pesos associados.
  Selecionar tudo novamente restaura máscara opaca, mesmo após feather.
  As operações combinadas e morfológicas preservam coberturas parciais.
  **Feather aqui não é blur gaussiano nem antialiasing nativo do ibisPaint**.
- Seleções limitam a pintura e o balde à máscara ativa. O contorno da
  seleção aparece sobre a tela de edição; Ctrl+D ou Esc desfazem a seleção.
  **Ctrl+A seleciona todo o canvas**; **Ctrl+Shift+I inverte a máscara**
  no documento inteiro, inclusive regiões fora do retângulo da seleção.
  Sem seleção, inverter seleciona tudo; inverter uma seleção completa
  desmarca. A operação preserva pixels, transparência, camadas e histórico
  raster, inclusive com Layer Lock ou Alpha Lock ativos. A nova máscara
  segue sendo salva em `selection.png`, sem alterar PNGs de camadas.
  **Arrastar sem modificadores dentro da seleção também mostra uma prévia
  do deslocamento** em tempo real. O motor prepara uma textura-máscara
  uma única vez por gesto e usa um shader LÖVE para desenhar a origem
  apagada e os pixels movidos com RGBA source-over. A posição e o contorno
  são atualizados apenas quando o deslocamento inteiro muda, evitando
  copiar e reconstruir até um milhão de pixels em Lua em cada mousemoved.
  O canvas virtual nunca altera a camada, dirty ou histórico antes de
  soltar; a confirmação usa o mesmo clamp/arredondamento do movimento CPU.
  Mover pixels da camada ativa é um único passo reversível no histórico
  (undo/redo também restaura a posição da máscara enquanto ela estiver ativa).
- **Copiar/Recortar/Colar** funcionam na camada ativa e apenas dentro da
  máscara: Ctrl+C copia, Ctrl+X recorta e Ctrl+V cola na posição original.
  A colagem é RGBA source-over; sua área passa a ser a seleção atual.
  A área de transferência é **interna ao aplicativo**, não é o clipboard
  do Windows. A colagem pode ser movida pela ferramenta Transformar.
- **Rotação de 90°** da seleção e seu conteúdo: Ctrl+Shift+R (horária) e
  Ctrl+Shift+L (anti-horária). **Escala nearest-neighbour**:
  Ctrl+Shift+↑ duplica as dimensões, Ctrl+Shift+↓ reduz a 50%.
  O canto superior esquerdo da seleção ancora a transformação.
  **Espelhar a seleção horizontalmente**: Ctrl+Shift+H.
  **Espelhar verticalmente**: Ctrl+Shift+V. O espelhamento reflete
  tanto os pixels quanto a máscara irregular dentro de seus limites,
  preserva os pixels fora da seleção e compõe sobreposição RGBA
  source-over. É uma operação nearest-neighbour de um único passo
  de undo/redo, incluindo geometria da seleção e histórico persistente.
  Camadas bloqueadas ou com Alpha Lock não podem ser transformadas.
  Os atalhos são específicos desta integração Lua, sem novos controles
  visuais na interface Ibis-Lua. Undo/redo restaura pixels e geometria
  enquanto a mesma seleção permanecer ativa.
- **Transformação livre por gesto** na ferramenta Transformar:
  **Alt + arrastar dentro da seleção** gira pelo ângulo definido entre
  a posição inicial e final do ponteiro em torno do centro geométrico;
  **Shift + arrastar dentro da seleção** redimensiona horizontal e
  verticalmente de maneira independente, conforme o deslocamento do mouse.
  O gesto normal sem modificadores continua movendo pixels.
  **Durante Alt/Shift+arrastar**, a área transformada já aparece no canvas
  com contorno temporário. A prévia agora usa um shader da GPU:
  máscara e Canvas temporários são criados uma única vez por gesto,
  enquanto ângulos/fatores são atualizados por uniforms GLSL.
  O contorno é transformado graficamente, sem criar outra máscara
  raster em Lua por movimento. Documento, miniaturas, dirty e histórico
  não mudam antes de soltar. A CPU grava o resultado em um passo reversível.
  A API `Engine.affine_selection(project,id,selection,angle,sx,sy,filter)`
  aceita ângulo fracionário em graus, escala X/Y contínua e filtro
  opcional `"bilinear"`. O padrão da API permanece `nearest` para
  compatibilidade, mas os **gestos Alt/Shift usam bilinear**.
  A interpolação bilinear ocorre em RGB pré-multiplicado e considera pixels
  fora da máscara como transparentes, evitando halos nas bordas;
  o resultado final tem o mesmo raster da pré-visualização.
- **Histórico independente de seleção (persistente por obra)**:
  **Ctrl+Alt+Z** desfaz e **Ctrl+Alt+Y** refaz operações APENAS de
  máscara: selecionar tudo, inverter, expandir, contrair, feather,
  desmarcar (Ctrl+D/Esc), retângulo, laço, varinha e suas combinações.
  São até 8 estados por pilha (undo/redo), com orçamento de até
  1.048.576 pixels marcados por pilha; snapshots mais antigos são
  descartados se o orçamento for excedido. Pesos alfa do feather são
  restaurados integralmente. Comando sem alteração não cria novo passo;
  uma nova edição invalida redo. O histórico raster é separado e
  continua em Ctrl+Z / Ctrl+Y, sem passos extras por máscara.
  Transformações de pixels que movem a máscara zeram seu histórico
  independente para não desalinhá-la do desenho. Ao salvar, as pilhas
  de máscara são persistidas em `selection_history.tsv` e PNGs
  `selection_history_<geração>_undo|redo_<índice>.png`. O manifesto
  só é publicado após os PNGs. Ao reabrir, a seleção atual vem do
  `selection.png` e as pilhas de máscara são restauradas após validação
  integral de dimensões, ordem, limite, PNGs e assinatura da cobertura
  atual; erros ignoram a timeline, sem impedir a abertura da pintura.
  Uma nova geração remove os PNGs antigos. Pilhas vazias removem
  o manifesto e os snapshots exclusivos da seleção.
  Os arquivos são separados do histórico raster `history.tsv`.
- Undo/redo do raster por traço pelos botões existentes, Ctrl+Z / Ctrl+Y.
  O histórico raster agora persiste por obra em `history.tsv` e PNGs de
  snapshots com geração identificada. Ao reabrir, recupera as pilhas de
  desfazer/refazer (até 8 registros em cada pilha) e, quando aplicável,
  o contorno correspondente à máscara de seleção. O manifesto só é gravado
  após os PNGs, e o carregamento valida o conjunto completo antes de
  aceitar qualquer passo de histórico.
- Salvamento automático ao voltar do editor para a galeria, ou Ctrl+S.
  Os arquivos ficam na pasta de dados do LÖVE, em lua-artworks/, como PNG por camada,
  index.tsv, layers.tsv e document.tsv. As obras salvas são listadas ao reiniciar.
  Uma seleção ativa também é salva em `selection.png` como máscara binária
  ou de cobertura alfa fracionária
  separada dos pixels da pintura; é restaurada automaticamente ao reabrir a
  obra e removida do disco no próximo salvamento após Ctrl+D ou Esc.
  Projetos antigos sem `selection.png` continuam abrindo normalmente.
  O novo layers.tsv preserva nome, visibilidade, opacidade, blending selecionado,
  Clipping, Alpha Lock e bloqueio; arquivos antigos de quatro campos ainda abrem.
  document.tsv guarda a camada ativa e o modo de fundo.

## Limitações explícitas
- **Não** há paridade com os algoritmos do ibisPaint oficial.
- Pincel circular, borracha, balde, conta-gotas, Alpha Lock, recorte básico por
  Clipping e os nove modos de mesclagem visíveis têm implementação independente.
  Filtros, feather gaussiano ou parametrizável na interface original,
  seleção por tolerância ajustável, interpolação bicúbica,
  prévia bilinear do movimento de pixels (o movimento raster inteiro usa
  shader nearest), formas, estabilização, pressão, máscaras adicionais,
  efeitos,
  texturas e demais ferramentas
  exibidas pelo Ibis-Lua continuam sem backend real nesta etapa.
- O no-op do pincel e da borracha evita modificações sub-byte por
  comparação RGBA 8-bit; isso não implementa acúmulo de opacidade
  abaixo da precisão do raster ou estabilização de traços.
- A rasterização por pixel feita em Lua é uma base funcional, não otimizada
  para telas enormes ou pincéis grandes.
- O histórico em memória mantém até 8 snapshots em cada pilha para telas
  com até 32 MiB por snapshot. **Persistência do histórico** restringe-se
  a obras de até 1.048.576 pixels, para limitar armazenamento e tempo de
  reabertura. Cada snapshot salvo usa PNG e um manifesto `history.tsv`;
  pode consumir espaço considerável com muitas etapas. Arquivos ausentes,
  corrompidos, com dimensões inesperadas ou camada removida não impedem
  abrir a pintura: o histórico inválido é ignorado, e referências antigas
  a camadas removidas são descartadas no salvamento. Operações estruturais
  de camadas não entram no histórico raster. O histórico não cobre mudanças
  de interface nem alterações externas aos PNGs. Operações puras de máscara
  possuem pilhas em memória SEPARADAS, não inseridas nos arquivos raster.
- A seleção ativa persiste como máscara `selection.png` na pasta da obra,
  e é validada por assinatura PNG, dimensões e limite de tamanho ao reabrir.
  Seleções inválidas são ignoradas sem afetar o conteúdo das camadas.
  A máscara não grava alterações sobre os pixels da pintura.
  O clipboard **não persiste** e não comunica com o Windows. Copiar/colar só manipula
  pixels da camada ativa, sem novos objetos ou camadas. Recortes de seleção,
  movimento, rotação e escala estão limitados a 1.048.576 pixels por documento;
  a varinha usa tolerância ajustável por obra em RGBA 8-bit (0..255);
  o valor zero mantém a margem mínima de quantização. O modo contíguo
  preserva flood-fill 4-conexo; o modo global percorre a camada ativa
  inteira na fonte escolhida (camada ativa ou composição visível). A rotação
  admite rotação livre e escalas independentes por gesto na ferramenta
  Transformar; os atalhos anteriores de 90° e 50%/200% continuam disponíveis.
  Os fatores da API livre devem estar entre 0,1 e 8 por eixo.
  Os gestos livres usam bilinear RGBA e os atalhos anteriores / chamadas
  sem filtro continuam nearest-neighbour. A prévia GPU dos gestos Alt/Shift
  atualiza uniforms e renderiza um Canvas, sem refazer a seleção na CPU
  a cada mousemoved. Isso ainda exige VRAM e tempo de GPU. A CPU prepara
  a máscara final e modifica pixels apenas na confirmação. Durante a
  prévia, o contorno usa transformação geométrica das arestas, podendo
  divergir um pouco do limite raster em ângulos fracionários.
  Não há filtros bicúbicos nem alças vetoriais. Operações cuja nova área exceda as bordas da tela
  falham sem cortar pixels.
  O movimento é deslocamento inteiro, limitado para manter a máscara no
  canvas. Sua prévia GPU usa uma máscara e um Canvas do tamanho do
  documento por gesto, com uso adicional de VRAM, principalmente em
  seleções grandes. A máscara é preparada no início do movimento útil;
  deslocamentos subpixel que arredondam para a mesma posição não
  repetem a renderização. A prévia não substitui o caminho CPU do commit.
  O contorno visual tem teto de 10.000 segmentos para não sobrecarregar
  a renderização, sem afetar o resultado da máscara raster.
- O formato atual é PNG + metadados TSV, **não RBD2 nem IPV**.
- O catálogo reconstituído contém obras salvas; pastas e suas mudanças,
  seleção múltipla e outras ações da galeria ainda não são persistidas.
- As miniaturas da galeria agora mostram pixels reais somente para obras
  persistidas; a miniatura das camadas exibe o buffer da camada durante a edição.
  Itens demonstrativos e obras ainda não salvas podem continuar sem prévia.
- Todos os nove modos atualmente presentes no painel de camadas alteram
  a composição real. A equação de cores usa alfa straight; o shader
  compõe em canvases alternados do LÖVE sem C++ da aplicação.
- Modos diferentes de Normal ou uso de Clipping exigem duas texturas
  temporárias da resolução integral da tela; em desenhos grandes isso
  pode consumir muita VRAM. Sem esses efeitos, o renderer mantém o
  caminho direto anterior. Não há equivalência de precisão com o ibisPaint.
- Alpha Lock é aplicado apenas à pintura RGB: não há borracha com redução
  de transparência nessa condição. O Clipping é aplicado à visualização,
  sem alterar os pixels originais nem agrupar camadas.
- O uso de shader exige dispositivo compatível com LÖVE 11.5; o CI valida
  a composição recortada no renderizador software Mesa, mas não substitui
  testes em hardware gráfico físico.
- O balde compara RGBA da camada ativa ou da composição visível
  (Ctrl+Alt+V) com tolerância 0–255 por canal,
  ou só RGB (Ctrl+Alt+M), em modo contíguo ou global por cor
  (Ctrl+Alt+B);
  não há slider integrado na interface Lua, apenas os atalhos
  Ctrl+Alt+PageUp/PageDown/Home. O algoritmo de duas fases mantém
  uma região fixa, não contamina a comparação com pixels recém-pintados
  e não cria histórico para preenchimento idêntico. Não equivale ao
  balde do ibisPaint.
- A suíte cobre Balde de Tinta com tolerância RGBA 0/16/48/64/255,
  fronteira, ilhas, Alpha Lock, seleção, tinta de baixa opacidade,
  no-op sem histórico, atalhos, preferências por obra e legados 2–8 colunas.
  Testes adicionais verificam Balde global RGBA com regiões separadas,
  diagonais, tolerância por canal, alfa, máscara, Alpha Lock, opacidade
  baixa, história raster, Ctrl+Alt+B e arquivos de 2–9 colunas.
  Testes de RGB-only do Balde cobrem alfa 0/25/50/75/100%,
  conectividade, varredura global, tolerância por canal, limites de
  seleção, Alpha Lock, preenchimento source-over, no-op, histórico,
  Ctrl+Alt+M, isolamento por obra e formatos 2–10 colunas.
  A suíte de Balde 8-conexo verifica cantos isolados, bordas,
  tolerância/RGBA/RGB-only, independência do modo global, máscaras,
  Alpha Lock, no-op, histórico, Ctrl+Alt+9, isolamento por obra e
  formatos 2–11 colunas.
  Os testes do Balde com referência composta verificam escrita
  restrita à camada ativa, camadas visíveis/ocultas, opacidade,
  clipping, fundo branco, comparação RGB/RGBA, conectividade,
  modo global, Alpha Lock, máscara, no-op, histórico, Ctrl+Alt+V
  e compatibilidade de documentos de 2–12 colunas.
- A suíte de pixels usa o LÖVE real para verificar tinta, borracha, balde,
  Alpha Lock, Clipping e os nove modos de blend na CPU e GPU,
  leitura de cores, composição semitransparente, miniatura,
  abertura de arquivos de quatro colunas e ciclo salvar/abrir PNG.
  Os testes também validam seleção por laço, varinha e retângulo,
  restrição de pintura à seleção, mover pixels, clipboard interno
  congelado, cut/paste source-over, giros 90°, escala 50%/200%,
  limites de tela e desfazer/refazer com geometria da seleção.
  Testes adicionais cobrem ângulos livres, escalas X/Y independentes,
  pixels RGBA preservados, parâmetros inválidos, operações nas bordas
  e gestos Alt/Shift reais na ponte com undo/redo.
  O CI também cobre flips H/V de máscaras irregulares, sobreposição
  semitransparente, proteção de pixels externos, histórico gravado/reaberto,
  atalhos Ctrl+Shift+H/V e bloqueio por Layer Lock/Alpha Lock.
  O CI cobre seleção global por cor em ilhas/diagonais desconectadas,
  distinção do flood-fill 4-conexo, canal alfa, limite 1 Mi pixels,
  tolerância progressiva, combinações soma/subtração/interseção, undo/redo
  de máscara, atalho Ctrl+Alt+G, preferência por obra e metadados legados.
  Testes adicionais cobrem Ctrl+Alt+T, fonte de todas as camadas visíveis,
  clipping, visibilidade, Multiply, opacidade, transparência/fundo branco,
  edição restrita à camada ativa e compatibilidade de metadados 2–5 colunas.
  A nova suíte de conectividade 8-conexa cobre pontes diagonais, bordas,
  canal alfa/tolerância, independência do modo global, Ctrl+Alt+8,
  persistência por obra, arquivos 2–6 colunas e histórico raster.
  Os testes de RGB-only exercitam alfa 0/25/50/100%, conexidade 4/8,
  modo global, tolerância, fonte composta, Ctrl+Alt+R, formatos 2–7
  colunas, preservação do alfa salvo e histórico raster.
  Também cobre a varinha com tolerância RGBA ajustável, conectividade de
  quatro vizinhos, limites 0/255, canal alfa, combinações preservadas,
  atalhos Ctrl+Alt+←/→/0, ausência de histórico ao mudar configuração
  e persistência/compatibilidade de `document.tsv`.
  O CI cobre histórico independente de máscara, oito passos limitados,
  Ctrl+Alt+Z/Y, redo invalidado por nova seleção, máscara nula e feather
  restaurados, gestos de retângulo e soma de áreas, convivência com
  undo/redo raster e **persistência separada após reabrir a obra**.
  Inclui validação de cabeçalho, checksum, dimensões, PNGs ausentes ou
  corrompidos, geração substituída e limpeza de pilhas vazias.
  A suíte também cobre feather de raio 1/2, pesos de alfa por pixel,
  compatibilidade PNG, pincel/balde/borracha/Alpha Lock, recorte e colagem,
  movimento, espelhamento, transformação livre e prévia GPU/CPU com
  transparência parcial, inclusive atalhos Ctrl+Alt+F e reabertura.
  Também cobre expansão/contração 8-conexa, cantos e bordas do canvas,
  ilhas desconectadas, buracos internos, contração até vazio e máscaras
  persistidas, além de atalhos Ctrl+Alt+↑/↓ com camada bloqueada.
  Também cobre união, diferença e interseção de máscaras
  irregulares, gestos reais de retângulo/laço/varinha, no-op/vazio,
  persistência e histórico raster intacto em camadas bloqueadas.
  Selecionar tudo e inverter também são testados com máscaras irregulares,
  dupla inversão, limite de tamanho, camada bloqueada, atalhos Ctrl+A /
  Ctrl+Shift+I, ausência de undo raster e persistência da seleção PNG.
  A suíte verifica que a API de prévia bilinear CPU não altera a obra
  e coincide com o commit pixel a pixel. A prévia GPU de rotação/escala
  compara RGBA pré-multiplicado com o commit CPU (tolerância GLSL),
  reutiliza máscara e Canvas, rejeita parâmetros inválidos e evita
  mutação antes de soltar. O contorno gráfico usa origem centralizada. A prévia de movimento GPU é comparada ao commit
  raster CPU, inclusive em sobreposições com transparência, e testa
  reutilização da máscara/Canvas, deslocamento quantizado, renderização
  e cancelamento no Bridge.
  O CI também verifica roundtrip PNG da máscara, desmarcação com remoção
  do arquivo e rejeição de PNG truncado ou com dimensões incompatíveis.
  O histórico persistente tem testes de undo/redo após reabertura,
  múltiplas camadas, geometria da máscara, corrupção do manifesto,
  ausência de um PNG e limpeza de snapshots obsoletos.
- Os testes Windows precisam passar no GitHub Actions antes de declarar a
  distribuição verificada.

## Como usar
1. git submodule update --init
2. python tools/assemble_lua.py
3. .\run.ps1 com LÖVE 11.5 instalado
4. .\test.ps1 valida os ganchos; o CI faz E2E de navegação e rasterização.

A interface foi desenvolvida com referência ao ibisPaint Windows 14.1.4,
sem validação 1:1. O motor não é cópia do aplicativo proprietário.
