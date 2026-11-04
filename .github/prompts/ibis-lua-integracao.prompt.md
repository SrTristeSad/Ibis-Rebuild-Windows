---
description: Integrar o Ibis-Lua existente ao motor Lua/LÖVE do Ibis-Rebuild-Windows, sem reinventar a interface.
---
Você está trabalhando no repositório Ibis-Rebuild-Windows. Respeite a autoria e as decisões existentes.

A interface de referência é **exclusivamente** https://github.com/SrTristeSad/Ibis-Lua, incluída como submódulo em ui/Ibis-Lua. Ela já existe: **não invente uma nova interface**, não substitua componentes visuais e não refaça o que já está implementado nela.

O motor de edição ativo deve ser implementado em **Lua/LuaJIT + LÖVE 11.5**, sem chamadas a rebuild_core.dll, FFI, WebView ou C++ do projeto. Separe pixels, persistência e integração de eventos do código visual. Não elimine recursos de UI para facilitar o motor.

Estado funcional conhecido: motor Lua com pincel circular, borracha,
preenchimento contíguo, conta-gotas, camadas normais, Alpha Lock,
Clipping com shader do LÖVE, blend RGBA CPU/GPU para os nove modos
já presentes no seletor (Normal, Multiply, Screen, Overlay, Darken, Lighten,
Color Burn, Color Dodge, Soft Light), snapshots limitados, miniaturas dos pixels reais
e arquivos PNG por camada. Ferramentas já ligadas à máscara raster Lua:
Varinha Mágica (RGBA contíguo), Laço (contorno livre), Transformar
(seleção retangular pelo arraste e movimento inteiro de pixels),
restrição do pincel e balde à seleção e undo/redo da movimentação.
União, subtração e interseção binária de máscaras são implementadas
em `Selection.combine(base,incoming,mode,w,h)`. Nos instrumentos
Transformar (retângulo), Laço e Varinha Mágica, capturar o modo no
**início** do gesto: Ctrl+Shift soma, Ctrl+Alt subtrai e
Ctrl+Shift+Alt intersecta. Ctrl+modificadores forçam um novo retângulo
até mesmo dentro da seleção; Shift/Alt sem Ctrl continuam sendo
redimensionar/girar na ferramenta Transformar. Sem modificadores,
substituir normalmente. Operações só de máscara NÃO tocam pixels,
dirty, histórico ou as máscaras de entrada; são permitidas em camadas
bloqueadas/Alpha Lock. Resultado vazio significa desmarcar, sem erro.
No primeiro gesto, somar equivale a selecionar; subtrair e intersectar
sem seleção resultam em máscara vazia. A seleção combinada segue
sendo salva em `selection.png`, sem criar novo formato.
Expansão/contração de máscara binária: `Selection.morph(s,"expand")`
e `Selection.morph(s,"contract")` usam vizinhança 8-conexa quadrada
de 3×3, sem alterar a máscara original. **Ctrl+Alt+Up** expande
1 pixel; **Ctrl+Alt+Down** contrai 1 pixel, acionamentos repetidos
permitem vários passos. Exterior do canvas conta como desmarcado:
expansão recorta nas bordas e contração da seleção total perde
uma borda de 1 pixel. Contração até vazio vira nil sem erro;
sem seleção ativa retornar erro não mutável. Não modificar pintura,
dirty ou histórico raster, nem depender de Layer Lock/Alpha Lock.
Persistência usa o mesmo PNG binário por obra. Testar buracos,
ilhas desconectadas, canto, ausência de seleção e atalhos/reabertura.
Feather **foi implementado** com a API `Selection.feather(s,radius)`,
raios inteiros 1..8 (atalho **Ctrl+Alt+F** usa 2 px, sem slider).
Máscaras antigas seguem binárias; `Selection.coverage(s,x,y)` expõe
a fração 0..1 opcional em `s.weights`, mantendo `Selection.contains`
compatível para os pixels com cobertura positiva. `selection.png` e
os snapshots de histórico armazenam pesos no canal alfa, quantizados
em 8 bits, sem novo formato ou campos de TSV. Clonar/restaurar máscara
NÃO pode compartilhar tabela de pesos. O feather é box blur separável,
não gaussiano. Pincel, borracha, balde e Alpha Lock usam intensidade
multiplicada pela cobertura; movimento, cópia/corte/cola, giros,
espelhamento, escala e prévias GPU devem preservar pesos, separar
o alfa residual na origem e compor source-over no destino. Testar
GPU/CPU com máscara fracionária e undo/redo de edição raster.
Operações só de máscara não criam histórico raster. Existe agora um
**histórico SEPARADO e PERSISTENTE de máscara**, por
`Bridge.selection_undo()`, `Bridge.selection_redo()` e
`Bridge.selection_history_snapshot()`. **Ctrl+Alt+Z/Y** desfaz/refaz
máscara; Ctrl+Z/Y continuam exclusivamente raster.
Todas as mudanças puras de seleção (Ctrl+A, Ctrl+Shift+I,
Ctrl+Alt+F/Up/Down, Ctrl+D/Esc, retângulo, laço, varinha e combinações)
registram snapshot ANTES da confirmação, incluindo nil e pesos alfa.
Nenhum no-op cria passo; nova edição invalida redo. Limitar a 8 estados
e 1.048.576 pixels marcados por pilha (descartar os estados antigos).
Transformações raster que movem pixels+seleção limpam a timeline
independente para evitar geometria dessincronizada. Undo raster que
realmente modifica a máscara também limpa a timeline só de seleção.
Ao salvar, `SelectionHistory.save` publica uma geração nova de PNGs
e o manifesto `selection_history.tsv` DEPOIS dos snapshots. Ao reabrir,
`SelectionHistory.load` valida dimensões, ordem de pilhas, limites,
PNG e assinatura determinística da máscara atual e de cada snapshot;
só então adota todas as entradas. Uma seleção de estado nil é codificada
explicitamente no manifesto. Se inválido/ausente, mantém a seleção
corrente e inicia pilhas vazias, sem bloquear a obra nem o histórico
raster. Limpar apenas `selection_history_*.png` e o manifesto próprio
quando pilhas vazias ou gerações antigas: nunca tocar nos PNGs de
camadas, `selection.png` ou `history.tsv`. A timeline de máscara agora
persiste; o histórico raster permanece independente em history.tsv.
Não declarar feather gaussiano, slider visual ou paridade ibisPaint.
Copiar/Recortar/Colar são internos à aplicação (Ctrl+C, Ctrl+X, Ctrl+V);
colagens preservam RGBA e não criam nova camada. Rotação ortogonal
(Ctrl+Shift+R, Ctrl+Shift+L) e escala nearest-neighbour 200%/50%
(Ctrl+Shift+Up/Down) estão integradas sem novos componentes visuais.
Espelhamento horizontal e vertical da seleção usam **Ctrl+Shift+H**
e **Ctrl+Shift+V**; `Engine.reshape_selection` aceita
`"flip_horizontal"` e `"flip_vertical"`. Espelhar a máscara irregular
e os pixels correspondentes com nearest-neighbour dentro dos mesmos
limites, sem tocar em pixels não selecionados, e preservar source-over,
undo/redo de pixels e geometria, persistência do histórico e restrições
de camada bloqueada / Alpha Lock. Se largura/altura relevante tiver
um único pixel, recusar o no-op sem gravar histórico.
No instrumento Transformar, **Alt+arrastar dentro da seleção** ativa
rotação contínua pelo ângulo relativo ao centro da máscara; **Shift+
arrastar dentro da seleção** ativa escala independente X/Y pelo
deslocamento do ponteiro. A função `Engine.affine_selection` aceita filtro opcional: por padrão
usa nearest-neighbour; os gestos Alt/Shift fornecem "bilinear" com RGB
premultiplicado e vizinhos não selecionados transparentes.
A API anterior `Engine.preview_affine` CPU permanece para testes e
compatibilidade, MAS não deve rodar a cada mousemoved.
A UI usa `Engine.begin_affine_gpu_preview` para alocar UMA máscara
e Canvas por gesto; `Engine.update_affine_gpu_preview` valida a mesma
geometria do commit CPU e usa shader GLSL de bilinear.
`Bridge.draw` mostra uma camada virtual no compositor e transforma
graficamente o contorno, com origem corrigida para o canvas centralizado.
Durante o arraste, não alterar pixels, dirty, histórico ou PNGs.
O release confirma pela CPU e libera máscara e Canvas GPU. Preservar
testes de paridade RGBA GPU/CPU com tolerância e de cache de recursos.
O contorno geométrico de prévia pode diferir ligeiramente do raster
confirmado em ângulos arbitrários.
O gesto normal de mover seleção também possui prévia na GPU:
`Engine.begin_move_preview` monta máscara RGBA e Canvas UMA vez
por gesto; `Engine.update_move_preview` usa shader de source-over
com origem mascarada e offset inteiro, reaproveitando texturas e
ignorando diferenças subpixel que mantenham o deslocamento
quantizado. `Engine.move_delta` compartilha rounding/clamp
entre preview e commit CPU. A prévia não deve modificar pixels,
seleção original, histórico, dirty nem miniaturas persistidas.
No desenho, transladar o contorno visual sem recriar a máscara
raster. Liberar mask_image e Canvas ao confirmar ou cancelar.
Histórico reversível deve incluir tanto pixels quanto a geometria da seleção.
O clipboard não acessa o clipboard do Windows.
O histórico de undo/redo agora persiste em `history.tsv` e PNGs por passo
(gerações com manifesto gravado por último) para obras de até 1.048.576
pixels. Em memória permanecem até 8 passos por pilha e snapshots limitados
a 32 MiB por camada. Ao reabrir, valide integralmente manifesto,
identidade de camadas, tamanho dos PNGs e máscaras de seleção antes
de adotar as pilhas; arquivos inválidos não devem bloquear a obra.
Não persista histórico de alterações estruturais de camadas.
Mantenha os testes de reabertura, duas camadas, undo/redo com contorno,
corrupção e limpeza de arquivos antigos.
A seleção ativa agora é salva em `selection.png` por obra, como máscara
binária ou com alfa fracionário, independente das camadas.
Reabertura valida assinatura PNG,
dimensões e limite de bytes; arquivo ausente ou inválido não deve impedir
a abertura de desenhos antigos. Ctrl+D/Esc seguido de salvamento remove
a máscara antiga. O clipboard interno não é persistido.
A seleção tem limite de 1.048.576 pixels, com contorno
visual limitado a 10.000 segmentos. Não criar botões nem painéis novos.
Operações de máscara (não raster): **Ctrl+A seleciona tudo** via
`Selection.all(w,h)`; **Ctrl+Shift+I inverte a seleção** via
`Selection.invert(mask,w,h)`. Inverter sem seleção marca todo o canvas;
inverter uma seleção total desmarca, com resultado nil sem erro. Inverter
deve calcular o complemento em TODA a tela, não no bounding box, e
não pode modificar a máscara de entrada, pixels da obra, dirty ou
histórico de desfazer/refazer raster. As operações são permitidas com
Layer Lock e Alpha Lock, mas rejeitadas em tela diferente do editor.
Persistir resultado em `selection.png` pelo Bridge.save existente.
Manter testes de máscara irregular, dupla inversão, limite 1 Mi,
atalhos de teclado, estado raster inalterado e reabertura PNG.
layers.tsv com oito colunas deve ler o formato
legado de quatro colunas; document.tsv mantém camada ativa/fundo. Mantenha estas operações
regredindo **nunca** e avance conectando exclusivamente os controles existentes.
Alpha Lock, Clipping e os nove modos de blend já possuem implementações
independentes e testes: preserve igualdade entre composição CPU e shader GPU,
inclusive para alfa parcial, sem alterar o alfa original da camada clipada.
Não invente novos modos nem reivindique equivalência exata com o aplicativo oficial.
Preserve os eventos do Ibis-Lua: selecionar a ferramenta Transformar permite
arrastar para criar seleção retangular e arrastar dentro dela para mover os
pixels da camada ativa; a Varinha e o Laço possuem gestos de seleção
independentes. Rotação ortogonal, escala 50%/200%, espelhamento H/V
e copiar/colar de pixels da camada ativa possuem implementação Lua;
preserve os testes de giro, flip de máscara irregular, amostragem,
limites do canvas, source-over e histórico com contorno.
A seleção é persistente como máscara por obra; o histórico dos passos de
edição raster e da geometria associada também é salvo para obras pequenas.
A rotação contínua e a escala independente estão implementadas por
gestos modificados; teste o motor e a ponte em LÖVE e preserve o
arraste comum de deslocamento. A prévia bilinear está disponível nos gestos Alt/Shift e a prévia
GPU nearest está disponível no movimento comum do Transformar.
Não declare movimento bilinear, interpolação bicúbica, transformação
vetorial nem clipboard Windows como concluídos. Teste comparando
pixels GPU/CPU do movimento E rotação/escala, reutilização da máscara e
Canvas, rejeição de parâmetros inválidos e undo/redo após o commit. Testes incluem prévia sem mutação, paridade de pixels
com commit, transparência sem halo, desfazer/refazer e renderização da
ponte Lua com a camada virtual de prévia. Preserve testes de PNG roundtrip, arquivo inválido,
desmarcação e compatibilidade com projetos sem seleção.

Prioridade:
1. Conectar com fidelidade os eventos e estados dos controles existentes do Ibis-Lua a funcionalidades reais.
2. Preservar desenho, fluxo, assets, galeria, painel de pincéis, camadas e seletor de cores.
3. Marcar o que ainda não está implementado; não apresentar controles demonstrativos como efeitos reais.
4. Implementar e testar progressivamente ferramentas e persistência em Lua, sem regressões.
5. Atualizar testes, documentação e workflow em cada etapa.

A montagem reproduz o código do Ibis-Lua pinado e aplica apenas ganchos específicos no estágio temporário via tools/assemble_lua.py. Se alguma âncora deixar de corresponder, falhe de modo explícito; não faça substituições aproximadas que quebrem a interface.

Antes de concluir, explique quais operações funcionam realmente, quais faltam e quais testes foram executados. Não afirme CI aprovado ou compatibilidade 1:1 sem evidência.
