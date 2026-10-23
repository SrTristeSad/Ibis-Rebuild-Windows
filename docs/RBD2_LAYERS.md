# RBD2 — camadas raster próprias do Windows (etapa 3)

**Escopo:** implementação independente de camadas raster RGBA8 no rebuild Windows, não uma reprodução do arquivo IPV nem do compositor do ibisPaint Android. Não altera Inkora.

## Compatibilidade e migração

- **RBD1** permanece legível, com oito bytes mágicos originais e uma camada raster RGBA8. Abrir não modifica o arquivo em disco.
- **RBD2** usa os oito bytes mágicos próprios `RBD2\r\n\26\n`, seguido de uint32 LE com tamanho do cabeçalho JSON UTF-8 (máximo 65.536 bytes), JSON e N blocos RGBA8 de tamanho `largura*altura*4`, concatenados em ordem da camada inferior para superior.
- Header: `version=2`, `pixel_format="RGBA8"`, `layer_count=N`, `active_layer` (índice 1..N), `id,name,width,height,folder,revision,saved_at` e array `layers` na ordem de composição, cada item `{id,name,visible,opacity}`.
- Não há compactação, histórico de desfazer, grupos, máscaras, blending avançado, transformações por camada, clipping, miniaturas integradas ou importação IPV nesta versão.
- Abrir um RBD1 promove em memória seu plano a camada raster. O arquivo só migra para RBD2 quando é salvo.
- Limits próprios: no máximo oito camadas de 2048×2048. Para cada camada o tamanho exato é validado antes da leitura ou gravação. Não são limites recuperados do Android.
- Metadados inválidos (IDs duplicados, nomes inválidos, opacidade fora de [0,1], visibilidade não booleana, layer_count divergente, revisão obsoleta e payload truncado/com cauda) são rejeitados. Gravação preserva atomicidade anterior.

## Composição

`rb_compose_normal` recebe dois planos RGBA8 disjuntos, dimensões, capacidades e opacidade. A operação é **normal, source-over de alfa reto** e percorre camadas inferiores para superiores. Valida todos os argumentos antes de modificar o destino. Camadas ocultas são ignoradas pela interface Lua. `rb_draw_basic_stroke` continua desenhando somente no buffer da camada ativa; o resultado composto serve para pré-visualização e PNG exportado.

A ABI C v1 foi ampliada com uma função sem alterar as entradas existentes. LuaJIT FFI mantém propriedade dos buffers, C++ não retém ponteiros. O arquivo salva os planos originais editáveis em separado em vez de achatar a imagem.

## Controles na interface

O painel **Camadas** apresenta seleção, criação e exclusão, alternância de visibilidade, opacidade e movimentação de camada para cima/baixo. Os controles de pincel ficam na aba ao lado. Ao salvar, o app escreve RBD2; ao reabrir, reconstrói buffers C++ individuais, compõe as camadas e preserva a edição independente.

## Testes

`tests/test_layers.lua` exige LuaJIT e a DLL C++ reais, exercitando migração RBD1 sem alteração precoce, reabertura RBD2 byte a byte, movimentação, visibilidade, opacidade, revisão obsoleta e corrupção. `tests/test_core.py` cobre composição e validação de buffers, alfa e opacidade. O self-test do programa cria duas camadas, salva/reabre RBD2 e confere a composição e exportação PNG nas duas rotas LÖVE. **Nenhuma dessas verificações demonstra equivalência visual com ibisPaint Android**.

O aplicativo original usa estruturas de camadas e composição nativas identificadas na pesquisa, mas regras exatas de blend, máscara e clipping exigem evidência adicional antes de serem apresentadas como reproduzidas.
