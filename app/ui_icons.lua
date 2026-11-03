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
    brush={
        {op='line',points={-5.7,5.9,-3.2,2.8,2.7,-3.1,5.8,-6.1}},
        {op='circle',mode='fill',x=-5.5,y=5.6,r=2.1},
        {op='line',points={-3.2,2.8,0.1,4.1,4.0,0.1}}},
    erase={
        {op='polygon',mode='line',points={-6,2,-1,-5,6,0,1,6,-3,6}},
        {op='line',points={-3,6,5,6}}},
    fill={
        {op='polygon',mode='line',points={-5,-2,0,-6,5,-1,0,4}},
        {op='line',points={-7,4,3,4}},
        {op='circle',mode='fill',x=5.5,y=5.3,r=1.8}},
    select={
        {op='line',points={-6,-3,-6,-6,-3,-6}},
        {op='line',points={1,-6,5,-6,5,-3}},
        {op='line',points={5,1,5,5,1,5}},
        {op='line',points={-3,5,-6,5,-6,1}}},
    shape={
        {op='rectangle',mode='line',x=-6,y=-5,w=8,h=8},
        {op='circle',mode='line',x=3.5,y=2.5,r=3.5}},
    picker={
        {op='line',points={-5,5,2,-2,4,0,6,-2,2,-6,0,-4}},
        {op='line',points={-5,5,-6,6}},
        {op='circle',mode='line',x=-3,y=3,r=1.8}}
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
glyphs.color={
    {op='circle',mode='line',x=0,y=0,r=6.3},
    {op='circle',mode='fill',x=2.8,y=-2.6,r=1.8},
    {op='circle',mode='fill',x=-2.5,y=0.2,r=1.3},
    {op='circle',mode='fill',x=.2,y=3.1,r=1.3}
}
glyphs.fullscreen={
    {op='line',points={-6,-2,-6,-6,-2,-6}},
    {op='line',points={2,-6,6,-6,6,-2}},
    {op='line',points={6,2,6,6,2,6}},
    {op='line',points={-2,6,-6,6,-6,2}}
}
glyphs.layers={
    {op='rectangle',mode='line',x=-5.5,y=-6.4,w=8.4,h=8.4},
    {op='rectangle',mode='line',x=-2.7,y=-2.5,w=8.4,h=8.4},
    {op='rectangle',mode='fill',x=3.7,y=-5.6,w=2,h=2}
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
