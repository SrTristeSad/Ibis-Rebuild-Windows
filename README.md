# Ibis Rebuild Windows

> **Arquitetura ativa Lua/LÖVE — migração progressiva.**
> A interface ativa vem do repositório [Ibis-Lua](https://github.com/SrTristeSad/Ibis-Lua),
> fixado como submódulo. O motor ativo usa Lua e APIs do LÖVE, sem
> rebuild_core.dll. Veja [a integração e suas limitações](docs/LUA_MIGRATION.md).
> O histórico de etapas C++ abaixo se refere à implementação anterior e
> não deve ser confundido com a funcionalidade do novo motor Lua.


## Implementação ativa em Lua/LÖVE

A interface é o [Ibis-Lua](ui/Ibis-Lua), incorporado por submódulo Git sem
alterações visuais. O motor de edição ativo fica em [bridge/](bridge),
sem DLL C++ do projeto. Possui pintura circular, borracha, balde contíguo,
com tolerância RGBA independente de 0 a 255 por canal,
conta-gotas de cor visível, Alpha Lock para preservar transparência, Clipping
por máscara alfa no shader do LÖVE, os nove modos de blend existentes no painel
(com fórmulas Lua e shader GPU), histórico raster limitado,
miniaturas de pixels reais e persistência PNG por camada com
metadados compatíveis com o formato antigo. O histórico raster de
desfazer/refazer também é salvo e reaberto em PNGs separados com
`history.tsv` para obras de até 1 Mi de pixels. Seleções ativas são
persistidas em `selection.png` por obra, separado dos pixels das camadas,
sem impedir a abertura de projetos antigos. Varinha Mágica, Laço e
Transformar conectam gestos existentes a seleções raster temporárias em Lua,
com movimento de pixels e histórico reversível (limitados a 1 Mi de pixels).
**Pincel e borracha agora registram histórico apenas na primeira alteração
real de pixels de cada gesto**, inclusive quando o arraste começa sobre uma
área onde nada muda. Clique de borracha em transparência, Alpha Lock sem
pixels, opacidade zero, cobertura de seleção nula ou pintura idêntica não
criam estado sujo nem invalidam `Refazer`. A detecção usa margem de
quantização compatível com RGBA 8-bit; um arraste alterado conserva
um único passo de Desfazer. Não há mudança no desenho da interface.
**Pressões consecutivas sem mouseup:** um novo clique válido no
canvas encerra a pincelada ou seleção que ainda estava em andamento.
A tinta já aplicada conserva seu Desfazer próprio; retângulos/laços
não confirmados restauram a seleção original e prévias de
movimento/transformação são descartadas. O segundo clique inicia
um gesto independente, sem linhas ligando pontos distantes.
Cliques rejeitados ou fora da obra não cancelam o gesto ativo.
Nenhuma alteração foi feita no layout original.
**Desfazer/Refazer durante um gesto:** Ctrl+Z/Ctrl+Y agora encerram
a pincelada antes de navegar no histórico. O mouse ainda pressionado
não pode pintar novamente após a restauração; um gesto sem alteração
continua preservando o Refazer anterior. Nos gestos de seleção,
Ctrl+Alt+Z/Y também cancelam retângulos e laços ainda não confirmados,
restaurando a máscara anterior sem criar histórico extra. Prévias de
movimento/transformação são descartadas sem alterar os pixels.
O fluxo de mouse e a interface original permanecem inalterados.
**Opacidade uniforme por pincelada:** dentro de um mesmo gesto de
mouse, o pincel e a borracha aplicam a cor ou a redução de alfa
uma única vez em cada pixel. Pontos interpolados e eventos de
movimento sobrepostos não escurecem o traço dependendo da velocidade
do cursor. Pinceladas **separadas** continuam acumulando opacidade
normalmente. Seleções com feather preservam a cobertura fracionária.
Chamadas diretas antigas ao motor continuam aceitando composição por
dab; a ponte ativa a cobertura uniforme em tinta parcial e máscara
suave, sem controles visuais novos.
**O último trecho do pincel e da borracha é aplicado também no evento
de soltar o mouse**: se não houver um último evento de movimento,
a ponta do traço ainda chega à posição final. Movimentos repetidos
sem deslocamento não reaplicam tinta nem acumulam opacidade.
O fechamento usa a mesma máscara, camada e histórico único do
arraste. O comportamento das seleções não foi alterado.
**Quando o cursor cruza as bordas do canvas**, pincel e borracha
completam o trecho até a borda sem modificar pixels fora da obra.
**Pincel e borracha podem entrar numa seleção após iniciar
fora dela.** O clique inicial sem tinta mantém o gesto aberto; só
os pixels cobertos pela máscara recebem cor ou apagamento quando
o traço a alcança. Pincéis largos também podem pintar a parte
selecionada mesmo com o centro do círculo fora da máscara.
Gestos que nunca tocam a seleção não consomem Desfazer/Refazer.
O Balde continua exigindo a semente dentro da seleção.
**Pincéis largos continuam tocando a borda mesmo com o centro
fora do canvas**: o recorte considera o raio real do círculo,
não apenas sua posição central. A borracha usa a mesma geometria.
Nenhum pixel é escrito fora do raster; o histórico e as máscaras
permanecem respeitados.
O cursor continua sendo acompanhado fora do canvas: ao reentrar,
o traço é recortado a partir do ponto de entrada, sem criar uma
linha diagonal entre dois pontos distantes. Isso também vale
para o mouseup fora do canvas e para canvas rotacionados.
A seleção e o histórico único do gesto continuam respeitados;
não foram introduzidos controles visuais.
Também há copiar/recortar/colar pixels da camada ativa por clipboard interno
(Ctrl+C/X/V), rotação de 90° (Ctrl+Shift+R/L) e escala 50%/200%
(Ctrl+Shift+Down/Up). Com Transformar selecionado, Alt+arrastar dentro
da seleção aplica rotação livre; Shift+arrastar aplica escala X/Y
independente. Alt/Shift mostram uma prévia **GPU bilinear RGBA**
com máscara e Canvas reutilizados por gesto, sem recalcular pixels
em Lua a cada mousemoved. O contorno é transformado graficamente
e a CPU só grava o resultado ao soltar, preservando undo/redo.
Os atalhos antigos mantêm nearest-neighbour. Espelhamento da
seleção **horizontal (Ctrl+Shift+H)** e **vertical (Ctrl+Shift+V)**
reflete pixels e máscara irregular com undo/redo.
**Ctrl+A** seleciona todo o canvas e **Ctrl+Shift+I** inverte a
máscara, sem alterar pixels ou histórico raster.
A **Varinha Mágica** tem tolerância ajustável por obra: **Ctrl+Alt+→**
aumenta 16 níveis, **Ctrl+Alt+←** diminui 16 e **Ctrl+Alt+0**
restaura a seleção exata. A faixa é 0–255 por canal RGBA;
a ferramenta seleciona apenas pixels conectados ao ponto clicado.
O ajuste é salvo em `document.tsv` e não modifica a pintura.
**Ctrl+Alt+G** alterna a Varinha entre **contígua** (padrão) e
**global por cor**: neste último modo, seleciona todas as regiões RGBA
semelhantes da fonte de cor escolhida, mesmo ilhas separadas e diagonais.
A preferência de modo é salva por obra na quarta coluna opcional de
`document.tsv`, sem modificar pixels, seleção nem histórico.
Arquivos anteriores continuam no modo contíguo por padrão.
**Ctrl+Alt+8** alterna a conectividade do modo contíguo entre **4 vizinhos**
(padrão, apenas lados) e **8 vizinhos** (inclui encontros pelos cantos).
Essa preferência é independente da seleção global, da tolerância e da
fonte de amostragem. É salva na sexta coluna opcional de `document.tsv`;
arquivos anteriores preservam a conectividade de quatro vizinhos.
A tolerância própria do **Balde de Tinta** é ajustada com
**Ctrl+Alt+PageUp** (+16), **Ctrl+Alt+PageDown** (−16) e
**Ctrl+Alt+Home** (zero). O valor de 0 a 255 é independente da
Varinha Mágica e salvo na oitava coluna opcional de `document.tsv`.
Arquivos anteriores usam 0, equivalente ao preenchimento RGBA
contíguo exato. Antes de pintar, o balde identifica a região usando
os pixels originais; mesmo com tolerância elevada ou tinta de baixa
opacidade, não reprocessa pixels, e não grava undo para no-op.
**Ctrl+Alt+B** alterna entre o Balde **contíguo** (padrão, região
4-conexa ao clique) e **global por cor**, que preenche todas as
regiões RGBA semelhantes da camada ativa, mesmo ilhas desconectadas
ou pixels unidos somente pela diagonal. Os dois modos respeitam a
tolerância própria do Balde, Alpha Lock, a seleção ativa e a opacidade,
e não afetam a Varinha. Alternar a configuração não pinta nem cria
histórico; o modo é salvo na **nona coluna opcional** de `document.tsv`.
Obras antigas iniciam no modo contíguo. O Ibis-Lua não ganhou
controles novos.
**Ctrl+Alt+M** alterna a comparação do Balde entre **RGBA**
(padrão, considera o alfa) e **somente RGB** (ignora diferenças
de transparência ao identificar pixels semelhantes). Funciona com
preenchimento contíguo ou global e com a tolerância independente do
Balde. A preferência é salva por obra na **décima coluna opcional**
de `document.tsv`; arquivos anteriores usam RGBA. A opção muda
**apenas a comparação**: pintar ainda usa a opacidade normal, podendo
alterar o alfa dos pixels atingidos, salvo quando Alpha Lock está ativo.
Cores RGB armazenadas sob alfa zero também entram na comparação
RGB-only, embora não sejam visíveis na tela.
**Ctrl+Alt+9** alterna a conectividade do Balde **contíguo** entre
**4 vizinhos** (padrão, apenas lados) e **8 vizinhos** (também cantos).
A conectividade não altera o modo global, que já preenche todas as
regiões semelhantes. Funciona com comparação RGB-only, RGBA, tolerância
e seleções, sem afetar a Varinha. O toggle não edita raster, máscara ou
histórico. Salva por obra na **11ª coluna opcional** de `document.tsv`;
arquivos antigos mantêm a conexão de 4 vizinhos. Nenhum controle
visual foi adicionado ao submódulo Ibis-Lua.
**Ctrl+Alt+V** alterna a **fonte de cor do Balde** entre a **camada
ativa** (padrão) e a **composição das camadas visíveis**, incluindo
visibilidade, opacidade, modos de mesclagem, clipping e fundo branco
quando configurado. Apenas a **camada ativa é pintada**: as camadas
usadas na referência não são modificadas. A fonte é independente da
Varinha e funciona com Balde global/contíguo, 4/8 vizinhos,
RGB/RGBA, tolerância, seleção e Alpha Lock. O modo é salvo por obra
na **12ª coluna opcional** de `document.tsv`; projetos antigos
mantêm a fonte camada ativa. Alterar a opção não modifica pixels
nem histórico. Nenhum novo controle visual foi adicionado.
Nenhum controle visual da interface original foi adicionado.
**Ctrl+Alt+R** alterna a comparação entre **RGBA** (padrão, incluindo
a transparência) e **somente RGB** (desconsidera diferenças de alfa).
Funciona com seleção contígua/global, conectividade 4/8 e a fonte de cor
da camada ativa ou da composição. A transparência dos pixels **não é
modificada** por essa opção: apenas a máscara selecionada muda.
O sinalizador é salvo na sétima coluna opcional de `document.tsv`,
e obras antigas começam usando RGBA como antes. Em pixels completamente
transparentes, os canais RGB armazenados também podem ser comparados,
mesmo que não estejam visíveis no canvas.
**Ctrl+Alt+T** alterna independentemente a fonte de cor: **camada ativa**
(padrão) ou **composição visível de todas as camadas**. A amostra composta
respeita visibilidade, opacidade, modos de mesclagem, clipping e o fundo
branco, sem alterar a camada em que o pincel edita. Nos fundos transparentes,
o canal alfa real continua sendo comparado. Essa preferência é salva na
quinta coluna opcional de `document.tsv`; obras anteriores iniciam na
camada ativa. Nenhum controle do Ibis-Lua original foi modificado.
Com **Transformar (retângulo), Laço e Varinha**, os modificadores
**Ctrl+Shift** somam áreas, **Ctrl+Alt** subtraem e
**Ctrl+Shift+Alt** intersectam; essas operações não modificam a
pintura e persistem no `selection.png`.
**Ctrl+Alt+↑** expande a seleção em 1 pixel e **Ctrl+Alt+↓**
contrai em 1 pixel (máscara binária, vizinhança de 8 pixels).
Essas operações preservam a pintura e são salvas como seleção PNG;
o feather opcional mantém os pesos destas operações.
**Ctrl+Alt+F** aplica feather de 2 px na máscara, com bordas de
alfa fracionário em pincel, borracha, balde e transformações;
a seleção suavizada é persistida no canal alfa de `selection.png`.
A API Lua também aceita raios de 1 a 8 px; não há slider de feather
nem implementação de blur gaussiano.
**Ctrl+Alt+Z** e **Ctrl+Alt+Y** desfazem/refazem exclusivamente
mudanças de seleção (retângulo, laço, varinha, soma/subtração,
inversão, expansão, feather ou desmarcar), incluindo o alfa parcial.
Esse histórico tem até oito estados por pilha e orçamento de memória;
**Ctrl+Z/Y continuam para os pixels**. As pilhas de seleção agora
**persistem após salvar e reabrir a obra**, em um manifesto
`selection_history.tsv` e PNGs próprios, separados de `history.tsv`.
O carregamento rejeita conjuntos incompletos ou incoerentes sem impedir
abrir a pintura. Transformações que deslocam pixels e máscara
encerram essa timeline para evitar dessincronização.
O arraste normal do Transformar também exibe uma prévia GPU do deslocamento inteiro,
com máscara/cache reutilizados sem recalcular todos os pixels em Lua
a cada movimento subpixel. O visual e os
controles originais do Ibis-Lua não foram alterados. Outros controles
do Ibis-Lua podem continuar simulados; consulte [limitações](docs/LUA_MIGRATION.md).

Para montar, execute `git submodule update --init` e depois
`python tools/assemble_lua.py`. Use `run.ps1` com LÖVE 11.5 instalado;
`build.ps1` empacota o aplicativo Lua em um arquivo .love.
O workflow Windows atual valida o motor e os cliques na interface existente.

## Histórico da implementação anterior em C++ (não faz parte do build Lua)

Reconstrução **independente e progressiva** dos fluxos do ibisPaint Android 14.1.2 para **Windows x64**, usando LuaJIT/LÖVE 11.5 na interface e C++ no processamento. **Sem WebView, sem Inkora e sem redistribuição de código ou binários Android.** Não existe paridade completa com o aplicativo de referência.

## Estado executável comprovado

O [workflow Windows x64](.github/workflows/windows-x64.yml) compila com MSVC, carrega a DLL C++ real, executa os testes Python/ctypes e LuaJIT/FFI, testa persistência e exercita o editor em dois processos LÖVE: executável fundido e pasta de fontes. O [CI aprovado da etapa 1](https://github.com/SrTristeSad/Ibis-Rebuild-Windows/actions/runs/40013747842) concluiu ambas as rotas com código zero, relatórios e capturas.

Na etapa 2, o motor ganhou um **pincel redondo básico de traço contínuo**, com composição RGBA source-over em C++ e desenho por arraste no editor. Esse algoritmo é **uma ferramenta própria funcional, não uma implementação equivalente ao pincel Android**. Há testes de continuidade, alfa, clipping e argumentos inválidos. Consulte [contrato do pincel básico](docs/BASIC_BRUSH.md).

A etapa 3 introduz camadas raster persistidas no formato independente [RBD2](docs/RBD2_LAYERS.md). A camada ativa recebe os traços C++, e uma pré-visualização em modo normal compõe camadas visíveis na ordem selecionada. Não há máscaras, grupos nem regras de blend recuperadas do Android.

A etapa 4 traz uma [borracha circular C++ e histórico de desfazer/refazer limitado](docs/ERASER_UNDO_STAGE4.md) por traço, com atalhos Ctrl+Z, Ctrl+Y e Ctrl+Shift+Z. O histórico usa apenas memória local durante a edição (não é persistido no RBD2); operações estruturais invalidam os passos anteriores.

Na etapa 6, a [seleção também pode ser rotacionada em 90° e redimensionada em 50%/200%](docs/SELECTION_TRANSFORM_STAGE6.md), preservando histórico reversível e salvamento RBD2. Não há paridade das transformações Android.

A etapa 7 acrescenta um [balde de preenchimento contíguo C++](docs/BUCKET_FILL_STAGE7.md), limitado à camada ativa, com tolerância de cor RGBA e um passo de histórico por preenchimento. Não equivale ao preenchimento original Android.

A etapa 8 introduz [formas geométricas raster em C++](docs/SHAPES_STAGE8.md): retângulo e elipse, com contorno ajustável, preenchimento, arraste, desfazer/refazer e persistência RBD2. Não são objetos vetoriais nem os algoritmos Android.

A etapa 9 adiciona [conta-gotas de pixels visíveis ou da camada ativa, cores hexadecimais RGBA e linhas retas](docs/COLORS_LINES_STAGE9.md). O conta-gotas não escreve pixels, enquanto cada linha usa o pincel C++ já testado e pode ser desfeita e salva em RBD2. Essas ferramentas são independentes, sem alegação de equivalência com o Android.

A etapa 10 introduz [pincel suave de borda gradual e controle de opacidade da pintura](docs/FEATHER_BRUSH_STAGE10.md). O pincel rígido antigo permanece inalterado; ambos usam C++ e camadas RBD2, com desfazer/refazer por arraste. Não há equivalência com os pincéis Android.

A etapa 11 acrescenta [estabilização de traços pelo mouse com níveis de 0 a 5](docs/STROKE_STABILIZER_STAGE11.md) para os pincéis e a borracha, com correção da extremidade ao soltar o mouse. Os pixels continuam rasterizados pelo C++ e salvos no RBD2; não equivale à estabilização do ibisPaint Android.

A etapa 12 recebe [eventos de toque do LÖVE com pressão variável](docs/TOUCH_PRESSURE_STAGE12.md): ajusta espessura e opacidade de pincéis/borracha, ignora o mouse sintetizado pelo toque e mantém histórico RBD2. Não existe suporte comprovado a drivers Windows Ink/Wintab nem identificação segura de canetas físicas.

A etapa 13 integra uma [ponte Windows Ink opcional na DLL C++](docs/WINDOWS_INK_STAGE13.md), conectando mensagens `WM_POINTER` de canetas ao editor sem WebView, com pressão 0–1024, inclinação informativa, borracha por ponta invertida e alternativa de mouse/toque. **O CI não atesta compatibilidade com canetas ou drivers físicos**.

A etapa 14 adiciona [pincel elíptico orientado pela inclinação da caneta](docs/TILT_BRUSH_STAGE14.md), implementado no núcleo C++ e selecionável no painel. O modo de inclinação zero preserva bit a bit os pincéis anteriores; os testes não substituem a validação com caneta física.

A etapa 15 introduz [navegação da tela de desenho com zoom ancorado no cursor, rotação e Espaço+arraste](docs/CANVAS_NAVIGATION_STAGE15.md). A interface possui controles visíveis e atalhos; a visualização muda sem alterar os pixels nem o histórico RBD2.

A etapa 16 traz uma [central de ferramentas e atalhos no editor](docs/TOOL_HUB_STAGE16.md): seleção por 1–8, ajuda F1/H ou botão no painel, escolha por clique e proteção do canvas enquanto a ajuda está aberta. Essa etapa reorganiza o acesso às ferramentas sem modificar o raster nativo nem o RBD2.

A etapa 17 adiciona [miniaturas RGBA reais no painel de camadas, cache de visualização e paginação adaptada à altura da janela](docs/LAYER_THUMBNAILS_STAGE17.md). A prévia amostra somente 28×28 pixels diretamente do buffer raster nativo e não altera camadas, histórico nem RBD2.

A etapa 18 acrescenta [renomear camadas por F2/Nome e visibilidade direta na lista](docs/LAYER_PROPERTIES_STAGE18.md), com validação UTF-8 idêntica ao RBD2 e manutenção de pixels, miniaturas e histórico ao mudar apenas o nome.

A etapa 19 acrescenta [duplicação independente de camadas pelo botão Duplicar ou Ctrl+J](docs/LAYER_DUPLICATE_STAGE19.md), com cópia completa do buffer RGBA nativo, novo ID, miniatura própria, opacidade e visibilidade preservadas e persistência RBD2. A duplicação é estrutural e limpa o histórico raster atual, como adicionar/remover camadas.

A etapa 20 implementa [histórico misto de pintura e alterações estruturais de camadas](docs/MIXED_HISTORY_STAGE20.md): adicionar, duplicar, excluir e reordenar agora podem ser desfeitos/refeitos na mesma linha do tempo das pinceladas, respeitando o orçamento de memória da sessão e sem alterar o RBD2.

A etapa 21 inclui [nome, visibilidade e opacidade de camadas no histórico de desfazer/refazer](docs/LAYER_METADATA_HISTORY_STAGE21.md), sem copiar os rasters nem alterar o formato RBD2. Essa evolução completa o histórico misto da etapa 20, preservando o teto de 24 passos/48 MiB por sessão.

A etapa 22 traz [Mesclar abaixo (Ctrl+E)](docs/MERGE_DOWN_STAGE22.md): duas camadas normais são compostas pelo C++ nativo, preservando opacidade e visibilidade no resultado, e a operação pode ser desfeita/refeita pelo histórico unificado com restauração dos dois buffers originais. Não modifica o RBD2 nem requer novas DLLs.

A etapa 23 acrescenta [espelhamento horizontal e vertical da camada ativa](docs/LAYER_FLIP_STAGE23.md), usando raster C++ nativo sem alterar outras camadas; ambos os eixos suportam desfazer/refazer cronológico e RBD2.

A etapa 24 adiciona [Limpar camada (Shift+Delete)](docs/LAYER_CLEAR_STAGE24.md): apaga todos os bytes RGBA da camada ativa pelo motor C++ existente, sem excluir a camada, sem alterar outras camadas e sem ocupar histórico quando a camada já está transparente. Desfazer/refazer funciona com o histórico unificado, e o salvamento permanece em RBD2.

A etapa 25 melhora o [acabamento visual do editor](docs/EDITOR_VISUAL_STAGE25.md): botões das oito ferramentas com ícones vetoriais próprios, paleta de alto contraste, miniaturas sobre fundo de transparência e realce da camada ativa, mantendo os mesmos alvos clicáveis, atalhos e o motor de edição. Não representa equivalência visual 1:1 comprovada com o Android.

A etapa 26 adiciona [modo foco (Tab), canvas ampliado e ajustes rápidos do pincel](docs/FOCUS_WORKSPACE_STAGE26.md). O painel direito pode ser recolhido/restaurado sem alterar zoom, rotação, pixels, camadas, RBD2 ou histórico; os limites de desenho acompanham o espaço visível.

A etapa 27 acrescenta [menus contextuais de camadas e ferramentas](docs/CONTEXT_MENUS_STAGE27.md) com botão direito sobre linhas de camadas/ícones de ferramenta, ações existentes, opções indisponíveis desabilitadas e navegação por teclado. O botão direito no canvas continua sendo navegação sem pintura.

A etapa 28 introduz a [biblioteca de pincéis raster (Ctrl+B)](docs/BRUSH_LIBRARY_STAGE28.md): quatro predefinições de traço rígido/suave usando o motor C++ atual, miniaturas esquemáticas e quatro espaços pessoais persistidos no `brushes.json` existente. A configuração não altera a obra RBD2 nem seu histórico.

A etapa 29 incorpora [barras deslizantes de precisão](docs/PRECISION_SLIDERS_STAGE29.md) para diâmetro (1–256 px), opacidade do traço (10–100% em passos de 1%), estabilização (0–5) e tolerância do balde (0–255), sem remover os controles anteriores e sem alterar pixels ao arrastar os ajustes.

A etapa 30 apresenta uma [prévia não destrutiva da ponta do pincel/borracha](docs/NATIVE_BRUSH_TIP_STAGE30.md), renderizada em um buffer RGBA temporário pelo mesmo C++ utilizado na pintura, com textura em cache, zoom/rotação e botão de liga/desliga. Não insere pixels no canvas nem modifica histórico/RBD2; hover real de caneta não é alegado.

A etapa 31 introduz [layout compacto inspirado na barra principal oficial do ibisPaint](docs/COMPACT_ANDROID_STAGE31.md). A barra inferior dá acesso ao seletor de ferramentas, propriedades, cor, janela flutuante de camadas e retorno à galeria, enquanto um botão no cabeçalho restaura o layout desktop antigo. A tela mantém as operações nativas e não reivindica equivalência visual 1:1.

A etapa 32 melhora o [acabamento da interface compacta com referências oficiais](docs/COMPACT_VISUAL_STAGE32.md): barra inferior com ícones vetoriais, amostra RGBA da cor selecionada, tema charcoal/cinza, indicação de opacidade nas camadas e barras rápidas de espessura (1–256 px) e opacidade (10–100%, passo de 1%). O canvas bloqueia interações de pintura na região dos controles; não se declara identidade visual 1:1 com a versão Android 14.1.2.

A etapa 33 acrescenta [janela compacta de cores HSB/RGB/Paleta](docs/COLOR_BRUSH_WINDOWS_STAGE33.md), com cor atual/anterior, edição alfa/hexadecimal, até 12 cores pessoais persistidas, histórico de sessão e filtros Todos/Básicos/Meus na biblioteca raster existente. As ferramentas continuam independentes do raster Android e usam o formato RGBA e o motor C++ já testados.

A etapa 34 melhora a [biblioteca de pincéis com amostras de traços C++ reais](docs/NATIVE_BRUSH_CATALOGUE_STAGE34.md), cache de texturas, reprodução de opacidade/cor RGBA, navegação por setas, alternância de categorias pelo Tab e confirmação por Enter. As amostras são redimensionadas apenas na visualização; não escrevem pixels no documento.

A etapa 35 apresenta o [laboratório de pincéis com prévia ampliada](docs/BRUSH_LAB_STAGE35.md): painel lateral de ajustes temporários, renderizador RGBA nativo, tamanho/diâmetro de 1–256px, opacidade de 10–100% em passos de 1%, estabilização 0–5, prévia imediata e botão explícito para aplicar. A visualização não altera os dados do pincel nem a obra sem confirmação.

A etapa 36 disponibiliza [capturas reais do aplicativo Windows](docs/REAL_WINDOWS_SCREENSHOTS_STAGE36.md) feitas pelo LÖVE e pelo motor C++ durante o CI. Baixe o artefato `IbisRebuild-Real-Windows-Screenshots` da execução Windows para ver a galeria, editor compacto, biblioteca de pincéis, cores, camadas e editor desktop.

A etapa 37 corrige [miniaturas reais da galeria e problemas de legibilidade](docs/GALLERY_POLISH_STAGE37.md): imagens vindas do composto RGBA C++, cache limitado, setas vetoriais de desfazer/refazer e textos UTF-8 com largura máxima. As capturas Windows do CI mostram o resultado da própria interface.

A etapa 38 refina [hierarquia visual, galeria e botões do editor Windows](docs/VISUAL_HIERARCHY_STAGE38.md), ampliando as miniaturas RGBA, medindo corretamente os títulos, organizando a barra compacta e agrupando a faixa de ferramentas desktop. O CI continua publicando capturas autênticas da interface.

A etapa 39 oferece o [painel lateral desktop com rolagem independente](docs/ADAPTIVE_SIDEBAR_STAGE39.md) nas janelas de altura inferior a 800 px. Os botões e sliders ficam disponíveis até em 960 × 640, com clique e recorte corretos, roda do mouse e teclas PageUp/PageDown/Home/End. A bateria Windows gera também a sétima captura real, `07-editor-960x640.png`.

A etapa 40 adiciona [prévia C++ em tempo real aos ajustes compactos](docs/COMPACT_BRUSH_PREVIEW_STAGE40.md), atualizada por tamanho, opacidade, estilo e cor, sem gravar na obra. A janela compacta de camadas também recorta nomes longos corretamente. O CI publica a oitava captura real `08-ajustes-pincel.png`.

A etapa 41 adiciona [opacidade precisa das camadas no popover compacto](docs/COMPACT_LAYER_OPACITY_STAGE41.md): controle 0–100% em passos de 1%, rascunho sem edições na obra durante o arraste e uma única ação desfeita/refeita por Ctrl+Z/Ctrl+Y ao soltar. O CI publica a nona captura real, `09-opacidade-camadas.png`.

A máquina virtual de CI não oferece OpenGL suficiente: o teste usa Mesa llvmpipe **somente no runner**. Um pacote portátil de teste é criado após aprovação das suítes e exclui as DLLs Mesa. A execução no computador do usuário ainda deve ser verificada separadamente.

| Recurso | Estado |
|---|---|
| LuaJIT/LÖVE, inicialização e encerramento | Aprovados em ambiente Windows CI |
| Núcleo C++ x64, FFI, buffers RGBA e amostras | Compilação e testes reais aprovados |
| Galeria, pastas, tela RGBA editável, RBD1 legado e RBD2 | Implementação própria com testes de persistência e migração |
| Zoom, rotação, pan, exportação PNG | Fluxos iniciais, testados em modo integrado |
| Pincel redondo básico do desktop | Implementado e testado, **não equivalente ao Android** |
| Camadas raster independentes e modo normal RGBA | RBD2 com visibilidade, opacidade e ordenação; **não equivale às camadas Android** |
| Motor original de pincéis, texturas e estabilização | Pendente |
| Grupos, máscaras, clipping e composição avançada Android | Pendente |
| Borracha circular independente e desfazer/refazer por pincelada | Implementados e testados; **não equivalentes ao Android** |
| Seleção retangular de pixels com movimento e desfazer/refazer | Implementada na etapa 5; não equivale ao Android |
| Transformação da seleção: 90° e escala por vizinho próximo | Implementação independente da etapa 6, reversível em RBD2 |
| Balde: preenchimento contíguo RGBA por tolerância | Implementação C++ da etapa 7 com desfazer/refazer e salvamento RBD2 |
| Formas: retângulo e elipse, cheias ou com contorno | Implementação raster independente da etapa 8, com arraste e histórico |
| Conta-gotas, cores RGBA personalizadas e linha reta | Etapa 9: leitura do raster nativo, cor hexadecimal estrita, traço C++ reversível |
| Pincel suave e opacidade por traço | Etapa 10: borda gradual C++, estilo rígido/suave e opacidade 10–100% |
| Estabilização de traço pelo mouse | Etapa 11: níveis 0–5, filtro de movimento e preservação exata do ponto final |
| Eventos de toque/pressão do LÖVE | Etapa 12: largura/alfa variáveis, contato único, sem duplicação do mouse simulado; drivers físicos não verificados |
| Ponte Windows Ink nativa opcional | Etapa 13: WM_POINTER e pressão de caneta com DLL C++, sem garantia de compatibilidade com hardware não testado |
| Ponta elíptica orientada por inclinação | Etapa 14: cilindro elíptico raster C++, sem tilt preserva pincel anterior; hardware físico não verificado |
| Navegação e rotação do canvas | Etapa 15: zoom e rotação sob cursor, Espaço/meio/direito para deslocar, atalhos e dock; sem edições no raster |
| Central de ferramentas e atalhos | Etapa 16: teclas 1–8, ajuda por F1/H, paleta clicável e bloqueio de edição com ajuda aberta |
| Miniaturas e navegação de camadas | Etapa 17: prévias de pixels reais, cache por camada, setas de paginação e layout para janelas menores |
| Propriedades individuais de camadas | Etapa 18: renomeio com validação RBD2 e botão Vis/Oc. por linha sem alterar a camada selecionada |
| Duplicação de camada independente | Etapa 19: novo buffer RGBA, cópia de metadados, botão/Ctrl+J e RBD2; respeita 8 camadas |
| Histórico estrutural e pintura | Etapa 20: Ctrl+Z/Y intercalando inserir, copiar, apagar e mover camadas com pintura, em memória limitada |
| Histórico das propriedades das camadas | Etapa 21: renomear, ocultar e alterar opacidade também admitem Ctrl+Z/Y e respeitam a mesma linha do tempo |
| Seleções avançadas, preenchimento e transformações Android | Pendente |
| Formas avançadas, filtros, texto, importação IPV e paridade Android | Pendente |

## Compilar no Windows

Requisitos: Windows x64, Python 3.12, Visual Studio 2022 Build Tools/Developer PowerShell para MSVC x64 e runtime **LÖVE 11.5 x64** previamente instalado.

```powershell
python tools/windows_preflight.py --runtime "C:\Program Files\LOVE" --compiler ((Get-Command cl.exe).Source)
python tools/build.py all --compiler ((Get-Command cl.exe).Source) --runtime "C:\Program Files\LOVE"
python tools/test.py --suite all --runtime "C:\Program Files\LOVE"
```

Ao concluir, execute **dist/Android1412Rebuild.exe**. O aplicativo é offline e armazena dados próprios em **dist/user-data**. Pode também rodar em modo desenvolvimento com o LÖVE oficial e a DLL compilada. Faltando DLL, os testes completos falham; a interface não substitui silenciosamente o núcleo por Lua.

Se o Clang ou LÖVE falharem antes de iniciar (por exemplo, ACCESS_DENIED no GetLongPathNameW ou erro no filesystem), consulte o [diagnóstico Win32](docs/WINDOWS_BOOTSTRAP.md). O resultado de CI não comprova automaticamente permissões corretas na estação local.

## Organização do projeto

- [app/](app): interface LÖVE, controles, ponte LuaJIT FFI, galeria e armazenamento.
- [native/](native): núcleo C++ e contrato ABI.
- [tests/](tests): testes do ABI C++ e persistência Lua.
- [tools/](tools): build offline, testes em processos separados e diagnósticos.
- [docs/](docs): documentação, limites de equivalência, pesquisa derivada e segurança.

## Escopo e segurança

O formato RBD1 é **próprio**, versionado e editável; **não é o formato IPV**. Não há comparação dinâmica completa com o aplicativo Android. Presença de símbolos nativos ou de uma operação com nome semelhante não comprova equivalência de comportamento. A implementação só declara os contratos efetivamente testados e documentados.

O histórico principal foi reiniciado a partir de uma árvore revisada de fontes independentes. Isso não garante eliminação de objetos Git/LFS antigos no servidor. Consulte [segurança da publicação](docs/SECURITY.md) antes de abrir novos PRs. Não incluir APKs, dados pessoais, extrações de engenharia reversa, recursos proprietários ou arquivos do Inkora. Atribuições e licenças de dependências continuam próprias de seus projetos.
