# Upload de texturas GPU — motor Lua

## Implementação

O editor mantém um `Image` do LÖVE para representar o canvas. Uma
pincelada modifica os buffers RGBA em LuaJIT, e o gerenciador de camadas
recompõe apenas a região afetada. Depois, `app/gpu_upload.lua` transfere
os bytes para `Image:replacePixels` do runtime LÖVE 11.5.

A implementação usa `ImageData:getFFIPointer` para copiar linhas RGBA8
do buffer do motor diretamente para o `ImageData` com `ffi.copy`.
Isso elimina a necessidade de criar uma string temporária por patch,
sem introduzir bibliotecas C/C++ próprias.

O cache LRU retém no máximo **quatro dimensões de patch e 1 MiB**.
Cada envio verifica dimensões, limites e tamanho RGBA8. Patches maiores
que o orçamento são temporários e são liberados após a chamada GPU.
O cache é liberado em `rebuildImage` e no encerramento do aplicativo.

## Coalescência de Windows Ink

Um único `Ink.poll()` pode entregar muitas amostras agrupadas,
especialmente com `GetPointerPenInfoHistory`. Antes, cada movimento
podia gerar uma composição e um upload. Agora, o editor acumula a
união das regiões afetadas por todas as amostras do pacote e efetua
**uma composição e um envio** ao fim do processamento no `love.update`.

Isso não elimina a necessidade de processar cada amostra para
pressão, inclinação, suavização e cobertura da pincelada; somente a
recomposição e o envio GPU são agrupados. Entradas de mouse e toque
do LÖVE continuam com a política de atualização existente.

## Testes

- `tests/test_gpu_upload.lua`: verifica bytes, recortes, reutilização,
  descarte LRU, orçamento de memória, validação, falha de envio e
  liberação. Executa com um substituto determinístico de `ImageData`.
- Smoke de GUI do Windows: testa upload real com duas regiões de um
  pacote agregadas em uma única atualização; verifica reuso dos
  buffers e leitura de volta do alfa da textura GPU real.
- Suítes Lua e Windows Actions: continuam verificando RBD2, histórico,
  pincéis, camadas e executável final.

Documentação oficial utilizada:
- https://love2d.org/wiki/Data:getFFIPointer
- https://love2d.org/wiki/(Image):replacePixels

## Limites

A API FFI fornece acesso direto à memória de `ImageData`. O código
**não guarda ponteiros depois de liberar o objeto**. A transferência
à GPU continua síncrona na thread da interface e pode ser um gargalo.
Ainda não há medição confiável de FPS ou latência em caneta física.
A política de unir regiões pode enviar pixels intermediários adicionais
em comparação a múltiplas atualizações pequenas; é necessário medir
o impacto em documentos reais e canetas de alta frequência.
