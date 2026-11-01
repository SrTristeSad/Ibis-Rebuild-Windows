-- Catalogo visual do ibisPaint para o shell de interface.
-- Referencia: selecao de ferramentas e barra nos tutoriais oficiais.
-- Nenhum asset proprietario; mapeia somente funcoes Lua existentes.
local M={}
M.entries={
    {id='transform',label='Transformar',icon='select',backend='select',partial=true},
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
function M.grid(p,index)
    assert(type(index)=='number' and index%1==0 and
        index>=1 and index<=#M.entries,'Indice da ferramenta inválido')
    local col=(index-1)%3
    local row=math.floor((index-1)/3)
    return {x=p.x+16+col*134,y=p.y+57+row*62,w=126,h=55}
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
