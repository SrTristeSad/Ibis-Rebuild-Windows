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
Copiar/Recortar/Colar são internos à aplicação (Ctrl+C, Ctrl+X, Ctrl+V);
colagens preservam RGBA e não criam nova camada. Rotação ortogonal
(Ctrl+Shift+R, Ctrl+Shift+L) e escala nearest-neighbour 200%/50%
(Ctrl+Shift+Up/Down) estão integradas sem novos componentes visuais.
No instrumento Transformar, **Alt+arrastar dentro da seleção** ativa
rotação contínua pelo ângulo relativo ao centro da máscara; **Shift+
arrastar dentro da seleção** ativa escala independente X/Y pelo
deslocamento do ponteiro. A função `Engine.affine_selection` aceita filtro opcional: por padrão
usa nearest-neighbour (compatibilidade), e os gestos Alt/Shift fornecem
"bilinear". O processamento bilinear amostra RGB pré-multiplicado e
trata pixels não selecionados como transparentes para impedir halos.
`Engine.preview_affine` produz um buffer temporário e `Bridge.draw`
exibe este buffer com composição das camadas e máscara de prévia,
sem mudar pixels, dirty ou pilhas de undo/redo. O buffer é descartado
na liberação/cancelamento do gesto. Prévia e commit precisam usar a
mesma matemática e verificar o retângulo de destino previamente.
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
binária independente das camadas. Reabertura valida assinatura PNG,
dimensões e limite de bytes; arquivo ausente ou inválido não deve impedir
a abertura de desenhos antigos. Ctrl+D/Esc seguido de salvamento remove
a máscara antiga. O clipboard interno não é persistido.
A seleção tem limite de 1.048.576 pixels, com contorno
visual limitado a 10.000 segmentos. Não criar botões nem painéis novos.
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
independentes. Rotação ortogonal, escala 50%/200% e copiar/colar de pixels da camada ativa
possuem implementação Lua; preserve os testes de giro, amostragem,
limites do canvas, source-over e histórico com contorno.
A seleção é persistente como máscara por obra; o histórico dos passos de
edição raster e da geometria associada também é salvo para obras pequenas.
A rotação contínua e a escala independente estão implementadas por
gestos modificados; teste o motor e a ponte em LÖVE e preserve o
arraste comum de deslocamento. A prévia bilinear em tempo real está implementada apenas para Alt/Shift
com a ferramenta Transformar; não declare prévia do movimento comum,
interpolação bicúbica, transformação vetorial nem clipboard Windows
como concluídos. Testes incluem prévia sem mutação, paridade de pixels
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
