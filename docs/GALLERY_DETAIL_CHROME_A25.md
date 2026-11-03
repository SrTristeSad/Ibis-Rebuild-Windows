# Fase A25 — Ícones vetoriais na visualização ampliada (02/11/2026)

## Diferença observada
A captura real `122-galeria-imagem-ampliada.png` do workflow Windows
mostra os comandos de reprodução, compartilhamento e mais opções
como glifos ausentes/quadrados porque a fonte instalada pelo LÖVE
não contém os caracteres usados pela A24. A barra também não mostrava
o botão "+" observado na referência oficial.

## Referência e confiança
- Tutorial oficial ibisPaint #20, "View Your Artwork":
  https://ibispaint.com/lecture/index.jsp?lang=en&no=20
- Captura de referência: https://ibispaint.com/img/lecture/en/chapter_20_02.png
- Captura real do rebuild: artefato `IbisRebuild-Lua-Real-Screenshots`
  do workflow da branch `migration/lua-only-engine`.
- Evidência visual pública de hierarquia/ordem, **não** medição
  geométrica autenticada da versão Android 14.1.2.

## Correção
- Adicionadas as cinco figuras vetoriais em `app/ui_icons.lua`.
- Geometria do rodapé isolada em `app/ibis_gallery_detail.lua`,
  com teste em 960x640, 1220x800 e 1920x1080.
- No `app/main.lua`, chamadas de desenho substituem os caracteres
  ilegíveis. O "+" usa o menu de criação já implementado na galeria.
- Informações, reprodução, compartilhamento e mais opções permanecem
  **não interativos** até existirem implementações corretas.
- Não foi alterado o motor raster, RBD2, camadas, histórico, Windows Ink
  nem o comportamento do botão Editar e dos gestos.

## Validação
A execução do CI correspondente ao commit desta fase e a inspeção da
captura atualizada precisam ser verificadas antes da aprovação visual.
Nenhuma alegação de equivalência pixel a pixel é feita.
