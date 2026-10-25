# Etapa 34 — Biblioteca de pincéis com amostras C++ reais

Esta etapa melhora a biblioteca independente de pincéis raster do editor Windows, baseada na ideia documentada pelo ibisPaint de distinguir pincéis básicos e personalizados. **Não** replica o motor de pincéis nem as imagens da versão Android 14.1.2.

## Referências de organização

- [ibisPaint — Details of Brush Parameters](https://ibispaint.com/lecture/index.jsp?lang=en&no=118): biblioteca de pincéis, parâmetros de tamanho/opacidade e amostra de traço.
- [ibisPaint — Make Custom Brush](https://ibispaint.com/lecture/index.jsp?lang=en&no=104): seleção, parâmetros e categoria personalizada.

## Alterações implementadas

Na janela `Biblioteca de pincéis`, as linhas artificiais desenhadas diretamente pelo LÖVE foram substituídas por **amostras raster RGBA produzidas pelas mesmas rotinas do núcleo C++ usadas para pintar**:

- `Native.basicStroke`, para os pincéis rígidos;
- `Native.featherStroke` com hardness 0,25, para os suaves;
- parâmetros do preset, como diâmetro, opacidade e cor RGBA atual;
- composição sobre o padrão quadriculado para tornar a transparência legível.

As imagens são geradas **uma vez por configuração** e ficam em cache por cartão; mudanças de cor ou parâmetros invalidam somente o cartão afetado. Os buffers temporários C++ não são a camada ativa. As texturas de cache são liberadas ao trocar de projeto ou encerrar, evitando acúmulo de memória.

A amostra é **reduzida para caber no cartão**, portanto seu diâmetro visual não representa pixels 1:1. A dimensão real aparece numericamente no cartão. O software continua implementando **somente** os quatro pincéis predefinidos e os quatro slots pessoais existentes.

## Navegação

A janela mantém os botões `Todos`, `Básicos` e `Meus` e acrescenta:

- Setas esquerda/direita: alternam entre predefinições selecionáveis;
- Setas cima/baixo: avançam ou retornam duas posições na grade de duas colunas;
- `Tab`: alterna entre Todos → Básicos → Meus;
- `Enter` ou `Enter` numérico: aplica o pincel destacado;
- `Esc`: fecha a janela sem mudar o pincel.

O foco é marcado por uma borda azul e nunca aponta para slots vazios da categoria `Meus`. Se essa categoria estiver vazia, `Enter` não executa nada. A escolha do pincel continua usando o armazenamento original `brushes.json`, sem modificar a estrutura dos dados.

## Validação automatizada

`tests/test_brush_samples.lua` compara **byte a byte** cada amostra C++ com uma chamada nativa independente equivalente; inclui estilos rígido/suave, diâmetro mínimo/máximo, alfa parcial, chave de cache e navegação sem slots vazios.

O autoteste de GUI executa a abertura da janela, confere que a textura corresponde aos bytes C++, verifica reutilização do cache e invalidação por alteração de cor, alterna categorias, navega por teclado e confirma que o documento, as camadas, a flag de modificação e o histórico não foram alterados.

A versão Windows continua sem WebView e sem modificações no Inkora, no C++ nativo ou no formato RBD2. A fidelidade visual final ao APK original depende de referência específica do Android 14.1.2 e continua pendente.
