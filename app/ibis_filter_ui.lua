-- Catalogo visual de filtros, sem processamento de imagens.
-- Categorias e nomes consultados nos tutoriais publicos do ibisPaint;
-- a disposicao exata do APK Android 14.1.2 nao foi comprovada.
local M={}
M.categories={
    {id='adjust',label='Ajustar cor',filters={
        {id='brightness',label='Brilho e contraste'},
        {id='hsl',label='Matiz / saturação'},
        {id='color-balance',label='Equilíbrio de cores'},
        {id='grayscale',label='Escala de cinza'},
        {id='invert',label='Inverter cores'},
        {id='posterize',label='Posterizar'},
        {id='curves',label='Curvas de tons'},
        {id='levels',label='Níveis'}}},
    {id='blur',label='Desfoque',filters={
        {id='gaussian',label='Desfoque gaussiano'},
        {id='motion',label='Desfoque de movimento'},
        {id='zoom',label='Desfoque de zoom'},
        {id='mosaic',label='Mosaico'},
        {id='unsharp',label='Máscara de nitidez'},
        {id='frosted',label='Vidro fosco'}}},
    {id='style',label='Estilo',filters={
        {id='stroke',label='Contorno'},
        {id='glow',label='Brilho externo'},
        {id='bevel',label='Chanfro'},
        {id='emboss',label='Relevo'},
        {id='shadow',label='Sombra projetada'}}},
    {id='draw',label='Desenhar',filters={
        {id='gradation',label='Gradação paralela'},
        {id='radial',label='Linhas radiais'},
        {id='speed',label='Linhas de velocidade'},
        {id='clouds',label='Nuvens'}}},
    {id='artistic',label='Artístico',filters={
        {id='chromatic',label='Aberração cromática'},
        {id='glitch',label='Glitch'},
        {id='noise',label='Ruído'},
        {id='retro',label='Jogo retrô'},
        {id='bloom',label='Bloom'}}},
    {id='pixelate',label='Pixelizar',filters={
        {id='crystal',label='Cristalizar'},
        {id='square',label='Pixels quadrados'},
        {id='triangle',label='Pixels triangulares'},
        {id='dots',label='Pontilhado'}}},
    {id='transform',label='Transformar',filters={
        {id='expansion',label='Expansão'},
        {id='fisheye',label='Olho de peixe'},
        {id='wave',label='Onda'},
        {id='twirl',label='Redemoinho'}}},
    {id='frame',label='Moldura',filters={
        {id='table',label='Tabela'},
        {id='blur-frame',label='Moldura desfocada'}}}
}
M.PAGE_SIZE=5
local categories,filters={},{}
for _,category in ipairs(M.categories) do
    assert(not categories[category.id],'Categoria de filtro duplicada')
    categories[category.id]=category
    for _,filter in ipairs(category.filters) do
        assert(not filters[filter.id],'Filtro duplicado')
        filters[filter.id]=filter
    end
end
function M.category(id) return categories[id] end
function M.filter(id) return filters[id] end
function M.canApply(id)
    -- Nenhum filtro dessa lista possui motor Lua nesta fase.
    return false
end
local function checkPanel(p)
    assert(type(p)=='table' and type(p.x)=='number' and
        type(p.y)=='number' and p.w>=420 and p.h>=440,
        'Painel de filtros inválido')
end
function M.categoryRect(p,index)
    checkPanel(p)
    assert(type(index)=='number' and index%1==0
        and index>=1 and index<=#M.categories,
        'Categoria fora da janela')
    return {x=p.x+12,y=p.y+58+(index-1)*39,w=126,h=34}
end
function M.filterRow(p,index)
    checkPanel(p)
    assert(type(index)=='number' and index%1==0
        and index>=1 and index<=M.PAGE_SIZE,
        'Linha de filtro inválida')
    return {x=p.x+151,y=p.y+60+(index-1)*54,w=p.w-163,h=49}
end
function M.pageCount(id)
    local category=assert(M.category(id),'Categoria de filtro inválida')
    return math.ceil(#category.filters/M.PAGE_SIZE)
end
function M.pageItems(id,page)
    local category=assert(M.category(id),'Categoria de filtro inválida')
    assert(type(page)=='number' and page%1==0 and
        page>=1 and page<=M.pageCount(id),
        'Página de filtros inválida')
    local first=(page-1)*M.PAGE_SIZE+1
    local result={}
    for i=first,math.min(#category.filters,first+M.PAGE_SIZE-1) do
        result[#result+1]=category.filters[i]
    end
    return result
end
return M
