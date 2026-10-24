local Native=require('native')
local Store=require('store')
local Layers=require('layers')
local FS=require('fs')
local JSON=require('json')
local Colors=require('colors')
local Stabilizer=require('stroke_stabilizer')
local Pressure=require('touch_pressure')
local Ink=require('windows_ink')
local View=require('canvas_view')
local EditorTools=require('editor_tools')
local Thumbnails=require('layer_thumbnails')
local dispatchInkEvent
local A={screen='gallery',folder='',dirty=false,buttons={},zoom=1,rotation=0,panX=0,panY=0,tool='inspect',color=0x192d40ff,view='grid',brushDiameter=12,brushStyle='hard',brushOpacity=1,penTiltEnabled=true,stabilization=0,stabilizer=nil,touchId=nil,inkPenId=nil,inkPreviousTool=nil,inkTiltX=0,inkTiltY=0,lastPressure=1,fillTolerance=0,shapeKind=0,pickerSource='composite',shapeFilled=false,shapeWidth=2,shapePreview=nil,drawing=false,sideTab='layers',spaceHeld=false,panning=false,panButton=nil,toolHelp=false,layerScroll=nil,layerThumbs=nil,layerThumbDirty=nil}
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
local function clearLayerThumbs()
    if A.layerThumbs then
        for _,entry in pairs(A.layerThumbs) do
            entry.image:release()
        end
    end
    A.layerThumbs={}
    A.layerThumbDirty={}
end
local function layerThumb(index)
    local layer=A.doc.layers[index]
    assert(layer and A.layerSession.buffers[index],'Camada de miniatura inválida')
    A.layerThumbs=A.layerThumbs or {}
    A.layerThumbDirty=A.layerThumbDirty or {}
    local entry=A.layerThumbs[layer.id]
    if not entry or A.layerThumbDirty[layer.id] then
        local pixels=Thumbnails.sample(A.layerSession.buffers[index])
        local imageData=love.image.newImageData(
            Thumbnails.SIZE,Thumbnails.SIZE,'rgba8',pixels)
        local image=love.graphics.newImage(imageData)
        imageData:release()
        image:setFilter('nearest','nearest')
        if entry then entry.image:release() end
        entry={image=image}
        A.layerThumbs[layer.id]=entry
        A.layerThumbDirty[layer.id]=nil
    end
    return entry.image
end
local function rebuildImage()
    if A.layerSession and A.doc and A.doc.layers then
        local layer=A.doc.layers[A.doc.active_layer]
        if layer then
            A.layerThumbDirty=A.layerThumbDirty or {}
            A.layerThumbDirty[layer.id]=true
        end
    end
    if A.image then A.image:release() end
    if A.imageData then A.imageData:release() end
    A.imageData=love.image.newImageData(A.buffer.width,A.buffer.height,'rgba8',Native.bytes(A.buffer))
    A.image=love.graphics.newImage(A.imageData);A.image:setFilter('nearest','nearest')
end
local function viewData()
    return {zoom=A.zoom,rotation=A.rotation,panX=A.panX,panY=A.panY,
        width=A.doc.width,height=A.doc.height}
end
local function commitView(v)
    A.zoom=v.zoom;A.rotation=v.rotation;A.panX=v.panX;A.panY=v.panY
end
local function fit()
    if not A.doc then return end
    local w,h=love.graphics.getDimensions()
    local v=viewData();View.fit(v,w,h);commitView(v)
end
local function zoomCanvas(factor,mx,my)
    if not A.doc then return false end
    local w,h=love.graphics.getDimensions()
    mx=mx or (w-280)/2;my=my or (h+56)/2
    local v=viewData()
    local changed=View.zoomAt(v,w,h,mx,my,factor)
    commitView(v);return changed
end
local function rotateCanvas(delta,mx,my)
    if not A.doc then return false end
    local w,h=love.graphics.getDimensions()
    mx=mx or (w-280)/2;my=my or (h+56)/2
    local v=viewData()
    local changed=View.rotateAt(v,w,h,mx,my,delta)
    commitView(v);return changed
end
local function resetCanvasRotation()
    if not A.doc then return false end
    local w,h=love.graphics.getDimensions()
    local v=viewData()
    local changed=View.resetRotation(v,w,h,(w-280)/2,(h+56)/2)
    commitView(v);return changed
end
local function openDoc(doc)
    assert(Native.available,'O editor requer o motor C++ compilado. A galeria continua disponível.')
    clearLayerThumbs()
    A.layerScroll=nil
    A.layerSession=Layers.open(A.store,doc)
    A.doc=A.layerSession.doc
    A.buffer=A.layerSession.composite
    A.screen='editor';A.dirty=false
    A.selection=nil;A.selectAction=nil;A.movePreview=nil;A.shapePreview=nil
    A.toolHelp=false
    rebuildImage();fit()
    status('Projeto raster aberto · camadas próprias RBD2 disponíveis')
end
-- All stroke styles use the same compositing and transaction boundary.
local function paintBrushSegment(x,y,pressure)
    if not A.drawing then return end
    local previousX,previousY=A.lastStrokeX,A.lastStrokeY
    A.lastPressure=Pressure.normalize(pressure or A.lastPressure)
    if x==previousX and y==previousY then return end
    local diameter=Pressure.diameter(A.brushDiameter,A.lastPressure)
    local opacity=Pressure.opacity(A.brushOpacity,A.lastPressure)
    if A.tool=='erase' then
        A.layerSession:erase(previousX,previousY,x,y,diameter,opacity)
    elseif A.inkPenId~=nil and A.penTiltEnabled and
        (A.inkTiltX~=0 or A.inkTiltY~=0) then
        A.layerSession:tiltStroke(previousX,previousY,x,y,diameter,A.color,
            opacity,A.brushStyle=='soft' and 0.25 or 1,
            A.inkTiltX,A.inkTiltY)
    elseif A.brushStyle=='soft' then
        A.layerSession:softStroke(previousX,previousY,x,y,diameter,
            A.color,opacity,0.25)
    else
        A.layerSession:stroke(previousX,previousY,x,y,diameter,A.color,opacity)
    end
    A.lastStrokeX=x;A.lastStrokeY=y
    A.dirty=true;rebuildImage()
end
local function finishStroke(finalX,finalY,pressure)
    if A.drawing and A.stabilizer then
        if finalX and finalY then
            local x,y=A.stabilizer:sample(finalX,finalY)
            paintBrushSegment(x,y,pressure)
        end
        -- Final endpoint correction avoids dropped last pixel when smoothing.
        local x,y=A.stabilizer:finish()
        paintBrushSegment(x,y,pressure)
    end
    if A.layerSession and A.layerSession.pending then A.layerSession:finishEdit() end
    A.drawing=false;A.stabilizer=nil;A.lastStrokeX=nil;A.lastStrokeY=nil
end
local function selectTool(id)
    local item=EditorTools.fromId(id)
    assert(item,'Ferramenta inválida')
    -- A tap on a toolbar button owns a touch/pen contact, but is not a
    -- drawing stroke. Reject only mid-stroke device tool changes.
    if A.screen~='editor' or
        (A.drawing and (A.inkPenId~=nil or A.touchId~=nil)) then
        return false
    end
    finishStroke()
    if A.tool~=id then A.shapePreview=nil end
    A.tool=id
    local tab=EditorTools.panelFor(id)
    if tab then A.sideTab=tab end
    return true
end
local function undoDoc()
    A.shapePreview=nil
    finishStroke()
    if A.layerSession and A.layerSession:undo() then
        A.selection=nil;A.selectAction=nil;A.movePreview=nil
        A.dirty=true;rebuildImage();status('Desfeito · apenas histórico desta sessão')
    end
end
local function redoDoc()
    A.shapePreview=nil
    finishStroke()
    if A.layerSession and A.layerSession:redo() then
        A.selection=nil;A.selectAction=nil;A.movePreview=nil
        A.dirty=true;rebuildImage();status('Refeito · apenas histórico desta sessão')
    end
end
local function saveDoc()
    A.shapePreview=nil
    finishStroke()
    if not A.doc then return end
    A.layerSession:save()
    A.dirty=false
    status('Projeto RBD2 salvo · revisão '..tostring(A.doc.revision))
end
local function toGallery()
    A.shapePreview=nil;A.toolHelp=false
    finishStroke()
    clearLayerThumbs();A.layerScroll=nil
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
    A.modal={kind=kind,focus=1,values=kind=='new' and {'Sem título','512','512'} or
        kind=='color' and {Colors.format(A.color)} or {''}}
    love.keyboard.setTextInput(true)
end
local function openLayerRename()
    if A.screen~='editor' or not A.doc then return end
    finishStroke()
    local layer=A.doc.layers[A.doc.active_layer]
    modal('renameLayer')
    A.modal.values[1]=layer.name
    A.modal.layerId=layer.id
end
local function duplicateActiveLayer()
    assert(A.screen=='editor' and A.layerSession,
        'Abra um projeto antes de duplicar')
    finishStroke()
    local index=A.layerSession:duplicate(A.doc.active_layer)
    A.layerScroll=nil
    A.dirty=true
    rebuildImage()
    status('Camada duplicada · cópia independente '..index)
    return index
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
    elseif m.kind=='renameLayer' then
        assert(A.screen=='editor' and A.layerSession and m.layerId,
            'Não existe camada para renomear')
        local index
        for i,layer in ipairs(A.doc.layers) do
            if layer.id==m.layerId then index=i;break end
        end
        assert(index,'A camada original não existe mais')
        local changed=A.layerSession:rename(index,m.values[1])
        if changed then
            A.dirty=true
            saveDoc()
            status('Camada renomeada: '..m.values[1])
        end
        A.modal=nil
    elseif m.kind=='color' then
        local value,err=Colors.parseHex(m.values[1])
        assert(value,err)
        A.color=value;A.modal=nil
        status('Cor personalizada aplicada: '..Colors.format(value))
    end
    love.keyboard.setTextInput(A.modal~=nil)
end
local function canvasTransform()
    local w,h=love.graphics.getDimensions()
    return View.center(viewData(),w,h)
end
local function canvasPoint(mx,my)
    local w,h=love.graphics.getDimensions()
    return View.toCanvas(viewData(),w,h,mx,my)
end
local function clampPixel(value,size)
    return math.max(0,math.min(size-1,math.floor(value)))
end
local function finishSelection()
    if not A.selectAction then return end
    if A.selectAction=='move' and A.selection and A.movePreview then
        local old=A.selection
        local dst=A.movePreview
        local changed=A.layerSession:moveSelection(
            old.x,old.y,old.w,old.h,dst.x,dst.y)
        if changed then A.dirty=true;rebuildImage() end
        A.selection={x=dst.x,y=dst.y,w=old.w,h=old.h}
        status(changed and 'Seleção movida · Ctrl+Z desfaz' or 'Seleção mantida')
    end
    A.selectAction=nil;A.movePreview=nil
end
local function applySelectionTransform(turns,scale)
    finishSelection()
    assert(A.screen=='editor' and A.tool=='select' and A.selection,
        'Selecione uma região retangular primeiro')
    local rect=A.selection
    local w,h=rect.w,rect.h
    if turns%2==1 then w,h=h,w end
    local factor=scale or 1
    w=math.max(1,math.floor(w*factor+0.5))
    h=math.max(1,math.floor(h*factor+0.5))
    assert(w<=A.doc.width and h<=A.doc.height,
        'O tamanho transformado ultrapassa as dimensões do canvas')
    local x=math.min(rect.x,A.doc.width-w)
    local y=math.min(rect.y,A.doc.height-h)
    local changed=A.layerSession:transformSelection(
        rect.x,rect.y,rect.w,rect.h,x,y,w,h,turns)
    if changed then A.dirty=true;rebuildImage() end
    A.selection={x=x,y=y,w=w,h=h}
    A.movePreview=nil
    status(changed and ('Seleção transformada ('..w..' × '..h..
        ') · Ctrl+Z desfaz') or 'Seleção mantida')
end
local function finishShape()
    local rect=A.shapePreview
    A.shapePreview=nil
    if not rect or A.screen~='editor' then return end
    local changed
    if A.shapeKind==2 then
        changed=A.layerSession:straightLine(rect.x0,rect.y0,rect.x1,rect.y1,
            A.shapeWidth,A.color)
    else
        changed=A.layerSession:drawShape(rect.x0,rect.y0,rect.x1,rect.y1,
            A.shapeKind,A.shapeFilled,A.shapeWidth,A.color)
    end
    if changed then A.dirty=true;rebuildImage() end
    status(changed and 'Forma raster criada · Ctrl+Z desfaz' or 'Forma não alterou pixels')
end
local function pickColor(px,py)
    if px<0 or py<0 or px>=A.doc.width or py>=A.doc.height then return false end
    local buffer=A.pickerSource=='active' and A.layerSession:activeBuffer()
        or A.buffer
    A.color=Native.readPixel(buffer,math.floor(px),math.floor(py))
    status('Conta-gotas ('..(A.pickerSource=='active' and 'camada' or 'composição')..
        '): '..Colors.format(A.color))
    return true
end
local function openColorModal() modal('color') end
local function editShapeColorButton(panel,y)
    button('Cor RGBA: '..Colors.format(A.color),panel+20,y,228,30,openColorModal)
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
    -- C++ erases only selected layer, then undo/redo restores its exact RGBA bytes.
    A.layerSession:beginEdit()
    A.layerSession:erase(1.5,1.5,1.5,1.5,1,1)
    assert(Native.readPixel(A.layerSession:activeBuffer(),1,1)==0,
        'Borracha não removeu alfa da camada ativa')
    assert(Native.readPixel(A.buffer,1,1)==0,'Pré-visualização não refletiu a borracha')
    assert(A.layerSession:finishEdit(),'Traço de borracha deveria gerar passo de histórico')
    assert(A.layerSession:undo(),'Não foi possível desfazer borracha')
    assert(Native.readPixel(A.buffer,1,1)==0xe53b44ff,'Undo não restaurou pixel exato')
    assert(A.layerSession:redo(),'Não foi possível refazer borracha')
    assert(Native.readPixel(A.buffer,1,1)==0,'Redo não restaurou transparência')
    assert(A.layerSession:undo(),'Fixture não conseguiu restaurar o pixel-alvo da GUI')
    assert(Native.readPixel(A.buffer,1,1)==0xe53b44ff,'Fixture GUI sem pixel restaurado')
    return {abi=1,buffer_roundtrip=true,pressure_contract=true,thickness_contract=true,pointer_contract=true,png_pixels=true,basic_desktop_stroke=true,basic_desktop_eraser=true,session_undo_redo=true,layered_roundtrip=true,android_runtime_compared=false}
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
    A.inkAttached=Ink.init(Native)
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
    if A.inkAttached and dispatchInkEvent then
        for _,event in ipairs(Ink.poll()) do dispatchInkEvent(event) end
    end
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
                assert(A.inkAttached and Ink.lib.rb_ink_is_attached()==1,
                    'A ponte Windows Ink não se anexou à janela LÖVE real')
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
                -- Exercise the real eraser toolbar and undo/redo buttons.
                local source=Native.readPixel(A.layerSession:activeBuffer(),1,1)
                assert(source==0xe53b44ff,'Fixture UI sem pixel-alvo')
                love.draw();love.mousepressed(312,90,1)
                assert(A.tool=='erase','Botão Borracha não selecionou ferramenta')
                local ox,oy=canvasTransform()
                local px=ox+(1.5-A.doc.width/2)*A.zoom
                local py=oy+(1.5-A.doc.height/2)*A.zoom
                love.draw();love.mousepressed(px,py,1)
                love.mousereleased(px,py,1)
                assert(Native.readPixel(A.layerSession:activeBuffer(),1,1)==0,
                    'Borracha pela GUI não apagou')
                love.draw();love.mousepressed(panel+160,298,1)
                assert(Native.readPixel(A.layerSession:activeBuffer(),1,1)==source,
                    'Botão desfazer não restaurou a pincelada')
                love.draw();love.mousepressed(panel+215,298,1)
                assert(Native.readPixel(A.layerSession:activeBuffer(),1,1)==0,
                    'Botão refazer não aplicou a borracha')
                -- Use the real selector and drag events against the same canvas.
                undoDoc()
                assert(Native.readPixel(A.layerSession:activeBuffer(),1,1)==source,
                    'Fixture da seleção não foi restaurada')
                love.draw();love.mousepressed(435,90,1)
                assert(A.tool=='select','Botão de seleção não ativou')
                love.draw();love.mousepressed(px,py,1)
                love.mousereleased(px,py,1)
                assert(A.selection and A.selection.x==1 and A.selection.y==1 and
                    A.selection.w==1 and A.selection.h==1,'Seleção por clique falhou')
                love.draw();love.mousepressed(px,py,1)
                love.mousemoved(px+2*A.zoom,py,2*A.zoom,0)
                love.mousereleased(px+2*A.zoom,py,1)
                assert(Native.readPixel(A.layerSession:activeBuffer(),1,1)==0,
                    'Mover seleção não limpou origem')
                assert(Native.readPixel(A.layerSession:activeBuffer(),3,1)==source,
                    'Mover seleção não chegou ao destino')
                undoDoc()
                assert(Native.readPixel(A.layerSession:activeBuffer(),1,1)==source,
                    'Desfazer movimento não restaurou origem')
                redoDoc()
                assert(Native.readPixel(A.layerSession:activeBuffer(),3,1)==source,
                    'Refazer movimento não restaurou destino')
                saveDoc()
                local persisted=A.store:openProject(A.doc.id)
                assert(persisted.layers[2].pixels:sub(49,52)==string.char(229,59,68,255),
                    'RBD2 não preservou pixels movidos pela seleção GUI')
                A.layerSession:pixel(4,1,0x20ba84ff)
                rebuildImage()
                A.selection={x=3,y=1,w=2,h=1}
                love.draw()
                love.mousepressed(panel+185,470,1)
                assert(A.selection and A.selection.w==1 and A.selection.h==2,
                    'Botão 90° não trocou dimensões da seleção')
                assert(Native.readPixel(A.layerSession:activeBuffer(),3,2)==0x20ba84ff,
                    'Rotação pela interface não reposicionou pixels')
                assert(Native.readPixel(A.layerSession:activeBuffer(),4,1)==0,
                    'Rotação não limpou origem')
                love.draw()
                love.mousepressed(panel+185,519,1)
                assert(A.selection.w==2 and A.selection.h==4,
                    'Botão 200% não redimensionou seleção')
                assert(Native.readPixel(A.layerSession:activeBuffer(),4,4)==0x20ba84ff,
                    'Escala por vizinho próximo incorreta')
                undoDoc()
                assert(Native.readPixel(A.layerSession:activeBuffer(),4,4)==0,
                    'Desfazer escala falhou')
                redoDoc()
                assert(Native.readPixel(A.layerSession:activeBuffer(),4,4)==0x20ba84ff,
                    'Refazer escala falhou')
                saveDoc()
                local transformed=A.store:openProject(A.doc.id)
                local offset=(4*A.doc.width+4)*4+1
                assert(transformed.layers[2].pixels:sub(offset,offset+3)==
                    string.char(32,186,132,255),
                    'RBD2 não persistiu escala após reabertura')
                -- Click real color palette, bucket toolbar, canvas, undo/redo.
                love.draw()
                love.mousepressed(374,90,1)
                assert(A.tool=='fill','Botão Balde não selecionou ferramenta')
                love.draw()
                love.mousepressed(panel+176,546,1)
                assert(A.color==0x347ce9ff,'Paleta de cores não selecionou azul')
                assert(A.fillTolerance==0,'Balde não iniciou com tolerância exata')
                love.draw()
                love.mousepressed(panel+215,472,1)
                assert(A.fillTolerance==8,'Controle + tolerância não respondeu')
                love.draw()
                love.mousepressed(panel+44,472,1)
                assert(A.fillTolerance==0,'Controle − tolerância não respondeu')
                local bx=ox+(0.5-A.doc.width/2)*A.zoom
                local by=oy+(0.5-A.doc.height/2)*A.zoom
                love.draw()
                love.mousepressed(bx,by,1)
                love.mousereleased(bx,by,1)
                assert(Native.readPixel(A.layerSession:activeBuffer(),0,0)==0x347ce9ff,
                    'Balde GUI não preencheu região transparente')
                assert(Native.readPixel(A.layerSession:activeBuffer(),3,1)==source,
                    'Balde atravessou cor de outra região')
                undoDoc()
                assert(Native.readPixel(A.layerSession:activeBuffer(),0,0)==0,
                    'Undo não removeu preenchimento')
                redoDoc()
                assert(Native.readPixel(A.layerSession:activeBuffer(),0,0)==0x347ce9ff,
                    'Redo não restaurou preenchimento')
                saveDoc()
                local filled=A.store:openProject(A.doc.id)
                assert(filled.layers[2].pixels:sub(1,4)==string.char(52,124,233,255),
                    'Preenchimento não persistiu no RBD2')
                -- Test the real shapes toolbar, outline width, color, drag and filled ellipse.
                love.draw();love.mousepressed(501,90,1)
                assert(A.tool=='shape','Botão Formas não selecionou ferramenta')
                love.draw();love.mousepressed(panel+40,510,1)
                assert(A.shapeWidth==1,'Espessura da forma não foi ajustada')
                love.draw();love.mousepressed(panel+99,560,1)
                assert(A.color==0xe53b44ff,'Paleta de formas não selecionou vermelho')
                local point=function(ix,iy)
                    return ox+(ix+.5-A.doc.width/2)*A.zoom,
                        oy+(iy+.5-A.doc.height/2)*A.zoom
                end
                local x0,y0=point(5,1)
                local x1,y1=point(7,3)
                local previous=Native.readPixel(A.layerSession:activeBuffer(),5,1)
                local previousInterior=Native.readPixel(A.layerSession:activeBuffer(),6,2)
                love.draw();love.mousepressed(x0,y0,1)
                love.mousemoved(x1,y1,x1-x0,y1-y0)
                assert(A.shapePreview and A.shapePreview.x1==7 and
                    A.shapePreview.y1==3,'Pré-visualização da forma não acompanha arraste')
                assert(Native.readPixel(A.layerSession:activeBuffer(),5,1)==previous,
                    'Arraste alterou raster antes de soltar o mouse')
                love.mousereleased(x1,y1,1)
                assert(not A.shapePreview,'Pré-visualização não foi finalizada')
                assert(Native.readPixel(A.layerSession:activeBuffer(),5,1)==0xe53b44ff,
                    'Retângulo não desenhou borda')
                assert(Native.readPixel(A.layerSession:activeBuffer(),6,2)==previousInterior,
                    'Contorno desenhou no centro')
                undoDoc()
                assert(Native.readPixel(A.layerSession:activeBuffer(),5,1)==previous,
                    'Desfazer forma não restaurou pixel original')
                redoDoc()
                assert(Native.readPixel(A.layerSession:activeBuffer(),5,1)==0xe53b44ff,
                    'Refazer forma não restaurou borda')
                love.draw();love.mousepressed(panel+186,425,1)
                love.draw();love.mousepressed(panel+186,467,1)
                assert(A.shapeKind==1 and A.shapeFilled,'Elipse preenchida não selecionada')
                love.draw();love.mousepressed(panel+138,561,1)
                assert(A.color==0x20ba84ff,'Paleta de formas não selecionou verde')
                local ex0,ey0=point(4,4)
                local ex1,ey1=point(8,6)
                local outerPrevious=Native.readPixel(A.layerSession:activeBuffer(),4,4)
                love.draw();love.mousepressed(ex0,ey0,1)
                love.mousemoved(ex1,ey1,ex1-ex0,ey1-ey0)
                love.mousereleased(ex1,ey1,1)
                assert(Native.readPixel(A.layerSession:activeBuffer(),6,5)==0x20ba84ff,
                    'Elipse preenchida não desenhou o centro')
                assert(Native.readPixel(A.layerSession:activeBuffer(),4,4)==outerPrevious,
                    'Elipse desenhou fora da região geométrica')
                saveDoc()
                local withShapes=A.store:openProject(A.doc.id)
                local offset=(5*A.doc.width+6)*4+1
                assert(withShapes.layers[2].pixels:sub(offset,offset+3)==
                    string.char(32,186,132,255),
                    'RBD2 não guardou elipse após salvar')
                -- Edit a custom RGBA color with actual dialog, keyboard and validation.
                love.draw();love.mousepressed(panel+120,656,1)
                assert(A.modal and A.modal.kind=='color',
                    'Botão Cor RGBA não abriu modal')
                for i=1,9 do love.keypressed('backspace') end
                love.textinput('INVALID')
                love.keypressed('return')
                assert(A.modal and A.modal.kind=='color',
                    'Cor inválida fechou o modal')
                for i=1,7 do love.keypressed('backspace') end
                love.textinput('#5A24C0BB')
                love.keypressed('return')
                assert(not A.modal and A.color==0x5a24c0bb,
                    'Modal não aplicou RGBA de 8 dígitos')
                love.draw();love.mousepressed(panel+120,656,1)
                for i=1,9 do love.keypressed('backspace') end
                love.textinput('#E14922')
                love.keypressed('return')
                assert(not A.modal and A.color==0xe14922ff,
                    'Cor hexadecimal de 6 dígitos não atribuiu alfa FF')
                -- Draw a straight line through real Shapes button + preview.
                love.draw();love.mousepressed(panel+55,607,1)
                assert(A.tool=='shape' and A.shapeKind==2,
                    'Botão Linha reta não selecionou o tipo')
                local lx0,ly0=point(1,6)
                local lx1,ly1=point(3,6)
                local oldLine=Native.readPixel(A.layerSession:activeBuffer(),1,6)
                love.draw();love.mousepressed(lx0,ly0,1)
                love.mousemoved(lx1,ly1,lx1-lx0,ly1-ly0)
                assert(A.shapePreview and A.shapePreview.x1==3 and
                    A.shapePreview.y1==6,'Prévia de linha não seguiu o arraste')
                assert(Native.readPixel(A.layerSession:activeBuffer(),1,6)==oldLine,
                    'Prévia da linha alterou o raster antes de soltar')
                love.mousereleased(lx1,ly1,1)
                assert(Native.readPixel(A.layerSession:activeBuffer(),1,6)==0xe14922ff
                    and Native.readPixel(A.layerSession:activeBuffer(),3,6)==0xe14922ff,
                    'Linha C++ não desenhou ambas as extremidades')
                undoDoc()
                assert(Native.readPixel(A.layerSession:activeBuffer(),1,6)==oldLine,
                    'Undo da linha falhou')
                redoDoc()
                assert(Native.readPixel(A.layerSession:activeBuffer(),3,6)==0xe14922ff,
                    'Redo da linha falhou')
                saveDoc()
                local lineSaved=A.store:openProject(A.doc.id)
                local lineOffset=(6*A.doc.width+3)*4+1
                assert(lineSaved.layers[2].pixels:sub(lineOffset,lineOffset+3)==
                    string.char(225,73,34,255),'Linha não persistiu no RBD2')
                -- Explicit two-layer sample fixture: sampling must not draw.
                Native.pixel(A.layerSession.buffers[1],1,5,0x246a90cc)
                Native.pixel(A.layerSession:activeBuffer(),1,5,0)
                A.layerSession:recompose();rebuildImage()
                A.dirty=true;saveDoc()
                love.draw();love.mousepressed(571,90,1)
                assert(A.tool=='picker','Conta-gotas não ativado')
                local pickX,pickY=point(1,5)
                local historyBefore=A.layerSession:historyStats().undo
                love.draw();love.mousepressed(pickX,pickY,1)
                love.mousereleased(pickX,pickY,1)
                assert(A.color==0x246a90cc,
                    'Conta-gotas visível não capturou camada inferior')
                love.draw();love.mousepressed(panel+185,436,1)
                assert(A.pickerSource=='active','Modo camada ativa não selecionado')
                love.draw();love.mousepressed(pickX,pickY,1)
                love.mousereleased(pickX,pickY,1)
                assert(A.color==0,'Conta-gotas ativo não capturou alfa zero')
                assert(A.layerSession:historyStats().undo==historyBefore,
                    'Capturar cor alterou histórico de desenho')
                assert(Native.readPixel(A.layerSession.buffers[1],1,5)==0x246a90cc
                    and Native.readPixel(A.layerSession:activeBuffer(),1,5)==0,
                    'Capturar cor modificou uma camada')
                -- Real brush preset/opacity controls and continuous mouse drag.
                A.layerSession:add('Pincel suave teste')
                A.dirty=true;rebuildImage()
                love.draw();love.mousepressed(252,90,1)
                assert(A.tool=='brush' and A.sideTab=='brush',
                    'Toolbar did not select brush panel')
                love.draw();love.mousepressed(panel+183,593,1)
                assert(A.brushStyle=='soft','Soft brush button did not activate')
                love.draw();love.mousepressed(panel+40,637,1)
                assert(math.abs(A.brushOpacity-.9)<.001,
                    'Opacity minus button failed')
                love.draw();love.mousepressed(panel+40,472,1)
                love.draw();love.mousepressed(panel+40,472,1)
                assert(A.brushDiameter==8,'Brush diameter controls failed')
                love.draw();love.mousepressed(panel+99,545,1)
                assert(A.color==0xe53b44ff,'Soft brush color swatch failed')
                local sx,sy=point(3,3)
                local tx,ty=point(4,3)
                local historyBeforeBrush=A.layerSession:historyStats().undo
                love.draw();love.mousepressed(sx,sy,1)
                love.mousemoved(tx,ty,tx-sx,ty-sy)
                love.mousereleased(tx,ty,1)
                local brushCenter=Native.readPixel(A.layerSession:activeBuffer(),4,3)
                local brushEdge=Native.readPixel(A.layerSession:activeBuffer(),7,3)
                assert(brushCenter%256>brushEdge%256 and brushEdge%256>0
                    and brushCenter%256<255,
                    'Native soft brush did not produce graded semi-transparent alpha')
                assert(Native.readPixel(A.layerSession:activeBuffer(),8,3)==0,
                    'Soft brush exceeded radius')
                assert(A.layerSession:historyStats().undo==historyBeforeBrush+1,
                    'One brush drag must create one undo entry')
                undoDoc()
                assert(Native.readPixel(A.layerSession:activeBuffer(),4,3)==0,
                    'Soft brush undo did not clear painted pixels')
                redoDoc()
                assert(Native.readPixel(A.layerSession:activeBuffer(),4,3)==brushCenter,
                    'Soft brush redo did not restore alpha')
                saveDoc()
                local painted=A.store:openProject(A.doc.id)
                local brushIndex=(3*A.doc.width+4)*4+1
                assert(painted.layers[3].pixels:byte(brushIndex+3)==brushCenter%256,
                    'RBD2 did not preserve soft brush opacity')
                love.draw();love.mousepressed(panel+72,594,1)
                assert(A.brushStyle=='hard','Hard brush toggle did not work')
                -- Actual stabilization buttons, pointer events and exact release.
                assert(A.stabilization==0,'Stabilizer should default to off')
                for i=1,3 do
                    love.draw();love.mousepressed(panel+226,720,1)
                end
                assert(A.stabilization==3,'Stabilization increment buttons failed')
                A.layerSession:add('Traço filtrado GUI')
                A.dirty=true;rebuildImage()
                local startX,startY=point(1,5)
                local moveX,moveY=point(3,5)
                local endX,endY=point(8,5)
                local undoCount=A.layerSession:historyStats().undo
                love.draw();love.mousepressed(startX,startY,1)
                assert(A.stabilizer and A.stabilizer.level==3,
                    'Mouse press failed to create smoothing state')
                love.mousemoved(moveX,moveY,moveX-startX,moveY-startY)
                assert(A.lastStrokeX<3.5,
                    'Stabilized move must follow behind the raw pointer')
                love.mousereleased(endX,endY,1)
                assert(A.stabilizer==nil and not A.drawing,
                    'Release did not finish the stabilization session')
                local endpoint=Native.readPixel(A.layerSession:activeBuffer(),8,5)
                assert(endpoint%256>0,
                    'Smoothed stroke failed to reach actual release pixel')
                assert(A.layerSession:historyStats().undo==undoCount+1,
                    'Filtered drag must be only one undo step')
                undoDoc()
                assert(Native.readPixel(A.layerSession:activeBuffer(),8,5)==0,
                    'Stabilized stroke undo failed')
                redoDoc()
                assert(Native.readPixel(A.layerSession:activeBuffer(),8,5)==endpoint,
                    'Stabilized stroke redo failed')
                saveDoc()
                local stabilized=A.store:openProject(A.doc.id)
                local finalOffset=(5*A.doc.width+8)*4+1
                assert(stabilized.layers[4].pixels:byte(finalOffset+3)==endpoint%256,
                    'Stabilized endpoint failed RBD2 roundtrip')
                for i=1,3 do
                    love.draw();love.mousepressed(panel+40,720,1)
                end
                assert(A.stabilization==0,'Stabilization decrement buttons failed')
                -- Exercise actual LÖVE touch callbacks with simulated pressure.
                A.layerSession:add('Pressão de toque GUI')
                A.dirty=true;rebuildImage()
                love.draw();love.mousepressed(252,90,1)
                assert(A.tool=='brush' and A.brushStyle=='hard',
                    'Touch test requires the hard C++ brush')
                for i=1,3 do
                    love.draw();love.mousepressed(panel+40,472,1)
                end
                assert(A.brushDiameter==2,'Touch test could not select thin brush')
                love.draw();love.mousepressed(panel+226,637,1)
                assert(math.abs(A.brushOpacity-1)<.001,
                    'Touch test requires 100% base opacity')
                local lowX,lowY=point(1,1)
                local highX,highY=point(7,5)
                local oldCount=A.layerSession:historyStats().undo
                love.draw();love.touchpressed('contact-light',lowX,lowY,0,0,.2)
                assert(A.touchId=='contact-light' and A.drawing,
                    'Touch press did not own brush stroke')
                local lowBeforeSynthetic=Native.readPixel(
                    A.layerSession:activeBuffer(),1,1)
                love.mousepressed(lowX,lowY,1,true)
                love.mousemoved(highX,highY,highX-lowX,highY-lowY,true)
                love.mousereleased(lowX,lowY,1,true)
                assert(Native.readPixel(A.layerSession:activeBuffer(),1,1)==
                    lowBeforeSynthetic,'Synthetic touch mouse event painted twice')
                love.touchpressed('contact-second',highX,highY,0,0,1)
                love.touchreleased('contact-second',highX,highY,0,0,1)
                assert(A.touchId=='contact-light' and
                    Native.readPixel(A.layerSession:activeBuffer(),7,5)==0,
                    'A second touch interrupted the active stroke')
                love.touchreleased('contact-light',lowX,lowY,0,0,.2)
                local lowAlpha=Native.readPixel(
                    A.layerSession:activeBuffer(),1,1)%256
                assert(lowAlpha>0 and lowAlpha<255 and A.touchId==nil,
                    'Low touch pressure did not produce partial alpha')
                assert(A.layerSession:historyStats().undo==oldCount+1,
                    'Synthetic mouse events created duplicate undo entries')
                love.draw();love.touchpressed('contact-strong',highX,highY,0,0,1)
                love.touchreleased('contact-strong',highX,highY,0,0,1)
                local highAlpha=Native.readPixel(
                    A.layerSession:activeBuffer(),7,5)%256
                assert(highAlpha>lowAlpha and highAlpha==255,
                    'Full pressure should produce stronger C++ paint')
                -- Moving pressure: release must reach exact endpoint with
                -- one undo/redo transaction and preserve pixels in RBD2.
                A.layerSession:add('Traço pressão variável GUI')
                A.dirty=true;rebuildImage()
                local sx,sy=point(1,3)
                local mx,my=point(3,3)
                local ex,ey=point(5,3)
                local beforeTouch=A.layerSession:historyStats().undo
                love.draw();love.touchpressed('contact-move',sx,sy,0,0,.2)
                love.touchmoved('contact-move',mx,my,mx-sx,my-sy,.6)
                assert(A.lastPressure==.6,
                    'Pressure from touchmoved was not used')
                love.touchreleased('contact-move',ex,ey,ex-mx,ey-my,1)
                local lastPixel=Native.readPixel(A.layerSession:activeBuffer(),5,3)
                assert(lastPixel%256>0 and not A.drawing and A.touchId==nil,
                    'Pressure stroke failed to complete at release')
                assert(A.layerSession:historyStats().undo==beforeTouch+1,
                    'Moving touch must create one undo entry')
                undoDoc()
                assert(Native.readPixel(A.layerSession:activeBuffer(),5,3)==0,
                    'Touch undo did not remove final pixel')
                redoDoc()
                assert(Native.readPixel(A.layerSession:activeBuffer(),5,3)==lastPixel,
                    'Touch redo did not restore pressure stroke')
                saveDoc()
                local touchSaved=A.store:openProject(A.doc.id)
                local lastOffset=(3*A.doc.width+5)*4+1
                assert(touchSaved.layers[6].pixels:byte(lastOffset+3)==
                    lastPixel%256,'Touch stroke not persisted in RBD2')
                -- Touch must also operate existing toolbar/canvas without
                -- duplicated mouse emulation.
                love.draw()
                love.touchpressed('touch-toolbar',192,90,0,0,1)
                love.mousepressed(192,90,1,true)
                love.touchreleased('touch-toolbar',192,90,0,0,1)
                assert(A.tool=='pixel','Touch could not select existing toolbar')
                -- Simulated WM_POINTER pen packets through the actual GUI
                -- dispatcher. This verifies routing, not physical pen drivers.
                A.layerSession:add('Windows Ink teste')
                A.dirty=true;rebuildImage()
                love.draw();love.mousepressed(252,90,1)
                assert(A.tool=='brush','Pen test failed to choose brush')
                local ax,ay=point(2,1)
                local bx,by=point(5,1)
                local penHistory=A.layerSession:historyStats().undo
                dispatchInkEvent({kind=1,id=87,x=ax,y=ay,pressure=.4,
                    tiltX=12,tiltY=-9,flags=0,mask=13})
                assert(A.inkPenId==87 and A.drawing and A.inkTiltX==12,
                    'Native pen DOWN was not captured')
                love.mousepressed(ax,ay,1,false)
                love.touchpressed('duplicate-pen-touch',ax,ay,0,0,1)
                assert(A.touchId==nil,'Pen stroke accepted synthetic touch')
                dispatchInkEvent({kind=2,id=88,x=bx,y=by,pressure=1,
                    tiltX=0,tiltY=0,flags=0,mask=1})
                assert(A.inkPenId==87,'Foreign pointer modified active pen')
                dispatchInkEvent({kind=2,id=87,x=bx,y=by,pressure=.4,
                    tiltX=10,tiltY=-5,flags=0,mask=13})
                dispatchInkEvent({kind=3,id=87,x=bx,y=by,pressure=.4,
                    tiltX=10,tiltY=-5,flags=0,mask=13})
                assert(A.inkPenId==nil and not A.drawing,
                    'Native pen UP failed to end brush')
                local inkPixel=Native.readPixel(A.layerSession:activeBuffer(),5,1)
                assert(inkPixel%256>0 and inkPixel%256<255,
                    'Native pen pressure not passed into C++ brush')
                assert(A.layerSession:historyStats().undo==penHistory+1,
                    'Native pen stroke must have one undo step')
                undoDoc()
                assert(Native.readPixel(A.layerSession:activeBuffer(),5,1)==0,
                    'Undo did not remove Windows Ink stroke')
                redoDoc()
                assert(Native.readPixel(A.layerSession:activeBuffer(),5,1)==inkPixel,
                    'Redo did not restore Windows Ink stroke')
                saveDoc()
                local penSaved=A.store:openProject(A.doc.id)
                local penAt=(1*A.doc.width+5)*4+1
                assert(penSaved.layers[7].pixels:byte(penAt+3)==inkPixel%256,
                    'Pen-drawn RGBA not persisted in RBD2')
                dispatchInkEvent({kind=1,id=89,x=bx,y=by,pressure=1,
                    tiltX=0,tiltY=0,flags=4,mask=1})
                assert(A.inkPreviousTool=='brush' and A.tool=='erase',
                    'Inverted pen was not switched to eraser')
                dispatchInkEvent({kind=3,id=89,x=bx,y=by,pressure=1,
                    tiltX=0,tiltY=0,flags=4,mask=1})
                assert(A.tool=='brush' and A.inkPenId==nil,
                    'Inverted pen did not restore previous tool')
                assert(Native.readPixel(A.layerSession:activeBuffer(),5,1)==0,
                    'Inverted pen eraser failed to erase')
                -- Independent tilted geometry via actual Windows Ink dispatcher
                -- and the live enable/disable button. Prior tools remain.
                A.layerSession:add('Inclinação ativa')
                A.dirty=true;rebuildImage()
                love.draw()
                assert(A.penTiltEnabled and A.tool=='brush',
                    'Tilt must be enabled for real pen by default')
                for i=1,2 do
                    love.draw();love.mousepressed(panel+226,472,1)
                end
                assert(A.brushDiameter==6,'Tilt test must use 6-pixel base width')
                local tiltX,tiltY=point(3,3)
                local historyTilt=A.layerSession:historyStats().undo
                dispatchInkEvent({kind=1,id=93,x=tiltX,y=tiltY,pressure=1,
                    tiltX=90,tiltY=0,flags=0,mask=5})
                dispatchInkEvent({kind=3,id=93,x=tiltX,y=tiltY,pressure=1,
                    tiltX=90,tiltY=0,flags=0,mask=5})
                assert(Native.readPixel(A.layerSession:activeBuffer(),7,3)==A.color,
                    'Inclinação horizontal não alargou ponta elíptica')
                assert(Native.readPixel(A.layerSession:activeBuffer(),3,6)==0,
                    'Ponta inclinada desenhou fora do eixo estreito')
                assert(A.layerSession:historyStats().undo==historyTilt+1,
                    'Pincel inclinado não criou uma única operação')
                undoDoc()
                assert(Native.readPixel(A.layerSession:activeBuffer(),7,3)==0,
                    'Inclinação: desfazer falhou')
                redoDoc()
                assert(Native.readPixel(A.layerSession:activeBuffer(),7,3)==A.color,
                    'Inclinação: refazer falhou')
                saveDoc()
                local tiltSaved=A.store:openProject(A.doc.id)
                local horizontalOffset=(3*A.doc.width+7)*4+1
                local r,g,b,a=Colors.channels(A.color)
                assert(tiltSaved.layers[8].pixels:sub(horizontalOffset,
                    horizontalOffset+3)==string.char(r,g,b,a),
                    'Inclinação não persistiu no RBD2')
                love.draw();love.mousepressed(panel+120,428,1)
                assert(not A.penTiltEnabled,'Botão não desativou inclinação')
                -- Clear this CI-only eighth layer; the max is eight layers.
                A.layerSession:clearHistory()
                Native.clear(A.layerSession:activeBuffer(),0)
                A.layerSession:recompose()
                A.dirty=true;rebuildImage()
                dispatchInkEvent({kind=1,id=94,x=tiltX,y=tiltY,pressure=1,
                    tiltX=90,tiltY=0,flags=0,mask=5})
                dispatchInkEvent({kind=3,id=94,x=tiltX,y=tiltY,pressure=1,
                    tiltX=90,tiltY=0,flags=0,mask=5})
                assert(Native.readPixel(A.layerSession:activeBuffer(),7,3)==0,
                    'Desativar tilt não restaurou pincel redondo')
                assert(Native.readPixel(A.layerSession:activeBuffer(),3,3)==A.color,
                    'Pincel redondo desativado não desenhou centro')
                love.draw();love.mousepressed(panel+120,428,1)
                assert(A.penTiltEnabled,'Não foi possível reativar inclinação')
                -- Stage 15: actual UI controls and simulated pointer navigation.
                -- Navigation must be view-only: no pixels, layers or history changed.
                local screenW,screenH=love.graphics.getDimensions()
                local cursorX,cursorY=(screenW-280)/2,(screenH+56)/2
                local viewBeforeX,viewBeforeY=canvasPoint(cursorX,cursorY)
                local beforePixels=Native.bytes(A.layerSession:activeBuffer())
                local beforeHistory=A.layerSession:historyStats().undo
                local firstZoom=A.zoom
                love.draw();love.mousepressed(39,screenH-100,1)
                local reducedZoom=A.zoom
                assert(reducedZoom<firstZoom,'Botão − de zoom não funcionou')
                love.draw();love.mousepressed(78,screenH-100,1)
                assert(A.zoom>reducedZoom,'Botão + de zoom não funcionou')
                local anchoredX,anchoredY=canvasPoint(cursorX,cursorY)
                assert(math.abs(anchoredX-viewBeforeX)<1e-5 and
                    math.abs(anchoredY-viewBeforeY)<1e-5,
                    'Zoom via botão deslocou a âncora do canvas')
                love.draw();love.mousepressed(122,screenH-100,1)
                assert(A.rotation<0,'Botão de rotação não funcionou')
                anchoredX,anchoredY=canvasPoint(cursorX,cursorY)
                assert(math.abs(anchoredX-viewBeforeX)<1e-5 and
                    math.abs(anchoredY-viewBeforeY)<1e-5,
                    'Rotação pelo painel deslocou a âncora')
                love.draw();love.mousepressed(201,screenH-100,1)
                assert(A.rotation==0,'Botão 0° não resetou rotação')
                love.draw();love.mousepressed(278,screenH-100,1)
                assert(A.panX==0 and A.panY==0 and A.rotation==0,
                    'Botão Encaixar não recentralizou')
                local fitZoom=A.zoom
                love.keypressed('-')
                assert(A.zoom<fitZoom,'Atalho de reduzir zoom não funcionou')
                love.keypressed('=')
                assert(math.abs(A.zoom-fitZoom)<1e-7,
                    'Atalho de aumentar zoom não recuperou escala')
                love.keypressed('q')
                assert(A.rotation<0,'Atalho Q não girou canvas')
                love.keypressed('e')
                assert(math.abs(A.rotation)<1e-7,'Atalho E não reverteu rotação')
                love.keypressed('0')
                assert(A.panX==0 and A.panY==0 and A.rotation==0,
                    'Atalho 0 não executou ajuste')
                local panX,panY=cursorX,cursorY
                love.keypressed('space')
                love.mousepressed(panX,panY,1,false)
                assert(A.panning and A.panButton==1 and not A.drawing,
                    'Espaço+arraste não entrou no modo mover tela')
                local originalPanX,originalPanY=A.panX,A.panY
                love.mousemoved(panX+43,panY-17,43,-17,false)
                assert(A.panX==originalPanX+43 and A.panY==originalPanY-17,
                    'Arraste em modo Espaço não deslocou a visualização')
                love.mousereleased(panX+43,panY-17,1,false)
                love.keyreleased('space')
                assert(not A.panning and not A.spaceHeld,
                    'Soltura do mouse/Espaço não encerrou navegação')
                love.mousepressed(panX,panY,2,false)
                assert(A.panning and A.panButton==2,
                    'Botão do meio não ativou navegação')
                love.mousemoved(panX-10,panY+12,-10,12,false)
                love.mousereleased(panX-10,panY+12,2,false)
                assert(not A.panning and A.panButton==nil,
                    'Botão do meio não encerrou navegação')
                love.mousepressed(panX,panY,3,false)
                assert(A.panning and A.panButton==3,
                    'Botão direito não ativou navegação')
                love.mousereleased(panX,panY,3,false)
                assert(not A.panning,'Botão direito não encerrou navegação')
                local wheelZoom=A.zoom
                love.wheelmoved(0,-1)
                assert(A.zoom<wheelZoom,
                    'Roda do mouse não reduziu zoom da tela')
                local wheelReduced=A.zoom
                love.wheelmoved(0,1)
                assert(A.zoom>wheelReduced,
                    'Roda do mouse não aumentou zoom da tela')
                assert(Native.bytes(A.layerSession:activeBuffer())==beforePixels,
                    'Navegação modificou pixels da camada ativa')
                assert(A.layerSession:historyStats().undo==beforeHistory,
                    'Navegação gerou indevidamente uma operação de desenho')
                assert(not A.layerSession.pending and not A.drawing,
                    'Navegação deixou transação de pincel aberta')
                love.keypressed('f')
                -- Stage 16: use real shortcut callbacks and the actual
                -- interactive help overlay, without modifying any pixels.
                local toolsBefore=Native.bytes(A.layerSession:activeBuffer())
                local historyBefore=A.layerSession:historyStats().undo
                local toolIds={'inspect','pixel','brush','erase','fill',
                               'select','shape','picker'}
                for i,id in ipairs(toolIds) do
                    love.keypressed(tostring(i))
                    assert(A.tool==id,
                        'Atalho de ferramenta '..i..' não selecionou '..id)
                end
                love.keypressed('3')
                assert(A.tool=='brush' and A.sideTab=='brush',
                    'Atalho Pincel não abriu as configurações')
                local helpPanel=love.graphics.getWidth()-268
                love.draw()
                love.mousepressed(helpPanel+206,96,1,false)
                assert(A.toolHelp,'Botão de ajuda não abriu a paleta')
                love.draw()
                local helpZoom=A.zoom
                love.mousepressed(80,200,1,false)
                love.mousemoved(120,220,40,20,false)
                love.mousereleased(120,220,1,false)
                love.wheelmoved(0,2)
                assert(A.toolHelp and A.tool=='brush' and A.zoom==helpZoom,
                    'Paleta não bloqueou entradas no canvas/zoom')
                love.keypressed('6')
                assert(not A.toolHelp and A.tool=='select',
                    'Atalho dentro da ajuda não selecionou ferramenta')
                love.keypressed('f1')
                assert(A.toolHelp,'F1 não reabriu ajuda')
                love.draw()
                local helpWidth=math.min(640,screenW-80)
                local helpHeight=math.min(544,screenH-72)
                local helpX=(screenW-helpWidth)/2
                local helpY=(screenH-helpHeight)/2
                love.mousepressed(helpX+60,helpY+94+65+17,1,false)
                assert(not A.toolHelp and A.tool=='brush',
                    'Clique no Pincel da paleta não selecionou ferramenta')
                love.keypressed('h')
                assert(A.toolHelp,'H não abriu ajuda')
                love.keypressed('escape')
                assert(not A.toolHelp and A.screen=='editor',
                    'Esc não fechou ajuda mantendo o editor aberto')
                love.keypressed('f1')
                love.draw()
                love.mousepressed(helpX+helpWidth-95,
                    helpY+helpHeight-33,1,false)
                assert(not A.toolHelp,'Botão Fechar ajuda não funcionou')
                assert(Native.bytes(A.layerSession:activeBuffer())==toolsBefore,
                    'Atalhos ou paleta alteraram pixels da obra')
                assert(A.layerSession:historyStats().undo==historyBefore and
                    not A.layerSession.pending and not A.drawing,
                    'Paleta criou entradas no histórico de desenho')
                -- Stage 17: thumbnail previews and page buttons in the
                -- actual LÖVE layer panel, preserving original raster/undo.
                love.draw();love.mousepressed(panel+70,382,1,false)
                assert(A.sideTab=='layers','Camadas não abriu o painel')
                local layerCount=#A.doc.layers
                assert(layerCount==Store.MAX_LAYERS,
                    'Teste de paginação requer oito camadas')
                local currentLayer=A.doc.active_layer
                local layerId=A.doc.layers[currentLayer].id
                love.draw()
                local cacheImage=layerThumb(currentLayer)
                assert(cacheImage==layerThumb(currentLayer),
                    'Miniatura idêntica não reutilizou cache')
                local originalRaster=Native.bytes(A.layerSession:activeBuffer())
                local originalEntries=A.layerSession:historyStats().undo
                local thumbnailBytes=Thumbnails.sample(
                    A.layerSession:activeBuffer())
                assert(#thumbnailBytes==Thumbnails.SIZE^2*4,
                    'Miniatura real não possui bytes RGBA completos')
                assert(Native.bytes(A.layerSession:activeBuffer())==originalRaster,
                    'Amostragem de miniatura escreveu no raster')
                A.layerSession:beginEdit()
                A.layerSession:pixel(8,6,0x73aa45ff)
                assert(A.layerSession:finishEdit(),
                    'Teste de edição da miniatura não criou histórico')
                A.dirty=true;rebuildImage()
                assert(A.layerThumbDirty[layerId],
                    'Editar o raster não invalidou sua miniatura')
                local newerImage=layerThumb(currentLayer)
                assert(newerImage~=cacheImage and not A.layerThumbDirty[layerId],
                    'Miniatura não foi atualizada depois do desenho')
                assert(newerImage==layerThumb(currentLayer),
                    'Miniatura reconstruída não foi armazenada no cache')
                undoDoc()
                assert(Native.bytes(A.layerSession:activeBuffer())==originalRaster
                    and A.layerSession:historyStats().undo==originalEntries,
                    'Desfazer não recuperou o raster após atualização da prévia')
                local previewAfterUndo=layerThumb(currentLayer)
                assert(previewAfterUndo~=newerImage,
                    'Desfazer não invalidou a prévia')
                local panelStart,panelStop=Thumbnails.window(layerCount,
                    A.doc.active_layer,Thumbnails.rows(screenH),A.layerScroll)
                assert(panelStart==4 and panelStop==8,
                    'Lista não exibiu a camada ativa superior')
                love.draw();love.mousepressed(panel+230,411,1,false)
                assert(A.layerScroll==3,
                    'Seta ▼ não percorreu a lista de camadas')
                love.draw()
                assert(A.layerThumbs[A.doc.layers[3].id]~=nil,
                    'Nova camada visível não recebeu miniatura')
                love.mousepressed(panel+189,411,1,false)
                assert(A.layerScroll==4,
                    'Seta ▲ não retornou à camada superior')
                love.draw();love.mousepressed(panel+110,528,1,false)
                assert(A.doc.active_layer==7,
                    'Linha com miniatura não permitiu selecionar camada')
                local selectedBytes=Native.bytes(A.layerSession:activeBuffer())
                local historySelected=A.layerSession:historyStats().undo
                assert(selectedBytes==Native.bytes(A.layerSession:activeBuffer())
                    and historySelected==A.layerSession:historyStats().undo,
                    'Selecionar linha alterou pixels ou histórico')
                -- Stage 18: rename the current layer by keyboard and
                -- toggle a DIFFERENT layer's visibility directly in its row.
                local selectedId=A.doc.layers[7].id
                local beforeName=A.doc.layers[7].name
                local renamePixelBytes=Native.bytes(A.layerSession.buffers[7])
                local historyBeforeRename=A.layerSession:historyStats().undo
                local previewBeforeRename=layerThumb(7)
                love.keypressed('f2')
                assert(A.modal and A.modal.kind=='renameLayer' and
                    A.modal.layerId==selectedId and A.modal.values[1]==beforeName,
                    'F2 não abriu renomeio na camada atual')
                A.modal.values[1]='  '
                love.keypressed('return')
                assert(A.modal and A.doc.layers[7].name==beforeName,
                    'Renomeio inválido não foi rejeitado')
                A.modal.values[1]=''
                love.textinput('Arte azul Étapa 18')
                love.keypressed('return')
                assert(not A.modal and A.doc.layers[7].name=='Arte azul Étapa 18',
                    'Renomeio pela interface não salvou nome UTF-8')
                assert(Native.bytes(A.layerSession.buffers[7])==renamePixelBytes
                    and A.layerSession:historyStats().undo==historyBeforeRename,
                    'Renomear camada mudou pixels ou histórico')
                assert(layerThumb(7)==previewBeforeRename,
                    'Renomeio recriou miniatura desnecessariamente')
                local renameSaved=A.store:openProject(A.doc.id)
                assert(renameSaved.layers[7].name=='Arte azul Étapa 18' and
                    renameSaved.layers[7].id==selectedId,
                    'Nome de camada não persistiu no RBD2')
                love.draw();love.mousepressed(panel+120,411,1,false)
                assert(A.modal and A.modal.kind=='renameLayer',
                    'Botão Nome não abriu editor de camada')
                love.keypressed('escape')
                assert(not A.modal and A.doc.layers[7].name=='Arte azul Étapa 18',
                    'Cancelar renomeio não preservou nome anterior')
                local otherIndex=8
                local otherVisible=A.doc.layers[otherIndex].visible
                local selectedIndex=A.doc.active_layer
                local otherId=A.doc.layers[otherIndex].id
                local otherPixels=Native.bytes(A.layerSession.buffers[otherIndex])
                local thumbBeforeVisibility=layerThumb(otherIndex)
                love.draw();love.mousepressed(panel+228,492,1,false)
                assert(A.doc.layers[otherIndex].visible~=otherVisible and
                    A.doc.active_layer==selectedIndex,
                    'Botão de visibilidade por linha trocou camada selecionada')
                assert(Native.bytes(A.layerSession.buffers[otherIndex])==otherPixels,
                    'Alternar visibilidade modificou pixels da camada')
                assert(layerThumb(otherIndex)==thumbBeforeVisibility,
                    'Alternar visibilidade recriou prévia sem alterar pixels')
                love.draw();love.mousepressed(panel+228,492,1,false)
                assert(A.doc.layers[otherIndex].visible==otherVisible,
                    'Botão por linha não restaurou a visibilidade')
                saveDoc()
                local metadataSaved=A.store:openProject(A.doc.id)
                assert(metadataSaved.layers[otherIndex].id==otherId and
                    metadataSaved.layers[otherIndex].visible==otherVisible and
                    metadataSaved.layers[7].name=='Arte azul Étapa 18',
                    'Propriedades das camadas não persistiram')
                A.testReport.ui={layer_add_button=true,layer_delete_button=true,
                    eraser_toolbar=true,undo_button=true,redo_button=true,
                    rectangle_select=true,rectangle_drag=true,selection_undo_redo=true,
                    rotation_button=true,nearest_scale_button=true,transform_undo_redo=true,
                    bucket_toolbar=true,bucket_tolerance_buttons=true,bucket_undo_redo=true,
                    bucket_rbd2_roundtrip=true,shape_toolbar=true,
                    shape_drag_preview=true,rectangle_outline=true,ellipse_fill=true,
                    shapes_undo_redo=true,shapes_rbd2_roundtrip=true,
                    hex_rgba_modal=true,hex_validation=true,
                    straight_line_drag=true,straight_line_undo_redo=true,
                    line_rbd2_roundtrip=true,eyedropper_visible=true,
                    eyedropper_active=true,eyedropper_no_paint=true,
                    soft_brush_toggle=true,brush_opacity_control=true,
                    feather_drag_alpha=true,brush_undo_redo=true,
                    soft_brush_rbd2_roundtrip=true,
                    stabilization_buttons=true,filtered_mouse_drag=true,
                    stabilized_exact_endpoint=true,stabilized_undo_redo=true,
                    stabilized_rbd2_roundtrip=true,
                    touch_pressure_low_high=true,touch_synthetic_suppression=true,
                    touch_single_owner=true,touch_pressure_move=true,
                    touch_undo_redo=true,touch_rbd2_roundtrip=true,
                    touch_toolbar=true,winink_pointer_dispatch=true,
                    winink_mouse_touch_guard=true,winink_pressure_undo_rbd2=true,
                    winink_eraser_inversion=true,
                    winink_real_hwnd_attached=true,
                    tilted_pen_ellipse=true,tilted_pen_toggle=true,
                    tilted_pen_undo_redo=true,tilted_pen_rbd2_roundtrip=true,
                    canvas_zoom_buttons=true,canvas_rotation_buttons=true,
                    canvas_keyboard_shortcuts=true,canvas_pan_space=true,
                    canvas_pan_middle_right=true,canvas_wheel_zoom=true,
                    canvas_navigation_no_raster_edit=true,
                    editor_tool_shortcuts=true,tool_help_sidebar_button=true,
                    tool_help_keyboard=true,tool_help_tool_buttons=true,
                    tool_help_blocks_canvas=true,tool_help_no_raster_edit=true,
                    layer_rgba_thumbnails=true,layer_thumbnail_cache=true,
                    layer_thumbnail_refresh_undo=true,layer_panel_page_buttons=true,
                    layer_preview_click_selection=true,
                    layer_f2_rename_modal=true,layer_rename_validation=true,
                    layer_rename_utf8_rbd2=true,layer_rename_preview_preserved=true,
                    layer_row_visibility_toggle=true,
                    layer_visibility_preserves_selection=true,
                    layer_properties_rbd2_roundtrip=true,
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
    button('← Galeria',20,78,92,34,toGallery)
    button('Ver',116,78,53,34,function()selectTool('inspect')end,A.tool=='inspect')
    button('Pixel',173,78,45,34,function()selectTool('pixel')end,A.tool=='pixel')
    button('Pincel',222,78,57,34,function()selectTool('brush')end,A.tool=='brush')
    button('Apagar',283,78,61,34,function()selectTool('erase')end,A.tool=='erase')
    button('Balde',348,78,53,34,function()selectTool('fill')end,A.tool=='fill')
    button('Seleção',405,78,61,34,function()selectTool('select')end,A.tool=='select')
    button('Formas',470,78,62,34,function()selectTool('shape')end,A.tool=='shape')
    button('Gotas',536,78,79,34,function()selectTool('picker')end,A.tool=='picker')
    button('Ajustar',619,78,67,34,function()finishStroke();fit()end)
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
    if A.shapePreview then
        local p=A.shapePreview
        local left=math.min(p.x0,p.x1)-dw/2
        local top=math.min(p.y0,p.y1)-dh/2
        local width=math.abs(p.x1-p.x0)+1
        local height=math.abs(p.y1-p.y0)+1
        local value=A.color
        local red=math.floor(value/16777216)%256/255
        local green=math.floor(value/65536)%256/255
        local blue=math.floor(value/256)%256/255
        love.graphics.setColor(red,green,blue,A.shapeFilled and .65 or .95)
        love.graphics.setLineWidth(math.max(1/A.zoom,A.shapeWidth))
        if A.shapeKind==0 then
            love.graphics.rectangle(A.shapeFilled and 'fill' or 'line',
                left,top,width,height)
        elseif A.shapeKind==1 then
            love.graphics.ellipse(A.shapeFilled and 'fill' or 'line',
                left+width/2,top+height/2,width/2,height/2,48)
        else
            love.graphics.line(p.x0+.5-dw/2,p.y0+.5-dh/2,
                p.x1+.5-dw/2,p.y1+.5-dh/2)
        end
    end
    if A.selection then
        local selected=A.movePreview or A.selection
        love.graphics.setLineWidth(math.max(1/A.zoom,.02))
        love.graphics.setColor(0,0,0,.9)
        love.graphics.rectangle('line',selected.x-dw/2-.5,selected.y-dh/2-.5,selected.w+1,selected.h+1)
        c('accent')
        love.graphics.rectangle('line',selected.x-dw/2,selected.y-dh/2,selected.w,selected.h)
    end
    c('accent');love.graphics.setLineWidth(1/A.zoom);love.graphics.rectangle('line',-dw/2,-dh/2,dw,dh)
    love.graphics.pop();love.graphics.setScissor()
    -- View-only controls remain outside the raster and layer history.
    local dockY=h-116
    button('−',20,dockY,36,30,function()zoomCanvas(1/1.25)end,
        false,A.zoom<=View.MIN_ZOOM)
    button('+',60,dockY,36,30,function()zoomCanvas(1.25)end,
        false,A.zoom>=View.MAX_ZOOM)
    button('↶',102,dockY,36,30,function()rotateCanvas(-math.pi/12)end)
    button('↷',142,dockY,36,30,function()rotateCanvas(math.pi/12)end)
    button('0°',182,dockY,43,30,resetCanvasRotation)
    button('Encaixar',230,dockY,83,30,fit)
    text(('Zoom %.0f%%'):format(A.zoom*100),324,dockY+7,'small','muted')
    box(panel,64,268,h-112,'panel')
    text('PROJETO',panel+20,88,'small','muted')
    button('? Ajuda',panel+172,82,76,31,function()
        finishStroke();A.toolHelp=true
    end)
    text(A.doc.name:sub(1,28),panel+20,115,'title')
    text(dw..' × '..dh..' · RGBA8',panel+20,150,'body','muted')
    text(A.inkAttached and ('Windows Ink · '..(A.inkPenId and 'caneta ativa'
        or 'aguardando caneta')) or 'Caneta Win32: modo alternativo',
        panel+20,171,'small','muted')
    button('Salvar · Ctrl+S',panel+20,186,228,38,saveDoc,A.dirty)
    button('Exportar PNG',panel+20,234,228,38,exportPNG)
    button('Renomear',panel+20,282,107,34,function()modal('rename');A.modal.values[1]=A.doc.name end)
    button('↶',panel+134,282,52,34,undoDoc,false,not A.layerSession:canUndo())
    button('↷',panel+196,282,52,34,redoDoc,false,not A.layerSession:canRedo())
    text('PAINEL',panel+20,343,'small','muted')
    if A.tool=='picker' then
        text('CONTA-GOTAS · RGBA',panel+20,378,'small','muted')
        button('Visível',panel+20,419,108,35,function()
            A.pickerSource='composite' end,A.pickerSource=='composite')
        button('Camada ativa',panel+140,419,108,35,function()
            A.pickerSource='active' end,A.pickerSource=='active')
        text('Clique em qualquer pixel no canvas.',panel+20,477,'small','muted')
        text('A cor é compartilhada com as ferramentas.',panel+20,506,'small','muted')
        editShapeColorButton(panel,557)
        text('Pixels transparentes também podem',panel+20,615,'small','muted')
        text('ser capturados sem alterar o desenho.',panel+20,639,'small','muted')
    elseif A.tool=='shape' then
        text('FORMAS · RASTER C++',panel+20,377,'small','muted')
        button('Retângulo',panel+20,410,108,32,
            function()A.shapeKind=0 end,A.shapeKind==0)
        button('Elipse',panel+140,410,108,32,
            function()A.shapeKind=1 end,A.shapeKind==1)
        button('Contorno',panel+20,452,108,32,
            function()A.shapeFilled=false end,not A.shapeFilled)
        button('Preenchida',panel+140,452,108,32,
            function()A.shapeFilled=true end,A.shapeFilled)
        button('−',panel+20,495,42,30,function()
            A.shapeWidth=math.max(1,A.shapeWidth-1)end,
            false,A.shapeWidth==1 or A.shapeFilled)
        text(('Espessura %dpx'):format(A.shapeWidth),panel+70,503,'small','muted')
        button('+',panel+206,495,42,30,function()
            A.shapeWidth=math.min(128,A.shapeWidth+1)end,
            false,A.shapeWidth==128 or A.shapeFilled)
        text('COR',panel+20,535,'small','muted')
        for i,swatch in ipairs(swatches) do
            local x=panel+20+(i-1)*36
            local rgba=swatch.rgba
            love.graphics.setColor(math.floor(rgba/16777216)%256/255,
                math.floor(rgba/65536)%256/255,
                math.floor(rgba/256)%256/255,1)
            love.graphics.rectangle('fill',x,551,29,27,4,4)
            if A.color==rgba then
                c('accent')
                love.graphics.setLineWidth(2)
                love.graphics.rectangle('line',x-2,549,33,31,4,4)
            end
            A.buttons[#A.buttons+1]={x=x,y=549,w=33,h=31,
                fn=function()A.color=swatch.rgba;status('Cor: '..swatch.name)end}
        end
        button('Linha reta',panel+20,594,108,30,
            function()A.shapeKind=2 end,A.shapeKind==2)
        editShapeColorButton(panel,639)
    elseif A.tool=='select' then
        text('TRANSFORMAR SELEÇÃO',panel+20,377,'small','muted')
        local rect=A.selection
        text(rect and ('Região: '..rect.w..' × '..rect.h..' px')
            or 'Arraste na tela para selecionar',panel+20,416,'small')
        button('↶ 90°',panel+20,451,108,37,function()
            applySelectionTransform(3,1)
        end,false,not rect or rect.h>A.doc.width or rect.w>A.doc.height)
        button('90° ↷',panel+140,451,108,37,function()
            applySelectionTransform(1,1)
        end,false,not rect or rect.h>A.doc.width or rect.w>A.doc.height)
        button('− 50%',panel+20,500,108,37,function()
            applySelectionTransform(0,.5)
        end,false,not rect)
        button('+ 200%',panel+140,500,108,37,function()
            applySelectionTransform(0,2)
        end,false,not rect or rect.w*2>A.doc.width or rect.h*2>A.doc.height)
        text('Cada transformação pode ser desfeita.',panel+20,564,'small','muted')
        text('Rotação: 90° · escala: vizinho próximo',panel+20,592,'small','muted')
        text('Ctrl+D remove o contorno',panel+20,630,'small','muted')
        text('Somente a camada ativa é alterada.',panel+20,666,'small','muted')
    else
    button('Camadas',panel+20,366,107,32,function()A.sideTab='layers'end,A.sideTab=='layers')
    button('Pincel',panel+139,366,109,32,function()A.sideTab='brush'end,A.sideTab=='brush')
    if A.sideTab=='layers' then
        local ls=A.layerSession
        local count=#A.doc.layers
        text(('RASTERS %d/%d'):format(count,Store.MAX_LAYERS),
            panel+20,407,'small','muted')
        button('Nome',panel+87,398,78,27,openLayerRename)
        local rows=Thumbnails.rows(h)
        local start,stop,maxStart=Thumbnails.window(count,
            A.doc.active_layer,rows,A.layerScroll)
        button('▲',panel+172,398,35,27,function()
            A.layerScroll=Thumbnails.scroll(start,maxStart,1)
        end,false,start>=maxStart)
        button('▼',panel+213,398,35,27,function()
            A.layerScroll=Thumbnails.scroll(start,maxStart,-1)
        end,false,start<=1)
        button('+ Camada',panel+20,431,72,34,function()
            finishStroke()
            ls:add()
            A.layerScroll=nil
            A.dirty=true;rebuildImage()
            status('Camada raster adicionada')
        end,false,count>=Store.MAX_LAYERS)
        button('Duplicar',panel+96,431,75,34,duplicateActiveLayer,
            false,count>=Store.MAX_LAYERS)
        button('Excluir',panel+175,431,73,34,function()
            finishStroke()
            ls:remove(A.doc.active_layer)
            clearLayerThumbs()
            A.layerScroll=nil
            A.dirty=true;rebuildImage()
            status('Camada removida')
        end,false,count<=1)
        -- Lower pane must stay usable at 960x640: one 33px row.
        local y=475
        for i=stop,start,-1 do
            local layer=A.doc.layers[i]
            local rowY=y
            button(' ',panel+20,rowY,228,33,function()
                if A.doc.active_layer~=i then
                    finishStroke();ls:select(i);A.dirty=true
                end
                A.layerScroll=start
            end,A.doc.active_layer==i)
            box(panel+24,rowY+2,29,29,'line')
            love.graphics.setColor(1,1,1,1)
            love.graphics.draw(layerThumb(i),panel+24.5,rowY+2.5)
            local label=layer.name
            local utf8=require('utf8')
            local cut=utf8.offset(label,12)
            if cut then label=label:sub(1,cut-1)..'…' end
            text(i..' '..label,panel+62,rowY+8,'body',
                A.doc.active_layer==i and 'bg' or 'text')
            button(layer.visible and 'Vis' or 'Oc.',
                panel+210,rowY+4,35,25,function()
                    finishStroke()
                    ls:setVisible(i,not layer.visible)
                    A.dirty=true;rebuildImage()
                    status(layer.visible and 'Camada visível'
                        or 'Camada oculta')
                end,layer.visible)
            y=y+37
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
        if A.tool=='fill' then
            text('BALDE CONTÍGUO · 4 VIZINHOS',panel+20,429,'small','muted')
            button('−',panel+20,456,46,32,function()
                A.fillTolerance=math.max(0,A.fillTolerance-8)end,
                false,A.fillTolerance==0)
            text(('Tol. %d / 255'):format(A.fillTolerance),panel+77,464,'small')
            button('+',panel+182,456,46,32,function()
                A.fillTolerance=math.min(255,A.fillTolerance+8)end,
                false,A.fillTolerance==255)
        else
            if A.tool=='brush' then
                button(A.penTiltEnabled and 'Inclinação Ink: ativa'
                    or 'Inclinação Ink: desligada',
                    panel+20,416,228,28,function()
                        finishStroke()
                        A.penTiltEnabled=not A.penTiltEnabled
                    end,A.penTiltEnabled)
            else
                text('PINCEL PRÓPRIO · NÃO EQUIVALENTE',panel+20,429,'small','muted')
            end
            button('−',panel+20,456,46,32,function()
                A.brushDiameter=math.max(1,A.brushDiameter-2)end)
            text(('Diâmetro %.0f px'):format(A.brushDiameter),panel+77,464,'small')
            button('+',panel+182,456,46,32,function()
                A.brushDiameter=math.min(256,A.brushDiameter+2)end)
        end
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
        if A.tool=='brush' or A.tool=='erase' then
            if A.tool=='brush' then
                button('Rígido',panel+20,579,108,31,function()
                    finishStroke();A.brushStyle='hard'
                end,A.brushStyle=='hard')
                button('Suave',panel+140,579,108,31,function()
                    finishStroke();A.brushStyle='soft'
                end,A.brushStyle=='soft')
            else
                text('BORRACHA REDONDA · ALFA',panel+20,586,'small','muted')
            end
            button('−',panel+20,622,42,30,function()
                finishStroke()
                A.brushOpacity=math.max(.1,
                    math.floor(A.brushOpacity*10+0.5)/10-.1)
            end,false,A.brushOpacity<=.101)
            text(('Opacidade %.0f%%'):format(A.brushOpacity*100+0.01),
                panel+69,630,'small','muted')
            button('+',panel+206,622,42,30,function()
                finishStroke()
                A.brushOpacity=math.min(1,
                    math.floor(A.brushOpacity*10+0.5)/10+.1)
            end,false,A.brushOpacity>=.999)
        else
            text('ENTRADA',panel+20,589,'small','muted')
            text('Mouse · pressão 1 · ângulos 0',panel+20,616,'small','muted')
            if A.lastPacket then
                local f=A.lastPacket.floats
                text(('x %.1f  y %.1f · p %.3f'):format(f[1],f[2],f[5]),
                    panel+20,646,'small','muted')
            end
        end
        editShapeColorButton(panel,669)
        if A.tool=='brush' or A.tool=='erase' then
            button('−',panel+20,705,42,29,function()
                finishStroke()
                A.stabilization=math.max(0,A.stabilization-1)
            end,false,A.stabilization==0)
            text(('Estabilizar %d / 5'):format(A.stabilization),
                panel+68,713,'small','muted')
            button('+',panel+206,705,42,29,function()
                finishStroke()
                A.stabilization=math.min(5,A.stabilization+1)
            end,false,A.stabilization==5)
        else
            text(A.tool=='fill' and 'Tolerância por canal RGBA · camada ativa'
                or 'Rasterização Android desconhecida',panel+20,705,'small','muted')
        end
    end
    end
    text(('Zoom %.0f%% · ângulo %.0f° · Espaço + arrastar: mover · Ctrl +/−: zoom · Q/E: girar'):format(
        A.zoom*100,math.deg(A.rotation)),22,h-72,'small','muted')
    if A.tool=='select' then
        text(A.selection and 'Arraste dentro da borda para mover · Ctrl+D desmarca'
            or 'Arraste na tela para selecionar uma área retangular',22,h-94,'small','accent')
    elseif A.tool=='shape' then
        text('Arraste para desenhar uma forma ou uma linha reta',22,h-94,'small','accent')
    elseif A.tool=='picker' then
        text('Clique para capturar a cor da tela ou da camada ativa',22,h-94,'small','accent')
    end
end
local function drawModal(w,h)
    love.graphics.setColor(0,0,0,.70);love.graphics.rectangle('fill',0,0,w,h)
    local x,y=w/2-220,h/2-210;box(x,y,440,420,'panel')
    local m=A.modal;local title=m.kind=='new' and 'Criar tela' or m.kind=='folder' and 'Criar pasta' or
        m.kind=='color' and 'Editar cor RGBA' or
        m.kind=='renameLayer' and 'Renomear camada' or 'Renomear projeto'
    text(title,x+24,y+24,'title')
    local names=m.kind=='new' and {'Nome','Largura','Altura'} or
        m.kind=='color' and {'Hexadecimal (#RRGGBB ou #RRGGBBAA)'} or {'Nome'}
    for i,label in ipairs(names) do
        local fy=y+86+(i-1)*72;text(label,x+24,fy,'small','muted')
        box(x+24,fy+20,392,38,'card');if m.focus==i then c('accent');love.graphics.rectangle('line',x+24,fy+20,392,38,5,5)end
        text(m.values[i]..(m.focus==i and '|' or ''),x+36,fy+30,'body')
        A.buttons[#A.buttons+1]={x=x+24,y=fy+20,w=392,h=38,fn=function()m.focus=i end}
    end
    if m.kind=='new' then text('Fundo transparente · limite inicial 2048 × 2048',x+24,y+314,'small','muted')end
    if m.kind=='color' then
        text('6 dígitos: alfa FF. 8 dígitos: alfa personalizado.',x+24,y+314,'small','muted')
    elseif m.kind=='renameLayer' then
        text('Nome UTF-8 · até 240 bytes · os pixels permanecem iguais.',
            x+24,y+314,'small','muted')
    end
    button('Cancelar',x+24,y+357,150,38,function()A.modal=nil;love.keyboard.setTextInput(false)end)
    button('Criar / confirmar',x+190,y+357,226,38,submitModal,true)
end
-- Non-editable tool hub. Its own button hit-map replaces all canvas controls.
local function drawToolHelp(w,h)
    love.graphics.setColor(0,0,0,.78)
    love.graphics.rectangle('fill',0,0,w,h)
    local width=math.min(640,w-80)
    local height=math.min(544,h-72)
    local x=(w-width)/2
    local y=(h-height)/2
    box(x,y,width,height,'panel')
    c('accent');love.graphics.rectangle('fill',x,y,5,height)
    text('Ferramentas e atalhos',x+22,y+20,'title')
    text('Escolha uma ferramenta ou pressione 1 a 8.',
        x+22,y+59,'small','muted')
    local cellWidth=(width-60)/2
    for i,item in ipairs(EditorTools.items) do
        local column=(i-1)%2
        local line=math.floor((i-1)/2)
        local left=x+20+column*(cellWidth+20)
        local top=y+94+line*65
        button(item.key..'  '..item.label,left,top,cellWidth,34,
            function()
                if selectTool(item.id) then A.toolHelp=false end
            end,A.tool==item.id)
        text(item.hint,left+8,top+39,'small','muted')
    end
    text('NAVEGAÇÃO',x+22,y+377,'small','accent')
    text('Espaço + arrastar · mover tela     Roda · zoom     Shift + roda · girar',
        x+22,y+399,'small','muted')
    text('Q / E · rotação     + / − · zoom     0 / F · encaixar     Ctrl+Z / Y · histórico',
        x+22,y+423,'small','muted')
    text('F1 ou H: abrir/fechar · Esc: fechar · Nenhum pixel é alterado.',
        x+22,y+447,'small','muted')
    button('Fechar ajuda',x+width-174,y+height-49,150,33,
        function()A.toolHelp=false end)
end
function love.draw()
    A.buttons={};local w,h=love.graphics.getDimensions();c('bg');love.graphics.clear(palette.bg)
    box(0,0,w,64,'panel');text('DESKTOP REBUILD',24,17,'title')
    text('ibisPaint Android 14.1.2 · reconstrução progressiva',285,24,'body','muted')
    text(Native.available and 'Lua ↔ C++ · offline' or 'Lua · C++ indisponível',w-222,24,'small',Native.available and 'accent' or 'warn')
    if A.screen=='gallery' then drawGallery(w,h)else drawEditor(w,h)end
    box(0,h-48,w,48,'panel');text(A.message or '',20,h-33,'small','muted')
    if A.testReport then text(A.testReport.ok and 'TESTES LUA OK' or 'FALHA NOS TESTES',w-220,h-32,'small',A.testReport.ok and 'accent' or 'warn')end
    if A.modal then A.buttons={};drawModal(w,h)
    elseif A.toolHelp and A.screen=='editor' then
        A.buttons={}
        drawToolHelp(w,h)
    end
end
local function pointerPressed(x,y,buttonNumber,pressure)
    pressure=Pressure.normalize(pressure)
    if A.toolHelp then
        if buttonNumber==1 then
            for i=#A.buttons,1,-1 do
                local b=A.buttons[i]
                if x>=b.x and x<=b.x+b.w and y>=b.y and y<=b.y+b.h then
                    b.fn();return
                end
            end
        end
        return
    end
    -- Middle/right mouse or Space+left pan the view without opening any
    -- painting, shape, selection or undo transaction.
    if A.screen=='editor' and not A.modal and
        (buttonNumber==2 or buttonNumber==3 or
        (buttonNumber==1 and A.spaceHeld)) then
        if x>=16 and x<love.graphics.getWidth()-268 and
            y>=125 and y<love.graphics.getHeight()-78 then
            finishStroke()
            A.panning=true;A.panButton=buttonNumber
            return
        end
    end
    if buttonNumber==1 then
        for i=#A.buttons,1,-1 do local b=A.buttons[i];if x>=b.x and x<=b.x+b.w and y>=b.y and y<=b.y+b.h then A.shapePreview=nil;b.fn();return end end
        if A.screen=='editor' and not A.modal and x<love.graphics.getWidth()-280 and y>125 and y<love.graphics.getHeight()-78 then
            guard(function()
                local px,py=canvasPoint(x,y)
                A.lastPacket=Native.pack({{id=1,info=0,x=px,y=py,pressure=pressure,time=math.floor(love.timer.getTime()*1000)}})
                if A.tool=='picker' then
                    pickColor(px,py)
                elseif A.tool=='shape' and px>=0 and py>=0 and
                    px<A.doc.width and py<A.doc.height then
                    local ix=clampPixel(px,A.doc.width)
                    local iy=clampPixel(py,A.doc.height)
                    A.shapePreview={x0=ix,y0=iy,x1=ix,y1=iy}
                    status('Arraste para delimitar a forma e solte para desenhar')
                elseif A.tool=='select' then
                    local ix=clampPixel(px,A.doc.width)
                    local iy=clampPixel(py,A.doc.height)
                    local rect=A.selection
                    if rect and ix>=rect.x and ix<rect.x+rect.w and
                        iy>=rect.y and iy<rect.y+rect.h then
                        A.selectAction='move'
                        A.moveOriginX=ix;A.moveOriginY=iy
                        A.movePreview={x=rect.x,y=rect.y,w=rect.w,h=rect.h}
                        status('Arraste a seleção para mover os pixels da camada')
                    else
                        A.selectAction='create'
                        A.selectOriginX=ix;A.selectOriginY=iy
                        A.selection={x=ix,y=iy,w=1,h=1}
                        status('Área selecionada · arraste novamente dentro dela para mover')
                    end
                elseif A.tool=='fill' and px>=0 and py>=0 and
                    px<A.doc.width and py<A.doc.height then
                    local changed=A.layerSession:fill(math.floor(px),math.floor(py),
                        A.color,A.fillTolerance)
                    if changed>0 then
                        A.dirty=true;rebuildImage()
                        status(('Balde C++ · %d pixels preenchidos · Ctrl+Z desfaz'):format(changed))
                    else
                        status('Balde: nenhum pixel alterado')
                    end
                elseif A.tool=='pixel' and px>=0 and py>=0 and px<A.doc.width and py<A.doc.height then
                    A.layerSession:beginEdit()
                    A.layerSession:pixel(math.floor(px),math.floor(py),A.color)
                    A.layerSession:finishEdit()
                    A.dirty=true;rebuildImage()
                    status('Pixel gravado pelo C++ · Ctrl+Z para desfazer')
                elseif A.tool=='brush' or A.tool=='erase' then
                    A.layerSession:beginEdit()
                    local diameter=Pressure.diameter(A.brushDiameter,pressure)
                    local opacity=Pressure.opacity(A.brushOpacity,pressure)
                    if A.tool=='erase' then
                        A.layerSession:erase(px,py,px,py,diameter,opacity)
                    elseif A.inkPenId~=nil and A.penTiltEnabled and
                        (A.inkTiltX~=0 or A.inkTiltY~=0) then
                        A.layerSession:tiltStroke(px,py,px,py,diameter,A.color,
                            opacity,A.brushStyle=='soft' and 0.25 or 1,
                            A.inkTiltX,A.inkTiltY)
                    elseif A.brushStyle=='soft' then
                        A.layerSession:softStroke(px,py,px,py,diameter,
                            A.color,opacity,0.25)
                    else
                        A.layerSession:stroke(px,py,px,py,diameter,A.color,opacity)
                    end
                    A.lastPressure=pressure
                    A.drawing=true;A.lastStrokeX=px;A.lastStrokeY=py
                    A.stabilizer=Stabilizer.new(A.stabilization,px,py)
                    A.dirty=true;rebuildImage()
                    status(A.tool=='erase' and 'Borracha C++ · apaga a camada ativa'
                        or 'Pincel C++ · histórico por pincelada · Ctrl+Z')
                end
            end)()
        end
    end
end
local function pointerReleased(x,y,b,pressure)
    if A.toolHelp then return end
    if A.panning and b==A.panButton then
        A.panning=false;A.panButton=nil
        return
    end
    if b==1 then
        guard(finishShape)()
        guard(finishSelection)()
        if A.drawing then
            guard(function()
                local px,py=canvasPoint(x,y)
                px=math.max(-16384,math.min(16384,px))
                py=math.max(-16384,math.min(16384,py))
                finishStroke(px,py,pressure)
            end)()
        else
            guard(finishStroke)()
        end
    end
end
local function pointerMoved(x,y,dx,dy,pressure)
    if A.toolHelp then return end
    if A.panning then
        View.pan(A,dx,dy)
        return
    end
    if A.shapePreview and A.screen=='editor' and A.tool=='shape' then
        local px,py=canvasPoint(x,y)
        A.shapePreview.x1=clampPixel(px,A.doc.width)
        A.shapePreview.y1=clampPixel(py,A.doc.height)
    end
    if A.screen=='editor' and A.tool=='select' and A.selectAction then
        local px,py=canvasPoint(x,y)
        local ix=clampPixel(px,A.doc.width)
        local iy=clampPixel(py,A.doc.height)
        if A.selectAction=='create' then
            A.selection={x=math.min(A.selectOriginX,ix),
                y=math.min(A.selectOriginY,iy),
                w=math.abs(ix-A.selectOriginX)+1,
                h=math.abs(iy-A.selectOriginY)+1}
        elseif A.selectAction=='move' then
            local rect=A.selection
            local dx=ix-A.moveOriginX
            local dy=iy-A.moveOriginY
            A.movePreview={x=math.max(0,math.min(A.doc.width-rect.w,rect.x+dx)),
                y=math.max(0,math.min(A.doc.height-rect.h,rect.y+dy)),
                w=rect.w,h=rect.h}
        end
    end
    if A.drawing and A.screen=='editor' and (A.tool=='brush' or A.tool=='erase') and not A.modal then
        guard(function()
            local px,py=canvasPoint(x,y)
            px=math.max(-16384,math.min(16384,px))
            py=math.max(-16384,math.min(16384,py))
            local sx,sy=A.stabilizer:sample(px,py)
            paintBrushSegment(sx,sy,pressure)
        end)()
    end
end
function love.mousepressed(x,y,buttonNumber,istouch)
    if istouch or A.touchId~=nil or A.inkPenId~=nil or Ink.mouseGuard() then return end
    pointerPressed(x,y,buttonNumber,1)
end
function love.mousereleased(x,y,b,istouch)
    if istouch or A.touchId~=nil or A.inkPenId~=nil or Ink.mouseGuard() then return end
    pointerReleased(x,y,b,1)
end
function love.mousemoved(x,y,dx,dy,istouch)
    if istouch or A.touchId~=nil or A.inkPenId~=nil or Ink.mouseGuard() then return end
    pointerMoved(x,y,dx,dy,1)
end
-- LÖVE 11.5 touch callbacks report pressure but do not distinguish a
-- pen from a finger. Own exactly one contact until its release.
function love.touchpressed(id,x,y,dx,dy,pressure)
    if A.touchId~=nil or A.drawing or A.inkPenId~=nil or Ink.mouseGuard() then return end
    A.touchId=id
    pointerPressed(x,y,1,Pressure.normalize(pressure))
end
function love.touchmoved(id,x,y,dx,dy,pressure)
    if A.touchId~=id or Ink.mouseGuard() then return end
    pointerMoved(x,y,dx,dy,Pressure.normalize(pressure))
end
function love.touchreleased(id,x,y,dx,dy,pressure)
    if A.touchId~=id or Ink.mouseGuard() then return end
    pointerReleased(x,y,1,Pressure.normalize(pressure))
    A.touchId=nil
end
-- Win32 pen events are delivered from the native queue on the LÖVE
-- main thread, not from a LuaJIT callback invoked inside WndProc.
dispatchInkEvent=function(e)
    if e.kind==1 then
        if A.inkPenId~=nil or A.touchId~=nil or A.drawing then return end
        A.inkPenId=e.id
        A.inkTiltX=e.tiltX or 0;A.inkTiltY=e.tiltY or 0
        A.inkPreviousTool=nil
        if e.flags and (e.flags%8>=2) and A.screen=='editor' then
            -- PEN_FLAG_INVERTED (2) or ERASER (4): erase temporarily.
            A.inkPreviousTool=A.tool
            A.tool='erase'
        end
        pointerPressed(e.x,e.y,1,Pressure.normalize(e.pressure))
        status('Windows Ink: caneta '..math.floor(e.pressure*100+.5)..
            '% · inclinação '..A.inkTiltX..'°/'..A.inkTiltY..'°')
    elseif e.id==A.inkPenId then
        if e.kind==2 then
            A.inkTiltX=e.tiltX or 0;A.inkTiltY=e.tiltY or 0
            pointerMoved(e.x,e.y,0,0,Pressure.normalize(e.pressure))
        elseif e.kind==3 or e.kind==4 then
            if e.kind==4 then
                guard(finishStroke)()
                A.shapePreview=nil
                guard(finishSelection)()
            else
                A.inkTiltX=e.tiltX or 0;A.inkTiltY=e.tiltY or 0
                pointerReleased(e.x,e.y,1,Pressure.normalize(e.pressure))
            end
            A.inkPenId=nil
            if A.inkPreviousTool then
                A.tool=A.inkPreviousTool;A.inkPreviousTool=nil
            end
        end
    end
end
function love.focus(focused)
    if not focused then
        A.shapePreview=nil;A.touchId=nil;A.inkPenId=nil
        A.panning=false;A.panButton=nil;A.spaceHeld=false
        A.toolHelp=false
        if A.inkPreviousTool then A.tool=A.inkPreviousTool;A.inkPreviousTool=nil end
        guard(finishSelection)()
        guard(finishStroke)()
    end
end
function love.wheelmoved(x,y)
    if A.toolHelp then return end
    if A.screen=='editor' and not A.modal then
        local mx=love.mouse.getPosition()
        if mx>=love.graphics.getWidth()-268 and A.sideTab=='layers' then
            local count=#A.doc.layers
            local index=math.max(1,math.min(count,A.doc.active_layer+(y>0 and 1 or -1)))
            if y~=0 and index~=A.doc.active_layer then
                finishStroke();A.layerSession:select(index)
                A.layerScroll=nil
                A.dirty=true
            end
            return
        end
        if y==0 then return end
        local w,h=love.graphics.getDimensions()
        local my=select(2,love.mouse.getPosition())
        if mx<16 or mx>=w-268 or my<125 or my>=h-78 then
            mx=(w-280)/2;my=(h+56)/2
        end
        if love.keyboard.isDown('lshift','rshift') then
            rotateCanvas(y*math.pi/36,mx,my)
        else
            zoomCanvas(1.15^y,mx,my)
        end
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
    if A.screen=='editor' and A.toolHelp then
        if key=='escape' or key=='f1' or key=='h' then
            A.toolHelp=false
        elseif EditorTools.fromKey(key) then
            if selectTool(EditorTools.fromKey(key).id) then
                A.toolHelp=false
            end
        end
        return
    end
    if A.screen=='editor' and love.keyboard.isDown('lctrl','rctrl') and key=='j' then
        guard(duplicateActiveLayer)()
        return
    end
    if A.screen=='editor' and key=='f2' then
        openLayerRename()
        return
    end
    if A.screen=='editor' and (key=='f1' or key=='h') then
        finishStroke();A.toolHelp=true
        return
    end
    if A.screen=='editor' and EditorTools.fromKey(key) and
        not love.keyboard.isDown('lctrl','rctrl','lalt','ralt') then
        selectTool(EditorTools.fromKey(key).id)
        return
    end
    if A.screen=='editor' and key=='space' then
        A.spaceHeld=true
        return
    end
    if A.screen=='editor' and key=='escape' and A.shapePreview then
        A.shapePreview=nil;status('Forma cancelada')
    elseif A.screen=='editor' and (key=='escape' or
        (key=='d' and love.keyboard.isDown('lctrl','rctrl'))) and A.selection then
        guard(finishSelection)();A.selection=nil;status('Seleção desmarcada')
    elseif A.screen=='editor' and love.keyboard.isDown('lctrl','rctrl') and key=='z' then
        if love.keyboard.isDown('lshift','rshift') then guard(redoDoc)() else guard(undoDoc)() end
    elseif A.screen=='editor' and love.keyboard.isDown('lctrl','rctrl') and key=='y' then guard(redoDoc)()
    elseif (love.keyboard.isDown('lctrl','rctrl')) and key=='s'then guard(saveDoc)()
    elseif (love.keyboard.isDown('lctrl','rctrl')) and key=='n' then modal('new')
    elseif key=='escape' and A.screen=='editor' then guard(toGallery)()
    elseif A.screen=='editor' and (key=='=' or key=='+' or key=='kp+') then
        zoomCanvas(1.25)
    elseif A.screen=='editor' and (key=='-' or key=='kp-') then
        zoomCanvas(1/1.25)
    elseif A.screen=='editor' and (key=='0' or key=='f') then fit()
    elseif A.screen=='editor' and key=='q' then rotateCanvas(-math.pi/12)
    elseif A.screen=='editor' and key=='e' then rotateCanvas(math.pi/12)
    elseif A.screen=='editor' and key=='r' then resetCanvasRotation() end
end
function love.keyreleased(key)
    if key=='space' then
        A.spaceHeld=false
        if A.panning and A.panButton==1 then
            A.panning=false;A.panButton=nil
        end
    end
end
function love.resize()if A.doc then fit()end end
function love.quit()
    Ink.close()
    clearLayerThumbs()
    if A.store then
        if A.doc and A.dirty then local ok,err=pcall(saveDoc);if not ok then status('Falha ao salvar; fechamento cancelado: '..tostring(err));return true end end
        pcall(function()A.store:setPreferences(A.preferences);A.store:saveBrushes(A.brushes)end)
    end
end
