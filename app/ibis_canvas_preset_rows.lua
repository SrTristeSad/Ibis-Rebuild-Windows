-- Aparencia da lista de tamanhos do dialogo Nova tela.
-- Somente desenho: o Store, o editor e os callbacks ficam fora.
-- Icones de proporcao sao formas vetoriais proprias, sem assets do APK.
local M={}
local Chrome=require('ibis_canvas_dialog_chrome')

function M.symbol(preset)
    assert(type(preset)=='table' and
        type(preset.w)=='number' and preset.w>0 and
        type(preset.h)=='number' and preset.h>0,
        'Proporcao de preset invalida')
    local ratio=22/math.max(preset.w,preset.h)
    return {w=math.max(2,math.floor(preset.w*ratio+.5)),
        h=math.max(2,math.floor(preset.h*ratio+.5))}
end

function M.draw(rect,preset,selected,hovered,titleFont,metaFont)
    assert(type(rect)=='table' and type(rect.x)=='number'
        and type(rect.y)=='number' and rect.w>=300
        and rect.h>=28 and type(preset.name)=='string',
        'Linha de preset invalida')
    local g=assert(love and love.graphics,'LÖVE necessario')
    local s=M.symbol(preset)
    g.push('all')
    g.setColor(Chrome.color(Chrome.rowStyle(selected,hovered)))
    g.rectangle('fill',rect.x,rect.y,rect.w,rect.h)
    g.setColor(Chrome.color(selected and 'rowSelectedBorder'
        or 'rowBorder'))
    g.setLineWidth(selected and 1.5 or 1)
    g.rectangle('line',rect.x+.5,rect.y+.5,
        rect.w-1,rect.h-1)
    local cx,cy=rect.x+22,rect.y+rect.h/2
    g.setColor(.46,.48,.52,1)
    g.rectangle('line',cx-s.w/2,cy-s.h/2,s.w,s.h)
    g.setColor(.20,.21,.23,1)
    g.setFont(titleFont)
    g.print(preset.name,rect.x+49,
        rect.y+(rect.h-titleFont:getHeight())/2)
    g.setColor(.33,.35,.38,1)
    g.setFont(metaFont)
    g.printf(('%d × %d'):format(preset.w,preset.h),
        rect.x+rect.w-190,
        rect.y+(rect.h-metaFont:getHeight())/2,178,'right')
    g.pop()
end

return M
