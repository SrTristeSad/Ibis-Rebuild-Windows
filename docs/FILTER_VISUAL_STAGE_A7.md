# Fase visual 7 — catálogo de filtros (interface, não motor)

Referência principal do projeto: [RESEARCH.md](RESEARCH.md) e
[research/evidence-index.json](research/evidence-index.json).
Os relatórios de engenharia reversa do Android 14.1.2 não comprovam
a disposição exata das miniaturas e controles da janela de filtros.

Referência complementar: [tutoriais oficiais ibisPaint](https://ibispaint.com/lecture/index.jsp?no=00)
para os nomes e categorias, e [atualizações oficiais](https://ibispaint.com/newFeature.jsp)
para o padrão geral de categoria e miniaturas. Esses documentos não
constituem uma comparação dinâmica com o APK 14.1.2.

## Entregue

- O botão **Filtro**, no seletor compacto de 15 ferramentas, abre uma
  janela dedicada e conserva a ferramenta real ativa no motor Lua.
- Oito categorias documentadas com lista navegável, até cinco opções
  por página e botões de avanço/retorno. Nenhuma ferramenta inventada.
- Cartões apresentam nomes e miniaturas **neutras**, explicitamente
  sem prévia do efeito, porque o processamento ainda está pendente.
- Selecionar um filtro altera apenas o destaque visual e a mensagem
  de estado; não altera pixels, camadas, RBD2, dirty flag ou undo.
- A seta do cabeçalho e Escape retornam à janela de ferramentas.
- Geometria isolada em `app/ibis_filter_ui.lua`, sem dependência de
  LÖVE; testes em 960×640, 1220×800 e 1920×1080 validam limites,
  colisões, paginação e inexistência de operação de filtros.
- Showcase Windows na captura `24-catalogo-filtros.png`: cliques
  reais em Ferramentas → Filtro → Desfoque → Desfoque gaussiano, com
  verificação de RGBA e histórico antes e depois.

## Pendências e limites

A biblioteca visual não contém os algoritmos de filtros nem gera
miniaturas de resultados. Não há fidelidade pixel a pixel demonstrada;
a geometria e os estilos dependem de comparação posterior com
capturas autenticadas do Android 14.1.2. Não usar os títulos e
nomes desta fase para afirmar que toda opção já existia na mesma
posição na versão-alvo.
