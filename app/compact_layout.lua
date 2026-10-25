-- Layout for an independently implemented, mobile-like workspace.
-- The seven main toolbar categories follow the official ibisPaint tutorial
-- (brush/eraser, tools, properties, color, full screen, layers, back).
-- This is a layout reference, NOT an Android view/asset extraction.
local UI={}
UI.IDS={'brush','tools','properties','color','fullscreen','layers','back'}
UI.LABELS={'Pincel','Ferramentas','Ajustes','Cor','Tela','Camadas','Voltar'}
UI.WIDTH=96
UI.GAP=7
UI.HEIGHT=42
function UI.toolbar(w,h)
    assert(type(w)=='number' and w>=960 and
        type(h)=='number' and h>=640,'Dimensão insuficiente')
    local total=#UI.IDS*UI.WIDTH+(#UI.IDS-1)*UI.GAP
    local x=math.floor((w-total)/2)
    local y=h-108
    local result={}
    for i,id in ipairs(UI.IDS) do
        result[i]={id=id,label=UI.LABELS[i],
            x=x+(i-1)*(UI.WIDTH+UI.GAP),y=y,
            w=UI.WIDTH,h=UI.HEIGHT}
    end
    return result
end
function UI.pick(w,h,x,y)
    for _,slot in ipairs(UI.toolbar(w,h)) do
        if x>=slot.x and x<slot.x+slot.w and
            y>=slot.y and y<slot.y+slot.h then
            return slot.id
        end
    end
    return nil
end
function UI.popup(w,h,kind)
    assert(kind=='tools' or kind=='layers' or kind=='properties',
        'Janela compacta desconhecida')
    assert(type(w)=='number' and w>=960 and
        type(h)=='number' and h>=640,'Janela compacta inválida')
    local width=kind=='tools' and 332 or 298
    local height=kind=='tools' and 410 or
        kind=='layers' and math.min(440,h-260) or 354
    return {x=kind=='layers' and w-width-20 or 20,y=134,
        w=width,h=height}
end
function UI.contains(rect,x,y)
    return x>=rect.x and x<rect.x+rect.w and
        y>=rect.y and y<rect.y+rect.h
end
function UI.layerRows(rect)
    return math.max(2,math.min(5,math.floor((rect.h-178)/40)))
end
return UI
