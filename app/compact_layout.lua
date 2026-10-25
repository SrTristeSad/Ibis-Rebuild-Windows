-- Layout for an independently implemented, mobile-like workspace.
-- The seven main toolbar categories follow the official ibisPaint tutorial
-- (brush/eraser, tools, properties, color, full screen, layers, back).
-- This is a layout reference, NOT an Android view/asset extraction.
local UI={}
UI.IDS={'brush','tools','properties','color','fullscreen','layers','back'}
UI.LABELS={'Pincel','Ferramentas','Ajustes','Cor','Tela','Camadas','Voltar'}
UI.WIDTH=82
UI.GAP=8
UI.HEIGHT=50
function UI.toolbar(w,h)
    assert(type(w)=='number' and w>=960 and
        type(h)=='number' and h>=640,'Dimensão insuficiente')
    local total=#UI.IDS*UI.WIDTH+(#UI.IDS-1)*UI.GAP
    local x=math.floor((w-total)/2)
    local y=h-112
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
-- Two quick rails live in a single bottom strip above the icon row.
-- Their hit boxes are independent of drawing bounds and popup hit maps.
function UI.quick(w,h)
    assert(type(w)=='number' and w>=960 and
        type(h)=='number' and h>=640,'Janela pequena para os ajustes')
    local left=math.floor((w-640)/2)
    return {
        diameter={x=left+92,y=h-159,w=160,h=14,
            labelX=left+10,valueX=left+258},
        opacity={x=left+409,y=h-159,w=160,h=14,
            labelX=left+319,valueX=left+576}
    }
end
local ranges={
    diameter={min=1,max=256,step=1},
    opacity={min=.1,max=1,step=.01}
}
function UI.quickFraction(kind,value)
    local r=assert(ranges[kind],'Ajuste rápido inválido')
    assert(type(value)=='number' and value==value,'Valor inválido')
    return math.max(0,math.min(1,(value-r.min)/(r.max-r.min)))
end
function UI.quickValue(kind,w,h,x)
    local r=assert(ranges[kind],'Ajuste rápido inválido')
    local rect=UI.quick(w,h)[kind]
    assert(type(x)=='number' and x==x,'Ponteiro inválido')
    local t=math.max(0,math.min(1,(x-rect.x)/rect.w))
    local steps=math.floor((r.max-r.min)/r.step+.5)
    local index=math.floor(t*steps+.5)
    local value=r.min+index*r.step
    return math.max(r.min,math.min(r.max,
        tonumber(string.format('%.4f',value))))
end
function UI.quickHit(w,h,x,y)
    for name,rect in pairs(UI.quick(w,h)) do
        if x>=rect.x-4 and x<=rect.x+rect.w+4 and
            y>=rect.y-5 and y<=rect.y+rect.h+5 then return name end
    end
    return nil
end
function UI.popup(w,h,kind)
    assert(kind=='tools' or kind=='layers' or kind=='properties'
        or kind=='color','Janela compacta desconhecida')
    assert(type(w)=='number' and w>=960 and
        type(h)=='number' and h>=640,'Janela compacta inválida')
    local width=kind=='color' and 404 or kind=='tools' and 332 or 298
    local height=kind=='color' and 450 or kind=='tools' and 410 or
        kind=='layers' and math.min(440,h-260) or 354
    return {x=(kind=='layers' or kind=='color') and w-width-20 or 20,
        y=134,w=width,h=height}
end
function UI.contains(rect,x,y)
    return x>=rect.x and x<rect.x+rect.w and
        y>=rect.y and y<rect.y+rect.h
end
function UI.layerRows(rect)
    return math.max(2,math.min(5,math.floor((rect.h-178)/40)))
end
return UI
