# Etapa 35 — Laboratório de pincéis: prévia ampliada e ajustes temporários

A biblioteca Windows recebeu um painel lateral de configuração com amostra raster real em resolução nativa, **ampliada/ajustada proporcionalmente para visualização**, sem nenhuma operação sobre o desenho aberto.

## Recursos implementados

- **Prévia ampliada** de 160 px de altura, ao lado dos oito cartões originais de pincéis (4 básicos, 4 pessoais), renderizada pela mesma rotina C++ da biblioteca, respeitando tipo rígido/suave, tamanho, opacidade e cor RGBA.
- **Ajustes rápidos** para tamanho (1–256 px), opacidade (10–100% com precisão de 1%) e estabilização (0–5). Clique e arraste o trilho para atualizar a prévia imediatamente.
- **Cópia de trabalho temporária.** Os ajustes não mudam o pincel ativo, não editam um preset e não gravam `brushes.json` até o usuário pressionar **Aplicar ajustes**. Essa ação ativa os novos parâmetros no motor existente e fecha a janela; para persistir a configuração como um pincel pessoal, use posteriormente **Salvar pincel atual**.
- **Esc descarta** os ajustes em preparação e fecha a biblioteca. A seleção de uma categoria ou de um cartão via setas atualiza a prévia do pincel focalizado, sem interferir na seleção existente por Enter ou no clique direto do cartão.
- **Layout adaptável:** o catálogo conserva as coordenadas da grade anterior, enquanto a janela cresce até 1040 px para acomodar a prévia. Janelas mínimas 960×640 continuam suportadas.
- **Cache independente**: o painel usa uma entrada de textura chamada `inspector` e invalida a imagem somente quando tamanho, estilo, opacidade ou cor se altera. As demais amostras não são recalculadas e as texturas são liberadas ao trocar de projeto ou encerrar.

## Garantias técnicas

O módulo `app/brush_lab.lua` implementa cálculos de geometria, hitboxes, limites e cópias de configuração sem depender de LÖVE nem modificar estado persistido. O renderer `app/brush_samples.lua` produz cada imagem em um buffer RGBA temporário C++, não na camada ativa; o formato de documento RBD2, histórico e ferramentas permanecem intactos.

- `tests/test_brush_lab.lua`: valida o posicionamento em três tamanhos de janela, a razão de aspecto, controles e faixas de valores, o isolamento dos presets e a igualdade exata de pixels com uma chamada C++ independente.
- Autoteste gráfico LÖVE: arrasta tamanho, opacidade e estabilização, verifica a invalidação do cache, compara bytes da amostra, testa o clique externo e confirma que **Aplicar** atualiza somente o pincel, enquanto **Esc** descarta as alterações. Compara bytes da obra, histórico, camadas e armazenamento original após as operações.

## Limites de fidelidade

Este é um editor Windows independente, não uma implementação 1:1 certificada da interface ou do motor de pincéis do ibisPaint Android 14.1.2. Não há novos pincéis texturizados, modos de mistura, importação de assets Android ou mudanças no Inkora.
