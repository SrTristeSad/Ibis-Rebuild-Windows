# Pincel redondo básico — etapa 2 (implementação independente)

**Não é um algoritmo recuperado do ibisPaint Android 14.1.2.** Esta etapa torna o editor Windows capaz de desenhar traços contínuos no buffer RGBA próprio enquanto a rasterização, presets, texturas, curvas de pressão, estabilizador e gestos específicos do alvo continuam desconhecidos.

## Contrato do núcleo

A ABI C existente ganha `rb_draw_basic_stroke(dst,capacity,width,height,x0,y0,x1,y1,diameter,rgba,opacity)`. Um segmento do cursor define uma cápsula com pontas arredondadas e diâmetro uniforme, amostrando pixel centers (i+0.5, j+0.5). A função usa composição **source-over em RGBA8 de alfa reto**, escreve diretamente no buffer pertencente a LuaJIT e não aloca memória ou usa CRT.

Parâmetros de segurança próprios: dimensões 1..8192, diâmetro 1..256, opacidade 0..1 e coordenadas finitas em -16384..16384. Entrada inválida retorna -1 sem escrever. Cor `0xRRGGBBAA`; 0 de alfa não altera destino. Pixels fora do documento são recortados. Não há antialias, suavização, alternância entre camadas ou amostragem real de pressão. Não confundir esse diâmetro próprio com o método `setThicknessToPressure` observado no binário Android.

## Interface e persistência

Na tela de edição há botão **Pincel básico**, com desenho por pressionar/arrastar o botão esquerdo, além de controles `−`/`+` de diâmetro. Cada evento de arraste envia um segmento C++ de um ponto ao seguinte; zoom, rotação e pan continuam convertidos pela transformação de canvas Lua. A liberação do botão ou perda de foco encerra o traço. O documento permanece RBD1 (raster editável único), com salvamento e reabertura preexistentes. Uma camada RGBA única ainda não é um sistema de camadas.

## Aceitação

`tests/test_core.py` cobre continuidade geométrica, composição alfa, clipping, validação de argumentos e ausência de escrita em erro. `nativeSelfTest` na aplicação verifica o pixel central de um traço e rejeita pintura fora dele. O pipeline Windows compila e executa C++ por ctypes e pelo LÖVE oficial nas duas rotas, mantendo o requisito de screenshot/exit zero. Não se considera essa etapa equivalente ao Android sem oráculos dinâmicos comparáveis.

Relação com [matriz de evidências](RESEARCH.md): pressão, pacotes JNI e setter de thickness têm contratos de origem observacional; o rasterizador desta etapa é uma escolha de implementação **independente e rotulada**, não uma reprodução desses algoritmos desconhecidos.
