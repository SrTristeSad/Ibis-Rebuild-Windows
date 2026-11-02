# Primeira etapa visual — ibisPaint 14.1.2 (Windows Lua)

## Objetivo e evidências

Nesta fase **a interface é prioridade**. O motor LuaJIT/LÖVE 11.5
já existente continua responsável por pintura, camadas, histórico RBD2,
salvamento e texturas. A reconstrução visual deve progredir antes de
criar novos motores para ferramentas ainda ausentes.

Referência de engenharia reversa disponível em
[RESEARCH.md](RESEARCH.md) e
[research/evidence-index.json](research/evidence-index.json):
o alvo investigado é `jp.ne.ibis.ibispaintx.app`, **14.1.2**,
versionCode `1401020064`. Os contratos da biblioteca original
não equivalem a um inventário visual completo ou uma captura
comprovada dessa versão. Nenhum asset original de APK foi incorporado.

A **organização** da barra e das categorias foi confrontada com os
[tutoriais oficiais de ferramentas](https://ibispaint.com/lecture/index.jsp?no=4)
e [galeria](https://ibispaint.com/lecture/index.jsp?lang=pt&no=03).
As telas atuais são uma implementação **independente**, ainda sem
paridade visual pixel a pixel com o APK Android.

## Implementado na primeira passagem

- Galeria: cores claras, cabeçalho `A Minha Galeria`, divisória
  e cartões com borda/miniaturas RGBA reais, preservando criação de
  obra, pastas, navegação e persistência existentes.
- Editor compacto: superfície cinza concentrada no desenho, faixa
  inferior neutra e duas barras de tamanho/opacidade ainda funcionais.
  A rota desktop anterior continua acessível.
- Barra inferior: **nove ações** nesta ordem: pincel/borracha,
  ferramentas, propriedades, cor, tela cheia, desfazer, refazer,
  camadas e voltar. Todas possuem ícones Lua vetoriais, hitboxes
  conferidas e ações ligadas às rotinas atuais.
- Seletor de ferramentas: **15 categorias** em uma grade 3×5,
  todas com ícone vetorial próprio ou de função existente,
  seleção e estado visível de integração.
- Painéis existentes de pincel, cor e camadas preservados;
  seletores e gestos atuais continuam conectados ao motor.

## Ferramentas exibidas e integração

| Categoria visual | Estado | Motor usado |
|---|---|---|
| Transformar | Parcial | `select` (retângulo/transformações atuais) |
| Vara mágica | Pendente | Nenhum |
| Laço | Pendente | Nenhum |
| Filtro | Pendente | Nenhum |
| Pincel | Funcional no escopo atual | `brush` |
| Borracha | Funcional no escopo atual | `erase` |
| Borrar | Pendente | Nenhum |
| Desfoque | Pendente | Nenhum |
| Caneta especial | Pendente | Nenhum |
| Balde | Funcional no escopo atual | `fill` |
| Vetor | Pendente | Nenhum |
| Texto | Pendente | Nenhum |
| Dividir quadros | Pendente | Nenhum |
| Conta-gotas | Funcional no escopo atual | `picker` |
| Tela | Parcial | `inspect` (navegação) |

Uma ferramenta pendente **não invoca outra ferramenta como substituta**
e não modifica o raster. Sua seleção mantém o painel aberto e
mostra `motor Lua pendente`. A implementação da capacidade fica
para a fase de motores, após estabilização visual.

## Validação e imagens reais

- `tests/test_compact_layout.lua` e
  `tests/test_compact_visual.lua`: nove ações, geometria responsiva
  960×640/1220×800/1920×1080 e proteção do canvas.
- `tests/test_ibis_visual_tools.lua`: quinze categorias, ordem,
  ícones, mapeamentos reais, estados pendentes e ausência de
  sobreposição nos popups.
- `.github/workflows/lua-windows.yml`: build e execução gráfica
  LÖVE real, gera **dez PNGs**, incluindo galeria, tela,
  pincéis, cores, camadas e catálogo das quinze ferramentas.
- Testes existentes de raster, camadas, RBD2 e caneta mantidos.

## Próximas etapas estritamente visuais

Comparação das capturas da **versão Android 14.1.2** com os PNGs do
aplicativo em dimensões compatíveis, retificação de dimensões/categorias
e acabamento do painel de pincéis, cor, camadas, popups e galeria.
Adicionar telas e controles faltantes com estados de disponibilidade
visíveis; **não** fazer otimização de raster como prioridade.

## Fase visual 2 — janelas de pintura, cor e camadas

A segunda etapa preservou as APIs de edição Lua e mudou apenas
geometria, comandos de interface e apresentação.

**Pincéis:** biblioteca passa a exibir oito posições em lista
vertical compacta, com traço RGBA renderizado pelo motor, nome,
diâmetro, opacidade e ação `Editar`. Mantém filtros Todos/Básicos/Meus,
quatro pincéis básicos, quatro posições pessoais, salvamento,
exclusão e inspetor com rascunho/aplicação. **Não foi criado um catálogo
falso de centenas de pincéis**.

**Cor:** o painel HSB agora mostra uma roda de matiz interativa,
em torno de caixa SV, com marcador do tom ativo e alfa abaixo.
A roda utiliza `app/ibis_visual_panels.lua` e o controle de cor
continua enviando RGBA ao motor original. RGB, paleta local, histórico
e campo hex permanecem. A posição visual e a detecção do ponteiro
compartilham a mesma geometria.

**Camadas:** linhas compactas com 52 px de altura, miniaturas RGBA
reais ampliadas e informações `Normal · opacidade`; botões
de visibilidade, ordenação, duplicação, fusão, exclusão e
controle de opacidade continuam ligados à API `Layers`.
A inscrição `Normal` descreve o modo já implementado no compositor
atual; outros modos de mesclagem **não são declarados funcionais**.

**Referências:** orientação de painel e controles visuais baseada na
[Seleção de cores oficial](https://ibispaint.com/lecture/index.jsp?no=11),
[Janela de camadas](https://ibispaint.com/lecture/index.jsp?no=156)
e [Barra de ferramentas](https://ibispaint.com/lecture/index.jsp?no=4).
Essas referências **não são captura verificada do APK 14.1.2**.

**Validação:** `tests/test_ibis_visual_panels.lua` verifica as
dimensões do catálogo, separação de ações, miniaturas e relação
geométrica entre roda HSB, quadrado de seleção e slider alfa em
960×640, 1220×800 e 1920×1080. Smoke gráfico do LÖVE e as dez
capturas continuam ativos. Ainda falta confronto manual detalhado
com capturas originais do Android 14.1.2 e teste com caneta física.

## Fase visual 3 — galeria, nova tela e controles de zoom

**Galeria:** três filtros locais (`Tudo`, `Desenhos`, `Pastas`) são
aplicados **somente ao catálogo exibido**, sem alterar `Store` ou
a localização de projetos. A galeria vazia tem um estado visual com
ação `Criar desenho`. Os cartões existentes preservam suas miniaturas
RGBA geradas do projeto real e os comandos de abrir obras/pastas.

**Nova tela:** diálogo desenhado pelo LÖVE com campos Nome, Largura
e Altura, visualização ao vivo da proporção em transparência e quatro
presets (`512×512`, `1024×1024`, `1920×1080`, `1080×1920`).
Os botões de tamanho atualizam os dois campos, sem criar arquivo antes
de confirmar. O diálogo aceita qualquer dimensão inteira de 1 a 2048,
dentro do limite do motor Lua. Projetos continuam sendo criados pela
mesma rotina `Store:createProject`.

**Canvas:** foi corrigida uma sobreposição: antes o fundo do canvas
encobria os controles compactos de zoom/desfazer; as áreas de clique
podiam continuar ativas e invisíveis. Os controles agora são
renderizados após a composição do canvas, como um grupo flutuante,
sem permitir que a pintura atinja essas áreas.

**Validação:** `app/ibis_gallery_ui.lua` contém a geometria e os
filtros em Lua puro. `tests/test_ibis_gallery_ui.lua` cobre
posicionamento em 960×640/1220×800/1920×1080, categorias, quatro
presets, valores inválidos, proporção e limites. A captura gráfica
Windows publica doze telas reais, acrescentando o diálogo e a galeria
filtrada. A prioridade continua exclusivamente visual: ainda são
necessários ajustes de proporção baseados em telas comprovadas da
versão 14.1.2, não apenas em tutoriais públicos.

## Fase visual 4 — seis controles superiores do editor

A barra superior direita agora segue a **ordem de funções apresentada
na documentação oficial do ibisPaint**: Visualização, Seleção,
Estabilizador, Formas, Régua e Materiais. Fonte secundária:
[03. Toolbar and Tool Selection](https://ibispaint.com/lecture/index.jsp?no=4).
O catálogo está em `app/ibis_top_toolbar.lua`, com geometria
testável, seis ícones vetoriais originais em `app/ui_icons.lua`
e interação isolada acima do canvas.

**Ações conectadas ao motor Lua atual:**

- **Visualização:** painel compacto com Encaixar, zoom, giro,
  zerar rotação e estado de prévia, reaproveitando `canvas_view.lua`.
- **Seleção:** ativa a ferramenta `select` e abre propriedades com
  transformações já disponíveis, desabilitadas sem seleção válida.
- **Estabilizador:** nível 0..5, com controles reais para
  `A.stabilization`, sem alterações permanentes no raster ao abrir.
- **Formas:** ativa a ferramenta `shape`, permitindo selecionar
  retângulo, elipse, linha, contorno/preenchimento e espessura.
- **Régua e Materiais:** janelas de apresentação **explicitamente
  pendentes**, sem implementar nem simular operações e sem alterar
  a obra.

Os quatro novos popups são tratados por `app/compact_layout.lua`.
Os botões são renderizados **após** o desenho do canvas,
e seu hitbox fica fora da área interativa de pintura. Isso evita
o defeito anterior dos controles de zoom encobertos.

**Validação visual:** `tests/test_ibis_top_toolbar.lua` verifica
ordem, ícones, posição, áreas de clique, separação da barra de zoom
e limites de janelas nas três resoluções suportadas.
A captura Windows agora inclui dezesseis imagens reais,
com as telas de Visualização, Estabilizador, Formas e Materiais.
Os testes de composição, camada, histórico RBD2 e Windows Ink
existentes permanecem ativos.

**Clique real automatizado:** o showcase Windows executa
`love.mousepressed` sobre as hitboxes de Visualização, Estabilizador,
Formas e Materiais nas etapas 13–16. Após cada clique compara a
ferramenta e o popup esperados, os bytes RGBA antes/depois e a contagem
do histórico. A interface não pode criar pintura ou edições implícitas
ao trocar painéis. Essa verificação passou no [Windows Actions
#41350930811](https://github.com/SrTristeSad/Ibis-Rebuild-Windows/actions/runs/41350930811);
o teste LuaJIT da geometria passou no [Linux Actions
#41350930799](https://github.com/SrTristeSad/Ibis-Rebuild-Windows/actions/runs/41350930799).

**Limite da evidência:** a documentação pública descreve o fluxo
do ibisPaint, mas não comprova equivalência geométrica específica
com cada build Android 14.1.2. A aprovação visual depende de
confrontar as capturas reais da aplicação com referências da
versão-alvo fornecidas pelo criador.

## Fase visual 5 — seletor HSB em losango e sliders dedicados

A [janela de cores descrita no tutorial oficial](https://ibispaint.com/lecture/index.jsp?no=11)
usa **roda circular de matiz com seletor em losango**, não o
quadrado pequeno que aparecia no nosso screenshot da fase anterior.
O objetivo desta fase foi corrigir essa diferença comprovada
na **apresentação e na interação**, sem mudar o raster Lua.

Implementado:

- `app/color_window.lua`: geometria invertível de um losango HSB:
  topo representa branco, direita matiz saturada e brilhante,
  base preto; `svPoint` e `svAt` mantêm posição e valor
  da cor sincronizados. `svHit` rejeita as áreas transparentes
  dos cantos da imagem; roda e losango não compartilham hitbox.
- `app/main.lua`: textura HSB em losango gerada uma vez por
  matiz arredondada, com cache de imagem GPU liberado ao substituir;
  indicador da cor selecionada e borda geométrica.
  A prévia não é uma pincelada nem altera RBD2.
- **Três sliders HSB compactos**, à direita da roda, para
  matiz, saturação e brilho, com gradientes, marcadores e
  captura/arrasto reais. O slider alfa separado, RGB e paleta
  existentes permanecem disponíveis.
- `tests/test_color_brush_windows.lua` e
  `tests/test_ibis_visual_panels.lua`: conversão geométrica,
  cores nos vértices e dentro do losango, limites, hitboxes
  da roda e sliders em 960×640, 1220×800 e 1920×1080.
- Showcase Windows com **19 screenshots reais**, inclusive
  losango HSB, RGB e paleta. O teste gráfico usa
  `love.mousepressed` e `love.mousereleased` na roda,
  no losango e no slider de saturação, verificando a cor
  resultante, bytes RGBA intactos e histórico de edições
  inalterado.

**Limitações:** essa referência é uma documentação pública
do ibisPaint; não equivale a uma inspeção dinâmica da versão
Android 14.1.2. O painel ainda precisa passar por comparação
de proporções, cores e componentes com screenshots autenticados
da versão-alvo. Não introduz pincéis, blends ou filtros novos.

## Complemento visual — paleta inicial não vazia

A documentação do ibisPaint descreve uma paleta inicial preparada,
além de cores recentes e da capacidade de guardar cores favoritas.
A captura anterior do rebuild mostrava uma aba `Paleta`
praticamente vazia, porque só exibia cores salvas pelo usuário.

Em `app/ibis_palette_ui.lua`, adicionamos uma **paleta inicial
independente de 36 cores RGBA** em quatro linhas de nove amostras,
com uma aba `Cores básicas` e outra `Minhas`. As cores são uma
seleção de interface criada para o rebuild, **não são amostras
extraídas ou declaradas exatas do Android 14.1.2**.
O histórico e a persistência de cores pessoais continuam separados.

`tests/test_ibis_palette_ui.lua` testa limites e colisões das
células nas três dimensões suportadas, cores RGBA e separação da
paleta pessoal. A GUI Windows clica em uma cor básica e confirma
que o tom selecionado mudou, mas os bytes do raster e o histórico
RBD2 ficaram inalterados. O showcase gera **20 capturas**,
incluindo os estados de cores básicas e cores pessoais.

## Fase visual 6 — janela de camadas e modos de mesclagem

A referência [Layer Window Details](https://ibispaint.com/lecture/index.jsp?no=156)
documenta uma linha distinta para **camada de seleção**, miniaturas
de camadas, visibilidade, opacidade, operações de camada e uma
lista de **modos de mesclagem**. Nosso painel compacto anterior
não apresentava a camada de seleção nem permitia visualizar
os modos disponíveis no original.

Implementação da interface, sem alterações no raster:

- `app/ibis_layer_ui.lua`: geometria da linha de seleção e
  catálogo explícito de oito modos. Somente **Normal**
  aparece disponível, pois o motor Lua atual não comprova
  mesclagem equivalente às demais opções.
- `app/main.lua`: linha superior **Camada de seleção** com
  estado vazio ou dimensões da seleção atual, sem criar uma
  camada raster fictícia; lista raster deslocada para não
  se sobrepor; modo `Normal` clicável apenas na camada ativa,
  com acesso à lista visual completa.
- Modo `Normal` retorna ao painel de camadas;
  `Multiplicar`, `Tela`, `Sobrepor`, `Adicionar`,
  `Subtrair`, `Escurecer` e `Clarear` aparecem
  desabilitados e não executam operações não implementadas.
  Cliques nesses itens não fecham a janela nem modificam
  o desenho. Há botão de retorno do seletor de modos
  para as camadas.
- Redimensionados os limites de lista em `app/compact_layout.lua`
  e `app/ibis_visual_panels.lua` para comportar a linha de
  seleção mantendo o controle de opacidade e os comandos
  existentes.
- `tests/test_ibis_layer_ui.lua` verifica geometria da janela
  em 960×640, 1220×800 e 1920×1080, ausência de sobreposições,
  separação da seleção e indisponibilidade explícita
  dos modos ainda sem motor.
- Showcase real Windows inclui capturas `21-camada-selecao.png`,
  `22-modos-mesclagem.png` e `23-selecao-ativa.png`, com cliques
  reais que verificam a navegação, a permanência do popup de modos
  desabilitados e a integridade dos bytes RGBA e histórico.

**Fidelidade ainda não comprovada:** títulos, espaçamento e
proporções são uma aproximação visual a partir do tutorial
oficial, e não medições diretas da versão Android 14.1.2.
Pastas, máscaras, alpha lock, clipping e modos alternativos
continuam pendentes da fase de motor e documentação específica,
não foram apresentados como já funcionais.

## Complemento — seletor de ferramentas em 1, 2 ou 3 colunas

O [tutorial oficial #03](https://ibispaint.com/lecture/index.jsp?no=4)
descreve **1, 2 ou 3 colunas** no seletor popup. A interface
anterior só desenhava duas colunas, embora a documentação da fase
inicial descrevesse incorretamente uma grade 3×5. Corrigimos
a divergência permitindo os três modos sem alterar os 15 IDs,
a ordem ou seus backends Lua.

- A opção ativa é persistida em `preferences.json`
  (`toolPopupColumns`). Valores ausentes ou inválidos usam duas
  colunas, preservando a apresentação anterior.
- Uma coluna dispõe os itens em páginas de até sete ferramentas;
  duas colunas exibem oito linhas; três usam cinco linhas.
  Assim todas as ações permanecem acessíveis na janela 960×640.
- O seletor de colunas foi colocado no **cabeçalho do popup**
  como adaptação para Windows. **Diferença declarada:** no ibisPaint
  documentado, essa preferência é ajustada na tela Configurações.
- `tests/test_ibis_tool_popup_columns.lua` valida geometria,
  ausência de colisões, acesso a quinze ferramentas e persistência.
  O showcase Windows gera três capturas reais extras, testa cliques
  de paginação e troca de coluna, verificando bytes RGBA e histórico
  inalterados.
- Não é declarada paridade pixel a pixel com o APK 14.1.2:
  escala, iconografia e o controle no cabeçalho dependem de
  validação visual do criador.

## Ajuste de fidelidade — Voltar → Configurações

A referência [03. Toolbar and Tool Selection](https://ibispaint.com/lecture/index.jsp?no=4)
e [184. Settings window details](https://ibispaint.com/lecture/index.jsp?no=81)
indica que o número de colunas do popup fica em **Voltar →
Configurações → Interface**, e não no cabeçalho da paleta de ferramentas.

- A barra compacta agora abre o menu Voltar com **Voltar para A
  Minha Galeria / Configurações / Cancelar**, preservando a antiga
  ação de retornar à galeria e o salvamento RBD2.
- O painel de Configurações mostra **Posição da seleção de
  ferramentas**, com Popup ativo e Esquerda/Direita explicitamente
  indisponíveis enquanto não houver implementação visual dessas
  variantes. Não há rota falsa para layout lateral.
- **Número de colunas** (1/2/3) e **Mostrar nomes das ferramentas**
  (Ativado/Desativado) atualizam somente a apresentação da paleta e
  persistem com `Store:setPreferences` (`toolPopupColumns` e
  `toolPopupLabels`). Valores ausentes usam 2 e verdadeiro.
- Os três botões temporários de coluna no cabeçalho da janela de
  ferramentas foram retirados. A opção de nomes tem impacto
  visual verificável no popup de ferramentas.
- `app/ibis_settings_ui.lua` expõe geometria Lua pura;
  `tests/test_ibis_settings_ui.lua` e a suíte Windows verificam
  limites, não colisão, preservação das preferências e ausência
  de edição do raster durante cliques reais.
- Capturas Windows **60–62** ilustram menu, painel e catálogo sem
  rótulos. A captura 59 passa a trocar colunas pelo caminho oficial.

**Evidência:** a hierarquia foi obtida dos tutoriais publicados,
não medida diretamente no APK Android 14.1.2. A disposição exata,
as cores e fontes exigem conferência contra imagens autênticas do APK.

## Galeria compacta de miniaturas e rolagem independente

O fluxo `My Gallery` mostrado em
[20. View Your Artwork](https://ibispaint.com/lecture/index.jsp?no=20)
e [29. Rearrange artworks](https://ibispaint.com/lecture/index.jsp?no=103)
apresenta **barra escura superior, título com quantidade de obras,
miniaturas em grade, e barra de ações inferior**. A galeria anterior
do rebuild tinha cabeçalho de aplicativo desktop, cartões grandes
e **obras inacessíveis quando excediam a primeira viewport**.

- `app/ibis_gallery_shell.lua` fornece geometria pura para grade
  responsiva, viewport, áreas clicáveis, rolagem limitada e menu
  da ação `+`. Preserva `visual_hierarchy.lua` para os contratos
  e testes da interface desktop anterior; não cria outro catálogo.
- `app/main.lua` usa miniaturas RGBA reais do cache existente,
  barra superior `A Minha Galeria (n)`, botão `Selecionar` em
  modo **somente visual** e rodapé `+` com ações existentes de
  `Nova tela` e `Nova pasta`. A seleção em lote, ordenação,
  compartilhamento e ferramentas de nuvem **não foram implementadas**.
- Os filtros `Tudo / Desenhos / Pastas` permanecem no rebuild,
  claramente não reivindicados como organização exata do APK.
  A rolagem do mouse não toca em pixels RBD2, camada, histórico
  nem muda de ferramenta. O botão `Voltar` navega ao pai da
  pasta atual, sem fingir uma tela inicial Android inexistente.
- `tests/test_ibis_gallery_ui.lua` cobre a nova geometria, a
  acessibilidade da última obra e clipping; o showcase Windows
  cria 18 **obras de teste isoladas**, compara a integridade do
  desenho ativo e captura as telas `63–65` (grade, rolagem,
  seleção visual).

**Limite de evidência:** screenshots de tutoriais oficiais
fundamentam hierarquia visual, não equivalência pixel a pixel
com o APK Android 14.1.2. Nenhum asset original foi copiado.

## Estabilizador — controles específicos do ibisPaint 14.1

A [versão oficial 14.1.0](https://ibispaint.com/newFeature.jsp?lang=en)
e o [tutorial 39, Stabilizer](https://ibispaint.com/lecture/index.jsp?no=50)
documentam a janela de **Tempo real**, **Constante**, **Traços rápidos**
e **Fade**, além da possibilidade de optar pela estabilização legada.
A janela anterior do rebuild apresentava apenas um controle legado
de 0 a 5, visualmente incompatível com a atualização 14.1.x.

- `app/ibis_stabilizer_ui.lua`: abas Estabilizar/Fade, opção
  de aplicar apenas ao pincel atual, seção de Tempo real,
  dois controles de rascunho independentes (Constante e Traços
  rápidos), interface de comprimentos inicial/final, formato
  Suave/Linear e geometria pura em Lua.
- `app/compact_layout.lua`: popup do estabilizador passa de
  318×254 a 348×430; cabe inteiramente em 960×640.
- `app/main.lua`: seleção de abas, escopo, rascunhos e
  opções Fade clicáveis. **Esses controles NÃO afetam a
  pintura**. A opção Após fica explicitamente pendente.
  O **nível legado 0–5** continua conectado ao motor Lua
  preexistente e é identificado separadamente.
- Escalas 0–100 dos rascunhos são uma escolha provisória
  de visualização; não são declaradas medições exatas
  do Android 14.1.2, nem simulam equivalência de curvas.
- `tests/test_ibis_stabilizer_ui.lua`: posicionamento,
  limites, independência de parâmetros e motores desabilitados.
  O showcase Windows adiciona quatro imagens `66–69`,
  exercitando cliques reais, integridade RGBA/histórico e
  manutenção do controle legado funcional.

**A reconstrução ainda não implementa a correção Constant,
Fast Strokes, After ou Fade como motores.** Essa fase
corrige exclusivamente aparência, navegação e estados,
sem modificar o algoritmo de estabilização existente.

## Nova tela — categorias de formato e dimensões da referência

A documentação oficial de [criação de obra](https://ibispaint.com/lecture/index.jsp?no=03)
mostra o seletor de dimensões e o uso de qualquer tamanho, HD/SD;
o [histórico oficial de novidades](https://ibispaint.com/newFeature.jsp?lang=en)
publica os tamanhos 1:1 (768×768), 3:4 (768×1024),
9:16 (720×1280) e A4 150 dpi (1240×1754).

- O diálogo `Nova tela` mantém seus campos de nome, largura,
  altura e a prévia da proporção, mas dispõe agora de duas abas:
  **Básicos** (presets anteriores) e **Formatos** (as quatro
  dimensões publicadas pelo ibisPaint).
- A aba de formatos fornece apenas dimensões em pixels; o
  **DPI do papel A4 não é armazenado** e não se promete
  fidelidade de exportação/impressão. O texto da interface
  sinaliza essa limitação.
- Alternar abas não sobrescreve dimensões digitadas,
  não cria arquivos e não muda o raster. Somente selecionar
  um preset altera largura/altura; somente `Criar tela`
  confirma `Store:createProject`.
- `app/ibis_gallery_ui.lua` centraliza dados e hitboxes;
  `tests/test_ibis_gallery_ui.lua` testa os dois catálogos,
  limites, proporções e ausência de sobreposição a 960×640,
  1220×800 e 1920×1080. O showcase gráfico Windows
  testa o clique real nas abas e nos tamanhos 3:4/A4,
  com capturas **70–74** e prova de que o número de obras,
  bytes RGBA e histórico não mudam antes da confirmação.

O limite de 2048 pixels por dimensão é do motor do rebuild,
não do ibisPaint original. Os screenshots oficiais
não comprovam paridade pixel a pixel com o Android 14.1.2.

## Seleção múltipla na galeria — rodapé funcional e ações pendentes

As referências oficiais
[30. Artworks Folder Feature](https://ibispaint.com/lecture/index.jsp?no=193)
e [notas da versão 6.2.0](https://ibispaint.com/information.jsp?newsID=10696514)
confirmam seleção múltipla para mover e excluir obras.

- O modo **Selecionar** mantém as miniaturas e marcas existentes.
  O rodapé mostra a **contagem de itens selecionados** e as ações
  **Todos / Limpar / Mover / Excluir**; a ação `+` só existe fora
  do modo de seleção.
- **Todos** e **Limpar** estão ligados ao catálogo visível atual
  (pastas e obras), respeitando filtros. Atalhos Ctrl+A e Ctrl+D
  funcionam somente durante seleção; Escape/Concluir encerram
  o modo e limpam as marcas.
- **Mover** e **Excluir** permanecem visualmente indisponíveis.
  Não existem permissões falsas nem deleções experimentais:
  ambos exigem implementação e testes adicionais do Store.
- `app/ibis_gallery_shell.lua` concentra as regras de chaves,
  contagem e geometria sem chamadas a arquivos. A suíte
  `tests/test_ibis_gallery_ui.lua` verifica filtros,
  exclusão de IDs invisíveis, ações disponíveis e
  hitboxes em três resoluções.
- O showcase Windows captura **75–78**, incluindo cliques
  reais em Todos/Limpar e clique num botão desabilitado,
  com igualdade dos bytes RGBA, do histórico e da quantidade
  de projetos e pastas antes/depois.

A ordem, as dimensões e a aparência exatas dos controles
continuam sem comparação direta com o APK Android 14.1.2.
