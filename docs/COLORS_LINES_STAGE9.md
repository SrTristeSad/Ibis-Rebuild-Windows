# Etapa 9 — Cores RGBA, conta-gotas e linha reta

Incremento do editor Windows x64 existente (LuaJIT/LÖVE + núcleo C++ independente). Não reproduz as ferramentas Android nem altera o projeto Inkora.

## Conta-gotas

Na barra superior, selecione **Gotas**. No painel, alterne entre **Visível** (o composto final RGBA das camadas, respeitando visibilidade, ordem e opacidade) e **Camada ativa** (pixels RGBA8 originais da camada em edição). Clique no canvas para capturar exatamente a cor do pixel; não é gerada uma pincelada ou um passo de desfazer. Pixels totalmente transparentes são aceitos. O núcleo C++ original já possui `rb_get_pixel`, reutilizado na captura.

## Cor personalizada

Na ferramenta Formas, Pincel, Balde ou Gotas, clique no botão **Cor RGBA** para editar a cor.
São aceitos **#RRGGBB** (alfa = FF) e **#RRGGBBAA** (alfa explícito). O `#` é opcional e espaços nas bordas são tolerados.
Cor inválida deixa o formulário aberto e mantém a cor anterior. O valor aceito é exibido no botão e compartilhado entre as ferramentas. Não há persistência independente da cor escolhida após reiniciar o aplicativo nem seletor HSV nessa etapa.

## Linha reta

Abra **Formas** > **Linha reta**. Ajuste espessura de 1 a 128 pixels, cor e arraste entre as extremidades. A interface mostra a prévia durante o movimento; ao soltar aplica **um traço real do motor C++ `rb_draw_basic_stroke`** na camada ativa. A operação inteira é um passo de desfazer/refazer e seu resultado é salvo no mesmo RBD2. As extremidades são os centros dos pixels clicados. Linhas não são objetos vetoriais editáveis. A prévia LÖVE pode diferir ligeiramente do raster final C++.

## Compatibilidade e validação

O formulário de cor é isolado em `app/colors.lua` e usa representação `0xRRGGBBAA`. O código mantém os arquivos RBD1/RBD2, o mecanismo de camadas e o histórico de sessão preexistentes.

`tests/test_colors_lines.lua` roda com LuaJIT/FFI e DLL C++ real: conversões hexadecimais, canal alfa, rejeição de entradas, amostragem composta/ativa, linha com preenchimento contínuo, desfazer/refazer, isolamento e persistência. O autoteste LÖVE aciona os **botões e entradas reais** do diálogo de cor, da ferramenta Formas/Linha e de ambas as modalidades do conta-gotas no executável empacotado e na rota oficial.

Limites: não há roda de cores HSV, mistura artística de pincéis, composição avançada do ibisPaint, estabilização, curva Bézier ou equivalência comprovada com Android 14.1.2.
