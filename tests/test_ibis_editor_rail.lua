package.path='app/?.lua;'..package.path
local Rail=require('ibis_editor_rail')
local Tools=require('ibis_visual_tools')
local Top=require('ibis_top_toolbar')
local Compact=require('compact_layout')
local Workspace=require('workspace_layout')
local T={}
function T.run()
    local checks=0
    local function check(c,message) checks=checks+1;assert(c,message)end
    for _,size in ipairs({{960,640},{1220,800},{1920,1080}}) do
        local w,h=size[1],size[2]
        local first=Rail.layout(w,h,1,#Tools.entries)
        check(first.x<=10 and first.y>=125,
            'Faixa nao esta no canto esquerdo do editor')
        local seen={}
        for page=1,first.pages do
            local rect=Rail.layout(w,h,page,#Tools.entries)
            local entries=Rail.entries(w,h,page,Tools.entries)
            check(#entries==rect.stop-rect.start+1,
                'Paginacao de ferramentas errada')
            local prev=rect.y
            for i,e in ipairs(entries) do
                check(e.index==rect.start+i-1 and
                    e.id==Tools.entries[e.index].id,
                    'Faixa mudou a ordem das ferramentas')
                check(not seen[e.id],'Ferramenta repetida')
                seen[e.id]=true
                check(e.x>=0 and e.x+e.w<=120
                    and e.y>=prev and e.y+e.h<=h-130,
                    'Faixa extrapola canvas seguro')
                check(Workspace.contains(w,h,true,e.x+e.w/2,
                    e.y+e.h/2,true),
                    'Clique lateral nao coincide com workspace')
                prev=e.y+e.h
            end
            local nav=Rail.navigation(w,h,page,#Tools.entries)
            if rect.pages>1 then
                check(nav~=nil and nav.y>=prev
                    and nav.y+nav.h<=h-130,
                    'Paginacao fora da area livre')
                check(nav.back==(page>1) and
                    nav.forward==(page<rect.pages),
                    'Setas de paginacao incorretas')
            else check(nav==nil,'Navegacao desnecessaria')end
        end
        for _,tool in ipairs(Tools.entries) do
            check(seen[tool.id],
                'Ferramenta desapareceu na resolucao '..w)
        end
        local dock=Compact.toolbar(w,h)
        local top=Top.toolbar(w,h)
        check(first.x+first.w<top[1].x
            and first.x+first.w<dock[1].x,
            'Faixa invade as barras de controle')
        check(not pcall(Rail.layout,w,h,0,#Tools.entries))
        check(not pcall(Rail.layout,w,h,first.pages+1,#Tools.entries))
        check(Rail.nextPage(w,h,1,#Tools.entries,-1)==1)
        check(Rail.nextPage(w,h,first.pages,#Tools.entries,1)==first.pages)
    end
    check(not pcall(Rail.layout,300,200,1,15))
    return {suite='ibis-editor-rail',passed=true,
        assertions=checks,all_15_tools_accessible=true}
end
return T
