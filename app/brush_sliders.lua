-- Precise, deterministic editor parameter rails. No LÖVE or native raster
-- dependency: values are UI settings, not image/pixel operations.
local Sliders={}
local defs={
    diameter={min=1,max=256,step=1,y=479,h=10},
    opacity={min=.1,max=1,step=.01,y=645,h=9},
    stabilization={min=0,max=5,step=1,y=726,h=9},
    tolerance={min=0,max=255,step=1,y=479,h=10},
}
local function finite(v)
    return type(v)=='number' and v==v and v>-1e12 and v<1e12
end
function Sliders.spec(kind)
    return assert(defs[kind],'Parâmetro deslizante desconhecido')
end
function Sliders.rail(kind,panel)
    local d=Sliders.spec(kind)
    assert(finite(panel) and panel>=0,'Painel inválido')
    return {x=panel+72,y=d.y,w=105,h=d.h}
end
local function round(v) return math.floor(v+.5) end
function Sliders.value(kind,mouseX,panel)
    local d=Sliders.spec(kind)
    assert(finite(mouseX),'Coordenada de ajuste inválida')
    local r=Sliders.rail(kind,panel)
    local t=math.max(0,math.min(1,(mouseX-r.x)/r.w))
    local steps=round((d.max-d.min)/d.step)
    local index=round(t*steps)
    return math.max(d.min,math.min(d.max,
        tonumber(string.format('%.4f',d.min+index*d.step))))
end
function Sliders.fraction(kind,value)
    local d=Sliders.spec(kind)
    assert(finite(value),'Valor de ajuste inválido')
    return math.max(0,math.min(1,(value-d.min)/(d.max-d.min)))
end
function Sliders.hit(kind,panel,x,y)
    local r=Sliders.rail(kind,panel)
    return finite(x) and finite(y) and x>=r.x-2 and x<=r.x+r.w+2
        and y>=r.y-1 and y<=r.y+r.h+1
end
function Sliders.activeKind(tool,tab,focus)
    if focus or tab~='brush' then return nil end
    if tool=='brush' or tool=='erase' then
        return {'diameter','opacity','stabilization'}
    elseif tool=='fill' then
        return {'tolerance'}
    end
    return nil
end
function Sliders.kindAt(tool,tab,focus,panel,x,y)
    local list=Sliders.activeKind(tool,tab,focus)
    if not list then return nil end
    for _,kind in ipairs(list) do
        if Sliders.hit(kind,panel,x,y) then return kind end
    end
    return nil
end
return Sliders
