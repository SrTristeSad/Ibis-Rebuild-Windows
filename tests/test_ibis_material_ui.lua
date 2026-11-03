package.path='app/?.lua;'..package.path
local Material=require('ibis_material_ui')
local Compact=require('compact_layout')
local T={}
function T.run()
    local tests=0
    local function check(v,msg) tests=tests+1;assert(v,msg) end
    local order={'all','cloth','balloons','backgrounds',
        'tracing-body','tracing-mini','tracing-parts','tracing-building'}
    check(#Material.categories==#order,'Categorias visuais ausentes')
    local state=Material.new()
    check(state.category=='all' and state.query=='' and not state.focused)
    for i,id in ipairs(order) do
        check(Material.categories[i].id==id and
            Material.category(id)==Material.categories[i],
            'Ordem das categorias alterada')
        Material.setCategory(state,id)
        check(state.category==id,'Categoria de materiais nao selecionada')
        check(#Material.items(state)==0 and not Material.canInsert(),
            'Nao inventar catalogo e insercao de materiais')
    end
    check(not pcall(Material.setCategory,state,'unknown'))
    check(Material.category('unknown')==nil)
    check(Material.appendQuery(state,'céu')=='céu',
        'Busca nao preservou UTF-8')
    check(Material.backspace(state)=='cé','Backspace UTF-8 falhou')
    check(Material.appendQuery(state,'u')=='céu')
    check(#Material.submit(state)==0 and state.submittedQuery=='céu'
        and state.searchCount==1,'Busca local vazia inventou resultados')
    check(Material.appendQuery(state,'\nB')=='céu B',
        'Controle de texto nao normalizado')
    local fresh=Material.new()
    local filled=Material.appendQuery(fresh,string.rep('á',90))
    check(#filled==Material.MAX_QUERY_CHARS*2
        and Material.appendQuery(fresh,'X')==filled,
        'Entrada excedeu limite Unicode')
    for _,dim in ipairs({{960,640},{1220,800},{1920,1080}}) do
        local w,h=dim[1],dim[2]
        local p=Compact.popup(w,h,'materials')
        check(p.w==444 and p.h==440 and p.x>=w/2
            and p.x+p.w<=w and p.y>=130 and
            p.y+p.h<h-48,'Janela de materiais nao cabe')
        local search,submit=Material.searchRect(p),
            Material.searchButton(p)
        local empty,footer=Material.emptyRect(p),Material.footerRect(p)
        check(search.x>=p.x+12 and search.x+search.w<submit.x
            and submit.x+submit.w<=p.x+p.w-12
            and search.y==submit.y and search.h==submit.h,
            'Busca e seu botao se sobrepoem')
        local cells={}
        for i=1,#Material.categories do
            local a=Material.categoryRect(p,i)
            check(a.x>=p.x+12 and a.x+a.w<=p.x+p.w-12
                and a.y>=search.y+search.h
                and a.y+a.h<empty.y,
                'Categorias fora da area visual')
            for _,b in ipairs(cells) do
                check(a.x+a.w<=b.x or b.x+b.w<=a.x
                    or a.y+a.h<=b.y or b.y+b.h<=a.y,
                    'Botoes de categorias sobrepostos')
            end
            cells[#cells+1]=a
        end
        check(empty.y>cells[#cells].y+cells[#cells].h
            and empty.y+empty.h<footer.y
            and footer.y+footer.h<p.y+p.h,
            'Estado vazio sobreposto ao rodape')
    end
    check(not pcall(Material.categoryRect,{x=0,y=0,w=444,h=440},9))
    check(not pcall(Material.searchRect,{x=0,y=0,w=318,h=222}))
    check(not pcall(Material.items,{category='invalid'}))
    return {suite='ibis-material-ui',passed=true,assertions=tests,
        material_count=0,insertions_available=false}
end
return T
