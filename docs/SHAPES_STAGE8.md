# Etapa 8 — Formas geométricas raster

Etapa incremental no projeto Windows x64 com LuaJIT/LÖVE e núcleo C++. Não é uma recuperação dos algoritmos do ibisPaint Android 14.1.2; o Inkora não participa.

## Interação

Na barra superior, escolha **Formas**. No painel direito, selecione **Retângulo** ou **Elipse**, depois **Contorno** ou **Preenchida**. Escolha uma cor e, no modo Contorno, ajuste a espessura de 1 a 128 pixels. Pressione e arraste sobre a tela, então solte para gravar os pixels. Durante o arraste aparece uma prévia gráfica; a pintura só ocorre ao soltar.

As formas são calculadas na camada raster ativa; nenhuma outra camada é modificada. É possível desfazer e refazer com Ctrl+Z / Ctrl+Y. O resultado final é persistido em RBD2 sem mudar o formato dos projetos. O histórico de sessão continua limitado a 24 entradas e 48 MiB, e não é gravado no documento.

## C++

`rb_draw_shape_rgba` recebe o raster RGBA8, os dois pontos extremos inteiros e inclusivos, o formato (0 retângulo / 1 elipse), modo cheio ou contorno, largura do contorno e cor 0xRRGGBBAA.

Retângulos têm borda interna de espessura inteira; elipses usam teste analítico do centro de cada pixel dentro de elipse externa e fora de uma elipse interna (contorno). Regiões de 1 pixel ou cujo contorno excede o raio são preenchidas. Aplicação de cores utiliza source-over em alfa reto, cobrindo cada pixel no máximo uma vez por chamada.

O núcleo aceita arrastes em qualquer sentido e faz recorte seguro quando a geometria cai fora do canvas. Verifica parâmetros e memória antes de escrever. O comprimento dos loops é limitado pelo tamanho do canvas, sem alocação dinâmica nem dependência de CRT.

## Testes e limites

Python/ctypes valida DLL real: retângulos reversos, bordas versus interior, preenchimento, elipses, anti-extrapolação, semitransparência e falhas sem escrita. LuaJIT/FFI testa o histórico, separação de camadas e salvar/reabrir RBD2. O LÖVE testa botões reais, o arraste, a prévia, desfazer/refazer e persistência em duas rotas de inicialização Windows.

As formas ainda não são vetores editáveis, não usam antialias ou estabilização, não seguem as configurações de pincéis Android e não oferecem paridade com ibisPaint. A prévia usa desenho LÖVE e pode diferir em pixels de borda do rasterizador C++.
