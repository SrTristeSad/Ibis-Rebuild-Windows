# Etapa 23 — Espelhamento horizontal e vertical de camadas

Continuação do Ibis Rebuild Windows x64, a partir da main da Etapa 22. O editor permanece LuaJIT/LÖVE + raster nativo C++ sem WebView e não modifica o Inkora.

## Novos comandos

Na aba Camadas, os botões **Esp. H** e **Esp. V** espelham **somente a camada ativa**, respectivamente na horizontal (esquerda/direita) ou vertical (cima/baixo). Atalhos **Ctrl+Shift+H** e **Ctrl+Shift+V** executam as mesmas ações. A composição das demais camadas não é alterada.

## Raster nativo

A função `rb_flip_rgba` da DLL C++ troca pixels RGBA de quatro bytes diretamente no buffer nativo, sem alocação extra: troca colunas simétricas no eixo horizontal ou linhas simétricas no vertical. São preservados todos os bytes, inclusive alfa de pixels semitransparentes. Dimensões e capacidade de buffer são validadas antes de qualquer alteração; valores de eixo diferentes de 0 ou 1 retornam erro sem escrever.

`Layers:flip(axis)` integra os comandos ao histórico cronológico existente: cada espelhamento é uma operação raster reversível por Ctrl+Z e Ctrl+Y, convivendo com pintura e operações estruturais. A imagem final é gravada no RBD2 pelo fluxo existente, sem criar outro formato.

## Verificação

`tests/test_layer_flip.lua` executa a DLL compilada via LuaJIT/FFI e compara exatamente os bytes de uma imagem assimétrica 4×3 antes/depois de ambos os eixos. Confere preservação da outra camada, desfazer/refazer, rejeição de eixos inválidos e reabertura RBD2.

O autoteste gráfico do LÖVE aciona os botões reais, confere desfazer/refazer e salvamento. A compilação e os testes devem passar nas duas rotas Windows antes de integrar à main.

**Limitações:** este espelhamento é raster e atua sobre a camada inteira, não sobre uma seleção parcial. Não equivale a uma reconstrução verificada da ferramenta original do ibisPaint Android 14.1.2.
