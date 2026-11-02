-- Contrato publico do seletor de ferramentas: 1, 2 e 3 colunas.
-- Geometria Lua pura: hitboxes e paginacao independem do motor raster.
local Catalog=require('ibis_visual_tools')
local UI=require('compact_layout')
local Store=require('store')
local T={}
function T.run(root)
    local checks=0
    local function check(ok,message)
        checks=checks+1
        assert(ok,message)
    end
    local seen={}
    for _,dim in ipairs({{960,640},{1220,800},{1920,1080}}) do
        local w,h=dim[1],dim[2]
        for columns=1,3 do
            local p=UI.popup(w,h,'tools',columns)
            check(p.x>=0 and p.y>=0 and
                p.x+p.w<=w and p.y+p.h<=h-125,
                'Seletor fora da janela')
            local collected={}
            for page=1,Catalog.pages(columns) do
                local rows=Catalog.pageItems(columns,page)
                local rects={}
                for _,item in ipairs(rows) do
                    check(not collected[item.index],
                        'Categoria duplicada na paginacao')
                    collected[item.index]=true
                    local r=Catalog.grid(p,item.index,columns,page)
                    check(r and r.x>=p.x and r.y>=p.y+28 and
                        r.x+r.w<p.x+p.w and
                        r.y+r.h<=p.y+p.h-25,
                        'Categoria ultrapassa popup')
                    for _,prev in ipairs(rects) do
                        check(r.x>=prev.x+prev.w or
                            prev.x>=r.x+r.w or
                            r.y>=prev.y+prev.h or
                            prev.y>=r.y+r.h,
                            'Hitboxes sobrepostas')
                    end
                    rects[#rects+1]=r
                end
            end
            for i=1,#Catalog.entries do
                check(collected[i],'Categoria nao acessivel')
            end
            for index=1,3 do
                local r=Catalog.columnRect(p,index)
                check(r.x>=p.x and r.x+r.w<p.x+p.w-28
                    and r.y>=p.y and r.y+r.h<p.y+29,
                    'Controle de coluna colide com fechar')
            end
            if columns==1 then
                check(Catalog.pages(columns)==3,
                    'Uma coluna deve paginar as 15 ferramentas')
                for _,direction in ipairs({-1,1}) do
                    local r=Catalog.pageButton(p,direction)
                    check(r.y>p.y+315 and r.y+r.h<p.y+p.h-27,
                        'Navegador de pagina colide com ferramentas')
                end
                check(#Catalog.pageItems(1,3)==1,
                    'Ultima pagina deve mostrar a ferramenta 15')
            else
                check(Catalog.pages(columns)==1,
                    'Duas e tres colunas nao exigem paginacao')
            end
        end
    end
    for _,bad in ipairs({0,4,-1,'3'}) do
        check(not pcall(Catalog.pages,bad),'Colunas invalidas aceitas')
        check(not pcall(UI.popup,960,640,'tools',bad),
            'Popup aceitou colunas invalidas')
    end
    local store=Store.open(root)
    local prefs=store:getPreferences()
    prefs.toolPopupColumns=3
    store:setPreferences(prefs)
    check(Store.open(root):getPreferences().toolPopupColumns==3,
        'Numero de colunas nao foi persistido')
    check(not pcall(Catalog.pageItems,1,4),
        'Navegador aceitou pagina 4')
    return {suite='ibis-tool-popup-columns',passed=true,
        assertions=checks,columns={1,2,3}}
end
return T
