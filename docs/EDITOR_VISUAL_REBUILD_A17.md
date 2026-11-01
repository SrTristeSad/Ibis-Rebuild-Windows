# A17 — Editor sem cabeçalho grande, ferramentas mais estreitas

## Referência

- [ibisPaint, capítulo 03: Toolbar and Tool Selection](https://ibispaint.com/lecture/index.jsp?no=4)
- [Captura real hospedada no ibisPaint](https://ibispaint.com/art/845226303/)
- Capturas comparativas geradas pelos testes LÖVE em `build/showcase`.

A captura pública mostra ferramentas pequenas em coluna estreita no
lado esquerdo, os seis botões superiores alinhados na borda, a
superfície de desenho sem faixa superior com título dominante e
dois controles horizontais sobre o rodapé.

## Revisão implementada

- O modo Compacto não desenha mais o cabeçalho cinza de 64 px.
- Ferramentas da coluna esquerda agora têm 68 px de largura,
  ícones acima de rótulos em fonte de 10 px, e começam na parte alta
  da tela. A lista de 15 ferramentas permanece completa.
- Os seis botões superiores agora flutuam a 8 px da borda.
- Os controles Windows Salvar/Desktop/Ajustes continuam presentes
  no canto superior esquerdo, com zoom em faixa independente menor.
- O canvas começa na borda superior, e o centro e a área editável
  seguem os mesmos parâmetros para evitar discrepância de clique.
- A região inferior distingue uma faixa cinza para os controles de
  espessura/opacidade e uma faixa escura somente para os ícones.
- As posições oficiais do Android 14.1.2 não foram medidas.
  Esta é uma revisão estrutural embasada em referência pública, não
  uma declaração de fidelidade pixel-a-pixel.

## Isolamento

Não foram alterados algoritmos raster, camadas, histórico RBD2,
arquivo de projeto, entrada Windows Ink ou os motores de pincel.
Teste real Windows e testes Lua verificam execução e geometria.

## Revisão dos rótulos após inspeção das capturas

Os nomes longos cortados na faixa de 68 px foram substituídos
por legendas curtas apenas no desenho da coluna; o catálogo
mantém nomes completos, ordem e callbacks originais. As legendas
estão centralizadas e não alteram áreas clicáveis.
