-- Catalogo visual do ibisPaint para o shell de interface.
-- Referencia: selecao de ferramentas e barra nos tutoriais oficiais.
-- Nenhum asset proprietario; mapeia somente funcoes Lua existentes.
local M={}
M.entries={
    {id='transform',label='Transformar',icon='select',backend=nil},
    {id='wand',label='Vara mágica',icon='magic',backend=nil},
    {id='lasso',label='Laço',icon='lasso',backend=nil},
    {id='filter',label='Filtro',icon='filter',backend=nil},
    {id='brush',label='Pincel',icon='brush',backend='brush'},
    {id='eraser',label='Borracha',icon='erase',backend='erase'},
    {id='smudge',label='Borrar',icon='smudge',backend=nil},
    {id='blur',label='Desfoque',icon='blur',backend=nil},
    {id='special',label='Caneta especial',icon='special',backend=nil},
    {id='bucket',label='Balde',icon='fill',backend='fill'},
    {id='vector',label='Vetor',icon='vector',backend=nil},
    {id='text',label='Texto',icon='text-tool',backend=nil},
    {id='frame',label='Dividir quadros',icon='frame-divider',backend=nil},
    {id='picker',label='Conta-gotas',icon='picker',backend='picker'},
    {id='canvas',label='Tela',icon='canvas-tool',backend='inspect'}
}
local byId={}
for _,entry in ipairs(M.entries) do
    assert(not byId[entry.id], 'Ferramenta visual repetida')
    byId[entry.id]=entry
end
function M.get(id) return byId[id] end
-- A documentacao oficial permite 1, 2 ou 3 colunas no popup.
-- Uma coluna pagina os 15 itens: nunca desenha fora da viewport.
function M.pages(columns)
    assert(columns==1 or columns==2 or columns==3,
        'Numero de colunas invalido')
    return columns==1 and 3 or 1
end
function M.pageItems(columns,page)
    local pages=M.pages(columns)
    assert(type(page)=='number' and page%1==0 and
        page>=1 and page<=pages,'Pagina do seletor invalida')
    local first=columns==1 and (page-1)*7+1 or 1
    local last=columns==1 and math.min(first+6,#M.entries)
        or #M.entries
    local result={}
    for i=first,last do
        result[#result+1]={index=i,entry=M.entries[i]}
    end
    return result
end
function M.grid(p,index,columns,page)
    assert(type(index)=='number' and index%1==0 and
        index>=1 and index<=#M.entries,'Indice da ferramenta inválido')
    columns=columns or 2
    page=page or 1
    M.pageItems(columns,page) -- valida quantidade de colunas e pagina
    local first=columns==1 and (page-1)*7+1 or 1
    local visible=columns==1 and 7 or #M.entries
    local position=index-first+1
    if position<1 or position>visible then return nil end
    local col=(position-1)%columns
    local row=math.floor((position-1)/columns)
    return {x=p.x+10+col*111,y=p.y+29+row*41,
        w=columns==1 and p.w-20 or 106,h=39}
end
function M.columnRect(p,index)
    assert(index==1 or index==2 or index==3,
        'Opcao de coluna invalida')
    return {x=p.x+p.w-116+(index-1)*28,y=p.y+4,w=24,h=22}
end
function M.pageButton(p,direction)
    assert(direction==1 or direction==-1,
        'Direcao de navegacao invalida')
    return {x=p.x+(direction==-1 and 14 or p.w-43),
        y=p.y+p.h-58,w=29,h=26}
end
function M.select(id,onBackend)
    local entry=assert(M.get(id),'Ferramenta desconhecida')
    if entry.backend then
        assert(type(onBackend)=='function','Callback do motor inválido')
        return onBackend(entry.backend),entry
    end
    return false,entry
end
return M
