-- Geometria da galeria de miniaturas, inspirada no tutorial oficial
-- "View Your Artwork" (#20) e "Rearrange artworks" (#103).
-- Não implementa serialização, ordenação proprietária ou cloud.
local M={}
M.CARD_W=160
M.CARD_H=175
M.STEP_X=174
M.STEP_Y=188
-- Official gallery has no dedicated local category-tab strip. Keep the
-- artwork grid directly below the 54 px title bar (12 px spacing).
M.GRID_TOP=66
function M.layout(w,h)
    assert(type(w)=='number' and w>=960 and
        type(h)=='number' and h>=640,'Janela de galeria pequena')
    local n=math.max(1,math.floor((w-44+14)/M.STEP_X))
    return {cols=n,top=M.GRID_TOP,bottom=h-58,
        left=math.floor((w-(n*M.CARD_W+(n-1)*14))/2),
        footerY=h-52}
end
function M.maxScroll(w,h,count)
    assert(type(count)=='number' and count%1==0 and count>=0,
        'Quantidade de obras invalida')
    local l=M.layout(w,h)
    local rows=math.ceil(count/l.cols)
    return math.max(0,(rows-1)*M.STEP_Y+M.CARD_H-
        (l.bottom-l.top))
end
function M.scroll(w,h,count,current,direction)
    assert(type(current)=='number' and current==current and
        type(direction)=='number' and direction==direction,
        'Rolagem invalida')
    local max=M.maxScroll(w,h,count)
    return math.max(0,math.min(max,current-direction*70))
end
function M.card(w,h,index,scroll)
    local l=M.layout(w,h)
    assert(type(index)=='number' and index%1==0 and index>=1
        and type(scroll)=='number' and scroll==scroll,
        'Indice de miniatura invalido')
    local col=(index-1)%l.cols
    local row=math.floor((index-1)/l.cols)
    local x=l.left+col*M.STEP_X
    local y=l.top+row*M.STEP_Y-scroll
    return {x=x,y=y,w=M.CARD_W,h=M.CARD_H,
        preview={x=x+10,y=y+9,w=140,h=130},
        titleX=x+9,titleY=y+143,
        metaX=x+9,metaY=y+159,
        visible=y<l.bottom and y+M.CARD_H>l.top}
end
function M.hit(w,h,index,scroll,x,y)
    local l=M.layout(w,h)
    local r=M.card(w,h,index,scroll)
    return r.visible and x>=r.x and x<r.x+r.w
        and y>=math.max(l.top,r.y)
        and y<math.min(l.bottom,r.y+r.h)
end
-- Long hold starts dragging; a normal click is dispatched on release.
-- A movement outside the card before the hold cancels a click safely.
M.LONG_PRESS_SECONDS=.48
M.DRAG_SLOP=9
function M.dragBegin(key,x,y,now,callback)
    assert(type(key)=='string' and
        (key:match('^p:p_[A-Za-z0-9_%-]+
    M.layout(w,h)
    return {x=18,y=h-230,w=292,h=172}
end
function M.newOption(p,index)
    assert(type(p)=='table' and p.w>=292 and p.h>=172
        and (index==1 or index==2 or index==3),
        'Opcao de criacao invalida')
    return {x=p.x+12,y=p.y+12+(index-1)*51,w=p.w-24,h=43}
end
-- Modo de selecao multipla na galeria.
-- Mover aceita apenas projetos; Excluir ainda nao possui backend.
-- IDs de pasta e obra sao mantidos distintos, como no catalogo existente.
function M.selectionKeys(folders,projects,filter)
    assert(type(folders)=='table' and type(projects)=='table' and
        (filter=='all' or filter=='works' or filter=='folders'),
        'Catalogo da galeria invalido')
    local keys={}
    if filter~='works' then
        for _,folder in ipairs(folders) do
            assert(type(folder.id)=='string','Pasta sem identificador')
            keys[#keys+1]='f:'..folder.id
        end
    end
    if filter~='folders' then
        for _,project in ipairs(projects) do
            assert(type(project.id)=='string','Obra sem identificador')
            keys[#keys+1]='p:'..project.id
        end
    end
    return keys
end
function M.selectionCount(selected,keys)
    assert(type(selected)=='table' and type(keys)=='table',
        'Estado de selecao invalido')
    local count=0
    for _,key in ipairs(keys) do
        if selected[key]==true then count=count+1 end
    end
    return count
end
function M.selectAll(keys)
    assert(type(keys)=='table','Lista de selecao invalida')
    local result={}
    for _,key in ipairs(keys) do result[key]=true end
    return result
end
function M.selectedProjectIds(selected,keys)
    assert(type(selected)=='table' and type(keys)=='table',
        'Estado de selecao invalido')
    local ids={}
    for _,key in ipairs(keys) do
        if selected[key]==true then
            if key:sub(1,2)~='p:' then return nil end
            ids[#ids+1]=key:sub(3)
        end
    end
    if #ids==0 then return nil end
    return ids
end
-- The chooser uses the complete local hierarchy, including nested folders.
function M.folderChoices(folders,current)
    assert(type(folders)=='table' and type(current)=='string',
        'Arvore de pastas invalida')
    local byId={}
    for _,folder in ipairs(folders) do byId[folder.id]=folder end
    local result={}
    if current~='' then
        result[#result+1]={id='',label='A Minha Galeria'}
    end
    for _,folder in ipairs(folders) do
        if folder.id~=current then
            local parts={folder.name}
            local seen={[folder.id]=true}
            local parent=folder.parent
            while parent~='' do
                assert(not seen[parent] and byId[parent],
                    'Arvore de pastas quebrada')
                seen[parent]=true
                local entry=byId[parent]
                table.insert(parts,1,entry.name)
                parent=entry.parent
            end
            result[#result+1]={id=folder.id,
                label=table.concat(parts,' / ')}
        end
    end
    table.sort(result,function(a,b)
        if a.label==b.label then return a.id<b.id end
        return a.label<b.label
    end)
    return result
end
function M.movePopup(w,h)
    M.layout(w,h)
    return {x=math.floor((w-540)/2),y=math.floor((h-470)/2),
        w=540,h=470}
end
function M.moveRow(p,index)
    assert(type(p)=='table' and p.w==540 and p.h==470
        and type(index)=='number' and index%1==0
        and index>=1 and index<=6,'Linha de destino invalida')
    return {x=p.x+24,y=p.y+91+(index-1)*47,w=p.w-48,h=39}
end
function M.movePageCount(n)
    assert(type(n)=='number' and n>=0 and n%1==0,
        'Quantidade de pastas invalida')
    return math.max(1,math.ceil(n/6))
end
function M.movePage(page,pages,delta)
    assert(type(page)=='number' and type(pages)=='number'
        and page%1==0 and pages%1==0 and pages>=1
        and (delta==-1 or delta==1),'Pagina de destino invalida')
    return math.max(1,math.min(pages,page+delta))
end
function M.moveNavRect(p,index)
    assert(type(p)=='table' and p.w==540 and p.h==470
        and (index==1 or index==2),'Navegacao de destino invalida')
    return {x=p.x+(index==1 and 24 or p.w-69),
        y=p.y+p.h-91,w=45,h=29}
end
function M.moveNewFolderRect(p)
    assert(type(p)=='table' and p.w==540 and p.h==470,
        'Popup de destino invalido')
    return {x=p.x+p.w-189,y=p.y+52,w=165,h=31}
end
function M.moveFolderNameRect(p)
    assert(type(p)=='table' and p.w==540 and p.h==470,
        'Popup de destino invalido')
    return {x=p.x+24,y=p.y+142,w=p.w-48,h=43}
end
function M.openNewFolder(state,current)
    assert(type(state)=='table' and type(current)=='string',
        'Seletor de pasta invalido')
    state.creating=true
    state.createName=''
    state.createError=nil
    state.createParent=state.target~=nil and state.target or current
end
function M.cancelNewFolder(state)
    assert(type(state)=='table','Seletor de pasta invalido')
    state.creating=false
    state.createError=nil
    state.createName=''
    state.createParent=nil
end
function M.appendFolderName(state,value)
    assert(type(state)=='table' and state.creating and
        type(state.createName)=='string' and type(value)=='string',
        'Entrada de pasta invalida')
    if #state.createName+#value<=240 then
        state.createName=state.createName..value
    end
    return state.createName
end
function M.backspaceFolderName(state)
    assert(type(state)=='table' and state.creating,
        'Entrada de pasta invalida')
    local text=state.createName
    -- LuaJIT 2.1 puro nao inclui modulo utf8. Um caractere valido
    -- termina no ultimo byte ASCII ou inicial de sequencia UTF-8.
    local pos=#text
    while pos>1 do
        local byte=text:byte(pos)
        if byte<128 or byte>=192 then break end
        pos=pos-1
    end
    if pos>0 then state.createName=text:sub(1,pos-1) end
    return state.createName
end
function M.createDestination(store,state,current)
    assert(type(store)=='table' and
        type(store.createFolder)=='function' and
        type(state)=='table' and state.creating and
        type(state.createName)=='string' and
        type(current)=='string','Criacao de pasta invalida')
    local parent=state.createParent
    assert(type(parent)=='string','Destino sem pasta pai')
    local ok,created=pcall(store.createFolder,store,
        state.createName,parent)
    if not ok then
        state.createError=tostring(created)
        return false,created
    end
    state.target=created
    M.cancelNewFolder(state)
    local choices=M.folderChoices(store.catalog.folders,current)
    for i,entry in ipairs(choices) do
        if entry.id==created then
            state.page=math.floor((i-1)/6)+1
            break
        end
    end
    return true,created
end
function M.moveConfirmRect(p)
    assert(type(p)=='table' and p.w==540 and p.h==470)
    return {x=p.x+p.w-182,y=p.y+p.h-50,w=158,h=38}
end
function M.moveCancelRect(p)
    assert(type(p)=='table' and p.w==540 and p.h==470)
    return {x=p.x+24,y=p.y+p.h-50,w=133,h=38}
end
function M.confirmPopup(w,h)
    M.layout(w,h)
    return {x=math.floor((w-440)/2),y=math.floor((h-238)/2),
        w=440,h=238}
end
function M.confirmAction(p)
    assert(type(p)=='table' and p.w==440 and p.h==238)
    return {x=p.x+235,y=p.y+174,w=184,h=43}
end
function M.confirmCancel(p)
    assert(type(p)=='table' and p.w==440 and p.h==238)
    return {x=p.x+21,y=p.y+174,w=169,h=43}
end
function M.selectionAction(w,h,id)
    M.layout(w,h)
    local x={
        all=w-436,clear=w-326,
        move=w-216,delete=w-108
    }
    local widths={all=102,clear=102,move=100,delete=96}
    assert(x[id],'Acao de selecao desconhecida')
    return {x=x[id],y=h-46,w=widths[id],h=36}
end
function M.selectionAvailable(id)
    assert(id=='all' or id=='clear' or id=='move' or id=='delete',
        'Acao de selecao desconhecida')
    return true -- Exclusao recuperavel exige confirmacao.
end
return M
) or
        key:match('^f:f_[A-Za-z0-9_%-]+
    M.layout(w,h)
    return {x=18,y=h-230,w=292,h=172}
end
function M.newOption(p,index)
    assert(type(p)=='table' and p.w>=292 and p.h>=172
        and (index==1 or index==2 or index==3),
        'Opcao de criacao invalida')
    return {x=p.x+12,y=p.y+12+(index-1)*51,w=p.w-24,h=43}
end
-- Modo de selecao multipla na galeria.
-- Mover aceita apenas projetos; Excluir ainda nao possui backend.
-- IDs de pasta e obra sao mantidos distintos, como no catalogo existente.
function M.selectionKeys(folders,projects,filter)
    assert(type(folders)=='table' and type(projects)=='table' and
        (filter=='all' or filter=='works' or filter=='folders'),
        'Catalogo da galeria invalido')
    local keys={}
    if filter~='works' then
        for _,folder in ipairs(folders) do
            assert(type(folder.id)=='string','Pasta sem identificador')
            keys[#keys+1]='f:'..folder.id
        end
    end
    if filter~='folders' then
        for _,project in ipairs(projects) do
            assert(type(project.id)=='string','Obra sem identificador')
            keys[#keys+1]='p:'..project.id
        end
    end
    return keys
end
function M.selectionCount(selected,keys)
    assert(type(selected)=='table' and type(keys)=='table',
        'Estado de selecao invalido')
    local count=0
    for _,key in ipairs(keys) do
        if selected[key]==true then count=count+1 end
    end
    return count
end
function M.selectAll(keys)
    assert(type(keys)=='table','Lista de selecao invalida')
    local result={}
    for _,key in ipairs(keys) do result[key]=true end
    return result
end
function M.selectedProjectIds(selected,keys)
    assert(type(selected)=='table' and type(keys)=='table',
        'Estado de selecao invalido')
    local ids={}
    for _,key in ipairs(keys) do
        if selected[key]==true then
            if key:sub(1,2)~='p:' then return nil end
            ids[#ids+1]=key:sub(3)
        end
    end
    if #ids==0 then return nil end
    return ids
end
-- The chooser uses the complete local hierarchy, including nested folders.
function M.folderChoices(folders,current)
    assert(type(folders)=='table' and type(current)=='string',
        'Arvore de pastas invalida')
    local byId={}
    for _,folder in ipairs(folders) do byId[folder.id]=folder end
    local result={}
    if current~='' then
        result[#result+1]={id='',label='A Minha Galeria'}
    end
    for _,folder in ipairs(folders) do
        if folder.id~=current then
            local parts={folder.name}
            local seen={[folder.id]=true}
            local parent=folder.parent
            while parent~='' do
                assert(not seen[parent] and byId[parent],
                    'Arvore de pastas quebrada')
                seen[parent]=true
                local entry=byId[parent]
                table.insert(parts,1,entry.name)
                parent=entry.parent
            end
            result[#result+1]={id=folder.id,
                label=table.concat(parts,' / ')}
        end
    end
    table.sort(result,function(a,b)
        if a.label==b.label then return a.id<b.id end
        return a.label<b.label
    end)
    return result
end
function M.movePopup(w,h)
    M.layout(w,h)
    return {x=math.floor((w-540)/2),y=math.floor((h-470)/2),
        w=540,h=470}
end
function M.moveRow(p,index)
    assert(type(p)=='table' and p.w==540 and p.h==470
        and type(index)=='number' and index%1==0
        and index>=1 and index<=6,'Linha de destino invalida')
    return {x=p.x+24,y=p.y+91+(index-1)*47,w=p.w-48,h=39}
end
function M.movePageCount(n)
    assert(type(n)=='number' and n>=0 and n%1==0,
        'Quantidade de pastas invalida')
    return math.max(1,math.ceil(n/6))
end
function M.movePage(page,pages,delta)
    assert(type(page)=='number' and type(pages)=='number'
        and page%1==0 and pages%1==0 and pages>=1
        and (delta==-1 or delta==1),'Pagina de destino invalida')
    return math.max(1,math.min(pages,page+delta))
end
function M.moveNavRect(p,index)
    assert(type(p)=='table' and p.w==540 and p.h==470
        and (index==1 or index==2),'Navegacao de destino invalida')
    return {x=p.x+(index==1 and 24 or p.w-69),
        y=p.y+p.h-91,w=45,h=29}
end
function M.moveNewFolderRect(p)
    assert(type(p)=='table' and p.w==540 and p.h==470,
        'Popup de destino invalido')
    return {x=p.x+p.w-189,y=p.y+52,w=165,h=31}
end
function M.moveFolderNameRect(p)
    assert(type(p)=='table' and p.w==540 and p.h==470,
        'Popup de destino invalido')
    return {x=p.x+24,y=p.y+142,w=p.w-48,h=43}
end
function M.openNewFolder(state,current)
    assert(type(state)=='table' and type(current)=='string',
        'Seletor de pasta invalido')
    state.creating=true
    state.createName=''
    state.createError=nil
    state.createParent=state.target~=nil and state.target or current
end
function M.cancelNewFolder(state)
    assert(type(state)=='table','Seletor de pasta invalido')
    state.creating=false
    state.createError=nil
    state.createName=''
    state.createParent=nil
end
function M.appendFolderName(state,value)
    assert(type(state)=='table' and state.creating and
        type(state.createName)=='string' and type(value)=='string',
        'Entrada de pasta invalida')
    if #state.createName+#value<=240 then
        state.createName=state.createName..value
    end
    return state.createName
end
function M.backspaceFolderName(state)
    assert(type(state)=='table' and state.creating,
        'Entrada de pasta invalida')
    local text=state.createName
    -- LuaJIT 2.1 puro nao inclui modulo utf8. Um caractere valido
    -- termina no ultimo byte ASCII ou inicial de sequencia UTF-8.
    local pos=#text
    while pos>1 do
        local byte=text:byte(pos)
        if byte<128 or byte>=192 then break end
        pos=pos-1
    end
    if pos>0 then state.createName=text:sub(1,pos-1) end
    return state.createName
end
function M.createDestination(store,state,current)
    assert(type(store)=='table' and
        type(store.createFolder)=='function' and
        type(state)=='table' and state.creating and
        type(state.createName)=='string' and
        type(current)=='string','Criacao de pasta invalida')
    local parent=state.createParent
    assert(type(parent)=='string','Destino sem pasta pai')
    local ok,created=pcall(store.createFolder,store,
        state.createName,parent)
    if not ok then
        state.createError=tostring(created)
        return false,created
    end
    state.target=created
    M.cancelNewFolder(state)
    local choices=M.folderChoices(store.catalog.folders,current)
    for i,entry in ipairs(choices) do
        if entry.id==created then
            state.page=math.floor((i-1)/6)+1
            break
        end
    end
    return true,created
end
function M.moveConfirmRect(p)
    assert(type(p)=='table' and p.w==540 and p.h==470)
    return {x=p.x+p.w-182,y=p.y+p.h-50,w=158,h=38}
end
function M.moveCancelRect(p)
    assert(type(p)=='table' and p.w==540 and p.h==470)
    return {x=p.x+24,y=p.y+p.h-50,w=133,h=38}
end
function M.confirmPopup(w,h)
    M.layout(w,h)
    return {x=math.floor((w-440)/2),y=math.floor((h-238)/2),
        w=440,h=238}
end
function M.confirmAction(p)
    assert(type(p)=='table' and p.w==440 and p.h==238)
    return {x=p.x+235,y=p.y+174,w=184,h=43}
end
function M.confirmCancel(p)
    assert(type(p)=='table' and p.w==440 and p.h==238)
    return {x=p.x+21,y=p.y+174,w=169,h=43}
end
function M.selectionAction(w,h,id)
    M.layout(w,h)
    local x={
        all=w-436,clear=w-326,
        move=w-216,delete=w-108
    }
    local widths={all=102,clear=102,move=100,delete=96}
    assert(x[id],'Acao de selecao desconhecida')
    return {x=x[id],y=h-46,w=widths[id],h=36}
end
function M.selectionAvailable(id)
    assert(id=='all' or id=='clear' or id=='move' or id=='delete',
        'Acao de selecao desconhecida')
    return true -- Exclusao recuperavel exige confirmacao.
end
return M
)) and
        type(x)=='number' and type(y)=='number' and
        type(now)=='number','Gesto da galeria invalido')
    return {key=key,x=x,y=y,px=x,py=y,started=now,
        callback=callback,active=false,moved=false}
end
function M.dragAdvance(gesture,x,y,now)
    assert(type(gesture)=='table' and type(x)=='number'
        and type(y)=='number' and type(now)=='number',
        'Arrasto da galeria invalido')
    gesture.px=x;gesture.py=y
    -- A pointer that moves before the hold is an aborted tap/scroll,
    -- never a delayed drag that could reorder documents accidentally.
    if not gesture.active and not gesture.earlyMove and
        now-gesture.started>=M.LONG_PRESS_SECONDS then
        gesture.active=true
    end
    local distance=(x-gesture.x)^2+(y-gesture.y)^2
    if distance>M.DRAG_SLOP^2 then
        gesture.moved=true
        if not gesture.active then gesture.earlyMove=true end
    end
    return gesture.active
end
function M.dragTarget(w,h,scroll,items,x,y)
    assert(type(items)=='table','Itens para arrastar invalidos')
    for i,item in ipairs(items) do
        if M.hit(w,h,i,scroll,x,y) then
            return item.key
        end
    end
    return nil
end
function M.newMenu(w,h)
    M.layout(w,h)
    return {x=18,y=h-230,w=292,h=172}
end
function M.newOption(p,index)
    assert(type(p)=='table' and p.w>=292 and p.h>=172
        and (index==1 or index==2 or index==3),
        'Opcao de criacao invalida')
    return {x=p.x+12,y=p.y+12+(index-1)*51,w=p.w-24,h=43}
end
-- Modo de selecao multipla na galeria.
-- Mover aceita apenas projetos; Excluir ainda nao possui backend.
-- IDs de pasta e obra sao mantidos distintos, como no catalogo existente.
function M.selectionKeys(folders,projects,filter)
    assert(type(folders)=='table' and type(projects)=='table' and
        (filter=='all' or filter=='works' or filter=='folders'),
        'Catalogo da galeria invalido')
    local keys={}
    if filter~='works' then
        for _,folder in ipairs(folders) do
            assert(type(folder.id)=='string','Pasta sem identificador')
            keys[#keys+1]='f:'..folder.id
        end
    end
    if filter~='folders' then
        for _,project in ipairs(projects) do
            assert(type(project.id)=='string','Obra sem identificador')
            keys[#keys+1]='p:'..project.id
        end
    end
    return keys
end
function M.selectionCount(selected,keys)
    assert(type(selected)=='table' and type(keys)=='table',
        'Estado de selecao invalido')
    local count=0
    for _,key in ipairs(keys) do
        if selected[key]==true then count=count+1 end
    end
    return count
end
function M.selectAll(keys)
    assert(type(keys)=='table','Lista de selecao invalida')
    local result={}
    for _,key in ipairs(keys) do result[key]=true end
    return result
end
function M.selectedProjectIds(selected,keys)
    assert(type(selected)=='table' and type(keys)=='table',
        'Estado de selecao invalido')
    local ids={}
    for _,key in ipairs(keys) do
        if selected[key]==true then
            if key:sub(1,2)~='p:' then return nil end
            ids[#ids+1]=key:sub(3)
        end
    end
    if #ids==0 then return nil end
    return ids
end
-- The chooser uses the complete local hierarchy, including nested folders.
function M.folderChoices(folders,current)
    assert(type(folders)=='table' and type(current)=='string',
        'Arvore de pastas invalida')
    local byId={}
    for _,folder in ipairs(folders) do byId[folder.id]=folder end
    local result={}
    if current~='' then
        result[#result+1]={id='',label='A Minha Galeria'}
    end
    for _,folder in ipairs(folders) do
        if folder.id~=current then
            local parts={folder.name}
            local seen={[folder.id]=true}
            local parent=folder.parent
            while parent~='' do
                assert(not seen[parent] and byId[parent],
                    'Arvore de pastas quebrada')
                seen[parent]=true
                local entry=byId[parent]
                table.insert(parts,1,entry.name)
                parent=entry.parent
            end
            result[#result+1]={id=folder.id,
                label=table.concat(parts,' / ')}
        end
    end
    table.sort(result,function(a,b)
        if a.label==b.label then return a.id<b.id end
        return a.label<b.label
    end)
    return result
end
function M.movePopup(w,h)
    M.layout(w,h)
    return {x=math.floor((w-540)/2),y=math.floor((h-470)/2),
        w=540,h=470}
end
function M.moveRow(p,index)
    assert(type(p)=='table' and p.w==540 and p.h==470
        and type(index)=='number' and index%1==0
        and index>=1 and index<=6,'Linha de destino invalida')
    return {x=p.x+24,y=p.y+91+(index-1)*47,w=p.w-48,h=39}
end
function M.movePageCount(n)
    assert(type(n)=='number' and n>=0 and n%1==0,
        'Quantidade de pastas invalida')
    return math.max(1,math.ceil(n/6))
end
function M.movePage(page,pages,delta)
    assert(type(page)=='number' and type(pages)=='number'
        and page%1==0 and pages%1==0 and pages>=1
        and (delta==-1 or delta==1),'Pagina de destino invalida')
    return math.max(1,math.min(pages,page+delta))
end
function M.moveNavRect(p,index)
    assert(type(p)=='table' and p.w==540 and p.h==470
        and (index==1 or index==2),'Navegacao de destino invalida')
    return {x=p.x+(index==1 and 24 or p.w-69),
        y=p.y+p.h-91,w=45,h=29}
end
function M.moveNewFolderRect(p)
    assert(type(p)=='table' and p.w==540 and p.h==470,
        'Popup de destino invalido')
    return {x=p.x+p.w-189,y=p.y+52,w=165,h=31}
end
function M.moveFolderNameRect(p)
    assert(type(p)=='table' and p.w==540 and p.h==470,
        'Popup de destino invalido')
    return {x=p.x+24,y=p.y+142,w=p.w-48,h=43}
end
function M.openNewFolder(state,current)
    assert(type(state)=='table' and type(current)=='string',
        'Seletor de pasta invalido')
    state.creating=true
    state.createName=''
    state.createError=nil
    state.createParent=state.target~=nil and state.target or current
end
function M.cancelNewFolder(state)
    assert(type(state)=='table','Seletor de pasta invalido')
    state.creating=false
    state.createError=nil
    state.createName=''
    state.createParent=nil
end
function M.appendFolderName(state,value)
    assert(type(state)=='table' and state.creating and
        type(state.createName)=='string' and type(value)=='string',
        'Entrada de pasta invalida')
    if #state.createName+#value<=240 then
        state.createName=state.createName..value
    end
    return state.createName
end
function M.backspaceFolderName(state)
    assert(type(state)=='table' and state.creating,
        'Entrada de pasta invalida')
    local text=state.createName
    -- LuaJIT 2.1 puro nao inclui modulo utf8. Um caractere valido
    -- termina no ultimo byte ASCII ou inicial de sequencia UTF-8.
    local pos=#text
    while pos>1 do
        local byte=text:byte(pos)
        if byte<128 or byte>=192 then break end
        pos=pos-1
    end
    if pos>0 then state.createName=text:sub(1,pos-1) end
    return state.createName
end
function M.createDestination(store,state,current)
    assert(type(store)=='table' and
        type(store.createFolder)=='function' and
        type(state)=='table' and state.creating and
        type(state.createName)=='string' and
        type(current)=='string','Criacao de pasta invalida')
    local parent=state.createParent
    assert(type(parent)=='string','Destino sem pasta pai')
    local ok,created=pcall(store.createFolder,store,
        state.createName,parent)
    if not ok then
        state.createError=tostring(created)
        return false,created
    end
    state.target=created
    M.cancelNewFolder(state)
    local choices=M.folderChoices(store.catalog.folders,current)
    for i,entry in ipairs(choices) do
        if entry.id==created then
            state.page=math.floor((i-1)/6)+1
            break
        end
    end
    return true,created
end
function M.moveConfirmRect(p)
    assert(type(p)=='table' and p.w==540 and p.h==470)
    return {x=p.x+p.w-182,y=p.y+p.h-50,w=158,h=38}
end
function M.moveCancelRect(p)
    assert(type(p)=='table' and p.w==540 and p.h==470)
    return {x=p.x+24,y=p.y+p.h-50,w=133,h=38}
end
function M.confirmPopup(w,h)
    M.layout(w,h)
    return {x=math.floor((w-440)/2),y=math.floor((h-238)/2),
        w=440,h=238}
end
function M.confirmAction(p)
    assert(type(p)=='table' and p.w==440 and p.h==238)
    return {x=p.x+235,y=p.y+174,w=184,h=43}
end
function M.confirmCancel(p)
    assert(type(p)=='table' and p.w==440 and p.h==238)
    return {x=p.x+21,y=p.y+174,w=169,h=43}
end
function M.selectionAction(w,h,id)
    M.layout(w,h)
    local x={
        all=w-436,clear=w-326,
        move=w-216,delete=w-108
    }
    local widths={all=102,clear=102,move=100,delete=96}
    assert(x[id],'Acao de selecao desconhecida')
    return {x=x[id],y=h-46,w=widths[id],h=36}
end
function M.selectionAvailable(id)
    assert(id=='all' or id=='clear' or id=='move' or id=='delete',
        'Acao de selecao desconhecida')
    return true -- Exclusao recuperavel exige confirmacao.
end
return M
