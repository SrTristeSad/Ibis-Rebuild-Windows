-- Tela inicial do rebuild, baseada no fluxo de navegacao do
-- ibisPaint atual: Minha Galeria e Galeria Online. A Colecao foi
-- removida no ibisPaint 12.2.0, nao deve ser recriada no 14.1.2.
-- Sem Store, ferramentas ou acesso externo.
local M={}
local BG={.145,.30,.46,1}
local colors={
    {1,.64,.11,1},{1,.44,.13,1},{.91,.25,.38,1},
    {.74,.31,.67,1},{.48,.36,.84,1},{.29,.53,.90,1},
    {.11,.65,.90,1},{.12,.73,.74,1},{.18,.72,.45,1},
    {.45,.75,.25,1},{.77,.78,.18,1},{.94,.75,.15,1}
}
function M.layout(w,h)
    assert(type(w)=='number' and w>=960 and
        type(h)=='number' and h>=640,
        'Janela inicial menor que o minimo Windows')
    local bw,bh=194,160
    local y=math.floor(h*.58)
    return {
        gallery={x=math.floor(w/2-bw-20),y=y,w=bw,h=bh},
        online={x=math.floor(w/2+20),y=y,w=bw,h=bh}
    }
end
function M.hit(w,h,x,y)
    local buttons=M.layout(w,h)
    for name,rect in pairs(buttons) do
        if x>=rect.x and x<rect.x+rect.w and
            y>=rect.y and y<rect.y+rect.h then return name end
    end
    return nil
end
local function wheel(g,cx,cy)
    local r=30
    for i,rgba in ipairs(colors) do
        g.setColor(rgba)
        local a=(i-1)*math.pi/6-math.pi/2
        g.arc('fill',cx,cy,r,a,a+math.pi/6,12)
    end
    g.setColor(1,1,1,1)
    g.setLineWidth(2)
    g.circle('line',cx,cy,r)
    g.setColor(BG)
    g.circle('fill',cx,cy,14)
    g.setColor(1,1,1,1)
    g.circle('line',cx,cy,14)
end
local function emblem(g,kind,cx,cy,enabled)
    g.setColor(1,1,1,enabled and .94 or .38)
    g.setLineWidth(1.5)
    g.circle('line',cx,cy,42)
    if kind=='gallery' then
        g.setLineWidth(3)
        g.line(cx-17,cy+17,cx+13,cy-14)
        g.setLineWidth(1.7)
        g.polygon('line',cx+11,cy-12,cx+19,cy-20,
            cx+24,cy-16,cx+17,cy-8)
        g.polygon('line',cx-19,cy+18,cx-11,cy+13,
            cx-15,cy+8,cx-22,cy+16)
    else
        g.circle('line',cx,cy,23)
        g.line(cx-23,cy,cx+23,cy)
        g.arc('line',cx,cy,11,0,math.pi*2,32)
        g.line(cx,cy-23,cx,cy+23)
    end
end
function M.draw(w,h,fonts)
    local g=assert(love and love.graphics,'LÖVE requerido')
    local buttons=M.layout(w,h)
    g.push('all')
    g.setColor(BG)
    g.rectangle('fill',0,0,w,h)
    g.setColor(1,1,1,1)
    g.setFont(fonts.large)
    local left='ibis'
    local right='aint'
    local full=fonts.large:getWidth(left)+72+
        fonts.large:getWidth(right)
    local start=math.floor((w-full)/2)
    local y=math.floor(h*.28)
    g.print(left,start,y)
    wheel(g,start+fonts.large:getWidth(left)+36,
        y+fonts.large:getHeight()/2)
    g.print(right,start+fonts.large:getWidth(left)+72,y)
    g.setFont(fonts.small)
    g.setColor(.85,.90,.94,1)
    g.printf('Rebuild para Windows · base Android 14.1.2',
        w/2-280,y+66,560,'center')
    local mx,my=love.mouse.getPosition()
    for _,kind in ipairs({'gallery','online'}) do
        local rect=buttons[kind]
        local enabled=kind=='gallery'
        local hover=enabled and
            mx>=rect.x and mx<rect.x+rect.w and
            my>=rect.y and my<rect.y+rect.h
        if hover then
            g.setColor(1,1,1,.10)
            g.rectangle('fill',rect.x,rect.y,rect.w,rect.h,5,5)
        end
        emblem(g,kind,rect.x+rect.w/2,rect.y+57,enabled)
        g.setColor(1,1,1,enabled and .95 or .58)
        g.setFont(fonts.body)
        g.printf(enabled and 'Minha Galeria' or 'Galeria Online',
            rect.x,rect.y+114,rect.w,'center')
        if not enabled then
            g.setFont(fonts.small)
            g.printf('Indisponível',rect.x,
                rect.y+137,rect.w,'center')
        end
    end
    g.pop()
end
return M
