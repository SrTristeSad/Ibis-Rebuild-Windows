# Etapa 18 — Propriedades e edição dos nomes das camadas

Esta etapa continua a reconstrução Windows x64 independente do ibisPaint Android 14.1.2, a partir da Etapa 17. Preserva LuaJIT/LÖVE 11.5, raster C++ nativo, miniaturas RGBA, RBD2 e histórico de pintura. O Inkora não foi modificado.

## Operações no painel de camadas

- O novo botão **Nome**, no cabeçalho da seção **Camadas**, abre uma janela de edição da camada ativa. A tecla **F2** faz o mesmo quando o editor está aberto. A edição é um formulário dedicado, com nome inicial preenchido, confirmação por Enter e cancelamento por Esc.
- O nome aceita texto UTF-8 válido de 1 a 240 bytes. Nomes vazios, compostos somente por espaços, controles e sequências UTF-8 inválidas são rejeitados pela mesma função de validação utilizada para arquivos RBD2. A rejeição não modifica o nome anterior e mantém a janela aberta para correção.
- O comando **Vis/Oc.** na lateral direita de **cada linha** alterna a visibilidade daquela camada sem selecioná-la. A área restante da linha continua servindo para selecionar a camada; o índice, o nome, a miniatura e a indicação da camada ativa permanecem visíveis.
- Os nomes são truncados na lista por caracteres UTF-8 completos, evitando cortar bytes de letras acentuadas. O nome integral permanece nos metadados e pode ser editado novamente.
- Os controles antigos de opacidade, mostrar/ocultar camada ativa, reordenar e adicionar/excluir camadas permanecem.

## Persistência e limites

`Layers:rename(index,name)` valida e altera apenas o campo `name` da camada identificada; não altera pixels, composição, identificador da camada, cache de miniatura ou histórico raster em memória. O modal identifica a camada pelo seu ID persistente para evitar renomear outra camada por troca de seleção.

Renomear é confirmado diretamente no armazenamento RBD2 pelo fluxo normal de salvamento do projeto. A visibilidade continua compondo ou omitindo a camada no resultado e preserva o buffer de seus pixels, sem trocar a camada ativa. Como anteriormente, mudanças na visibilidade invalidam o histórico de pintura em memória; mudanças **apenas no nome** não invalidam esse histórico.

Nenhum formato de arquivo novo foi introduzido. Não há hierarquia de pastas, máscaras, mistura avançada ou equivalência afirmada com o gerenciamento de camadas proprietário do aplicativo Android.

## Verificação

`tests/test_layer_properties.lua` testa nomes UTF-8, rejeição atômica de nomes inválidos, preservação de buffers C++ e histórico raster, visibilidade isolada, opacidade preexistente e persistência/reabertura RBD2. O autoteste LÖVE usa F2, Enter, Esc, botão Nome, botão de visibilidade da linha de outra camada e verifica os bytes originais, miniaturas, seleção e metadados salvos em ambas as rotas Windows de execução.

O CI valida o executável empacotado e a inicialização oficial do LÖVE. Um resultado verde não comprova paridade visual ou funcional integral com o ibisPaint Android.
