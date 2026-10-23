# Etapa 5 — seleção retangular e movimentação de pixels

A ferramenta de **Seleção** cria uma região por arraste no canvas e a desenha por cima da composição das camadas, acompanhando zoom, pan e rotação. Depois, arrastar **dentro** do retângulo move seus pixels na **camada ativa**, sem modificar os outros planos. O destino é limitado ao tamanho do canvas, evitando descartar pixels fora da área visível.

O núcleo C++ independente oferece \`rb_move_rect_rgba\` com buffer RGBA8 do canvas e um scratch alocado pelo chamador (LuaJIT FFI). O retângulo selecionado é copiado para scratch antes de limpar a origem, permitindo deslocamentos sobrepostos sem ler pixels que já foram substituídos. No destino, utiliza source-over de alfa reto, preservando pixels que já existiam fora da região recortada. Operações inválidas são rejeitadas antes de alterar os dois buffers.

Mover um retângulo gera **um único passo de desfazer/refazer** na sessão em memória. O formato RBD2 continua inalterado; salvar e reabrir preserva o resultado nos planos de cada camada. O histórico da etapa 4 segue limitado a 48 MiB e 24 operações.

No editor, escolha **Seleção**, arraste para criar o retângulo e arraste de novo dentro da área delimitada para mover. **Esc** ou **Ctrl+D** desmarca. **Ctrl+Z** desfaz o movimento e **Ctrl+Y** refaz.

As funções **não** reproduzem a seleção, o recorte, transformações de escala/rotação, máscaras ou o algoritmo de blend do ibisPaint Android 14.1.2. Este é um estágio funcional independente de construção do editor Windows, não paridade com o original.

Validação: testes Python/ctypes sobre a DLL MSVC, LuaJIT/FFI com camadas RBD2 e histórico, além de eventos de mouse no aplicativo LÖVE oficial e empacotado. A execução no PC do usuário continua sendo uma verificação separada dos testes de CI.
