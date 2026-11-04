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
- Composição visível em ordem de camadas com visibilidade e opacidade no modo normal.
- Undo/redo do raster por traço pelos botões existentes, Ctrl+Z / Ctrl+Y.
- Salvamento automático ao voltar do editor para a galeria, ou Ctrl+S.
  Os arquivos ficam na pasta de dados do LÖVE, em lua-artworks/, como PNG por camada,
  index.tsv e layers.tsv. As obras salvas são listadas ao reiniciar.

## Limitações explícitas
- **Não** há paridade com os algoritmos do ibisPaint oficial.
- Pincel circular, borracha, balde, conta-gotas e camadas normais têm implementação
  raster básica. Filtros, blending avançado, clipping, alpha-lock, seleções, formas,
  estabilização, pressão, máscaras, efeitos, texturas e demais ferramentas
  exibidas pelo Ibis-Lua continuam sem backend real nesta etapa.
- A rasterização por pixel feita em Lua é uma base funcional, não otimizada
  para telas enormes ou pincéis grandes.
- Histórico mantém até 8 snapshots de camada para telas até 32 MiB por
  snapshot; não persiste ao encerrar. Operações estruturais de camadas
  ainda não entram no histórico raster.
- O formato atual é PNG + metadados TSV, **não RBD2 nem IPV**.
- O catálogo reconstituído contém obras salvas; pastas e suas mudanças,
  seleção múltipla e outras ações da galeria ainda não são persistidas.
- As miniaturas da galeria agora mostram pixels reais somente para obras
  persistidas; a miniatura das camadas exibe o buffer da camada durante a edição.
  Itens demonstrativos e obras ainda não salvas podem continuar sem prévia.
- A seleção de modos de blending, Clipping e Alpha Lock ainda é apenas de UI.
  Enquanto qualquer um deles estiver selecionado, o motor bloqueia novas
  pinceladas/preenchimentos nessa camada e informa a limitação, em vez de
  aplicar um resultado incorreto silenciosamente.
- O balde compara a cor RGBA da camada ativa com tolerância mínima de quantização,
  sem controlar tolerância por slider. Não equivale ao balde do ibisPaint.
- A suíte de pixels usa o LÖVE real para verificar tinta, borracha, balde,
  leitura de cores, composição, miniatura e ciclo salvar/abrir PNG.
- Os testes Windows precisam passar no GitHub Actions antes de declarar a
  distribuição verificada.

## Como usar
1. git submodule update --init
2. python tools/assemble_lua.py
3. .\run.ps1 com LÖVE 11.5 instalado
4. .\test.ps1 valida os ganchos; o CI faz E2E de navegação e rasterização.

A interface foi desenvolvida com referência ao ibisPaint Windows 14.1.4,
sem validação 1:1. O motor não é cópia do aplicativo proprietário.
