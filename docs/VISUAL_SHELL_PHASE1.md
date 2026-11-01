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
