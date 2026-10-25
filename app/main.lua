local Native=require('native')
local Store=require('store')
local Layers=require('layers')
local FS=require('fs')
local JSON=require('json')
local Colors=require('colors')
local ColorPanel=require('color_window')
local Stabilizer=require('stroke_stabilizer')
local Pressure=require('touch_pressure')
local Ink=require('windows_ink')
local View=require('canvas_view')
local EditorTools=require('editor_tools')
local Thumbnails=require('layer_thumbnails')
local Icons=require('ui_icons')
local GalleryThumb=require('gallery_thumbnails')
local TextFit=require('text_fit')
local Visual=require('visual_hierarchy')
local Menus=require('context_menus')
local Presets=require('brush_presets')
local BrushCard=require('brush_catalogue_card')
local Samples=require('brush_samples')
local Lab=require('brush_lab')
local BrushKeyboard=require('brush_keyboard')
local Sliders=require('brush_sliders')
local Tip=require('brush_cursor')
local Workspace=require('workspace_layout')
local Sidebar=require('sidebar_scroll')
local Compact=require('compact_layout')
local LayerKeys=require('compact_layer_keys')
local Inspector=require('compact_inspector')
local LayerOpacity=require('compact_layer_opacity')
local DesktopOpacity=require('desktop_layer_opacity')
local LayerOpacitySteps=require('layer_opacity_steps')
local LayerOrder=require('layer_order_controls')
local LayerRowVisual=require('layer_row_visual')
local CompactLayerWheel=require('compact_layer_wheel')
local LayerListWheel=require('layer_list_wheel')
local dispatchInkEvent
local showcaseNames={'01-galeria.png','02-editor-compacto.png',
    '03-biblioteca-pinceis.png','04-seletor-cores.png',
    '05-camadas.png','06-editor-desktop.png',
    '07-editor-960x640.png','08-ajustes-pincel.png',
    '09-opacidade-camadas.png'}
local A={screen='gallery',folder='',dirty=false,buttons={},zoom=1,rotation=0,panX=0,panY=0,tool='inspect',color=0x192d40ff,view='grid',brushDiameter=12,brushStyle='hard',brushOpacity=1,penTiltEnabled=true,stabilization=0,stabilizer=nil,touchId=nil,inkPenId=nil,inkPreviousTool=nil,inkTiltX=0,inkTiltY=0,lastPressure=1,fillTolerance=0,shapeKind=0,pickerSource='composite',shapeFilled=false,shapeWidth=2,shapePreview=nil,drawing=false,sideTab='layers',spaceHeld=false,panning=false,panButton=nil,toolHelp=false,contextMenu=nil,brushLibrary=false,selectedBrushCustom=nil,brushFocus=nil,brushSampleCache=nil,brushLabDraft=nil,brushLabEdited=false,brushLabDrag=nil,sliderDrag=nil,previewEnabled=true,tipCache=nil,hoverX=nil,hoverY=nil,mouseOutside=false,focusMode=false,compactUi=false,quickDrag=nil,compactPanel=nil,colorMode='hsb',colorDrag=nil,colorHistory={},savedColors={},previousColor=nil,brushFilter='all',compactLayerStart=nil,compactLayerOpacityDrag=nil,desktopLayerOpacityDrag=nil,layerScroll=nil,layerThumbs=nil,layerThumbDirty=nil,sidebarScroll=0,sidebarDrawing=false}
-- Visual language: neutral studio workspace, clear blue tool state and
-- compact layer controls. All painting remains inside the native canvas.
local palette={bg={.105,.119,.139},panel={.147,.167,.191},card={.194,.218,.247},line={.267,.307,.342},text={.94,.96,.98},muted={.65,.71,.76},accent={.29,.68,.98},selected={.16,.34,.48},canvas={.126,.140,.158},warn={1,.72,.35}}
-- A denser gray and charcoal editing chrome, referencing the official tool
-- and layer screenshots. The desktop palette remains untouched.
local compactPalette={bg={.215,.222,.229},panel={.125,.133,.145},
    card={.210,.220,.231},line={.345,.365,.380},
    text={.95,.96,.97},muted={.70,.73,.76},
    accent={.34,.69,1},selected={.14,.29,.43},
    canvas={.25,.26,.27},warn={1,.72,.35}}
local swatches={
    {name='Grafite',rgba=0x192d40ff},{name='Preto',rgba=0x000000ff},
    {name='Vermelho',rgba=0xe53b44ff},{name='Verde',rgba=0x20ba84ff},
    {name='Azul',rgba=0x347ce9ff},{name='Branco',rgba=0xffffffff}
}
local function c(key,alpha)
    local v=(A.compactUi and compactPalette or palette)[key]
    love.graphics.setColor(v[1],v[2],v[3],alpha or 1)
end
local function text(value,x,y,font,key) c(key or 'text');love.graphics.setFont(A.fonts[font or 'body']);love.graphics.print(value,x,y) end
local function box(x,y,w,h,key)
    c(key)
    love.graphics.rectangle('fill',x,y,w,h,A.compactUi and 4 or 6,
        A.compactUi and 4 or 6)
end
local function status(s) A.message=s;A.messageTime=love.timer.getTime() end
local function guard(fn)
    return function(...) local ok,err=pcall(fn,...);if not ok then status(tostring(err)) end end
end
local function button(label,x,y,w,h,fn,active,disabled)
    local mx,my=love.mouse.getPosition()
    if A.sidebarDrawing then my=my+(A.sidebarScroll or 0) end
    local hover=not disabled and mx>=x and mx<=x+w and my>=y and my<=y+h
    box(x,y,w,h,disabled and 'panel' or active and 'selected'
        or hover and 'line' or 'card')
    c(active and 'accent' or 'line')
    love.graphics.setLineWidth(1)
    love.graphics.rectangle('line',x+.5,y+.5,w-1,h-1,6,6)
    c(disabled and 'muted' or 'text')
    love.graphics.setFont(A.fonts.body)
    local printable=TextFit.truncate(label,Visual.clampTextWidth(w),
        function(value)return A.fonts.body:getWidth(value)end)
    love.graphics.printf(printable,x,y+(h-A.fonts.body:getHeight())/2,
        w,'center')
    if not disabled then
        A.buttons[#A.buttons+1]={x=x,y=y,w=w,h=h,fn=guard(fn)}
    end
end
local function iconButton(id,x,y,w,h,fn,active,disabled)
    button('',x,y,w,h,fn,active,disabled)
    c(disabled and 'muted' or active and 'accent' or 'text')
    Icons.draw(id,x+w/2,y+h/2,17)
end
local function fitted(value,x,y,font,key,maxWidth)
    local face=A.fonts[font or 'body']
    text(TextFit.truncate(value,maxWidth,function(s)
        return face:getWidth(s)
    end),x,y,font,key)
end
-- Same click rectangles as earlier stages; only their rendering changes.
local toolSlots={
    {id='inspect',x=116,w=53},{id='pixel',x=173,w=45},
    {id='brush',x=222,w=57},{id='erase',x=283,w=61},
    {id='fill',x=348,w=53},{id='select',x=405,w=61},
    {id='shape',x=470,w=62},{id='picker',x=536,w=79}
}
local selectTool
local function toolButton(slot)
    local item=assert(EditorTools.fromId(slot.id))
    local x,w=slot.x,slot.w
    local selected=A.tool==item.id
    button('',x,78,w,34,function()selectTool(item.id)end,selected)
    c(selected and 'accent' or 'text')
    Icons.draw(item.id,x+w/2,88,16)
    c(selected and 'text' or 'muted')
    love.graphics.setFont(A.fonts.small)
    love.graphics.printf(Visual.toolLabel(item.id),x,98,w,'center')
    if selected then
        c('accent')
        love.graphics.rectangle('fill',x+8,109,w-16,2,1,1)
    end
end
local function releaseTipCache()
    if A.tipCache and A.tipCache.image then
        A.tipCache.image:release()
    end
    A.tipCache=nil
end
local function releaseBrushSamples()
    if A.brushSampleCache then
        for _,entry in pairs(A.brushSampleCache) do
            if entry.image then entry.image:release() end
        end
    end
    A.brushSampleCache={}
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
local function paneHidden()
    return A.focusMode or A.compactUi
end
local function viewData()
    return {zoom=A.zoom,rotation=A.rotation,panX=A.panX,panY=A.panY,
        width=A.doc.width,height=A.doc.height,
        focusMode=paneHidden(),compactUi=A.compactUi and not A.focusMode}
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
    local v=viewData()
    if not mx or not my then mx,my=View.center(v,w,h) end
    local changed=View.zoomAt(v,w,h,mx,my,factor)
    commitView(v);return changed
end
local function rotateCanvas(delta,mx,my)
    if not A.doc then return false end
    local w,h=love.graphics.getDimensions()
    local v=viewData()
    if not mx or not my then mx,my=View.center(v,w,h) end
    local changed=View.rotateAt(v,w,h,mx,my,delta)
    commitView(v);return changed
end
local function resetCanvasRotation()
    if not A.doc then return false end
    local w,h=love.graphics.getDimensions()
    local v=viewData()
    local centerX,centerY=View.center(v,w,h)
    local changed=View.resetRotation(v,w,h,centerX,centerY)
    commitView(v);return changed
end
local function openDoc(doc)
    assert(Native.available,'O editor requer o motor C++ compilado. A galeria continua disponível.')
    clearLayerThumbs()
    A.layerScroll=nil
    A.layerSession=Layers.open(A.store,doc)
    A.doc=A.layerSession.doc
    A.buffer=A.layerSession.composite
    releaseTipCache()
    releaseBrushSamples()
    A.screen='editor';A.dirty=false;A.focusMode=false;A.contextMenu=nil;A.brushLibrary=false;A.sliderDrag=nil;A.desktopLayerOpacityDrag=nil;A.hoverX=nil;A.hoverY=nil;A.mouseOutside=false;A.sidebarScroll=0
    A.compactUi=not (A.options and (A.options.selfTest or A.options.luaTest))
    A.compactPanel=nil;A.compactLayerStart=nil
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
selectTool=function(id)
    local item=EditorTools.fromId(id)
    assert(item,'Ferramenta inválida')
    -- A tap on a toolbar button owns a touch/pen contact, but is not a
    -- drawing stroke. Reject only mid-stroke device tool changes.
    if A.screen~='editor' or
        (A.drawing and (A.inkPenId~=nil or A.touchId~=nil)) then
        return false
    end
    finishStroke()
    if A.tool~=id then A.shapePreview=nil;A.sidebarScroll=0 end
    A.tool=id
    local tab=EditorTools.panelFor(id)
    if tab then A.sideTab=tab end
    return true
end
-- The canvas gains horizontal workspace while the document/view state is
-- untouched. All editing shortcuts remain active with the pane hidden.
local function toggleFocusMode()
    assert(A.screen=='editor' and A.doc,'Abra uma obra para usar o modo foco')
    finishStroke()
    A.shapePreview=nil
    A.panning=false;A.panButton=nil;A.contextMenu=nil;A.brushLibrary=false;A.sliderDrag=nil;A.quickDrag=nil
    A.compactPanel=nil;A.colorDrag=nil;A.desktopLayerOpacityDrag=nil
    A.focusMode=not A.focusMode
    status(A.focusMode and 'Modo foco · Tab restaura painel' or
        'Painel de ferramentas restaurado')
    return A.focusMode
end
local function toggleCompactUi()
    assert(A.screen=='editor' and A.doc,'Abra uma obra para trocar o layout')
    finishStroke()
    A.shapePreview=nil;A.selectAction=nil;A.movePreview=nil
    A.panning=false;A.panButton=nil;A.sliderDrag=nil;A.quickDrag=nil
    A.contextMenu=nil;A.brushLibrary=false;A.toolHelp=false
    A.compactPanel=nil;A.compactLayerStart=nil;A.colorDrag=nil
    A.desktopLayerOpacityDrag=nil
    A.compactUi=not A.compactUi
    status(A.compactUi and 'Interface compacta · barra inferior ativa' or
        'Interface desktop · painel lateral restaurado')
end
local function toggleCompactPanel(kind)
    assert(A.compactUi and A.screen=='editor','Painel compacto indisponível')
    finishStroke()
    A.shapePreview=nil;A.panning=false;A.panButton=nil
    A.compactPanel=A.compactPanel==kind and nil or kind
end
local function undoDoc()
    A.shapePreview=nil
    finishStroke()
    if A.layerSession then
        local changed,structural,metadata=A.layerSession:undo()
        if changed then
            A.selection=nil;A.selectAction=nil;A.movePreview=nil
            if structural then clearLayerThumbs();A.layerScroll=nil end
            A.dirty=true;rebuildImage()
            status(structural and 'Estrutura desfeita · sessão atual'
                or metadata and 'Propriedade desfeita · sessão atual'
                or 'Pintura desfeita · sessão atual')
        end
    end
end
local function redoDoc()
    A.shapePreview=nil
    finishStroke()
    if A.layerSession then
        local changed,structural,metadata=A.layerSession:redo()
        if changed then
            A.selection=nil;A.selectAction=nil;A.movePreview=nil
            if structural then clearLayerThumbs();A.layerScroll=nil end
            A.dirty=true;rebuildImage()
            status(structural and 'Estrutura refeita · sessão atual'
                or metadata and 'Propriedade refeita · sessão atual'
                or 'Pintura refeita · sessão atual')
        end
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
    A.shapePreview=nil;A.toolHelp=false;A.contextMenu=nil;A.brushLibrary=false;A.sliderDrag=nil;A.quickDrag=nil;A.compactLayerOpacityDrag=nil;A.desktopLayerOpacityDrag=nil;A.compactPanel=nil;A.colorDrag=nil;A.compactPanel=nil
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
local function chooseColor(value)
    Colors.channels(value)
    if A.color~=value then
        A.colorHistory=ColorPanel.history(A.colorHistory or {},A.color)
        A.color=value
    end
    A.colorHistory=ColorPanel.history(A.colorHistory or {},value)
end
local function savePaletteColor()
    local new,added=ColorPanel.saved(A.savedColors,A.color)
    if not added then
        status('Cor já existe na paleta');return false
    end
    local prefs={}
    for key,value in pairs(A.preferences or {}) do prefs[key]=value end
    prefs.colorPalette=JSON.array(new)
    A.store:setPreferences(prefs)
    A.preferences=prefs;A.savedColors=new
    status('Cor salva na paleta local')
    return true
end
local function openCompactColor()
    assert(A.screen=='editor' and A.compactUi and
        not A.focusMode,'Abra o editor compacto')
    finishStroke()
    A.compactPanel='color'
    A.previousColor=A.color
    A.colorMode='hsb'
    A.colorDrag=nil
    A.colorHistory=ColorPanel.history(A.colorHistory or {},A.color)
end
local function updateColorDrag(kind,x,y)
    local w,h=love.graphics.getDimensions()
    local p=Compact.popup(w,h,'color')
    local r,g,b,a=Colors.channels(A.color)
    if kind=='sv' then
        local sat,bright=ColorPanel.svAt(p,x,y)
        local hue=ColorPanel.hsb(A.color)
        A.color=ColorPanel.fromHSB(hue,sat,bright,a)
    elseif kind=='hue' then
        local _,sat,bright=ColorPanel.hsb(A.color)
        A.color=ColorPanel.fromHSB(ColorPanel.hueAt(p,y),sat,bright,a)
    elseif kind=='alpha' then
        A.color=ColorPanel.rgba(r,g,b,
            ColorPanel.hsbAlphaValue(p,x))
    else
        local mode,channel=kind:match('^(%a+)%-(%u)$')
        assert(mode=='rgb' or mode=='hsb','Ajuste inválido')
        local value=ColorPanel.trackValue(p,mode,channel,x)
        if mode=='rgb' then
            A.color=ColorPanel.withRGB(A.color,channel,value)
        else
            A.color=ColorPanel.withHSB(A.color,channel,value)
        end
    end
end
local function modal(kind)
    A.contextMenu=nil;A.compactPanel=nil
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
local function flipActiveLayer(axis)
    assert(A.screen=='editor' and A.layerSession,'Abra uma obra antes de espelhar')
    finishStroke()
    A.layerSession:flip(axis)
    A.selection=nil;A.selectAction=nil;A.movePreview=nil;A.shapePreview=nil
    A.dirty=true;rebuildImage()
    status(axis==0 and 'Camada espelhada na horizontal' or
        'Camada espelhada na vertical')
end
local function clearActiveLayer()
    assert(A.screen=='editor' and A.layerSession,'Abra uma obra antes de limpar')
    finishStroke()
    local changed=A.layerSession:clearActive()
    if changed then
        A.selection=nil;A.selectAction=nil;A.movePreview=nil;A.shapePreview=nil
        A.dirty=true
        rebuildImage()
        status('Pixels da camada apagados · Ctrl+Z restaura')
    else
        status('Camada já está transparente')
    end
    return changed
end
local function mergeActiveLayerDown()
    assert(A.screen=='editor' and A.layerSession,'Abra um projeto antes de mesclar')
    finishStroke()
    local index=A.layerSession:mergeDown(A.doc.active_layer)
    clearLayerThumbs()
    A.layerScroll=nil
    A.selection=nil;A.selectAction=nil;A.movePreview=nil;A.shapePreview=nil
    A.dirty=true
    rebuildImage()
    status('Camadas mescladas abaixo · Ctrl+Z restaura ambas')
    return index
end
-- Route menu commands to established editing operations and transactions.
-- No replacement raster implementation and no duplicated painting algorithm.
local function performMenuAction(menu,key)
    assert(menu and menu.kind and key,'Menu contextual inválido')
    if menu.kind=='layer' then
        assert(A.doc.layers[A.doc.active_layer] and
            A.doc.active_layer==menu.target,
            'Camada de destino não está selecionada')
        local ls=A.layerSession
        if key=='rename' then openLayerRename()
        elseif key=='duplicate' then duplicateActiveLayer()
        elseif key=='visibility' then
            finishStroke()
            local layer=A.doc.layers[A.doc.active_layer]
            ls:setVisible(A.doc.active_layer,not layer.visible)
            A.dirty=true;rebuildImage()
            status(layer.visible and 'Camada visível' or 'Camada oculta')
        elseif key=='clear' then clearActiveLayer()
        elseif key=='flipH' then flipActiveLayer(0)
        elseif key=='flipV' then flipActiveLayer(1)
        elseif key=='merge' then mergeActiveLayerDown()
        elseif key=='up' or key=='down' then
            finishStroke()
            local index=A.doc.active_layer
            ls:move(index,index+(key=='up' and 1 or -1))
            A.layerScroll=nil;A.dirty=true;rebuildImage()
        elseif key=='delete' then
            finishStroke()
            ls:remove(A.doc.active_layer)
            clearLayerThumbs();A.layerScroll=nil
            A.dirty=true;rebuildImage()
            status('Camada removida')
        else error('Ação de camada desconhecida: '..tostring(key)) end
        return
    end
    assert(menu.kind=='tool','Menu de ferramenta desconhecido')
    assert(selectTool(menu.target),'Não é possível mudar a ferramenta durante a pincelada')
    if key=='use' then return end
    if key=='sizeDown' or key=='sizeUp' then
        A.brushDiameter=math.max(1,math.min(256,
            A.brushDiameter+(key=='sizeDown' and -2 or 2)))
    elseif key=='opacityDown' or key=='opacityUp' then
        A.brushOpacity=math.max(.1,math.min(1,
            math.floor(A.brushOpacity*10+.5)/10+
                (key=='opacityDown' and -.1 or .1)))
    elseif key=='toleranceDown' or key=='toleranceUp' then
        A.fillTolerance=math.max(0,math.min(255,
            A.fillTolerance+(key=='toleranceDown' and -8 or 8)))
    elseif key=='outline' or key=='filled' then
        A.shapeFilled=key=='filled'
    elseif key=='visible' or key=='active' then
        A.pickerSource=key=='visible' and 'composite' or 'active'
    elseif key=='deselect' then
        A.selection=nil;A.selectAction=nil;A.movePreview=nil
    elseif key=='color' then
        modal('color')
    elseif key=='help' then
        A.toolHelp=true
    else
        error('Ação de ferramenta desconhecida: '..tostring(key))
    end
end
local function openContextMenu(kind,target,x,y)
    assert(A.screen=='editor' and A.doc and not A.modal and not A.toolHelp,
        'Menu só pode abrir dentro do editor')
    finishStroke()
    A.panning=false;A.panButton=nil
    local entries,title
    if kind=='layer' then
        if target~=A.doc.active_layer then
            A.layerSession:select(target)
            A.layerScroll=nil
            A.dirty=true
        end
        local layer=A.doc.layers[target]
        entries=Menus.layerEntries(#A.doc.layers,target,
            Store.MAX_LAYERS,layer.visible)
        title='Camada '..target..' · '..layer.name
    elseif kind=='tool' then
        local item=assert(EditorTools.fromId(target))
        entries=Menus.toolEntries(target,{
            size=A.brushDiameter,opacity=A.brushOpacity,
            tolerance=A.fillTolerance,hasSelection=A.selection~=nil})
        title=item.label..' · opções'
    else error('Menu desconhecido') end
    local w,h=love.graphics.getDimensions()
    local px,py,pw,ph=Menus.place(x,y,w,h,entries)
    A.contextMenu={kind=kind,target=target,title=title,
        entries=entries,x=px,y=py,w=pw,h=ph,cursor=1}
end
local function brushLabFromFocus()
    local slot=A.brushFocus
    local chosen
    if slot then
        chosen=slot<=4 and Presets.BUILTINS[slot] or
            Presets.custom(A.brushes)[slot-4]
    end
    A.brushLabDraft=chosen and Lab.draft(chosen) or
        Lab.draft({style=A.brushStyle,diameter=A.brushDiameter,
            opacity=A.brushOpacity,stabilization=A.stabilization})
    A.brushLabEdited=false;A.brushLabDrag=nil;A.brushLabKey='diameter'
end
local function adjustBrushLab(kind,x)
    local rect=Presets.layout(love.graphics.getDimensions())
    if not A.brushLabDraft then return end
    local value=Lab.value(rect,kind,x)
    A.brushLabDraft=Lab.adjust(A.brushLabDraft,kind,value)
    A.brushLabEdited=true
end
local function openBrushLibrary()
    A.compactPanel=nil
    assert(A.screen=='editor' and A.layerSession and not A.modal,
        'Abra uma obra para escolher um pincel')
    finishStroke()
    A.contextMenu=nil;A.toolHelp=false
    A.brushLibrary=true;A.brushFilter='all'
    local preferred=A.selectedBrushCustom and A.selectedBrushCustom+4 or 1
    A.brushFocus=Presets.focus('all',Presets.custom(A.brushes),preferred)
    brushLabFromFocus()
    status('Biblioteca: setas navegam · Enter aplica · Tab muda categoria')
end
local function switchBrushCategory(filter)
    local saved=Presets.custom(A.brushes)
    A.brushFilter=filter
    A.brushFocus=Presets.focus(filter,saved,A.brushFocus)
    brushLabFromFocus()
end
local function applyBrushPreset(preset)
    finishStroke()
    local chosen=Presets.copy(preset)
    assert(selectTool('brush'),'Não é possível selecionar pincel agora')
    A.brushStyle=chosen.style
    A.brushDiameter=chosen.diameter
    A.brushOpacity=chosen.opacity
    A.stabilization=chosen.stabilization
    A.selectedBrushCustom=Presets.slot(preset)
    A.brushLabDrag=nil;A.brushLibrary=false
    status('Pincel: '..preset.name..' · configurações aplicadas')
end
local function applyBrushLab()
    local draft=assert(A.brushLabDraft,'Ajuste de pincel indisponível')
    local chosen=Lab.draft(draft)
    finishStroke()
    assert(selectTool('brush'),'Não é possível selecionar pincel')
    A.brushStyle=chosen.style
    A.brushDiameter=chosen.diameter
    A.brushOpacity=chosen.opacity
    A.stabilization=chosen.stabilization
    A.selectedBrushCustom=nil
    A.brushLabDrag=nil
    A.brushLibrary=false
    status('Ajustes temporários aplicados · Salvar pincel para guardar')
end
local function saveCustomBrush()
    finishStroke()
    local nextItems,preset,index=Presets.save(A.brushes,{
        style=A.brushStyle,diameter=A.brushDiameter,
        opacity=A.brushOpacity,stabilization=A.stabilization})
    -- Only replace the live library after atomic serialization succeeds.
    A.store:saveBrushes(nextItems)
    A.brushes=nextItems
    A.selectedBrushCustom=index
    status('Ajuste pessoal salvo: '..preset.name)
end
local function deleteCustomBrush()
    assert(A.selectedBrushCustom,'Selecione um ajuste pessoal para excluir')
    local nextItems=Presets.remove(A.brushes,A.selectedBrushCustom)
    A.store:saveBrushes(nextItems)
    A.brushes=nextItems
    A.selectedBrushCustom=nil
    status('Ajuste pessoal excluído · pincel atual mantido')
end
-- Parameter rails change only brush/fill settings. Never call raster APIs.
local function applyParameterSlider(kind,x)
    local panel=love.graphics.getWidth()-268
    local value=Sliders.value(kind,x,panel)
    if kind=='diameter' then A.brushDiameter=value
    elseif kind=='opacity' then A.brushOpacity=value
    elseif kind=='stabilization' then A.stabilization=value
    elseif kind=='tolerance' then A.fillTolerance=value
    else error('Controle deslizante desconhecido') end
    return value
end
local function drawParameterSlider(kind,panel,value)
    local rail=Sliders.rail(kind,panel)
    local fraction=Sliders.fraction(kind,value)
    c('line')
    love.graphics.rectangle('fill',rail.x,rail.y+3,rail.w,4,2,2)
    c('accent')
    love.graphics.rectangle('fill',rail.x,rail.y+3,
        math.max(.5,rail.w*fraction),4,2,2)
    local cx=rail.x+rail.w*fraction
    c('text')
    love.graphics.circle('fill',cx,rail.y+rail.h/2,4,16)
    c('accent')
    love.graphics.circle('line',cx,rail.y+rail.h/2,4.5,16)
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
        chooseColor(value);A.modal=nil
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
-- Isolated from the large legacy graphical self-test closure because
-- LuaJIT Lua 5.1 caps each function at 200 local variables.
local function verifyVisualToolbar()
    local appearancePixels=Native.bytes(A.layerSession.composite)
    local appearanceUndo=A.layerSession:historyStats().undo
    local appearanceLayerCount=#A.doc.layers
    for _,slot in ipairs(toolSlots) do
        assert(Icons.commands(slot.id) and #Icons.commands(slot.id)>=2,
            'Ícone vetorial ausente no editor')
        love.draw()
        local hit=false
        for _,target in ipairs(A.buttons) do
            if target.x==slot.x and target.y==78 and
                target.w==slot.w and target.h==34 then hit=true;break end
        end
        assert(hit,'Barra visual perdeu região clicável da ferramenta '..slot.id)
        love.mousepressed(slot.x+slot.w/2,94,1,false)
        assert(A.tool==slot.id,'Ferramenta visual não selecionou '..slot.id)
    end
    assert(Native.bytes(A.layerSession.composite)==appearancePixels and
        A.layerSession:historyStats().undo==appearanceUndo and
        #A.doc.layers==appearanceLayerCount,
        'Novo layout alterou raster, histórico ou camadas')
    selectTool('inspect')
    A.sideTab='layers'
end
-- Stage 26: exercise focus mode through actual buttons, keyboard and
-- expanded-canvas hit testing without mutating the existing document.
local function verifyFocusWorkspace()
    local w,h=love.graphics.getDimensions()
    local originalTool,originalTab=A.tool,A.sideTab
    local diameter,opacity=A.brushDiameter,A.brushOpacity
    local image=Native.bytes(A.layerSession.composite)
    local history=A.layerSession:historyStats().undo
    local count=#A.doc.layers
    local dirty=A.dirty
    local originalView=viewData()
    local oldX,oldY=View.center(originalView,w,h)
    assert(not A.focusMode,'Modo foco deve começar fechado no teste')
    assert(not Workspace.contains(w,h,false,w-75,170),
        'Região lateral não pode ser canvas com painel aberto')
    love.draw()
    love.mousepressed(w-290,31,1,false)
    assert(A.focusMode,'Botão superior não recolheu o painel')
    love.draw()
    assert(Workspace.contains(w,h,true,w-75,170),
        'Área do antigo painel não passou a ser canvas')
    for _,target in ipairs(A.buttons) do
        assert(not (target.x>=w-268 and target.y>64),
            'Controle do painel permanece clicável após recolher')
    end
    local newX,newY=View.center(viewData(),w,h)
    assert(math.abs(newX-oldX-134)<1e-6 and newY==oldY,
        'Canvas não se recentralizou sem deslocar verticalmente')
    A.lastPacket=nil
    selectTool('inspect')
    love.draw()
    love.mousepressed(w-75,170,1,false)
    assert(A.lastPacket,'Clique na área expandida não chegou ao canvas')
    selectTool('brush')
    A.brushDiameter=12;A.brushOpacity=.8
    love.draw()
    local dockY=h-116
    love.mousepressed(506,dockY+12,1,false)
    assert(A.brushDiameter==10,
        'Controle rápido de tamanho não alterou o pincel')
    love.draw();love.mousepressed(582,dockY+12,1,false)
    assert(A.brushDiameter==12,'Controle rápido + não restaurou tamanho')
    love.draw();love.mousepressed(674,dockY+12,1,false)
    assert(math.abs(A.brushOpacity-.7)<1e-6,
        'Controle rápido de opacidade não funcionou')
    love.draw();love.mousepressed(754,dockY+12,1,false)
    assert(math.abs(A.brushOpacity-.8)<1e-6,
        'Controle rápido + não restaurou opacidade')
    A.brushDiameter=diameter;A.brushOpacity=opacity
    love.keypressed('tab')
    assert(not A.focusMode,'Tab não restaurou painel')
    local backX,backY=View.center(viewData(),w,h)
    assert(backX==oldX and backY==oldY,
        'Retornar do foco alterou posição do canvas')
    love.keypressed('tab')
    assert(A.focusMode,'Tab não entrou no foco pela segunda vez')
    love.draw();love.mousepressed(w-290,31,1,false)
    assert(not A.focusMode,'Botão superior não restaurou painel')
    assert(A.zoom==originalView.zoom and A.rotation==originalView.rotation
        and A.panX==originalView.panX and A.panY==originalView.panY,
        'Foco alterou zoom, rotação ou pan anteriores')
    assert(Native.bytes(A.layerSession.composite)==image and
        A.layerSession:historyStats().undo==history and
        #A.doc.layers==count and A.dirty==dirty,
        'Modo foco alterou pixels, camadas, histórico ou dirty flag')
    selectTool(originalTool);A.sideTab=originalTab
end
-- GUI regression: events travel through real LÖVE mouse/key handlers.
-- Kept outside the large legacy test closure for LuaJIT's local limit.
local function verifyContextMenus()
    local w,h=love.graphics.getDimensions()
    local panel=w-268
    local oldTool,oldTab=A.tool,A.sideTab
    local oldDiameter,oldOpacity=A.brushDiameter,A.brushOpacity
    local initialPixels=Native.bytes(A.layerSession.composite)
    local initialLayerCount=#A.doc.layers
    local initialHistory=A.layerSession:historyStats().undo
    local function choose(key)
        local menu=assert(A.contextMenu,'Menu esperado')
        local index
        for i,item in ipairs(menu.entries) do
            if item.key==key then index=i;break end
        end
        assert(index and menu.entries[index].enabled,
            'Ação não disponível: '..key)
        love.draw()
        love.mousepressed(menu.x+24,
            menu.y+Menus.HEADER+(index-1)*Menus.ROW+10,1,false)
        assert(not A.contextMenu,'Menu não fechou após ação')
    end
    -- Right-click on a toolbar slot opens options WITHOUT painting.
    selectTool('inspect')
    A.sideTab='layers'
    love.draw()
    love.mousepressed(245,92,2,false)
    assert(A.contextMenu and A.contextMenu.kind=='tool' and
        A.contextMenu.target=='brush' and A.tool=='inspect',
        'Botão direito no pincel não abriu o menu correspondente')
    choose('sizeUp')
    assert(A.tool=='brush' and A.brushDiameter==oldDiameter+2,
        'Menu de pincel não aplicou tamanho no estado real')
    A.brushDiameter=oldDiameter
    love.draw()
    love.mousepressed(245,92,2,false)
    assert(A.contextMenu,'Menu deveria reabrir')
    love.keypressed('escape')
    assert(not A.contextMenu,'Esc não fechou o menu de ferramenta')
    love.draw()
    love.mousepressed(536,90,2,false)
    assert(A.contextMenu and A.contextMenu.target=='picker',
        'Conta-gotas precisa de menu específico')
    choose('active')
    assert(A.tool=='picker' and A.pickerSource=='active',
        'Menu de conta-gotas não mudou fonte')
    A.pickerSource='composite'
    love.draw()
    love.mousepressed(480,92,2,false)
    assert(A.contextMenu and A.contextMenu.target=='shape',
        'Formas precisa de menu específico')
    choose('filled')
    assert(A.tool=='shape' and A.shapeFilled,
        'Forma preenchida via menu não funcionou')
    A.shapeFilled=false
    -- Outside click dismisses instead of reaching canvas or toolbar.
    selectTool('brush')
    love.draw();love.mousepressed(245,92,2,false)
    assert(A.contextMenu,'Menu não abriu para teste externo')
    love.draw();love.mousepressed(math.min(700,w-305),250,1,false)
    assert(not A.contextMenu and not A.drawing,
        'Clique externo não pode iniciar uma pincelada')
    selectTool('inspect')
    A.sideTab='layers'
    love.draw()
    love.mousepressed(370,245,2,false)
    assert(A.panning and not A.contextMenu,
        'Botão direito no canvas precisa continuar movendo a vista')
    love.mousereleased(370,245,2,false)
    assert(not A.panning,'Arraste direito não foi encerrado')
    -- Context action on an actual layer row, not just isolated APIs.
    love.draw()
    local rows=Thumbnails.rows(h)
    local start,stop=Thumbnails.window(#A.doc.layers,
        A.doc.active_layer,rows,A.layerScroll)
    local target=stop
    love.mousepressed(panel+75,487,2,false)
    assert(A.contextMenu and A.contextMenu.kind=='layer' and
        A.contextMenu.target==target and A.doc.active_layer==target,
        'Botão direito na linha não selecionou camada nem abriu menu')
    local originalVisibility=A.doc.layers[target].visible
    love.keypressed('down')
    love.keypressed('down')
    assert(A.contextMenu and
        A.contextMenu.entries[A.contextMenu.cursor].key=='visibility',
        'Setas não navegam o menu')
    love.keypressed('return')
    assert(not A.contextMenu and
        A.doc.layers[target].visible~=originalVisibility,
        'Enter não acionou visibilidade')
    undoDoc()
    assert(A.doc.layers[target].visible==originalVisibility,
        'Desfazer não restaurou visibilidade alterada pelo menu')
    local beforeDuplicate=#A.doc.layers
    if beforeDuplicate<Store.MAX_LAYERS then
        A.layerScroll=nil
        love.draw()
        local st,sp=Thumbnails.window(beforeDuplicate,
            A.doc.active_layer,Thumbnails.rows(h),A.layerScroll)
        love.mousepressed(panel+74,487,2,false)
        assert(A.contextMenu and A.contextMenu.target==sp,
            'Menu de linha precisa respeitar rolagem de camadas')
        choose('duplicate')
        assert(#A.doc.layers==beforeDuplicate+1,
            'Duplicação pelo menu não criou camada')
        undoDoc()
        assert(#A.doc.layers==beforeDuplicate,
            'Desfazer não restaurou estrutura após duplicação no menu')
    end
    assert(Native.bytes(A.layerSession.composite)==initialPixels and
        #A.doc.layers==initialLayerCount,
        'Menus restaurados não podem alterar pixels ou camada total')
    -- Menu never produces a paint history entry; actual operations above
    -- create undoable metadata/structural history already tested.
    assert(A.layerSession:historyStats().undo<=
        math.min(initialHistory+1,A.layerSession.MAX_HISTORY_ENTRIES),
        'Menu contextual inseriu operações de desenho inesperadas')
    assert(not A.contextMenu and not A.modal,
        'Menu ou modal residual após verificações')
    A.brushDiameter=oldDiameter;A.brushOpacity=oldOpacity
    selectTool(oldTool);A.sideTab=oldTab
end
-- Stage 28: exercise real clickable picker, save/remove and storage,
-- plus isolation from raster/history in the current active document.
local function verifyBrushLibrary()
    local w,h=love.graphics.getDimensions()
    local panel=w-268
    local rect=Presets.layout(w,h)
    local originalTool,originalTab=A.tool,A.sideTab
    local originalStyle,originalDiameter=A.brushStyle,A.brushDiameter
    local originalOpacity,originalStabilization=A.brushOpacity,A.stabilization
    local originalSlot=A.selectedBrushCustom
    local originalDirty=A.dirty
    local originalPixels=Native.bytes(A.layerSession.composite)
    local originalHistory=A.layerSession:historyStats().undo
    local originalLayers=#A.doc.layers
    local originals=A.store:getBrushes()
    selectTool('brush')
    A.sideTab='brush'
    love.draw()
    love.mousepressed(panel+100,344,1,false)
    assert(A.brushLibrary,'Botão Biblioteca não abriu')
    love.draw()
    -- A preview-only click must update the inspector but cannot apply,
    -- paint, save a preset or close the catalogue.
    local beforePreviewDiameter=A.brushDiameter
    local beforePreviewStyle=A.brushStyle
    local cardWidth=(Lab.CATALOGUE_WIDTH-56)/2
    local previewButton=BrushCard.previewButton(rect.x+20,
        rect.y+80+88,cardWidth)
    love.mousepressed(previewButton.x+previewButton.w/2,
        previewButton.y+previewButton.h/2,1,false)
    assert(A.brushLibrary and A.brushFocus==3 and
        A.brushLabDraft.diameter==24 and
        A.brushLabDraft.style=='soft' and
        A.brushLabEdited==false and
        A.brushDiameter==beforePreviewDiameter and
        A.brushStyle==beforePreviewStyle,
        'Prévia no cartão aplicou o pincel em vez de só inspecionar')
    love.draw()
    assert(A.brushSampleCache.inspector.key==
        Samples.key(A.brushLabDraft,A.color) and
        Native.bytes(A.layerSession.composite)==originalPixels and
        A.layerSession:historyStats().undo==originalHistory,
        'Prévia de cartão alterou pixels/histórico ou não atualizou C++')
    -- Built-in #3 occupies the second row, first column.
    love.mousepressed(rect.x+34,rect.y+80+88+10,1,false)
    assert(not A.brushLibrary and A.brushStyle=='soft' and
        A.brushDiameter==24 and math.abs(A.brushOpacity-.6)<1e-6 and
        A.stabilization==2,'Biblioteca não aplicou o Marcador suave')
    local originalIsDown=love.keyboard.isDown
    love.keyboard.isDown=function(...)
        for i=1,select('#',...) do
            if select(i,...)=='lctrl' then return true end
        end
        return false
    end
    love.keypressed('b')
    love.keyboard.isDown=originalIsDown
    assert(A.brushLibrary,'Ctrl+B não abriu biblioteca')
    love.draw()
    love.mousepressed(100,245,1,false)
    assert(A.brushLibrary and
        Native.bytes(A.layerSession.composite)==originalPixels,
        'Clique externo não deve fechar nem pintar por baixo do modal')
    love.draw()
    love.mousepressed(rect.x+90,rect.y+496,1,false)
    local saved=Presets.custom(A.store:getBrushes())
    assert(saved[1] and saved[1].diameter==24 and
        math.abs(saved[1].opacity-.6)<1e-6,
        'Salvar pessoal não persistiu no brushes.json')
    assert(A.selectedBrushCustom==1 and A.brushLibrary,
        'Salvar ajuste deve manter a biblioteca aberta')
    -- "Meus" must show saved slot 1 in the first row (not row 3).
    -- Its preview must remain non-destructive before the card is applied.
    love.draw()
    love.mousepressed(rect.x+609,rect.y+62,1,false)
    assert(A.brushFilter=='personal' and A.brushFocus==5,
        'Filtro pessoal não focou primeiro pincel salvo')
    love.draw()
    local personalCardWidth=(Lab.CATALOGUE_WIDTH-56)/2
    local previewSlot=BrushCard.previewButton(rect.x+20,
        rect.y+80,personalCardWidth)
    love.mousepressed(previewSlot.x+previewSlot.w/2,
        previewSlot.y+previewSlot.h/2,1,false)
    assert(A.brushLibrary and A.brushFocus==5 and
        A.brushLabDraft.diameter==24 and
        A.doc.active_layer>=1 and
        Native.bytes(A.layerSession.composite)==originalPixels,
        'Prévia pessoal compactada alterou projeto ou aplicou pincel')
    A.brushDiameter=7
    love.draw()
    love.mousepressed(rect.x+35,rect.y+80+10,1,false)
    assert(not A.brushLibrary and A.brushDiameter==24 and
        A.selectedBrushCustom==1,
        'Aplicar cartão pessoal na primeira linha falhou')
    openBrushLibrary()
    assert(A.brushLibrary,'Reabrir biblioteca falhou')
    love.draw()
    love.mousepressed(rect.x+270,rect.y+496,1,false)
    assert(not Presets.custom(A.store:getBrushes())[1] and
        not A.selectedBrushCustom,
        'Excluir ajuste pessoal não atualizou armazenamento')
    love.keypressed('escape')
    assert(not A.brushLibrary,'Esc não fechou biblioteca')
    assert(#A.store:getBrushes()==#originals,
        'Entrada antiga foi adicionada/removida sem solicitação')
    assert(A.dirty==originalDirty and
        Native.bytes(A.layerSession.composite)==originalPixels and
        A.layerSession:historyStats().undo==originalHistory and
        #A.doc.layers==originalLayers,
        'Biblioteca alterou pixels, dirty flag, camadas ou histórico')
    A.brushStyle=originalStyle
    A.brushDiameter=originalDiameter
    A.brushOpacity=originalOpacity
    A.stabilization=originalStabilization
    A.selectedBrushCustom=originalSlot
    selectTool(originalTool)
    A.sideTab=originalTab
end
-- Stage 29: tests actual LÖVE drag handlers rather than just slider math.
-- Keep isolated to avoid LuaJIT's per-function local-variable ceiling.
local function verifyPrecisionSliders()
    local panel=love.graphics.getWidth()-268
    local originalTool,originalTab=A.tool,A.sideTab
    local originalDiameter,originalOpacity=A.brushDiameter,A.brushOpacity
    local originalStabilization,originalTolerance=A.stabilization,A.fillTolerance
    local pixels=Native.bytes(A.layerSession.composite)
    local history=A.layerSession:historyStats().undo
    local dirty=A.dirty
    local count=#A.doc.layers
    selectTool('brush')
    A.sideTab='brush'
    local diameter=Sliders.rail('diameter',panel)
    love.draw()
    love.mousepressed(diameter.x,diameter.y+5,1,false)
    assert(A.sliderDrag=='diameter' and A.brushDiameter==1 and
        not A.drawing,'Click on size rail must capture slider without painting')
    love.mousemoved(diameter.x+diameter.w/2,diameter.y+5,53,0,false)
    assert(A.brushDiameter==129,'Size drag failed at center')
    -- Release on the canvas side: no stroke or selection is allowed.
    love.mousereleased(300,250,1,false)
    assert(A.sliderDrag==nil and A.brushDiameter==1 and
        not A.drawing,'Release left of rail must clamp and stop capture')
    love.draw()
    local opacity=Sliders.rail('opacity',panel)
    love.mousepressed(opacity.x+opacity.w/2,opacity.y+4,1,false)
    assert(A.sliderDrag=='opacity' and math.abs(A.brushOpacity-.55)<1e-8,
        'Opacity should support 1% precision, starting at 55%')
    love.mousemoved(opacity.x+opacity.w,opacity.y+4,53,0,false)
    love.mousereleased(opacity.x+opacity.w,opacity.y+4,1,false)
    assert(A.brushOpacity==1 and A.sliderDrag==nil,
        'Opacity drag must reach 100% and release')
    love.draw()
    local stabil=Sliders.rail('stabilization',panel)
    love.mousepressed(stabil.x+stabil.w/2,stabil.y+4,1,false)
    love.mousereleased(stabil.x+stabil.w/2,stabil.y+4,1,false)
    assert(A.stabilization==3,'Stabilization rail did not choose level 3')
    selectTool('fill')
    love.draw()
    local tolerance=Sliders.rail('tolerance',panel)
    love.mousepressed(tolerance.x+tolerance.w/2,tolerance.y+5,1,false)
    love.mousereleased(tolerance.x+tolerance.w/2,tolerance.y+5,1,false)
    assert(A.fillTolerance==128 and not A.drawing,
        'Fill rail must choose tolerance 128 without painting')
    -- Former +/- buttons remain functional in the same legacy rectangles.
    selectTool('brush')
    love.draw()
    love.mousepressed(panel+40,472,1,false)
    assert(A.brushDiameter==1,
        'Legacy − button changed or escaped native range')
    A.brushDiameter=4
    love.draw();love.mousepressed(panel+208,472,1,false)
    assert(A.brushDiameter==6,'Legacy diameter + stopped working')
    assert(A.sliderDrag==nil and
        Native.bytes(A.layerSession.composite)==pixels and
        A.layerSession:historyStats().undo==history and
        A.dirty==dirty and #A.doc.layers==count,
        'Slider input must not affect document raster/history/dirty flag')
    A.brushDiameter=originalDiameter;A.brushOpacity=originalOpacity
    A.stabilization=originalStabilization;A.fillTolerance=originalTolerance
    selectTool(originalTool);A.sideTab=originalTab
end
-- Exercise the actual editor preview image/cache and pointer handlers.
-- Kept separate from large GUI self-test for LuaJIT's 200-local ceiling.
local function verifyBrushTipHover()
    local w,h=love.graphics.getDimensions()
    local savedTool=A.tool
    local savedDiameter,savedStyle=A.brushDiameter,A.brushStyle
    local savedOpacity,savedColor=A.brushOpacity,A.color
    local savedPreview=A.previewEnabled
    local savedDirty=A.dirty
    local layers=#A.doc.layers
    local pixels=Native.bytes(A.layerSession.composite)
    local history=A.layerSession:historyStats().undo
    selectTool('brush')
    A.brushDiameter=18;A.brushStyle='soft';A.brushOpacity=.6
    A.color=0xe53b44ff;A.previewEnabled=true
    local x,y=View.center(viewData(),w,h)
    love.mousemoved(x,y,0,0,false)
    love.draw()
    assert(A.tipCache and A.tipCache.stamp and
        A.tipCache.key==Tip.key(Tip.options(
            A.tool,A.brushDiameter,A.brushOpacity,A.color,
            A.brushStyle,1,0,0,false)),
        'Hover não gerou textura nativa coerente com o pincel')
    local nativeReference=Tip.render(Native,Tip.options('brush',18,.6,
        0xe53b44ff,'soft',1,0,0,false))
    assert(Native.bytes(A.tipCache.stamp.buffer)==
        Native.bytes(nativeReference.buffer),
        'Prévia gráfica divergiu dos bytes RGBA do raster C++')
    local cache=A.tipCache
    love.draw()
    assert(A.tipCache==cache,
        'Preview precisa reutilizar textura entre frames sem alterações')
    A.brushOpacity=.7
    love.draw()
    assert(A.tipCache~=cache and
        Native.bytes(A.tipCache.stamp.buffer)~=
            Native.bytes(nativeReference.buffer),
        'Opacidade nova não atualizou a prévia nativa')
    selectTool('erase')
    love.draw()
    assert(A.tipCache.stamp.kind=='erase' and
        Native.readPixel(A.tipCache.stamp.buffer,
            math.floor(A.tipCache.stamp.center),
            math.floor(A.tipCache.stamp.center))%256>0,
        'Borracha não mostrou sua máscara de remoção')
    love.draw()
    love.mousepressed(w-445,30,1,false)
    assert(not A.previewEnabled,'Botão de prévia não desligou')
    love.draw()
    love.mousepressed(w-445,30,1,false)
    assert(A.previewEnabled,'Botão de prévia não religou')
    love.mousemoved(x,y,0,0,false)
    assert(Tip.visible(A,w,h,x,y),'Prévia deve voltar no canvas')
    A.brushLibrary=true
    assert(not Tip.visible(A,w,h,x,y),
        'Biblioteca aberta deve ocultar prévia')
    A.brushLibrary=false
    A.toolHelp=true
    assert(not Tip.visible(A,w,h,x,y),
        'Janela de ajuda deve ocultar prévia')
    A.toolHelp=false
    love.mousemoved(6,170,0,0,false)
    assert(not Tip.visible(A,w,h,6,170),
        'Fora da área de trabalho não pode haver prévia')
    love.mousemoved(x,y,0,0,false)
    assert(Tip.visible(A,w,h,x,y),
        'Mouse deve restabelecer a posição de hover')
    assert(Native.bytes(A.layerSession.composite)==pixels and
        A.layerSession:historyStats().undo==history and
        #A.doc.layers==layers and A.dirty==savedDirty,
        'Prévia visual alterou bytes, histórico ou estrutura da obra')
    A.brushDiameter=savedDiameter;A.brushStyle=savedStyle
    A.brushOpacity=savedOpacity;A.color=savedColor
    A.previewEnabled=savedPreview
    A.hoverX=nil;A.hoverY=nil
    selectTool(savedTool)
end
-- Full GUI regression for mobile-inspired mode using real click dispatch,
-- independent of the large legacy test function's LuaJIT local budget.
local function verifyCompactUi()
    local w,h=love.graphics.getDimensions()
    local pixels=Native.bytes(A.layerSession.composite)
    local layerCount=#A.doc.layers
    local dirty=A.dirty
    local zoom,rotation,panX,panY=A.zoom,A.rotation,A.panX,A.panY
    local oldTool,oldTab=A.tool,A.sideTab
    local oldSize,oldOpacity=A.brushDiameter,A.brushOpacity
    assert(not A.compactUi,'Legacy self-test must begin with desktop UI')
    love.draw()
    love.mousepressed(w-595,30,1,false)
    assert(A.compactUi and not A.compactPanel,
        'Layout compacto não ligou no cabeçalho')
    local dock=Compact.toolbar(w,h)
    local function tap(slot)
        love.draw()
        local b=dock[slot]
        love.mousepressed(b.x+b.w/2,b.y+b.h/2,1,false)
    end
    local clip=Workspace.bounds(w,h,true,true)
    assert(clip.right==w-16 and clip.bottom==h-190,
        'Canvas compacto deve evitar os ajustes e a barra inferior')
    assert(A.zoom==zoom and A.rotation==rotation and
        A.panX==panX and A.panY==panY,
        'Mudança de layout não pode transformar documento')
    tap(2)
    assert(A.compactPanel=='tools','Botão Ferramentas não abriu a paleta')
    local p=Compact.popup(w,h,'tools')
    love.draw()
    love.mousepressed(p.x+14+156+32,p.y+52+70+25,1,false)
    assert(not A.compactPanel and A.tool=='erase',
        'Ícone de borracha na paleta não ativou ferramenta')
    tap(1)
    assert(A.tool=='brush','Botão Pincel não retornou para pincel')
    selectTool('inspect')
    tap(1)
    assert(A.tool=='brush',
        'Pincel deve partir de outras ferramentas para pincel, não borracha')
    tap(1)
    assert(A.tool=='erase','Segundo toque no Pincel deve alternar para borracha')
    tap(1)
    assert(A.tool=='brush','Terceiro toque deve restaurar pincel')
    tap(5)
    assert(A.focusMode and A.compactUi,
        'Botão Tela precisa esconder a barra compacta')
    love.draw()
    local expanded=Workspace.bounds(w,h,true,false)
    assert(expanded.bottom==h-78,
        'Tela cheia precisa ampliar a área de desenho inferior')
    love.keypressed('tab')
    assert(not A.focusMode and A.compactUi,
        'Tab deve restaurar barra compacta depois da tela cheia')
    tap(3)
    assert(A.compactPanel=='properties','Ajustes não abriram')
    p=Compact.popup(w,h,'properties')
    love.draw()
    love.mousepressed(p.x+17+73+25,p.y+54+29+15,1,false)
    assert(A.brushDiameter==math.min(256,oldSize+2),
        'Ajuste compacto de diâmetro não chamou o motor existente')
    A.brushDiameter=oldSize
    love.keypressed('escape')
    assert(not A.compactPanel and A.screen=='editor',
        'Esc no popover não deve voltar para galeria')
    tap(4)
    assert(A.compactPanel=='color',
        'Botão Cor não abriu a janela compacta de cor')
    p=Compact.popup(w,h,'color')
    love.draw()
    love.mousepressed(p.x+270,p.y+88,1,false)
    assert(A.modal and A.modal.kind=='color',
        'Código hexadecimal não abriu o editor existente')
    love.keypressed('escape')
    assert(not A.modal and A.screen=='editor',
        'Fechar cor hexadecimal não deve sair do editor')
    tap(6)
    assert(A.compactPanel=='layers','Janela de camadas não abriu')
    p=Compact.popup(w,h,'layers')
    love.draw()
    assert(#A.buttons>0,'A janela de camadas não tem ações clicáveis')
    -- Dismissal must never penetrate to a painting stroke.
    love.mousepressed(450,240,1,false)
    assert(not A.compactPanel and not A.drawing,
        'Clique fora de camadas iniciou ação no canvas')
    tap(6)
    if #A.doc.layers<Store.MAX_LAYERS then
        love.draw()
        love.mousepressed(p.x+39,p.y+59,1,false)
        assert(#A.doc.layers==layerCount+1,
            'Adicionar camada na janela compacta falhou')
        undoDoc()
        assert(#A.doc.layers==layerCount,
            'Ctrl+Z equivalente não restaurou estrutura compacta')
    end
    A.compactPanel=nil
    tap(2)
    assert(A.compactPanel=='tools','Paleta não reabriu')
    love.draw()
    local close=Compact.popup(w,h,'tools')
    love.mousepressed(close.x+close.w-29,close.y+22,1,false)
    assert(not A.compactPanel,'Botão X não fechou paleta')
    -- Preserve raster and cached image while toggling workspace back.
    assert(Native.bytes(A.layerSession.composite)==pixels and
        #A.doc.layers==layerCount,
        'Ações desfeitas da barra compacta modificaram a obra')
    love.draw()
    love.mousepressed(w-595,30,1,false)
    assert(not A.compactUi and A.compactPanel==nil,
        'Retorno para a interface desktop falhou')
    assert(A.zoom==zoom and A.rotation==rotation and
        A.panX==panX and A.panY==panY,
        'Trocar layout de volta mudou zoom ou rotação')
    A.brushDiameter=oldSize;A.brushOpacity=oldOpacity
    selectTool(oldTool);A.sideTab=oldTab
    A.dirty=dirty
end
-- Stage 32: exercise quick rails through real LÖVE mouse events.
-- The visuals must never mutate layers, pixels, dirty or undo history.
local function verifyCompactVisualControls()
    local w,h=love.graphics.getDimensions()
    local previousTool,previousTab=A.tool,A.sideTab
    local previousSize,previousOpacity=A.brushDiameter,A.brushOpacity
    local previousDirty,previousPreview=A.dirty,A.previewEnabled
    local previousZoom,previousRotation=A.zoom,A.rotation
    local previousPanX,previousPanY=A.panX,A.panY
    local pixels=Native.bytes(A.layerSession.composite)
    local undo=A.layerSession:historyStats().undo
    local layers=#A.doc.layers
    assert(not A.compactUi,'Fixture visual precisa começar no desktop')
    selectTool('brush')
    love.draw()
    love.mousepressed(w-595,30,1,false)
    assert(A.compactUi and not A.compactPanel,
        'Botão do cabeçalho não abriu modo compacto novo')
    local controls=Compact.quick(w,h)
    love.draw()
    love.mousepressed(controls.diameter.x,controls.diameter.y+7,1,false)
    assert(A.quickDrag=='diameter' and A.brushDiameter==1 and
        not A.drawing,'Barra de tamanho não capturou o mouse corretamente')
    love.mousemoved(controls.diameter.x+80,
        controls.diameter.y+7,80,0,false)
    assert(A.brushDiameter>1 and A.brushDiameter<256,
        'Deslizamento não atualizou diâmetro continuamente')
    love.mousereleased(controls.diameter.x+controls.diameter.w+20,
        controls.diameter.y+7,1,false)
    assert(A.brushDiameter==256 and A.quickDrag==nil,
        'Soltar fora da barra não limitou tamanho nem liberou o mouse')
    love.draw()
    love.mousepressed(controls.opacity.x+80,
        controls.opacity.y+7,1,false)
    assert(A.quickDrag=='opacity' and math.abs(A.brushOpacity-.55)<1e-8,
        'Barra de opacidade não permite 55%')
    love.mousemoved(controls.opacity.x-25,
        controls.opacity.y+7,-105,0,false)
    assert(A.brushOpacity==.1,'Opacidade deve limitar em 10%')
    love.mousereleased(controls.opacity.x+controls.opacity.w+25,
        controls.opacity.y+7,1,false)
    assert(A.quickDrag==nil and A.brushOpacity==1,
        'Arraste de opacidade deve terminar em 100%')
    love.draw()
    local bar=Compact.toolbar(w,h)
    love.mousepressed(bar[2].x+bar[2].w/2,
        bar[2].y+bar[2].h/2,1,false)
    assert(A.compactPanel=='tools','Ícone Ferramentas deixou de funcionar')
    love.draw()
    love.mousepressed(controls.diameter.x,
        controls.diameter.y+7,1,false)
    assert(not A.compactPanel and not A.quickDrag and
        A.brushDiameter==256,
        'Clique fora do popup vazou para a barra rápida')
    love.draw()
    love.mousepressed(bar[5].x+bar[5].w/2,
        bar[5].y+bar[5].h/2,1,false)
    assert(A.focusMode,'Ícone Tela Cheia deixou de funcionar')
    love.keypressed('tab')
    assert(not A.focusMode and A.compactUi,
        'Tab não restaurou a barra compacta')
    assert(Native.bytes(A.layerSession.composite)==pixels and
        A.layerSession:historyStats().undo==undo and
        #A.doc.layers==layers and A.dirty==previousDirty,
        'Ajuste visual alterou pixels, histórico, camadas ou dirty')
    love.draw()
    love.mousepressed(w-595,30,1,false)
    assert(not A.compactUi,'Troca de volta ao desktop falhou')
    A.brushDiameter=previousSize;A.brushOpacity=previousOpacity
    A.previewEnabled=previousPreview
    selectTool(previousTool);A.sideTab=previousTab
    assert(A.zoom==previousZoom and A.rotation==previousRotation and
        A.panX==previousPanX and A.panY==previousPanY,
        'Troca de estilo modificou navegação da tela')
end
-- Stage 33: real mouse/event checks for color workflow, persistent
-- palette and categorized brush window; native document stays unchanged.
local function verifyColorBrushWindows()
    local w,h=love.graphics.getDimensions()
    local prev=A.color
    local oldTool,oldTab=A.tool,A.sideTab
    local oldSize,oldStyle=A.brushDiameter,A.brushStyle
    local oldOpacity,oldStab=A.brushOpacity,A.stabilization
    local oldSelected=A.selectedBrushCustom
    local oldHistory=A.colorHistory
    local oldSaved=A.savedColors
    local oldPrefs=A.preferences
    local oldDirty=A.dirty
    local bytes=Native.bytes(A.layerSession.composite)
    local steps=A.layerSession:historyStats().undo
    local layers=#A.doc.layers
    assert(not A.compactUi,'Color tests start in original desktop mode')
    selectTool('brush')
    love.draw()
    love.mousepressed(w-595,30,1,false)
    assert(A.compactUi,'Compact panel needed for color button')
    local bar=Compact.toolbar(w,h)
    local function colorButton()
        love.draw()
        love.mousepressed(bar[4].x+bar[4].w/2,
            bar[4].y+bar[4].h/2,1,false)
    end
    colorButton()
    assert(A.compactPanel=='color' and A.colorMode=='hsb' and
        A.previousColor==prev,'Compact Color did not open HSB with previous')
    local p=Compact.popup(w,h,'color')
    local hue=ColorPanel.hueRect(p)
    love.draw()
    love.mousepressed(hue.x+9,hue.y+40,1,false)
    assert(A.colorDrag=='hue' and not A.drawing,
        'Hue slider did not capture pointer')
    love.mousemoved(hue.x+9,hue.y+110,0,70,false)
    love.mousereleased(hue.x+9,hue.y+110,1,false)
    assert(A.colorDrag==nil and A.color~=prev,
        'Hue drag did not edit live RGBA')
    local sv=ColorPanel.svRect(p)
    love.draw()
    love.mousepressed(sv.x+sv.w,sv.y,1,false)
    love.mousereleased(sv.x+sv.w,sv.y,1,false)
    local _,saturation,brightness=ColorPanel.hsb(A.color)
    assert(saturation>99 and brightness>99,
        'HSB square did not apply saturation/brightness')
    love.draw()
    love.mousepressed(p.x+185,p.y+143,1,false)
    assert(A.colorMode=='rgb','RGB tab did not open')
    local rail=ColorPanel.track(p,'rgb','R')
    love.draw()
    love.mousepressed(rail.x,rail.y+5,1,false)
    assert(A.colorDrag=='rgb-R','RGB slider did not capture pointer')
    love.mousemoved(rail.x+rail.w/2,rail.y+5,132,0,false)
    love.mousereleased(rail.x+rail.w/2,rail.y+5,1,false)
    local r=Colors.channels(A.color)
    assert(r==128,'RGB red channel did not map midpoint to 128')
    love.draw()
    love.mousepressed(p.x+310,p.y+143,1,false)
    assert(A.colorMode=='palette','Paleta tab did not open')
    local newColor=0x8ac331a9
    chooseColor(newColor)
    if #A.savedColors<ColorPanel.PALETTE_LIMIT then
        local originalCount=#A.savedColors
        love.draw()
        love.mousepressed(p.x+285,p.y+326,1,false)
        assert(#A.savedColors==originalCount+1 and
            A.store:getPreferences().colorPalette and
            #A.store:getPreferences().colorPalette==#A.savedColors,
            'Save palette did not persist to preferences.json')
        chooseColor(0x440099ff)
        local index=#A.savedColors
        love.draw()
        love.mousepressed(p.x+22+((index-1)%6)*61+15,
            p.y+211+math.floor((index-1)/6)*46+15,1,false)
        assert(A.color==newColor,
            'Saved swatch did not restore its RGBA alpha')
    end
    local beforeHex=A.color
    love.draw()
    love.mousepressed(p.x+68,p.y+142,1,false)
    assert(A.colorMode=='hsb','HSB tab did not restore')
    love.draw()
    love.mousepressed(p.x+260,p.y+83,1,false)
    assert(A.modal and A.modal.kind=='color',
        'RGBA hexadecimal modal no longer accessible')
    love.keypressed('escape')
    assert(not A.modal and A.screen=='editor' and
        A.color==beforeHex,'Canceling hex modal unexpectedly changed color')
    openBrushLibrary()
    local pos=Presets.layout(w,h)
    love.draw()
    love.mousepressed(pos.x+610,pos.y+61,1,false)
    assert(A.brushFilter=='personal' and A.brushLibrary,
        'My Brushes tab failed')
    love.draw()
    love.mousepressed(pos.x+490,pos.y+61,1,false)
    assert(A.brushFilter=='builtin','Built-in Brushes tab failed')
    love.draw()
    love.mousepressed(pos.x+385,pos.y+61,1,false)
    assert(A.brushFilter=='all','All brushes tab failed')
    love.draw()
    love.mousepressed(pos.x+34,pos.y+91,1,false)
    assert(not A.brushLibrary and A.tool=='brush' and
        A.brushDiameter==Presets.BUILTINS[1].diameter,
        'Filter did not preserve actual brush preset selection')
    assert(Native.bytes(A.layerSession.composite)==bytes and
        A.layerSession:historyStats().undo==steps and
        #A.doc.layers==layers and A.dirty==oldDirty,
        'Color/brush windows modified native pixels/history/dirty')
    love.draw()
    love.mousepressed(w-595,30,1,false)
    assert(not A.compactUi,'Layout did not return to desktop')
    A.color=prev;A.brushDiameter=oldSize;A.brushStyle=oldStyle
    A.brushOpacity=oldOpacity;A.stabilization=oldStab
    A.selectedBrushCustom=oldSelected
    A.colorHistory=oldHistory
    A.store:setPreferences(oldPrefs)
    A.preferences=oldPrefs;A.savedColors=oldSaved
    selectTool(oldTool);A.sideTab=oldTab
end
-- GUI regression for native brush-catalogue RGBA swatches, caching and
-- category/keyboard input. Kept outside nativeSelfTest to avoid local limit.
local function verifyNativeBrushCatalogue()
    local w,h=love.graphics.getDimensions()
    local rect=Presets.layout(w,h)
    local previousTool=A.tool
    local previousTab=A.sideTab
    local previousBrushes=A.brushes
    local previousColor=A.color
    local previousStyle=A.brushStyle
    local previousDiameter=A.brushDiameter
    local previousOpacity=A.brushOpacity
    local previousStabilization=A.stabilization
    local previousSlot=A.selectedBrushCustom
    local previousDirty=A.dirty
    local originalPixels=Native.bytes(A.layerSession.composite)
    local originalHistory=A.layerSession:historyStats().undo
    local originalLayers=#A.doc.layers
    selectTool('brush')
    releaseBrushSamples()
    openBrushLibrary()
    love.draw()
    local cached=assert(A.brushSampleCache and A.brushSampleCache[3],
        'Brush window did not render native C++ swatches')
    local expected=Samples.render(Native,Presets.BUILTINS[3],A.color)
    assert(Native.bytes(cached.sample.buffer)==Native.bytes(expected.buffer),
        'Marker preview does not use native feather renderer')
    local first=assert(A.brushSampleCache[1])
    love.draw()
    assert(A.brushSampleCache[1]==first and A.brushSampleCache[3]==cached,
        'Brush window allocates new preview textures every frame')
    A.color=0x40c9aaff
    love.draw()
    assert(A.brushSampleCache[1]~=first and
        A.brushSampleCache[3]~=cached and
        A.brushSampleCache[3].key==Samples.key(
            Presets.BUILTINS[3],A.color),
        'Preview cache did not invalidate when RGBA color changed')
    local originalPresets=A.brushes
    local private=Presets.save({},Presets.BUILTINS[3])
    A.brushes=private
    love.draw()
    love.mousepressed(rect.x+609,rect.y+62,1,false)
    assert(A.brushFilter=='personal' and A.brushFocus==5,
        'Personal tab should focus only populated custom slots')
    love.keypressed('right')
    assert(A.brushFocus==5,
        'Keyboard navigation should skip unpopulated personal slots')
    love.draw()
    assert(A.brushSampleCache[5] and
        Native.bytes(A.brushSampleCache[5].sample.buffer)==
        Native.bytes(Samples.render(Native,private[1],A.color).buffer),
        'Custom stroke sample does not represent saved renderer settings')
    love.keypressed('return')
    assert(not A.brushLibrary and A.tool=='brush' and
        A.brushDiameter==24 and A.brushStyle=='soft' and
        A.selectedBrushCustom==1,
        'Enter did not apply keyboard-focused personal brush')
    A.brushes=originalPresets
    openBrushLibrary()
    love.keypressed('tab')
    assert(A.brushFilter=='builtin' and A.brushFocus and
        A.brushFocus<=4,'Tab must switch to built-in brushes')
    love.keypressed('right')
    assert(A.brushFocus==2,'Right arrow did not focus next built-in')
    love.keypressed('down')
    assert(A.brushFocus==4,'Down arrow did not follow two-column grid')
    love.keypressed('kpenter')
    assert(not A.brushLibrary and A.brushDiameter==48 and
        A.brushStyle=='soft' and math.abs(A.brushOpacity-.3)<1e-6,
        'Keypad Enter failed to apply focused preset')
    openBrushLibrary()
    love.keypressed('escape')
    assert(not A.brushLibrary,'Esc must close brush library')
    assert(Native.bytes(A.layerSession.composite)==originalPixels and
        A.layerSession:historyStats().undo==originalHistory and
        #A.doc.layers==originalLayers and A.dirty==previousDirty,
        'Native sample creation or keyboard input edited the document')
    A.brushes=previousBrushes;A.color=previousColor
    A.brushStyle=previousStyle;A.brushDiameter=previousDiameter
    A.brushOpacity=previousOpacity;A.stabilization=previousStabilization
    A.selectedBrushCustom=previousSlot
    A.brushFocus=nil
    releaseBrushSamples()
    selectTool(previousTool)
    A.sideTab=previousTab
end
-- Stage 35 regression: edit a live C++ brush inspector with pointer drags,
-- explicitly apply/cancel and prove no pixels or saved presets were touched.
local function verifyBrushLabLive()
    local w,h=love.graphics.getDimensions()
    local oldTool,oldTab=A.tool,A.sideTab
    local oldSize,oldStyle=A.brushDiameter,A.brushStyle
    local oldOpacity,oldStabilization=A.brushOpacity,A.stabilization
    local oldSlot,oldDirty=A.selectedBrushCustom,A.dirty
    local pixels=Native.bytes(A.layerSession.composite)
    local history=A.layerSession:historyStats().undo
    local count=#A.doc.layers
    local previousSaved=A.store:getBrushes()
    assert(not A.compactUi,'Brush inspector regression starts in desktop')
    selectTool('brush')
    releaseBrushSamples()
    openBrushLibrary()
    A.brushFocus=1
    brushLabFromFocus()
    love.draw()
    local rect=Presets.layout(w,h)
    local panel=Lab.layout(rect)
    local initial=assert(A.brushSampleCache.inspector,
        'Large native RGBA preview must be rendered on opening')
    assert(initial.key==Samples.key(A.brushLabDraft,A.color),
        'Initial live preview does not match chosen preset')
    local d=Lab.rail(rect,'diameter')
    love.mousepressed(d.x,d.y+7,1,false)
    assert(A.brushLabDrag=='diameter' and A.brushLabDraft.diameter==1,
        'Brush inspector must capture its own size slider')
    love.mousemoved(d.x+d.w/2,d.y+7,d.w/2,0,false)
    love.mousereleased(d.x+d.w/2,d.y+7,1,false)
    assert(A.brushLabDrag==nil and A.brushLabDraft.diameter==129,
        'Live diameter draft must support exact midpoint')
    local o=Lab.rail(rect,'opacity')
    love.draw()
    love.mousepressed(o.x+o.w/2,o.y+7,1,false)
    assert(A.brushLabDraft.opacity==.55 and
        A.brushLabDrag=='opacity','Opacity draft must support 55%')
    love.mousereleased(o.x+o.w/2,o.y+7,1,false)
    local stab=Lab.rail(rect,'stabilization')
    love.draw()
    love.mousepressed(stab.x+stab.w,stab.y+7,1,false)
    love.mousereleased(stab.x+stab.w,stab.y+7,1,false)
    assert(A.brushLabDraft.stabilization==5 and A.brushLabEdited,
        'Stabilizer and draft-modified indicator failed')
    love.draw()
    local updated=assert(A.brushSampleCache.inspector)
    assert(updated~=initial and
        updated.key==Samples.key(A.brushLabDraft,A.color),
        'Live C++ preview did not refresh after adjustments')
    local expected=Samples.render(Native,A.brushLabDraft,A.color)
    assert(Native.bytes(updated.sample.buffer)==
        Native.bytes(expected.buffer),
        'Large RGBA preview pixels diverged from native renderer')
    love.mousepressed(5,220,1,false)
    assert(A.brushLibrary and not A.drawing and
        A.brushLabDraft.diameter==129,
        'Click outside inspector leaked through into document')
    local builtIn=Presets.BUILTINS[1]
    assert(builtIn.diameter==3 and builtIn.opacity==1,
        'Editing draft must not mutate built-in brush')
    love.draw()
    love.mousepressed(panel.x+panel.w/2,
        panel.y+panel.h-20,1,false)
    assert(not A.brushLibrary and A.brushDiameter==129 and
        A.brushOpacity==.55 and A.stabilization==5 and
        A.selectedBrushCustom==nil,
        'Apply draft must update active brush without linking to saved slot')
    openBrushLibrary()
    love.draw()
    local again=Lab.rail(rect,'diameter')
    love.mousepressed(again.x,again.y+7,1,false)
    love.mousereleased(again.x,again.y+7,1,false)
    assert(A.brushLabDraft.diameter==1,
        'Cancel test did not edit draft independently')
    love.keypressed('escape')
    assert(not A.brushLibrary and A.brushDiameter==129,
        'Escape must discard unsaved draft adjustments')
    assert(Native.bytes(A.layerSession.composite)==pixels and
        A.layerSession:historyStats().undo==history and
        #A.doc.layers==count and A.dirty==oldDirty,
        'Inspector touched document pixels/history/layers/dirty')
    local now=A.store:getBrushes()
    assert(#now==#previousSaved,
        'Brush inspector changed stored library without save action')
    for i=1,#previousSaved do
        assert(now[i].id==previousSaved[i].id,
            'Saved brush identifiers changed unexpectedly')
    end
    A.brushDiameter=oldSize;A.brushStyle=oldStyle
    A.brushOpacity=oldOpacity;A.stabilization=oldStabilization
    A.selectedBrushCustom=oldSlot
    A.brushLabDrag=nil;A.brushLabDraft=nil
    releaseBrushSamples()
    selectTool(oldTool);A.sideTab=oldTab
end
-- Explicit CI-only visual capture mode. Every screenshot comes from the
-- real LÖVE draw callback using the same independent native C++ raster.
-- Never runs without --showcase-dir and does not touch normal user projects.
local function advanceShowcase()
    local sh=A.showcase
    sh.stage=sh.stage+1
    sh.frames=0;sh.pending=false;sh.captured=false
    if sh.stage==2 then
        local project=A.store:openProject(sh.projectId)
        openDoc(project)
        selectTool('brush')
        A.brushDiameter=24;A.brushOpacity=.70;A.brushStyle='soft'
        A.color=0xe17caaff
        A.compactUi=true
    elseif sh.stage==3 then
        openBrushLibrary()
        A.brushFocus=3
        brushLabFromFocus()
    elseif sh.stage==4 then
        A.brushLibrary=false
        openCompactColor()
    elseif sh.stage==5 then
        A.compactPanel='layers'
    elseif sh.stage==6 then
        A.compactPanel=nil
        A.compactUi=false
        fit()
    elseif sh.stage==7 then
        assert(love.window.setMode(960,640,{
            resizable=true,minwidth=960,minheight=640,vsync=0}),
            'Minimum viewport unavailable for screenshot')
        selectTool('brush')
        A.sideTab='brush'
        A.sidebarScroll=Sidebar.max(640)
        fit()
        status('Painel lateral 960x640 · rolagem independente')
    elseif sh.stage==8 then
        assert(love.window.setMode(1220,800,{
            resizable=true,minwidth=960,minheight=640,vsync=0}),
            'Could not restore 1220x800 for compact inspector preview')
        A.compactUi=true
        A.compactPanel='properties'
        A.brushStyle='soft'
        A.brushDiameter=44
        A.brushOpacity=.55
        A.color=0x34aaf7ff
        selectTool('brush')
        fit()
        status('Ajustes compactos · prévia nativa de pincel C++')
    elseif sh.stage==9 then
        if #A.doc.layers==1 then
            A.layerSession:add('Destaques')
            A.layerSession:beginEdit()
            A.layerSession:stroke(70,120,410,370,30,0xeaa346ff,1)
            A.layerSession:finishEdit()
            A.dirty=true;rebuildImage()
        end
        A.layerSession:setOpacity(A.doc.active_layer,.37)
        A.dirty=true;rebuildImage()
        A.compactPanel='layers'
        A.compactLayerOpacityDrag=nil
        status('Camadas · opacidade precisa de 37%')
    elseif sh.stage>#showcaseNames then
        externalWrite(sh.directory..'/showcase-report.json',
            JSON.encode({ok=true,real_love_render=true,
                native_cpp=Native.available,
                screenshots=showcaseNames,
                android_1412_pixel_parity=false}))
        A.showcase=nil
        love.event.quit(0)
    end
end
-- Stage 39: real 960x640 LÖVE resize, scrollbar, independent sliders
-- and proof the canvas/history never change when navigating the sidebar.
local function verifyAdaptiveDesktopSidebar()
    local oldW,oldH=love.graphics.getDimensions()
    local previousTool,previousTab=A.tool,A.sideTab
    local previousStabilization=A.stabilization
    local previousDirty=A.dirty
    local before=Native.bytes(A.layerSession.composite)
    local history=A.layerSession:historyStats().undo
    local layers=#A.doc.layers
    assert(not A.compactUi and not A.focusMode,
        'Small sidebar regression needs desktop editor')
    local changed=love.window.setMode(960,640,{
        resizable=true,minwidth=960,minheight=640,vsync=0})
    assert(changed,'Cannot create minimum Windows LÖVE viewport')
    local w,h=love.graphics.getDimensions()
    assert(w==960 and h==640,'Minimum viewport must be exact')
    assert(selectTool('brush'),'Brush panel unavailable at 960x640')
    A.sideTab='brush'
    A.sidebarScroll=0
    love.draw()
    local panel=w-Sidebar.WIDTH
    local slider=Sliders.rail('stabilization',panel)
    assert(slider.y>h-48,'Regression setup: last slider already visible')
    for _=1,4 do
        love.draw()
        love.mousepressed(w-11,h-62,1,false)
    end
    assert(A.sidebarScroll==160,'Sidebar bottom arrow did not reach end')
    love.draw()
    for _,b in ipairs(A.buttons) do
        if b.x>=panel and b.x<w then
            assert(b.y>=64 and b.y+b.h<=h-48,
                'Sidebar button escaped clipped viewport')
        end
    end
    local sliderY=slider.y-A.sidebarScroll+slider.h/2
    assert(sliderY>=64 and sliderY<h-48,
        'Stabilization slider still inaccessible at 640px height')
    love.mousepressed(slider.x+slider.w,sliderY,1,false)
    assert(A.sliderDrag=='stabilization' and A.stabilization==5,
        'Scrolled slider click did not reach original value/hitbox')
    love.mousereleased(slider.x+slider.w,sliderY,1,false)
    assert(A.sliderDrag==nil,'Slider drag failed to release')
    love.draw()
    love.mousepressed(w-11,77,1,false)
    assert(A.sidebarScroll==116,'Scroll up arrow did not work')
    love.draw()
    assert(Native.bytes(A.layerSession.composite)==before and
        A.layerSession:historyStats().undo==history and
        #A.doc.layers==layers and A.dirty==previousDirty,
        'Sidebar navigation or parameter preview painted on canvas')
    assert(love.window.setMode(oldW,oldH,{
        resizable=true,minwidth=960,minheight=640,vsync=0}),
        'Failed to restore original Windows GUI size')
    A.sidebarScroll=0
    A.stabilization=previousStabilization
    selectTool(previousTool);A.sideTab=previousTab
    love.draw()
    assert(love.graphics.getWidth()==oldW and
        love.graphics.getHeight()==oldH,
        'GUI resolution not restored after small viewport test')
end
-- Stage 40: actual compact properties popup and native C++ swatch.
-- Exercise the same existing mouse buttons without any document edits.
local function verifyCompactNativeInspector()
    local w,h=love.graphics.getDimensions()
    local oldTool,oldTab=A.tool,A.sideTab
    local oldStyle,oldDiameter=A.brushStyle,A.brushDiameter
    local oldOpacity,oldStabilization=A.brushOpacity,A.stabilization
    local oldDirty=A.dirty
    local bytes=Native.bytes(A.layerSession.composite)
    local undo=A.layerSession:historyStats().undo
    local layers=#A.doc.layers
    assert(not A.compactUi,'Compact inspector test begins in desktop mode')
    selectTool('brush')
    A.brushStyle='hard';A.brushDiameter=24;A.brushOpacity=.8
    love.draw()
    love.mousepressed(w-595,30,1,false)
    assert(A.compactUi,'Compact toolbar toggle failed')
    local dock=Compact.toolbar(w,h)
    love.draw()
    love.mousepressed(dock[3].x+dock[3].w/2,
        dock[3].y+dock[3].h/2,1,false)
    assert(A.compactPanel=='properties','Properties popup not opened')
    local p=Compact.popup(w,h,'properties')
    love.draw()
    local first=assert(A.brushSampleCache and
        A.brushSampleCache.compact_preview,
        'Native brush swatch not rendered in compact inspector')
    assert(first.key==Samples.key(Inspector.settings(A),A.color),
        'Compact swatch does not reflect currently active C++ brush')
    love.mousepressed(p.x+17+73+25,p.y+54+29+15,1,false)
    assert(A.brushDiameter==26,'Compact diameter adjustment broke')
    love.draw()
    local second=assert(A.brushSampleCache.compact_preview)
    assert(second.key~=first.key and
        second.key==Samples.key(Inspector.settings(A),A.color),
        'Diameter change did not invalidate C++ preview cache')
    love.mousepressed(p.x+17+30,p.y+54+109+15,1,false)
    assert(math.abs(A.brushOpacity-.7)<1e-8,
        'Opacity popup action not applied to active brush')
    love.draw()
    local third=assert(A.brushSampleCache.compact_preview)
    assert(third.key~=second.key,
        'Opacity change failed to update preview cache')
    love.mousepressed(p.x+17+146+42,p.y+54+68+16,1,false)
    assert(A.brushStyle=='soft','Soft brush button stopped working')
    love.draw()
    local fourth=assert(A.brushSampleCache.compact_preview)
    local reference=Samples.render(Native,Inspector.settings(A),A.color)
    assert(fourth.key~=third.key and
        Native.bytes(fourth.sample.buffer)==Native.bytes(reference.buffer),
        'Native preview pixels do not match current brush style and color')
    love.mousepressed(p.x+110,p.y+p.h-35,1,false)
    assert(A.brushLibrary and not A.compactPanel,
        'Brush library did not open from compact properties')
    love.keypressed('escape')
    assert(not A.brushLibrary and not A.drawing,
        'Escape should dismiss brush library without a stroke')
    assert(Native.bytes(A.layerSession.composite)==bytes and
        A.layerSession:historyStats().undo==undo and
        #A.doc.layers==layers and A.dirty==oldDirty,
        'Live brush preview or popup adjustments edited the document')
    love.draw()
    love.mousepressed(w-595,30,1,false)
    assert(not A.compactUi,'Failed to return to desktop')
    A.brushStyle=oldStyle;A.brushDiameter=oldDiameter
    A.brushOpacity=oldOpacity;A.stabilization=oldStabilization
    selectTool(oldTool);A.sideTab=oldTab
    releaseBrushSamples()
end
-- Stage 41: drag at 1% resolution, then confirm ONE undo entry,
-- even after multiple pointer movements. Preview must not edit raster.
-- Stage 41: actual compact panel wheel navigation at minimum Windows size.
-- Check the list moves while project pixels, selection, zoom and undo do not.
local function verifyCompactLayerWheel()
    local previousW,previousH=love.graphics.getDimensions()
    local previousTool,previousTab=A.tool,A.sideTab
    local previousStart=A.compactLayerStart
    local previousScroll=A.sidebarScroll
    local previousDirty=A.dirty
    local selected=A.doc.active_layer
    local pixels=Native.bytes(A.layerSession.composite)
    local history=A.layerSession:historyStats().undo
    assert(not A.compactUi and not A.focusMode and
        A.screen=='editor','Compact wheel test needs desktop editor')
    assert(love.window.setMode(960,640,{
        resizable=true,minwidth=960,minheight=640,vsync=0}),
        'Cannot enter 960x640 for compact layer wheel test')
    toggleCompactUi()
    A.compactPanel='layers'
    A.compactLayerStart=1
    love.draw()
    local zoomAtPopup=A.zoom
    local w,h=love.graphics.getDimensions()
    local popup=Compact.popup(w,h,'layers')
    local px,py=popup.x+60,popup.y+101
    assert(CompactLayerWheel.hit(w,h,px,py,#A.doc.layers),
        'Layer wheel row must be reachable in minimum popup')
    local originalMouse=love.mouse.getPosition
    love.mouse.getPosition=function()return px,py end
    love.wheelmoved(0,1)
    love.mouse.getPosition=originalMouse
    local _,_,maximum=Thumbnails.window(#A.doc.layers,
        A.doc.active_layer,Compact.layerRows(popup),1)
    assert(A.compactLayerStart==math.min(2,maximum),
        'Wheel must move only the compact list')
    love.draw()
    love.mouse.getPosition=function()return px,py end
    love.wheelmoved(0,-1)
    love.mouse.getPosition=originalMouse
    assert(A.compactLayerStart==1,'Reverse wheel must restore first row')
    assert(A.doc.active_layer==selected and
        A.layerSession:historyStats().undo==history and
        Native.bytes(A.layerSession.composite)==pixels and
        A.dirty==previousDirty and A.zoom==zoomAtPopup,
        'Wheel must never edit pixels, selection, zoom or history')
    A.compactPanel=nil
    toggleCompactUi()
    assert(love.window.setMode(previousW,previousH,{
        resizable=true,minwidth=960,minheight=640,vsync=0}),
        'Failed to restore desktop resolution after wheel test')
    selectTool(previousTool)
    A.sideTab=previousTab
    A.sidebarScroll=Sidebar.clamp(previousH,previousScroll or 0)
    A.compactLayerStart=previousStart
    love.draw()
end
local function verifyCompactLayerOpacity()
    local w,h=love.graphics.getDimensions()
    assert(not A.compactUi and not A.focusMode,
        'Opacity GUI regression must begin in desktop mode')
    local previousTool,previousTab=A.tool,A.sideTab
    local previousDirty=A.dirty
    local previousStart=A.compactLayerStart
    local layerIndex=A.doc.active_layer
    local initial=A.doc.layers[layerIndex].opacity
    local bytes=Native.bytes(A.layerSession.composite)
    local layers=#A.doc.layers
    local oldHistory=A.layerSession:historyStats().undo
    love.draw()
    love.mousepressed(w-595,30,1,false)
    assert(A.compactUi,'Compact mode unavailable')
    local dock=Compact.toolbar(w,h)
    love.draw()
    love.mousepressed(dock[6].x+dock[6].w/2,
        dock[6].y+dock[6].h/2,1,false)
    assert(A.compactPanel=='layers','Compact layers popup failed')
    local p=Compact.popup(w,h,'layers')
    local rail=LayerOpacity.rect(p)
    love.draw()
    love.mousepressed(rail.x,rail.y+6,1,false)
    assert(A.compactLayerOpacityDrag and
        A.compactLayerOpacityDrag.index==layerIndex,
        'Opacity pointer must own the selected layer')
    love.mousemoved(rail.x+rail.w*.2,rail.y+6,18,0,false)
    love.mousemoved(rail.x+rail.w*.8,rail.y+6,18,0,false)
    love.mousemoved(rail.x+rail.w*.37,rail.y+6,-18,0,false)
    love.draw()
    assert(A.compactLayerOpacityDrag.value==.37 and
        A.doc.layers[layerIndex].opacity==initial and
        A.layerSession:historyStats().undo==oldHistory and
        Native.bytes(A.layerSession.composite)==bytes,
        'Draft preview wrote pixels, metadata or history before release')
    love.mousereleased(rail.x+rail.w*.37,rail.y+6,1,false)
    assert(not A.compactLayerOpacityDrag and
        A.doc.layers[layerIndex].opacity==.37,
        'Mouse release must commit exact 37%')
    local entry=A.layerSession.undoStack[#A.layerSession.undoStack]
    assert(entry and entry.kind=='property' and
        entry.field=='opacity' and entry.before==initial and
        entry.after==.37,
        'Opacity drag must be one stable, undoable metadata edit')
    assert(A.layerSession:undo() and
        A.doc.layers[layerIndex].opacity==initial,
        'Undo did not restore original layer opacity')
    assert(Native.bytes(A.layerSession.composite)==bytes,
        'Undo must exactly restore original C++ RGBA composite')
    assert(A.layerSession:redo() and
        A.doc.layers[layerIndex].opacity==.37,
        'Redo did not reapply 37 percent')
    assert(A.layerSession:undo() and
        A.doc.layers[layerIndex].opacity==initial,
        'Final cleanup did not restore original opacity')
    rebuildImage()
    love.keypressed('escape')
    assert(not A.compactPanel and not A.compactLayerOpacityDrag,
        'Escape must close layers popup and release slider')
    love.draw()
    love.mousepressed(w-595,30,1,false)
    assert(not A.compactUi,'Failed to restore desktop editor')
    assert(Native.bytes(A.layerSession.composite)==bytes and
        #A.doc.layers==layers,
        'Opacity GUI test left a modified drawing or layer structure')
    A.dirty=previousDirty
    A.compactLayerStart=previousStart
    selectTool(previousTool)
    A.sideTab=previousTab
end
-- Real Windows GUI regression: the classic rail operates within the
-- scrolled 960x640 panel and creates one property-undo step on release.
local function verifyDesktopLayerOpacity()
    local oldW,oldH=love.graphics.getDimensions()
    local oldTool,oldTab=A.tool,A.sideTab
    local oldScroll,oldDirty=A.sidebarScroll,A.dirty
    local index=A.doc.active_layer
    local initial=A.doc.layers[index].opacity
    local initialBytes=Native.bytes(A.layerSession.composite)
    local oldUndo=A.layerSession:historyStats().undo
    assert(not A.compactUi and not A.focusMode,
        'Desktop opacity regression requires classic editor')
    assert(love.window.setMode(960,640,{
        resizable=true,minwidth=960,minheight=640,vsync=0}),
        'Cannot resize for desktop layer opacity test')
    selectTool('brush')
    A.sideTab='layers'
    A.sidebarScroll=Sidebar.max(640)
    love.draw()
    local w,h=love.graphics.getDimensions()
    local rail=DesktopOpacity.rect(w,h)
    local y=rail.y-A.sidebarScroll+rail.h/2
    local target=initial==.37 and .41 or .37
    assert(DesktopOpacity.hit(w,h,rail.x+rail.w*.5,y,A.sidebarScroll),
        'Opacity rail must be reachable in scrolled 960x640 panel')
    love.mousepressed(rail.x,y,1,false)
    assert(A.desktopLayerOpacityDrag and
        A.desktopLayerOpacityDrag.index==index,
        'Desktop rail must capture selected layer')
    love.mousemoved(rail.x+rail.w*.81,y,20,0,false)
    love.mousemoved(rail.x+rail.w*target,y,-15,0,false)
    love.draw()
    assert(A.desktopLayerOpacityDrag.value==target and
        A.doc.layers[index].opacity==initial and
        A.layerSession:historyStats().undo==oldUndo and
        Native.bytes(A.layerSession.composite)==initialBytes,
        'Preview drag cannot modify pixels or history')
    love.mousereleased(rail.x+rail.w*target,y,1,false)
    assert(not A.desktopLayerOpacityDrag and
        A.doc.layers[index].opacity==target and
        A.layerSession:historyStats().undo<=oldUndo+1,
        'Release may create only one undo entry')
    local entry=A.layerSession.undoStack[#A.layerSession.undoStack]
    assert(entry and entry.kind=='property' and
        entry.field=='opacity' and entry.before==initial and
        entry.after==target,'Metadata undo entry must match drag')
    assert(A.layerSession:undo() and
        A.doc.layers[index].opacity==initial and
        Native.bytes(A.layerSession.composite)==initialBytes,
        'Opacity undo must exactly restore C++ composite')
    assert(A.layerSession:redo() and
        A.doc.layers[index].opacity==target,
        'Opacity redo must reapply the chosen percentage')
    assert(A.layerSession:undo() and
        A.doc.layers[index].opacity==initial,
        'Opacity regression cleanup must restore initial value')
    rebuildImage()
    assert(love.window.setMode(oldW,oldH,{
        resizable=true,minwidth=960,minheight=640,vsync=0}),
        'Cannot restore viewport after desktop opacity test')
    selectTool(oldTool);A.sideTab=oldTab
    A.sidebarScroll=Sidebar.clamp(oldH,oldScroll or 0)
    A.dirty=oldDirty
    love.draw()
    assert(Native.bytes(A.layerSession.composite)==initialBytes,
        'Desktop opacity test changed the drawing')
end
-- Real LÖVE regression for independent layer-list wheel scrolling.
-- Tests the minimum viewport without changing selected layers or raster.
local function verifyLayerListWheel()
    local oldW,oldH=love.graphics.getDimensions()
    local oldTool,oldTab=A.tool,A.sideTab
    local oldScroll,oldStart=A.sidebarScroll,A.layerScroll
    local oldDirty=A.dirty
    local selected=A.doc.active_layer
    local before=Native.bytes(A.layerSession.composite)
    local undo=A.layerSession:historyStats().undo
    assert(not A.compactUi and not A.focusMode and #A.doc.layers>1,
        'Layer wheel regression requires multiple classic desktop layers')
    assert(love.window.setMode(960,640,{
        resizable=true,minwidth=960,minheight=640,vsync=0}),
        'Layer wheel test could not enter 960x640 viewport')
    selectTool('brush')
    A.sideTab='layers'
    A.sidebarScroll=Sidebar.max(640)
    A.layerScroll=1
    love.draw()
    local width,height=love.graphics.getDimensions()
    local originalMousePosition=love.mouse.getPosition
    local pointerX=width-Sidebar.WIDTH+110
    local pointerY=LayerListWheel.TOP-A.sidebarScroll+16
    love.mouse.getPosition=function()return pointerX,pointerY end
    assert(LayerListWheel.hit(width,height,pointerX,pointerY,A.sidebarScroll),
        'Layer list is not visible in 960x640')
    love.wheelmoved(0,1)
    assert(A.layerScroll==2 and A.sidebarScroll==160 and
        A.doc.active_layer==selected,
        'List wheel must change list start, not panel or selection')
    love.draw()
    love.wheelmoved(0,-1)
    assert(A.layerScroll==1,'Reverse wheel did not restore list start')
    pointerY=431-A.sidebarScroll+15
    love.wheelmoved(0,1)
    assert(A.sidebarScroll==120 and A.layerScroll==1 and
        A.doc.active_layer==selected,
        'Wheel over action controls must scroll only the outer panel')
    love.mouse.getPosition=originalMousePosition
    assert(Native.bytes(A.layerSession.composite)==before and
        A.layerSession:historyStats().undo==undo and
        A.dirty==oldDirty,
        'List navigation must not modify canvas, undo or dirty flag')
    assert(love.window.setMode(oldW,oldH,{
        resizable=true,minwidth=960,minheight=640,vsync=0}),
        'Could not restore viewport after layer wheel regression')
    selectTool(oldTool)
    A.sideTab=oldTab
    A.sidebarScroll=Sidebar.clamp(oldH,oldScroll or 0)
    A.layerScroll=oldStart
    love.draw()
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
        elseif args[i]=='--showcase-dir' then options.showcaseDir=args[i+1]
        elseif args[i]=='--lua-test' then options.luaTest=true
        elseif args[i]=='--self-test' then options.selfTest=true end
    end
    A.options=options;local base=love.filesystem.getSourceBaseDirectory()
    package.path=base..'/?.lua;'..base..'/?/init.lua;'..package.path
    Native.load(base)
    A.inkAttached=Ink.init(Native)
    A.root=options.data or (base..'/user-data');A.store=Store.open(A.root)
    A.preferences=A.store:getPreferences() or {};A.brushes=A.store:getBrushes() or {}
    A.savedColors={}
    if type(A.preferences.colorPalette)=='table' then
        for _,v in ipairs(A.preferences.colorPalette) do
            if #A.savedColors>=ColorPanel.PALETTE_LIMIT then break end
            if pcall(Colors.channels,v) then
                A.savedColors[#A.savedColors+1]=v
            end
        end
    end
    A.colorHistory={}
    refreshGallery();status(Native.available and 'Motor C++ v1 carregado' or 'Galeria disponível · motor C++ ainda não compilado')
    if options.showcaseDir then
        assert(Native.available,'Visual showcase requires the real native C++ DLL')
        assert(not options.selfTest and not options.luaTest,
            'Showcase must not share the isolated test modes')
        -- Paint before the gallery capture so its thumbnail depicts the
        -- actual project, not a generic placeholder or an empty canvas.
        local sample=Native.buffer(512,512)
        Native.clear(sample,0)
        Native.featherStroke(sample,92,378,431,166,54,
            0x2391e8ff,.62,.25)
        Native.featherStroke(sample,93,240,425,358,46,
            0xe17caaff,.64,.25)
        Native.basicStroke(sample,112,355,402,178,16,
            0x2734aaff,1)
        Native.basicStroke(sample,96,185,395,318,11,
            0xffc15aff,1)
        Native.basicStroke(sample,132,430,392,421,13,
            0x24bd90ff,1)
        local demo=A.store:createProject('Demonstração de pincéis',
            512,512,'',Native.bytes(sample))
        refreshGallery()
        A.showcase={directory=options.showcaseDir,projectId=demo.id,
            stage=1,frames=0,pending=false,captured=false}
        status('Captura real de UI · galeria, editor, pincéis, cores, camadas')
    end
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
    if A.showcase then
        local sh=A.showcase
        if sh.error then
            externalWrite(sh.directory..'/showcase-report.json',
                JSON.encode({ok=false,error=sh.error,stage=sh.stage}))
            A.showcase=nil
            love.event.quit(2)
        elseif sh.captured then
            advanceShowcase()
        else
            sh.frames=sh.frames+1
            if sh.frames>300 then
                sh.error='Capture timed out at stage '..sh.stage
            end
        end
    end
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
                love.mousepressed(panel+210,448,1)
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
                assert(A.layerSession:historyStats().undo==
                    math.min(Layers.MAX_HISTORY_ENTRIES,historyTilt+1) and
                    A.layerSession.undoStack[#A.layerSession.undoStack].kind=='raster',
                    'Pincel inclinado não criou uma operação de pintura válida')
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
                    and A.layerSession:historyStats().undo==historyBeforeRename+1,
                    'Renomear camada deve criar histórico sem modificar pixels')
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
                -- Stage 19: real panel duplicate, new C++ pixel allocation,
                -- independent edits/undo, new ID, RBD2, and capacity guard.
                love.draw();love.mousepressed(panel+211,448,1,false)
                assert(#A.doc.layers==Store.MAX_LAYERS-1,
                    'Excluir não liberou uma vaga para duplicação')
                local sourceIndex=A.doc.active_layer
                A.layerSession:setVisible(sourceIndex,true)
                A.layerSession:setOpacity(sourceIndex,.65)
                A.layerSession:beginEdit()
                A.layerSession:pixel(4,4,0xe53b44ab)
                assert(A.layerSession:finishEdit(),
                    'Marca de origem não criou histórico raster')
                A.dirty=true;rebuildImage()
                local beforeCopyHistory=A.layerSession:historyStats().undo
                local originalId=A.doc.layers[sourceIndex].id
                local originalName=A.doc.layers[sourceIndex].name
                local originalPixels=Native.bytes(A.layerSession.buffers[sourceIndex])
                local originalThumb=layerThumb(sourceIndex)
                assert(beforeCopyHistory>0,'Teste requer um histórico anterior')
                love.draw();love.mousepressed(panel+132,448,1,false)
                local duplicateIndex=sourceIndex+1
                assert(#A.doc.layers==Store.MAX_LAYERS and
                    A.doc.active_layer==duplicateIndex,
                    'Duplicar não selecionou cópia acima da origem')
                assert(A.doc.layers[duplicateIndex].id~=originalId and
                    A.doc.layers[sourceIndex].id==originalId,
                    'Duplicar reutilizou o identificador da origem')
                assert(A.doc.layers[duplicateIndex].name==
                    'Cópia de '..originalName,
                    'Nome da cópia está incorreto')
                assert(A.doc.layers[duplicateIndex].opacity==.65 and
                    A.doc.layers[duplicateIndex].visible,
                    'Cópia não preservou visibilidade e opacidade')
                assert(Native.bytes(A.layerSession.buffers[duplicateIndex])==
                    originalPixels and
                    Native.bytes(A.layerSession.buffers[sourceIndex])==originalPixels,
                    'Cópia não começou com pixels idênticos à origem')
                assert(layerThumb(sourceIndex)==originalThumb and
                    layerThumb(duplicateIndex)~=originalThumb,
                    'A cópia não recebeu miniatura própria')
                assert(Thumbnails.sample(A.layerSession.buffers[sourceIndex])==
                    Thumbnails.sample(A.layerSession.buffers[duplicateIndex]),
                    'Miniatura da cópia tem pixels diferentes da origem')
                assert(A.layerSession:historyStats().undo==beforeCopyHistory+1,
                    'Duplicar não foi registrado como passo reversível')
                A.layerSession:beginEdit()
                A.layerSession:pixel(2,2,0x113355ff)
                assert(A.layerSession:finishEdit(),
                    'Editar a nova camada não criou histórico')
                A.dirty=true;rebuildImage()
                assert(Native.readPixel(A.layerSession.buffers[sourceIndex],2,2)~=
                    0x113355ff,
                    'Editar a cópia alterou pixels da origem')
                undoDoc()
                assert(Native.bytes(A.layerSession.buffers[duplicateIndex])==
                    originalPixels,'Desfazer na cópia não restaurou pixels iniciais')
                redoDoc()
                assert(Native.readPixel(A.layerSession.buffers[duplicateIndex],2,2)==
                    0x113355ff,'Refazer na cópia perdeu os pixels')
                local copyAfterEdit=Native.bytes(A.layerSession.buffers[duplicateIndex])
                love.draw();love.mousepressed(panel+132,448,1,false)
                assert(#A.doc.layers==Store.MAX_LAYERS and
                    Native.bytes(A.layerSession.buffers[duplicateIndex])==copyAfterEdit,
                    'Botão Duplicar não respeitou o limite de oito camadas')
                saveDoc()
                local duplicatedSaved=A.store:openProject(A.doc.id)
                assert(duplicatedSaved.format==2 and
                    duplicatedSaved.layer_count==Store.MAX_LAYERS and
                    duplicatedSaved.layers[sourceIndex].pixels==originalPixels and
                    duplicatedSaved.layers[duplicateIndex].pixels==copyAfterEdit and
                    duplicatedSaved.layers[sourceIndex].id==originalId and
                    duplicatedSaved.layers[duplicateIndex].id~=originalId,
                    'RBD2 não preservou duas camadas independentes')
                -- Make room again, then exercise the actual Ctrl+J handler.
                love.draw();love.mousepressed(panel+211,448,1,false)
                assert(#A.doc.layers==Store.MAX_LAYERS-1,
                    'Excluir cópia não liberou vaga para atalho')
                local control=love.keyboard.isDown
                love.keyboard.isDown=function(...)
                    for i=1,select('#',...) do
                        if select(i,...)=='lctrl' then return true end
                    end
                    return control(...)
                end
                love.keypressed('j')
                love.keyboard.isDown=control
                assert(#A.doc.layers==Store.MAX_LAYERS and
                    A.doc.active_layer==sourceIndex+1,
                    'Ctrl+J não duplicou a camada ativa')
                -- Stage 20: undo and redo actual structural operations
                -- via the same editor commands used for raster painting.
                local lastId=A.doc.layers[A.doc.active_layer].id
                local originalIdAfterCopy=A.doc.layers[sourceIndex].id
                local originalAtSource=Native.bytes(A.layerSession.buffers[sourceIndex])
                local beforeStructural=A.layerSession:historyStats().undo
                assert(beforeStructural>=2,
                    'Historical painting and duplicate must share timeline')
                undoDoc()
                assert(#A.doc.layers==Store.MAX_LAYERS-1 and
                    A.doc.active_layer==sourceIndex and
                    A.doc.layers[sourceIndex].id==originalIdAfterCopy,
                    'Desfazer Ctrl+J não removeu apenas a cópia')
                assert(A.layerSession:canRedo(),
                    'Duplicação desfeita não entrou no histórico de refazer')
                assert(Native.bytes(A.layerSession.buffers[sourceIndex])==
                    originalAtSource,'Desfazer cópia alterou original')
                redoDoc()
                assert(#A.doc.layers==Store.MAX_LAYERS and
                    A.doc.layers[sourceIndex+1].id==lastId,
                    'Refazer Ctrl+J não recuperou o mesmo ID de camada')
                assert(layerThumb(sourceIndex+1)~=nil and
                    layerThumb(sourceIndex)~=nil,
                    'Histórico estrutural não recuperou miniaturas')
                love.draw();love.mousepressed(panel+214,448,1,false)
                assert(#A.doc.layers==Store.MAX_LAYERS-1,
                    'Excluir no novo histórico falhou')
                local afterRemove=A.layerSession:historyStats().undo
                undoDoc()
                assert(#A.doc.layers==Store.MAX_LAYERS and
                    A.doc.layers[sourceIndex+1].id==lastId,
                    'Desfazer Excluir não restaurou identidade')
                assert(A.layerSession:historyStats().undo==afterRemove-1,
                    'Desfazer Excluir não avançou um passo')
                redoDoc()
                assert(#A.doc.layers==Store.MAX_LAYERS-1,
                    'Refazer Excluir não removeu camada novamente')
                undoDoc()
                assert(#A.doc.layers==Store.MAX_LAYERS and
                    A.doc.layers[sourceIndex+1].id==lastId,
                    'Desfazer depois de refazer Excluir falhou')
                local finalCount=A.layerSession:historyStats().undo
                local lastLayer=A.doc.active_layer
                A.layerSession:move(lastLayer,lastLayer-1)
                A.dirty=true;rebuildImage()
                assert(A.layerSession:historyStats().undo==finalCount+1,
                    'Mover não entrou na linha do tempo')
                local movedId=A.doc.layers[lastLayer-1].id
                undoDoc()
                assert(A.doc.layers[lastLayer].id==movedId,
                    'Desfazer movimentação não restaurou ordem')
                redoDoc()
                assert(A.doc.layers[lastLayer-1].id==movedId,
                    'Refazer movimentação não recuperou ordem')
                saveDoc()
                local mixedSaved=A.store:openProject(A.doc.id)
                assert(mixedSaved.layers[lastLayer-1].id==movedId and
                    mixedSaved.layer_count==Store.MAX_LAYERS,
                    'RBD2 não preservou a estrutura após desfazer/refazer')
                -- Stage 21: real modal and panel properties participate in
                -- the same undo/redo stack as raster and structural edits.
                local metaIndex=A.doc.active_layer
                local metaId=A.doc.layers[metaIndex].id
                local previousName=A.doc.layers[metaIndex].name
                local metaPixels=Native.bytes(A.layerSession:activeBuffer())
                love.keypressed('f2')
                assert(A.modal and A.modal.kind=='renameLayer',
                    'F2 não abriu renomeio no histórico de propriedades')
                A.modal.values[1]='Camada histórica 21'
                love.keypressed('return')
                assert(A.doc.layers[metaIndex].name=='Camada histórica 21' and
                    not A.modal,'Editar nome não registrou alteração')
                local entry=A.layerSession.undoStack[#A.layerSession.undoStack]
                assert(entry and entry.kind=='property' and entry.field=='name',
                    'Renomear não criou etapa reversível')
                undoDoc()
                assert(A.doc.layers[metaIndex].name==previousName,
                    'Ctrl+Z não restaurou nome da camada')
                redoDoc()
                assert(A.doc.layers[metaIndex].name=='Camada histórica 21',
                    'Ctrl+Y não refez nome da camada')
                local wasVisible=A.doc.layers[metaIndex].visible
                love.draw()
                love.mousepressed(panel+70,screenH-116,1,false)
                assert(A.doc.layers[metaIndex].visible~=wasVisible,
                    'Botão Ocultar/Mostrar não registrou visibilidade')
                undoDoc()
                assert(A.doc.layers[metaIndex].visible==wasVisible,
                    'Desfazer visibilidade não restaurou estado')
                redoDoc()
                assert(A.doc.layers[metaIndex].visible~=wasVisible,
                    'Refazer visibilidade falhou')
                local priorOpacity=A.doc.layers[metaIndex].opacity
                love.draw()
                love.mousepressed(panel+40,screenH-79,1,false)
                local loweredOpacity=A.doc.layers[metaIndex].opacity
                assert(loweredOpacity<priorOpacity,
                    'Controle − de opacidade não modificou camada')
                undoDoc()
                assert(math.abs(A.doc.layers[metaIndex].opacity-priorOpacity)<1e-5,
                    'Desfazer opacidade não restaurou valor original')
                redoDoc()
                assert(math.abs(A.doc.layers[metaIndex].opacity-loweredOpacity)<1e-5,
                    'Refazer opacidade não recuperou valor')
                assert(A.doc.layers[metaIndex].id==metaId and
                    Native.bytes(A.layerSession:activeBuffer())==metaPixels,
                    'Histórico de propriedades alterou ID ou raster original')
                saveDoc()
                local propertiesSaved=A.store:openProject(A.doc.id)
                assert(propertiesSaved.layers[metaIndex].id==metaId and
                    propertiesSaved.layers[metaIndex].name=='Camada histórica 21'
                    and propertiesSaved.layers[metaIndex].visible~=wasVisible
                    and math.abs(propertiesSaved.layers[metaIndex].opacity-
                        loweredOpacity)<1e-5 and
                    propertiesSaved.layers[metaIndex].pixels==metaPixels,
                    'RBD2 não preservou propriedades reversíveis da camada')
                -- Stage 22: merge via the real editor button, undo original
                -- layers and verify deterministic redo and persistent RGBA.
                local mergeIndex=A.doc.active_layer
                assert(A.sideTab=='layers' and mergeIndex>2,
                    'Mesclar precisa de uma camada acima de duas outras')
                local countBefore=#A.doc.layers
                local lowerId=A.doc.layers[mergeIndex-1].id
                local upperId=A.doc.layers[mergeIndex].id
                local originalLower=Native.bytes(A.layerSession.buffers[mergeIndex-1])
                local originalUpper=Native.bytes(A.layerSession.buffers[mergeIndex])
                local historyBefore=A.layerSession:historyStats().undo
                love.draw()
                love.mousepressed(panel+190,344,1,false)
                assert(#A.doc.layers==countBefore-1 and
                    A.doc.active_layer==mergeIndex-1 and
                    A.doc.layers[mergeIndex-1].id==lowerId,
                    'Botão Mesclar abaixo não funcionou')
                local mergedPixels=Native.bytes(A.layerSession.buffers[mergeIndex-1])
                assert(A.layerSession:historyStats().undo==historyBefore+1,
                    'Mesclar não criou exatamente uma etapa de histórico')
                undoDoc()
                assert(#A.doc.layers==countBefore and
                    A.doc.layers[mergeIndex-1].id==lowerId and
                    A.doc.layers[mergeIndex].id==upperId and
                    Native.bytes(A.layerSession.buffers[mergeIndex-1])==originalLower and
                    Native.bytes(A.layerSession.buffers[mergeIndex])==originalUpper,
                    'Desfazer Mesclar não recuperou os pixels/IDs originais')
                assert(layerThumb(mergeIndex)~=nil,
                    'Miniatura da camada restaurada não reapareceu')
                redoDoc()
                assert(#A.doc.layers==countBefore-1 and
                    Native.bytes(A.layerSession.buffers[mergeIndex-1])==mergedPixels,
                    'Refazer Mesclar não reproduziu o resultado C++')
                saveDoc()
                local mergedSave=A.store:openProject(A.doc.id)
                assert(mergedSave.layer_count==countBefore-1 and
                    mergedSave.layers[mergeIndex-1].pixels==mergedPixels and
                    mergedSave.layers[mergeIndex-1].id==lowerId,
                    'RBD2 não persistiu resultado Mesclar abaixo')
                local originalIsDown=love.keyboard.isDown
                love.keyboard.isDown=function(...)
                    for j=1,select('#',...) do
                        if select(j,...)=='lctrl' then return true end
                    end
                    return originalIsDown(...)
                end
                love.keypressed('e')
                love.keyboard.isDown=originalIsDown
                assert(#A.doc.layers==countBefore-2,
                    'Ctrl+E não executou Mesclar abaixo')
                undoDoc()
                assert(#A.doc.layers==countBefore-1,
                    'Ctrl+Z não restaurou a segunda mesclagem')
                -- Stage 23: GUI button uses C++ to mirror the active layer.
                local flipIndex=A.doc.active_layer
                A.layerSession:beginEdit()
                A.layerSession:pixel(0,0,0xff1122ff)
                A.layerSession:pixel(A.doc.width-1,A.doc.height-1,0x1133aaff)
                assert(A.layerSession:finishEdit(),
                    'Fixture de espelhamento não criou pixels assimétricos')
                A.dirty=true;rebuildImage()
                local flipOriginal=Native.bytes(A.layerSession:activeBuffer())
                local flipOther=Native.bytes(A.layerSession.buffers[1])
                love.draw()
                love.mousepressed(panel+74,313,1,false)
                local horizontally=Native.bytes(A.layerSession:activeBuffer())
                assert(horizontally~=flipOriginal,
                    'Esp. H não espelhou a camada ativa')
                undoDoc()
                assert(Native.bytes(A.layerSession:activeBuffer())==flipOriginal,
                    'Desfazer Esp. H não restaurou RGBA')
                redoDoc()
                assert(Native.bytes(A.layerSession:activeBuffer())==horizontally,
                    'Refazer Esp. H não restaurou RGBA')
                love.draw();love.mousepressed(panel+191,313,1,false)
                local bothDirections=Native.bytes(A.layerSession:activeBuffer())
                undoDoc();undoDoc()
                assert(Native.bytes(A.layerSession:activeBuffer())==flipOriginal,
                    'Duplo desfazer de espelhamento falhou')
                redoDoc();redoDoc()
                assert(Native.bytes(A.layerSession:activeBuffer())==bothDirections,
                    'Duplo refazer de espelhamento falhou')
                assert(Native.bytes(A.layerSession.buffers[1])==flipOther,
                    'Espelhar camada ativa modificou a inferior')
                saveDoc()
                local flipSaved=A.store:openProject(A.doc.id)
                assert(flipSaved.layers[flipIndex].pixels==bothDirections,
                    'RBD2 não persistiu o espelhamento')
                -- Stage 24: the actual action row clears only the active
                -- raster, and integrates with the existing history/RBD2.
                local preClear=Native.bytes(A.layerSession:activeBuffer())
                local lowerBeforeClear=Native.bytes(A.layerSession.buffers[1])
                local clearCount=A.layerSession:historyStats().undo
                love.draw();love.mousepressed(panel+73,344,1,false)
                local zero=string.rep(string.char(0),#preClear)
                assert(Native.bytes(A.layerSession:activeBuffer())==zero,
                    'Limpar não deixou pixels transparentes')
                assert(A.layerSession:historyStats().undo>=1 and
                    A.layerSession:historyStats().undo<=
                        math.min(clearCount+1,A.layerSession.MAX_HISTORY_ENTRIES) and
                    A.layerSession.undoStack[#A.layerSession.undoStack].after==zero,
                    'Limpar deve registrar um passo de histórico mesmo no limite')
                assert(Native.bytes(A.layerSession.buffers[1])==lowerBeforeClear,
                    'Limpar modificou outra camada')
                undoDoc()
                assert(Native.bytes(A.layerSession:activeBuffer())==preClear,
                    'Desfazer Limpar não restaurou pixels RGBA')
                redoDoc()
                assert(Native.bytes(A.layerSession:activeBuffer())==zero,
                    'Refazer Limpar não apagou pixels')
                saveDoc()
                local clearSaved=A.store:openProject(A.doc.id)
                assert(clearSaved.layers[flipIndex].pixels==zero,
                    'RBD2 não persistiu limpeza da camada')
                local noOpHistory=A.layerSession:historyStats().undo
                love.draw();love.mousepressed(panel+73,344,1,false)
                assert(A.layerSession:historyStats().undo==noOpHistory,
                    'Limpar camada vazia criou histórico desnecessário')
                -- Shortcut must use the same native path, not delete layer.
                A.layerSession:beginEdit()
                A.layerSession:pixel(1,1,0x47ca21b4)
                assert(A.layerSession:finishEdit(),'Fixture Shift+Delete falhou')
                A.dirty=true;rebuildImage()
                local previousIsDown=love.keyboard.isDown
                love.keyboard.isDown=function(...)
                    for j=1,select('#',...) do
                        if select(j,...)=='lshift' then return true end
                    end
                    return false
                end
                love.keypressed('delete')
                love.keyboard.isDown=previousIsDown
                assert(Native.bytes(A.layerSession:activeBuffer())==zero,
                    'Shift+Delete não limpou camada ativa')
                undoDoc()
                assert(Native.readPixel(A.layerSession:activeBuffer(),1,1)==
                    0x47ca21b4,'Desfazer Shift+Delete perdeu pixel')
                redoDoc()
                assert(Native.bytes(A.layerSession:activeBuffer())==zero,
                    'Refazer Shift+Delete não limpou camada')
                assert(Native.bytes(A.layerSession.buffers[1])==lowerBeforeClear,
                    'Atalho Limpar atingiu outra camada')
                verifyVisualToolbar()
                verifyFocusWorkspace()
                verifyContextMenus()
                verifyBrushLibrary()
                verifyPrecisionSliders()
                verifyBrushTipHover()
                verifyCompactUi()
                verifyCompactVisualControls()
                verifyColorBrushWindows()
                verifyNativeBrushCatalogue()
                verifyBrushLabLive()
                verifyAdaptiveDesktopSidebar()
                verifyCompactNativeInspector()
                verifyCompactLayerOpacity()
                verifyDesktopLayerOpacity()
                verifyCompactLayerWheel()
                verifyLayerListWheel()
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
                    layer_duplicate_button=true,layer_duplicate_deep_pixels=true,
                    layer_duplicate_undo_redo=true,layer_duplicate_rbd2=true,
                    layer_duplicate_capacity_guard=true,layer_duplicate_ctrl_j=true,
                    structural_undo_duplicate=true,structural_redo_duplicate=true,
                    structural_undo_delete=true,structural_redo_delete=true,
                    structural_undo_move=true,structural_redo_move=true,
                    structural_thumbnails_restored=true,
                    mixed_history_rbd2_roundtrip=true,
                    metadata_rename_undo_redo=true,metadata_visibility_undo_redo=true,
                    metadata_opacity_undo_redo=true,metadata_pixels_preserved=true,
                    metadata_rbd2_roundtrip=true,
                    merge_down_button=true,merge_down_undo=true,
                    merge_down_redo=true,merge_down_ctrl_e=true,
                    merge_down_rbd2=true,
                    flip_hv_buttons=true,flip_undo_redo=true,
                    flip_rbd2_roundtrip=true,flip_layer_isolation=true,
                    layer_clear_button=true,layer_clear_noop=true,
                    layer_clear_shift_delete=true,layer_clear_undo_redo=true,
                    layer_clear_isolated=true,layer_clear_rbd2=true,
                    vector_tool_glyphs=true,visual_toolbar_hitboxes=true,
                    visual_toolbar_switching=true,visual_only_no_raster_edits=true,
                    focus_button=true,focus_tab_toggle=true,
                    focus_expanded_canvas=true,focus_quick_brush_controls=true,
                    focus_panel_restoration=true,focus_no_raster_edits=true,
                    context_tool_menu=true,context_layer_menu=true,
                    context_menu_click_actions=true,context_menu_keyboard=true,
                    context_menu_outside_dismiss=true,context_right_pan_preserved=true,
                    context_menu_undo_redo=true,
                    brush_library_button=true,brush_library_ctrl_b=true,
                    brush_library_builtin=true,brush_library_personal_roundtrip=true,
                    brush_library_isolated=true,brush_library_escape=true,
                    precision_slider_drag=true,precision_slider_opacity=true,
                    precision_slider_stabilization=true,precision_slider_tolerance=true,
                    precision_slider_no_raster_edits=true,legacy_buttons_preserved=true,
                    native_tip_hover=true,native_tip_cache=true,
                    native_tip_opacity_refresh=true,native_eraser_mask=true,
                    native_tip_toggle=true,native_tip_modal_isolation=true,
                    native_tip_no_raster_edits=true,
                    compact_bottom_toolbar=true,compact_tool_palette=true,
                    compact_raster_layer_panel=true,compact_property_controls=true,
                    compact_color_modal=true,compact_raster_isolation=true,
                    compact_return_desktop=true,
                    compact_brush_eraser_switch=true,
                    compact_fullscreen_toggle=true,
                    compact_vector_toolbar=true,
                    compact_quick_size=true,compact_quick_opacity=true,
                    compact_quick_capture=true,compact_visual_isolation=true,
                    compact_popup_hit_protection=true,
                    color_window_hsb_drag=true,color_window_rgb_drag=true,
                    color_window_palette_save=true,color_hex_modal_available=true,
                    brush_library_filter_tabs=true,
                    color_brush_no_raster_edits=true,
                    native_catalogue_swatch=true,native_catalogue_texture_cache=true,
                    native_catalogue_rgba_invalidation=true,
                    keyboard_brush_selection=true,brush_category_focus=true,
                    native_catalogue_no_raster_edits=true,
                    brush_lab_large_preview=true,brush_lab_live_native_cache=true,
                    brush_lab_diameter_drag=true,brush_lab_opacity_one_percent=true,
                    brush_lab_apply_cancel=true,brush_lab_no_raster_edits=true,
                    sidebar_960x640=true,sidebar_scroll_hitbox=true,
                    sidebar_slider_reachable=true,sidebar_raster_unchanged=true,
                    compact_native_brush_preview=true,
                    compact_live_cache_invalidation=true,
                    compact_native_no_document_writes=true,
                    compact_layer_opacity_one_percent=true,
                    compact_layer_opacity_single_undo=true,
                    compact_layer_opacity_undo_redo=true,
                    compact_layer_draft_no_raster=true,
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
local function galleryPreview(doc)
    if not Native.available then return nil end
    A.galleryPreviewCache=A.galleryPreviewCache or {order={},entries={}}
    local cache=A.galleryPreviewCache
    local key=GalleryThumb.key(doc)
    if cache.entries[key] then
        return cache.entries[key].image
    end
    if (A.galleryPreviewBudget or 0)<=0 then return nil end
    A.galleryPreviewBudget=A.galleryPreviewBudget-1
    local ok,item=pcall(function()
        local saved=A.store:openProject(doc.id)
        local session=Layers.open(A.store,saved)
        local width,height=GalleryThumb.size(saved.width,saved.height,176,126)
        local data=love.image.newImageData(width,height,'rgba8')
        GalleryThumb.sample(Native.bytes(session.composite),
            saved.width,saved.height,width,height,function(r,g,b,a,x,y)
                data:setPixel(x,y,r/255,g/255,b/255,a/255)
            end)
        local image=love.graphics.newImage(data)
        image:setFilter('linear','linear')
        data:release()
        return image
    end)
    cache.entries[key]={image=ok and item or nil}
    cache.order[#cache.order+1]=key
    if #cache.order>16 then
        local old=table.remove(cache.order,1)
        local previous=cache.entries[old]
        if previous and previous.image then previous.image:release() end
        cache.entries[old]=nil
    end
    return ok and item or nil
end
local function releaseGalleryPreviews()
    if A.galleryPreviewCache then
        for _,entry in pairs(A.galleryPreviewCache.entries) do
            if entry.image then entry.image:release() end
        end
    end
    A.galleryPreviewCache=nil
end
local function drawGallery(w,h)
    text('Meus desenhos',42,106,'large');text('Projetos locais editáveis · organização offline',44,163,'body','muted')
    button('Nova tela',w-322,113,140,42,function()modal('new')end,true,not Native.available)
    button('Nova pasta',w-168,113,126,42,function()modal('folder')end)
    button('Raiz',44,206,70,32,function()setFolder('')end,A.folder=='')
    if A.folder~='' then text('/ '..A.folder,127,213,'small','muted') end
    local index=0
    local function card(label,sub,folder,fn,project)
        index=index+1
        local r=Visual.galleryCard(w,h,index)
        if not r.visible then return end
        local x,y=r.x,r.y
        local mx,my=love.mouse.getPosition()
        local hovered=mx>=x and mx<x+r.w and my>=y and my<y+r.h
        box(x,y,r.w,r.h,hovered and 'line' or 'card')
        if folder then
            box(r.preview.x,r.preview.y,r.preview.w,r.preview.h,'bg')
            c('accent')
            love.graphics.rectangle('fill',x+75,y+75,67,43,6,6)
            love.graphics.rectangle('fill',x+75,y+60,31,20,4,4)
        else
            c('bg')
            love.graphics.rectangle('fill',r.preview.x,r.preview.y,
                r.preview.w,r.preview.h,3,3)
            local preview=project and galleryPreview(project)
            if preview then
                local pw,ph=preview:getDimensions()
                local left=r.preview.x+(r.preview.w-pw)/2
                local top=r.preview.y+(r.preview.h-ph)/2
                local tile=8
                for row=0,math.ceil(ph/tile)-1 do
                    for col=0,math.ceil(pw/tile)-1 do
                        local v=(row+col)%2==0 and .83 or .67
                        love.graphics.setColor(v,v,v,1)
                        love.graphics.rectangle('fill',
                            left+col*tile,top+row*tile,
                            math.min(tile,pw-col*tile),
                            math.min(tile,ph-row*tile))
                    end
                end
                love.graphics.setColor(1,1,1,1)
                love.graphics.draw(preview,left,top)
            else
                c('muted')
                love.graphics.rectangle('line',x+83,y+52,46,46,3,3)
            end
        end
        fitted(label,r.titleX,r.titleY,'body','text',176)
        text(sub,r.metaX,r.metaY,'small','muted')
        if hovered then
            c('accent')
            love.graphics.rectangle('fill',x,y+2,3,r.h-4,2,2)
        end
        A.buttons[#A.buttons+1]={x=x,y=y,w=r.w,h=r.h,fn=guard(fn)}
    end
    for _,folder in ipairs(A.folders) do card(folder.name,'Pasta',true,function()setFolder(folder.id)end) end
    for _,doc in ipairs(A.projects) do
        card(doc.name,doc.width..' × '..doc.height..' · r'..(doc.revision or 1),
            false,function()openDoc(A.store:openProject(doc.id))end,doc)
    end
    if index==0 then
        text('Uma galeria vazia, pronta para a primeira tela.',44,290,'title','muted')
        text('Crie uma pasta ou uma tela. Tudo é salvo neste computador.',44,335,'body','muted')
    end
end
-- A true renderer-produced single dab, composited over the canvas as
-- ephemeral GUI. The scratch pixels never enter Layers/RBD2 or undo.
local function drawBrushTip(w,h)
    local x,y=A.hoverX,A.hoverY
    if x==nil or y==nil then x,y=love.mouse.getPosition() end
    if not Tip.visible(A,w,h,x,y) then return end
    local settings=Tip.options(A.tool,A.brushDiameter,A.brushOpacity,
        A.color,A.brushStyle,1,0,0,false)
    local key=Tip.key(settings)
    if not A.tipCache or A.tipCache.key~=key then
        local stamp=Tip.render(Native,settings)
        local pixels=Native.bytes(stamp.buffer)
        local data=love.image.newImageData(stamp.size,stamp.size,
            'rgba8',pixels)
        local img=love.graphics.newImage(data)
        data:release()
        img:setFilter('nearest','nearest')
        releaseTipCache()
        A.tipCache={key=key,image=img,stamp=stamp}
    end
    local cache=A.tipCache
    love.graphics.push()
    love.graphics.translate(x,y)
    love.graphics.rotate(A.rotation)
    love.graphics.scale(A.zoom)
    love.graphics.setColor(1,1,1,1)
    love.graphics.draw(cache.image,-cache.stamp.center,
        -cache.stamp.center)
    love.graphics.pop()
    love.graphics.setLineWidth(1)
    love.graphics.setColor(0,0,0,.82)
    love.graphics.circle('line',x,y,3,12)
    love.graphics.setColor(1,1,1,.86)
    love.graphics.circle('line',x,y,2,12)
end
-- Fast sizing is only editor state: no native raster edit or undo entry.
local function applyQuickControl(kind,x)
    local w,h=love.graphics.getDimensions()
    local nextValue=Compact.quickValue(kind,w,h,x)
    if kind=='diameter' then A.brushDiameter=nextValue
    elseif kind=='opacity' then A.brushOpacity=nextValue
    else error('Controle rápido inválido') end
    return nextValue
end
local function drawCompactQuick(kind,w,h,value)
    local d=Compact.quick(w,h)[kind]
    local factor=Compact.quickFraction(kind,value)
    local label=kind=='diameter' and 'Tamanho' or 'Opac.'
    local valueLabel=kind=='diameter' and ('%d px'):format(value) or
        ('%.0f%%'):format(value*100)
    text(label,d.labelX,d.y-2,'small','muted')
    text(valueLabel,d.valueX,d.y-2,'small','text')
    c('line')
    love.graphics.rectangle('fill',d.x,d.y+5,d.w,4,2,2)
    c('accent')
    love.graphics.rectangle('fill',d.x,d.y+5,
        math.max(1,d.w*factor),4,2,2)
    c('text')
    love.graphics.circle('fill',d.x+d.w*factor,d.y+7,6,18)
end
local function drawEditor(w,h)
    local panel=w-268
    if not A.compactUi then
        box(12,69,690,49,'panel')
        c('line')
        love.graphics.rectangle('fill',12,117,690,1)
        button('Galeria',20,78,92,34,toGallery)
        for _,slot in ipairs(toolSlots) do toolButton(slot) end
        button('Ajustar',619,78,67,34,function()finishStroke();fit()end)
        button(A.focusMode and 'Mostrar painel' or 'Modo foco · Tab',
            w-357,15,134,33,toggleFocusMode,A.focusMode)
    else
        if A.focusMode then
            button('Mostrar barra · Tab',20,78,176,34,toggleFocusMode)
        else
            iconButton('undo',20,78,43,34,undoDoc,false,
                not A.layerSession:canUndo())
            iconButton('redo',67,78,43,34,redoDoc,false,
                not A.layerSession:canRedo())
            button('−',118,78,43,34,function()zoomCanvas(1/1.25)end)
            button('+',165,78,43,34,function()zoomCanvas(1.25)end)
            button('Encaixar',217,78,90,34,fit)
            text('Desenho · '..A.doc.width..' × '..A.doc.height,
                326,87,'small','muted')
        end
    end
    button(A.compactUi and 'Layout desktop' or 'Layout compacto',
        w-645,15,134,33,toggleCompactUi,A.compactUi)
    button(A.previewEnabled and 'Prévia: ligada' or 'Prévia: desligada',
        w-501,15,134,33,function()
            A.previewEnabled=not A.previewEnabled
        end,A.previewEnabled)
    local cx,cy=canvasTransform()
    box(12,120,w-Workspace.panelWidth(paneHidden())-20,
        h-(A.compactUi and not A.focusMode and 310 or 178),'canvas')
    love.graphics.setScissor(Workspace.scissor(w,h,paneHidden(),A.compactUi and not A.focusMode))
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
    love.graphics.pop()
    drawBrushTip(w,h)
    love.graphics.setScissor()
    -- View-only controls remain outside the raster and layer history.
    local dockY=h-116
    if not A.compactUi then
    button('−',20,dockY,36,30,function()zoomCanvas(1/1.25)end,
        false,A.zoom<=View.MIN_ZOOM)
    button('+',60,dockY,36,30,function()zoomCanvas(1.25)end,
        false,A.zoom>=View.MAX_ZOOM)
    iconButton('rotate-left',102,dockY,36,30,
        function()rotateCanvas(-math.pi/12)end)
    iconButton('rotate-right',142,dockY,36,30,
        function()rotateCanvas(math.pi/12)end)
    button('0°',182,dockY,43,30,resetCanvasRotation)
    button('Encaixar',230,dockY,83,30,fit)
    text(('Zoom %.0f%%'):format(A.zoom*100),324,dockY+7,'small','muted')
    end
    if not paneHidden() then
    local scrollMax=Sidebar.max(h)
    A.sidebarScroll=Sidebar.clamp(h,A.sidebarScroll or 0)
    local sideOffset=A.sidebarScroll
    local sidebarButtonStart=#A.buttons
    box(panel,64,268,h-112,'panel')
    c('line')
    love.graphics.rectangle('fill',panel,64,1,h-112)
    love.graphics.setScissor(panel,64,268,h-112)
    love.graphics.push()
    love.graphics.translate(0,-sideOffset)
    A.sidebarDrawing=true
    text(A.sideTab=='brush' and 'PROJETO E PINCEL' or
        'CAMADAS E PROJETO',panel+20,88,'small','muted')
    box(panel+12,114,244,71,'card')
    button('? Ajuda',panel+172,82,76,31,function()
        finishStroke();A.toolHelp=true
    end)
    fitted(A.doc.name,panel+20,115,'title','text',228)
    text(dw..' × '..dh..' · RGBA8',panel+20,150,'body','muted')
    text(A.inkAttached and ('Windows Ink · '..(A.inkPenId and 'caneta ativa'
        or 'aguardando caneta')) or 'Caneta Win32: modo alternativo',
        panel+20,171,'small','muted')
    button('Salvar · Ctrl+S',panel+20,186,228,38,saveDoc,A.dirty)
    button('Exportar PNG',panel+20,234,228,38,exportPNG)
    button('Renomear',panel+20,282,107,34,function()modal('rename');A.modal.values[1]=A.doc.name end)
    iconButton('undo',panel+134,282,52,34,undoDoc,false,
        not A.layerSession:canUndo())
    iconButton('redo',panel+196,282,52,34,redoDoc,false,
        not A.layerSession:canRedo())
    if A.sideTab=='layers' and A.tool~='picker' and A.tool~='shape' and
        A.tool~='select' then
        -- Existing action row: replace passive heading with useful command.
        button('Limpar',panel+20,329,106,30,clearActiveLayer)
        button('Mesclar ↓',panel+142,329,106,30,mergeActiveLayerDown,
            false,A.doc.active_layer<=1)
    elseif A.sideTab=='brush' and (A.tool=='brush' or A.tool=='erase') then
        button('Biblioteca de pincéis',panel+20,329,228,30,openBrushLibrary)
    else
        text('PAINEL',panel+20,343,'small','muted')
    end
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
        button('Girar -90°',panel+20,451,108,37,function()
            applySelectionTransform(3,1)
        end,false,not rect or rect.h>A.doc.width or rect.w>A.doc.height)
        button('Girar +90°',panel+140,451,108,37,function()
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
        button('Esp. H',panel+20,299,108,27,function()flipActiveLayer(0)end)
        button('Esp. V',panel+140,299,108,27,function()flipActiveLayer(1)end)
        local ls=A.layerSession
        local count=#A.doc.layers
        text(('RASTERS %d/%d'):format(count,Store.MAX_LAYERS),
            panel+20,407,'small','muted')
        button('Nome',panel+87,398,78,27,openLayerRename)
        local rows=Thumbnails.rows(Sidebar.virtualHeight(h))
        local start,stop,maxStart=Thumbnails.window(count,
            A.doc.active_layer,rows,A.layerScroll)
        iconButton('up',panel+172,398,35,27,function()
            A.layerScroll=Thumbnails.scroll(start,maxStart,1)
        end,false,start>=maxStart)
        iconButton('down',panel+213,398,35,27,function()
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
            local visual=LayerRowVisual.presentation(layer.visible,
                A.doc.active_layer==i,layer.opacity)
            local rowY=y
            button(' ',panel+20,rowY,228,33,function()
                if A.doc.active_layer~=i then
                    finishStroke();ls:select(i);A.dirty=true
                end
                A.layerScroll=start
            end,A.doc.active_layer==i)
            -- Real RGBA miniature on a checkerboard, including transparent pixels.
            for ty=0,3 do for tx=0,3 do
                local light=(tx+ty)%2==0
                love.graphics.setColor(light and .78 or .57,
                    light and .80 or .60,light and .82 or .63,1)
                love.graphics.rectangle('fill',panel+24+tx*7,rowY+2+ty*7,7,7)
            end end
            love.graphics.setColor(1,1,1,visual.thumbnailAlpha)
            love.graphics.draw(layerThumb(i),panel+24.5,rowY+2.5)
            love.graphics.setColor(1,1,1,1)
            c('line')
            love.graphics.rectangle('line',panel+24,rowY+2,29,29,2,2)
            if A.doc.active_layer==i then
                c('accent')
                love.graphics.rectangle('fill',panel+19,rowY+5,3,27,1,1)
            end
            -- Keep the full layer number visible and fit UTF-8 names
            -- to the actual free pixels before the visibility button.
            local prefix=tostring(i)..'  '
            local font=A.fonts.body
            local free=math.max(0,143-font:getWidth(prefix))
            local label=TextFit.truncate(layer.name,free,
                function(value)return font:getWidth(value)end)
            -- Two readable lines: layer name and actual layer opacity.
            -- Keep the existing hitboxes and icon-based visibility action.
            text(prefix..label,panel+62,rowY+2,'body',visual.textColor)
            fitted(visual.detail,panel+62,rowY+20,'small',
                visual.textColor,143)
            iconButton(visual.eyeIcon,
                panel+210,rowY+4,35,25,function()
                    finishStroke()
                    local nextVisible=not A.doc.layers[i].visible
                    ls:setVisible(i,nextVisible)
                    A.dirty=true;rebuildImage()
                    status(nextVisible and 'Camada visível'
                        or 'Camada oculta')
                end,layer.visible)
            y=y+37
        end
        local active=A.doc.layers[A.doc.active_layer]
        do
            local actionY=Sidebar.virtualHeight(h)-131
            local opacityY=Sidebar.virtualHeight(h)-94
            button(active.visible and 'Ocultar' or 'Mostrar',panel+20,actionY,109,30,function()
                -- Match the visibility action in each thumbnail row:
                -- commit an ongoing stroke before changing compositing.
                finishStroke()
                local index=A.doc.active_layer
                local nextVisible=not A.doc.layers[index].visible
                ls:setVisible(index,nextVisible)
                A.dirty=true;rebuildImage()
                status(nextVisible and 'Camada visível' or 'Camada oculta')
            end,active.visible)
            button('Acima',panel+139,actionY,54,30,function()
                local i=A.doc.active_layer
                local target=LayerOrder.target(i,count,1)
                if target then
                    finishStroke()
                    ls:move(i,target);A.dirty=true;rebuildImage()
                end
            end,false,not LayerOrder.target(A.doc.active_layer,count,1))
            button('Abaixo',panel+196,actionY,52,30,function()
                local i=A.doc.active_layer
                local target=LayerOrder.target(i,count,-1)
                if target then
                    finishStroke()
                    ls:move(i,target);A.dirty=true;rebuildImage()
                end
            end,false,not LayerOrder.target(A.doc.active_layer,count,-1))
            button('−',panel+20,opacityY,42,29,function()
                finishStroke()
                ls:setOpacity(A.doc.active_layer,
                    LayerOpacitySteps.change(active.opacity,-1))
                A.dirty=true;rebuildImage()
            end,false,not LayerOpacitySteps.canChange(active.opacity,-1))
            local previewOpacity=A.desktopLayerOpacityDrag and
                A.desktopLayerOpacityDrag.index==A.doc.active_layer and
                A.desktopLayerOpacityDrag.value or active.opacity
            text(('Opacidade %.0f%%'):format(previewOpacity*100),
                panel+68,opacityY+8,'small')
            button('+',panel+206,opacityY,42,29,function()
                finishStroke()
                ls:setOpacity(A.doc.active_layer,
                    LayerOpacitySteps.change(active.opacity,1))
                A.dirty=true;rebuildImage()
            end,false,not LayerOpacitySteps.canChange(active.opacity,1))
            -- Interactive desktop opacity rail; dragging previews only.
            -- The actual layer property is committed once on mouse release.
            local opacityRail=DesktopOpacity.rect(w,h)
            box(opacityRail.x,opacityRail.y,opacityRail.w,
                opacityRail.h,'line')
            c('accent')
            love.graphics.rectangle('fill',opacityRail.x,opacityRail.y,
                math.max(1,opacityRail.w*previewOpacity),
                opacityRail.h,2,2)
            c('text')
            love.graphics.circle('fill',
                opacityRail.x+opacityRail.w*previewOpacity,
                opacityRail.y+opacityRail.h/2,5,18)
        end
    else
        if A.tool=='fill' then
            text('BALDE CONTÍGUO · 4 VIZINHOS',panel+20,429,'small','muted')
            button('−',panel+20,456,46,32,function()
                A.fillTolerance=math.max(0,A.fillTolerance-8)end,
                false,A.fillTolerance==0)
            text(('Tol. %d / 255'):format(A.fillTolerance),panel+77,464,'small')
            drawParameterSlider('tolerance',panel,A.fillTolerance)
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
            drawParameterSlider('diameter',panel,A.brushDiameter)
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
            drawParameterSlider('opacity',panel,A.brushOpacity)
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
            drawParameterSlider('stabilization',panel,A.stabilization)
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
    -- Restore exact screen-space hit boxes and clip partially hidden
    -- controls. This prevents clicking off-screen sidebar actions.
    A.sidebarDrawing=false
    love.graphics.pop()
    love.graphics.setScissor()
    for i=#A.buttons,sidebarButtonStart+1,-1 do
        local b=A.buttons[i]
        local visible=Sidebar.visible(h,sideOffset,b.y,b.h)
        if not visible then
            table.remove(A.buttons,i)
        else
            b.y=visible.y;b.h=visible.h
        end
    end
    if scrollMax>0 then
        local bar=Sidebar.thumb(w,h,sideOffset)
        c('line')
        love.graphics.rectangle('fill',bar.x+1,bar.trackTop,
            3,bar.trackHeight,2,2)
        c('accent')
        love.graphics.rectangle('fill',bar.x,bar.y,bar.w,bar.h,2,2)
        -- Accessible fixed-position controls, outside the translated clip.
        for _,item in ipairs({
            {y=67,delta=-44,up=true},
            {y=h-72,delta=44,up=false}
        }) do
            box(w-18,item.y,15,20,'card')
            c('muted')
            local midX=w-10.5
            local y=item.y+10
            if item.up then
                love.graphics.polygon('fill',midX-4,y+3,midX+4,y+3,midX,y-3)
            else
                love.graphics.polygon('fill',midX-4,y-3,midX+4,y-3,midX,y+3)
            end
            local delta=item.delta
            A.buttons[#A.buttons+1]={x=w-18,y=item.y,w=15,h=20,
                fn=guard(function()
                    A.sidebarScroll=Sidebar.clamp(h,A.sidebarScroll+delta)
                end)}
        end
    end
    end -- right-side panel, hidden during focus mode
    if A.focusMode and not A.compactUi and
        (A.tool=='brush' or A.tool=='erase') then
        -- Keep the most-used drawing controls accessible without the pane.
        text('Tamanho',430,dockY+7,'small','muted')
        button('−',490,dockY,32,30,function()
            finishStroke()
            A.brushDiameter=math.max(1,A.brushDiameter-2)
        end,false,A.brushDiameter<=1)
        text(('%dpx'):format(A.brushDiameter),528,dockY+7,'small')
        button('+',566,dockY,32,30,function()
            finishStroke()
            A.brushDiameter=math.min(256,A.brushDiameter+2)
        end,false,A.brushDiameter>=256)
        text('Opac.',608,dockY+7,'small','muted')
        button('−',658,dockY,32,30,function()
            finishStroke()
            A.brushOpacity=math.max(.1,
                math.floor(A.brushOpacity*10+.5)/10-.1)
        end,false,A.brushOpacity<=.101)
        text(('%.0f%%'):format(A.brushOpacity*100),694,dockY+7,'small')
        button('+',739,dockY,32,30,function()
            finishStroke()
            A.brushOpacity=math.min(1,
                math.floor(A.brushOpacity*10+.5)/10+.1)
        end,false,A.brushOpacity>=.999)
    end
    if not A.compactUi then
    text(('Zoom %.0f%% · ângulo %.0f° · Espaço + arrastar: mover · Ctrl +/−: zoom · Q/E: girar'):format(
        A.zoom*100,math.deg(A.rotation)),22,h-72,'small','muted')
    end
    if A.tool=='select' and not A.compactUi then
        text(A.selection and 'Arraste dentro da borda para mover · Ctrl+D desmarca'
            or 'Arraste na tela para selecionar uma área retangular',22,h-94,'small','accent')
    elseif A.tool=='shape' and not A.compactUi then
        text('Arraste para desenhar uma forma ou uma linha reta',22,h-94,'small','accent')
    elseif A.tool=='picker' and not A.compactUi then
        text('Clique para capturar a cor da tela ou da camada ativa',22,h-94,'small','accent')
    end
    if A.compactUi and not A.focusMode then
        box(10,h-184,w-20,126,'panel')
        c('accent')
        love.graphics.rectangle('fill',10,h-184,3,126)
        c('line')
        love.graphics.rectangle('fill',13,h-184,w-23,1)
        text('FERRAMENTA',28,h-162,'small','muted')
        fitted(EditorTools.fromId(A.tool).label,28,h-144,'body',
            'text',210)
        if A.tool=='brush' or A.tool=='erase' then
            drawCompactQuick('diameter',w,h,A.brushDiameter)
            drawCompactQuick('opacity',w,h,A.brushOpacity)
        else
            text(('Zoom %.0f%% · %s'):format(A.zoom*100,
                EditorTools.fromId(A.tool).label),
                (w-350)/2,h-161,'small','muted')
        end
        c('line')
        love.graphics.rectangle('fill',w/2-310,h-126,620,1)
        for _,slot in ipairs(Compact.toolbar(w,h)) do
            local active=(slot.id=='brush' and
                (A.tool=='brush' or A.tool=='erase')) or
                (slot.id=='tools' and A.compactPanel=='tools') or
                (slot.id=='layers' and A.compactPanel=='layers') or
                (slot.id=='properties' and A.compactPanel=='properties')
            local label=slot.id=='brush' and
                (A.tool=='erase' and 'Borracha' or 'Pincel') or
                (slot.id=='tools' and 'Ferram.' or
                slot.id=='fullscreen' and 'Tela' or slot.label)
            button('',slot.x,slot.y,slot.w,slot.h,function()
                if slot.id=='brush' then
                    selectTool(A.tool=='brush' and 'erase' or 'brush')
                elseif slot.id=='tools' or slot.id=='layers' or
                    slot.id=='properties' then
                    toggleCompactPanel(slot.id)
                elseif slot.id=='color' then openCompactColor()
                elseif slot.id=='fullscreen' then toggleFocusMode()
                elseif slot.id=='back' then toGallery() end
            end,active)
            c(active and 'accent' or 'text')
            Icons.draw(slot.id=='brush' and
                (A.tool=='erase' and 'erase' or 'brush') or slot.id,
                slot.x+slot.w/2,slot.y+17,21)
            c('text')
            love.graphics.setFont(A.fonts.small)
            love.graphics.printf(label,slot.x,slot.y+32,
                slot.w,'center')
            if active then
                c('accent')
                love.graphics.rectangle('fill',slot.x+12,
                    slot.y+slot.h-2,slot.w-24,2,1,1)
            end
            if slot.id=='color' then
                local r,g,b=Colors.channels(A.color)
                love.graphics.setColor(r/255,g/255,b/255,1)
                love.graphics.rectangle('fill',
                    slot.x+slot.w-16,slot.y+4,9,9,2,2)
            end
        end
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
    text('Q / E · girar     0 / F · encaixar     Tab · modo foco     Ctrl+Z / Y',
        x+22,y+423,'small','muted')
    text('F1 ou H: abrir/fechar · Esc: fechar · Nenhum pixel é alterado.',
        x+22,y+447,'small','muted')
    button('Fechar ajuda',x+width-174,y+height-49,150,33,
        function()A.toolHelp=false end)
end
local function drawContextMenu()
    local m=A.contextMenu
    box(m.x,m.y,m.w,m.h,'panel')
    c('accent')
    love.graphics.rectangle('fill',m.x,m.y,3,m.h,2,2)
    c('line')
    love.graphics.setLineWidth(1)
    love.graphics.rectangle('line',m.x+.5,m.y+.5,m.w-1,m.h-1,6,6)
    text(m.title,m.x+12,m.y+10,'small','text')
    for i,entry in ipairs(m.entries) do
        local y=m.y+Menus.HEADER+(i-1)*Menus.ROW
        button(entry.label,m.x+6,y,m.w-12,Menus.ROW-1,function()
            local chosen=A.contextMenu
            A.contextMenu=nil
            performMenuAction(chosen,entry.key)
        end,i==m.cursor,not entry.enabled)
    end
end
-- Each card owns one lazily-created GPU image whose RGBA pixels were
-- produced by the real C++ renderer, not a LÖVE approximation.
local function brushSampleImage(slot,preset)
    local settingsKey=Samples.key(preset,A.color)
    A.brushSampleCache=A.brushSampleCache or {}
    local item=A.brushSampleCache[slot]
    if item and item.key==settingsKey then return item end
    if item and item.image then item.image:release() end
    local sample=Samples.render(Native,preset,A.color)
    local data=love.image.newImageData(sample.width,sample.height,
        'rgba8',Native.bytes(sample.buffer))
    local image=love.graphics.newImage(data)
    data:release()
    image:setFilter('linear','linear')
    item={key=settingsKey,image=image,sample=sample}
    A.brushSampleCache[slot]=item
    return item
end
-- Modal brush catalogue. Every preview uses native renderer parameters
-- only as a schematic sample, never claims a pixel-perfect Android stroke.
-- The larger live inspector uses the existing C++ preview renderer.
-- It is a scratch image, never a document stroke.
local function drawBrushLab(rect)
    local p=Lab.layout(rect)
    box(p.x,p.y,p.w,p.h,'card')
    local draft=assert(A.brushLabDraft,'Nenhum pincel em prévia')
    text(draft.style=='hard' and 'PRÉVIA · Rígido' or
        'PRÉVIA · Suave',p.x+9,p.y+11,'small','muted')
    fitted(BrushCard.inspectorName(A.brushFocus,
        Presets.custom(A.brushes)),p.x+9,p.y+29,
        'small','accent',p.w-18)
    local space=Lab.preview(rect)
    local tile=11
    for row=0,math.ceil(space.h/tile)-1 do
        for col=0,math.ceil(space.w/tile)-1 do
            local v=(row+col)%2==0 and .79 or .57
            love.graphics.setColor(v,v,v,1)
            love.graphics.rectangle('fill',space.x+col*tile,
                space.y+row*tile,
                math.min(tile,space.w-col*tile),
                math.min(tile,space.h-row*tile))
        end
    end
    local image=brushSampleImage('inspector',draft)
    local fit=Lab.fit(image.sample.width,image.sample.height,space)
    love.graphics.setColor(1,1,1,1)
    love.graphics.draw(image.image,fit.x,fit.y,0,fit.sx,fit.sy)
    local names={diameter='Tamanho',opacity='Opacidade',
        stabilization='Estabil.'}
    for _,kind in ipairs({'diameter','opacity','stabilization'}) do
        local rail=Lab.rail(rect,kind)
        local value=draft[kind]
        local valueString=kind=='diameter' and
            tostring(value)..' px' or kind=='opacity' and
            ('%.0f%%'):format(value*100) or
            tostring(value)..'/5'
        text((A.brushLabKey==kind and '> ' or '')..names[kind],
            rail.x,rail.y-20,'small',
            A.brushLabKey==kind and 'accent' or 'muted')
        love.graphics.setFont(A.fonts.small)
        local labelWidth=A.fonts.small:getWidth(valueString)
        text(valueString,rail.x+rail.w-labelWidth,rail.y-20,'small')
        c('line');love.graphics.rectangle('fill',
            rail.x,rail.y+4,rail.w,5,2,2)
        c('accent')
        local fraction=Lab.fraction(kind,value)
        love.graphics.rectangle('fill',rail.x,rail.y+4,
            math.max(1,rail.w*fraction),5,2,2)
        c('text')
        love.graphics.circle('fill',
            rail.x+rail.w*fraction,rail.y+6.5,5,18)
    end
    button(A.brushLabEdited and 'Aplicar ajustes *' or
        'Aplicar ajustes',p.x+8,p.y+p.h-36,p.w-16,31,
        applyBrushLab)
end
local function drawBrushLibrary(w,h)
    local rect=Presets.layout(w,h)
    love.graphics.setColor(0,0,0,.78)
    love.graphics.rectangle('fill',0,0,w,h)
    box(rect.x,rect.y,rect.w,rect.h,'panel')
    c('accent')
    love.graphics.rectangle('fill',rect.x,rect.y,4,rect.h)
    text('Biblioteca de pincéis',rect.x+20,rect.y+12,'title')
    text('Pincéis raster locais · básicos e pessoais',
        rect.x+20,rect.y+52,'small','muted')
    local saved=Presets.custom(A.brushes)
    local filled=0
    for i=1,Presets.LIMIT do
        if saved[i] then filled=filled+1 end
    end
    button('Todos',rect.x+344,rect.y+47,94,30,function()
        switchBrushCategory('all') end,A.brushFilter=='all')
    button('Básicos (4)',rect.x+447,rect.y+47,111,30,function()
        switchBrushCategory('builtin') end,A.brushFilter=='builtin')
    button('Meus ('..filled..')',rect.x+567,rect.y+47,110,30,function()
        switchBrushCategory('personal') end,A.brushFilter=='personal')
    local half=(Lab.CATALOGUE_WIDTH-56)/2
    for i=1,8 do
        local column,line=Presets.cardPosition(A.brushFilter,i)
        -- Invisible slots have no geometry or UI actions in this category.
        local x=column and rect.x+20+column*(half+16) or nil
        local y=line and rect.y+80+line*88 or nil
        local preset=i<=4 and Presets.BUILTINS[i] or saved[i-4]
        if Presets.visible(A.brushFilter,i) and preset then
            local selected=Presets.matches(preset,A)
            button('',x,y,half,80,function()
                applyBrushPreset(preset)
            end,selected)
            text(preset.name,x+12,y+5,'body')
            text(('%d px  ·  %s  ·  %.0f%%  ·  Est. %d'):format(
                preset.diameter,preset.style=='hard' and 'rígido' or 'suave',
                preset.opacity*100,preset.stabilization),
                x+12,y+28,'small','muted')
            local place=Samples.cardRect(x,y,half)
            -- Checkerboard makes partial transparency legible.
            for row=0,1 do for col=0,11 do
                local bright=(row+col)%2==0
                local t=bright and .79 or .58
                love.graphics.setColor(t,t,t,1)
                love.graphics.rectangle('fill',
                    place.x+col*place.w/12,place.y+row*place.h/2,
                    place.w/12+.25,place.h/2+.25)
            end end
            local image=brushSampleImage(i,preset)
            love.graphics.setColor(1,1,1,1)
            love.graphics.draw(image.image,place.x,place.y,0,
                place.w/image.sample.width,
                place.h/image.sample.height)
            -- Separate preview-only action. Clicking the card elsewhere
            -- still applies immediately, preserving the classic workflow.
            local previewAction=BrushCard.previewButton(x,y,half)
            button('Prévia',previewAction.x,previewAction.y,
                previewAction.w,previewAction.h,function()
                    A.brushFocus=i
                    brushLabFromFocus()
                    status('Prévia: '..preset.name..
                        ' · Ajuste parâmetros e clique Aplicar ajustes')
                end,A.brushFocus==i)
            if A.brushFocus==i then
                c('accent');love.graphics.setLineWidth(2)
                love.graphics.rectangle('line',
                    x+2,y+2,half-4,76,4,4)
                love.graphics.setLineWidth(1)
            end
        elseif Presets.visible(A.brushFilter,i) then
            box(x,y,half,80,'card')
            text('Espaço pessoal '..(i-4),x+12,y+16,'body','muted')
            text('Salve o pincel atual abaixo',x+12,y+42,'small','muted')
        end
    end
    text('Prévia para examinar · Clique no cartão para aplicar',
        rect.x+20,rect.y+434,'small','muted')
    drawBrushLab(rect)
    text(('AJUSTES SALVOS  %d / %d · Amostras C++'):format(
        filled,Presets.LIMIT),
        rect.x+20,rect.y+452,'small','muted')
    button('Salvar pincel atual',rect.x+20,rect.y+480,210,37,
        saveCustomBrush,false,filled>=Presets.LIMIT)
    button('Excluir pessoal',rect.x+240,rect.y+480,170,37,
        deleteCustomBrush,false,not A.selectedBrushCustom or
        not saved[A.selectedBrushCustom])
    button('Fechar · Esc',rect.x+rect.w-166,rect.y+480,146,37,
        function()A.brushLibrary=false end)
end
local function drawColorTile(color,x,y,w,h)
    local r,g,b,a=Colors.channels(color)
    local d=math.max(6,math.min(12,math.floor(h/3)))
    for j=0,math.ceil(h/d)-1 do
        for i=0,math.ceil(w/d)-1 do
            local light=(i+j)%2==0
            local v=light and .83 or .56
            love.graphics.setColor(v,v,v,1)
            love.graphics.rectangle('fill',x+i*d,y+j*d,
                math.min(d,w-i*d),math.min(d,h-j*d))
        end
    end
    love.graphics.setColor(r/255,g/255,b/255,a/255)
    love.graphics.rectangle('fill',x,y,w,h,2,2)
    c('line')
    love.graphics.rectangle('line',x,y,w,h,2,2)
end
local function drawColorPopup(p)
    local x,y=p.x,p.y
    text('Atual',x+22,y+49,'small','muted')
    text('Anterior',x+130,y+49,'small','muted')
    drawColorTile(A.color,x+21,y+66,97,40)
    drawColorTile(A.previousColor or A.color,x+129,y+66,97,40)
    button(Colors.format(A.color),x+237,y+66,151,40,
        function()modal('color')end)
    button('HSB',x+22,y+127,112,32,function()
        A.colorMode='hsb' end,A.colorMode=='hsb')
    button('RGB',x+143,y+127,112,32,function()
        A.colorMode='rgb' end,A.colorMode=='rgb')
    button('Paleta',x+264,y+127,124,32,function()
        A.colorMode='palette' end,A.colorMode=='palette')
    if A.colorMode=='hsb' then
        local hue,sat,bright,alpha=ColorPanel.hsb(A.color)
        local square=ColorPanel.svRect(p)
        local count=14
        for row=0,count-1 do
            for col=0,count-1 do
                local value=ColorPanel.fromHSB(hue,col/(count-1)*100,
                    (1-row/(count-1))*100,255)
                local r,g,b=Colors.channels(value)
                love.graphics.setColor(r/255,g/255,b/255,1)
                love.graphics.rectangle('fill',
                    square.x+col*square.w/count,
                    square.y+row*square.h/count,
                    math.ceil(square.w/count)+.2,
                    math.ceil(square.h/count)+.2)
            end
        end
        local selectX=square.x+square.w*sat/100
        local selectY=square.y+square.h*(1-bright/100)
        c('text');love.graphics.setLineWidth(2)
        love.graphics.circle('line',selectX,selectY,5,18)
        local hueRect=ColorPanel.hueRect(p)
        for i=0,35 do
            local value=ColorPanel.fromHSB(i*10,100,100,255)
            local r,g,b=Colors.channels(value)
            love.graphics.setColor(r/255,g/255,b/255,1)
            love.graphics.rectangle('fill',hueRect.x,
                hueRect.y+i*hueRect.h/36,hueRect.w,
                math.ceil(hueRect.h/36)+.1)
        end
        c('text');love.graphics.setLineWidth(2)
        local yy=hueRect.y+hueRect.h*hue/360
        love.graphics.rectangle('line',hueRect.x-2,yy-2,
            hueRect.w+4,4,1,1)
        text(('H %.0f°'):format(hue),x+299,y+195,'small')
        text(('S %.0f%%'):format(sat),x+299,y+226,'small')
        text(('B %.0f%%'):format(bright),x+299,y+257,'small')
        text(('A %d'):format(alpha),x+299,y+288,'small')
        local rail=ColorPanel.hsbAlphaRect(p)
        c('line');love.graphics.rectangle('fill',rail.x,rail.y+3,
            rail.w,5,2,2)
        c('accent');love.graphics.rectangle('fill',rail.x,rail.y+3,
            rail.w*alpha/255,5,2,2)
        c('text')
        love.graphics.circle('fill',rail.x+rail.w*alpha/255,
            rail.y+5,5,18)
        text('Alfa',x+23,y+350,'small','muted')
    elseif A.colorMode=='rgb' then
        local r,g,b,a=Colors.channels(A.color)
        local values={R=r,G=g,B=b,A=a}
        for _,key in ipairs({'R','G','B','A'}) do
            local rail=ColorPanel.track(p,'rgb',key)
            local fraction=values[key]/255
            text(key..'  '..values[key],x+21,rail.y-3,'small')
            c('line');love.graphics.rectangle('fill',
                rail.x,rail.y+3,rail.w,5,2,2)
            c('accent');love.graphics.rectangle('fill',
                rail.x,rail.y+3,rail.w*fraction,5,2,2)
            c('text');love.graphics.circle('fill',
                rail.x+rail.w*fraction,rail.y+5,5,18)
        end
        text('Canais 0 a 255 · precisão de 1 unidade',
            x+21,y+368,'small','muted')
    else
        text('Cores da paleta local',x+22,y+183,'small','muted')
        for i,value in ipairs(A.savedColors) do
            local col=(i-1)%6
            local row=math.floor((i-1)/6)
            local px=x+22+col*61
            local py=y+211+row*46
            drawColorTile(value,px,py,49,32)
            A.buttons[#A.buttons+1]={x=px,y=py,w=49,h=32,
                fn=function()chooseColor(value)end}
        end
        text(('Salvas: %d / %d'):format(#A.savedColors,
            ColorPanel.PALETTE_LIMIT),x+22,y+316,'small','muted')
        button('Guardar cor atual',x+204,y+310,184,32,
            savePaletteColor,false,
            #A.savedColors>=ColorPanel.PALETTE_LIMIT)
    end
    text('Cores recentes',x+22,y+392,'small','muted')
    for i,value in ipairs(A.colorHistory) do
        if i>10 then break end
        local px=x+22+(i-1)*37
        local py=y+411
        drawColorTile(value,px,py,30,22)
        A.buttons[#A.buttons+1]={x=px,y=py,w=30,h=22,
            fn=function()chooseColor(value)end}
    end
end
-- Live preview is a native C++ raster on a separate scratch buffer.
-- Its GPU image cache is shared with the stage-35 catalogue.
local function drawCompactBrushPreview(p)
    local rect=Inspector.preview(p)
    local caption=Inspector.caption(p)
    text('PRÉVIA C++',caption.x,caption.y,'small','muted')
    for row=0,math.ceil(rect.h/9)-1 do
        for col=0,math.ceil(rect.w/9)-1 do
            local v=(row+col)%2==0 and .81 or .59
            love.graphics.setColor(v,v,v,1)
            love.graphics.rectangle('fill',rect.x+col*9,rect.y+row*9,
                math.min(9,rect.w-col*9),
                math.min(9,rect.h-row*9))
        end
    end
    local state=Inspector.settings(A)
    local swatch=brushSampleImage('compact_preview',state)
    local fit=Inspector.fitted(swatch.sample.width,
        swatch.sample.height,rect)
    love.graphics.setColor(1,1,1,1)
    love.graphics.draw(swatch.image,fit.x,fit.y,0,
        fit.scale,fit.scale)
end
local function drawCompactPopup(w,h)
    local kind=A.compactPanel
    local p=Compact.popup(w,h,kind)
    box(p.x+5,p.y+7,p.w,p.h,'bg')
    box(p.x,p.y,p.w,p.h,'panel')
    c('line');love.graphics.rectangle('line',p.x+.5,p.y+.5,
        p.w-1,p.h-1,5,5)
    c('accent');love.graphics.rectangle('fill',p.x+1,p.y+44,p.w-2,2)
    text(kind=='tools' and 'Ferramentas' or
        kind=='layers' and 'Camadas raster' or
        kind=='color' and 'Cores · RGBA' or
        'Ajustes',p.x+14,p.y+13,'body')
    button('×',p.x+p.w-44,p.y+8,31,30,function()
        A.compactPanel=nil end)
    if kind=='tools' then
        for i,tool in ipairs(EditorTools.items) do
            local x=p.x+14+(i-1)%2*156
            local y=p.y+52+math.floor((i-1)/2)*70
            button(' ',x,y,148,62,function()
                if selectTool(tool.id) then A.compactPanel=nil end
            end,A.tool==tool.id)
            c(A.tool==tool.id and 'accent' or 'text')
            Icons.draw(tool.id,x+24,y+16,15)
            text(tool.label,x+44,y+15,'small')
            text(tool.key,x+121,y+39,'small','muted')
        end
        button('Ajuda · F1',p.x+14,p.y+p.h-57,p.w-28,34,
            function()A.compactPanel=nil;A.toolHelp=true end)
    elseif kind=='properties' then
        local x,y=p.x+17,p.y+54
        if A.tool=='fill' then
            text('Tolerância: '..A.fillTolerance..'/255',x,y,'body')
            button('−',x,y+32,60,34,function()
                A.fillTolerance=math.max(0,A.fillTolerance-8) end)
            button('+',x+73,y+32,60,34,function()
                A.fillTolerance=math.min(255,A.fillTolerance+8) end)
        else
            text('Diâmetro: '..A.brushDiameter..' px',x,y,'body')
            button('−',x,y+29,60,32,function()
                finishStroke();A.brushDiameter=math.max(1,A.brushDiameter-2) end)
            button('+',x+73,y+29,60,32,function()
                finishStroke();A.brushDiameter=math.min(256,A.brushDiameter+2) end)
            text(('Opacidade: %.0f%%'):format(A.brushOpacity*100),
                x,y+83,'body')
            button('−',x,y+109,60,32,function()
                finishStroke();A.brushOpacity=math.max(.1,A.brushOpacity-.1) end)
            button('+',x+73,y+109,60,32,function()
                finishStroke();A.brushOpacity=math.min(1,A.brushOpacity+.1) end)
            if A.tool=='brush' or A.tool=='erase' then
                text('Estabilizar: '..A.stabilization..'/5',x,y+162,'body')
                button('−',x,y+190,60,32,function()
                    A.stabilization=math.max(0,A.stabilization-1) end)
                button('+',x+73,y+190,60,32,function()
                    A.stabilization=math.min(5,A.stabilization+1) end)
            end
            if A.tool=='brush' then
                button('Rígido',x+146,y+28,98,32,function()
                    finishStroke();A.brushStyle='hard'
                end,A.brushStyle=='hard')
                button('Suave',x+146,y+68,98,32,function()
                    finishStroke();A.brushStyle='soft'
                end,A.brushStyle=='soft')
                drawCompactBrushPreview(p)
            end
        end
        button('Biblioteca de pincéis',x,p.y+p.h-54,p.w-34,34,
            openBrushLibrary)
    elseif kind=='color' then
        drawColorPopup(p)
    elseif kind=='layers' then
        local ls=A.layerSession
        local count=#A.doc.layers
        local active=A.doc.active_layer
        button('+',p.x+14,p.y+44,53,32,function()
            finishStroke();ls:add();A.compactLayerStart=nil
            A.dirty=true;rebuildImage()
        end,false,count>=Store.MAX_LAYERS)
        button('Duplicar',p.x+76,p.y+44,97,32,
            duplicateActiveLayer,false,count>=Store.MAX_LAYERS)
        button('Excluir',p.x+181,p.y+44,101,32,function()
            finishStroke();ls:remove(A.doc.active_layer)
            clearLayerThumbs();A.compactLayerStart=nil
            A.dirty=true;rebuildImage()
        end,false,count<=1)
        local start,stop,maxStart=Thumbnails.window(count,active,
            Compact.layerRows(p),A.compactLayerStart)
        local y=p.y+87
        for index=stop,start,-1 do
            local i=index
            local layer=A.doc.layers[i]
            local visual=LayerRowVisual.presentation(layer.visible,
                active==i,layer.opacity)
            button(' ',p.x+13,y,231,35,function()
                if i~=A.doc.active_layer then
                    finishStroke();ls:select(i);A.dirty=true
                end
                A.compactLayerStart=start
            end,active==i)
            for ty=0,3 do for tx=0,3 do
                local bright=(tx+ty)%2==0
                love.graphics.setColor(bright and .8 or .59,
                    bright and .81 or .61,bright and .82 or .63,1)
                love.graphics.rectangle('fill',p.x+19+tx*7,
                    y+3+ty*7,7,7)
            end end
            love.graphics.setColor(1,1,1,visual.thumbnailAlpha)
            love.graphics.draw(layerThumb(i),p.x+19,y+3)
            love.graphics.setColor(1,1,1,1)
            if visual.selected then
                c('accent')
                love.graphics.rectangle('fill',p.x+13,y+5,3,25,1,1)
            end
            fitted(i..' · '..layer.name,p.x+57,y+9,
                'small',visual.textColor,Inspector.rowLabelWidth())
            text(('%.0f%%'):format(layer.opacity*100),
                p.x+190,y+9,'small',visual.textColor)
            iconButton(visual.eyeIcon,
                p.x+251,y+3,33,29,
                function()
                    finishStroke();ls:setVisible(i,not layer.visible)
                    A.dirty=true;rebuildImage()
                end,layer.visible)
            y=y+40
        end
        iconButton('up',p.x+13,p.y+p.h-87,34,28,function()
            A.compactLayerStart=Thumbnails.scroll(start,maxStart,1)
        end,false,start>=maxStart)
        iconButton('down',p.x+54,p.y+p.h-87,34,28,function()
            A.compactLayerStart=Thumbnails.scroll(start,maxStart,-1)
        end,false,start<=1)
        button('Nome',p.x+95,p.y+p.h-87,84,28,openLayerRename)
        button('Mesclar',p.x+186,p.y+p.h-87,98,28,
            mergeActiveLayerDown,false,active<=1)
        local layer=A.doc.layers[A.doc.active_layer]
        local drag=A.compactLayerOpacityDrag
        local shown=drag and drag.index==A.doc.active_layer and
            drag.value or layer.opacity
        text(('Opacidade %.0f%%'):format(shown*100),
            p.x+14,p.y+p.h-45,'small')
        local track=LayerOpacity.rect(p)
        c('line')
        love.graphics.rectangle('fill',track.x,track.y+4,
            track.w,5,2,2)
        c('accent')
        love.graphics.rectangle('fill',track.x,track.y+4,
            math.max(1,track.w*LayerOpacity.fraction(shown)),5,2,2)
        c('text')
        love.graphics.circle('fill',
            track.x+track.w*LayerOpacity.fraction(shown),
            track.y+6.5,5,16)
        button('−',p.x+190,p.y+p.h-49,41,30,function()
            finishStroke()
            ls:setOpacity(A.doc.active_layer,
                LayerOpacitySteps.change(A.doc.layers[A.doc.active_layer].opacity,-1))
            A.dirty=true;rebuildImage()
        end,false,not LayerOpacitySteps.canChange(layer.opacity,-1))
        button('+',p.x+242,p.y+p.h-49,41,30,function()
            finishStroke()
            ls:setOpacity(A.doc.active_layer,
                LayerOpacitySteps.change(A.doc.layers[A.doc.active_layer].opacity,1))
            A.dirty=true;rebuildImage()
        end,false,not LayerOpacitySteps.canChange(layer.opacity,1))
    end
end
function love.draw()
    A.buttons={};A.galleryPreviewBudget=1
    local w,h=love.graphics.getDimensions();c('bg')
    love.graphics.clear((A.compactUi and compactPalette or palette).bg)
    box(0,0,w,64,'panel')
    c('accent');love.graphics.rectangle('fill',0,0,4,64)
    text('Ibis Rebuild',24,13,'title')
    if A.screen=='gallery' or w>=1120 then
        local name=A.screen=='editor' and A.doc and A.doc.name
            or 'Minha galeria'
        fitted(name,232,24,'body','muted',
            A.screen=='editor' and Visual.headerNameWidth(w) or 320)
    end
    c(Native.available and 'accent' or 'warn')
    love.graphics.circle('fill',w-201,31,3.2,14)
    text(Native.available and 'Editor local' or 'Motor indisponível',
        w-191,24,'small',Native.available and 'accent' or 'warn')
    if A.screen=='gallery' then drawGallery(w,h)else drawEditor(w,h)end
    box(0,h-48,w,48,'panel')
    fitted(A.message or '',20,h-33,'small','muted',w-260)
    if A.testReport then text(A.testReport.ok and 'TESTES LUA OK' or 'FALHA NOS TESTES',w-220,h-32,'small',A.testReport.ok and 'accent' or 'warn')end
    if A.modal then A.buttons={};drawModal(w,h)
    elseif A.toolHelp and A.screen=='editor' then
        A.buttons={}
        drawToolHelp(w,h)
    elseif A.brushLibrary and A.screen=='editor' then
        A.buttons={}
        drawBrushLibrary(w,h)
    elseif A.contextMenu and A.screen=='editor' then
        A.buttons={}
        drawContextMenu()
    elseif A.compactUi and A.compactPanel and A.screen=='editor' then
        A.buttons={}
        drawCompactPopup(w,h)
    end
    if A.showcase and A.showcase.frames>=3 and
        not A.showcase.pending then
        local sh=A.showcase
        sh.pending=true
        local file=showcaseNames[sh.stage]
        love.graphics.captureScreenshot(function(image)
            local ok,err=pcall(externalWrite,sh.directory..'/'..file,
                image:encode('png'):getString())
            if ok then sh.captured=true
            else sh.error=tostring(err) end
        end)
    end
end
local function pointerPressed(x,y,buttonNumber,pressure)
    pressure=Pressure.normalize(pressure)
    A.hoverX=x;A.hoverY=y;A.mouseOutside=false
    if A.compactUi and A.compactPanel then
        if buttonNumber==1 and A.compactPanel=='layers' then
            local p=Compact.popup(love.graphics.getWidth(),love.graphics.getHeight(),'layers')
            -- Only this slider is in the lower panel; the +/- buttons stay
            -- untouched, and the canvas never receives this pointer.
            if LayerOpacity.hit(p,x,y) then
                finishStroke()
                local i=A.doc.active_layer
                local initial=A.doc.layers[i].opacity
                A.compactLayerOpacityDrag=LayerOpacity.draft(i,initial,
                    LayerOpacity.value(p,x))
                return
            end
        end
        if buttonNumber==1 and A.compactPanel=='color' and
            A.colorMode~='palette' then
            local w,h=love.graphics.getDimensions()
            local p=Compact.popup(w,h,'color')
            local kind
            if A.colorMode=='rgb' then
                local channel=ColorPanel.trackHit(p,'rgb',x,y)
                if channel then kind='rgb-'..channel end
            else
                local square=ColorPanel.svRect(p)
                local hue=ColorPanel.hueRect(p)
                local alpha=ColorPanel.hsbAlphaRect(p)
                if x>=square.x and x<=square.x+square.w and
                    y>=square.y and y<=square.y+square.h then
                    kind='sv'
                elseif x>=hue.x-3 and x<=hue.x+hue.w+3 and
                    y>=hue.y-3 and y<=hue.y+hue.h+3 then
                    kind='hue'
                elseif x>=alpha.x-3 and x<=alpha.x+alpha.w+3 and
                    y>=alpha.y-5 and y<=alpha.y+alpha.h+5 then
                    kind='alpha'
                end
            end
            if kind then
                A.colorHistory=ColorPanel.history(A.colorHistory,A.color)
                A.colorDrag=kind
                updateColorDrag(kind,x,y)
                return
            end
        end
        if buttonNumber==1 then
            for i=#A.buttons,1,-1 do
                local b=A.buttons[i]
                if x>=b.x and x<=b.x+b.w and y>=b.y and y<=b.y+b.h then
                    b.fn();return
                end
            end
        end
        A.compactPanel=nil;A.colorDrag=nil
        return -- Closing a palette must not paint behind it.
    end
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
    if A.brushLibrary then
        if buttonNumber==1 then
            local rect=Presets.layout(love.graphics.getDimensions())
            local kind=Lab.hit(rect,x,y)
            if kind then
                A.brushLabDrag=kind
                adjustBrushLab(kind,x)
                return
            end
        end
        if buttonNumber==1 then
            for i=#A.buttons,1,-1 do
                local b=A.buttons[i]
                if x>=b.x and x<=b.x+b.w and y>=b.y and y<=b.y+b.h then
                    b.fn();return
                end
            end
        end
        return -- The underlying canvas is always inert.
    end
    if A.contextMenu then
        if buttonNumber==1 then
            for i=#A.buttons,1,-1 do
                local b=A.buttons[i]
                if x>=b.x and x<=b.x+b.w and y>=b.y and y<=b.y+b.h then
                    b.fn();return
                end
            end
        end
        A.contextMenu=nil
        return -- Outside click dismisses; never leaks to the canvas.
    end
    if A.screen=='editor' and not A.modal and buttonNumber==2 then
        local toolId=not A.compactUi and Menus.toolAt(toolSlots,x,y) or nil
        if toolId then
            openContextMenu('tool',toolId,x,y)
            return
        end
        if not paneHidden() and A.sideTab=='layers' and A.tool~='shape'
            and A.tool~='select' and A.tool~='picker' then
            local count=#A.doc.layers
            local height=love.graphics.getHeight()
            local rows=Thumbnails.rows(Sidebar.virtualHeight(height))
            local start,stop=Thumbnails.window(count,
                A.doc.active_layer,rows,A.layerScroll)
            local clickY=Sidebar.contains(love.graphics.getWidth(),
                height,x,y) and
                Sidebar.pointerY(y,A.sidebarScroll or 0) or -999
            local index=Menus.layerAt(x,clickY,
                love.graphics.getWidth()-268,start,stop)
            if index then
                openContextMenu('layer',index,x,y)
                return
            end
        end
    end
    if buttonNumber==1 and A.screen=='editor' and
        A.compactUi and not A.focusMode and
        (A.tool=='brush' or A.tool=='erase') and
        not A.modal and not A.spaceHeld then
        local w,h=love.graphics.getDimensions()
        local kind=Compact.quickHit(w,h,x,y)
        if kind then
            finishStroke()
            A.quickDrag=kind
            applyQuickControl(kind,x)
            return
        end
    end
    if buttonNumber==1 and A.screen=='editor' and not A.modal and
        not A.spaceHeld and not A.compactUi and not paneHidden() and
        A.sideTab=='layers' and A.tool~='picker' and
        A.tool~='shape' and A.tool~='select' then
        local w,h=love.graphics.getDimensions()
        if DesktopOpacity.hit(w,h,x,y,A.sidebarScroll) then
            finishStroke()
            local i=A.doc.active_layer
            local initial=A.doc.layers[i].opacity
            A.desktopLayerOpacityDrag=DesktopOpacity.draft(i,initial,
                DesktopOpacity.value(w,h,x))
            return
        end
    end
    if buttonNumber==1 and A.screen=='editor' and not A.modal
        and not A.spaceHeld then
        local panel=love.graphics.getWidth()-268
        local inSidebar=not paneHidden() and
            Sidebar.contains(love.graphics.getWidth(),
                love.graphics.getHeight(),x,y)
        local hitY=inSidebar and Sidebar.pointerY(y,A.sidebarScroll or 0)
            or y
        local kind=Sliders.kindAt(A.tool,A.sideTab,paneHidden(),
            panel,x,hitY)
        if kind and not inSidebar then kind=nil end
        if kind then
            finishStroke()
            A.shapePreview=nil
            A.sliderDrag=kind
            applyParameterSlider(kind,x)
            return
        end
    end
    -- Middle/right mouse or Space+left pan the view without opening any
    -- painting, shape, selection or undo transaction.
    if A.screen=='editor' and not A.modal and
        (buttonNumber==2 or buttonNumber==3 or
        (buttonNumber==1 and A.spaceHeld)) then
        if Workspace.contains(love.graphics.getWidth(),
            love.graphics.getHeight(),paneHidden(),x,y,A.compactUi and not A.focusMode) then
            finishStroke()
            A.panning=true;A.panButton=buttonNumber
            return
        end
    end
    if buttonNumber==1 then
        for i=#A.buttons,1,-1 do local b=A.buttons[i];if x>=b.x and x<=b.x+b.w and y>=b.y and y<=b.y+b.h then A.shapePreview=nil;b.fn();return end end
        if A.screen=='editor' and not A.modal and Workspace.contains(
            love.graphics.getWidth(),love.graphics.getHeight(),paneHidden(),x,y,A.compactUi and not A.focusMode) then
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
    if A.desktopLayerOpacityDrag and b==1 then
        local drag=A.desktopLayerOpacityDrag
        A.desktopLayerOpacityDrag=nil
        if A.screen=='editor' and A.layerSession and
            drag.index<=#A.doc.layers then
            drag.value=DesktopOpacity.value(
                love.graphics.getWidth(),love.graphics.getHeight(),x)
            if DesktopOpacity.changed(drag) then
                finishStroke()
                local changed=A.layerSession:setOpacity(drag.index,
                    drag.value)
                if changed then A.dirty=true;rebuildImage() end
                status(('Opacidade da camada %d: %.0f%%'):format(
                    drag.index,drag.value*100))
            end
        end
        return
    end
    if A.compactLayerOpacityDrag and b==1 then
        local drag=A.compactLayerOpacityDrag
        A.compactLayerOpacityDrag=nil
        if A.screen=='editor' and A.compactPanel=='layers' and
            drag.index<=#A.doc.layers then
            local p=Compact.popup(love.graphics.getWidth(),love.graphics.getHeight(),'layers')
            drag.value=LayerOpacity.value(p,x)
            if LayerOpacity.changed(drag) then
                finishStroke()
                local changed=A.layerSession:setOpacity(drag.index,
                    drag.value)
                if changed then A.dirty=true;rebuildImage() end
                status(('Opacidade da camada %d: %.0f%%'):format(
                    drag.index,drag.value*100))
            end
        end
        return
    end
    if A.brushLabDrag and b==1 then
        adjustBrushLab(A.brushLabDrag,x)
        A.brushLabDrag=nil
        return
    end
    if A.colorDrag and b==1 then
        updateColorDrag(A.colorDrag,x,y)
        A.colorDrag=nil
        A.colorHistory=ColorPanel.history(A.colorHistory,A.color)
        return
    end
    if A.quickDrag and b==1 then
        applyQuickControl(A.quickDrag,x)
        A.quickDrag=nil
        return
    end
    if A.sliderDrag and b==1 then
        applyParameterSlider(A.sliderDrag,x)
        A.sliderDrag=nil
        return
    end
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
    A.hoverX=x;A.hoverY=y;A.mouseOutside=false
    if A.desktopLayerOpacityDrag then
        A.desktopLayerOpacityDrag.value=DesktopOpacity.value(
            love.graphics.getWidth(),love.graphics.getHeight(),x)
        return
    end
    if A.compactLayerOpacityDrag then
        local p=Compact.popup(love.graphics.getWidth(),love.graphics.getHeight(),'layers')
        A.compactLayerOpacityDrag.value=LayerOpacity.value(p,x)
        return
    end
    if A.brushLabDrag then
        adjustBrushLab(A.brushLabDrag,x)
        return
    end
    if A.colorDrag then
        updateColorDrag(A.colorDrag,x,y)
        return
    end
    if A.quickDrag then
        applyQuickControl(A.quickDrag,x)
        return
    end
    if A.sliderDrag then
        applyParameterSlider(A.sliderDrag,x)
        return
    end
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
    A.mouseOutside=true;A.hoverX=nil;A.hoverY=nil
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
            A.mouseOutside=true;A.hoverX=nil;A.hoverY=nil
            if A.inkPreviousTool then
                A.tool=A.inkPreviousTool;A.inkPreviousTool=nil
            end
        end
    end
end
function love.mousefocus(focused)
    if not focused then
        A.mouseOutside=true;A.hoverX=nil;A.hoverY=nil
    end
end
function love.focus(focused)
    if not focused then
        A.mouseOutside=true;A.hoverX=nil;A.hoverY=nil
        A.compactLayerOpacityDrag=nil;A.desktopLayerOpacityDrag=nil
        A.shapePreview=nil;A.touchId=nil;A.inkPenId=nil
        A.panning=false;A.panButton=nil;A.spaceHeld=false
        A.toolHelp=false;A.contextMenu=nil;A.brushLibrary=false;A.brushLabDrag=nil;A.sliderDrag=nil;A.compactPanel=nil
        if A.inkPreviousTool then A.tool=A.inkPreviousTool;A.inkPreviousTool=nil end
        guard(finishSelection)()
        guard(finishStroke)()
    end
end
function love.wheelmoved(x,y)
    if A.screen=='editor' and A.compactUi and
        A.compactPanel=='layers' and not A.modal and
        not A.toolHelp and not A.contextMenu and not A.brushLibrary then
        local w,h=love.graphics.getDimensions()
        local mx,my=love.mouse.getPosition()
        if y~=0 and CompactLayerWheel.hit(w,h,mx,my,#A.doc.layers) then
            A.compactLayerStart=CompactLayerWheel.scroll(#A.doc.layers,
                A.doc.active_layer,w,h,A.compactLayerStart,y)
        end
        return -- Never zoom or change the selection behind the popup.
    end
    if A.toolHelp or A.contextMenu or A.brushLibrary or A.compactPanel then return end
    if A.screen=='editor' and not A.modal then
        local mx,my=love.mouse.getPosition()
        local width,height=love.graphics.getDimensions()
        -- Layer rows have their own scroll region; the outer sidebar
        -- still scrolls everywhere else. Wheel navigation is view-only.
        local insideSidebar=not paneHidden() and
            Sidebar.contains(width,height,mx,my)
        if insideSidebar and A.sideTab=='layers' and
            A.tool~='picker' and A.tool~='shape' and
            A.tool~='select' and
            LayerListWheel.hit(width,height,mx,my,A.sidebarScroll) then
            if y~=0 then
                A.layerScroll=LayerListWheel.scroll(#A.doc.layers,
                    A.doc.active_layer,height,A.layerScroll,y)
            end
            return
        end
        if insideSidebar then
            if y~=0 and Sidebar.max(height)>0 then
                A.sidebarScroll=Sidebar.clamp(height,
                    (A.sidebarScroll or 0)-y*40)
            end
            return -- Never zoom or change selected layer over a panel.
        end
        if y==0 then return end
        local w,h=love.graphics.getDimensions()
        local my=select(2,love.mouse.getPosition())
        if not Workspace.contains(w,h,paneHidden(),mx,my,A.compactUi and not A.focusMode) then
            mx,my=View.center(viewData(),w,h)
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
    if A.desktopLayerOpacityDrag then
        if key=='escape' then
            A.desktopLayerOpacityDrag=nil
            status('Ajuste de opacidade cancelado')
        end
        return
    end
    if A.modal then
        if key=='escape'then A.modal=nil;love.keyboard.setTextInput(false)
        elseif key=='return'then guard(submitModal)()
        elseif key=='tab'then A.modal.focus=A.modal.focus%#A.modal.values+1
        elseif key=='backspace'then local utf8=require('utf8');local s=A.modal.values[A.modal.focus];local pos=utf8.offset(s,-1);if pos then A.modal.values[A.modal.focus]=s:sub(1,pos-1)end end
        return
    end
    if A.screen=='editor' and A.brushLibrary then
        if key=='escape' then
            A.brushLibrary=false;A.brushLabDrag=nil
        elseif BrushKeyboard.select(key) then
            A.brushLabKey=BrushKeyboard.select(key)
        elseif (key=='-' or key=='=' or key=='+' or
            key=='kp-' or key=='kp+') and A.brushLabDraft then
            local kind=A.brushLabKey or 'diameter'
            local updated=BrushKeyboard.step(A.brushLabDraft,kind,key)
            if updated then
                A.brushLabEdited=A.brushLabEdited or
                    updated[kind]~=A.brushLabDraft[kind]
                A.brushLabDraft=updated
            end
        elseif key=='tab' then
            local nextFilter=A.brushFilter=='all' and 'builtin' or
                A.brushFilter=='builtin' and 'personal' or 'all'
            switchBrushCategory(nextFilter)
        elseif key=='left' or key=='right' or
            key=='up' or key=='down' then
            local offset=(key=='left' and -1 or
                key=='right' and 1 or key=='up' and -2 or 2)
            A.brushFocus=Presets.navigate(A.brushFilter,
                Presets.custom(A.brushes),A.brushFocus,offset)
            brushLabFromFocus()
        elseif key=='return' or key=='kpenter' then
            local idx=A.brushFocus
            if idx then
                local chosen=idx<=4 and Presets.BUILTINS[idx] or
                    Presets.custom(A.brushes)[idx-4]
                if chosen then guard(applyBrushPreset)(chosen) end
            end
        end
        return
    end
    if A.screen=='editor' and A.compactPanel then
        if A.compactPanel=='layers' and not A.compactLayerOpacityDrag then
            local nextIndex=LayerKeys.target(key,A.doc.active_layer,
                #A.doc.layers)
            if nextIndex then
                if nextIndex~=A.doc.active_layer then
                    finishStroke()
                    A.layerSession:select(nextIndex)
                    A.compactLayerStart=nil
                    A.dirty=true
                    status('Camada selecionada: '..nextIndex)
                end
                return
            elseif key=='v' then
                finishStroke()
                local index=A.doc.active_layer
                A.layerSession:setVisible(index,
                    not A.doc.layers[index].visible)
                A.dirty=true
                rebuildImage()
                status('Visibilidade da camada '..index..' alternada')
                return
            end
        end
        if key=='escape' then
            A.compactLayerOpacityDrag=nil
            A.compactPanel=nil;A.colorDrag=nil
        elseif EditorTools.fromKey(key) then
            selectTool(EditorTools.fromKey(key).id)
            A.compactPanel=nil
        end
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
    if A.screen=='editor' and A.contextMenu then
        local menu=A.contextMenu
        if key=='escape' then
            A.contextMenu=nil
        elseif key=='up' or key=='down' then
            local step=key=='up' and -1 or 1
            for offset=1,#menu.entries do
                local index=(menu.cursor-1+step*offset)%#menu.entries+1
                if menu.entries[index].enabled then
                    menu.cursor=index
                    break
                end
            end
        elseif key=='return' or key=='kpenter' then
            local entry=menu.entries[menu.cursor]
            if entry and entry.enabled then
                A.contextMenu=nil
                guard(function()performMenuAction(menu,entry.key)end)()
            end
        end
        return
    end
    if A.screen=='editor' and not paneHidden() and
        (key=='pageup' or key=='pagedown' or
            key=='home' or key=='end') then
        local w,h=love.graphics.getDimensions()
        local mx,my=love.mouse.getPosition()
        if Sidebar.contains(w,h,mx,my) and Sidebar.max(h)>0 then
            local delta=key=='pageup' and -180 or
                key=='pagedown' and 180 or nil
            A.sidebarScroll=Sidebar.clamp(h,
                key=='home' and 0 or key=='end' and
                    Sidebar.max(h) or (A.sidebarScroll or 0)+delta)
            return
        end
    end
    if A.screen=='editor' and key=='b' and
        love.keyboard.isDown('lctrl','rctrl') then
        guard(openBrushLibrary)()
        return
    end
    if A.screen=='editor' and key=='tab' then
        guard(toggleFocusMode)()
        return
    end
    if A.screen=='editor' and key=='delete' and
        love.keyboard.isDown('lshift','rshift') then
        guard(clearActiveLayer)()
        return
    end
    if A.screen=='editor' and love.keyboard.isDown('lctrl','rctrl') and
        key=='h' and love.keyboard.isDown('lshift','rshift') then
        guard(function()flipActiveLayer(0)end)()
        return
    end
    if A.screen=='editor' and love.keyboard.isDown('lctrl','rctrl') and
        key=='v' and love.keyboard.isDown('lshift','rshift') then
        guard(function()flipActiveLayer(1)end)()
        return
    end
    if A.screen=='editor' and love.keyboard.isDown('lctrl','rctrl') and key=='e' then
        guard(mergeActiveLayerDown)()
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
function love.resize()
    A.desktopLayerOpacityDrag=nil
    A.sidebarScroll=Sidebar.clamp(love.graphics.getHeight(),
        A.sidebarScroll or 0)
    if A.doc then fit() end
end
function love.quit()
    Ink.close()
    releaseTipCache()
    releaseBrushSamples()
    releaseGalleryPreviews()
    clearLayerThumbs()
    if A.store then
        if A.doc and A.dirty then local ok,err=pcall(saveDoc);if not ok then status('Falha ao salvar; fechamento cancelado: '..tostring(err));return true end end
        pcall(function()A.store:setPreferences(A.preferences);A.store:saveBrushes(A.brushes)end)
    end
end
