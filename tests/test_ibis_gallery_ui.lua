package.path='app/?.lua;'..package.path
local G=require('ibis_gallery_ui')
local Shell=require('ibis_gallery_shell')
local Retention=require('ibis_deleted_retention')
local T={}
function T.run()
    local checks=0
    local function eq(cond,msg) checks=checks+1;assert(cond,msg) end
    eq(Retention.SECONDS==2592000,'Janela de 30 dias incorreta')
    local clock=1700000000
    eq(Retention.label(clock,clock)=='30 dias restantes',
        'Dia da exclusao incorreto')
    eq(Retention.label(clock,clock+29*86400)=='1 dia restante',
        'Ultimo dia incorreto')
    eq(Retention.label(clock,clock+30*86400)==
        'Prazo vencido · arquivo preservado',
        'Expiracao nao deve afirmar eliminacao automatica')
    eq(Retention.status(clock,clock-86400).remainingDays==30,
        'Relogio regressivo ampliou prazo acima do teto')
    eq(Retention.status(clock,clock+31*86400).expired,
        'Prazo vencido nao sinalizado')
    eq(not pcall(Retention.status,-1,clock),
        'Timestamp invalido foi aceito')
    local drag=Shell.dragBegin('p:p_first',40,77,10)
    eq(not Shell.dragAdvance(drag,44,80,10.1)
        and not drag.active and not drag.moved,
        'Short click cannot become a drag')
    eq(Shell.dragAdvance(drag,44,80,10.6) and drag.active,
        'Long hold did not activate dragging')
    local moving=Shell.dragBegin('f:f_folder',40,77,10)
    eq(not Shell.dragAdvance(moving,200,77,10.1)
        and moving.moved and not moving.active,
        'Early movement should not activate reorder')
    local items={{key='p:p_a'},{key='f:f_b'},{key='p:p_c'}}
    local rect=Shell.card(960,640,2,0)
    eq(Shell.dragTarget(960,640,0,items,
        rect.x+8,rect.y+8)=='f:f_b',
        'Drop hit test lost mixed-order folder')
    eq(Shell.dragTarget(960,640,0,items,5,5)==nil,
        'Drop outside grid accepted')
    eq(not pcall(Shell.dragBegin,'bad',1,2,0),
        'Invalid gallery key accepted')
    local into=Shell.dropAction('','', 'p:p_a','f:f_b',
        960,640,rect.x+20,rect.y+20)
    eq(into and into.kind=='move' and into.folder=='f_b',
        'Artwork dropped on folder must move into folder')
    local atParent=Shell.dropAction('f_child','f_parent',
        'p:p_a',nil,960,640,25,25)
    eq(atParent and atParent.kind=='move' and
        atParent.folder=='f_parent',
        'Back drop must move artwork to parent')
    local atRoot=Shell.dropAction('f_top','',
        'p:p_a',nil,960,640,25,25)
    eq(atRoot and atRoot.kind=='move' and
        atRoot.folder=='',
        'Back drop must allow returning to gallery root')
    eq(Shell.dropAction('',nil,'p:p_a',nil,
        960,640,25,25)==nil,
        'Root Back cannot move a project')
    local keeping=Shell.dropAction('','',
        'f:f_one','f:f_two',960,640,40,75)
    eq(keeping and keeping.kind=='reorder'
        and keeping.target=='f:f_two',
        'Folder reordering should not nest folders accidentally')
    local other=Shell.dropAction('','',
        'p:p_a','p:p_b',960,640,40,75)
    eq(other and other.kind=='reorder'
        and other.target=='p:p_b',
        'Artwork reordering should remain working')
    eq(Shell.dropAction('',nil,'p:p_a','p:p_a',
        960,640,40,75)==nil,
        'Self drop cannot move or reorder')
    eq(not Shell.parentDrop(960,640,160,25) and
        not Shell.parentDrop(960,640,25,65) and
        Shell.parentDrop(960,640,25,25),
        'Parent drop hitbox outside real Back control')
    local groupRect=Shell.card(960,640,2,0)
    local gx,gy=groupRect.x+groupRect.w/2,
        groupRect.y+groupRect.h/2
    eq(Shell.groupHit(groupRect,gx,gy)
        and not Shell.groupHit(groupRect,groupRect.x+5,gy),
        'Grouping should require thumbnail central area')
    local group=Shell.dropAction('','',
        'p:p_a','p:p_b',960,640,gx,gy,groupRect)
    eq(group and group.kind=='group' and group.target=='p:p_b',
        'Artwork-on-artwork central drop did not create a group')
    local edge=Shell.dropAction('','',
        'p:p_a','p:p_b',960,640,groupRect.x+5,gy,groupRect)
    eq(edge and edge.kind=='reorder',
        'Artwork edge drops must preserve ordinary reordering')
    local folderInstead=Shell.dropAction('','',
        'f:f_a','p:p_b',960,640,gx,gy,groupRect)
    eq(folderInstead.kind=='reorder',
        'Dragging a folder over artwork must not group or nest it')
    eq(not pcall(Shell.groupHit,{x='bad',y=1,w=160,h=175},gx,gy),
        'Invalid artwork rectangle accepted')
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
    local Chrome=require('ibis_gallery_card_chrome')
    local sizes={{960,640},{1220,800},{1920,1080}}
    for _,size in ipairs(sizes) do
        local w,h=size[1],size[2]
        local grid=Shell.layout(w,h)
        local rect=Shell.card(w,h,1,0)
        local original={x=rect.x,y=rect.y,w=rect.w,h=rect.h}
        local idle=Chrome.geometry(rect,false,false)
        local hover=Chrome.geometry(rect,false,true)
        local picked=Chrome.geometry(rect,true,false)
        eq(not idle.outerFrame and idle.backdrop=='none'
            and idle.imageOutline=='subtle',
            'Galeria ainda apresenta contorno de cartao desktop')
        eq(hover.backdrop=='hover' and
            picked.backdrop=='selected' and
            picked.imageOutline=='selection',
            'Estados de foco e selecao perderam contraste')
        eq(idle.title.x>=rect.x and
            idle.title.x+idle.title.w<=rect.x+rect.w and
            idle.title.y>=rect.preview.y+rect.preview.h and
            idle.metadata.y+14<=rect.y+rect.h,
            'Titulo centralizado e metadados extrapolam cartao')
        eq(idle.image.x==rect.preview.x and
            idle.image.y==rect.preview.y and
            idle.image.w==rect.preview.w and
            idle.image.h==rect.preview.h,
            'Fidelidade visual mudou a origem da miniatura real')
        eq(rect.x==original.x and rect.y==original.y
            and rect.w==original.w and rect.h==original.h
            and Shell.hit(w,h,1,0,rect.x+10,rect.y+10),
            'Alteracao visual mudou hitbox ou scroll da galeria')
        eq(grid.cols>=1 and rect.visible,
            'Grade nao se ajusta a resolucao')
        eq(not pcall(Chrome.geometry,
            {x=0,y=0,w=10,h=10,preview={x=9,y=9,w=20,h=20}},
            false,false),'Geometria invalida foi aceita')
    end
    for _,size in ipairs(sizes) do
        local r=G.dialog(size[1],size[2])
        eq(r.x>=0 and r.y>=0 and r.x+r.w<=size[1]
            and r.y+r.h<=size[2],'Dialogo de tela fora da janela')
        local header=G.dialogHeader(r)
        local close=G.dialogClose(r)
        eq(header.x==r.x and header.y==r.y and
            header.w==r.w and header.h==44,
            'Cabecalho da nova tela nao acompanha painel')
        eq(close.x>=header.x+header.w-48 and
            close.x+close.w<=header.x+header.w and
            close.y>=header.y and
            close.y+close.h<=header.y+header.h,
            'Fechar da nova tela extrapola cabecalho')
        local fields=G.fields(r)
        eq(header.y+header.h<fields[1].y,
            'Cabecalho interfere com o campo Nome')
        eq(#fields==3,'Nome largura altura exigidos')
        for i,field in ipairs(fields) do
            eq(field.x>=r.x and field.x+field.w<=r.x+r.w and
                field.y>=r.y and field.y+field.h<r.y+r.h-120,
                'Campo de tela fora do painel')
            if i>1 then
                local prev=fields[i-1]
                eq(field.y>=prev.y+prev.h or
                    prev.y>=field.y+field.h or
                    field.x>=prev.x+prev.w or
                    prev.x>=field.x+field.w,
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
        local firstRow=G.presetButton(r,1)
        local lastRow=G.presetButton(r,4)
        eq(firstRow.y>=tabs[1].y+tabs[1].h and
            lastRow.y+lastRow.h<=r.y+422,
            'Lista vertical invade abas ou rodape')
        eq(fields[2].y==fields[3].y and
            fields[2].x+fields[2].w<fields[3].x,
            'Largura e altura nao estao lado a lado')
        for _,index in ipairs({2,3}) do
            local field=fields[index]
            local minus=G.dimensionStepper(r,index,-1)
            local plus=G.dimensionStepper(r,index,1)
            eq(minus.x>=field.x+field.w-66 and
                plus.x>=minus.x+minus.w and
                plus.x+plus.w<=field.x+field.w and
                plus.y==minus.y and
                minus.y>=field.y and
                plus.y+plus.h<=field.y+field.h,
                'Ajustes +/- escapam do campo numerico')
        end
        eq(G.stepDimension('512',1)=='528' and
            G.stepDimension('528',-1)=='512',
            'Ajuste +/- nao altera a dimensao no formulario')
        eq(G.stepDimension('2040',1)=='2048' and
            G.stepDimension('16',-1)=='1',
            'Ajuste ultrapassou limites do motor Lua')
        eq(G.stepDimension('1',-1)==nil and
            G.stepDimension('2048',1)==nil and
            G.stepDimension('x',1)==nil and
            G.stepDimension('22.5',-1)==nil,
            'Ajuste aceitou input invalido ou extremo ultrapassado')
        eq(not pcall(G.dimensionStepper,r,1,1)
            and not pcall(G.dimensionStepper,r,2,0)
            and not pcall(G.stepDimension,'512',0),
            'Ajuste de dimensao aceitou eixo/direcao invalidos')
        for _,axis in ipairs({2,3}) do
            local track=G.dimensionSlider(r,axis)
            local field=fields[axis]
            eq(track.x>=field.x and
                track.x+track.w<=field.x+field.w and
                track.y>=field.y+field.h and
                track.y+track.h<tabs[1].y,
                'Slider invade campo ou abas de formato')
            eq(G.sliderHit(track,track.x,track.y+track.h/2)
                and G.sliderHit(track,track.x+track.w,
                    track.y+track.h/2)
                and not G.sliderHit(track,track.x-1,track.y),
                'Area clicavel da barra nao bate com a geometria')
            eq(G.sliderValue(track,track.x)=='1' and
                G.sliderValue(track,track.x+track.w)=='2048',
                'Barras nao alcançam limites reais 1..2048')
            eq(G.sliderValue(track,track.x-500)=='1' and
                G.sliderValue(track,track.x+track.w+500)=='2048',
                'Arrasto de slider ultrapassou os extremos')
            local halfway=G.sliderValue(track,track.x+track.w/2)
            eq(tonumber(halfway)>=1024 and
                tonumber(halfway)<=1025,
                'Slider nao possui escala linear')
            local start=G.sliderPosition(track,512)
            eq(start and
                G.sliderValue(track,start)=='512',
                'Slider nao representa os valores de presets')
            eq(G.sliderPosition(track,'abc')==nil and
                G.sliderPosition(track,0)==nil and
                G.sliderPosition(track,2049)==nil,
                'Slider de dimensoes mostrou valor invalido')
        end
        eq(not pcall(G.dimensionSlider,r,1) and
            not pcall(G.sliderValue,{x=0,y=0,w=0,h=20},3)
            and not pcall(G.sliderValue,
                {x=0,y=0,w=100,h=20},0/0),
            'Sliders aceitaram geometria/eixo/NaN invalidos')
        eq(fields[3].x+fields[3].w<preview.x and
            preview.y+preview.h<firstRow.y,
            'Campos ou previa invadem lista de formatos')
        local VisualRows=require('ibis_canvas_preset_rows')
        local landscape=VisualRows.symbol({w=1920,h=1080})
        local portrait=VisualRows.symbol({w=1080,h=1920})
        eq(landscape.w>landscape.h and
            portrait.h>portrait.w and
            landscape.w<=22 and portrait.h<=22,
            'Icones de proporcao nao refletem formato')

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
                eq(before.y+before.h<=b.y and
                    before.x==b.x and before.w==b.w,
                    'Linhas de presets se sobrepoem ou mudam coluna')
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
        eq(l.top==66 and l.bottom==h-58,
            'Galeria nao alinha miniaturas sob cabecalho oficial')
        eq(Shell.GRID_TOP==66,
            'Layout depende da antiga faixa de filtros')
        eq(Shell.card(w,h,1,0).y==66,
            'Primeira miniatura ainda esta deslocada pelas abas')
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
        Shell.selectionAvailable('move') and
        Shell.selectionAvailable('delete'),
        'Disponibilidade da movimentacao nao acompanha backend')
    local ids=Shell.selectedProjectIds(
        {['p:c']=true,['p:e']=true},keys)
    eq(#ids==2 and ids[1]=='c' and ids[2]=='e',
        'Selecao de projetos nao manteve ordem do catalogo')
    eq(Shell.selectedProjectIds({['f:a']=true},keys)==nil,
        'Pasta selecionada aceita para mover desenhos')
    eq(Shell.selectedProjectIds({},keys)==nil,
        'Mover aceitou selecao vazia')
    local choices=Shell.folderChoices({
        {id='f_root',name='Projetos',parent=''},
        {id='f_child',name='Finalizados',parent='f_root'},
        {id='f_other',name='Rascunhos',parent=''}
    },'f_root')
    eq(#choices==3,'Seletor nao excluiu a pasta atual')
    local named={}
    for _,choice in ipairs(choices) do named[choice.id]=choice.label end
    eq(named['']=='A Minha Galeria' and
        named.f_child=='Projetos / Finalizados' and
        named.f_other=='Rascunhos',
        'Seletor nao apresentou hierarquia completa')
    eq(#Shell.folderChoices({},'')==0,
        'Seletor nao devia inventar pasta destino')
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
    for _,dim in ipairs(sizes) do
        local p=Shell.movePopup(dim[1],dim[2])
        local bar=Shell.layout(dim[1],dim[2])
        eq(p.x>=0 and p.y>=0 and p.x+p.w<=dim[1] and
            p.y+p.h<bar.footerY,
            'Popup de destino invade janela')
        local prev
        for i=1,6 do
            local row=Shell.moveRow(p,i)
            eq(row.x>=p.x and row.x+row.w<=p.x+p.w and
                row.y>=p.y and row.y+row.h<=p.y+p.h,
                'Destino fora do popup')
            if prev then eq(prev.y+prev.h<row.y,
                'Destinos sobrepostos') end
            prev=row
        end
        eq(Shell.moveConfirmRect(p).y>prev.y+prev.h,
            'Confirmacao sobreposta ao ultimo destino')
        eq(Shell.moveCancelRect(p).y==Shell.moveConfirmRect(p).y)
    end
    eq(Shell.movePageCount(0)==1 and
        Shell.movePageCount(7)==2 and Shell.movePageCount(13)==3,
        'Paginacao do seletor de destinos incorreta')
    eq(Shell.movePage(1,3,1)==2 and
        Shell.movePage(3,3,1)==3 and
        Shell.movePage(1,3,-1)==1,'Paginacao fora dos limites')
    local fakeStore={
        catalog={folders={
            {id='f_root',name='Raiz',parent=''},
            {id='f_child',name='Interior',parent='f_root'}}},
        createFolder=function(self,name,parent)
            if name=='duplicada' then
                error('store: folder name already exists')
            end
            assert(type(name)=='string' and name~='')
            assert(parent=='f_child','Criou pasta no pai incorreto')
            local id='f_new'..tostring(#self.catalog.folders+1)
            self.catalog.folders[#self.catalog.folders+1]={
                id=id,name=name,parent=parent}
            return id
        end
    }
    local draft={ids={'p_project'},page=1,target='f_child'}
    Shell.openNewFolder(draft,'f_root')
    eq(draft.creating and draft.createParent=='f_child'
        and draft.createName=='','Nova pasta perdeu pai selecionado')
    Shell.appendFolderName(draft,'Coleção 🎨')
    eq(Shell.backspaceFolderName(draft)=='Coleção ',
        'Backspace cortou byte de UTF-8')
    Shell.appendFolderName(draft,'nova')
    local ok,created=Shell.createDestination(
        fakeStore,draft,'f_root')
    eq(ok and created=='f_new3' and draft.target==created
        and not draft.creating,'Criacao de pasta nao selecionou destino')
    eq(fakeStore.catalog.folders[3].parent=='f_child',
        'Nova pasta nao foi criada na hierarquia escolhida')
    Shell.openNewFolder(draft,'f_root')
    Shell.appendFolderName(draft,'duplicada')
    local accepted=Shell.createDestination(fakeStore,draft,'f_root')
    eq(not accepted and draft.creating
        and type(draft.createError)=='string'
        and #fakeStore.catalog.folders==3,
        'Falha de criacao nao foi mantida no formulario')
    Shell.cancelNewFolder(draft)
    eq(not draft.creating and not draft.createError
        and #fakeStore.catalog.folders==3,
        'Cancelar criou pastas indevidas')
    Shell.openNewFolder(draft,'f_root')
    Shell.appendFolderName(draft,string.rep('z',250))
    eq(#draft.createName==0,'Limite de 240 bytes nao respeitado')
    Shell.cancelNewFolder(draft)
    for _,size in ipairs(sizes) do
        local p=Shell.movePopup(size[1],size[2])
        local new=Shell.moveNewFolderRect(p)
        local name=Shell.moveFolderNameRect(p)
        local first=Shell.moveRow(p,1)
        eq(new.x>=p.x and new.x+new.w<=p.x+p.w
            and new.y>=p.y and new.y+new.h<first.y,
            'Botao Nova pasta encobre os destinos')
        eq(name.x>=p.x and name.x+name.w<=p.x+p.w
            and name.y>first.y and name.y+name.h<p.y+p.h-50,
            'Campo do nome encobre confirmacao')
    end
    for _,size in ipairs(sizes) do
        local p=Shell.confirmPopup(size[1],size[2])
        local yes=Shell.confirmAction(p)
        local no=Shell.confirmCancel(p)
        eq(p.x>=0 and p.y>=0 and
            p.x+p.w<=size[1] and p.y+p.h<=size[2],
            'Confirmacao fora da viewport')
        eq(no.x+no.w<yes.x and
            yes.x+yes.w<=p.x+p.w and
            yes.y==no.y and yes.y+yes.h<p.y+p.h,
            'Controles de confirmacao sobrepostos')
    end
    for _,size in ipairs(sizes) do
        local p=Retention.morePopup(size[1],size[2])
        local item=Retention.moreItem(p)
        eq(p.x>=0 and p.y>54 and p.x+p.w<=size[1] and
            p.y+p.h<120+70,
            'Menu opcoes sai da regiao superior')
        eq(item.x>=p.x and item.y>=p.y and
            item.x+item.w<=p.x+p.w and
            item.y+item.h<=p.y+p.h,
            'Opcao recentemente excluidos sai do menu')
    end
    for _,size in ipairs(sizes) do
        local oldRight
        for _,action in ipairs({'all','clear','recover'}) do
            local r=Retention.trashAction(size[1],size[2],action)
            eq(r.x>=0 and r.y>=Shell.layout(size[1],size[2]).footerY
                and r.x+r.w<=size[1] and r.y+r.h<=size[2],
                'Acoes de recuperacao fora do rodape')
            if oldRight then
                eq(r.x>oldRight,'Acoes de recuperacao sobrepostas')
            end
            oldRight=r.x+r.w
        end
    end
    eq(not pcall(Retention.trashAction,960,640,'delete'),
        'Exclusao definitiva nao pode ser exposta')
    for _,dim in ipairs(sizes) do
        local w,h=dim[1],dim[2]
        local l=Shell.layout(w,h)
        local count=l.cols*8
        local max=Shell.maxScroll(w,h,count)
        eq(max>0,'Fixture must allow scrolling')
        local down,dir=Shell.dragAutoScroll(
            w,h,count,0,l.bottom-1,.016)
        eq(down>0 and dir==1,'Bottom drag did not scroll')
        local slow=Shell.dragAutoScroll(
            w,h,count,0,l.bottom-68,.016)
        eq(slow>0 and slow<down,'Edge speed gradient failed')
        local up,back=Shell.dragAutoScroll(
            w,h,count,max,l.top+1,.016)
        eq(up<max and back==-1,'Top drag did not scroll')
        eq(Shell.dragAutoScroll(w,h,count,down,
            (l.top+l.bottom)/2,.016)==down,
            'Center drag unexpectedly scrolled')
        eq(Shell.dragAutoScroll(w,h,count,down,20,.016)==down,
            'Back-button drag unexpectedly scrolled')
        eq(Shell.dragAutoScroll(w,h,count,down,h-10,.016)==down,
            'Footer drag unexpectedly scrolled')
        eq(Shell.dragAutoScroll(w,h,count,0,l.top+1,.016)==0,
            'Top limit crossed')
        eq(Shell.dragAutoScroll(w,h,count,max,l.bottom-1,.016)==max,
            'Bottom limit crossed')
        eq(Shell.dragAutoScroll(w,h,l.cols,0,l.bottom-1,.016)==0,
            'Small gallery must not scroll')
        eq(Shell.dragAutoScroll(w,h,count,0,l.bottom-1,10)==
            Shell.dragAutoScroll(w,h,count,0,l.bottom-1,.05),
            'Frame time spike caused excessive scrolling')
    end
    eq(not pcall(Shell.dragAutoScroll,960,640,50,0,600,-.1),
        'Negative delta time was accepted')
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
