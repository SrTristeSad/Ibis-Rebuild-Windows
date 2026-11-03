-- Somente geometria e rascunho visual da ferramenta Transformar.
-- O mecanismo atual de selecao retangular e distinto de Transformar.
-- Tutorial oficial: https://ibispaint.com/lecture/index.jsp?no=154
local M={}
M.modes={
    {id='translate',label='Mover / Escala'},
    {id='perspective',label='Perspectiva'},
    {id='mesh',label='Malha'}
}
M.fields={
    {id='movementX',label='Mover X',unit=' px',minimum=-2048,maximum=2048,step=1},
    {id='movementY',label='Mover Y',unit=' px',minimum=-2048,maximum=2048,step=1},
    {id='zoom',label='Zoom',unit='%',minimum=1,maximum=800,step=5},
    {id='angle',label='Ângulo',unit='°',minimum=-180,maximum=180,step=5}
}
local byMode,byField={},{}
for _,mode in ipairs(M.modes) do byMode[mode.id]=mode end
for _,field in ipairs(M.fields) do byField[field.id]=field end
function M.mode(id) return byMode[id] end
function M.field(id) return byField[id] end
function M.new()
    return {mode='translate',target='layer',scaling=true,rotation=true,
        repeatDisplay=false,showFrame=true,movementX=0,movementY=0,
        zoom=100,angle=0}
end
function M.canApply()
    -- Movimento em pixel real exigira motor proprio; NUNCA roteie
    -- para a selecao retangular existente por equivalencia presumida.
    return false
end
function M.chooseMode(state,id)
    assert(type(state)=='table' and M.mode(id),
        'Modo de transformacao inexistente')
    state.mode=id
end
function M.chooseTarget(state,id)
    assert(type(state)=='table' and (id=='layer' or id=='canvas'),
        'Alvo de transformacao invalido')
    state.target=id
end
local toggleKeys={scaling=true,rotation=true,
    repeatDisplay=true,showFrame=true}
function M.toggle(state,key)
    assert(type(state)=='table' and toggleKeys[key]
        and type(state[key])=='boolean','Toggle invalido')
    state[key]=not state[key]
    return state[key]
end
function M.adjust(state,key,delta)
    local field=assert(M.field(key),'Campo de transformacao invalido')
    assert(type(state)=='table' and type(state[key])=='number'
        and (delta==1 or delta==-1),'Ajuste de transformacao invalido')
    local result=state[key]+delta*field.step
    state[key]=math.max(field.minimum,math.min(field.maximum,result))
    return state[key]
end
local function panel(p)
    assert(type(p)=='table' and type(p.x)=='number' and
        type(p.y)=='number' and type(p.w)=='number' and
        type(p.h)=='number' and p.w>=420 and p.h>=440,
        'Painel de transformacao invalido')
end
function M.modeRect(p,i)
    panel(p)
    assert(type(i)=='number' and i%1==0 and i>=1 and i<=3)
    return {x=p.x+14+(i-1)*130,y=p.y+57,w=122,h=36}
end
function M.toggleRect(p,i)
    panel(p)
    assert(type(i)=='number' and i%1==0 and i>=1 and i<=3)
    return {x=p.x+14+(i-1)*130,y=p.y+111,w=122,h=34}
end
function M.fieldRow(p,i)
    panel(p)
    assert(type(i)=='number' and i%1==0 and i>=1 and i<=4)
    return {x=p.x+14,y=p.y+160+(i-1)*39,w=p.w-28,h=33}
end
function M.minusRect(p,i)
    local row=M.fieldRow(p,i)
    return {x=row.x+row.w-91,y=row.y+1,w=38,h=31}
end
function M.plusRect(p,i)
    local row=M.fieldRow(p,i)
    return {x=row.x+row.w-43,y=row.y+1,w=38,h=31}
end
function M.targetRect(p,i)
    panel(p)
    assert(type(i)=='number' and i%1==0 and i>=1 and i<=2)
    return {x=p.x+14+(i-1)*200,y=p.y+320,w=192,h=33}
end
function M.frameRect(p)
    panel(p)
    return {x=p.x+14,y=p.y+362,w=p.w-28,h=31}
end
function M.pendingArea(p)
    panel(p)
    return {x=p.x+14,y=p.y+121,w=p.w-28,h=235}
end
function M.footerRect(p)
    panel(p)
    return {x=p.x+14,y=p.y+p.h-30,w=p.w-28,h=22}
end
return M
