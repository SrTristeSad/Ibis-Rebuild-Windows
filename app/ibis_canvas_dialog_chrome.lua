-- Chrome neutro da janela Nova tela. Sem callbacks, Store ou raster.
-- Referencia: tutorial publico ibisPaint #02 (hierarquia, nao pixels).
local M={}
local palette={
    body={.84,.85,.86,1},
    section={.28,.29,.30,1},
    sectionText={.96,.96,.97,1},
    border={.24,.26,.28,1},
    tabSelected={.73,.75,.77,1},
    tabNormal={.87,.88,.89,1},
    tabHover={.80,.82,.84,1},
    rowSelected={.75,.77,.79,1},
    rowNormal={.89,.90,.91,1},
    rowHover={.82,.84,.86,1},
    rowBorder={.64,.66,.68,1},
    rowSelectedBorder={.28,.31,.34,1}
}
function M.color(key)
    local rgba=assert(palette[key],'Cor do chrome desconhecida')
    return rgba[1],rgba[2],rgba[3],rgba[4]
end
function M.rowStyle(selected,hovered)
    return selected and 'rowSelected' or
        hovered and 'rowHover' or 'rowNormal'
end
function M.body(rect)
    assert(type(rect)=='table' and type(rect.x)=='number'
        and type(rect.y)=='number' and rect.w>=640 and rect.h>=482,
        'Dialogo Nova tela invalido')
    local g=assert(love and love.graphics,'LÖVE necessario')
    g.push('all')
    g.setColor(M.color('body'))
    g.rectangle('fill',rect.x,rect.y,rect.w,rect.h)
    g.setColor(M.color('border'))
    g.setLineWidth(1)
    g.rectangle('line',rect.x+.5,rect.y+.5,rect.w-1,rect.h-1)
    g.pop()
end
function M.section(rect,font)
    local g=assert(love and love.graphics,'LÖVE necessario')
    g.push('all')
    g.setColor(M.color('section'))
    g.rectangle('fill',rect.x+1,rect.y+47,rect.w-2,21)
    g.setColor(M.color('sectionText'))
    g.setFont(font)
    g.print('Ilustração',rect.x+13,rect.y+50)
    g.pop()
end
function M.tab(rect,label,selected,hovered,font)
    assert(type(rect)=='table' and rect.w>=100 and rect.h>=25,
        'Aba Nova tela invalida')
    local g=assert(love and love.graphics,'LÖVE necessario')
    g.push('all')
    g.setColor(M.color(selected and 'tabSelected' or
        hovered and 'tabHover' or 'tabNormal'))
    g.rectangle('fill',rect.x,rect.y,rect.w,rect.h)
    g.setColor(M.color('rowBorder'))
    g.setLineWidth(1)
    g.rectangle('line',rect.x+.5,rect.y+.5,rect.w-1,rect.h-1)
    if selected then
        g.setColor(M.color('border'))
        g.rectangle('fill',rect.x,rect.y+rect.h-3,rect.w,3)
    end
    g.setColor(.18,.20,.22,1)
    g.setFont(font)
    g.printf(label,rect.x,
        rect.y+(rect.h-font:getHeight())/2,rect.w,'center')
    g.pop()
end
return M
