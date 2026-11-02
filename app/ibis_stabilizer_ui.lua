-- Referencia: ibisPaint ver.14.1.0, tutorial oficial #39.
-- Geometria e rascunhos somente visuais; o estabilizador Lua
-- existente usa nivel legada 0..5. Modos novos NAO alteram raster.
local M={}
M.tabs={{id='stabilization',label='Estabilizar'},
    {id='fade',label='Fade'}}
M.MAX_DRAFT=100
local allowed={constant=true,fast=true,start=true,['end']=true}
function M.new()
    return {tab='stabilization',scope=false,fadeScope=false,
        constant=0,fast=0,start=0,['end']=0,
        fadeEnabled=false,shape='smooth'}
end
function M.tab(state,id)
    assert(type(state)=='table' and
        (id=='stabilization' or id=='fade'),'Aba invalida')
    state.tab=id
    return id
end
function M.toggle(state,key)
    assert(type(state)=='table' and
        (key=='scope' or key=='fadeScope' or key=='fadeEnabled')
        and type(state[key])=='boolean','Toggle visual invalido')
    state[key]=not state[key]
    return state[key]
end
function M.step(state,key,delta)
    assert(type(state)=='table' and allowed[key] and
        type(state[key])=='number' and
        (delta==1 or delta==-1),'Controle visual invalido')
    state[key]=math.max(0,math.min(M.MAX_DRAFT,
        state[key]+delta*10))
    return state[key]
end
function M.shape(state,id)
    assert(type(state)=='table' and
        (id=='smooth' or id=='linear'),'Forma de Fade invalida')
    state.shape=id
end
function M.canApply(id)
    return id=='legacy'
end
local function panel(p)
    assert(type(p)=='table' and type(p.x)=='number'
        and type(p.y)=='number' and p.w>=348 and p.h>=430,
        'Popup de estabilizacao invalido')
end
function M.tabRect(p,i)
    panel(p);assert(i==1 or i==2)
    return {x=p.x+16+(i-1)*159,y=p.y+54,w=151,h=33}
end
function M.scopeRect(p)
    panel(p)
    return {x=p.x+16,y=p.y+97,w=p.w-32,h=31}
end
function M.methodRect(p,i)
    panel(p);assert(i==1 or i==2)
    return {x=p.x+16+(i-1)*159,y=p.y+141,w=151,h=32}
end
function M.legacyRow(p)
    panel(p)
    return {x=p.x+16,y=p.y+195,w=p.w-32,h=43}
end
function M.draftRow(p,i)
    panel(p);assert(i==1 or i==2)
    return {x=p.x+16,y=p.y+251+(i-1)*58,w=p.w-32,h=52}
end
function M.draftButton(p,i,direction)
    local r=M.draftRow(p,i)
    assert(direction==1 or direction==-1)
    return {x=r.x+r.w-(direction==1 and 38 or 82),
        y=r.y+18,w=36,h=30}
end
function M.fadeToggleRect(p)
    panel(p)
    return {x=p.x+16,y=p.y+149,w=p.w-32,h=32}
end
function M.fadeRow(p,i)
    panel(p);assert(i==1 or i==2)
    return {x=p.x+16,y=p.y+196+(i-1)*59,w=p.w-32,h=52}
end
function M.fadeButton(p,i,direction)
    local r=M.fadeRow(p,i)
    assert(direction==1 or direction==-1)
    return {x=r.x+r.w-(direction==1 and 38 or 82),
        y=r.y+18,w=36,h=30}
end
function M.shapeRect(p,i)
    panel(p);assert(i==1 or i==2)
    return {x=p.x+16+(i-1)*159,y=p.y+330,w=151,h=32}
end
function M.footerRect(p)
    panel(p)
    return {x=p.x+16,y=p.y+p.h-35,w=p.w-32,h=27}
end
return M
