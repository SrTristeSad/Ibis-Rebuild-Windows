-- Centralized desktop toolbar registry. Native tool behavior stays in main.lua.
-- Keys 1-8 work without modifiers only when editing an open document.
local Tools={}
Tools.items={
    {key='1',id='inspect',label='Ver',hint='Navegar sem desenhar'},
    {key='2',id='pixel',label='Pixel',hint='Pintar pixel isolado'},
    {key='3',id='brush',label='Pincel',hint='Desenho livre e pressão'},
    {key='4',id='erase',label='Borracha',hint='Apagar na camada ativa'},
    {key='5',id='fill',label='Balde',hint='Preenchimento por região'},
    {key='6',id='select',label='Seleção',hint='Selecionar e transformar'},
    {key='7',id='shape',label='Formas',hint='Retângulos, elipses e linhas'},
    {key='8',id='picker',label='Conta-gotas',hint='Capturar a cor RGBA'}
}
local byKey={}
local byId={}
for _,item in ipairs(Tools.items) do
    assert(not byKey[item.key] and not byId[item.id],
        'Atalho e ferramenta devem ser únicos')
    byKey[item.key]=item
    byId[item.id]=item
end
function Tools.fromKey(key)
    return byKey[key]
end
function Tools.fromId(id)
    return byId[id]
end
function Tools.isPainting(id)
    return id=='brush' or id=='erase'
end
function Tools.panelFor(id)
    if id=='brush' or id=='erase' or id=='fill' then return 'brush' end
    return nil
end
return Tools
