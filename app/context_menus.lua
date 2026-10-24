-- Pure menu descriptions and geometry; no LÖVE or raster dependencies.
-- The caller owns callbacks and must block the canvas while a menu is open.
local Menu={}
Menu.WIDTH=222
Menu.HEADER=35
Menu.ROW=30
function Menu.toolAt(slots,x,y)
    if y<78 or y>=112 then return nil end
    for _,slot in ipairs(slots) do
        if x>=slot.x and x<slot.x+slot.w then return slot.id end
    end
    return nil
end
function Menu.layerAt(x,y,panel,start,stop)
    if x<panel+20 or x>=panel+248 or y<475 then return nil end
    local offset=math.floor((y-475)/37)
    local index=stop-offset
    if offset<0 or index<start or index>stop or (y-475)%37>=33 then
        return nil
    end
    return index
end
function Menu.layerEntries(count,index,maximum,visible)
    assert(type(count)=='number' and count>=1 and count<=maximum and
        index>=1 and index<=count and type(visible)=='boolean',
        'Menu de camadas inválido')
    return {
        {key='rename',label='Renomear camada',enabled=true},
        {key='duplicate',label='Duplicar camada',enabled=count<maximum},
        {key='visibility',label=visible and 'Ocultar camada' or 'Mostrar camada',enabled=true},
        {key='clear',label='Limpar pixels da camada',enabled=true},
        {key='flipH',label='Espelhar horizontal',enabled=true},
        {key='flipV',label='Espelhar vertical',enabled=true},
        {key='merge',label='Mesclar abaixo',enabled=index>1},
        {key='up',label='Mover acima',enabled=index<count},
        {key='down',label='Mover abaixo',enabled=index>1},
        {key='delete',label='Excluir camada',enabled=count>1}
    }
end
function Menu.toolEntries(id,context)
    assert(type(id)=='string' and type(context)=='table','Menu de ferramenta inválido')
    local entries={{key='use',label='Usar ferramenta',enabled=true}}
    local function add(key,label,enabled)
        entries[#entries+1]={key=key,label=label,enabled=enabled~=false}
    end
    if id=='brush' or id=='erase' then
        add('sizeDown','Diminuir tamanho',context.size>1)
        add('sizeUp','Aumentar tamanho',context.size<256)
        add('opacityDown','Diminuir opacidade',context.opacity>.101)
        add('opacityUp','Aumentar opacidade',context.opacity<.999)
    elseif id=='fill' then
        add('toleranceDown','Menos tolerância',context.tolerance>0)
        add('toleranceUp','Mais tolerância',context.tolerance<255)
    elseif id=='shape' then
        add('outline','Forma com contorno',true)
        add('filled','Forma preenchida',true)
    elseif id=='picker' then
        add('visible','Capturar visível',true)
        add('active','Capturar camada ativa',true)
    elseif id=='select' then
        add('deselect','Desmarcar seleção',context.hasSelection==true)
    elseif id~='pixel' and id~='inspect' then
        error('Ferramenta desconhecida')
    end
    if id~='inspect' then add('color','Editar cor RGBA',true) end
    add('help','Ferramentas e atalhos',true)
    return entries
end
function Menu.place(x,y,w,h,entries)
    assert(type(entries)=='table' and #entries>0 and
        type(w)=='number' and w>=960 and type(h)=='number' and h>=640,
        'Geometria de menu inválida')
    local height=Menu.HEADER+#entries*Menu.ROW
    local left=math.max(8,math.min(w-Menu.WIDTH-8,math.floor(x)))
    local top=math.max(70,math.min(h-height-54,math.floor(y)))
    return left,top,Menu.WIDTH,height
end
function Menu.hit(menu,x,y)
    if x<menu.x or x>=menu.x+menu.w or
        y<menu.y+Menu.HEADER or y>=menu.y+menu.h then
        return nil
    end
    local i=math.floor((y-menu.y-Menu.HEADER)/Menu.ROW)+1
    return menu.entries[i],i
end
return Menu
