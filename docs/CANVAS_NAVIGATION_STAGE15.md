# Etapa 15 — Navegação da tela de desenho

Incremento no aplicativo Windows x64 existente, LuaJIT/LÖVE 11.5 e C++ nativo. Esta etapa não modifica o rasterizador, o formato RBD2, as camadas, a pressão de caneta ou o Inkora.

## Como navegar

- **Roda do mouse:** amplia ou reduz em torno do ponto sob o cursor, quando o cursor está sobre a tela de desenho. Se o cursor está fora da tela editável, o zoom usa o centro do espaço de trabalho.
- **Shift + roda:** gira o desenho em passos de 5 graus em torno do cursor. Sobre o painel de camadas, o comportamento preexistente da roda para alternar camadas continua.
- **Espaço + botão esquerdo + arraste:** desloca a visualização, sem criar qualquer pincelada ou ação no histórico.
- **Botão do meio ou direito + arraste:** também desloca a visualização sobre o espaço de desenho.
- **Teclas + / -:** ampliam e reduzem a partir do centro do espaço de trabalho. **Q / E:** rotação em passos de 15 graus; **R:** volta a 0 grau sem mover o centro; **0 ou F:** ajusta e recentraliza a obra.
- **Barra inferior de navegação:** botões de aproximação e afastamento, rotação à esquerda e direita, ângulo 0° e Encaixar. O zoom atual aparece ao lado.

O editor mantém os pixels, camadas, histórico e formato do projeto absolutamente inalterados em qualquer uma dessas ações. Zoom varia de 5% a 3200%; no limite não ocorre mudança adicional. Os gestos não incluem zoom multitoque, rolagem cinética ou gestos proprietários do ibisPaint Android.

## Implementação e preservação de ponto focal

O módulo Lua puro `app/canvas_view.lua` centraliza o mapeamento de coordenadas entre a tela lógica do LÖVE e o documento raster. Para zoom e rotação com ancoragem, primeiro calcula a coordenada de pixel sob o cursor, altera zoom/ângulo e corrige `panX/panY` para que aquele mesmo pixel continue sob o cursor. A mesma função de mapeamento é utilizada para desenhar, selecionar e editar, evitando divergências.

A navegação com arraste é processada antes das ferramentas: enquanto o modo de panorâmica está ativo, nenhum pincel, seleção, forma ou transação de desfazer pode começar. A tecla Espaço desativa o modo ao ser solta; a perda de foco encerra o deslocamento. O projeto continua exatamente como estava.

## Testes

`tests/test_canvas_view.lua` valida correspondência direta/inversa de coordenadas, âncoras sob zoom e giro, limites de escala, casos inválidos, deslocamento, recentralização e janelas de dimensões menores.

O autoteste LÖVE abre o editor existente, aciona os **botões reais** e eventos `love.mousepressed`/`love.mousemoved`/`love.mousereleased`/`love.wheelmoved`/`love.keypressed`, confere as transformações e verifica que **nenhum pixel ou entrada no histórico de desfazer** foi alterado. CI executa as duas rotas Windows: aplicativo empacotado e fonte pelo LÖVE oficial.

Essas funcionalidades são melhorias do editor desktop independente, não reprodução validada dos controles originais do ibisPaint Android 14.1.2.
