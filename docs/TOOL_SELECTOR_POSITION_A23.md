# Fase A23 — posição real do seletor de ferramentas (02/11/2026)

## Referências e grau de certeza

- [ibisPaint — Toolbar and Tool Selection](https://ibispaint.com/lecture/index.jsp?no=4): catálogo e seleção de ferramentas.
- [ibisPaint — Settings window details](https://ibispaint.com/lecture/index.jsp?no=185): localização e preferências da interface.
- [Evidências derivadas do Android 14.1.2](RESEARCH.md) e [índice](research/evidence-index.json): **não** comprovam coordenadas exatas dessa tela.

## Problema corrigido

O painel Configurações indicava "Popup" como selecionado enquanto
o editor compacto mantinha a coluna esquerda sempre presente; as
opções Esquerda/Direita estavam desabilitadas. A informação visual
não correspondia ao comportamento real.

## Implementação Lua

- `app/ibis_settings_ui.lua`: valida as três posições. Para
  instalações existentes sem preferência salva, a inicialização
  escolhe **Esquerda**, preservando a faixa já usada.
- `app/ibis_editor_rail.lua`: mesma coleção de 15 ferramentas e
  hitboxes no lado esquerdo ou direito. No lado direito a primeira
  linha começa em 64 px para não cobrir a barra superior. O cálculo
  de paginação reserva a altura do navegador de páginas.
- `app/main.lua`: opções de Configurações agora alteram e salvam
  `toolRailPosition` no Store. O modo Popup oculta a faixa
  lateral e seus botões, mantendo acesso ao seletor pela barra
  inferior. Os callbacks de ferramentas existentes são reutilizados,
  inclusive para ferramentas pendentes, sem escrever no raster.
- `tests/test_ibis_settings_ui.lua` e
  `tests/test_ibis_editor_rail.lua`: persistência, posições e
  não sobreposição em 960×640, 1220×800 e 1920×1080.
- Showcase Windows amplia a prova de interface real para os estados
  **120-ferramentas-direita.png** e
  **121-ferramentas-popup-sem-faixa.png**, com verificação de
  hitboxes e invariância de bytes RGBA e histórico.

## Limites e validação

A semântica das posições segue o tutorial público e uma adaptação
Windows; **não** é validação pixel a pixel do Android 14.1.2.
As capturas provam a interface do rebuild LÖVE, não a aparência
do aplicativo original. Não houve alteração no raster, RBD2,
Windows Ink, camadas nem na branch `main`.
