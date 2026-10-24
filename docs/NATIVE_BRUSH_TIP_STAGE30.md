# Etapa 30 — Prévia da ponta gerada pelo raster C++

O editor Windows agora mostra o formato e a opacidade de uma pincelada **antes de desenhar**, sobrepondo uma imagem temporária ao canvas. O núcleo C++, o armazenamento RBD2, o histórico e os pixels do desenho **não são alterados** pela prévia; Inkora permanece fora do escopo.

## Como usar

1. Selecione **Pincel** ou **Borracha** e posicione o mouse sobre o documento.
2. O indicador aparece alinhado ao cursor, com diâmetro em unidades do documento, respeitando o zoom e a rotação da tela.
3. Use o botão **Prévia: ligada/desligada**, no cabeçalho, para ocultá-lo ou reativá-lo. O ajuste é temporário enquanto o editor estiver aberto.

A prévia é escondida durante pintura, navegação por arraste, interação com barras deslizantes, menus, biblioteca de pincéis, modais, ajuda, contatos de toque ou caneta ativa, e quando o ponteiro sai da área de desenho. Em modo foco, respeita os limites ampliados do canvas.

## Fiel ao rasterizador desta reconstrução

`app/brush_cursor.lua` gera uma amostra RGBA em **buffer temporário próprio**, chamando diretamente as APIs existentes do C++: `Native.basicStroke` para pontas rígidas, `Native.featherStroke` para suaves, ou `Native.tiltStroke` se o sistema receber parâmetros de inclinação de uma ferramenta habilitada. O tamanho e a opacidade usam `Pressure.diameter/opacity` para compartilhar a política de pressão do editor. O buffer de amostra e a textura gerada são reutilizados até algum parâmetro relevante mudar (ferramenta, cor, estilo, tamanho, opacidade ou inclinação).

**Borracha:** a amostra é uma **máscara branca de remoção** baseada na geometria do traço C++. O resultado real de apagar depende dos pixels que estão sob o cursor; a amostra é uma representação da área afetada e não uma simulação de como a composição ficará após apagar.

A textura é desenhada apenas pela GPU do LÖVE, com transparência, zoom e rotação. Ela não é copiada para qualquer `Layers`, projeto ou pilha de desfazer. Não são gerados PNGs/assets para esta funcionalidade.

## Cobertura

- `tests/test_brush_cursor.lua`: confere bytes RGBA idênticos aos de uma pincelada nativa no buffer separado, tamanho mínimo/máximo, estilos rígido/suave e inclinação, máscara da borracha, invalidação de cache e ocultação em estados de interação não compatíveis.
- Autoteste de interface LÖVE: cursor em hover real via eventos de mouse, construção e reaproveitamento da textura, regeneração após ajuste, máscara da borracha, botão liga/desliga, bloqueio por modal e comparação byte a byte de pixels, histórico e camadas do documento.
- Windows Actions: valida LuaJIT, C++ compilado, interface gráfica nos dois caminhos de inicialização e publicação do pacote após aprovação.

## Limitações

Esta prévia é fiel ao **raster C++ da reconstrução**, não ao motor de pincéis do ibisPaint Android 14.1.2. O pipeline atual de Windows Ink não disponibiliza eventos comprovados de *hover* de caneta antes do contato; portanto a prévia se destina principalmente ao mouse e desaparece durante o contato ativo de caneta e toque. Não há reprodução 1:1 certificada do aplicativo Android.
