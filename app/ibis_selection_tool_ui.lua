-- Navegacao visual das ferramentas Laco e Varinha Magica.
-- Os comandos abaixo NAO alteram selecoes reais, pixels nem o motor.
-- Referencias: tutorial oficial ibisPaint "Fine Tuning Using the Lasso"
-- e notas de versao 14.1 sobre a Varinha Magica.
local M={}
M.modes={
    {id='set',label='Definir'},
    {id='add',label='Adicionar'},
    {id='subtract',label='Subtrair'}
}
M.sources={
    {id='canvas',label='Tela inteira'},
    {id='current',label='Camada atual'}
}
M.toggles={
    {id='gap',label='Reconhecer lacunas'},
    {id='unpainted',label='Reconhecer áreas vazias'},
    {id='continuous',label='Seleção contínua'}
}
local modeById,sourceById,toggleById={},{},{}
for _,item in ipairs(M.modes) do modeById[item.id]=item end
for _,item in ipairs(M.sources) do sourceById[item.id]=item end
for _,item in ipairs(M.toggles) do toggleById[item.id]=item end
function M.new(kind)
    assert(kind=='wand' or kind=='lasso',
        'Tipo de selecao visual desconhecido')
    return {kind=kind,mode='set',source='canvas',
        tolerance=10,gap=false,unpainted=false,
        continuous=false}
end
function M.canApply(kind) return kind=='wand' end
function M.selectMode(state,id)
    assert(type(state)=='table' and modeById[id],
        'Modo de selecao visual invalido')
    state.mode=id
    return id
end
function M.selectSource(state,id)
    assert(type(state)=='table' and state.kind=='wand'
        and sourceById[id],'Referencia de varinha invalida')
    state.source=id
    return id
end
function M.adjustTolerance(state,delta)
    assert(type(state)=='table' and state.kind=='wand'
        and type(state.tolerance)=='number'
        and (delta==1 or delta==-1),
        'Controle de tolerancia invalido')
    state.tolerance=math.max(0,math.min(100,
        state.tolerance+5*delta))
    return state.tolerance
end
function M.toggle(state,id)
    assert(type(state)=='table' and state.kind=='wand'
        and toggleById[id] and type(state[id])=='boolean',
        'Opcao de varinha invalida')
    state[id]=not state[id]
    return state[id]
end
local function panel(p)
    assert(type(p)=='table' and type(p.x)=='number'
        and type(p.y)=='number' and p.w>=420 and p.h>=440,
        'Painel de selecao visual invalido')
end
local function valid(i,count)
    assert(type(i)=='number' and i%1==0
        and i>=1 and i<=count,'Indice de controle invalido')
end
function M.modeRect(p,index)
    panel(p);valid(index,#M.modes)
    return {x=p.x+14+(index-1)*131,y=p.y+60,w=124,h=36}
end
function M.sourceRect(p,index)
    panel(p);valid(index,#M.sources)
    return {x=p.x+14+(index-1)*199,y=p.y+135,w=191,h=34}
end
function M.toleranceRow(p)
    panel(p)
    return {x=p.x+14,y=p.y+183,w=p.w-28,h=34}
end
function M.toleranceButton(p,delta)
    panel(p)
    assert(delta==1 or delta==-1,'Sentido invalido')
    local row=M.toleranceRow(p)
    return {x=row.x+row.w-(delta==1 and 42 or 90),
        y=row.y+1,w=40,h=32}
end
function M.toggleRect(p,index)
    panel(p);valid(index,#M.toggles)
    return {x=p.x+14,y=p.y+229+(index-1)*39,
        w=p.w-28,h=34}
end
function M.lassoIllustration(p)
    panel(p)
    return {x=p.x+14,y=p.y+119,w=p.w-28,h=201}
end
function M.actionRect(p,index)
    panel(p);valid(index,2)
    return {x=p.x+14+(index-1)*199,y=p.y+357,
        w=191,h=34}
end
function M.footerRect(p)
    panel(p)
    return {x=p.x+14,y=p.y+p.h-32,w=p.w-28,h=23}
end
return M
