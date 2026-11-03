# A49 — Seleção de ícones livres para a interface Windows

## Mudança aplicada

O glifo **Conta-gotas** (`picker`) do arquivo `app/ui_icons.lua` foi
substituído por uma adaptação vetorial para Lua do ícone aberto
[Tabler color-picker](https://github.com/tabler/tabler-icons/blob/main/icons/outline/color-picker.svg).
A geometria foi convertida para o espaço normalizado já usado por `Icons.draw`
(escala aproximada de 24 para 16 unidades), e os cantos arredondados do
SVG foram representados como segmentos de reta. Nenhum motor, ID, atalho,
hitbox, comando, formato RBD2 ou arquivo proprietário foi alterado.

**Autor e licença:** Tabler Icons, copyright (c) 2020-2026 Paweł Kuna,
licença MIT. Texto integral abaixo, que deve acompanhar redistribuições
dessa adaptação.

## Avaliação de outras ferramentas

- Pincel, Borracha e Balde: as silhuetas já documentadas na A47
  correspondem melhor à referência Windows IMG-M04 que os ícones
  genéricos `brush`, `eraser` e `bucket` do Tabler (que são
  predominantemente contornados e, no caso do bucket, vertical).
  Sem substituição neste estágio.
- Camadas: o desenho A48 das três folhas permanece mais próximo
  da imagem Windows do que o ícone genérico `layers-subtract`.
- Varinha, Laço e Filtro: preservar A46, pois os candidatos abertos
  examinados não comprovam ganho de fidelidade.
- Ferramentas, Ajustes e Tela: não alterar layouts ou glifos sem
  captura Windows específica confirmando a geometria.

## Verificações e limitações

`tests/test_ui_icons.lua` verifica o registro e a silhueta vetorial
do Conta-gotas. Os testes CI devem ser avaliados no commit final;
não inferir aprovação de Windows/LÖVE apenas pelos testes de estrutura.

A comparação é de *silhuetas* e não uma comparação pixel-a-pixel com
uma versão instalada do ibisPaint no Windows. O glifo adaptado não é
um asset oficial do ibisPaint. A PR #66 permanece Draft e não deve
ser mesclada à main automaticamente.

## Licença MIT — Tabler Icons

MIT License

Copyright (c) 2020-2026 Paweł Kuna

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
