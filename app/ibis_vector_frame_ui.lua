-- Catalogos visuais de Vetor e Dividir Quadros em Lua puro.
-- NAO instanciam camadas vetoriais, molduras ou alteram pixels.
-- Referencias: https://ibispaint.com/lecture/index.jsp?no=191
--              https://ibispaint.com/lecture/index.jsp?no=38
local M={}
M.tabs={
    vector={{id='select',label='Selecionar'},
        {id='vertices',label='Vértices'},
        {id='order',label='Ordem'}},
    frame={{id='create',label='Novo quadro'},
        {id='divide',label='Dividir'},
        {id='border',label='Borda'}}
}
M.fields={
    horizontal={label='Espaço horizontal',min=0,max=120,step=1,unit=' px'},
    vertical={label='Espaço vertical',min=0,max=120,step=1,unit=' px'},
    thickness={label='Espessura da borda',min=1,max=50,step=1,unit=' px'},
    opacity={label='Opacidade da borda',min=0,max=100,step=5,unit='%'}
}
local fieldOrder={
    create={'horizontal','vertical','thickness'},
    divide={'horizontal','vertical'},
    border={'thickness','opacity'}
}
function M.new(kind)
    assert(kind=='vector' or kind=='frame','Ferramenta visual desconhecida')
    if kind=='vector' then
        return {kind='vector',tab='select',multi=false}
    end
    return {kind='frame',tab='create',horizontal=12,vertical=18,
        thickness=3,opacity=100,cut='vertical'}
end
function M.canApply() return false end
function M.chooseTab(state,id)
    assert(type(state)=='table' and M.tabs[state.kind],
        'Estado visual invalido')
    for _,tab in ipairs(M.tabs[state.kind]) do
        if tab.id==id then state.tab=id;return id end
    end
    error('Aba visual desconhecida')
end
function M.toggleMulti(state)
    assert(type(state)=='table' and state.kind=='vector'
        and state.tab=='select' and type(state.multi)=='boolean',
        'Alternancia de selecao indisponivel')
    state.multi=not state.multi
    return state.multi
end
function M.chooseCut(state,id)
    assert(type(state)=='table' and state.kind=='frame'
        and state.tab=='divide'
        and (id=='vertical' or id=='horizontal'),
        'Divisao visual desconhecida')
    state.cut=id
    return id
end
function M.fieldsFor(state)
    assert(type(state)=='table' and state.kind=='frame',
        'Campos apenas para Dividir Quadros')
    return assert(fieldOrder[state.tab],'Aba de moldura invalida')
end
function M.adjust(state,key,direction)
    assert(type(state)=='table' and state.kind=='frame'
        and (direction==1 or direction==-1),
        'Ajuste visual invalido')
    local allowed=false
    for _,id in ipairs(M.fieldsFor(state)) do
        if id==key then allowed=true;break end
    end
    local f=assert(M.fields[key],'Campo desconhecido')
    assert(allowed and type(state[key])=='number'
        and state[key]==state[key],
        'Campo nao aplicavel nesta aba')
    state[key]=math.max(f.min,math.min(f.max,
        state[key]+direction*f.step))
    return state[key]
end
local function panel(p)
    assert(type(p)=='table' and type(p.x)=='number'
        and type(p.y)=='number' and p.w>=420 and p.h>=440,
        'Painel visual invalido')
end
local function index(i,limit)
    assert(type(i)=='number' and i%1==0
        and i>=1 and i<=limit,'Indice de controle invalido')
end
function M.tabRect(p,i)
    panel(p);index(i,3)
    return {x=p.x+14+(i-1)*131,y=p.y+57,w=124,h=36}
end
function M.vectorPreview(p)
    panel(p)
    return {x=p.x+14,y=p.y+122,w=p.w-28,h=137}
end
function M.vectorAction(p,i)
    panel(p);index(i,2)
    return {x=p.x+14,y=p.y+275+(i-1)*48,w=p.w-28,h=35}
end
function M.frameRow(p,i)
    panel(p);index(i,3)
    return {x=p.x+14,y=p.y+122+(i-1)*53,w=p.w-28,h=46}
end
function M.frameStep(p,i,direction)
    local r=M.frameRow(p,i)
    assert(direction==1 or direction==-1,'Sentido de passo invalido')
    return {x=r.x+r.w-(direction==1 and 42 or 90),
        y=r.y+8,w=38,h=30}
end
function M.cutRect(p,i)
    panel(p);index(i,2)
    return {x=p.x+14+(i-1)*199,y=p.y+233,w=191,h=36}
end
function M.framePreview(p)
    panel(p)
    return {x=p.x+14,y=p.y+285,w=p.w-28,h=78}
end
function M.frameDisabledAction(p)
    panel(p)
    return {x=p.x+14,y=p.y+374,w=p.w-28,h=29}
end
function M.footer(p)
    panel(p)
    return {x=p.x+14,y=p.y+p.h-27,w=p.w-28,h=21}
end
return M
