# Fase A14 — Vetor e Dividir Quadros, sem motor simulado

Fontes:
- [pesquisa do projeto](RESEARCH.md) e
  [indice de evidencia](research/evidence-index.json), alvos Android 14.1.2.
- [Tutorial oficial 50: Vector Layer](https://ibispaint.com/lecture/index.jsp?no=191)
  descreve formas/vertices e o menu de ordenacao.
- [Tutorial oficial 63: Frame Divider](https://ibispaint.com/lecture/index.jsp?no=38)
  descreve Adicionar Quadro, espacos horizontal/vertical,
  espessura de borda, divisao de quadros e selecao de quadros.
As referencias publicas nao fixam dimensoes nem pixels da UI 14.1.2.

## Interface implementada

- As entradas ja existentes Vetor e Dividir Quadros no catalogo
  de 15 ferramentas passam a abrir popups independentes, sem
  entrar por engano no seletor de forma raster.
- Vetor: abas de Selecao, Vertices e Ordem com estado local,
  escolha visual entre selecao simples/multipla e
  representacao diagramatica original, sem camada vetorial.
  Acoes que exigem uma forma selecionada ficam desabilitadas.
- Dividir Quadros: abas Novo quadro, Dividir e Borda;
  ajuste local e limitado de espacos horizontal/vertical,
  espessura de borda e opacidade; orientacao demonstrativa
  horizontal/vertical; moldura simbolica em Lua/LÖVE.
  Criar/aplicar quadro fica desabilitado.
- Escape e botao voltar retornam ao catalogo de ferramentas.
- Sem escrita em canvas, mascaras, camadas, estruturas de
  documento RBD2, historico nem dirty flag.
- Testes standalone e suite LÖVE regressiva asseguram estados,
  limites e geometria em tres resolucoes, alem de isolamento
  do backend de Vetor e Quadros.
- Showcase Windows usa cliques reais sobre Vetor (Ordem),
  Dividir Quadros (espacamento) e sua aba Dividir, adicionando
  39-vetor.png, 40-dividir-quadros.png e 41-quadros-divisao.png.

## Motor pendente

Formato vetorial, camadas vetoriais, vertices, edicao e ordem
de formas, geracao de molduras, materiais de borda e corte
real de quadros. Nao declarar equivalencia 1:1 sem confronto
dinamico com capturas autenticadas do ibisPaint Android 14.1.2.
