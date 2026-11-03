# A42 — Conta-gotas rápido pelo botão direito no Windows

## Evidência oficial

- [Gestures, Keyboard shortcuts (Windows Version)](https://ibispaint.com/lecture/index.jsp?no=167): clique direito sobre o desenho com Pincel selecionado lê a cor e mantém o Pincel.
- [Comunicado 13.1.0, 26/05/2025](https://ibispaint.com/information.jsp?newsID=179933299): inclusão do Quick Eyedropper acionado por clique direito no Windows.
- [Novidades do fabricante](https://ibispaint.com/newFeature.jsp): confirma a sequência de uso e a permanência no pincel.

**É um comportamento Windows comprovado. Não é um desenho inferido da interface Android.**

## Mudança implementada

Em app/main.lua, o botão direito do mouse (2 no LÖVE) deixa de iniciar pan quando a ferramenta brush está ativa sobre um pixel válido do canvas. Ele usa pickColor já existente para ler o RGBA da composição ou da camada ativa segundo a preferência atual, mantendo o pincel ativo.

A coleta só acontece com documento/editor aberto, sem ferramentas pendentes, sem modal/popup/menu/contexto, sem Espaço segurado ou pan em curso. Qualquer botão visível registrado é uma área bloqueada: clicar nele não atravessa a interface para acessar pixels escondidos. Fora do canvas, não inventamos cor.

Permanecem o pan por botão central (3) e Espaço + botão esquerdo; para outras ferramentas, o pan direito existente não foi alterado. Não foram criados novos ícones, telas ou menus.

## Teste no GUI real Windows

O smoke oficial LÖVE:
1. Pinta um pixel e testa undo/redo e composição RGBA.
2. Calcula a posição de tela do pixel (20,20), inclusive zoom, rotação e deslocamento.
3. Emite mousepressed e mousereleased com botão 2, lê a cor obtida e confirma permanência em brush, ausência de pan e de pintura.
4. Reproduz clique direito sobre faixa lateral e com popup Ferramentas aberto; a cor e o pan não podem mudar.
5. Muda para borracha e confere pan legado com botão direito e liberação correta.
6. Confere bytes RGBA e passos de histórico inalterados.

Motor raster Lua, camadas, RBD2 e Windows Ink preservados. PR #66 permanece Draft, main não é alterada. Essa implementação NÃO comprova visualmente a interface do aplicativo PC.

## Limitações

Lupa de amostragem, seleção da camada de conteúdo e comportamento de stylus físico não foram verificados na versão Windows específica, portanto não foram inventados.
