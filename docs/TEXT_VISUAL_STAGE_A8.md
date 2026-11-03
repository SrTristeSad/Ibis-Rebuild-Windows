# Fase A8 — interface da ferramenta Texto

Referencias: [documentacao da engenharia reversa](RESEARCH.md),
[indice de evidencias](research/evidence-index.json) e
[tutorial oficial de Texto](https://ibispaint.com/lecture/index.jsp?no=37).

O tutorial publico documenta entrada de texto, alinhamento,
orientacao vertical, selecao de fontes, Tamanho, Estilo, Fundo
e Espacamento. O repositorio nao possui medicao pixel a pixel do
APK Android 14.1.2 para esse painel.

## Feito

- Ferramentas -> Texto abre popup independente em Lua/LÖVE.
- Abas Texto, Tamanho, Estilo, Fundo e Espaco, com navegacao
  por mouse e estado selecionado.
- Edicao local de rascunho UTF-8, apagamento, quebra de linha,
  alinhamento e orientacao. O texto digitado **nao** integra
  camadas nem e persistido no RBD2.
- Controles de parametros mostram valores locais; fontes e
  seletores de cores permanecem explicitamente pendentes.
- Escape e voltar retornam a Ferramentas. Fechar libera o foco.
- Sem substituicao do motor Lua, sem manipular pixels.
- Testes de geometria, Unicode e limites para 960x640,
  1220x800 e 1920x1080. Showcase com cliques reais em
  Ferramentas, Texto, entrada e Estilo, comparando bytes RGBA,
  contagem de undo e dirty flag.

## Pendente

Renderizacao, editor de cursor completo, criacao de camada de
texto, tipografia original, aplicacao dos parametros e comparacao
com capturas autenticadas do Android 14.1.2.
