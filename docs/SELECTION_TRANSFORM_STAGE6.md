# Etapa 6 — Transformar a seleção raster

Implementação incremental independente para Windows x64, usando os arquivos e camadas já existentes. Não modifica Inkora nem utiliza algoritmos proprietários da versão Android.

## Controles

Escolha **Seleção**, marque uma área por arraste e use o painel lateral para:

- **↶ 90° / 90° ↷**: girar os pixels da seleção em passos exatos de 90 graus.
- **− 50% / + 200%**: reduzir/ampliar por amostragem de **vizinho mais próximo** (ideal para pixel art).

A área selecionada é atualizada com as novas dimensões. A posição superior esquerda é preservada sempre que couber; quando estiver perto da borda, desloca-se apenas o suficiente para permanecer na tela. Operações maiores que o canvas são rejeitadas, sem descartar pixels.

## Implementação e segurança

\`rb_transform_rect_rgba\` (C++ x64) recebe raster RGBA8, retângulo original, destino, dimensões finais, rotação em quartos de volta e **scratch RGBA8 separado**, de propriedade do LuaJIT FFI. A implementação valida dimensões, capacidade, separação de buffers e modo antes de escrever. Copia o conteúdo original para scratch, limpa apenas a região de origem e cola a transformação usando source-over com alfa reto. A mesma área pode se sobrepor ao destino sem corromper a origem.

O processamento ocorre **somente na camada selecionada**; a composição normal das camadas continua no C++ preexistente. Cada transformação gera um passo de desfazer/refazer em memória (histórico de 24 entradas e 48 MiB), e os pixels finais são salvos normalmente no **RBD2** existente, sem novo formato ou migração destrutiva. O histórico não é persistido.

## Limitações

São somente passos de 90°, não rotação livre ou transformação por perspectiva. Escala usa vizinho próximo, sem suavização. O conteúdo deslocado é mesclado no raster; não há objeto transformável independente, máscara, seleção livre, interpolação bilinear, filtros nem paridade validada com ibisPaint Android 14.1.2.

## Verificação

\`tests/test_core.py\` exige a DLL C++ real para validar rotação horária/anti-horária, meia-volta, ampliação, sobreposição e rejeição atômica de dados inválidos. \`tests/test_selection.lua\` valida o roundtrip real LuaJIT/FFI + RBD2, desfazer/refazer e isolamento entre camadas. O self-test LÖVE aciona botões reais do painel em duas rotas Windows, confere bytes de pixels e reabertura.
