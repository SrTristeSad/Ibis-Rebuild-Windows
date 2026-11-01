-- Navegacao local no painel de Materiais, sem catalogo nem download.
-- A classificacao e inspirada nos tutoriais ibisPaint de Texturas e Manga.
-- Nao sao categorias extraidas do APK Android 14.1.2.
local M={}
M.categories={
    {id='all',label='Todos'},
    {id='cloth',label='Padrões de tecido'},
    {id='balloons',label='Balões mangá'},
    {id='backgrounds',label='Fundos'},
    {id='tracing-body',label='Corpo inteiro'},
    {id='tracing-mini',label='Miniaturas'},
    {id='tracing-parts',label='Partes do corpo'},
    {id='tracing-building',label='Construções'}
}
M.MAX_QUERY_CHARS=80
local byId={}
for _,item in ipairs(M.categories) do
    assert(not byId[item.id], 'Categoria de materiais repetida')
    byId[item.id]=item
end
function M.category(id) return byId[id] end
function M.new()
    return {category='all',query='',submittedQuery='',
        focused=false,searchCount=0}
end
function M.setCategory(state,id)
    assert(type(state)=='table' and M.category(id),
        'Categoria de materiais inválida')
    state.category=id
end
local function starts(s)
    local indices={}
    for i=1,#s do
        local b=s:byte(i)
        if b<128 or b>=192 then indices[#indices+1]=i end
    end
    return indices
end
function M.appendQuery(state,text)
    assert(type(state)=='table' and type(state.query)=='string'
        and type(text)=='string','Entrada de busca inválida')
    local input=text:gsub('[%c]',' ')
    local positions=starts(input)
    local count=#starts(state.query)
    for i,first in ipairs(positions) do
        if count>=M.MAX_QUERY_CHARS then break end
        local last=positions[i+1] and positions[i+1]-1 or #input
        state.query=state.query..input:sub(first,last)
        count=count+1
    end
    return state.query
end
function M.backspace(state)
    assert(type(state)=='table' and type(state.query)=='string')
    local positions=starts(state.query)
    if #positions>0 then
        state.query=state.query:sub(1,positions[#positions]-1)
    end
    return state.query
end
function M.submit(state)
    assert(type(state)=='table' and type(state.query)=='string')
    state.submittedQuery=state.query
    state.searchCount=(state.searchCount or 0)+1
    state.focused=false
    -- Nao ha itens originais ou de usuario no repositorio para buscar.
    return {}
end
function M.items(state)
    assert(type(state)=='table' and M.category(state.category))
    return {}
end
function M.canInsert() return false end
local function panel(p)
    assert(type(p)=='table' and type(p.x)=='number'
        and type(p.y)=='number' and p.w>=444 and p.h>=440,
        'Painel de materiais inválido')
end
function M.searchRect(p)
    panel(p)
    return {x=p.x+16,y=p.y+57,w=p.w-126,h=36}
end
function M.searchButton(p)
    panel(p)
    return {x=p.x+p.w-102,y=p.y+57,w=86,h=36}
end
function M.categoryRect(p,i)
    panel(p)
    assert(type(i)=='number' and i%1==0
        and i>=1 and i<=#M.categories,
        'Índice de categoria de materiais inválido')
    local col=(i-1)%3
    local row=math.floor((i-1)/3)
    return {x=p.x+16+col*138,y=p.y+111+row*44,
        w=128,h=37}
end
function M.emptyRect(p)
    panel(p)
    return {x=p.x+16,y=p.y+257,w=p.w-32,h=126}
end
function M.footerRect(p)
    panel(p)
    return {x=p.x+16,y=p.y+p.h-36,w=p.w-32,h=22}
end
return M
