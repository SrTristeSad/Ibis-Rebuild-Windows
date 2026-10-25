# Etapa 40 — Prévia viva do pincel compacto e leitura das camadas

O projeto Windows Lua/LÖVE + C++ continua independente. Esta etapa trabalha com os controles existentes, em vez de redesenhar ou alterar o motor do pincel.

## Ajustes compactos

A janela **Ajustes** do modo compacto passa a incluir uma miniatura de **103 × 65 px**, posicionada ao lado dos controles de diâmetro, opacidade, estabilização e estilo. A amostra é gerada pelo mesmo código C++ usado pelo motor de desenho, em um buffer RGBA separado, com quadro de transparência ao fundo.

A prévia é atualizada ao modificar **diâmetro**, **opacidade**, **estilo rígido/suave** e a cor atual. A estabilização é exibida como parâmetro, mas não altera a amostra estática: ela age sobre o movimento durante a pincelada. As imagens são guardadas em cache por configuração e liberadas pelo mecanismo que já encerra as texturas da biblioteca de pincéis. A prévia não modifica a tela, as camadas, o histórico nem o estado de salvamento do projeto.

O botão **Biblioteca de pincéis** continua abrindo o catálogo de pincéis. As posições e hitboxes dos botões da janela foram preservadas.

## Camadas

O nome de cada camada no popup compacto agora usa a largura medida da fonte, com recorte UTF-8 seguro. Isso evita que nomes longos invadam o campo da opacidade. Os controles de seleção, visibilidade, duplicação, exclusão, mesclagem, rolagem e opacidade permanecem com a mesma funcionalidade.

## Validação

- `app/compact_inspector.lua`: geometria independente, snapshot de parâmetros e encaixe proporcional da textura nativa.
- `tests/test_compact_inspector.lua`: limites em resoluções de 960 × 640 a 1920 × 1080, canais RGBA e igualdade pixel a pixel de pincéis rígidos e suaves com chamadas C++ independentes.
- Autoteste LÖVE: abre o popup pelo botão real, modifica diâmetro/opacidade/estilo e confere invalidação de cache e igualdade dos pixels, abre a biblioteca e descarta sem escrita na obra.
- O GitHub Actions Windows segue gerando o executável e passa a incluir a oitava captura real **`08-ajustes-pincel.png`**, em 1220 × 800, além das sete anteriores.

Essa prévia é da implementação independente do Windows e **não** demonstra fidelidade 1:1 com o ibisPaint Android 14.1.2. Não há alteração no motor C++, no formato RBD2 ou no Inkora.
