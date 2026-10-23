local Native=require('native')
local Store=require('store')
local Layers=require('layers')
local FS=require('fs')
local JSON=require('json')
local A={screen='gallery',folder='',dirty=false,buttons={},zoom=1,rotation=0,panX=0,panY=0,tool='inspect',color=0x192d40ff,view='grid',brushDiameter=12,drawing=false,sideTab='layers'}
local palette={bg={.055,.070,.09},panel={.09,.111,.14},card={.12,.15,.19},line={.20,.24,.29},text={.90,.94,.97},muted={.55,.64,.72},accent={.24,.80,.70},warn={1,.70,.30}}
local swatches={
    {name='Grafite',rgba=0x192d40ff},{name='Preto',rgba=0x000000ff},
    {name='Vermelho',rgba=0xe53b44ff},{name='Verde',rgba=0x20ba84ff},
    {name='Azul',rgba=0x347ce9ff},{name='Branco',rgba=0xffffffff}
}
local function c(key,alpha) local v=palette[key];love.graphics.setColor(v[1],v[2],v[3],alpha or 1) end
local function text(value,x,y,font,key) c(key or 'text');love.graphics.setFont(A.fonts[font or 'body']);love.graphics.print(value,x,y) end
local function box(x,y,w,h,key) c(key);love.graphics.rectangle('fill',x,y,w,h,8,8) end
local function status(s) A.message=s;A.messageTime=love.timer.getTime() end
local function guard(fn)
    return function(...) local ok,err=pcall(fn,...);if not ok then status(tostring(err)) end end
end
local function button(label,x,y,w,h,fn,active,disabled)
    local mx,my=love.mouse.getPosition();local hover=mx>=x and mx<=x+w and my>=y and my<=y+h
    box(x,y,w,h,disabled and 'panel' or active and 'accent' or hover and 'line' or 'card')
    c(active and 'bg' or disabled and 'muted' or 'text');love.graphics.setFont(A.fonts.body)
    love.graphics.printf(label,x,y+(h-17)/2,w,'center')
    if not disabled then A.buttons[#A.buttons+1]={x=x,y=y,w=w,h=h,fn=guard(fn)} end
end
local function externalWrite(path,bytes)
    path=path:gsub('\\','/');local dir,name=path:match('^(.*)/([^/]+)$');assert(dir and name,'Caminho absoluto necessário')
    local fs=FS.new(dir);fs:writeAtomic(name,bytes)
end
local function refreshGallery() A.folders=A.store:folders(A.folder);A.projects=A.store:listProjects(A.folder) end
local function setFolder(id)
    A.folder=id or '';refreshGallery()
end
local function rebuildImage()
    if A.image then A.image:release() end
    if A.imageData then A.imageData:release() end
    A.imageData=love.image.newImageData(A.buffer.width,A.buffer.height,'rgba8',Native.bytes(A.buffer))
    A.image=love.graphics.newImage(A.imageData);A.image:setFilter('nearest','nearest')
end
local function fit()
    if not A.doc then return end
    local w,h=love.graphics.getDimensions();A.zoom=math.min((w-380)/A.doc.width,(h-200)/A.doc.height)*.84
    A.panX=0;A.panY=0;A.rotation=0
end
local function openDoc(doc)
    assert(Native.available,'O editor requer o motor C++ compilado. A galeria continua disponível.')
    A.layerSession=Layers.open(A.store,doc)
    A.doc=A.layerSession.doc
    A.buffer=A.layerSession.composite
    A.screen='editor';A.dirty=false
    rebuildImage();fit()
    status('Projeto raster aberto · camadas próprias RBD2 disponíveis')
end
local function saveDoc()
    if not A.doc then return end
    A.layerSession:save()
    A.dirty=false
    status('Projeto RBD2 salvo · revisão '..tostring(A.doc.revision))
end
local function toGallery()
    if A.doc and A.dirty then saveDoc() end
    A.screen='gallery';refreshGallery()
end
local function exportPNG()
    assert(A.doc,'Nenhum projeto aberto')
    local name=A.doc.id..'-r'..A.doc.revision..'.png'
    local data=love.image.newImageData(A.doc.width,A.doc.height,'rgba8',Native.bytes(A.buffer))
    local encoded=data:encode('png');A.store.fs:writeAtomic('exports/'..name,encoded:getString());data:release()
    status('PNG exportado: exports/'..name)
    return name
end
local function modal(kind)
    if kind=='new' and not Native.available then status('Criação de raster requer rebuild_core.dll. Consulte o diagnóstico de compilação.');return end
    A.modal={kind=kind,focus=1,values=kind=='new' and {'Sem título','512','512'} or {''}}
    love.keyboard.setTextInput(true)
end
local function submitModal()
    local m=A.modal
    if m.kind=='folder' then
        A.store:createFolder(m.values[1],A.folder);A.modal=nil;refreshGallery();status('Pasta criada')
    elseif m.kind=='new' then
        local w,h=tonumber(m.values[2]),tonumber(m.values[3])
        assert(w and h and w==math.floor(w) and h==math.floor(h) and w>=1 and h>=1 and w<=2048 and h<=2048,'Use dimensões inteiras de 1 a 2048 nesta etapa')
        local buffer=Native.buffer(w,h);Native.clear(buffer,0)
        local doc=A.store:createProject(m.values[1],w,h,A.folder,Native.bytes(buffer))
        A.modal=nil;openDoc(doc)
    elseif m.kind=='rename' then
        A.doc.name=m.values[1];saveDoc();A.modal=nil
    end
    love.keyboard.setTextInput(A.modal~=nil)
end
local function canvasTransform()
    local w,h=love.graphics.getDimensions();return (w-280)/2+A.panX,(h+56)/2+A.panY
end
local function canvasPoint(mx,my)
    local cx,cy=canvasTransform();local dx,dy=(mx-cx)/A.zoom,(my-cy)/A.zoom
    local ca,sa=math.cos(-A.rotation),math.sin(-A.rotation)
    return dx*ca-dy*sa+A.doc.width/2,dx*sa+dy*ca+A.doc.height/2
end
local function nativeSelfTest()
    assert(Native.available,'C++ indisponível; não é permitido substituir por um mock Lua')
    assert(Native.pressure(.25,true,0,1)==.25)
    assert(Native.pressure(5,false,10,10)==1)
    local value,accepted=Native.thickness(.2,-2);assert(accepted and value==-2)
    value,accepted=Native.thickness(.2,3);assert(not accepted and math.abs(value-.2)<1e-6)
    local packed=Native.pack({{id=9,info=7,x=1,y=2,previous_x=3,previous_y=4,pressure=.5,altitude=.6,azimuth=.7,time=101,stylus=false}})
    assert(#packed.ints==2 and #packed.floats==7 and #packed.times==1 and packed.floats[6]==0 and packed.floats[7]==0)
    local buf=Native.buffer(9,7);Native.clear(buf,0);Native.pixel(buf,8,6,0x123456ff)
    assert(Native.readPixel(buf,8,6)==0x123456ff)
    local stroke=Native.buffer(9,7);Native.clear(stroke,0)
    Native.basicStroke(stroke,1.5,2.5,6.5,2.5,1,0xaabbccff,1)
    assert(Native.readPixel(stroke,4,2)==0xaabbccff,'Traço básico contínuo C++ falhou')
    assert(Native.readPixel(stroke,4,3)==0,'Traço básico atingiu pixel fora do segmento')
    local doc=A.store:createProject('Fixture nativa',9,7,'',Native.bytes(buf));openDoc(doc);saveDoc()
    local reopened=A.store:openProject(doc.id)
    assert(reopened.format==2 and reopened.layers[1].pixels==Native.bytes(buf),
        'Migração RBD1/RBD2 falhou')
    A.layerSession:add('Teste acima')
    A.layerSession:pixel(1,1,0xe53b44ff)
    assert(Native.readPixel(A.buffer,1,1)==0xe53b44ff,'Composição RBD2 nativa falhou')
    A.layerSession:setVisible(2,false)
    assert(Native.readPixel(A.buffer,1,1)==0,'Ocultação de camada falhou')
    A.layerSession:setVisible(2,true)
    saveDoc()
    local layered=A.store:openProject(doc.id)
    assert(layered.layer_count==2 and layered.layers[2].pixels:sub(41,44)==string.char(229,59,68,255),
        'Camada RBD2 não reabriu sem perda de pixel')
    local png=exportPNG();local pngData=A.store.fs:read('exports/'..png)
    local image=love.image.newImageData(love.filesystem.newFileData(pngData,'oracle.png'))
    local r,g,b,a=image:getPixel(8,6);assert(math.abs(r-18/255)<1/255 and math.abs(g-52/255)<1/255 and math.abs(b-86/255)<1/255 and a==1)
    image:release()
    return {abi=1,buffer_roundtrip=true,pressure_contract=true,thickness_contract=true,pointer_contract=true,png_pixels=true,basic_desktop_stroke=true,layered_roundtrip=true,android_runtime_compared=false}
end
function love.load(args)
    A.fonts={small=love.graphics.newFont(12),body=love.graphics.newFont(14),title=love.graphics.newFont(25),large=love.graphics.newFont(40)}
    local options={}
    for i=1,#args do
        if args[i]=='--data-dir' then options.data=args[i+1]
        elseif args[i]=='--report' then options.report=args[i+1]
        elseif args[i]=='--capture' then options.capture=args[i+1]
        elseif args[i]=='--lua-test' then options.luaTest=true
        elseif args[i]=='--self-test' then options.selfTest=true end
    end
    A.options=options;local base=love.filesystem.getSourceBaseDirectory()
    package.path=base..'/?.lua;'..base..'/?/init.lua;'..package.path
    Native.load(base)
    A.root=options.data or (base..'/user-data');A.store=Store.open(A.root)
    A.preferences=A.store:getPreferences() or {};A.brushes=A.store:getBrushes() or {}
    refreshGallery();status(Native.available and 'Motor C++ v1 carregado' or 'Galeria disponível · motor C++ ainda não compilado')
    if options.luaTest or options.selfTest then
        A.testReport={kind='stage1-executable-tests',native_loaded=Native.available,android_runtime_compared=false}
        local ok,err=pcall(function()
            local run=require('tests.test_store').run
            A.testReport.storage=run(A.root..'/storage-fixtures')
            if options.selfTest then A.testReport.native=nativeSelfTest() end
        end)
        A.testReport.ok=ok;A.testReport.error=not ok and tostring(err) or nil
        A.testReport.test_mode=options.selfTest and 'lua-native-integration' or 'lua-storage-only'
        A.testFrames=0
        local ffi=require('ffi')
        ffi.cdef[[void* GetActiveWindow(void); int ShowWindow(void*,int);]]
        local user=ffi.load('user32');local hwnd=user.GetActiveWindow()
        if hwnd~=nil then user.ShowWindow(hwnd,0) end
    end
end
function love.errorhandler(message)
    local detail=debug.traceback(tostring(message),2)
    io.stderr:write(detail..'\n')
    if A.options and A.options.report then
        pcall(externalWrite,A.options.report,JSON.encode({ok=false,error=detail,native_loaded=Native.available,android_runtime_compared=false}))
    end
    return function()return 2 end
end
function love.update(dt)
    if A.testReport then
        A.testFrames=A.testFrames+1
        if A.testFrames==2 and not A.options.selfTest and A.testReport.ok then
            local ok,err=pcall(function()
                -- Exercise the real Lua controls, not a separate gallery mock.
                local width=love.graphics.getWidth()
                love.mousepressed(width-100,134,1)
                assert(A.modal and A.modal.kind=='folder','Botão Nova pasta não abriu formulário')
                love.textinput('Estudos');love.keypressed('return')
                assert(#A.folders==1 and A.folders[1].name=='Estudos','Criação pela interface falhou')
                local id=A.folders[1].id
                love.draw();love.mousepressed(80,295,1)
                assert(A.folder==id,'Navegação de pasta falhou')
                love.draw();love.mousepressed(width-100,134,1)
                love.textinput('Subpasta');love.keypressed('return')
                assert(#A.folders==1 and A.folders[1].name=='Subpasta','Criação de subpasta falhou')
                love.draw();love.mousepressed(80,220,1)
                assert(A.folder=='' and #A.folders==1,'Retorno à raiz falhou')
                local reopened=Store.open(A.root)
                assert(reopened:folders(id)[1].name=='Subpasta','UI não persistiu a hierarquia')
                A.testReport.ui={folder_form=true,unicode_text_input=true,navigation=true,nested_folder_persisted=true}
            end)
            if not ok then A.testReport.ok=false;A.testReport.error=tostring(err)end
        end
        if A.testFrames==2 and A.options.selfTest and A.testReport.ok then
            local ok,err=pcall(function()
                assert(A.screen=='editor' and A.sideTab=='layers',
                    'Teste GUI de camadas requer editor real')
                local panel=love.graphics.getWidth()-268
                local before=#A.doc.layers
                love.draw()
                love.mousepressed(panel+45,448,1)
                assert(#A.doc.layers==before+1 and A.doc.active_layer==before+1,
                    'Botão Nova camada não atualizou a sessão')
                love.draw()
                love.mousepressed(panel+165,448,1)
                assert(#A.doc.layers==before,'Botão Excluir não atualizou a sessão')
                saveDoc()
                local reopened=A.store:openProject(A.doc.id)
                assert(reopened.layer_count==before,'Controles GUI não persistiram RBD2')
                A.testReport.ui={layer_add_button=true,layer_delete_button=true,
                    persisted_from_real_editor=true}
            end)
            if not ok then
                A.testReport.ok=false
                A.testReport.error='layer-controls: '..tostring(err)
            end
        end
        if A.testFrames==3 and A.options.capture then
            love.graphics.captureScreenshot(function(image)
                local ok,err=pcall(externalWrite,A.options.capture,image:encode('png'):getString())
                A.testReport.capture=ok;A.testReport.capture_error=not ok and tostring(err) or nil;A.captureDone=true
            end)
        end
        if (not A.options.capture and A.testFrames>3) or (A.captureDone and A.testFrames>4) then
            if A.options.report then externalWrite(A.options.report,JSON.encode(A.testReport)) end
            love.event.quit(A.testReport.ok and 0 or 2)
        elseif A.testFrames>120 then
            A.testReport.ok=false;A.testReport.error='Timeout na captura'
            if A.options.report then externalWrite(A.options.report,JSON.encode(A.testReport)) end
            love.event.quit(3)
        end
    end
end
local function drawGallery(w,h)
    text('Meus desenhos',42,106,'large');text('Projetos locais editáveis · organização offline',44,163,'body','muted')
    button('Nova tela',w-322,113,140,42,function()modal('new')end,true,not Native.available)
    button('Nova pasta',w-168,113,126,42,function()modal('folder')end)
    button('Raiz',44,206,70,32,function()setFolder('')end,A.folder=='')
    if A.folder~='' then text('/ '..A.folder,127,213,'small','muted') end
    local colw=230;local cols=math.max(1,math.floor((w-88)/colw));local index=0
    local function card(label,sub,folder,fn)
        local x=44+(index%cols)*colw;local y=266+math.floor(index/cols)*172;index=index+1
        if y+150>h-66 then return end
        box(x,y,212,148,'card')
        if folder then
            c('accent');love.graphics.rectangle('fill',x+20,y+26,48,33,5,5);love.graphics.rectangle('fill',x+20,y+18,23,14,3,3)
        else
            c('line');love.graphics.rectangle('fill',x+18,y+16,176,74,3,3)
            c('muted');love.graphics.rectangle('line',x+77,y+27,58,52)
        end
        text(label:sub(1,30),x+18,y+102,'body');text(sub,x+18,y+124,'small','muted')
        A.buttons[#A.buttons+1]={x=x,y=y,w=212,h=148,fn=guard(fn)}
    end
    for _,folder in ipairs(A.folders) do card(folder.name,'Pasta',true,function()setFolder(folder.id)end) end
    for _,doc in ipairs(A.projects) do card(doc.name,doc.width..' × '..doc.height..' · r'..(doc.revision or 1),false,function()openDoc(A.store:openProject(doc.id))end) end
    if index==0 then
        text('Uma galeria vazia, pronta para a primeira tela.',44,290,'title','muted')
        text('Crie uma pasta ou uma tela. Tudo é salvo neste computador.',44,335,'body','muted')
    end
end
local function drawEditor(w,h)
    local panel=w-268
    button('← Galeria',20,78,112,34,toGallery)
    button('Inspecionar',144,78,100,34,function()A.tool='inspect'end,A.tool=='inspect')
    button('Pixel diagnóstico',254,78,143,34,function()A.tool='pixel'end,A.tool=='pixel')
    button('Pincel básico',407,78,138,34,function()A.tool='brush'end,A.tool=='brush')
    button('Ajustar',555,78,76,34,fit)
    local cx,cy=canvasTransform()
    love.graphics.setScissor(16,125,panel-32,h-194)
    love.graphics.push();love.graphics.translate(cx,cy);love.graphics.rotate(A.rotation);love.graphics.scale(A.zoom)
    local dw,dh=A.doc.width,A.doc.height
    local checker=math.max(8,math.ceil(math.max(dw,dh)/64))
    for y=0,dh-1,checker do for x=0,dw-1,checker do
        local light=(math.floor(x/checker)+math.floor(y/checker))%2==0
        love.graphics.setColor(light and .85 or .73,light and .85 or .73,light and .85 or .73)
        love.graphics.rectangle('fill',x-dw/2,y-dh/2,math.min(checker,dw-x),math.min(checker,dh-y))
    end end
    love.graphics.setColor(1,1,1);love.graphics.draw(A.image,-dw/2,-dh/2)
    c('accent');love.graphics.setLineWidth(1/A.zoom);love.graphics.rectangle('line',-dw/2,-dh/2,dw,dh)
    love.graphics.pop();love.graphics.setScissor()
    box(panel,64,268,h-112,'panel')
    text('PROJETO',panel+20,88,'small','muted');text(A.doc.name:sub(1,28),panel+20,115,'title')
    text(dw..' × '..dh..' · RGBA8',panel+20,150,'body','muted')
    button('Salvar · Ctrl+S',panel+20,186,228,38,saveDoc,A.dirty)
    button('Exportar PNG',panel+20,234,228,38,exportPNG)
    button('Renomear',panel+20,282,228,34,function()modal('rename');A.modal.values[1]=A.doc.name end)
    text('PAINEL',panel+20,343,'small','muted')
    button('Camadas',panel+20,366,107,32,function()A.sideTab='layers'end,A.sideTab=='layers')
    button('Pincel',panel+139,366,109,32,function()A.sideTab='brush'end,A.sideTab=='brush')
    if A.sideTab=='layers' then
        local ls=A.layerSession
        local count=#A.doc.layers
        text(('RASTERS %d / %d · NORMAL'):format(count,Store.MAX_LAYERS),panel+20,407,'small','muted')
        button('+ Camada',panel+20,431,109,34,function()
            ls:add();A.dirty=true;rebuildImage();status('Camada raster adicionada')
        end,false,count>=Store.MAX_LAYERS)
        button('Excluir',panel+139,431,109,34,function()
            ls:remove(A.doc.active_layer);A.dirty=true;rebuildImage()
            status('Camada removida')
        end,false,count<=1)
        -- Reserve the footer actions even at the minimum 640px window height.
        local rows=math.max(1,math.min(6,math.floor((h-131-475)/30)))
        local start=math.max(1,math.min(A.doc.active_layer-math.floor(rows/2),count-rows+1))
        local stop=math.min(count,start+rows-1)
        local y=475
        for i=stop,start,-1 do
            local layer=A.doc.layers[i]
            button((layer.visible and '● ' or '○ ')..i..' '..layer.name:sub(1,17),
                panel+20,y,228,27,function()if A.doc.active_layer~=i then ls:select(i);A.dirty=true end end,A.doc.active_layer==i)
            y=y+30
        end
        local active=A.doc.layers[A.doc.active_layer]
        do
            local actionY=h-131
            local opacityY=h-94
            button(active.visible and 'Ocultar' or 'Mostrar',panel+20,actionY,109,30,function()
                ls:setVisible(A.doc.active_layer,not active.visible)
                A.dirty=true;rebuildImage()
            end,active.visible)
            button('Acima',panel+139,actionY,54,30,function()
                local i=A.doc.active_layer
                ls:move(i,math.min(count,i+1));A.dirty=true;rebuildImage()
            end,false,A.doc.active_layer==count)
            button('Abaixo',panel+196,actionY,52,30,function()
                local i=A.doc.active_layer
                ls:move(i,math.max(1,i-1));A.dirty=true;rebuildImage()
            end,false,A.doc.active_layer==1)
            button('−',panel+20,opacityY,42,29,function()
                ls:setOpacity(A.doc.active_layer,math.max(0,active.opacity-.1))
                A.dirty=true;rebuildImage()
            end)
            text(('Opacidade %.0f%%'):format(active.opacity*100),panel+68,opacityY+8,'small')
            button('+',panel+206,opacityY,42,29,function()
                ls:setOpacity(A.doc.active_layer,math.min(1,active.opacity+.1))
                A.dirty=true;rebuildImage()
            end)
        end
    else
        text('PINCEL PRÓPRIO · NÃO EQUIVALENTE',panel+20,429,'small','muted')
        button('−',panel+20,456,46,32,function()
            A.brushDiameter=math.max(1,A.brushDiameter-2)end)
        text(('Diâmetro %.0f px'):format(A.brushDiameter),panel+77,464,'small')
        button('+',panel+182,456,46,32,function()
            A.brushDiameter=math.min(256,A.brushDiameter+2)end)
        text('COR',panel+20,511,'small','muted')
        for i,swatch in ipairs(swatches) do
            local x=panel+20+(i-1)*36
            local color=swatch.rgba
            love.graphics.setColor(math.floor(color/16777216)%256/255,
                math.floor(color/65536)%256/255,math.floor(color/256)%256/255,1)
            love.graphics.rectangle('fill',x,535,29,27,4,4)
            if A.color==color then
                c('accent');love.graphics.setLineWidth(2)
                love.graphics.rectangle('line',x-2,533,33,31,4,4)
            end
            A.buttons[#A.buttons+1]={x=x,y=533,w=33,h=31,
                fn=function()A.color=swatch.rgba;status('Cor: '..swatch.name)end}
        end
        text('ENTRADA',panel+20,589,'small','muted')
        text('Mouse · pressão 1 · ângulos 0',panel+20,616,'small','muted')
        if A.lastPacket then
            local f=A.lastPacket.floats
            text(('x %.1f  y %.1f · p %.3f'):format(f[1],f[2],f[5]),
                panel+20,646,'small','muted')
        end
        text('Rasterização Android desconhecida',panel+20,705,'small','muted')
    end
    text(('Zoom %.0f%% · rotação %.0f°'):format(A.zoom*100,math.deg(A.rotation)),22,h-72,'small','muted')
end
local function drawModal(w,h)
    love.graphics.setColor(0,0,0,.70);love.graphics.rectangle('fill',0,0,w,h)
    local x,y=w/2-220,h/2-210;box(x,y,440,420,'panel')
    local m=A.modal;local title=m.kind=='new' and 'Criar tela' or m.kind=='folder' and 'Criar pasta' or 'Renomear projeto'
    text(title,x+24,y+24,'title')
    local names=m.kind=='new' and {'Nome','Largura','Altura'} or {'Nome'}
    for i,label in ipairs(names) do
        local fy=y+86+(i-1)*72;text(label,x+24,fy,'small','muted')
        box(x+24,fy+20,392,38,'card');if m.focus==i then c('accent');love.graphics.rectangle('line',x+24,fy+20,392,38,5,5)end
        text(m.values[i]..(m.focus==i and '|' or ''),x+36,fy+30,'body')
        A.buttons[#A.buttons+1]={x=x+24,y=fy+20,w=392,h=38,fn=function()m.focus=i end}
    end
    if m.kind=='new' then text('Fundo transparente · limite inicial 2048 × 2048',x+24,y+314,'small','muted')end
    button('Cancelar',x+24,y+357,150,38,function()A.modal=nil;love.keyboard.setTextInput(false)end)
    button('Criar / confirmar',x+190,y+357,226,38,submitModal,true)
end
function love.draw()
    A.buttons={};local w,h=love.graphics.getDimensions();c('bg');love.graphics.clear(palette.bg)
    box(0,0,w,64,'panel');text('DESKTOP REBUILD',24,17,'title')
    text('ibisPaint Android 14.1.2 · etapa 1',285,24,'body','muted')
    text(Native.available and 'Lua ↔ C++ · offline' or 'Lua · C++ indisponível',w-222,24,'small',Native.available and 'accent' or 'warn')
    if A.screen=='gallery' then drawGallery(w,h)else drawEditor(w,h)end
    box(0,h-48,w,48,'panel');text(A.message or '',20,h-33,'small','muted')
    if A.testReport then text(A.testReport.ok and 'TESTES LUA OK' or 'FALHA NOS TESTES',w-220,h-32,'small',A.testReport.ok and 'accent' or 'warn')end
    if A.modal then A.buttons={};drawModal(w,h)end
end
function love.mousepressed(x,y,buttonNumber)
    if buttonNumber==1 then
        for i=#A.buttons,1,-1 do local b=A.buttons[i];if x>=b.x and x<=b.x+b.w and y>=b.y and y<=b.y+b.h then b.fn();return end end
        if A.screen=='editor' and not A.modal and x<love.graphics.getWidth()-280 and y>125 and y<love.graphics.getHeight()-78 then
            guard(function()
                local px,py=canvasPoint(x,y)
                A.lastPacket=Native.pack({{id=1,info=0,x=px,y=py,pressure=Native.pressure(1,false,0,1),time=math.floor(love.timer.getTime()*1000)}})
                if A.tool=='pixel' and px>=0 and py>=0 and px<A.doc.width and py<A.doc.height then
                    A.layerSession:pixel(math.floor(px),math.floor(py),A.color)
                    A.dirty=true;rebuildImage()
                    status('Pixel diagnóstico gravado pelo C++. Isto não é uma implementação de pincel.')
                elseif A.tool=='brush' then
                    A.layerSession:stroke(px,py,px,py,A.brushDiameter,A.color,1)
                    A.drawing=true;A.lastStrokeX=px;A.lastStrokeY=py
                    A.dirty=true;rebuildImage()
                    status('Pincel básico próprio em C++ · sem equivalência comprovada com Android')
                end
            end)()
        end
    elseif buttonNumber==3 and A.screen=='editor' then A.panning=true end
end
function love.mousereleased(x,y,b)
    if b==3 then A.panning=false end
    if b==1 then A.drawing=false;A.lastStrokeX=nil;A.lastStrokeY=nil end
end
function love.mousemoved(x,y,dx,dy)
    if A.panning then A.panX=A.panX+dx;A.panY=A.panY+dy end
    if A.drawing and A.screen=='editor' and A.tool=='brush' and not A.modal then
        guard(function()
            local px,py=canvasPoint(x,y)
            A.layerSession:stroke(A.lastStrokeX,A.lastStrokeY,px,py,
                A.brushDiameter,A.color,1)
            A.lastStrokeX=px;A.lastStrokeY=py
            A.dirty=true;rebuildImage()
        end)()
    end
end
function love.focus(focused)
    if not focused then A.drawing=false;A.lastStrokeX=nil;A.lastStrokeY=nil end
end
function love.wheelmoved(x,y)
    if A.screen=='editor' and not A.modal then
        local mx=love.mouse.getPosition()
        if mx>=love.graphics.getWidth()-268 and A.sideTab=='layers' then
            local count=#A.doc.layers
            local index=math.max(1,math.min(count,A.doc.active_layer+(y>0 and 1 or -1)))
            if y~=0 and index~=A.doc.active_layer then
                A.layerSession:select(index);A.dirty=true
            end
            return
        end
        if love.keyboard.isDown('lshift','rshift')then A.rotation=A.rotation+y*math.pi/36
        else A.zoom=math.max(.05,math.min(32,A.zoom*(1.15^y)))end
    end
end
function love.textinput(t)
    if A.modal then local i=A.modal.focus;A.modal.values[i]=A.modal.values[i]..t end
end
function love.keypressed(key)
    if A.modal then
        if key=='escape'then A.modal=nil;love.keyboard.setTextInput(false)
        elseif key=='return'then guard(submitModal)()
        elseif key=='tab'then A.modal.focus=A.modal.focus%#A.modal.values+1
        elseif key=='backspace'then local utf8=require('utf8');local s=A.modal.values[A.modal.focus];local pos=utf8.offset(s,-1);if pos then A.modal.values[A.modal.focus]=s:sub(1,pos-1)end end
        return
    end
    if (love.keyboard.isDown('lctrl','rctrl')) and key=='s'then guard(saveDoc)()
    elseif (love.keyboard.isDown('lctrl','rctrl')) and key=='n' then modal('new')
    elseif key=='escape' and A.screen=='editor' then guard(toGallery)()
    elseif key=='f' and A.screen=='editor'then fit()
    elseif key=='r' then A.rotation=0 end
end
function love.resize()if A.doc then fit()end end
function love.quit()
    if A.store then
        if A.doc and A.dirty then local ok,err=pcall(saveDoc);if not ok then status('Falha ao salvar; fechamento cancelado: '..tostring(err));return true end end
        pcall(function()A.store:setPreferences(A.preferences);A.store:saveBrushes(A.brushes)end)
    end
end
