-- Borrar/Desfoque/Caneta Especial: interface pura, sem motor de efeitos.
-- Base publica: ibisPaint tutoriais sobre parametros e caneta especial.
local M={}
M.types={smudge='Borrar',blur='Desfoque',special='Caneta especial'}
M.specials={
    {id='liquify',label='Liquify'},
    {id='lasso-fill',label='Preencher Laço'},
    {id='lasso-erase',label='Apagar Laço'},
    {id='copy-relative',label='Cópia relativa'},
    {id='copy-fixed',label='Cópia fixa'},
    {id='copy-move',label='Cópia móvel'}
}
M.liquifyModes={
    {id='drag',label='Arrastar'},
    {id='shrink',label='Encolher'},
    {id='expand',label='Expandir'},
    {id='smoothen',label='Suavizar'},
    {id='revert',label='Reverter'}
}
local specialById,modeById={},{}
for _,item in ipairs(M.specials) do
    assert(not specialById[item.id],'Especial duplicado')
    specialById[item.id]=item
end
for _,item in ipairs(M.liquifyModes) do
    assert(not modeById[item.id],'Modo Liquify duplicado')
    modeById[item.id]=item
end
function M.special(id) return specialById[id] end
function M.liquifyMode(id) return modeById[id] end
function M.new(kind)
    assert(M.types[kind],'Ferramenta de efeito desconhecida')
    return {kind=kind,diameter=24,opacity=100,strength=50,
        specialId='liquify',liquifyId='drag'}
end
function M.canApply() return false end
local ranges={
    diameter={min=1,max=256,step=1},
    opacity={min=0,max=100,step=5},
    strength={min=0,max=100,step=5}
}
function M.adjust(state,field,direction)
    local range=ranges[field]
    assert(type(state)=='table' and M.types[state.kind]
        and range and (direction==1 or direction==-1),
        'Ajuste de efeito invalido')
    if field=='strength' then
        assert(state.kind=='special' and state.specialId=='liquify',
            'Forca apenas para Liquify')
    else
        assert(state.kind~='special','Controle de pincel apenas para Borrar/Desfoque')
    end
    local old=assert(state[field])
    assert(type(old)=='number' and old==old,
        'Valor invalido no estado')
    state[field]=math.max(range.min,math.min(range.max,
        old+direction*range.step))
    return state[field]
end
function M.selectSpecial(state,id)
    assert(type(state)=='table' and state.kind=='special'
        and M.special(id),'Caneta especial inexistente')
    state.specialId=id
    return id
end
function M.selectLiquify(state,id)
    assert(type(state)=='table' and state.kind=='special'
        and state.specialId=='liquify' and M.liquifyMode(id),
        'Modo Liquify inexistente')
    state.liquifyId=id
    return id
end
local function panel(p)
    assert(type(p)=='table' and type(p.x)=='number'
        and type(p.y)=='number' and p.w>=420 and p.h>=440,
        'Painel de efeitos invalido')
end
local function idx(i,total)
    assert(type(i)=='number' and i%1==0
        and i>=1 and i<=total,'Indice de controle invalido')
end
function M.paintRow(p,i)
    panel(p);idx(i,2)
    return {x=p.x+16,y=p.y+95+(i-1)*73,w=p.w-32,h=59}
end
function M.paintButton(p,i,dir)
    local r=M.paintRow(p,i)
    assert(dir==1 or dir==-1,'Direcao invalida')
    return {x=r.x+r.w-(dir==1 and 42 or 90),
        y=r.y+24,w=40,h=30}
end
function M.paintPreview(p)
    panel(p)
    return {x=p.x+16,y=p.y+259,w=p.w-32,h=114}
end
function M.specialRect(p,i)
    panel(p);idx(i,#M.specials)
    local col=(i-1)%2
    local row=math.floor((i-1)/2)
    return {x=p.x+16+col*198,y=p.y+65+row*61,
        w=190,h=54}
end
function M.liquifyModeRect(p,i)
    panel(p);idx(i,#M.liquifyModes)
    local col=(i-1)%3
    local row=math.floor((i-1)/3)
    return {x=p.x+16+col*132,y=p.y+265+row*42,
        w=124,h=36}
end
function M.strengthRow(p)
    panel(p)
    return {x=p.x+16,y=p.y+363,w=p.w-32,h=35}
end
function M.strengthButton(p,dir)
    local r=M.strengthRow(p)
    assert(dir==1 or dir==-1)
    return {x=r.x+r.w-(dir==1 and 42 or 90),
        y=r.y+2,w=40,h=31}
end
function M.pendingRect(p)
    panel(p)
    return {x=p.x+16,y=p.y+261,w=p.w-32,h=132}
end
function M.footer(p)
    panel(p)
    return {x=p.x+16,y=p.y+p.h-29,w=p.w-32,h=23}
end
return M
