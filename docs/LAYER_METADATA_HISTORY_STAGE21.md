# Etapa 21 — Histórico unificado das propriedades das camadas

Continuação direta do Ibis Rebuild Windows x64 após a Etapa 20, sem alterar Inkora, a DLL raster C++ ou o formato RBD2. Esta etapa completa a linha do tempo de desfazer/refazer de forma a incorporar **nome, visibilidade e opacidade** de cada camada, junto com pinceladas e operações estruturais.

## Comportamento no editor

As alterações feitas pelo modal **F2 / Nome**, pelos botões **Vis/Oc.** de cada linha, pelo botão **Ocultar/Mostrar** da camada ativa e pelos ajustes de **opacidade −/+** passam a criar passos de histórico comuns. O usuário pode pintar, renomear, ocultar uma camada, mudar sua opacidade, mover a camada e desfazer esses passos na ordem inversa usando **Ctrl+Z** ou os botões do editor. **Ctrl+Y** / **Ctrl+Shift+Z** refazem as alterações.

Cada passo utiliza **ID persistente da camada**, nome do campo e valores anterior/posterior. Assim, renomear uma camada e depois reordená-la não associa uma alteração posterior à camada errada. Modificar uma propriedade de uma camada que não esteja selecionada também não força a seleção dessa camada ao desfazer/refazer.

O programa não cria entradas para ações sem efeito: renomear para o mesmo nome, pressionar **Mostrar** quando a camada já está visível ou ajustar opacidade para o mesmo valor. Valores inválidos continuam sendo rejeitados pelo validador existente, antes de qualquer alteração no histórico.

## Memória e persistência

As entradas de propriedades ocupam apenas alguns bytes e o nome, sem cópias dos buffers RGBA. O orçamento permanece de **48 MiB e 24 operações** para o histórico total, sujeito à política de descarte das operações mais antigas. Um novo comando após um desfazer elimina o ramo de refazer, inclusive se ele contiver pintura ou alterações estruturais.

Nome, visibilidade e opacidade continuam salvos normalmente no **RBD2**, sem mudança de esquema. O histórico em si, como antes, permanece apenas na sessão: reabrir um documento apresenta o estado salvo, não a sequência de passos antigos. Ao desfazer renomeio, visibilidade ou opacidade, os pixels das camadas não são alterados. Para ocultar/exibir ou mudar a opacidade, somente a composição visual do raster é atualizada.

O sistema é próprio da reconstrução Windows e **não reproduz nem reivindica equivalência com o histórico do ibisPaint Android 14.1.2**.

## Testes

- `tests/test_layer_property_history.lua`: intercalamento de pinturas, adição, renomeio, opacidade, visibilidade e reordenação com **sete desfazeres e sete refazeres**; seleção por ID, integridade dos pixels C++, ausência de operações nulas, rejeição atômica, ramificação do histórico, limite de memória e arquivo RBD2.
- Ajustes de regressão nos testes históricos das etapas 4, 18 e 19, onde o comportamento esperado antes era limpar ou não acrescentar histórico.
- O autoteste de interface LÖVE exercita F2, Enter, botão Ocultar/Mostrar e controle de opacidade, seguido de desfazer/refazer, comparações de bytes nativos e reabertura do documento.
- O CI Windows deve passar tanto no executável empacotado quanto na execução das fontes pelo LÖVE oficial.
