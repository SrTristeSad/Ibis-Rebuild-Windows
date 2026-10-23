# Etapa 7 — Balde de preenchimento RGBA

Implementação independente para Windows x64; sem WebView, sem Inkora e sem código Android.

## Uso
Selecione **Balde** na barra, escolha a cor no painel e regule tolerância 0..255 em passos de 8.
Clique no canvas para preencher a região contígua da camada ativa.
O algoritmo considera quatro vizinhos: esquerda, direita, acima e abaixo (diagonais não conectam).
A tolerância é a diferença absoluta máxima POR canal, incluindo alfa, comparada à cor RGBA do pixel inicial.
O destino recebe RGBA exato escolhido, inclusive transparência; não mistura com o fundo.

## Contrato C++
rb_flood_fill_rgba recebe raster RGBA8, ponto inicial, cor de substituição, tolerância e memória de trabalho fornecida pelo LuaJIT.
Fila: width*height números de 32 bits. Máscara visitada: width*height bytes.
É necessário que plano, fila, máscara e contador sejam mutuamente disjuntos.
Todos os argumentos são validados antes da primeira escrita e o algoritmo não aloca memória internamente nem usa recursão.
Um pixel válido entra na fila uma única vez, evitando overflow e pilhas profundas.
O retorno informa a quantidade de pixels substituídos.

## Persistência e limites
Cada preenchimento que altera pixels cria um único passo de desfazer/refazer em memória.
RBD2 permanece inalterado; salvar persiste os pixels editados de cada camada, não o histórico.
Máximo desktop atual 2048x2048 por plano. Não há preenchimento por imagem composta, fechamento de lacunas, gradientes ou algoritmo Android recuperado.

## Testes
Testes da DLL C++ via ctypes e LuaJIT FFI verificam conectividade, tolerância, alfa, invalidade sem escrita, histórico e RBD2.
O autoteste LÖVE usa botões reais de cor, tolerância e Balde, salva e reabre em ambas as rotas Windows.
O CI Windows não substitui a verificação na máquina do usuário.
