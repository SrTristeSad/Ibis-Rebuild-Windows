# Etapa 10 — Pincel suave e opacidade de pintura

Etapa incremental do editor Windows x64 já existente. Não modifica Inkora nem utiliza código, recursos ou algoritmos extraídos do Android.

## Controles

Selecione **Pincel** e, no painel direito, escolha **Rígido** ou **Suave**. Rígido usa a implementação C++ antiga `rb_draw_basic_stroke`, que permanece sem alterações. Suave usa a nova função independente `rb_draw_feather_stroke` com dureza interna de 25%. Ambas respeitam o diâmetro ajustável (1..256) e a nova opacidade de pintura, regulável em passos de 10% entre 10% e 100%.

A **Borracha** existente continua rígida, mas também respeita o controle de opacidade. A opacidade de pintura é independente da opacidade da camada e do canal alfa da cor hexadecimal selecionada.

## Rasterização

O pincel suave pinta cápsulas redondas ao longo dos segmentos de movimento do mouse. Calcula distância de cada centro de pixel ao segmento, gera cobertura gradual entre o núcleo (25% do raio) e a borda externa, e mistura pela composição de alfa reto source-over no C++.

A versão usa uma rampa linear **na distância ao quadrado** para não depender de `sqrt` ou das rotinas CRT ausentes da DLL. A dureza 100% delega à API do pincel rígido antigo e deve produzir pixels idênticos. Operações inválidas falham antes de escrever. O processamento só modifica a camada ativa.

Um arraste contínuo é uma edição da sessão com um único Ctrl+Z/Ctrl+Y. Os pixels finais e o alfa são salvos normalmente no formato existente RBD2 e podem ser reabertos. As configurações do pincel não são persistidas como metadados da obra, e o histórico permanece limitado a 24 operações / 48 MiB em memória.

## Limitações

A implementação não reproduz o motor de pincéis do ibisPaint Android 14.1.2. Não há pressão real de caneta, texturas, estabilização, máscara de cobertura por pincelada nem interpolação avançada. Segmentos consecutivos podem acumular alfa em áreas repetidamente cobertas, como em outros traços básicos deste projeto. O pincel suave não equivale a um airbrush original.

## Testes

`tests/test_core.py`: executa a nova função na DLL compilada por ctypes, verificando gradiente de alfa, limite do raio, opacidade parcial, parâmetros inválidos sem escrita e equivalência byte a byte ao pincel rígido quando dureza=100%.

`tests/test_soft_brush.lua`: executa LuaJIT com FFI e motor C++ nativo, verificando camadas independentes, pixels na borda, transações de desfazer/refazer e persistência RBD2.

O autoteste gráfico aciona botões reais de estilo, diâmetro, paleta e opacidade e desenha por arraste com mouse no LÖVE. O CI verifica o executável empacotado e o modo oficial. Ainda é necessária validação manual no PC do usuário.
