package.path='app/?.lua;'..package.path
local G=require('ibis_gallery_ui')
local Shell=require('ibis_gallery_shell')
local T={}
function T.run()
    local checks=0
    local function eq(cond,msg) checks=checks+1;assert(cond,msg) end
    eq(#G.FILTERS==3,'Galeria precisa de tres filtros')
    eq(#G.PRESETS==4,'Dialogo precisa preservar quatro formatos')
    eq(#G.OFFICIAL_PRESETS==4,
        'Nova aba deve ter quatro tamanhos de referencia')
    eq(#G.PRESET_TABS==2,'Nova tela precisa de duas categorias')
    eq(G.presetList('basic')==G.PRESETS)
    eq(G.presetList('formats')==G.OFFICIAL_PRESETS)
    eq(not pcall(G.presetList,'invalid'),
        'Categoria invalida foi aceita')
    for _,kind in ipairs({'folder','work'}) do
        eq(G.filter('all',kind),'Tudo deve mostrar desenhos e pastas')
        eq(G.filter(kind=='work' and 'works' or 'folders',kind),
            'Filtro especializado deve manter tipo')
        eq(not G.filter(kind=='work' and 'folders' or 'works',kind),
            'Filtro especializado nao pode misturar categorias')
    end
    local sizes={{960,640},{1220,800},{1920,1080}}
    for _,size in ipairs(sizes) do
        local r=G.dialog(size[1],size[2])
        eq(r.x>=0 and r.y>=0 and r.x+r.w<=size[1]
            and r.y+r.h<=size[2],'Dialogo de tela fora da janela')
        local fields=G.fields(r)
        eq(#fields==3,'Nome largura altura exigidos')
        for i,field in ipairs(fields) do
            eq(field.x>=r.x and field.x+field.w<=r.x+r.w and
                field.y>=r.y and field.y+field.h<r.y+r.h-120,
                'Campo de tela fora do painel')
            if i>1 then
                eq(field.y>=fields[i-1].y+fields[i-1].h,
                    'Campos de texto sobrepostos')
            end
        end
        local preview=G.preview(r)
        eq(preview.x>fields[1].x+fields[1].w,
            'Previa da tela encobre entradas')
        local tabs={}
        for i=1,2 do
            local tab=G.tabRect(r,i)
            tabs[i]=tab
            eq(tab.x>=r.x and tab.y>=r.y and
                tab.x+tab.w<=r.x+r.w and
                tab.y+tab.h<r.y+351,
                'Aba invade preset ou borda do dialogo')
        end
        eq(tabs[1].x+tabs[1].w<tabs[2].x,
            'Abas se sobrepoem')
        for _,category in ipairs({'basic','formats'}) do
        for index,preset in ipairs(G.presetList(category)) do
            local b=G.presetButton(r,index)
            local v=G.aspectViewport(r,tostring(preset.w),tostring(preset.h))
            eq(v~=nil,'Preset de tela invalido')
            eq(v.x>=preview.x and v.y>=preview.y and
                v.x+v.w<=preview.x+preview.w and
                v.y+v.h<=preview.y+preview.h,'Preview ultrapassou area')
            eq(v.y>=preview.y+37 and v.y+v.h<=preview.y+preview.h-8,
                'Prévia quadriculada cobre título ou margem inferior')
            eq(v.w>0 and v.h>0,'Canvas de preview zerado')
            eq(math.abs(v.w/v.h-preset.w/preset.h)<.02,
                'Previa nao respeitou aspecto')
            eq(b.y>preview.y+preview.h and
                b.x>=r.x and b.x+b.w<=r.x+r.w,
                'Preset sobrepoe preview ou sai da janela')
            if index>1 then
                local before=G.presetButton(r,index-1)
                eq(before.x+before.w<b.x,'Presets se sobrepoem')
            end
        end
        end
        eq(G.aspectViewport(r,'2049','512')==nil,
            'Dimensoes maiores que o motor aceitas')
        eq(G.aspectViewport(r,'512','0')==nil,
            'Dimensoes zero aceitas')
        eq(G.aspectViewport(r,'texto','512')==nil,
            'Dimensoes nao numericas aceitas')
        eq(G.aspectViewport(r,'1.2','512')==nil,
            'Dimensoes fracionarias aceitas')
    end

    -- A galeria original usa miniaturas em grade e permite rolagem.
    for _,size in ipairs(sizes) do
        local w,h=size[1],size[2]
        local l=Shell.layout(w,h)
        eq(l.top>54 and l.bottom==h-58,
            'Galeria invade cabecalho ou rodape')
        local seen={}
        for i=1,l.cols*4 do
            local r=Shell.card(w,h,i,0)
            eq(r.x>=0 and r.x+r.w<=w,
                'Miniatura extrapola horizontalmente')
            eq(r.preview.x>=r.x and
                r.preview.x+r.preview.w<=r.x+r.w and
                r.titleY>r.preview.y+r.preview.h,
                'Miniatura cruza titulo')
            seen[#seen+1]=r
            if i>1 and (i-1)%l.cols~=0 then
                eq(r.x>seen[i-1].x+seen[i-1].w,
                    'Miniaturas se sobrepoem')
            end
        end
        local count=l.cols*8
        local max=Shell.maxScroll(w,h,count)
        eq(max>0,'Galeria longa nao rola')
        eq(Shell.scroll(w,h,count,0,-999)==max,
            'Scroll nao chega ao fim')
        eq(Shell.scroll(w,h,count,max,999)==0,
            'Scroll nao retorna ao inicio')
        local r=Shell.card(w,h,count,max)
        eq(r.visible and r.y+r.h<=l.bottom,
            'Ultima miniatura nao aparece por inteiro')
        eq(Shell.hit(w,h,count,max,r.x+10,r.y+10),
            'Ultima miniatura nao pode ser clicada')
        eq(not Shell.hit(w,h,1,max,0,0),
            'Galeria captura ponteiro fora da viewport')
        local popup=Shell.newMenu(w,h)
        for i=1,3 do
            local action=Shell.newOption(popup,i)
            eq(action.y>=popup.y and
                action.y+action.h<=popup.y+popup.h and
                action.y+action.h<l.footerY,
                'Menu de criacao sobrepoe rodape')
        end
    end
    -- Seleção em lote: somente operações de estado são habilitadas.
    local selectionFolders={{id='a'},{id='b'}}
    local selectionProjects={{id='c'},{id='d'},{id='e'}}
    local keys=Shell.selectionKeys(selectionFolders,
        selectionProjects,'all')
    eq(#keys==5 and keys[1]=='f:a' and keys[3]=='p:c',
        'Pastas e obras precisam de namespaces diferentes')
    eq(#Shell.selectionKeys(selectionFolders,
        selectionProjects,'works')==3)
    eq(#Shell.selectionKeys(selectionFolders,
        selectionProjects,'folders')==2)
    eq(not pcall(Shell.selectionKeys,{},{} ,'invalid'))
    local selected=Shell.selectAll(keys)
    eq(Shell.selectionCount(selected,keys)==5,
        'Todos nao marcou o catalogo')
    selected['p:c']=nil
    eq(Shell.selectionCount(selected,keys)==4,
        'Desmarcar item falhou')
    eq(Shell.selectionCount({},keys)==0)
    eq(Shell.selectionCount({['p:unseen']=true},keys)==0,
        'Itens filtrados ou inexistentes nao podem ser contados')
    eq(Shell.selectionCount(Shell.selectAll({}),{})==0)
    eq(Shell.selectionAvailable('all') and
        Shell.selectionAvailable('clear') and
        not Shell.selectionAvailable('move') and
        not Shell.selectionAvailable('delete'),
        'Acoes destrutivas foram declaradas funcionais')
    eq(not pcall(Shell.selectionAvailable,'unknown'))
    for _,size in ipairs(sizes) do
        local w,h=size[1],size[2]
        local bar=Shell.layout(w,h)
        local previous
        for _,id in ipairs({'all','clear','move','delete'}) do
            local rect=Shell.selectionAction(w,h,id)
            eq(rect.x>=400 and rect.y>=bar.footerY and
                rect.x+rect.w<=w-8 and rect.y+rect.h<=h,
                'Comando de selecao fora do rodape')
            if previous then
                eq(rect.x>previous.x+previous.w,
                    'Comandos de selecao sobrepostos')
            end
            previous=rect
        end
    end
    eq(G.preset('square').w==512 and G.preset('portrait').h==1920)
    eq(G.preset('ibis-square').w==768)
    eq(G.preset('ibis-portrait').w==768
        and G.preset('ibis-portrait').h==1024)
    eq(G.preset('ibis-story').w==720
        and G.preset('ibis-story').h==1280)
    eq(G.preset('ibis-a4').w==1240
        and G.preset('ibis-a4').h==1754)
    eq(not pcall(G.tabRect,G.dialog(960,640),3))
    eq(G.preset('nonexistent')==nil)
    eq(not pcall(G.filter,'invalid','work'))
    eq(not pcall(G.presetButton,{x=0,y=0},5))
    return {suite='ibis-gallery-canvas-dialog',passed=true,
        assertions=checks,filter_without_data_mutation=true,
        presets_within_raster_limits=true,preview_aspect=true}
end
return T
