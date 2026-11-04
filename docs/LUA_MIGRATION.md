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
- Seleções limitam a pintura e o balde à máscara ativa. O contorno da
  seleção aparece sobre a tela de edição; Ctrl+D ou Esc desfazem a seleção.
  Mover pixels da camada ativa é um único passo reversível no histórico
  (undo/redo também restaura a posição da máscara enquanto ela estiver ativa).
- Undo/redo do raster por traço pelos botões existentes, Ctrl+Z / Ctrl+Y.
- Salvamento automático ao voltar do editor para a galeria, ou Ctrl+S.
  Os arquivos ficam na pasta de dados do LÖVE, em lua-artworks/, como PNG por camada,
  index.tsv, layers.tsv e document.tsv. As obras salvas são listadas ao reiniciar.
  O novo layers.tsv preserva nome, visibilidade, opacidade, blending selecionado,
  Clipping, Alpha Lock e bloqueio; arquivos antigos de quatro campos ainda abrem.
  document.tsv guarda a camada ativa e o modo de fundo.

## Limitações explícitas
- **Não** há paridade com os algoritmos do ibisPaint oficial.
- Pincel circular, borracha, balde, conta-gotas, Alpha Lock, recorte básico por
  Clipping e os nove modos de mesclagem visíveis têm implementação independente.
  Filtros, seleção por tolerância ajustável, rotação e escala da
  seleção, formas, estabilização, pressão, máscaras adicionais, efeitos,
  texturas e demais ferramentas
  exibidas pelo Ibis-Lua continuam sem backend real nesta etapa.
- A rasterização por pixel feita em Lua é uma base funcional, não otimizada
  para telas enormes ou pincéis grandes.
- Histórico mantém até 8 snapshots de camada para telas até 32 MiB por
  snapshot; não persiste ao encerrar. Operações estruturais de camadas
  ainda não entram no histórico raster.
- A seleção atual é **temporária**, não persiste ao salvar nem possui
  copiar/colar, redimensionar ou rotacionar. Os recortes de seleção e a
  transformação estão limitados a 1.048.576 pixels por documento; a
  varinha compara RGBA com tolerância mínima de quantização. O movimento
  é deslocamento inteiro, limitado para manter a máscara dentro do canvas.
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
  restrição de pintura à seleção, mover pixels e desfazer/refazer.
- Os testes Windows precisam passar no GitHub Actions antes de declarar a
  distribuição verificada.

## Como usar
1. git submodule update --init
2. python tools/assemble_lua.py
3. .\run.ps1 com LÖVE 11.5 instalado
4. .\test.ps1 valida os ganchos; o CI faz E2E de navegação e rasterização.

A interface foi desenvolvida com referência ao ibisPaint Windows 14.1.4,
sem validação 1:1. O motor não é cópia do aplicativo proprietário.
