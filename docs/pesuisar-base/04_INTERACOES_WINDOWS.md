# 04 — Comportamento comprovado do ibisPaint no Windows

Fontes centrais:
- [196/195 — Gestures, Keyboard Shortcuts (Windows Version)](https://ibispaint.com/lecture/index.jsp?no=167)
- [184 — Settings](https://ibispaint.com/lecture/index.jsp?no=81)
- [188 — Layer Window](https://ibispaint.com/lecture/index.jsp?no=156)
- [New Feature](https://ibispaint.com/newFeature.jsp)
- [Produto Windows](https://ibispaint.com/productWin.jsp)

## A. Mouse, teclado e caneta — comportamento explicitamente Windows

| Operação | Interação documentada |
|---|---|
| Mover o canvas | Espaço + arrastar com botão esquerdo do mouse |
| Aproximar/afastar | Roda do mouse; para caneta Alt+Espaço ou Z + arrasto |
| Girar canvas | Shift + roda do mouse; para caneta Shift+Espaço ou R + arrasto circular |
| Conta-gotas rápido | Botão direito com Pincel ativo, sem trocar de ferramenta; implementado/testado na A42 |
| Mudar espessura | Alt+Ctrl + arraste do mouse; para caneta equivalente com teclas. A43 implementa o ajuste no rebuild com sensibilidade própria; [ e ] ajustam 1 px |
| Abrir lista de atalhos | Shift + / (slash) |
| Copiar/cortar/colar | Atalhos ilustrados no manual, verificar mapa em imagem da versão-alvo |
| Confirmar campos/diálogos | Enter; Tab muda foco de campos, conforme manual |
| Cancelar/fechar/foco | Escape; comportamento varia conforme popup |

A lista completa **é configurável/evolui**: não inventar
mapeamentos de Ctrl+S etc a partir do rebuild. O tutorial
mostra os comandos em imagens, e a lista da aplicação é
a fonte definitiva.

## B. Funcionalidades específicas de PC

### Drag-and-drop no Windows/Mac

A página oficial [New Feature](https://ibispaint.com/newFeature.jsp)
documenta:
- Arrastar imagem do Explorer para **Title/My Gallery**:
  criação de nova obra no catálogo.
- Arrastar para o **Canvas**: importar como camada, abrir
  Transform e permitir mover/rotacionar/redimensionar.
- Ao arrastar, aparece indicador "+" no destino.
- Fotografar indicador de drop, cursor, progresso,
  erro de formato inválido e eventual diálogo, sem inventá-los.

### Camadas flutuantes

Desde a versão 12.2.0 o Windows suporta janela de camadas
flutuante. O [manual](https://ibispaint.com/lecture/index.jsp?no=156)
mostra:
- abrir Layer → botão de floating ou arrastar move bar;
- janela sobre o desenho; arrastar barra para mover;
- redimensionar por cantos/bordas; botão X fecha;
- configuração separada de altura das linhas no modo floating.

### Cor flutuante

[Novos recursos](https://ibispaint.com/newFeature.jsp):
abrir Color, botão floating ou arrastar move bar; mover,
redimensionar e fechar. Disponível em tablets e PCs.
A posição padrão e as dimensões exatas da build Windows
continuam não verificadas.

### Windows Ink e portabilidade

Produto oficial requer compatibilidade com Windows Ink em
dispositivos com caneta e toque. A implementação LuaJIT FFI
do rebuild já possui integração em CI com a janela, mas
a validação com caneta física permanece em aberto.

## C. Ajustes específicos do Windows

Em [Settings](https://ibispaint.com/lecture/index.jsp?no=81):
- "Invert Direction of Mouse Wheel" presente no Windows/Mac;
- seleção Tool Position left/right/popup;
- exibição dos nomes dos instrumentos;
- quantidade de colunas no popup;
- alturas distintas para camadas e floating;
- formato dos thumbnails;
- exibição dos atalhos de teclado;
- alguns itens de som não são mostrados em PC.

**Não substituir UI do Windows por telas de configuração Android
só porque o APK contém preferências similares.**

## D. Importar, salvar e persistência

Formatos oficiais PC, conforme
[productWin](https://ibispaint.com/productWin.jsp):
- Entradas: BMP, JPEG, PNG, TIFF, PSD, IPV.
- Saídas: JPEG, PNG, PSD, IPV.
- My Gallery pode sincronizar via Cloud Storage.
- [PSD](https://ibispaint.com/lecture/index.jsp?no=119):
  exportar com camadas preservadas ou achatado, conforme escolha;
  verificar o fluxo no PC.
- Original do aplicativo usa IPV; **RBD2 do nosso rebuild é um
  formato próprio e não pode ser declarado compatível com IPV**.
  Não inventar importador de IPV se não existe.

## E. Sistemas confirmados como parte do produto, mas com
## UI exata ainda pendente de captura Windows

Ferramentas Brush/Eraser, Smudge, Blur, Bucket, Lasso,
Wand, Transform, Vector, Text, Frame Divider, filtros
e Adjustment Layers; seleção, forma/régua, materiais,
paleta e cores, importação PSD, gravação e animação.
A confirmação conceitual consta nos [tutoriais oficiais](https://ibispaint.com/lecture/index.jsp?no=0)
e na [página do Windows](https://ibispaint.com/productWin.jsp).
**Ter recurso no produto não equivale a ter seu layout ou
comportamento detalhado completamente mapeado.**

## F. Efeitos de versão

[Novidades 12.2](https://ibispaint.com/newFeature.jsp):
Collection removida; pastas introduzidas; floating layers
Windows; mudança em hit de botão +/- e trilho entre eles.
[Novidades 14.1](https://ibispaint.com/newFeature.jsp):
revisões em estabilizador, pincel, Shape, layer solo e
outras funções; dependência de versão/licença deve ser
verificada na build PC efetiva.

O [histórico 14.1.4](https://ibispaint.com/historyAndRights.jsp?newsID=313331619)
menciona correções específicas de Windows; logo, fotos de
2022/2024/2025 não devem ser copiadas sem revalidar em 2026.
