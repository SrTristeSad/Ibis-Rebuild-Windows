-- Barra superior do editor, inspirada na ordem documentada dos
-- seis controles de ibisPaint. Vetores independentes, sem assets do APK.
-- Geometria pura para testar visibilidade e impedir toques no canvas.
local Top={}
Top.items={
    {id='view',label='Visualizar',icon='top-view'},
    {id='selection',label='Seleção',icon='top-selection'},
    {id='stabilizer',label='Estabilizar',icon='top-stabilizer'},
    {id='shape',label='Formas',icon='top-shape'},
    {id='ruler',label='Régua',icon='top-ruler'},
    {id='materials',label='Materiais',icon='top-material'}
}
Top.SIZE=36
Top.GAP=7
Top.Y=8
Top.RIGHT=18
function Top.toolbar(w,h)
    assert(type(w)=='number' and w>=960 and
        type(h)=='number' and h>=640,'Tela pequena para controles')
    local total=#Top.items*Top.SIZE+(#Top.items-1)*Top.GAP
    local left=w-Top.RIGHT-total
    local slots={}
    for i,item in ipairs(Top.items) do
        slots[i]={id=item.id,label=item.label,icon=item.icon,
            x=left+(i-1)*(Top.SIZE+Top.GAP),y=Top.Y,
            w=Top.SIZE,h=Top.SIZE}
    end
    return slots
end
function Top.pick(w,h,x,y)
    for _,slot in ipairs(Top.toolbar(w,h)) do
        if x>=slot.x and x<slot.x+slot.w and
            y>=slot.y and y<slot.y+slot.h then
            return slot.id
        end
    end
end
function Top.byId(id)
    for _,item in ipairs(Top.items) do
        if item.id==id then return item end
    end
end
return Top
