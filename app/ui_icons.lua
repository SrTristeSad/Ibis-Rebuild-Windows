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
