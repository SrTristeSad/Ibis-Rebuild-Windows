# Fase A13 — Borrar, Desfoque e Caneta Especial

## Fontes e limites de evidencia

A referencia principal continua sendo [RESEARCH.md](RESEARCH.md)
e [evidence-index.json](research/evidence-index.json). Fontes publicas:

- [Ferramentas na barra](https://ibispaint.com/lecture/index.jsp?no=4):
  Borrar, Desfoque e Caneta Especial sao acoes distintas.
- [Parametros de pincel](https://ibispaint.com/lecture/index.jsp?no=118):
  tamanho/opacidade e familias de texturas para Borrar/Desfoque.
- [Liquify](https://ibispaint.com/lecture/index.jsp?no=138):
  Arrastar, Encolher, Expandir, Suavizar, Reverter, Forca.
- [Caneta Copia](https://ibispaint.com/lecture/index.jsp?no=141):
  Copia Relativa/Fixa.
- [Comunicado oficial 8.0.0](https://ibispaint.com/information.jsp?newsID=15599838):
  os seis tipos originais de Caneta Especial.

## Implementado

- Cada uma das tres ferramentas, ja presente no seletor
  de 15 acoes, abre agora seu **proprio popup**, sem alterar
  a ferramenta de pintura Lua ativa.
- Borrar/Desfoque possuem tamanho e opacidade de
  **rascunho**, com botoes de incremento e decremento,
  limites e uma miniatura vetorial simbolica local.
- Caneta Especial lista seis subtipos documentados:
  Liquify, Preencher Laco, Apagar Laco, Copia Relativa,
  Copia Fixa e Copia Movel.
- Dentro do Liquify, os cinco modos publicos e o
  parametro Forca aparecem em controles locais.
- Outros subtipos exibem exclusivamente estado
  indisponivel e descricao.
- Navegacao volta ao seletor; nenhum motor de
  efeitos, deformacao, copia ou selecao e invocado.
- Quatro novos estados do showcase grafico real
  capturam Borrar, Desfoque, Caneta Especial e
  Liquify. Os testes clicam em controles reais
  e verificam que RGBA, selecao, camada, undo,
  dirty e ferramenta ativa ficam intactos.
- Suite de Lua puro valida contratos, clamps, limites,
  subtipos, geometria e isolamentos em 960x640,
  1220x800 e 1920x1080.

## Pendente

Catalogo real de pontas, filtros de mistura,
blur incremental, copy stamp, deformacao,
operacoes de Laco, equivalencia do motor e
comparacao de interface 1:1 com capturas
autenticadas do ibisPaint Android 14.1.2.
