# Etapa 31 — Interface compacta inspirada na navegação Android

A Etapa 31 aproxima a organização do editor Windows dos fluxos públicos do ibisPaint, sem afirmar que a reconstrução já seja visualmente 1:1.

## Referência verificada

O tutorial oficial de navegação do ibisPaint (<https://ibispaint.com/lecture/index.jsp?no=4>) descreve os sete acessos da barra principal, nesta ordem: **Pincel/Borracha**, **Ferramentas**, **Propriedades**, **Cor**, **Tela cheia**, **Camadas** e **Voltar**. A versão atual do aplicativo Android tem interfaces responsivas; portanto o layout Windows desta etapa é uma **adaptação independente**, e não uma cópia exata extraída do APK 14.1.2.

## Como usar

Ao abrir um projeto numa execução normal, o editor apresenta a **barra inferior compacta**. Os botões foram conectados à mesma lógica já implementada: Pincel alterna Pincel/Borracha, Ferramentas abre uma paleta de oito ferramentas disponíveis, Ajustes abre as propriedades atuais, Cor abre o editor hexadecimal, Tela chama o modo foco, Camadas abre a janela raster flutuante, Voltar retorna à galeria. O cabeçalho oferece **Layout desktop** para restaurar a antiga barra superior com painel lateral; o botão **Layout compacto** volta à organização inferior.

A **janela de camadas** exibe miniaturas RGBA verdadeiras e permite selecionar, alternar visibilidade, adicionar, duplicar, excluir, renomear, mesclar abaixo e alterar opacidade. A lista paginada preserva o limite atual de oito camadas. A janela de ferramentas usa os ícones vetoriais existentes e atalhos 1 a 8. Os ajustes compactos usam o mesmo estado e as mesmas operações de diâmetro, opacidade, estilo e estabilização, além da tolerância quando o Balde está selecionado. Os controles detalhados do layout desktop permanecem disponíveis.

O canvas aumenta horizontalmente sem o painel lateral permanente; um limite inferior separado impede pintar sobre a barra principal. Zoom, rotação, pan, raster, camadas, RBD2, bibliotecas de pincel e Windows Ink continuam usando o motor existente.

## Segurança e testes

- `app/compact_layout.lua`: geometrias puras das sete ações e dos popups, sem imagens, dependências de LÖVE ou operações de pixels.
- `tests/test_compact_layout.lua`: valida ordem baseada no tutorial oficial, limites mínimos de clique, janelas adaptadas aos tamanhos Windows 960×640, 1220×800 e 1920×1080, separação de canvas/barra e transformação de coordenadas.
- Autoteste gráfico LÖVE: troca entre layouts, abre e usa paletas, muda ferramenta e parâmetro, abre o editor de cor, entra/sai da janela de camadas, altera estrutura de camadas e a desfaz, e confirma que cliques de fechamento não atravessam até a obra.
- CI Windows x64: compila o motor nativo, testa LuaJIT/C++ e ambas as rotas oficiais de inicialização LÖVE antes de disponibilizar pacote.

**Limitações:** as oito ferramentas do editor independente não equivalem à gama completa de ferramentas Android; as janelas compactas têm controles somente para os comportamentos realmente implementados, sem prometer modos de mesclagem, camadas vetoriais, texturas ou paletas do Android ainda ausentes. O programa continua separado do Inkora, sem WebView e sem redistribuir assets Android.
