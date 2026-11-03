-- Chrome superior da tela inicial.
-- Evidencia publica: ibisPaint 14.0.2 (NAO medicao do APK 14.1.2).
-- Premium, Ajuda e Configuracoes nao possuem rota equivalente aqui.
-- Nunca registrar cliques ou acionar outro painel por engano.
local M={}
local function dimensions(w,h)
    assert(type(w)=='number' and w>=960 and
        type(h)=='number' and h>=640,
        'Viewport da tela inicial invalido')
end

function M.controls(w,h)
    dimensions(w,h)
    local r=math.min(20,math.floor(h*.026))
    local gap=math.max(50,math.floor(h*.09))
    local right=math.max(30,math.floor(h*.042))
    local y=math.max(29,math.floor(h*.045))
    local items={}
    for i,id in ipairs({'premium','help','settings'}) do
        local x=w-right+(i-3)*gap
        items[i]={id=id,x=x-r-6,y=y-r-6,w=2*r+12,
            h=2*r+12,cx=x,cy=y,r=r,actionable=false}
    end
    return items
end

local function icon(g,item,fonts)
    local x,y,r=item.cx,item.cy,item.r
    if item.id=='premium' then
        g.setColor(.98,.77,.19,1)
        g.circle('fill',x,y,r*.84)
        g.setColor(1,1,1,1)
        g.setFont(fonts.body)
        local text='P'
        g.print(text,math.floor(x-fonts.body:getWidth(text)/2),
            math.floor(y-fonts.body:getHeight()/2))
    elseif item.id=='help' then
        g.setColor(.95,.96,.98,.92)
        g.setLineWidth(1.8)
        g.circle('line',x,y,r*.80,36)
        g.setFont(fonts.body)
        local text='?'
        g.print(text,math.floor(x-fonts.body:getWidth(text)/2),
            math.floor(y-fonts.body:getHeight()/2))
    else
        g.setColor(.95,.96,.98,.90)
        g.setLineWidth(1.8)
        g.circle('line',x,y,r*.57,36)
        g.circle('line',x,y,r*.22,24)
        for i=0,7 do
            local a=i*math.pi/4
            g.line(x+math.cos(a)*r*.64,y+math.sin(a)*r*.64,
                x+math.cos(a)*r*.90,y+math.sin(a)*r*.90)
        end
        -- Sem bolinha vermelha: nao simular notificacoes inexistentes.
    end
end

function M.draw(w,h,fonts)
    local g=assert(love and love.graphics,
        'LÖVE necessario ao chrome da tela inicial')
    local controls=M.controls(w,h)
    g.push('all')
    for _,item in ipairs(controls) do
        icon(g,item,fonts)
    end
    -- Hover informa a limitacao sem instalar hitbox clicavel.
    local mx,my=love.mouse.getPosition()
    for _,item in ipairs(controls) do
        if mx>=item.x and mx<item.x+item.w and
            my>=item.y and my<item.y+item.h then
            g.setColor(.08,.15,.22,.88)
            local tw=181
            local tx=math.min(w-tw-12,math.max(12,item.cx-tw/2))
            local ty=item.y+item.h+8
            g.rectangle('fill',tx,ty,tw,27,5,5)
            g.setColor(1,1,1,1)
            g.setFont(fonts.small)
            g.printf('Indisponível no rebuild',tx,ty+6,tw,'center')
            break
        end
    end
    g.pop()
end

return M
