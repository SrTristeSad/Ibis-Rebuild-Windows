package.path='app/?.lua;'..package.path
local Filters=require('ibis_filter_ui')
local UI=require('compact_layout')
local T={}
function T.run()
    local checks=0
    local function check(value,message)
        checks=checks+1
        assert(value,message)
    end
    check(#Filters.categories==8,'Categorias documentadas ausentes')
    check(Filters.PAGE_SIZE==5,'Capacidade da lista incorreta')
    local ids,all={},0
    for _,category in ipairs(Filters.categories) do
        check(Filters.category(category.id)==category,'Categoria não encontrada')
        local total=0
        for page=1,Filters.pageCount(category.id) do
            local items=Filters.pageItems(category.id,page)
            check(#items>0 and #items<=Filters.PAGE_SIZE,
                'Paginação de filtros inválida')
            for _,item in ipairs(items) do
                total=total+1;all=all+1
                check(not ids[item.id],'Filtro duplicado')
                ids[item.id]=true
                check(Filters.filter(item.id)==item,'Filtro não encontrado')
                check(type(item.label)=='string' and #item.label>0,
                    'Filtro sem identificação visual')
                check(not Filters.canApply(item.id),
                    'Filtro sem motor não pode modificar a obra')
            end
        end
        check(total==#category.filters,'Filtro omitido na paginação')
    end
    check(all>=35,'Catálogo visual pouco representativo')
    for _,size in ipairs({{960,640},{1220,800},{1920,1080}}) do
        local w,h=size[1],size[2]
        local p=UI.popup(w,h,'filters')
        check(p.w==420 and p.h==440 and p.x>=0 and p.y>=0 and
            p.x+p.w<=w and p.y+p.h<=h,
            'Janela de filtros extrapola o monitor')
        local rects={}
        for i=1,#Filters.categories do
            rects[#rects+1]=Filters.categoryRect(p,i)
        end
        for i=1,Filters.PAGE_SIZE do
            rects[#rects+1]=Filters.filterRow(p,i)
        end
        for i,a in ipairs(rects) do
            check(a.x>=p.x+8 and a.x+a.w<=p.x+p.w-8 and
                a.y>=p.y+54 and a.y+a.h<p.y+p.h-70,
                'Controle do catálogo fora de limites')
            for j=1,i-1 do
                local b=rects[j]
                check(a.x+a.w<=b.x or b.x+b.w<=a.x or
                    a.y+a.h<=b.y or b.y+b.h<=a.y,
                    'Controles de categoria ou filtro sobrepostos')
            end
        end
    end
    check(Filters.filter('unknown')==nil and
        not Filters.canApply('unknown'),'Filtro desconhecido editável')
    check(not pcall(Filters.pageCount,'unknown'))
    check(not pcall(Filters.pageItems,'blur',0))
    check(not pcall(Filters.pageItems,'blur',3))
    check(not pcall(Filters.categoryRect,{x=0,y=0,w=420,h=440},9))
    check(not pcall(Filters.filterRow,{x=0,y=0,w=420,h=440},6))
    return {suite='ibis-filter-ui',passed=true,assertions=checks,
        categories=#Filters.categories,filters=all,
        filters_operational=0}
end
return T
