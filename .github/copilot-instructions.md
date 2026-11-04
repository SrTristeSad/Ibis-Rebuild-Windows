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
- Seleção raster ativa fica em bridge/lua_selection.lua: Varinha Mágica,
  Laço e seleção retangular via Transformar. Transformar move apenas pixels
  selecionados da camada ativa com undo/redo; pincel e balde respeitam
  a seleção. Testar pixels não selecionados, histórico e bordas.
- Histórico raster persiste em `history.tsv` e PNGs versionados por geração
  para documentos de até 1.048.576 pixels, com até 8 snapshots em cada
  pilha (undo e redo). Os arquivos de snapshot devem ser validados em
  conjunto: um item corrompido invalida todo o histórico, mas nunca
  impede reabrir os PNGs da obra. Descarte históricos de camadas removidas
  sem bloquear o salvamento. Teste reabertura com duas camadas e seleção.
- Seleção ativa persiste em `selection.png` por obra (máscara binária),
  sem mudar os PNGs das camadas; arquivo ausente, corrompido ou com dimensões
  incorretas não pode impedir a abertura do projeto. Desmarcar e salvar remove
  o arquivo anterior. O histórico de seleção não persiste e a seleção fica
  limitada a 1.048.576 pixels. Copiar/recortar/colar operam em clipboard
  INTERNO do Lua, não na área de transferência do Windows. Rotação 90° e escala 50%/200% são raster nearest-neighbour,
  ancoradas no canto superior esquerdo e devem rejeitar saída fora do canvas.
- Atalhos sem novos controles: Ctrl+C/X/V (clipboard), Ctrl+Shift+R/L
  (giro horário/anti-horário), Ctrl+Shift+Up/Down (200%/50%).
  Preserve undo/redo de pixels e geometria, compatibilidade com a máscara
  de seleção e testes da transformação.
- Rotação livre e escala X/Y independente usam `Engine.affine_selection`
  com mapeamento inverso e filtro opcional (`nearest` por padrão). Em Transformar:
  Alt+arrastar gira relativamente ao centro da seleção, Shift+arrastar
  redimensiona nos dois eixos, sem alterar o layout/controles visuais.
  Os gestos Alt/Shift mostram prévia bilinear sobre uma camada virtual
  (composição com outras camadas preservada), sem alterar buffers reais
  ou histórico durante o arraste. Aplicar ao soltar com o mesmo filtro,
  liberar o recurso gráfico da prévia ao encerrar/cancelar.
  O movimento sem modificadores permanece como antes.
  A bilinear deve interpolar RGB premultiplicado por alfa e não
  misturar pixels fora da seleção. Rejeitar parâmetros NaN/infinito,
  fator fora de 0,1..8 e retângulo fora do canvas SEM alterar pixels,
  máscara ou histórico. Preservar testes de undo/redo e RGBA.
- Não alegue prévia do movimento simples, interpolação bicúbica,
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
