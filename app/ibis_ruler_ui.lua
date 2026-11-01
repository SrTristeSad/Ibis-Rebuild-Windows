-- Catalogo visual de reguas: sem modificar pinceladas ou camadas.
-- Os oito tipos foram documentados nos tutoriais publicos ibisPaint
-- 74-81. Nao se declara geometria 1:1 do Android 14.1.2.
local M={}
M.types={
    {id='straight',name='Reta',symbol='straight'},
    {id='circle',name='Circular',symbol='circle'},
    {id='ellipse',name='Eliptica',symbol='ellipse'},
    {id='radial',name='Radial',symbol='radial'},
    {id='mirror',name='Espelho',symbol='mirror'},
    {id='kaleidoscope',name='Caleidoscopio',symbol='kaleidoscope'},
    {id='array',name='Matriz',symbol='array'},
    {id='perspective-array',name='Matriz em perspectiva',symbol='perspective'}
}
local byId={}
for _,item in ipairs(M.types) do
    assert(not byId[item.id],'Regua duplicada')
    byId[item.id]=item
end
function M.get(id) return byId[id] end
function M.canApply(id)
    return false -- Nenhum guia altera trajetoria de pincel nessa fase.
end
function M.new()
    return {previewId=nil}
end
function M.select(state,id)
    assert(type(state)=='table','Estado de regua invalido')
    if id==nil then
        state.previewId=nil
        return nil
    end
    local item=assert(M.get(id),'Tipo de regua desconhecido')
    state.previewId=item.id
    return item
end
local function checkPanel(p)
    assert(type(p)=='table' and type(p.x)=='number'
        and type(p.y)=='number' and p.w>=390 and p.h>=402,
        'Painel de reguas invalido')
end
function M.cell(p,index)
    checkPanel(p)
    assert(type(index)=='number' and index%1==0
        and index>=1 and index<=#M.types,
        'Indice de regua invalido')
    local col=(index-1)%2
    local row=math.floor((index-1)/2)
    return {x=p.x+12+col*185,y=p.y+57+row*65,w=173,h=57}
end
function M.clear(p)
    checkPanel(p)
    return {x=p.x+12,y=p.y+327,w=119,h=31}
end
function M.caption(p)
    checkPanel(p)
    return {x=p.x+142,y=p.y+330,w=p.w-154,h=26}
end
-- Miniaturas originais em coordenadas locais (-8..8) para
-- desenhar pela API vetor do LÖVE. Nao sao assets do APK.
M.symbols={
    straight={{op='line',a={-7,5,7,-5}}},
    circle={{op='circle',a={0,0,6}}},
    ellipse={{op='ellipse',a={0,0,7,4}}},
    radial={{op='line',a={-7,0,7,0}},
        {op='line',a={0,-7,0,7}},
        {op='line',a={-5,-5,5,5}},
        {op='line',a={-5,5,5,-5}}},
    mirror={{op='line',a={0,-7,0,7}},
        {op='line',a={-6,5,-3,-4,0,2}},
        {op='line',a={6,5,3,-4,0,2}}},
    kaleidoscope={{op='line',a={-7,0,7,0}},
        {op='line',a={0,-7,0,7}},
        {op='line',a={-5,-5,5,5}},
        {op='line',a={-5,5,5,-5}},
        {op='circle',a={0,0,3}}},
    array={{op='rectangle',a={-7,-7,6,6}},
        {op='rectangle',a={1,-7,6,6}},
        {op='rectangle',a={-7,1,6,6}},
        {op='rectangle',a={1,1,6,6}}},
    perspective={{op='line',a={-7,-6,7,-6}},
        {op='line',a={-7,6,7,6}},
        {op='line',a={-7,-6,0,6,7,-6}},
        {op='line',a={-3,-6,0,6,3,-6}}}
}
function M.symbol(id)
    local item=M.get(id)
    return item and M.symbols[item.symbol] or nil
end
return M
