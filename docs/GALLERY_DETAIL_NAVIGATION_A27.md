# Fase A27 — Navegação discreta da galeria ampliada (02/11/2026)

## Comparação
Captura real `122-galeria-imagem-ampliada.png` do rebuild A26:
duas setas laterais escuras de 46×50 ficam sempre sobre o conteúdo.
A referência oficial do tutorial #20 demonstra gestos horizontais
sem esses botões fixos:
https://ibispaint.com/lecture/index.jsp?lang=en&no=20
https://ibispaint.com/img/lecture/en/chapter_20_02.png

## Correção
- `app/ibis_gallery_detail.lua`: guarda de hover geométrico
  `navRevealed`, independente de documentos.
- `app/main.lua`: mostra as setas exclusivamente quando o cursor
  está perto do respectivo controle e há outra obra na direção.
  **Nenhuma hitbox é criada enquanto o botão está oculto.**
- `app/ui_icons.lua`: duas setas vetoriais originais (sem glifos
  dependentes da fonte instalada).
- `tests/test_ibis_gallery_detail.lua`: limites e hover em três
  resoluções. Gestos, atalhos, botão Editar, RBD2 e ordenação não mudam.

## Validação e limites
A referência oficial orienta o comportamento, mas não autentica
geometria da versão Android 14.1.2. A navegação por hover é
adaptação específica para Windows. Exige execução do CI e inspeção
das capturas do commit. Sem alegação de reprodução pixel a pixel.
