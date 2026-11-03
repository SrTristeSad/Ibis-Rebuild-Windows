package.path='app/?.lua;'..package.path
local Rail=require('ibis_editor_rail')
local Tools=require('ibis_visual_tools')
local Top=require('ibis_top_toolbar')
local Compact=require('compact_layout')
local Workspace=require('workspace_layout')
local T={}
function T.run()
    local checks=0
    local function check(ok,msg)checks=checks+1;assert(ok,msg)end
    for _,dim in ipairs({{960,640},{1220,800},{1920,1080}}) do
        local w,h=dim[1],dim[2]
        for _,position in ipairs({'left','right'}) do
            local root=Rail.layout(w,h,1,#Tools.entries,position)
            check(root.w==68 and root.columns==1 and
                root.cell==64 and root.row==39,
                'PC precisa de coluna unica de glifos e rotulos')
            check(root.pages==(h==640 and 2 or 1),
                'Quinze itens devem paginar apenas em janela pequena')
            check(Rail.clampPage(w,h,8,#Tools.entries,position)==root.pages,
                'Resize nao limitou pagina')
            check(root.x>=0 and root.x+root.w<=w and
                root.y>=10 and root.y<90,
                'Faixa ficou fora da viewport')
            if position=='right' then
                check(root.x>=w-80 and root.y>=64,
                    'Faixa direita sobrepoe barra superior')
            else
                check(root.x<=10,'Faixa esquerda deslocada')
            end
            local seen={}
            for page=1,root.pages do
                local rect=Rail.layout(w,h,page,#Tools.entries,position)
                local entries=Rail.entries(w,h,page,Tools.entries,position)
                check(#entries==rect.stop-rect.start+1,
                    'Numero incorreto na pagina')
                local nav=Rail.navigation(w,h,page,#Tools.entries,position)
                if rect.pages==1 then
                    check(nav==nil,'Controle de pagina fantasma')
                else
                    check(nav and nav.y+nav.h<=h-130 and
                        nav.back==(page>1) and
                        nav.forward==(page<rect.pages),
                        'Navegacao fora da faixa ou estado errado')
                end
                for i,item in ipairs(entries) do
                    check(item.index==rect.start+i-1 and
                        item.id==Tools.entries[item.index].id and
                        item.label==Tools.entries[item.index].label,
                        'Ordem dos 15 comandos alterada')
                    check(type(item.shortLabel)=='string' and
                        #item.shortLabel>0,'Rótulo ausente')
                    check(not seen[item.id],'Comando duplicado')
                    seen[item.id]=true
                    check(item.x==rect.x+Rail.MARGIN and
                        item.y==rect.y+(i-1)*rect.row and
                        item.w==Rail.CELL and item.h==Rail.ROW,
                        'Hitbox e desenho nao coincidem')
                    check(item.x+item.w<=rect.x+rect.w and
                        item.y+item.h<=h-130,
                        'Comando invade faixa de controles inferiores')
                    check(Workspace.contains(w,h,true,
                        item.x+item.w/2,item.y+item.h/2,true),
                        'Comando fora da area do editor')
                    if i>1 then
                        local prev=entries[i-1]
                        check(item.x==prev.x and
                            item.y>=prev.y+prev.h,
                            'Itens da coluna se sobrepoem')
                    end
                end
                check(Rail.nextPage(w,h,page,#Tools.entries,1,position)
                    ==math.min(root.pages,page+1),
                    'Proxima pagina invalida')
            end
            for _,entry in ipairs(Tools.entries) do
                check(seen[entry.id],
                    'Ferramenta perdida no rail '..position)
            end
            -- Nenhum item pode ocupar a segunda coluna da A39.
            local first=Rail.entries(w,h,1,Tools.entries,position)[1]
            local oldX=position=='left' and first.x+75 or first.x-75
            local oldY=first.y+first.h/2
            for page=1,root.pages do
                for _,item in ipairs(Rail.entries(w,h,page,
                    Tools.entries,position)) do
                    check(not (oldX>=item.x and
                        oldX<item.x+item.w and
                        oldY>=item.y and oldY<item.y+item.h),
                        'Segunda coluna antiga voltou')
                end
            end
        end
        local rail=Rail.layout(w,h,1,#Tools.entries)
        local top=Top.toolbar(w,h)
        local dock=Compact.toolbar(w,h)
        check(rail.x+rail.w<top[1].x and
            rail.y+rail.rows*rail.row<dock[1].y,
            'Faixa invade topo ou rodape')
    end
    for _,position in ipairs({'left','right'}) do
        for _,dim in ipairs({{960,640},{1220,800},{1920,1080}}) do
            local w,h=dim[1],dim[2]
            local root=Rail.layout(w,h,1,43,position)
            check(root.pages>=2,'Catalogo extenso nao pagina')
            local total=0
            for page=1,root.pages do
                local r=Rail.layout(w,h,page,43,position)
                local nav=Rail.navigation(w,h,page,43,position)
                check(nav and nav.y+nav.h<=h-130,
                    'Paginacao estendida invade ajustes')
                total=total+r.stop-r.start+1
            end
            check(total==43,'Paginacao perdeu entradas')
        end
    end
    check(not pcall(Rail.layout,960,640,1,15,'popup'))
    check(not pcall(Rail.layout,300,200,1,15))
    check(not pcall(Rail.clampPage,960,640,0,15))
    check(not pcall(Rail.layout,960,640,0,15))
    return {suite='ibis-editor-rail',passed=true,
        assertions=checks,all_15_tools_accessible=true,
        pc_single_column=true,compact_pages=true}
end
return T
