# A38 — Editor compacto sem controles desktop permanentes

Data: 02/11/2026. Branch: migration/lua-only-engine.

## Diferença identificada

A captura LÖVE real `02-editor-compacto.png` da A37 (workflow Windows
41563417901) exibe permanentemente seis controles de conveniência
Windows no canto superior esquerdo: Salvar, Desktop, Ajustes, -/+, Ajustar.

A referência pública do fabricante organiza o editor ao redor da barra
principal inferior, da janela seletora de ferramentas e dos controles
do canto superior direito. Esses seis controles Windows não pertencem
à composição documentada.

- Fonte oficial: https://ibispaint.com/lecture/index.jsp?lang=pt&no=04
- Fontes técnicas derivadas da versão-alvo:
  `docs/RESEARCH.md`, `docs/research/evidence-index.json`.
- Captura real: artefato `IbisRebuild-Lua-Real-Screenshots` do workflow
  Windows da branch; **é do rebuild, não do ibisPaint original**.

A referência oficial pode retratar outra versão, e não foram recuperadas
medidas reais de tela do APK 14.1.2. Isso continua sendo uma correção
de estrutura, não uma reivindicação de equivalência pixel a pixel.

## Implementação

- `app/ibis_windows_hud.lua`: layout puro e hit-test dos seis comandos
  originais. Exposto **somente com F10** no editor compacto.
- `app/main.lua`: o editor compacto já não desenha nem registra as
  hitboxes desses comandos por padrão. F10 exibe/oculta temporariamente
  o painel. O painel também é ocultado ao abrir subpainéis, trocar modo,
  focar o canvas ou reabrir o documento.
- Teclas já existentes continuam: `Ctrl+S` salvar; `+/-` zoom;
  `0/F` ajustar; `Tab` modo foco. Desktop e Ajustes estão acessíveis
  através de F10; a barra inferior de propriedades continua funcionando.
- A ajuda F1 indica a tecla F10, sem alterar atalhos anteriores.
- `tests/test_ibis_top_toolbar.lua`: geometria 960×640,
  1220×800 e 1920×1080, estados de visibilidade, hitboxes invisíveis
  proibidas e preservação dos comandos.

## Preservação e validação exigida

Sem mudanças em raster, RBD2, camadas, pincéis, histórico nem Windows Ink.
A PR permanece draft; não mexer na branch main.

Validar LuaJIT Linux, testes Windows e screenshot LÖVE real. A interface
normal deve deixar livre o canto superior esquerdo; o painel PC apenas
é uma adaptação documentada. Não considerar paridade com Android 14.1.2.

## Validação GUI adicional

O smoke Windows com LÖVE real passou a verificar o estado F10
fechado (nenhuma hitbox), abertura por tecla, registro dos três
comandos superiores, clique real em **Ajustes** e seu fechamento
por Escape. O teste exige bytes RGBA e histórico inalterados.
O autoteste legado de troca de layout também passa a retornar
por F10 → Desktop, preservando o callback existente.
