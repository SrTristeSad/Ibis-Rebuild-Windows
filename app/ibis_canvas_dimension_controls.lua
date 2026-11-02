-- Vetores originais para os controles +/- da Nova tela (Windows).
-- Modulo de desenho apenas, sem Store, RBD2 ou eventos de mouse.
local M={}
function M.draw(rect,direction,enabled,hovered)
    assert(type(rect)=='table' and type(rect.x)=='number'
        and type(rect.y)=='number' and rect.w>=20
        and rect.h>=20 and (direction==-1 or direction==1),
        'Geometria de ajuste invalida')
    local g=assert(love and love.graphics,'LÖVE obrigatorio')
    g.push('all')
    if not enabled then
        g.setColor(.94,.94,.94,1)
    elseif hovered then
        g.setColor(.80,.88,.98,1)
    else
        g.setColor(.90,.92,.94,1)
    end
    g.rectangle('fill',rect.x,rect.y,rect.w,rect.h,2,2)
    g.setColor(enabled and .49 or .76,
        enabled and .54 or .76,
        enabled and .60 or .76,1)
    g.setLineWidth(1)
    g.rectangle('line',rect.x+.5,rect.y+.5,
        rect.w-1,rect.h-1,2,2)
    g.setColor(enabled and .22 or .66,
        enabled and .26 or .66,
        enabled and .31 or .66,1)
    g.setLineWidth(1.8)
    local cx,cy=rect.x+rect.w/2,rect.y+rect.h/2
    g.line(cx-5,cy,cx+5,cy)
    if direction==1 then g.line(cx,cy-5,cx,cy+5) end
    g.pop()
end
return M
