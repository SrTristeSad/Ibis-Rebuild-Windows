# A16 — Reconstrução da composição do editor

A principal falha apontada pelo criador era de aparência, não de
número de ferramentas. A tela compacta possuía cartões grandes,
título de aplicativo dominante e controles espalhados. A mudança
foi baseada em uma captura pública real da interface ibisPaint:

- [Tela do editor, hospedada pelo ibisPaint](https://ibispaint.com/art/845226303/)
- [03. Barra de ferramentas e seleção](https://ibispaint.com/lecture/index.jsp?no=4)

## Mudanças reais na tela

- Faixa vertical cinza-escura **visível à esquerda do canvas** com
  15 ferramentas em ordem documentada, ícones vetoriais originais
  e navegação entre páginas para viewports baixos.
- A faixa usa a **mesma rotina de seleção** do popup: ferramentas
  implementadas ativam os motores Lua existentes; pendentes
  abrem painéis de rascunho com estado não executável.
- Barra inferior sem blocos com rótulos grandes; comandos em
  faixa contínua, ícones centrais, indicador da ferramenta ativa.
- Ajustes rápidos de diâmetro e opacidade passam a ficar em
  **duas linhas horizontais**, como nas referências, e continuam
  controlando o pincel/borracha reais.
- No editor compacto, o cabeçalho deixa de enfatizar o nome
  do rebuild; mostra percentual de zoom em barra discreta.
- Galeria e editor Desktop ficam com a interface anterior, para
  não quebrar o fluxo de trabalho e a organização das camadas.
- O raster Lua, o RBD2, as operações de camadas, undo, zoom e
  a entrada Windows Ink permanecem inalterados.
- Testes de geometria da faixa nas resoluções 960x640,
  1220x800 e 1920x1080 e smoke tests LÖVE com cliques reais.

## Limitações e próximo comparativo

Os exemplos públicos servem para estrutura e hierarquia,
não para certificar que fontes, espessuras, medidas e
comportamentos são idênticos à build Android **14.1.2**.
O confronto pixel a pixel ainda depende de imagens dessa
versão e do mesmo tamanho de viewport. Não houve extração
nem inclusão de assets do APK.

## Segunda revisão de proporção do rodapé

A inspeção das capturas de CI revelou uma região inferior excessiva.
A faixa do editor compacto ocupa agora aproximadamente 130 px de
altura em vez de 184 px; os controles de espessura e opacidade
continuam empilhados, e o dock com ícones foi rebaixado ao rodapé.
O canvas recupera 60 px de espaço vertical e sua área de clique e
recorte acompanham a nova geometria, sem deformar ou editar pixels.
