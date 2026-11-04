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
- Tamanho e opacidade vindos dos controles já existentes do Ibis-Lua.
- Cor RGB atualmente selecionada pelo painel já existente.
- Balde de preenchimento contíguo por igualdade RGBA na camada ativa (até
  1.048.576 pixels por documento), com histórico raster reversível.
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
- **Varinha Mágica** seleciona uma região contígua por RGBA da camada ativa;
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
  de interface, seleção feita sem pintura ou alterações externas aos PNGs.
- A seleção ativa persiste como máscara `selection.png` na pasta da obra,
  e é validada por assinatura PNG, dimensões e limite de tamanho ao reabrir.
  Seleções inválidas são ignoradas sem afetar o conteúdo das camadas.
  A máscara não grava alterações sobre os pixels da pintura.
  O clipboard **não persiste** e não comunica com o Windows. Copiar/colar só manipula
  pixels da camada ativa, sem novos objetos ou camadas. Recortes de seleção,
  movimento, rotação e escala estão limitados a 1.048.576 pixels por documento;
  a varinha compara RGBA com tolerância mínima de quantização. A rotação
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
- O balde compara a cor RGBA da camada ativa com tolerância mínima de quantização,
  sem controlar tolerância por slider. Não equivale ao balde do ibisPaint.
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
  A suíte agora cobre feather de raio 1/2, pesos de alfa por pixel,
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
