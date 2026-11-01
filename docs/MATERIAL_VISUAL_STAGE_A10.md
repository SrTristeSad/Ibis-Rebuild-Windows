# Fase A10 — biblioteca visual de Materiais

Referência primária: [RESEARCH.md](RESEARCH.md) e
[índice de evidências](research/evidence-index.json).
Não há extração validada de miniaturas, disposição pixel a pixel
ou catálogo de materiais original do Android 14.1.2.

Referências públicas complementares:
- https://ibispaint.com/lecture/index.jsp?lang=pt&no=42
  (Textura com ferramenta Material: padrões e busca por palavra-chave)
- https://ibispaint.com/lecture/index.jsp?no=186
  (Materiais de traçado, balões e fundos)

Essas categorias foram agrupadas para o rebuild com rótulos de
navegação próprios: não afirmamos que correspondam exatamente
às oito categorias ou à ordem do APK original.

## Implementado — exclusivamente interface

- O botão Materiais abre janela visual Lua/LÖVE 444x440.
- Oito categorias locais, incluindo tecidos, fundos, balões
  e grupos de esboços para traçado. A categoria clicada é
  destacada; nenhum material de verdade é criado.
- Campo de busca com foco, texto Unicode e botão Buscar.
  Consultas são armazenadas apenas em estado temporário da
  interface e retornam zero itens por falta de catálogo.
- Mensagem explícita de estado vazio; nenhuma miniatura
  fictícia nem simulação de download ou aplicação.
- Abrir, navegar, pesquisar e fechar a janela não afetam
  camadas, histórico, raster, documento nem serialização RBD2.
- Testes isolados em 960x640, 1220x800 e 1920x1080,
  cobrindo hitboxes, Unicode, estado vazio e limites.
- O showcase Windows tem duas novas capturas reais:
  29-materiais-categorias.png e 30-materiais-busca.png;
  cliques reais testam a categoria Fundos e a busca por
  "céu", comparando bytes RGBA, dirty e contagem de undo.

## Limites

Integração de catálogo online, thumbnails originais,
importação, aplicação de texturas, rede e operações de
transferência permanecem pendentes. Não há comparação
visual pixel a pixel com a build Android 14.1.2.
