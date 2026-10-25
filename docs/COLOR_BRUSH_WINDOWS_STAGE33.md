# Etapa 33 — Janela de cores HSB/RGB e biblioteca de pincéis categorizada

O editor Windows independente passa a oferecer uma janela compacta de cores acessível pelo botão **Cor** na barra inferior e categorias de pincéis que organizam somente os rasterizadores já disponíveis.

## Referência de organização

- [ibisPaint: Select Colors in the Color window](https://ibispaint.com/lecture/index.jsp?no=11) apresenta cor atual/anterior, HSB, RGB, alfa, código hexadecimal e paleta/histórico.
- [ibisPaint: Details of Brush Parameters](https://ibispaint.com/lecture/index.jsp?no=118) explica o painel de ajustes e a distinção dos parâmetros do pincel.

Essas referências são públicas e não demonstram paridade 1:1 com o APK Android 14.1.2. Não foram importados assets ou algoritmos do Android.

## Janela de cores

Na interface compacta, **Cor** abre uma janela flutuante (sem ocupar o canvas inteiro). As abas **HSB**, **RGB** e **Paleta** são funcionais. HSB disponibiliza um quadrado de saturação/brilho, seletor vertical de matiz e barra de alfa; RGB oferece ajuste separado de cada canal R/G/B/A entre 0 e 255. Os arrastes atualizam a cor atual enquanto o mouse/caneta/toque permanece pressionado; nenhum clique de configuração é encaminhado à pintura.

O topo mostra **cor atual** e **anterior** com transparência real e botão hexadecimal que abre o editor #RRGGBB/#RRGGBBAA já existente. A paleta guarda **até 12 cores pessoais** em `preferences.json` usando gravação atômica, mantendo os demais campos de preferência; o histórico de **até 12 cores recentes** fica somente na sessão atual. Os valores de alfa são preservados. O código de desenho nativo continua recebendo a mesma representação `0xRRGGBBAA`.

## Biblioteca de pincéis

A biblioteca raster existente, disponível pelo botão **Biblioteca de pincéis** ou `Ctrl+B`, ganhou três filtros: **Todos**, **Básicos** e **Meus**. Eles separam as quatro predefinições locais e os quatro espaços pessoais, sem alterar a ordem dos cartões, suas posições de clique, os arquivos `brushes.json`, ou criar pincéis Android fictícios. Continuam funcionando salvar, remover e aplicar.

## Testes

- `tests/test_color_brush_windows.lua`: conversão RGBA/HSB e reversão para RGB preservando alfa, extremos e entradas inválidas, áreas de captura, ordenação do histórico, limite da paleta, filtros da biblioteca.
- Autoteste gráfico LÖVE: clique no botão Cor, arraste matiz, saturação/brilho e RGB, salve e recarregue cor local, abra e feche modal hexadecimal, alterne abas e filtros de pincéis; compare bytes RGBA e histórico nativo antes/depois, sem escrever pixels.
- Windows CI: testa LuaJIT, C++, persistência e a interface em executável fundido e pasta LÖVE antes de publicar o pacote.

Não há novos modos de mesclagem, pincéis texturizados, filtros ou outras operações Android. O Inkora e os demais projetos permanecem inalterados.
