# A47 — Ícones Pincel, Borracha e Balde próximos da referência Windows

## Imagem de referência

- [Microsoft Store oficial: ibisPaint Windows](https://apps.microsoft.com/detail/9pfdf2zd4z4n)
- [IMG-M04 do atlas visual](pesuisar-base/02_ATLAS_VISUAL.md):
  ![Referência Windows mostrando Pincel, Borracha e Lata de Tinta](https://store-images.s-microsoft.com/image/apps.32378.14202576542330599.5d8d33ef-6e70-4d7f-953d-99930bb9592a.1715e9a7-d182-4d1e-a9b7-883949af7782)

A imagem é oficial para Windows, porém **promocional e sem versão,
DPI ou escala registrados**. Confirma as silhuetas reconhecíveis
usadas pela barra lateral, não suas medidas definitivas.

| Ferramenta | A46 | Direção A47 |
|---|---|---|
| Pincel | Traço diagonal simples e ponto | Cabo, virola e cerdas inclinados |
| Borracha | Contorno de polígono | Bloco diagonal preenchido |
| Balde | Contorno genérico e gota redonda | Recipiente inclinado e gota separada |

## Escopo de implementação

- Modificado somente o desenho dos três glifos existentes em
  \`app/ui_icons.lua\`: \`brush\`, \`erase\` e \`fill\`.
- O registro é compartilhado entre a faixa lateral, o popup e o
  ícone Pincel da barra inferior. A identificação das ferramentas
  continua por \`id\`; nenhum callback/atalho mudou.
- \`app/main.lua\`, \`app/ibis_editor_rail.lua\`,
  \`app/compact_layout.lua\`, raster, RBD2 e Windows Ink
  **não foram modificados**.
- Testes LuaJIT cobrem integridade geométrica das 15 ferramentas
  (com os três novos glifos), identidade do Pincel entre faixas,
  sem reutilização indevida do glifo por Eraser/Bucket e
  silhuetas estruturais esperadas.
- CI Windows com LÖVE real produz capturas do editor; comparar
  com A46 para garantir que os únicos efeitos visuais esperados
  ocorreram nos três ícones.

## Não alegar

- Fidelidade 1:1 com uma build Windows específica.
- Uso ou extração de assets proprietários originais.
- Implementação funcional de novos submodos do Balde.
- Alteração dos controles inferiores para uma geometria não
  comprovada na versão-alvo PC.

Esta alteração implementa **reconhecimento visual**, mantendo o
objetivo do clone PC e os critérios da \`PESUISAR_BASE.md\`.
PR #66 permanece Draft; não mesclar em \`main\`.
