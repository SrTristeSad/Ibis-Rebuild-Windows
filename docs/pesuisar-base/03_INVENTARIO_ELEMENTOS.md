# 03 — Inventário rastreável de elementos e estados da interface

**Referência visual obrigatória: Windows oficial.** O manual
geral ajuda a identificar elementos, mas não valida layout PC.
Classificações: **W** = comprovado PC/Windows; **G** = oficial
multiplataforma, geometria PC pendente; **P** = PC/tablet documentado;
**?** = não verificado para versão visual-alvo.

| Área / tela | Elementos, estados e ações a fotografar | Evidência |
|---|---|---|
| Tela inicial | Logo, versão, My Gallery, Online Gallery, Pro, Ajuda, Ajustes, Daily Ranking, avisos, estado sem rede | W02 13.1.8; HIST 2022; atual ? |
| Galeria | Cabeçalho, botão criar (+), obras, thumbnail, vazio, nuvem, seleção, edição, ordenação, pasta, arrasto, lixeira | W05 pastas e reorganização; visual atual ? |
| Nova obra | Tipo (imagem/animação...), importar imagem, presets, largura, altura, proporção, DPI, qualidade, unidades, limite, confirmar/cancelar | G tutorial início; visual PC atual ? |
| Editor, vista normal | Área de desenho, fundo, recorte, zoom/rotação, faixa esquerda, rodapé, barra superior, cursor e scroll | W01/W03; escala exata ? |
| Editor, foco e vistas | Zoom, rotação, espelhar visualização, grid, guidelines, referência, fullscreen, redimensionamento | W02 + G View Menu |
| Barra inferior | 9 ações documentadas (detalhe abaixo), seleção, disabled, hover, teclado | G01; confirmar disposição em PC-alvo |
| Seletor de ferramentas | Left/Right/Popup, largura, itens, rótulos, 1/2/3 colunas popup, highlight, scroll, abertura/fechamento | W04 (opções) + G02; layout PC atual ? |
| Topo direito | View, seleção, estabilização, formas, régua, Material; cliques, menus e estado ativo | G03; confirmar layout PC |
| Traços rápidos | Espessura, opacidade, -/+, trilho, handle, numerais, arrasto, wheel e atalhos | W02/G01; curva e medidas ? |
| Pincel/borracha | Lista de pincéis, tipos, busca, ajustes, amostra, categorias, customização, modos, pressão, inclinacão | G03, Store IMG-M01; medir PC |
| Cor | Cor atual/anterior, HSB/RGB, roda, hex, opacidade, paleta, histórico e cor salva | G Color; possibilidade de floating PC |
| Camadas | Selection Layer, raster, vector, folder, adjustment, 3D, linha, thumb, número/nome, seleção, olho, ordem, menu | G Layer Details; implementação varia por licença |
| Layer: ações | Criar/duplicar/excluir, limpar, renomear, copiar, bloquear, solo, mesclar, inverter, mover, alpha-lock, clipping | G Layer Details |
| Layer: rodapé | Blending mode, opacidade, fundo branco/transparente, seleção, thumb inteira/só conteúdo, ajuste de altura | G Layer Details / W04 |
| Floating Layer | Abre por botão ou barra; título, mover, redimensionar pelas bordas, fechar, estado persistente | **P01/P02; PC documentado** |
| Floating Color | Abre na janela Color, move, redimensiona e fecha; sobreposição ao canvas | **P: novidades oficiais** |
| Settings | Gesture, UI, pressão/stylus, cursor, profissionais, conta, nuvem, privacidade, backup/reset | W04, diferenças Windows |
| View Menu | Reference Window, grade e cor/passo, manga manuscript, interpolation zoom/pixel | G View |
| Selection | Seleção livre, laço, mágica, cor, transformar, acrescentar/subtrair, preview e concluir | G tutorial por ferramenta |
| Transform | Mover, escalar, girar, perspective/mesh; confirmação, desfazer | G tutorial |
| Filter | Categorias e submenus, preview, parâmetros, aplicar/cancelar, efeitos condicionados | G catálogo oficial |
| Régua/Formas | Straight/Circular/Elliptical/Symmetry/Perspective; posições, snapping, shapes e parâmetros | G tutorial + Store M02 |
| Texto | Inserir, editar, fonte, tamanho, cor, estilo, caixa, confirmação, camada | G tutorial + Store M02 |
| Material | Busca, categorias, thumbs, importação, inserção, dimensionamento, licenças | G tutorial + Store M03 |
| Animação | Frames, timeline, onion skin, play, FPS, loop, export vídeo, áudio se disponível | G tutorials/novidades |
| Back/Menu | Configurações, salvar imagem, galeria, fechamento, confirmação e estados | W03 + G início |
| Arquivos | Abrir/importar BMP/JPEG/PNG/TIFF/PSD/IPV; exportar JPEG/PNG/PSD/IPV | **W01 formatos** |
| Drag-and-drop | Arquivo sobre título/galeria cria obra; no canvas adiciona camada/transform | **W05 explicitamente PC** |
| Nuvem | Sincronização, pasta, estado conectado/desconectado, erro, progresso | W01 + G nuvem |
| Conta/licença | Login, demonstração, Pro/Premium, acesso bloqueado, mensagens da região | W01; estado exato ? |
| Teclado/ajuda | Janela de atalhos, edição/consulta, pressionamento, tab/foco, confirmar/fechar | **W02** |

## A. Barra principal (manual oficial — conferência visual PC pendente)

Da esquerda para a direita:
1. Brush/Eraser (alternar); 2. Tool Selector; 3. Properties;
4. Color; 5. Fullscreen; 6. Undo; 7. Redo; 8. Layer; 9. Back.

Fonte: [Toolbar and Tool Selection](https://ibispaint.com/lecture/index.jsp?no=4).
A contagem e a ordem são **contratos de tutorial**, não justificativa
para inventar hitboxes em pixels.

## B. As quinze ferramentas da seleção oficial

| # | Ferramenta | Interface/painel para auditar |
|---:|---|---|
| 1 | Transform | translate, scale, rotate, perspective/mesh |
| 2 | Magic Wand | modo de seleção, tolerância, preview |
| 3 | Lasso | desenhar forma livre, adicionar/remover seleção |
| 4 | Filter | categorias, opções, preview e OK/Cancel |
| 5 | Brush | preset, lista, parâmetros, custom, preview |
| 6 | Eraser | preset, tamanho, opacidade e dinâmica |
| 7 | Smudge | preset, espessura, intensidade |
| 8 | Blur | preset e controle de intensidade |
| 9 | Special Pen | lista de efeitos, parâmetros |
| 10 | Bucket | modo de preenchimento, tolerância, referência |
| 11 | Vector | elementos vetoriais e edição |
| 12 | Text | texto e fonte, camada e opções |
| 13 | Frame Divider | quadros, margens, divisão |
| 14 | Eyedropper | origem, rápido, cor e camada |
| 15 | Canvas | transformação/tamanho/resolução |

Fonte: [03 — Toolbar and Tool Selection](https://ibispaint.com/lecture/index.jsp?no=4).
**Não afirmar que todos os motores já funcionam no rebuild.**
Os subsistemas pendentes continuam pendentes e o clone visual
deve refletir com exatidão estados suportados/indisponíveis.

## C. Inventário detalhado de Layer Window

Documentação: [188 — Layer Window Details](https://ibispaint.com/lecture/index.jsp?no=156).

- **Linhas/tipos:** Selection Layer, raster, pasta, vector,
  adjustment, 3D (dependência de versão/plano).
- **Coluna da lista:** miniatura, visibilidade, nome, número,
  estado selecionado, reordenação, menu, pasta expandida/fechada.
- **Ações:** adicionar layer, adicionar especial, duplicar,
  importar imagem, limpar, inverter cor, mover/transformar,
  espelhar horizontal/vertical, mesclar abaixo, excluir,
  clipping, alpha-lock, opacity, blend mode.
- **Menu contextual:** renomear, bloquear, solo, rasterizar,
  salvar layer PNG transparente, seleções a partir de opacidade.
- **Fundo:** cor sólida, transparência clara/escura, papel
  de canvas e configurações.
- **Modo floating de PC:** botão específico, barra de mover,
  arrasto, redimensionamento por cantos/bordas e fechar.

## D. Inventário da janela de cor

Documentação: [10 — Color window](https://ibispaint.com/lecture/index.jsp?no=11).

Cor atual/anterior; roda HSB e região de valor/saturação;
sliders H, S, B e opacidade; alternância HSB/RGB;
entrada de código hexadecimal; paleta salva; histórico
(100 amostras segundo tutorial geral); picker e janela floating
PC/tablet segundo notas oficiais. Conferir diferenças de versão.

## E. Pincéis e propriedades

Documentação: [186 — Brush Parameters](https://ibispaint.com/lecture/index.jsp?no=118).

Guia Basic (tamanho/opacidade); Fade (início/fim),
Shape (forma/espaçamento), Jitter, Type (tipo/textura),
Dynamic (velocidade/pressão), Settings (mín/máx,
blend/nome/reset), Texture (em modos aplicáveis).
A captura promocional do Microsoft Store mostra uma
janela de pincéis com lista e ajustes; não prova valores
nem quantidade atual.

## F. Configurações e diferenças de PC

Documentação: [184 — Settings](https://ibispaint.com/lecture/index.jsp?no=81).

Tool Select Position Left/Right/Popup; popup 1–3 colunas;
mostrar rótulos; mensagens Undo; tema de janela;
suavização/pixelização em zoom; Layer Row Height (normal
e floating); conteúdo das miniaturas; fundo de canvas;
Show Keyboard Shortcuts; Invert Mouse Wheel Direction
(**Windows/Mac**). Alguns itens *não* aparecem no PC
(exemplo: efeitos sonoros). Não criar controles mobile
que a documentação marca como indisponíveis no Windows.

## Regra geral de estados

Para cada item acima, pesquisar e capturar: fechado; aberto;
selecionado; desabilitado; vazio; com dados; foco/hover;
scroll; menu de opções; cancelamento/confirmar; alternância
de temas; janela pequena/grande; DPI. **Estado não visto
deve permanecer "?"**, e não ser preenchido por imaginação.
