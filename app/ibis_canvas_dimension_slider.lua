-- Barras lineares da tela Nova tela. Somente desenho (sem Store).
local M={}
function M.draw(track,value,hovered,dragging,geometry)
    local g=assert(love and love.graphics,'LÖVE necessario')
    local pos=geometry.sliderPosition(track,value)
    local cy=track.y+track.h/2
    g.push('all')
    g.setLineWidth(3)
    g.setColor(.75,.78,.82,1)
    g.line(track.x,cy,track.x+track.w,cy)
    if pos then
        g.setColor(.30,.60,.91,1)
        g.line(track.x,cy,pos,cy)
        g.setColor(.27,.59,.91,1)
    else
        g.setColor(.68,.70,.73,1)
        pos=track.x
    end
    g.circle('fill',pos,cy,dragging and 7 or hovered and 6.5 or 6)
    g.setColor(.97,.98,.99,1)
    g.setLineWidth(1)
    g.circle('line',pos,cy,dragging and 7 or hovered and 6.5 or 6)
    g.pop()
end
return M
