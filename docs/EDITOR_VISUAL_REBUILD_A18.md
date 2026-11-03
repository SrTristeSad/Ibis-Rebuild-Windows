# A18 — Paleta de ferramentas e janela de camadas

## Referências públicas

- [Toolbar and Tool Selection, capítulo 03](https://ibispaint.com/lecture/index.jsp?no=4):
  o seletor popup possui 1, 2 ou 3 colunas, e os 15 ícones têm
  ordem definida; os botões não mostram placas de "Pronto/Pendente".
- [Layer Window Details](https://ibispaint.com/lecture/index.jsp?no=156):
  a camada de seleção ocupa linha distinta, camadas reais exibem
  miniaturas/visibilidade, e o painel abre junto à barra inferior.
- Evidência específica Android 14.1.2:
  [research evidence index](research/evidence-index.json) (comparação
  pixel a pixel ainda indisponível).

## Alterações

- Popup Ferramentas configurado com **2 colunas**, 242 px de largura,
  383 px de altura e posição inferior esquerda ao lado da faixa.
- Quadro flutuante com contorno fino, sem filete azul genérico;
  botões de ferramenta compactos, com ícone e legenda centralizados.
- Estados pendentes não ocupam uma segunda legenda dentro de cada
  botão, mas continuam sem executar operações raster.
- Fechar com X, Escape, botão de ferramentas ou clique externo;
  mesmo motor Lua existente e mesma ordem dos 15 comandos.
- Popup Camadas reposicionado próximo à área inferior direita,
  preservando thumbnails, linha de seleção, visibilidade, duplicação,
  exclusão, opacidade, histórico e mesclagem disponível.
- 46-paleta-ferramentas.png e 47-janela-camadas.png são capturas
  reais LÖVE com verificação de não alteração do documento.
- Geometria e colisões verificadas em 960x640, 1220x800 e 1920x1080.

## Ainda não resolvido

O restante dos painéis usa layouts provisórios, e a paleta atual
não implementa personalização 1-3 colunas. Não há calibração visual
com screenshots da compilação exata Android 14.1.2, nem motor
para as ferramentas marcadas como não implementadas.
