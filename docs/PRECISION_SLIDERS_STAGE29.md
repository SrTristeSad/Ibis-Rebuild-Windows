# Etapa 29 — Barras de precisão para parâmetros de desenho

Continuação do Ibis Rebuild Windows independente. Esta etapa **não modifica o raster C++, o RBD2, o Inkora nem os modos de pincel já existentes**.

## Controles

No editor, selecione Pincel ou Borracha. Com a aba **Pincel** aberta, as linhas de diâmetro, opacidade e estabilização agora incluem **barras que aceitam clique e arraste**, mantendo os botões `−` e `+` nos mesmos lugares e com os mesmos comportamentos anteriores.

- **Diâmetro:** 1 a 256 px, ajuste por pixel (passo 1).
- **Opacidade do traço:** 10% a 100%, ajuste por 1 ponto percentual (em vez dos 10% oferecidos pelos botões antigos).
- **Estabilização:** 0 a 5, níveis inteiros do suavizador atual.
- **Balde:** com a aba Pincel selecionada, o controle equivalente permite definir tolerância de 0 a 255, passo 1.

O cursor captura o arraste até soltar o botão, mesmo que saia da barra ou chegue ao canvas. Valores fora dos extremos são limitados automaticamente. O movimento do ponteiro enquanto o slider estiver ativo **não pinta, não cria seleção, não faz pan e não gera transações de histórico**. Nos menus, biblioteca e modo foco os sliders ocultos não recebem cliques. Os oito atalhos de ferramenta, botões antigos, modo foco e navegação continuam funcionando.

## Implementação

`app/brush_sliders.lua` concentra faixas, quantização, desenho lógico da geometria e áreas ativas; `app/main.lua` representa as barras no painel, captura eventos de mouse/toque/caneta já encaminhados pelo LÖVE e aplica somente propriedades de configuração. A unidade de opacidade gravada em memória é um valor de 0.1 a 1.0; o raster nativo recebe os mesmos argumentos de sempre na próxima pincelada.

## Validação

- `tests/test_brush_sliders.lua`: limites inclusivos, precisão percentual, monotonicidade, correspondência gráfica e isolamento de ferramentas/painel.
- Autoteste GUI: eventos de clique/arraste/soltura reais, saída dos limites da barra, ajustes de diâmetro/opacidade/estabilização/tolerância, compatibilidade dos botões antigos e igualdade dos bytes RGBA, histórico, camadas e estado de edição.
- Windows Actions: executa testes LuaJIT, ABI e raster C++ e dois caminhos de inicialização LÖVE, publicando o pacote somente após aprovação.

## Limitações

A interface continua uma adaptação funcional desktop, sem paridade de aparência 1:1 certificada para o ibisPaint Android. Os cursores não adicionam novas categorias de pincel nem curvas de pressão.
