-- A44: gestos de navegacao com caneta no ibisPaint Windows.
-- Alt+Espaco + arrasto = zoom; Shift+Espaco + arrasto circular =
-- rotacao. Sem qualquer acoplamento a raster, LÖVE ou GPU.
-- Sensibilidade proprio rebuild; nao e medida do original PC.
local M={}
M.ZOOM_PER_PIXEL=.012
local function finite(v)
    return type(v)=='number' and v==v
        and v>-1e8 and v<1e8
end
local function angle(x,y)
    -- LuaJIT 2.1 disponibiliza atan2 com quadrantes completos.
    return math.atan2(y,x)
end
function M.mode(pen,space,alt,shift)
    if not pen or not space or alt==shift then return nil end
    return alt and 'zoom' or 'rotate'
end
function M.begin(kind,x,y,px,py)
    assert(kind=='zoom' or kind=='rotate','Navegacao desconhecida')
    assert(finite(x) and finite(y) and finite(px) and finite(py),
        'Posicao invalida de navegacao')
    if kind=='rotate' and
        (x-px)^2+(y-py)^2<100 then return nil end
    return {kind=kind,prevX=x,prevY=y,pivotX=px,pivotY=py}
end
function M.move(state,x,y)
    assert(type(state)=='table' and
        (state.kind=='zoom' or state.kind=='rotate') and
        finite(state.prevX) and finite(state.prevY) and
        finite(state.pivotX) and finite(state.pivotY) and
        finite(x) and finite(y),'Estado de navegacao invalido')
    local result
    if state.kind=='zoom' then
        local delta=math.max(-80,math.min(80,state.prevY-y))
        result=math.exp(delta*M.ZOOM_PER_PIXEL)
    else
        local oldX=state.prevX-state.pivotX
        local oldY=state.prevY-state.pivotY
        local newX=x-state.pivotX
        local newY=y-state.pivotY
        if newX^2+newY^2<100 then return 0 end
        local delta=angle(newX,newY)-angle(oldX,oldY)
        result=(delta+math.pi)%(math.pi*2)-math.pi
    end
    state.prevX=x;state.prevY=y
    return result
end
return M
