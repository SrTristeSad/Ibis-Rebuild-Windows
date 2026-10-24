# Etapa 25 — Acabamento da interface do editor Windows

Continuação da Etapa 24, sem modificação de Inkora, do raster C++, do RBD2 nem dos comandos de edição existentes.

## O que mudou

- Faixa de ferramentas com **oito ícones vetoriais próprios** (Ver, Pixel, Pincel, Borracha, Balde, Seleção, Formas, Conta-gotas), desenhados diretamente por LÖVE e sem depender de PNG, WebView ou fontes de ícones. Texto curto sob cada ícone e sinalização em azul para a ferramenta ativa.
- Paleta de interface mais uniforme: plano de trabalho cinza, superfície de painel antracite, botões com bordas, seleção azul e textos em alto contraste.
- Visualização das camadas com miniaturas RGBA reais sobre xadrez de transparência; identificação da camada ativa por filete azul e seleção menos agressiva.
- Indicador passivo da opacidade da camada ativa, preservando os botões originais que realmente a ajustam.
- Cabeçalho e título da janela simplificados, sem texto permanente de infraestrutura/debug.
- Canvas recebe superfície visual independente; o checkerboard interno e os pixels continuam intactos.

**Compatibilidade:** os oito botões de ferramentas mantiveram exatamente os retângulos de clique anteriores. Atalhos 1–8, F1/H, histórico, zoom, RBD2, Windows Ink, camadas, modal e rotinas de teste permanecem disponíveis.

## Testes

- `tests/test_ui_icons.lua`: exige geometria completa para as oito ferramentas, coordenadas limitadas, IDs únicos e ausência de dependências de arte externa; integrado ao teste LuaJIT.
- Autoteste LÖVE: desenho de todos os ícones, verificação dos oito alvos reais de clique, troca de ferramentas e ausência de alterações no RGBA, número de camadas e histórico.
- GitHub Actions Windows x64 compila, roda LuaJIT+C++, testa as rotas LÖVE e executável standalone e publica apenas builds aprovadas.

## Escopo e limitações

Esta etapa aprimora a **apresentação própria** do aplicativo. Não há referência dinâmica do ibisPaint Android 14.1.2 sendo executada lado a lado; portanto **não se declara paridade visual 1:1**. Falta trabalho de navegação, menus e composição espacial para aproximar toda a interface do original.
