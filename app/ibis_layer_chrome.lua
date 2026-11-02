-- Somente representacao da janela Camadas; nenhuma edicao de pixels.
-- Cores/organizacao baseadas em Layer Window Details do ibisPaint.
local M={}
M.colors={
    window={.91,.92,.93},header={.21,.22,.24},
    selected={.70,.81,.95},selection={.96,.85,.88},
    row={.94,.945,.95},line={.67,.69,.72},
    text={.14,.17,.20},muted={.39,.42,.46},
    footer={.17,.18,.20}
}
local function color(id)
    local c=assert(M.colors[id])
    love.graphics.setColor(c[1],c[2],c[3],1)
end
function M.regions(p)
    assert(type(p)=='table' and type(p.x)=='number'
        and type(p.y)=='number' and p.w>=298 and p.h>=350,
        'Painel de camadas invalido')
    return {
        header={x=p.x,y=p.y,w=p.w,h=44},
        footer={x=p.x,y=p.y+p.h-91,w=p.w,h=91}
    }
end
function M.backgroundRow(p,n)
    local footer=M.regions(p).footer
    assert(type(n)=='number' and n%1==0 and n>=1 and n<=4,
        'Quantidade de camadas invalidas')
    local y=p.y+126+n*52
    if y+30>footer.y then return nil end
    return {x=p.x+13,y=y,w=p.w-26,h=30}
end
-- Slots fixos e compactos. Os IDs são semânticos e independem
-- dos rótulos, para preservar os comandos na interface Windows.
function M.toolbar(p,group)
    M.regions(p)
    local icons={
        {id='add',label='Nova camada',icon='add'},
        {id='duplicate',label='Duplicar camada',icon='copy'},
        {id='delete',label='Excluir camada',icon='delete'},
        {id='previous',label='Subir lista',icon='up'},
        {id='next',label='Descer lista',icon='down'},
        {id='rename',label='Renomear',icon='edit'},
        {id='merge',label='Mesclar abaixo',icon='merge'}
    }
    local first,last
    if group=='top' then first,last=1,3
    elseif group=='footer' then first,last=4,7
    else error('Grupo de controles de camada desconhecido') end
    local result={}
    for i=first,last do
        local item=icons[i]
        result[#result+1]={id=item.id,icon=item.icon,label='',
            hint=item.label,x=p.x+11+(i-1)*40,
            y=p.y+49,w=36,h=30}
    end
    return result
end
function M.footerControls(p)
    M.regions(p)
    local y=p.y+p.h-87
    return {
        {id='clipping',label='Clipping',x=p.x+8,y=y,w=88,h=32,
            available=false},
        {id='alpha',label='Alpha Lock',x=p.x+101,y=y,w=91,h=32,
            available=true},
        {id='blend',label='Normal',x=p.x+197,y=y,w=93,h=32,
            available=true}
    }
end
function M.actionHint(p,x,y)
    for _,group in ipairs({'top','footer'}) do
        for _,slot in ipairs(M.toolbar(p,group)) do
            if x>=slot.x and x<slot.x+slot.w and
                y>=slot.y and y<slot.y+slot.h then
                return slot.hint
            end
        end
    end
end
function M.paintFooterControl(slot,font)
    assert(type(slot)=='table' and type(slot.available)=='boolean')
    local lg=love.graphics
    local active=slot.available
    lg.setColor(slot.selected and .48 or active and .93 or .33,
        slot.selected and .74 or active and .94 or .35,
        slot.selected and .98 or active and .95 or .37,1)
    lg.rectangle('fill',slot.x,slot.y,slot.w,slot.h,2,2)
    lg.setColor(active and .70 or .43,active and .72 or .44,
        active and .75 or .45,1)
    lg.rectangle('line',slot.x+.5,slot.y+.5,
        slot.w-1,slot.h-1,2,2)
    lg.setColor(slot.selected and .06 or active and .17 or .65,
        slot.selected and .18 or active and .18 or .67,
        slot.selected and .35 or active and .20 or .69,1)
    lg.setFont(font)
    lg.printf(slot.label,slot.x+2,slot.y+
        (slot.h-font:getHeight())/2,slot.w-4,'center')
end
function M.step(p,direction)
    M.regions(p)
    assert(direction==1 or direction==-1,'Passo de opacidade invalido')
    return {id=direction==1 and 'increase' or 'decrease',
        label='',icon=direction==1 and 'add' or 'subtract',
        x=p.x+(direction==1 and 255 or 49),
        y=p.y+p.h-35,w=29,h=29}
end
local function drawGlyph(g,glyphId,x,y)
    -- Ícones vetoriais próprios, sem assets do APK.
    g.setLineWidth(1.7)
    if glyphId=='add' or glyphId=='subtract' then
        g.line(x-5,y,x+5,y)
        if glyphId=='add' then g.line(x,y-5,x,y+5) end
    elseif glyphId=='copy' then
        g.rectangle('line',x-5,y-7,10,12,1,1)
        g.rectangle('line',x-2,y-4,10,12,1,1)
    elseif glyphId=='delete' then
        g.rectangle('line',x-5,y-3,10,10,1,1)
        g.line(x-7,y-5,x+7,y-5)
        g.line(x-3,y-8,x+3,y-8)
    elseif glyphId=='up' or glyphId=='down' then
        local v=glyphId=='up' and -1 or 1
        g.line(x,y-7*v,x,y+7*v)
        g.line(x-4,y+2*v,x,y+7*v,x+4,y+2*v)
    elseif glyphId=='edit' then
        g.line(x-5,y+6,x+5,y-4)
        g.line(x-6,y+7,x-2,y+6)
        g.line(x+3,y-6,x+7,y-2)
    elseif glyphId=='merge' then
        g.line(x-6,y-5,x+6,y-5)
        g.line(x-6,y+6,x+6,y+6)
        g.line(x,y-2,x,y+3)
        g.line(x-3,y,x,y+3,x+3,y)
    end
end
function M.paintAction(slot,disabled,font)
    assert(type(slot)=='table' and type(slot.x)=='number'
        and type(slot.y)=='number' and slot.w>0 and slot.h>0,
        'Slot de controle invalido')
    assert(type(font)=='userdata' or type(font)=='table',
        'Fonte de controle invalida')
    local lg=love.graphics
    lg.setColor(disabled and .29 or .27,
        disabled and .30 or .28,
        disabled and .32 or .30,1)
    lg.rectangle('fill',slot.x,slot.y,slot.w,slot.h,4,4)
    lg.setColor(disabled and .39 or .60,
        disabled and .41 or .63,
        disabled and .43 or .66,1)
    lg.rectangle('line',slot.x+.5,slot.y+.5,
        slot.w-1,slot.h-1,4,4)
    lg.setColor(disabled and .55 or .94,
        disabled and .57 or .95,
        disabled and .59 or .97,1)
    local centered=slot.label=='' or slot.label=='+'
        or slot.label=='−'
    local x=centered and slot.x+slot.w/2 or slot.x+15
    drawGlyph(lg,slot.icon,x,slot.y+slot.h/2)
    if slot.label~='' and slot.label~='+' and slot.label~='−' then
        lg.setFont(font)
        lg.print(slot.label,slot.x+28,
            slot.y+(slot.h-font:getHeight())/2)
    end
end
function M.frame(p)
    local q=M.regions(p)
    color('window')
    love.graphics.rectangle('fill',p.x,p.y,p.w,p.h,5,5)
    color('header')
    love.graphics.rectangle('fill',p.x,p.y,p.w,44,5,5)
    color('footer')
    love.graphics.rectangle('fill',q.footer.x,q.footer.y,
        q.footer.w,q.footer.h)
    color('line')
    love.graphics.rectangle('line',p.x+.5,p.y+.5,
        p.w-1,p.h-1,5,5)
end
function M.selection(r,info,font)
    color('selection')
    love.graphics.rectangle('fill',r.x,r.y,r.w,r.h)
    color('line')
    love.graphics.rectangle('line',r.x+.5,r.y+.5,r.w-1,r.h-1)
    love.graphics.setColor(.98,.72,.78,1)
    love.graphics.rectangle('fill',r.x+5,r.y+4,26,26)
    color('text')
    love.graphics.setFont(font)
    love.graphics.print('Camada de seleção',r.x+38,r.y+4)
    color('muted')
    love.graphics.print(info,r.x+38,r.y+20)
end
function M.row(r,active)
    color(active and 'selected' or 'row')
    love.graphics.rectangle('fill',r.x,r.y,r.w,r.h)
    color('line')
    love.graphics.rectangle('line',r.x+.5,r.y+.5,r.w-1,r.h-1)
    if active then
        love.graphics.setColor(.19,.48,.84,1)
        love.graphics.rectangle('fill',r.x,r.y,3,r.h)
    end
end
function M.label(r,index,name,opacity,body,small)
    color('text')
    love.graphics.setFont(body)
    love.graphics.print(tostring(index),r.x+54,r.y+3)
    love.graphics.setFont(small)
    love.graphics.printf(name,r.x+71,r.y+6,
        math.max(40,r.w-120),'left')
    color('muted')
    love.graphics.print(('%d%%'):format(math.floor(opacity*100+.5)),
        r.x+151,r.y+31)
end
function M.eye(r,visible,drawIcon)
    local x=r.x+r.w-34
    love.graphics.setColor(.86,.88,.90,1)
    love.graphics.rectangle('fill',x,r.y+9,32,29,3,3)
    color(visible and 'text' or 'muted')
    drawIcon(visible and 'visible' or 'hidden',x+16,r.y+23.5,18)
    return {x=x,y=r.y+9,w=32,h=29}
end
function M.background(r,font)
    love.graphics.setColor(.86,.87,.89,1)
    love.graphics.rectangle('fill',r.x,r.y,r.w,r.h)
    color('text')
    love.graphics.setFont(font)
    love.graphics.print('Fundo',r.x+8,r.y+8)
    for i=1,3 do
        local v=i==1 and 1 or i==2 and .76 or .35
        love.graphics.setColor(v,v,v,1)
        love.graphics.rectangle('fill',r.x+r.w-89+(i-1)*28,
            r.y+5,24,20)
        color('line')
        love.graphics.rectangle('line',r.x+r.w-89+(i-1)*28+.5,
            r.y+5.5,23,19)
    end
end
return M
