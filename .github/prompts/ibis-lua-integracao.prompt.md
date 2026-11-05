---
description: Integrar o Ibis-Lua existente ao motor Lua/LÖVE do Ibis-Rebuild-Windows, sem reinventar a interface.
---
Você está trabalhando no repositório Ibis-Rebuild-Windows. Respeite a autoria e as decisões existentes.

A interface de referência é **exclusivamente** https://github.com/SrTristeSad/Ibis-Lua, incluída como submódulo em ui/Ibis-Lua. Ela já existe: **não invente uma nova interface**, não substitua componentes visuais e não refaça o que já está implementado nela.

O motor de edição ativo deve ser implementado em **Lua/LuaJIT + LÖVE 11.5**, sem chamadas a rebuild_core.dll, FFI, WebView ou C++ do projeto. Separe pixels, persistência e integração de eventos do código visual. Não elimine recursos de UI para facilitar o motor.

**Histórico do pincel/borracha somente quando muda pixels**:
`Engine.stroke(..., selection, on_first_change)` recebe um callback
final opcional, que é executado uma vez por chamada e ANTES da primeira
escrita que ultrapasse meio nível RGBA 8-bit. A ponte só chama
`Engine.begin_stroke` quando houver alteração e no máximo uma vez
por gesto via `drawing.history_started`. Sem alterações reais,
não fazer `replacePixels`, não marcar dirty, não criar undo nem
apagar redo. Um clique no pixel já da mesma cor, eraser em
transparência, Alpha Lock em vazio, opacidade zero/sub-byte e
seleção fora da pincelada são no-op. Um arraste pode começar sem
efeito e pintar depois; capturar a camada ANTES da primeira edição
e permitir undo/redo do gesto completo. O `Engine.stroke` direto
sem callback não cria histórico automaticamente, preservando seu
contrato com `Engine.begin_stroke` explícito. Testar pixels,
arraste real da UI, máscaras, undo/redo e histórico persistido.
Não alterar atalhos, assets ou o submódulo.
**Troca de ferramenta/camada com arraste ainda ativo**:
`Bridge.mousemoved` e `Bridge.mousereleased` verificam
`stroke_context_valid` e `gesture_context_valid` antes
de continuar pintura ou finalizar transformações/seleções.
Uma pincelada usa a ferramenta, camada, máscara e Alpha Lock
do mousepress; se a ferramenta ou camada ativa for trocada,
a camada ficar oculta/bloqueada, Alpha Lock mudar ou a
referência da máscara mudar, cancelar o restante do gesto.
Manter os pixels já pintados e seu undo único, sem criar
novas escritas após a troca. Uma prévia de movimento/giro/
escala desatualizada não pode virar commit; retângulo e laço
inacabados restauram a seleção prévia. Testar mousemove e
mouseup, duas camadas, máscara, PNG e undo/redo, sem UI nova.
**Um novo clique interrompe o gesto antigo**:
`Bridge.mousepressed` invoca `interrupt_active_gesture()`
APÓS validar que a ferramenta e o clique no canvas são válidos,
mas ANTES de executar a nova ação. Evita pinceladas e seleções
simultâneas com mouseup perdido ou presses consecutivos.
A tinta já aplicada mantém o histórico único; retângulo/laço
ainda não confirmado restaura a máscara prévia, sem gerar
um passo de seleção; preview de movimento/transformação é
liberada sem commit. Um segundo press de pincel é um gesto
independente e não cria linha conectando os centros. Não
cancelar o gesto por clique rejeitado fora do canvas ou
ferramenta desconhecida. Testar todos esses casos em eventos
reais, incluindo máscara, PNG, undo/redo e reabertura.
Não modificar o submódulo Ibis-Lua.
**Undo/Redo sem gestos pendentes**:
`Bridge.undo/redo` e `Bridge.selection_undo/redo` chamam
`interrupt_active_gesture()` antes de navegar nas pilhas,
mesmo quando o histórico está vazio. Uma pincelada iniciada
é encerrada sem descartar seu snapshot válido, para que
Ctrl+Z desfaça a pincelada inteira e eventos posteriores de
mouse não repintem o raster. Um retângulo ou laço inacabado
restitui a máscara original `before_selection_ref` (o
modo replace esconde a máscara só temporariamente), sem novo
histórico. Prévia GPU de mover/transformar é liberada sem
commit. Undo/Redo de máscaras são independentes do raster.
Testar também redo no-op, pilha vazia, mouseup atrasado,
atalhos Ctrl+Alt+Z/Y, PNG e histórico persistido.
Não alterar a interface Ibis-Lua.
**Começar pincelada fora da máscara ativa**:
Não descartar `Bridge.mousepressed` com pincel/borracha quando
o centro inicial está fora de `Selection.contains`. A máscara
se aplica a **cada pixel** em `Engine.stroke` por
`Selection.coverage`, permitindo arrastar de fora para dentro
ou tocar a seleção com a borda de um pincel largo. Nenhuma
edição pode ocorrer fora da máscara. Um gesto totalmente fora
é no-op, não cria histórico nem descarta redo. O Balde mantém
a semente obrigatoriamente dentro da máscara; seleções e
conta-gotas conservam suas próprias regras. Não iniciar o
pincel fora do canvas. Testar pintando, apagando, raios largos,
undo/redo e PNG após reabrir. Não modificar Ibis-Lua.
**Opacidade uniforme do pincel e da borracha por gesto**:
`Engine.stroke(..., on_first_change, covered_pixels)` aceita uma
tabela opcional esparsa de pixels já modificados. Quando a ponte
pinta com opacidade menor que 100% ou seleção com cobertura suave,
`drawing.covered_pixels` persiste entre mousepress, mousemoved
e mousereleased. A mesma pincelada modifica um pixel uma só vez,
sem aumentar alfa por sobreposições de dabs interpolados e sem
depender da fragmentação dos eventos de mouse. Uma nova
pincelada começa com mapa vazio e pode acumular cor/opacidade.
Alpha Lock, feather, borracha, no-op, histórico tardio, um
snapshot por gesto, bordas e composição source-over permanecem
funcionais. Chamadas do motor sem argumento adicional preservam
o comportamento antigo por dab. Não gravar mapa no arquivo;
descartar ao fim do gesto. Cobrir equivalência com segmentos
longos/curtos, histórico, PNG, Alpha Lock e máscaras feather.
Não alterar Ibis-Lua.
**Segmento final no mouseup do pincel/borracha**:
`Bridge.mousereleased(model,rx,ry,scale)` deve processar as
coordenadas finais do gesto, mesmo quando estão fora do canvas,
e pintar apenas o trecho interno antes de descartar `drawing`.
Pincel/borracha armazenam `drawing.raw_x/raw_y` fora da obra.
`canvas_point(..., true)` é permitido somente para o percurso da
tinta, não nos cliques, conta-gotas nem seleções. Recortar cada
segmento em `clip_stroke_segment` (Liang–Barsky), recortando
os **centros do pincel** ao retângulo dos centros de pixels
expandido pelo raio efetivo de `Engine.stroke`
(`max(0.75, min(256, d.size)/2)`). Pincéis e borrachas largos
devem atingir a borda mesmo quando o centro já está fora;
`dab` nunca escreve fora do raster. Não gerar diagonal artificial
quando o cursor retorna à obra após percorrer área externa.
Atualizar a posição bruta também para segmentos 100% externos.
Preservar rotação, Alpha Lock, máscara e um snapshot por gesto.
Movimentos e releases repetidos na mesma posição (diferença menor
ou igual a 0,005 pixel) não podem reaplicar dabs nem acumular
opacidade. Reutilizar a mesma função auxiliar `continue_stroke`
para `mousemoved` e `mousereleased`, chamando `paint` e o
snapshot tardio no máximo uma vez por gesto. Respeitar seleção
ativa, limite do canvas, modelo do projeto, Alpha Lock, borracha,
camada ativa e undo/redo persistido. Sem coordenadas finais,
`mousereleased()` legado apenas encerra a pincelada.
Os gestos de seleção/transformação conservam o próprio release.
Não alterar UI. Testar eventos reais da ponte, RGBA e PNG.
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
A Varinha Mágica tem **tolerância RGBA por obra** de 0 a 255, em
unidades de canal 8-bit: `Selection.magic_wand(layer,w,h,x,y,tolerance)`.
A comparação é por distância absoluta INDEPENDENTE em R/G/B/A à
cor do seed, com margem 1/510 para quantização. Somente conexões
ortogonais de quatro vizinhos; nunca espalhar por ilhas desconectadas.
Sem argumento, tolerância 0 reproduz seleções antigas. **Ctrl+Alt+Right**
aumenta em 16; **Ctrl+Alt+Left** reduz em 16; **Ctrl+Alt+0** zera.
Faixa sempre 0..255 e mostrar `notice` existente. Preferência não cria
undo/redo nem dirty raster, mas é persistida por obra na terceira
coluna de `document.tsv`; arquivos legados de 2 colunas ou valor
inválido restauram zero. Preservar combinação Ctrl+Shift/Alt no
clique, seleção PNG e histórico independente. Não criar slider na UI.
Testar 0, 16, 48, 64 e 255, alfa, conectividade, atalhos, reabertura
e rejeição de parâmetros inválidos.
**Modo global por cor** da Varinha é alternado em **Ctrl+Alt+G**:
`Selection.magic_wand(layer,w,h,x,y,tolerance,global_mode)` aceita
opcional booleano (false/nil preserva o flood-fill 4-conexo, true
percorre TODOS os pixels da camada ativa, selecionando inclusive ilhas
e conexões só diagonais). O critério RGBA e a tolerância são idênticos
em ambos; global não altera raster ou outras camadas. A preferência
`project.wand_global` inicia false e é salva na quarta coluna opcional
de `document.tsv` como 0/1. Metadados legados de duas/três colunas e
valores inválidos retornam false. O toggle usa o notice da UI original,
não cria seleção nem undo/redo; somente o clique posterior aplica a
máscara e deve respeitar combinações Ctrl+Shift/Alt, limites e histórico
persistente da seleção. Não adicionar slider/painel ou alterar submódulo.
Testar diferença contígua/global, diagonais, ilhas separadas, alfa,
tolerância RGBA 0/16/48/64/255, modos combinados, persistência e undo.
**Amostragem de todas as camadas visíveis (opcional)**: Ctrl+Alt+T
alterna `project.wand_sample_all` sem alterar máscaras, dirty nem
histórico. Padrão false: pixel RGBA vem da camada ativa, exatamente
como antes. True: `Engine.composite_pixel_source(project,model,true)`
fornece `pixels:getPixel(x,y)` com o mesmo cálculo do conta-gotas para
camadas visíveis, opacidade, modos de mesclagem e clipping. O fundo branco
é RGBA opaco; fundos transparentes mantêm alfa composto. Não gerar textura
composta nem alterar raster/seleção durante amostragem. A seleção resultante
continua editando somente a camada ativa, respeita contígua/global,
tolerância, booleanas e limite 1 Mi. Persistir 0/1 na quinta coluna de
`document.tsv`; arquivos de 2–4 colunas e valores inválidos iniciam
na camada ativa, sem quebrar tolerância/modo global legados. Usar notice
existente e não alterar o submódulo de interface. Testar sobreposição,
ocultas, opacidade, Multiply, clipping, fundo branco/transparente,
combinação independente dos modos, isolamento por obra e undo.
**Conectividade diagonal opcional da Varinha**: Ctrl+Alt+8 alterna
`project.wand_diagonal` entre false (4-vizinhos padrão) e true
(8-vizinhos, incluindo diagonais) no modo contíguo. O argumento
opcional `diagonal_mode` de
`Selection.magic_wand(layer,w,h,x,y,tolerance,global_mode,diagonal_mode)`
é booleano, default false. Preservar o scanline 4-conexo existente
inalterado. O modo global é independente desse argumento e da
conectividade; limites 1 Mi, RGBA por canal, tolerância, combinações,
histórico de máscaras e fonte da cor seguem idênticos. O toggle não
altera seleção ativa, pixels, dirty nem histórico. Persistir como
sexta coluna opcional em `document.tsv` (0/1); legados com 2–5
colunas ou valor inválido usam 4-vizinhos sem alterar as preferências
já gravadas. Não modificar o Ibis-Lua original nem criar UI extra.
Testar pontes em diagonal, bordas, tolerância/alfa, ilhas, modos
global/contíguo, shortcut Ctrl+Alt+8, reabertura e undo.
**Balde de Tinta com tolerância RGBA por obra**:
`Engine.fill(project,id,x,y,rgb,alpha,alpha_lock,selection,tolerance)`
aceita tolerância 0..255 (inteiro opcional, nil=0), por canal RGBA.
O flood-fill mantém conectividade ortogonal e limite 1 Mi px;
0 mantém o comportamento exato. Descobrir região completa dos
pixels originais antes de escrever, marcando visited para nunca
revisitar células já descobertas mesmo que a tinta tenha cor similar.
Aplicar máscara, pesos feather, Alpha Lock, opacidade e registrar no
máximo um snapshot raster, sem histórico nem dirty quando nenhum pixel
muda. A tolerância da varinha NÃO afeta o balde. Preferência própria
`project.bucket_tolerance`: Ctrl+Alt+PageUp +16,
Ctrl+Alt+PageDown −16, Ctrl+Alt+Home 0; clamp 0..255 e notice
existente. Persistir na oitava coluna de `document.tsv`; arquivos
de 2–7 colunas ou valor inválido assumem 0, preservando preferências
da Varinha. Não alterar Ibis-Lua nem adicionar componentes gráficos.
Testar tolerância 0/16/48/64/255, fronteiras, ilhas, Alpha Lock,
seleção e feather, opacidade baixa, loops, no-op/undo e compatibilidade.
**Modo global por cor do Balde**: Ctrl+Alt+B alterna
`project.bucket_global` entre false (padrão 4-conexo)
e true (varredura global RGBA, incluindo ilhas sem conexão).
`Engine.fill(project,id,x,y,rgb,alpha,alpha_lock,selection,tolerance,global_mode)`
aceita último booleano opcional; nil/false preserva exatamente
o algoritmo contíguo. O modo global usa o mesmo critério RGBA/tolerância
e identifica todos os pixels da camada ativa que combinam antes de
qualquer alteração do raster. Respeita a máscara e o Alpha Lock,
alfa fracionário e undo/redo de um único passo; no-op não deve criar
dirty nem histórico. Independente da Varinha e de suas preferências;
não amostra a composição visível, não afeta outras camadas. O toggle
não altera pixels, máscara ou histórico, apenas preferência e notice.
Persistir a flag opcional (0/1) na nona coluna de `document.tsv`,
com modo contíguo para arquivos anteriores 2–8 colunas e valor inválido,
preservando as configurações já armazenadas. Testar ilhas, diagonais,
tolerância, alfa, seleção, Alpha Lock, no-op, atalho, persistência e undo.
Não modificar Ibis-Lua nem introduzir elementos gráficos.
**Comparação RGB-only opcional do Balde**: Ctrl+Alt+M alterna
`project.bucket_rgb_only` false/true por obra. O último argumento
opcional de `Engine.fill(project,id,x,y,rgb,alpha,alpha_lock,selection,tolerance,global_mode,rgb_only)`
aceita nil/false (padrão RGBA) ou true (compara só R/G/B,
ignorando alfa para correspondência de cor). Deve funcionar
nos modos contíguo e global, com tolerância RGBA anterior de 0..255
por canal (alfa desconsiderado no RGB-only); não deve afetar
`wand_rgb_only`, `bucket_global` ou o histórico ao alternar.
Pixels com alfa zero podem conter RGB armazenado e ser selecionados.
Ao pintar, permanecer usando as regras source-over existentes:
a tinta pode mudar o alfa; Alpha Lock bloqueia alfa e pixels vazios.
Persistir a preferência como décima coluna opcional de
`document.tsv`; legados 2–9 colunas ou valor inválido retornam a
RGBA preservando todos os campos anteriores. Sem controles novos,
sem DLL própria. Testar alfas diferentes, global/contíguo,
tolerância, no-op, Undo/Redo, Alpha Lock, seleção, dados inválidos,
atalho Ctrl+Alt+M, reabertura e isolation por obra.
**Conectividade diagonal opcional do Balde**:
Ctrl+Alt+9 alterna `project.bucket_diagonal` entre false
(padrão histórico, somente 4 lados) e true (8 vizinhos, incluindo cantos).
`Engine.fill(project,id,x,y,rgb,alpha,alpha_lock,selection,tolerance,global_mode,rgb_only,diagonal_mode)`
recebe último booleano opcional. Nil/false mantém exatamente o
scanline 4-conexo; true percorre segmentos que se tocam por diagonais,
estendendo a busca uma coluna para cada lado nas linhas acima e abaixo.
A lista de pontos deve estar completa antes de modificar o raster;
o conjunto visited protege contra revisitas, mesmo com tolerância
e opacidade parcial. Modo global ignora diagonal. Preservar máscara,
feather, Alpha Lock, critérios RGBA/RGB-only, tolerância, limite de 1 Mi,
um passo de histórico e no-op sem dirty. É independente de
`wand_diagonal`, da preferência global e da comparação de cores.
Persistir na 11ª coluna opcional de `document.tsv` (0=4, 1=8);
legados 2–10 colunas e flag inválida assumem false, sem perder as
preferências anteriores. Toggle sem alterar pixels ou máscaras.
Cobrir testes de cantos, bordas, global, tolerância, Alpha Lock,
seleções, undo/redo, reabertura e Ctrl+Alt+9. Não alterar UI.
**Amostragem composta opcional do Balde**: Ctrl+Alt+V alterna
`project.bucket_sample_all` entre false (camada ativa, padrão)
e true (composição das camadas visíveis). A ponte deve passar a
`Engine.fill(project,id,x,y,rgb,alpha,alpha_lock,selection,tolerance,global_mode,rgb_only,diagonal_mode,reference)`
a fonte opcional `Engine.composite_pixel_source(project,model,true)`
na forma `{ pixels = objeto_com_getPixel }`. A referência é
usada apenas para **descobrir os pixels correspondentes** pelo
mesmo RGBA/RGB/tolerância; a escrita e o snapshot do histórico
continuam exclusivamente na camada ativa. A composição considera
visibilidade, opacidade, blend, clipping e fundo branco (outros
fundos mantêm transparência). A região deve ser encontrada antes
de qualquer mutação para não contaminar a própria amostragem.
Alpha Lock compara o alfa da camada de DESTINO, e impede pintar
pixels vazios independentemente da cor composta. Preservar
máscara/feather, global/contíguo, 4/8, no-op, limite 1 Mi e
undo/redo. Preferência independente de `wand_sample_all`, salva
na 12ª coluna opcional de `document.tsv` (0/1); arquivos com
2–11 colunas ou flag inválida usam false mantendo os campos
anteriores. Alternar não edita pixels/máscara/histórico. Testar
camadas ocultas e superiores, fundo branco, opacidade, clipping,
comparação RGB, Alpha Lock de destino, Ctrl+Alt+V, persistência
e isolamento por obra. Sem novos controles visuais nem DLL própria.
**Comparação RGB-only opcional da Varinha**: Ctrl+Alt+R alterna
`project.wand_rgb_only`. Com false/nil (padrão) a comparação considera
R/G/B/A com tolerância independente 0..255 em cada canal. Com true,
`Selection.magic_wand(layer,w,h,x,y,tolerance,global_mode,diagonal_mode,rgb_only)`
considera só diferenças em R/G/B; o canal alfa não participa do teste
de semelhança, mas NÃO é alterado no raster. RGB armazenado sob alfa zero
também é comparado: não inventar cor de fundo quando a origem é a camada
ativa. Fonte composta e fundo branco continuam usando sua matemática
existente. A flag é independente de contiguidade 4/8, global, fonte,
tolerância e combinações booleanas. Salvar 0/1 na sétima coluna opcional
de `document.tsv`; arquivos 2–6 colunas ou flag inválida usam false
sem perder as demais preferências. Toggle só altera preferência por
obra, mostra notice e não toca na máscara, dirty, histórico ou pixels.
Testar alfa zero/fracionário, tolerância, global, contiguidade,
composição visível, reabertura, corrupção de flag, undo e RGB salvo.
Não criar novos elementos na interface Ibis-Lua.
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
