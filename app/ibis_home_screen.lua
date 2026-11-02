-- Tela inicial do rebuild; navegação do ibisPaint atual.
-- Galeria Online continua indisponível, sem callback fictício.
-- Geometria visual baseada na captura pública de 14.0.2, não
-- em medição autenticada do Android 14.1.2.
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
    -- Manter o círculo inteiro dentro do retângulo clicável.
    local radius=math.floor(math.min(90,h*.082))
    local bw=math.floor(math.min(244,math.max(180,h*.26)))
    local bh=radius*2+74
    local y=math.floor(h*.60)
    local separation=math.floor(math.min(w*.43,h*.40))
    return {
        gallery={x=math.floor((w-separation-bw)/2),y=y,
            w=bw,h=bh,iconRadius=radius},
        online={x=math.floor((w+separation-bw)/2),y=y,
            w=bw,h=bh,iconRadius=radius}
    }
end
-- Escala a fonte já carregada: nenhuma nova fonte ou textura por frame.
-- A largura é limitada pela altura para preservar 960x640.
function M.logoMetrics(w,h,textWidth,fontHeight)
    M.layout(w,h)
    assert(type(textWidth)=='number' and textWidth>0 and
        type(fontHeight)=='number' and fontHeight>0,
        'Medidas invalidas do logotipo')
    local width=math.min(w*.70,h*.85)
    local scale=width/textWidth
    return {x=math.floor((w-width)/2),y=math.floor(h*.22),
        w=width,h=fontHeight*scale,scale=scale}
end
function M.hit(w,h,x,y)
    local buttons=M.layout(w,h)
    for name,rect in pairs(buttons) do
        if x>=rect.x and x<rect.x+rect.w and
            y>=rect.y and y<rect.y+rect.h then return name end
    end
    return nil
end
local function wheel(g,cx,cy,r)
    for i,rgba in ipairs(colors) do
        g.setColor(rgba)
        local a=(i-1)*math.pi/6-math.pi/2
        g.arc('fill',cx,cy,r,a,a+math.pi/6,12)
    end
    g.setColor(1,1,1,1)
    g.setLineWidth(.7)
    g.circle('line',cx,cy,r)
    g.setColor(BG)
    g.circle('fill',cx,cy,r*.43)
    g.setColor(1,1,1,1)
    g.circle('line',cx,cy,r*.43)
end
local function emblem(g,kind,cx,cy,enabled,radius)
    g.push()
    g.translate(cx,cy)
    g.scale(radius/42)
    g.setColor(1,1,1,enabled and .94 or .38)
    g.setLineWidth(1.5)
    g.circle('line',0,0,42)
    if kind=='gallery' then
        g.setLineWidth(3)
        g.line(-17,17,13,-14)
        g.setLineWidth(1.7)
        g.polygon('line',11,-12,19,-20,24,-16,17,-8)
        g.polygon('line',-19,18,-11,13,-15,8,-22,16)
    else
        g.circle('line',0,0,23)
        g.line(-23,0,23,0)
        g.arc('line',0,0,11,0,math.pi*2,32)
        g.line(0,-23,0,23)
    end
    g.pop()
end
function M.draw(w,h,fonts)
    local g=assert(love and love.graphics,'LÖVE requerido')
    local buttons=M.layout(w,h)
    g.push('all')
    g.setColor(BG)
    g.rectangle('fill',0,0,w,h)
    g.setColor(1,1,1,1)
    g.setFont(fonts.large)
    -- O disco cromático substitui a primeira letra de "Paint".
    local left,right='ibis','aint'
    local height=fonts.large:getHeight()
    local leftWidth=fonts.large:getWidth(left)
    local gap=height*1.12
    local full=leftWidth+gap+fonts.large:getWidth(right)
    local brand=M.logoMetrics(w,h,full,height)
    g.push()
    g.translate(brand.x,brand.y)
    g.scale(brand.scale)
    g.print(left,0,0)
    wheel(g,leftWidth+gap/2,height*.50,height*.49)
    g.print(right,leftWidth+gap,0)
    g.pop()
    g.setFont(fonts.small)
    g.setColor(.85,.90,.94,1)
    g.printf('Rebuild para Windows · base Android 14.1.2',
        brand.x,brand.y+brand.h+14,brand.w,'right')
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
        emblem(g,kind,rect.x+rect.w/2,
            rect.y+rect.iconRadius+4,enabled,rect.iconRadius)
        g.setColor(1,1,1,enabled and .95 or .58)
        g.setFont(fonts.body)
        local labelY=rect.y+rect.iconRadius*2+16
        g.printf(enabled and 'Minha Galeria' or 'Galeria Online',
            rect.x,labelY,rect.w,'center')
        if not enabled then
            g.setFont(fonts.small)
            g.printf('Indisponível',rect.x,
                labelY+23,rect.w,'center')
        end
    end
    g.pop()
end
return M
