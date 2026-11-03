-- A43 — gestos de tamanho de pincel com teclado/mouse Windows.
-- O atalho Ctrl+Alt+arraste e [/] sao do tutorial oficial Windows.
-- A sensibilidade de 4 pontos por 1 px e propria do rebuild:
-- nao ha medicao equivalente da curva original para a mesma versao.
local M={}
M.MIN=1
M.MAX=256
M.DRAG_POINTS_PER_PIXEL=4
local function finite(v)
    return type(v)=='number' and v==v and
        v>-1000000000 and v<1000000000
end
local function clamp(value)
    return math.max(M.MIN,math.min(M.MAX,value))
end
function M.begin(x,diameter)
    assert(finite(x) and finite(diameter),
        'Inicio de ajuste do pincel invalido')
    return {originX=x,origin=clamp(math.floor(diameter+.5))}
end
function M.move(gesture,x)
    assert(type(gesture)=='table' and finite(gesture.originX)
        and finite(gesture.origin) and finite(x),
        'Arrasto do pincel invalido')
    local delta=(x-gesture.originX)/M.DRAG_POINTS_PER_PIXEL
    local steps=delta>=0 and math.floor(delta+.5)
        or -math.floor(-delta+.5)
    return clamp(gesture.origin+steps)
end
function M.step(diameter,direction)
    assert(finite(diameter) and (direction==1 or direction==-1),
        'Passo do pincel invalido')
    return clamp(math.floor(diameter+.5)+direction)
end
function M.keyDirection(key)
    if key=='leftbracket' then return -1 end
    if key=='rightbracket' then return 1 end
    return nil
end
return M
