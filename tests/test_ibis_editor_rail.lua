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
        check(first.x<=10 and first.y>=10 and first.y<=30,
            'Faixa nao esta no canto esquerdo do editor')
        check(first.w==136 and first.columns==2 and first.cell==64,
            'Seletor nao possui duas colunas compactas')
        for _,position in ipairs({'left','right'}) do
            local root=Rail.layout(w,h,1,#Tools.entries,position)
            check(root.rows==8 and root.pages==1,
                'Quinze ferramentas devem ocupar oito fileiras')
            if position=='right' then
                check(root.x+root.w<=w and root.x>=w-150
                    and root.y>=64,'Faixa direita invade barra superior')
            end
            local seen={}
            for page=1,root.pages do
                local rect=Rail.layout(w,h,page,#Tools.entries,position)
                local entries=Rail.entries(w,h,page,Tools.entries,position)
                check(#entries==rect.stop-rect.start+1,
                    'Paginacao de ferramentas errada')
                for i,e in ipairs(entries) do
                    local row=math.floor((i-1)/2)
                    local col=(i-1)%2
                    check(e.index==rect.start+i-1 and
                        e.id==Tools.entries[e.index].id and
                        e.label==Tools.entries[e.index].label,
                        'Faixa mudou catalogo ou ordem de ferramentas')
                    check(type(e.shortLabel)=='string' and
                        #e.shortLabel>0,'Legenda de ferramenta vazia')
                    check(not seen[e.id],'Ferramenta duplicada')
                    seen[e.id]=true
                    check(e.x==rect.x+Rail.MARGIN+
                        col*(Rail.CELL+Rail.GAP) and
                        e.y==rect.y+row*rect.row and
                        e.w==Rail.CELL and e.h==Rail.ROW,
                        'Geometria visual e de clique nao coincide')
                    check(e.x>=rect.x and
                        e.x+e.w<=rect.x+rect.w and
                        e.y+e.h<=h-130,
                        'Faixa invade area de ajustes inferiores')
                    check(Workspace.contains(w,h,true,e.x+e.w/2,
                        e.y+e.h/2,true),
                        'Clique lateral fora do workspace')
                    if i>1 then
                        local prev=entries[i-1]
                        if col==1 then
                            check(prev.y==e.y and
                                prev.x+prev.w<e.x,
                                'Duas colunas se sobrepoem')
                        else
                            check(e.y>=prev.y+prev.h,
                                'Fileiras sucessivas se sobrepoem')
                        end
                    end
                end
                local nav=Rail.navigation(w,h,page,#Tools.entries,position)
                check(nav==nil,'Quinze itens nao precisam paginacao')
            end
            for _,tool in ipairs(Tools.entries) do
                check(seen[tool.id],
                    'Ferramenta perdida em '..position..' '..w)
            end
            -- Ultima fileira impar possui somente Tela à esquerda;
            -- não deve existir uma ferramenta fantasma à direita.
            local last=Rail.entries(w,h,1,Tools.entries,position)[15]
            local blankX=last.x+Rail.CELL+Rail.GAP+Rail.CELL/2
            local blankY=last.y+last.h/2
            local occupied=false
            for _,entry in ipairs(Rail.entries(w,h,1,Tools.entries,position)) do
                if blankX>=entry.x and blankX<entry.x+entry.w and
                    blankY>=entry.y and blankY<entry.y+entry.h then
                    occupied=true
                end
            end
            check(not occupied,'Area vazia virou ferramenta invisivel')
        end
        check(not pcall(Rail.layout,w,h,1,#Tools.entries,'popup'),
            'Popup nao deve virar faixa lateral')
        local dock=Compact.toolbar(w,h)
        local top=Top.toolbar(w,h)
        check(first.x+first.w<top[1].x
            and first.x+first.w<dock[1].x,
            'Faixa invade barras de controle')
        check(not pcall(Rail.layout,w,h,0,#Tools.entries))
        check(not pcall(Rail.layout,w,h,first.pages+1,#Tools.entries))
        check(Rail.nextPage(w,h,1,#Tools.entries,-1)==1)
        check(Rail.nextPage(w,h,first.pages,#Tools.entries,1)==first.pages)
    end
    -- Catálogos futuros maiores ainda paginam sem cortar controles.
    for _,position in ipairs({'left','right'}) do
        for _,size in ipairs({{960,640},{1220,800},{1920,1080}}) do
            local w,h=size[1],size[2]
            local first=Rail.layout(w,h,1,43,position)
            check(first.pages>=2,'Catalogo estendido nao pagina')
            local total=0
            for page=1,first.pages do
                local r=Rail.layout(w,h,page,43,position)
                local nav=Rail.navigation(w,h,page,43,position)
                check(nav~=nil and nav.y==r.y+r.rows*r.row and
                    nav.y+nav.h<=h-130,
                    'Navegacao da faixa invade ajuste inferior')
                check(nav.back==(page>1) and
                    nav.forward==(page<first.pages),
                    'Navegacao indica pagina incorreta')
                total=total+r.stop-r.start+1
            end
            check(total==43,'Paginacao removeu itens')
            check(Rail.nextPage(w,h,1,43,1,position)==2,
                'Avanco do seletor nao altera pagina')
            check(Rail.nextPage(w,h,first.pages,43,1,position)
                ==first.pages,'Ultima pagina extrapola limite')
        end
    end
    check(not pcall(Rail.layout,300,200,1,15))
    return {suite='ibis-editor-rail',passed=true,
        assertions=checks,all_15_tools_accessible=true,
        two_column_rail=true,fit_960_640=true}
end
return T
