-- Nova tela: estrutura inferida da captura publica oficial do tutorial
-- 02. Nao e screenshot verificado em Android 14.1.2.
-- Geometria, formatos e disponibilidade sao independentes do Store.
local G={}
G.MAX=2048
G.ITEMS={
    {id='sd',name='SD (Velocidade)',w=621,h=1344},
    {id='square-sd',name='1:1 (SD)',w=1280,h=1280},
    {id='portrait-sd',name='3:4 (SD)',w=768,h=1024},
    {id='story-sd',name='9:16 (SD)',w=720,h=1280},
    {id='x-header',name='X Header',w=1500,h=500},
    {id='chat-stamp',name='Chat Stamp',w=370,h=320},
    {id='vertical',name='Vertical',w=690,h=4096},
    {id='printing',kind='heading',name='Para impressão'},
    {id='postcard',name='Postcard (JP)',w=1181,h=1748},
    {id='a4',name='A4',w=1240,h=1754},
    {id='legacy',kind='heading',name='Compatibilidade Windows'},
    {id='legacy-square',name='Quadrado',w=512,h=512},
    {id='legacy-large',name='1024 × 1024',w=1024,h=1024},
    {id='legacy-landscape',name='Paisagem',w=1920,h=1080},
    {id='legacy-portrait',name='Retrato',w=1080,h=1920}
}
function G.allowed(item)
    return item and item.kind~='heading'
        and type(item.w)=='number' and type(item.h)=='number'
        and item.w>=1 and item.h>=1
        and item.w<=G.MAX and item.h<=G.MAX
end
function G.item(id)
    for _,item in ipairs(G.ITEMS) do
        if item.id==id then return item end
    end
    return nil
end
function G.layout(w,h)
    assert(type(w)=='number' and w>=960
        and type(h)=='number' and h>=640,
        'Janela pequena demais para escolha de tela')
    local pw,ph=442,math.min(744,h-28)
    return {x=math.floor((w-pw)/2),y=math.floor((h-ph)/2),
        w=pw,h=ph}
end
function G.close(r)
    return {x=r.x+r.w-40,y=r.y+3,w=35,h=35}
end
function G.field(r,axis)
    assert(axis==1 or axis==2 or axis==3,'Campo invalido')
    if axis==1 then
        return {x=r.x+78,y=r.y+r.h-72,w=r.w-94,h=28}
    end
    return {x=r.x+r.w-112,
        y=r.y+(axis==2 and 146 or 186),w=92,h=28}
end
function G.stepper(r,axis,direction)
    assert((axis==2 or axis==3)
        and (direction==-1 or direction==1),
        'Eixo ou direcao invalidos')
    return {x=r.x+(direction==-1 and 49 or 288),
        y=r.y+(axis==2 and 146 or 186),w=29,h=28}
end
function G.slider(r,axis)
    assert(axis==2 or axis==3,'Slider invalido')
    return {x=r.x+87,y=r.y+(axis==2 and 150 or 190),
        w=192,h=20}
end
function G.listViewport(r)
    return {x=r.x+9,y=r.y+239,w=r.w-18,
        h=r.h-322}
end
local function itemHeight(item)
    return item.kind=='heading' and 25 or 39
end
function G.listHeight()
    local h=0
    for _,item in ipairs(G.ITEMS) do h=h+itemHeight(item) end
    return h
end
function G.maxScroll(r)
    return math.max(0,G.listHeight()-G.listViewport(r).h)
end
function G.clampScroll(r,offset)
    return math.max(0,math.min(G.maxScroll(r),offset or 0))
end
function G.scroll(r,offset,wheelY)
    return G.clampScroll(r,(offset or 0)-wheelY*44)
end
function G.row(r,id,offset)
    local area=G.listViewport(r)
    local y=area.y-G.clampScroll(r,offset)
    for _,item in ipairs(G.ITEMS) do
        local hh=itemHeight(item)
        if item.id==id then
            local box={x=area.x,y=y,w=area.w,h=hh}
            return box, y>=area.y and y+hh<=area.y+area.h
        end
        y=y+hh
    end
    return nil,false
end
function G.rows(r,offset)
    local area=G.listViewport(r)
    local y=area.y-G.clampScroll(r,offset)
    local result={}
    for _,item in ipairs(G.ITEMS) do
        local hh=itemHeight(item)
        result[#result+1]={item=item,
            x=area.x,y=y,w=area.w,h=hh,
            visible=y>=area.y and y+hh<=area.y+area.h}
        y=y+hh
    end
    return result
end
function G.choose(modal,id)
    assert(modal and modal.kind=='new','Modal de canvas ausente')
    local item=G.item(id)
    if not G.allowed(item) then return false end
    modal.values[2]=tostring(item.w)
    modal.values[3]=tostring(item.h)
    modal.focus=1
    return true
end
return G
