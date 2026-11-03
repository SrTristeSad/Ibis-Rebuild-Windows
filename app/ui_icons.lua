-- Small vector glyphs for the eight editor tools. No external images/fonts.
-- Descriptions are pure Lua so the headless suite can validate completeness.
local Icons={}
local glyphs={
    inspect={
        {op='circle',mode='line',x=-1.5,y=-1.5,r=4.1},
        {op='line',points={1.5,1.5,6.4,6.4}}},
    pixel={
        {op='rectangle',mode='fill',x=-4.2,y=-4.2,w=8.4,h=8.4},
        {op='rectangle',mode='fill',x=4.9,y=-5.5,w=2,h=2},
        {op='rectangle',mode='fill',x=-6.6,y=4.4,w=2,h=2}},
    -- A47: silhuetas inspiradas nas ferramentas PC observadas na
    -- Microsoft Store. Vetores próprios; sem copiar sprites oficiais.
    brush={
        -- Pincel inclinado: corpo, virola e ponta com cerdas.
        {op='polygon',mode='fill',
            points={1.8,-5.6,3.6,-7,6.2,-4.5,4.4,-2.9,
                -1.1,2.4,-3.1,.3}},
        {op='line',points={-2.0,1.6,.1,3.5}},
        {op='polygon',mode='fill',
            points={-2.7,1.2,-.2,3.3,-2.2,5.5,-5.7,6.4,
                -5.0,3.2}},
        {op='line',points={-6.2,6.6,-3.6,6.6}}},
    erase={
        -- Bloco de borracha diagonal preenchido, nao seta/losango.
        {op='polygon',mode='fill',
            points={-6.2,1.6,-1.9,-5.8,5.4,-1.6,1.2,5.6,
                -4.0,5.6}},
        {op='line',points={-4.5,6.5,5.8,6.5}}},
    fill={
        -- Lata de tinta virada e gota separada.
        {op='polygon',mode='line',
            points={-5.3,-2.1,.4,-6.2,5.8,-.7,.2,4.9,-5.4,-.4}},
        {op='line',points={-6.4,-3.0,-4.8,-4.4,-3.5,-4.5}},
        {op='line',points={-6.2,5.6,2.0,5.6}},
        {op='polygon',mode='fill',
            points={4.2,3.4,5.5,1.1,6.9,3.6,5.4,5.6}}},
    select={
        {op='line',points={-6,-3,-6,-6,-3,-6}},
        {op='line',points={1,-6,5,-6,5,-3}},
        {op='line',points={5,1,5,5,1,5}},
        {op='line',points={-3,5,-6,5,-6,1}}},
    shape={
        {op='rectangle',mode='line',x=-6,y=-5,w=8,h=8},
        {op='circle',mode='line',x=3.5,y=2.5,r=3.5}},
    -- A49: adaptado do Tabler Icons "color-picker" (MIT, Pawel Kuna).
    -- SVG original: tabler/tabler-icons/icons/outline/color-picker.svg
    -- A silhueta da pipeta e mantida em coordenadas Lua normalizadas.
    picker={
        {op='line',points={-.7,-3.5,3.5,.7}},
        {op='line',points={-5.6,2.8,2.59,-5.39,3.57,-5.39,
            5.39,-3.57,5.39,-2.59,-2.8,5.6,-5.6,5.6,-5.6,2.8}}}
}
-- Compact action bar glyphs. Pure vectors inspired by functional
-- categories in the official toolbar, not copied Android assets.
glyphs.tools={
    {op='rectangle',mode='line',x=-6.4,y=-6.4,w=5.3,h=5.3},
    {op='rectangle',mode='line',x=1.2,y=-6.4,w=5.3,h=5.3},
    {op='rectangle',mode='line',x=-6.4,y=1.2,w=5.3,h=5.3},
    {op='rectangle',mode='line',x=1.2,y=1.2,w=5.3,h=5.3}
}
glyphs.properties={
    {op='line',points={-6.4,-4.5,6.4,-4.5}},
    {op='line',points={-6.4,0,6.4,0}},
    {op='line',points={-6.4,4.5,6.4,4.5}},
    {op='circle',mode='fill',x=-1.7,y=-4.5,r=1.8},
    {op='circle',mode='fill',x=3.1,y=0,r=1.8},
    {op='circle',mode='fill',x=-2.5,y=4.5,r=1.8}
}
-- A50: representacao estatica do indicador de cor; no editor,
-- Icons.drawColorSwatch colore o disco com a selecao RGBA atual.
glyphs.color={
    {op='circle',mode='line',x=0,y=0,r=6.8},
    {op='circle',mode='fill',x=0,y=0,r=5.2}
}
-- A51: a barra Windows mostra uma seta para baixo no controle
-- Tela/visualizacao. Adaptacao do Tabler "arrow-down" (licenca MIT);
-- somente silhueta, sem alterar a acao de foco nem o hit-test.
-- Fonte: tabler/tabler-icons/icons/outline/arrow-down.svg
glyphs.fullscreen={
    {op='line',points={0,-6.2,0,6.2}},
    {op='line',points={-5.2,.9,0,6.2,5.2,.9}}
}
glyphs.layers={
    -- A48: tres folhas deslocadas para baixo/direita, como na
    -- referencia promocional Windows IMG-M04. A folha frontal e
    -- preenchida; os dois contornos traseiros ficam abertos sob ela.
    {op='line',points={6.4,-2.5,6.4,6.4,-2.5,6.4}},
    {op='line',points={4.2,-4.7,4.2,4.2,-4.7,4.2}},
    {op='rectangle',mode='fill',x=-6.4,y=-6.4,w=8.5,h=8.5}
}
glyphs.back={
    {op='line',points={-5,-.5,4.7,-.5}},
    {op='line',points={-5,-.5,.1,-5.5}},
    {op='line',points={-5,-.5,.1,4.5}}
}
-- Desktop/compact chrome glyphs rendered as vectors instead of missing
-- Windows default-font Unicode symbols (which showed empty squares).
glyphs.undo={
    {op='line',points={-6,-4,1,-4,4,-2,5,1,3.5,4}},
    {op='line',points={-6,-4,-2,-7}},
    {op='line',points={-6,-4,-1,0}}
}
glyphs.redo={
    {op='line',points={6,-4,-1,-4,-4,-2,-5,1,-3.5,4}},
    {op='line',points={6,-4,2,-7}},
    {op='line',points={6,-4,1,0}}
}
glyphs['rotate-left']={
    {op='line',points={-5,-2,-5,-5,-2,-5}},
    {op='line',points={-5,-5,0,-6,5,-3,6,1,3,5,-2,5}}
}
glyphs['rotate-right']={
    {op='line',points={5,-2,5,-5,2,-5}},
    {op='line',points={5,-5,0,-6,-5,-3,-6,1,-3,5,2,5}}
}
glyphs.visible={
    {op='polygon',mode='line',points={-7,0,-4,-3,0,-4,4,-3,7,0,4,3,0,4,-4,3}},
    {op='circle',mode='fill',x=0,y=0,r=2}
}
glyphs.hidden={
    {op='polygon',mode='line',points={-7,0,-4,-3,0,-4,4,-3,7,0,4,3,0,4,-4,3}},
    {op='line',points={-6,6,6,-6}}
}
glyphs.up={
    {op='polygon',mode='fill',points={-5,3,5,3,0,-4}},
    {op='line',points={-5,5,5,5}}
}
glyphs.down={
    {op='polygon',mode='fill',points={-5,-3,5,-3,0,4}},
    {op='line',points={-5,-5,5,-5}}
}
-- Icones vetoriais originais para categorias ainda sem motor Lua.
-- O nome representa a funcao na UI, nao implica suporte funcional.
-- Mover/Transformar: cruz de quatro setas, desenhada em vetores
-- independentes; nao reutilizar a caixa de selecao.
glyphs.transform={
    {op='line',points={0,-5.5,0,5.5}},
    {op='line',points={-5.5,0,5.5,0}},
    {op='line',points={-2.7,-3,0,-6.5,2.7,-3}},
    {op='line',points={-2.7,3,0,6.5,2.7,3}},
    {op='line',points={-3,-2.7,-6.5,0,-3,2.7}},
    {op='line',points={3,-2.7,6.5,0,3,2.7}},
    {op='circle',mode='fill',x=0,y=0,r=1.25}
}
-- A46: tres silhuetas do seletor Windows observadas na imagem
-- promocional oficial Microsoft Store: estrela/varinha, laco com
-- cordao e FX num circulo. Redesenho independente em vetores Lua;
-- nao sao sprites nem medidas extraidas do aplicativo original.
glyphs.magic={
    -- Cabo diagonal e estrela principal de oito pontas.
    {op='line',points={-6,6,.2,-.2}},
    {op='line',points={2,-7,2,-1}},
    {op='line',points={-1,-4,5,-4}},
    {op='line',points={.2,-5.8,3.8,-2.2}},
    {op='line',points={.2,-2.2,3.8,-5.8}},
    {op='circle',mode='fill',x=-4,y=-4.8,r=.65},
    {op='line',points={4.6,2.7,6.5,2.7}},
    {op='line',points={5.55,1.75,5.55,3.65}}}
glyphs.lasso={
    -- Volta do laco irregular e cauda: evita parecer lupa.
    {op='line',points={-5.4,-1.2,-4.6,-3.6,-2.2,-5.2,
        1.0,-5.4,3.9,-3.8,5.4,-1.4,4.8,.8,
        2.5,2.6,-.8,2.7,-3.8,1.5,-5.4,-1.2}},
    {op='line',points={-.8,2.7,.2,4.3,-1.9,6,-4.2,5.1}},
    {op='circle',mode='fill',x=-4.2,y=5.1,r=1.0}}
glyphs.filter={
    -- Letra FX em circunferencia como no seletor PC.
    {op='circle',mode='line',x=0,y=0,r=6.3},
    -- F, alinhado a esquerda.
    {op='line',points={-4.4,3.4,-4.4,-3.3,-.9,-3.3}},
    {op='line',points={-4.4,-.2,-1.2,-.2}},
    -- X, alinhado a direita.
    {op='line',points={.4,-3.3,4.5,3.4}},
    {op='line',points={4.5,-3.3,.4,3.4}}}
glyphs.smudge={
    {op='line',points={-6,4,-3,-2,0,-3,2,-1,5,-5}},
    {op='line',points={-5,6,-1,2,2,3,5,0}},
    {op='circle',mode='fill',x=5,y=-5,r=1.5}}
glyphs.blur={
    {op='circle',mode='line',x=0,y=0,r=2.5},
    {op='circle',mode='line',x=0,y=0,r=5.4},
    {op='circle',mode='fill',x=0,y=0,r=1.1}}
glyphs.special={
    {op='line',points={-5,5,4,-4}},
    {op='circle',mode='fill',x=-5,y=5,r=2},
    {op='line',points={3,-6,3,-3}},
    {op='line',points={1,-5,5,-5}}}
glyphs.vector={
    {op='circle',mode='line',x=-5,y=5,r=1.8},
    {op='circle',mode='line',x=0,y=-4,r=1.8},
    {op='circle',mode='line',x=5,y=4,r=1.8},
    {op='line',points={-4,3,-1,-2,3,2}}}
glyphs['text-tool']={
    {op='line',points={-5,-5,5,-5}},
    {op='line',points={0,-5,0,6}},
    {op='line',points={-3,6,3,6}}}
glyphs['frame-divider']={
    {op='rectangle',mode='line',x=-6,y=-6,w=12,h=12},
    {op='line',points={0,-6,0,6}},
    {op='line',points={-6,0,0,0}}}
glyphs['canvas-tool']={
    {op='rectangle',mode='line',x=-6,y=-5,w=12,h=10},
    {op='line',points={-3,2,0,-2,3,2}},
    {op='circle',mode='fill',x=3,y=-2,r=1.2}}
-- Acoes do canto superior direito, desenhadas em Lua sem assets alheios.
glyphs['top-view']={
    {op='line',points={-6,-3,-2,-3,-2,-6}},
    {op='line',points={2,-6,2,-3,6,-3}},
    {op='line',points={6,2,6,5,2,5}},
    {op='line',points={-2,5,-6,5,-6,2}},
    {op='circle',mode='line',x=0,y=0,r=2.1}}
glyphs['top-selection']={
    {op='line',points={-6,-3,-6,-6,-3,-6}},
    {op='line',points={1,-6,6,-6,6,-2}},
    {op='line',points={6,2,6,6,2,6}},
    {op='line',points={-2,6,-6,6,-6,2}},
    {op='circle',mode='line',x=0,y=0,r=2.6}}
glyphs['top-stabilizer']={
    {op='line',points={-6,4,-3,-3,-1,0,2,-4,5,3}},
    {op='line',points={-6,6,6,6}},
    {op='circle',mode='fill',x=5,y=3,r=1.7}}
glyphs['top-shape']={
    {op='rectangle',mode='line',x=-6,y=-5,w=7.5,h=8},
    {op='circle',mode='line',x=3,y=2.5,r=3.5}}
glyphs['top-ruler']={
    {op='rectangle',mode='line',x=-6.4,y=-2,w=12.8,h=4},
    {op='line',points={-4,-2,-4,1}},
    {op='line',points={-.5,-2,-.5,0}},
    {op='line',points={3,-2,3,1}}}
glyphs['top-material']={
    {op='rectangle',mode='line',x=-5.5,y=-5.5,w=11,h=11},
    {op='circle',mode='fill',x=2.5,y=-2.5,r=1.4},
    {op='line',points={-4,3,-1,-1,1,1,3,-1,5,3}}}

-- Galeria ampliada: geometria vetorial para evitar caracteres
-- ausentes nas fontes do Windows/LÖVE. Sem assets externos.
glyphs['gallery-add']={
    {op='line',points={-6,0,6,0}},
    {op='line',points={0,-6,0,6}}}
glyphs['gallery-info']={
    {op='circle',mode='line',x=0,y=0,r=6.2},
    {op='circle',mode='fill',x=0,y=-3.5,r=.9},
    {op='line',points={0,-.5,0,4}}}
glyphs['gallery-play']={
    {op='polygon',mode='fill',points={-4.3,-6,5.8,0,-4.3,6}}}
glyphs['gallery-share']={
    {op='rectangle',mode='line',x=-5.6,y=-1.7,w=11.2,h=7.6},
    {op='line',points={0,2,0,-7}},
    {op='line',points={-3,-4,0,-7,3,-4}}}
glyphs['gallery-more']={
    {op='circle',mode='fill',x=-5,y=0,r=1.5},
    {op='circle',mode='fill',x=0,y=0,r=1.5},
    {op='circle',mode='fill',x=5,y=0,r=1.5}}

-- Setas discretas exibidas somente ao aproximar o ponteiro.
glyphs['gallery-prev']={
    {op='line',points={3.6,-6,-3.6,0,3.6,6}}}
glyphs['gallery-next']={
    {op='line',points={-3.6,-6,3.6,0,-3.6,6}}}
function Icons.commands(id)
    return glyphs[id]
end
-- A50: o controle de cor do Windows e um disco com amostra viva,
-- nao uma paleta de tres pontos ou pequenos quadrados redundantes.
-- As cores RGB sao normalizadas [0,1]; o alfa do pincel fica no slider.
function Icons.colorSwatchGeometry(cx,cy,size)
    assert(type(cx)=='number' and cx==cx and
        type(cy)=='number' and cy==cy and
        type(size)=='number' and size>0 and size==size,
        'Geometria do indicador de cor invalida')
    return {cx=cx,cy=cy,fillRadius=size*.35,
        ringRadius=size*.44}
end
function Icons.drawColorSwatch(cx,cy,size,r,g,b)
    for _,value in ipairs({r,g,b}) do
        assert(type(value)=='number' and value==value and
            value>=0 and value<=1, 'Canal de cor invalido')
    end
    local gapi=assert(love and love.graphics,
        'Renderizacao LOVE obrigatoria')
    local geom=Icons.colorSwatchGeometry(cx,cy,size)
    gapi.push('all')
    gapi.setColor(r,g,b,1)
    gapi.circle('fill',geom.cx,geom.cy,geom.fillRadius,32)
    gapi.setColor(.85,.85,.85,1)
    gapi.setLineWidth(1.4)
    gapi.circle('line',geom.cx,geom.cy,geom.ringRadius,32)
    gapi.pop()
end
-- A53: para Pincel/Borracha, a area Propriedades da barra do
-- ibisPaint mostra o tamanho atual num disco. A nossa UI so possui
-- diametros inteiros (1..256); outros modos mantem glyphs.properties.
function Icons.brushSizeLabel(diameter)
    assert(type(diameter)=='number' and diameter==diameter and
        diameter%1==0 and diameter>=1 and diameter<=256,
        'Diametro do pincel fora dos limites do motor Lua')
    return tostring(diameter)
end
function Icons.drawBrushSizeBadge(cx,cy,size,diameter,font)
    assert(type(cx)=='number' and cx==cx and
        type(cy)=='number' and cy==cy and
        type(size)=='number' and size>0 and size==size,
        'Indicador de tamanho invalido')
    local label=Icons.brushSizeLabel(diameter)
    local g=assert(love and love.graphics,
        'Renderizacao LOVE obrigatoria')
    assert(font and type(font.getHeight)=='function' and
        type(font.getWidth)=='function','Fonte de tamanho ausente')
    g.push('all')
    g.setColor(.075,.075,.075,1)
    g.circle('fill',cx,cy,size*.46,32)
    g.setColor(.85,.85,.85,1)
    g.setLineWidth(1.1)
    g.circle('line',cx,cy,size*.46,32)
    g.setFont(font)
    -- Caber ate tres algarismos sem aumentar a hitbox do botao.
    local textWidth=font:getWidth(label)
    local fit=math.min(1,(size*.83)/math.max(1,textWidth))
    g.push()
    g.translate(cx,cy)
    g.scale(fit,fit)
    g.print(label,-textWidth/2,-font:getHeight()/2)
    g.pop()
    g.pop()
end
-- A52: a funcao principal do editor ja atingiu o limite de
-- upvalues no LuaJIT. Delegar a escolha do icone ao proprio modulo
-- de renderizacao evita capturar o catalogo dentro de drawEditor.
local visualTools
-- A54: disco do seletor com a ferramenta em escala menor e uma
-- pequena marca de menu. Isso distingue o segundo botao do alternador
-- Pincel/Borracha sem alterar o ID nem os callbacks da barra.
function Icons.toolSelectorGeometry(cx,cy,size)
    assert(type(cx)=='number' and cx==cx and
        type(cy)=='number' and cy==cy and
        type(size)=='number' and size>0 and size==size,
        'Geometria do seletor invalida')
    return {cx=cx,cy=cy,radius=size*.49,
        iconSize=size*.65,caret={
            cx+size*.22,cy+size*.22,
            cx+size*.42,cy+size*.22,
            cx+size*.32,cy+size*.34}}
end
function Icons.drawToolSelector(activeTool,pendingId,cx,cy,size)
    visualTools=visualTools or require('ibis_visual_tools')
    local id=visualTools.toolbarIcon(activeTool,pendingId)
    local g=assert(love and love.graphics,
        'Renderizacao LOVE obrigatoria')
    local frame=Icons.toolSelectorGeometry(cx,cy,size)
    g.push('all')
    g.setColor(.07,.07,.07,1)
    g.circle('fill',cx,cy,frame.radius,32)
    g.setColor(.80,.80,.80,1)
    g.setLineWidth(1)
    g.circle('line',cx,cy,frame.radius,32)
    g.setColor(.95,.95,.95,1)
    Icons.draw(id,cx,cy,frame.iconSize)
    g.polygon('fill',unpack(frame.caret))
    g.pop()
end
function Icons.draw(id,cx,cy,size)
    local shapes=assert(glyphs[id],'Ícone de ferramenta desconhecido')
    local g=assert(love and love.graphics,'Renderização LÖVE obrigatória')
    g.push('all')
    g.translate(cx,cy)
    g.scale(size/16)
    g.setLineWidth(1.65)
    g.setLineJoin('bevel')
    for _,command in ipairs(shapes) do
        if command.op=='line' then
            g.line(unpack(command.points))
        elseif command.op=='rectangle' then
            g.rectangle(command.mode,command.x,command.y,command.w,command.h,1,1)
        elseif command.op=='circle' then
            g.circle(command.mode,command.x,command.y,command.r,18)
        elseif command.op=='polygon' then
            g.polygon(command.mode,unpack(command.points))
        end
    end
    g.pop()
end
return Icons
