-- Layout for an independently implemented, mobile-like workspace.
-- As nove acoes principais seguem a ordem documentada na barra
-- ibisPaint: pincel/borracha, ferramentas, ajustes, cor, tela,
-- desfazer, refazer, camadas, voltar. Desenhos vetoriais sao originais.
local UI={}
UI.IDS={'brush','tools','properties','color','fullscreen',
    'undo','redo','layers','back'}
UI.LABELS={'Pincel','Ferramentas','Ajustes','Cor','Tela',
    'Desfazer','Refazer','Camadas','Voltar'}
UI.WIDTH=72
UI.GAP=7
UI.HEIGHT=50
function UI.toolbar(w,h)
    assert(type(w)=='number' and w>=960 and
        type(h)=='number' and h>=640,'Dimensão insuficiente')
    local total=#UI.IDS*UI.WIDTH+(#UI.IDS-1)*UI.GAP
    local x=math.floor((w-total)/2)
    local y=h-60
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
        diameter={x=left+185,y=h-123,w=370,h=14,
            labelX=left+52,valueX=left+569},
        opacity={x=left+185,y=h-97,w=370,h=14,
            labelX=left+52,valueX=left+569}
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
function UI.popup(w,h,kind,columns)
    columns=columns or 2
    if kind=='tools' then
        assert(columns==1 or columns==2 or columns==3,
            'Colunas do seletor invalidas')
    end
    assert(kind=='tools' or kind=='layers' or kind=='properties'
        or kind=='color' or kind=='view' or kind=='stabilizer'
        or kind=='ruler' or kind=='materials' or kind=='blends'
        or kind=='filters' or kind=='text' or kind=='transform'
        or kind=='wand' or kind=='lasso' or kind=='smudge'
        or kind=='blur' or kind=='special'
        or kind=='vector' or kind=='frame',
        'Janela compacta desconhecida')
    assert(type(w)=='number' and w>=960 and
        type(h)=='number' and h>=640,'Janela compacta inválida')
    local isTop=kind=='view' or kind=='stabilizer'
        or kind=='ruler' or kind=='materials'
    local width=kind=='tools' and (columns==3 and 358 or 242) or
        kind=='color' and 404 or kind=='ruler' and 390
        or kind=='materials' and 444 or (kind=='tools' or
        kind=='filters' or kind=='text' or kind=='transform'
        or kind=='wand' or kind=='lasso' or kind=='smudge'
        or kind=='blur' or kind=='special'
        or kind=='vector' or kind=='frame') and 420
        or isTop and 318 or 298
    local height=kind=='color' and 450 or
        (kind=='tools' and (columns==3 and 288 or 383)) or
        ((kind=='filters' or kind=='text' or kind=='transform'
            or kind=='wand' or kind=='lasso' or kind=='smudge'
            or kind=='blur' or kind=='special'
            or kind=='vector' or kind=='frame')
            and math.min(440,h-188)) or
        kind=='layers' and math.min(440,h-260) or
        kind=='view' and 314 or kind=='stabilizer' and 254 or
        kind=='blends' and math.min(440,h-260) or
        kind=='ruler' and 402 or kind=='materials' and 440 or 354
    local x=(kind=='tools' and 85) or
        ((kind=='layers' or kind=='color' or kind=='blends' or isTop)
        and w-width-20 or 20)
    local y=(kind=='tools' and math.max(125,h-130-height-6)) or
        (kind=='layers' and math.max(134,h-130-height-8)) or 134
    return {x=x,y=y,w=width,h=height}
end
function UI.contains(rect,x,y)
    return x>=rect.x and x<rect.x+rect.w and
        y>=rect.y and y<rect.y+rect.h
end
function UI.layerRows(rect)
    return math.max(2,math.min(4,math.floor((rect.h-188)/52)))
end
return UI
