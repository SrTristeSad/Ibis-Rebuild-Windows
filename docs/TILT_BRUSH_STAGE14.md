# Etapa 14 — Ponta elíptica orientada pela inclinação da caneta

Ampliação independente do editor Windows (LuaJIT/LÖVE + núcleo C++ x64), sem tocar Inkora, sem WebView e sem alegar equivalência aos pincéis proprietários do ibisPaint Android.

## O que muda

A ponte Windows Ink da etapa 13 já recebia `tiltX` e `tiltY`, mas o pincel não os utilizava. Agora a ferramenta **Pincel** apresenta o botão **Inclinação Ink: ativa/desligada** acima do ajuste de diâmetro. Quando ativa e há um contato de caneta Windows Ink com inclinação diferente de zero, o editor rasteriza um traço com seção **elíptica alongada na direção da inclinação**, utilizando a nova exportação `rb_draw_tilt_stroke` da DLL C++. O botão não afeta o mouse, toques de dedo ou a ferramenta Borracha.

A API da Microsoft define `tiltX` e `tiltY` de −90 a +90 graus; sem campo suportado, a ponte informa 0. O editor atualiza a inclinação **antes** de processar eventos de movimento e soltura. O modo inclinado respeita cor RGBA, opacidade, diâmetro e pressão já existentes, e oferece ponta rígida ou suave conforme o estilo atual. A ponta de uma caneta invertida continua usando a borracha existente, sem inclinação.

## Modelo C++ independente

O núcleo aplica uma cápsula elíptica ao longo de cada segmento: os pixels são projetados em dois eixos ortogonais orientados pelo vetor de inclinação; a distância mínima ao segmento é calculada nessa métrica anisotrópica. Os raios variam com a força do ângulo: eixo maior até 175% do raio base e eixo menor até 85%. Bordas suaves usam gradiente de cobertura por distância quadrática normalizada, sem usar `sqrt` e sem nova dependência de CRT. Com inclinação 0/0, o código encaminha **exatamente** para os renderizadores redondo rígido ou suave preexistentes, preservando comportamento e pixels.

A mudança trabalha só na camada ativa. Uma pincelada continua uma transação reversível por Ctrl+Z / Ctrl+Y e o RBD2 persiste o resultado raster, sem alterar o formato. Ela não implementa pincel vetorial, reconhecimento de caligrafia, rotação axial da caneta, pressão calibrada por modelo, texturas ou algoritmo Android original.

## Verificação

- Python/ctypes testa o DLL C++ MSVC com elipses horizontal e vertical, traços, alfa e tolerância a entradas inválidas; compara byte a byte pincel rígido/suave com tilt zero.
- LuaJIT/FFI testa uma camada inclinada e uma suave, isolamento da base, desfazer/refazer e reabertura RBD2.
- O autoteste real LÖVE ativa/desativa o botão da interface, usa o despachante Windows Ink com eventos simulados, compara a geometria raster do motor, desfaz/refaz e salva o projeto em ambas as rotas de inicialização Windows.

**Limitação:** os testes automáticos usam dados simulados de inclinação; não comprovam que uma caneta digitalizadora física ou seu driver ofereça `PEN_MASK_TILT_X` / `PEN_MASK_TILT_Y`. A documentação oficial da Microsoft está em https://learn.microsoft.com/en-us/windows/win32/api/winuser/ns-winuser-pointer_pen_info.
