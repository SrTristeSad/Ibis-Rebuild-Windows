local Native=require('native')
local Store=require('store')
local Layers=require('layers')
local FS=require('fs')
local JSON=require('json')
local Colors=require('colors')
local ColorPanel=require('color_window')
local Stabilizer=require('stroke_stabilizer')
local DirtyRegion=require('dirty_region')
local GPUUpload=require('gpu_upload')
local StrokePath=require('stroke_path')
local Pressure=require('touch_pressure')
local PressureCurves=require('pressure_curves')
local PressureInfluence=require('pressure_influence')
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
local PopupFocus=require('compact_popup_focus')
local IbisTools=require('ibis_visual_tools')
local EditorRail=require('ibis_editor_rail')
local TopToolbar=require('ibis_top_toolbar')
local IbisPanels=require('ibis_visual_panels')
IbisPanels.galleryDetail=require('ibis_gallery_detail')
IbisPanels.canvasPresetRows=require('ibis_canvas_preset_rows')
IbisPanels.canvasDimensionControls=require('ibis_canvas_dimension_controls')
IbisPanels.canvasDimensionSlider=require('ibis_canvas_dimension_slider')
IbisPanels.canvasDialogChrome=require('ibis_canvas_dialog_chrome')
IbisPanels.canvasReferenceDraw=require('ibis_canvas_reference_draw')
IbisPanels.galleryCardChrome=require('ibis_gallery_card_chrome')
local LayerUI=require('ibis_layer_ui')
local LayerChrome=require('ibis_layer_chrome')
local FilterUI=require('ibis_filter_ui')
local TextUI=require('ibis_text_ui')
local RulerUI=require('ibis_ruler_ui')
local MaterialUI=require('ibis_material_ui')
local TransformUI=require('ibis_transform_ui')
local SelectionToolUI=require('ibis_selection_tool_ui')
local EffectUI=require('ibis_effect_tools_ui')
local VectorFrameUI=require('ibis_vector_frame_ui')
local PaletteUI=require('ibis_palette_ui')
local GalleryUI=require('ibis_gallery_ui')
IbisPanels.canvasReference=require('ibis_canvas_reference')
local GalleryShell=require('ibis_gallery_shell')
local SettingsUI=require('ibis_settings_ui')
IbisPanels.stabilizer=require('ibis_stabilizer_ui')
IbisPanels.trash=require('ibis_deleted_retention')
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
    '09-opacidade-camadas.png','10-seletor-ferramentas.png',
    '11-criar-tela.png','12-galeria-desenhos.png',
    '13-menu-visualizacao.png','14-estabilizador.png',
    '15-opcoes-forma.png','16-materiais-pendentes.png',
    '17-losango-hsb.png','18-sliders-rgb.png',
    '19-paleta-cores.png','20-cores-pessoais.png',
    '21-camada-selecao.png','22-modos-mesclagem.png',
    '23-selecao-ativa.png','24-catalogo-filtros.png',
    '25-texto-rascunho.png','26-texto-estilo.png',
    '27-reguas-catalogo.png','28-regua-espelho.png',
    '29-materiais-categorias.png','30-materiais-busca.png',
    '31-transformar-mover.png','32-transformar-perspectiva.png',
    '33-varinha-magica.png','34-laco.png',
    '35-borrar.png','36-desfoque.png',
    '37-caneta-especial.png','38-liquify.png',
    '39-vetor.png','40-dividir-quadros.png',
    '41-quadros-divisao.png',
    '42-busca-fechada.png','43-texto-foco-encerrado.png',
    '44-editor-faixa-ferramentas.png','45-editor-faixa-interacao.png',
    '46-paleta-ferramentas.png','47-janela-camadas.png',
    '48-camadas-visuais.png','49-camada-selecionada.png',
    '50-camadas-comandos.png','51-camadas-adicionar.png',
    '52-camadas-duplicar.png','53-camadas-rodape-oficial.png',
    '54-camadas-mesclagem-rodape.png',
    '55-varinha-mascara-real.png',
    '56-ferramenta-pendente-nao-pinta.png',
    '57-ferramentas-uma-coluna.png',
    '58-ferramentas-uma-coluna-pagina2.png',
    '59-ferramentas-tres-colunas.png',
    '60-menu-voltar.png','61-configuracoes-ibis.png',
    '62-ferramentas-sem-rotulos.png',
    '63-galeria-miniaturas.png','64-galeria-rolagem.png',
    '65-galeria-selecao-visual.png',
    '66-estabilizador-1412-tempo-real.png',
    '67-estabilizador-1412-fade.png',
    '68-estabilizador-1412-rascunho.png',
    '69-estabilizador-legado-lua.png',
    '70-nova-tela-tamanhos-basicos.png',
    '71-nova-tela-formatos-oficiais.png',
    '72-nova-tela-proporcao-3-4.png',
    '73-nova-tela-a4-pixels.png',
    '74-nova-tela-presets-preservados.png',
    '75-galeria-selecao-rodape.png',
    '76-galeria-selecionar-todos.png',
    '77-galeria-limpar-selecao.png',
    '78-galeria-excluir-pendente.png',
    '79-galeria-mover-abrir.png',
    '80-galeria-mover-escolher-pasta.png',
    '81-galeria-obra-movida.png',
    '82-galeria-destino-verificado.png',
    '83-mover-criar-pasta.png',
    '84-mover-nova-pasta-criada.png',
    '85-mover-obra-para-pasta-nova.png',
    '86-mover-pasta-nova-verificada.png',
    '87-mover-criacao-cancelada.png',
    '88-excluir-confirmacao.png',
    '89-excluir-cancelado.png',
    '90-excluir-recuperavel.png',
    '91-excluidos-recentemente.png',
    '92-recuperar-confirmacao.png',
    '93-desenho-recuperado.png',
    '94-galeria-menu-tres-pontos.png',
    '95-excluidos-prazo-recuperacao.png',
    '96-excluidos-selecao-em-lote.png',
    '97-excluidos-lote-recuperado.png',
    '98-galeria-sem-abas-inventadas.png',
    '99-galeria-rolagem-sem-abas.png',
    '100-galeria-selecao-sem-abas.png',
    '101-galeria-arrasto-pressionado.png',
    '102-galeria-ordem-alterada.png',
    '103-galeria-ordem-persistida.png',
    '104-galeria-arrasto-curto-cancelado.png',
    '105-galeria-pastas-e-obras-reordenadas.png',
    '106-arrastar-desenho-para-pasta.png',
    '107-desenho-dentro-da-pasta.png',
    '108-arrastar-desenho-para-voltar.png',
    '109-desenho-movido-para-pasta-pai.png',
    '110-agrupar-desenho-sobre-outro.png',
    '111-pasta-criada-com-dois-desenhos.png',
    '112-conteudo-da-pasta-agrupada.png',
    '113-agrupar-com-nome-duplicado.png',
    '114-arrasto-rolagem-para-baixo.png',
    '115-arrasto-rolagem-para-cima.png',
    '116-arrasto-rolagem-cancelado.png',
    '117-alpha-lock-camada-ativado.png',
    '118-alpha-lock-pintura-real.png',
    '119-alpha-lock-rbd2-reaberto.png',
    '120-ferramentas-direita.png',
    '121-ferramentas-popup-sem-faixa.png',
    '122-galeria-imagem-ampliada.png',
    '123-galeria-proxima-obra.png',
    '124-galeria-gesto-voltar.png',
    '125-galeria-editar-obra.png'}
local A={wandEngine=require('wand_selection'),toolRailPage=1,screen='gallery',galleryDetailId=nil,galleryDetailSwipe=nil,folder='',galleryFilter='all',dirty=false,buttons={},zoom=1,rotation=0,panX=0,panY=0,tool='inspect',color=0x192d40ff,view='grid',brushDiameter=12,brushStyle='hard',brushOpacity=1,penTiltEnabled=true,pressureCurve='linear',pressureSize=true,pressureOpacity=true,stabilization=0,stabilizer=nil,touchId=nil,inkPenId=nil,inkPreviousTool=nil,inkTiltX=0,inkTiltY=0,lastPressure=1,fillTolerance=0,shapeKind=0,pickerSource='composite',shapeFilled=false,shapeWidth=2,shapePreview=nil,drawing=false,sideTab='layers',spaceHeld=false,panning=false,panButton=nil,toolHelp=false,contextMenu=nil,brushLibrary=false,selectedBrushCustom=nil,brushFocus=nil,brushSampleCache=nil,brushLabDraft=nil,brushLabEdited=false,brushLabDrag=nil,sliderDrag=nil,previewEnabled=true,tipCache=nil,hoverX=nil,hoverY=nil,mouseOutside=false,focusMode=false,compactUi=false,quickDrag=nil,compactPanel=nil,colorMode='hsb',paletteTab='standard',colorDrag=nil,colorHistory={},savedColors={},previousColor=nil,brushFilter='all',compactLayerStart=nil,compactLayerOpacityDrag=nil,desktopLayerOpacityDrag=nil,layerScroll=nil,layerThumbs=nil,layerThumbDirty=nil,sidebarScroll=0,sidebarDrawing=false}
local function clearWandSelection()
    if A.wandOverlay then
        A.wandOverlay:release()
        A.wandOverlay=nil
    end
    A.wandSelection=nil
end
-- Cache de ImageData temporario, limitado a 1 MiB e quatro dimensoes.
local gpuUpload=GPUUpload.new({maxEntries=4,maxCacheBytes=1024*1024})
-- Visual language: neutral studio workspace, clear blue tool state and
-- compact layer controls. All painting remains inside the native canvas.
local palette={bg={.105,.119,.139},panel={.147,.167,.191},card={.194,.218,.247},line={.267,.307,.342},text={.94,.96,.98},muted={.65,.71,.76},accent={.29,.68,.98},selected={.16,.34,.48},canvas={.126,.140,.158},warn={1,.72,.35}}
-- A denser gray and charcoal editing chrome, referencing the official tool
-- and layer screenshots. The desktop palette remains untouched.
local compactPalette={bg={.60,.61,.62},panel={.205,.215,.227},
    card={.29,.305,.325},line={.43,.45,.47},
    text={.96,.97,.98},muted={.76,.79,.82},
    accent={.36,.70,1},selected={.20,.36,.53},
    canvas={.57,.58,.59},warn={1,.72,.35}}
local galleryPalette={
    bg={.915,.927,.937},panel={.985,.988,.990},
    card={1,1,1},line={.78,.81,.84},
    text={.15,.19,.23},muted={.40,.45,.50},
    accent={.16,.47,.90},selected={.82,.89,.99},
    canvas={.86,.87,.88},warn={.86,.42,.19}
}
local swatches={
    {name='Grafite',rgba=0x192d40ff},{name='Preto',rgba=0x000000ff},
    {name='Vermelho',rgba=0xe53b44ff},{name='Verde',rgba=0x20ba84ff},
    {name='Azul',rgba=0x347ce9ff},{name='Branco',rgba=0xffffffff}
}
local function c(key,alpha)
    local colors=A.screen=='gallery' and galleryPalette or
        (A.compactUi and compactPalette or palette)
    local v=colors[key]
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
local function refreshGallery()
    A.folders=A.store:folders(A.folder)
    A.projects=A.store:listProjects(A.folder)
    A.trashProjects=A.store:deletedProjects()
    A.galleryItems=A.store:galleryItems(A.folder)
end
local function setFolder(id)
    A.folder=id or '';A.galleryScroll=0
    A.galleryDetailId=nil;A.galleryDetailSwipe=nil
    A.galleryGesture=nil
    A.galleryMoveMenu=nil;A.galleryDeleteMenu=nil
    A.galleryRestoreMenu=nil;A.galleryTrash=false
    A.galleryMoreMenu=false
    A.gallerySelected={};A.gallerySelecting=false
    refreshGallery()
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
    gpuUpload:clear() -- projeto/textura completos invalidam scratch anterior
    if A.image then A.image:release() end
    if A.imageData then A.imageData:release() end
    A.imageData=love.image.newImageData(A.buffer.width,A.buffer.height,'rgba8',Native.bytes(A.buffer))
    A.image=love.graphics.newImage(A.imageData);A.image:setFilter('nearest','nearest')
    A.imageData:release();A.imageData=nil
end
-- Upload only a dirty subtexture, keeping the existing GPU Image alive.
-- Non-brush mutations continue to use rebuildImage() for full sync.
local function updateImageRegion(rect)
    if not rect then return false end
    -- Uma chamada Ink.poll pode conter dezenas de WM_POINTERUPDATE.
    -- Nao recompor/enviar a mesma textura a cada amostra do pacote;
    -- acumular a regiao e fazer um unico envio ao final do love.update.
    if A.deferInkUploads then
        A.pendingInkRect=DirtyRegion.union(A.pendingInkRect,rect)
        return true
    end
    A.layerSession:recomposeRect(rect)
    gpuUpload:send(A.image,A.buffer,rect)
    local layer=A.doc.layers[A.doc.active_layer]
    A.layerThumbDirty=A.layerThumbDirty or {}
    A.layerThumbDirty[layer.id]=true
    A.partialCanvasUpdates=(A.partialCanvasUpdates or 0)+1
    A.dirty=true
    return true
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
    assert(Native.available,'O editor requer o motor Lua compilado. A galeria continua disponível.')
    clearLayerThumbs()
    A.layerScroll=nil
    clearWandSelection()
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
local function paintBrushSegment(x,y,pressure,defer)
    if not A.drawing then return end
    local previousX,previousY=A.lastStrokeX,A.lastStrokeY
    local startPressure=A.lastPressure
    local endPressure=Pressure.normalize(pressure or startPressure)
    A.lastPressure=endPressure
    if x==previousX and y==previousY then return end
    -- Native single-pass segment interpolates from the last sample to the
    -- current sample, preserving old RGBA bytes for constant pressure.
    local diameter0,opacity0=PressureInfluence.resolve(
        A.brushDiameter,A.brushOpacity,startPressure,A.pressureCurve,
        A.pressureSize,A.pressureOpacity)
    local diameter1,opacity1=PressureInfluence.resolve(
        A.brushDiameter,A.brushOpacity,endPressure,A.pressureCurve,
        A.pressureSize,A.pressureOpacity)
    local isTilt=A.tool=='brush' and A.inkPenId~=nil and
        A.penTiltEnabled and (A.inkTiltX~=0 or A.inkTiltY~=0)
    local style=A.tool=='erase' and 2 or
        isTilt and 3 or A.brushStyle=='soft' and 1 or 0
    A.layerSession:pressureStroke(previousX,previousY,x,y,
        diameter0,diameter1,A.color,opacity0,opacity1,
        A.brushStyle=='soft' and 0.25 or 1,
        isTilt and A.inkTiltX or 0,isTilt and A.inkTiltY or 0,style,true)
    A.lastStrokeX=x;A.lastStrokeY=y
    local rect=DirtyRegion.segment(A.doc.width,A.doc.height,
        previousX,previousY,x,y,diameter0,diameter1)
    if defer then
        A.pendingBrushRect=DirtyRegion.union(A.pendingBrushRect,rect)
    else
        updateImageRegion(rect)
    end
end
-- Batch the Lua raster calls from one input packet into one composition/upload.
local function paintBrushPath(x,y,pressure,closing)
    if not A.drawing or not A.strokePath then return end
    local emit=function(px,py,p)
        paintBrushSegment(px,py,p,true)
    end
    local count
    if closing then
        count=A.strokePath:finish(x,y,pressure,emit)
    else
        count=A.strokePath:sample(x,y,pressure,emit)
    end
    if count>0 then
        updateImageRegion(A.pendingBrushRect)
    end
    A.pendingBrushRect=nil
end
local function finishStroke(finalX,finalY,pressure)
    if A.drawing and A.stabilizer then
        if finalX and finalY then
            local x,y=A.stabilizer:sample(finalX,finalY)
            paintBrushPath(x,y,pressure)
        end
        -- Closing the spatial path includes the unsmoothed release endpoint.
        local x,y=A.stabilizer:finish()
        paintBrushPath(x,y,pressure,true)
    end
    if A.layerSession and A.layerSession.pending then A.layerSession:finishEdit() end
    A.drawing=false;A.stabilizer=nil;A.strokePath=nil;A.pendingBrushRect=nil;A.lastStrokeX=nil;A.lastStrokeY=nil
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
    clearWandSelection()
    A.visualPendingTool=nil
    if A.tool~=id then A.shapePreview=nil;A.sidebarScroll=0 end
    A.tool=id
    local tab=EditorTools.panelFor(id)
    if tab then A.sideTab=tab end
    return true
end
-- The canvas gains horizontal workspace while the document/view state is
-- untouched. All editing shortcuts remain active with the pane hidden.
local function navigateCompactPanel(nextPanel)
    PopupFocus.navigate(A,nextPanel)
    love.keyboard.setTextInput(false)
end
local function toggleFocusMode()
    assert(A.screen=='editor' and A.doc,'Abra uma obra para usar o modo foco')
    finishStroke()
    A.shapePreview=nil
    A.panning=false;A.panButton=nil;A.contextMenu=nil;A.brushLibrary=false;A.sliderDrag=nil;A.quickDrag=nil
    navigateCompactPanel(nil);A.colorDrag=nil;A.desktopLayerOpacityDrag=nil
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
    navigateCompactPanel(nil);A.compactLayerStart=nil;A.colorDrag=nil
    A.desktopLayerOpacityDrag=nil
    A.compactUi=not A.compactUi
    status(A.compactUi and 'Interface compacta · barra inferior ativa' or
        'Interface desktop · painel lateral restaurado')
end
local function toggleCompactPanel(kind)
    assert(A.compactUi and A.screen=='editor','Painel compacto indisponível')
    finishStroke()
    A.shapePreview=nil;A.panning=false;A.panButton=nil
    navigateCompactPanel(A.compactPanel==kind and nil or kind)
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
    A.backMenu=false;A.settingsOpen=false
    A.galleryCreateMenu=false;A.galleryMoveMenu=nil;A.galleryScroll=0
    A.galleryGesture=nil
    A.galleryDetailId=nil;A.galleryDetailSwipe=nil
    A.galleryDeleteMenu=nil;A.galleryRestoreMenu=nil;A.galleryTrash=false
    A.galleryMoreMenu=false
    A.gallerySelecting=false;A.gallerySelected={}
    clearWandSelection()
    A.visualPendingTool=nil
    A.shapePreview=nil;A.toolHelp=false;A.contextMenu=nil;A.brushLibrary=false;A.sliderDrag=nil;A.quickDrag=nil;A.compactLayerOpacityDrag=nil;A.desktopLayerOpacityDrag=nil;A.colorDrag=nil;navigateCompactPanel(nil)
    finishStroke()
    clearLayerThumbs();A.layerScroll=nil
    if A.doc and A.dirty then saveDoc() end
    A.screen='gallery';refreshGallery()
end
-- No ibisPaint o botao Voltar abre um menu com Configuracoes
-- e retorno para A Minha Galeria. Nenhuma acao edita o documento.
local function openBackMenu()
    assert(A.screen=='editor' and A.doc,'Menu indisponivel')
    finishStroke()
    A.shapePreview=nil;A.quickDrag=nil
    A.panning=false;A.panButton=nil;A.colorDrag=nil
    navigateCompactPanel(nil)
    A.backMenu=true;A.settingsOpen=false
end
local function saveToolPreference(key,value)
    assert(key=='toolPopupColumns' or key=='toolPopupLabels'
        or key=='toolRailPosition',
        'Preferencia de interface invalida')
    local prefs={}
    for k,v in pairs(A.preferences or {}) do prefs[k]=v end
    prefs[key]=value
    A.store:setPreferences(prefs)
    A.preferences=prefs
    if key=='toolPopupColumns' then
        A.toolPopupColumns=SettingsUI.normalizeColumns(value)
        A.toolPopupPage=1
    elseif key=='toolRailPosition' then
        A.toolRailPosition=SettingsUI.normalizePosition(value)
        A.toolRailPage=1
    else
        A.toolPopupLabels=SettingsUI.labelsVisible(value)
    end
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
    elseif kind=='hue' or kind=='wheel' then
        local _,sat,bright=ColorPanel.hsb(A.color)
        local angle=kind=='wheel' and IbisPanels.wheelHue(p,x,y)
            or ColorPanel.hueAt(p,y)
        A.color=ColorPanel.fromHSB(angle,sat,bright,a)
    elseif kind=='alpha' then
        A.color=ColorPanel.rgba(r,g,b,
            ColorPanel.hsbAlphaValue(p,x))
    elseif kind:sub(1,5)=='mini-' then
        local channel=kind:sub(6)
        local value=ColorPanel.hsbMiniValue(p,channel,x)
        A.color=ColorPanel.withHSB(A.color,channel,value)
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
    if kind=='new' then
        A.modal.canvasListScroll=0
        A.modal.presetTab='basic' -- Preservado para dados de builds antigos.
    end
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
local function brushInUse()
    return {style=A.brushStyle,diameter=A.brushDiameter,
        opacity=A.brushOpacity,stabilization=A.stabilization}
end
local function brushLabSource()
    return Lab.source(A.brushFocus,Presets.custom(A.brushes),
        brushInUse())
end
local function brushLabFromFocus()
    A.brushLabDraft=brushLabSource()
    A.brushLabEdited=false;A.brushLabDrag=nil;A.brushLabKey='diameter'
end
local function resetBrushLab()
    brushLabFromFocus()
    status('Prévia restaurada · pincel em uso preservado')
end
local function adjustBrushLab(kind,x)
    local rect=Presets.layout(love.graphics.getDimensions())
    if not A.brushLabDraft then return end
    local value=Lab.value(rect,kind,x)
    A.brushLabDraft=Lab.adjust(A.brushLabDraft,kind,value)
    A.brushLabEdited=Lab.differences(brushLabSource(),
        A.brushLabDraft)>0
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
        'Prévia de cartão alterou pixels/histórico ou não atualizou Lua')
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
        'Prévia gráfica divergiu dos bytes RGBA do raster Lua')
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
    assert(clip.right==w-16 and clip.bottom==h-130,
        'Canvas compacto deve evitar os ajustes e a barra inferior')
    assert(A.zoom==zoom and A.rotation==rotation and
        A.panX==panX and A.panY==panY,
        'Mudança de layout não pode transformar documento')
    tap(2)
    assert(A.compactPanel=='tools','Botão Ferramentas não abriu a paleta')
    local p=Compact.popup(w,h,'tools')
    love.draw()
    local eraser=IbisTools.grid(p,6)
    love.mousepressed(eraser.x+eraser.w/2,eraser.y+eraser.h/2,1,false)
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
        'Brush window did not render native Lua swatches')
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
-- Stage 35 regression: edit a live Lua brush inspector with pointer drags,
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
    local appliedPreview=assert(A.brushSampleCache.inspector_active,
        'In-use Lua comparison sample must be rendered')
    local inUse=brushInUse()
    assert(appliedPreview.key==Samples.key(inUse,A.color) and
        Native.bytes(appliedPreview.sample.buffer)==
        Native.bytes(Samples.render(Native,inUse,A.color).buffer),
        'In-use comparison differs from actual Lua brush parameters')
    local updated=assert(A.brushSampleCache.inspector)
    assert(updated~=initial and
        updated.key==Samples.key(A.brushLabDraft,A.color),
        'Live Lua preview did not refresh after adjustments')
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
    assert(A.brushLabDraft.diameter==1 and A.brushLabEdited,
        'Cancel test did not edit draft independently')
    -- Restoring draft leaves the previously applied settings untouched.
    love.draw()
    local reset=Lab.resetRect(rect)
    love.mousepressed(reset.x+reset.w/2,reset.y+reset.h/2,1,false)
    assert(A.brushLibrary and A.brushLabDraft.diameter==3 and
        A.brushLabDraft.opacity==1 and
        A.brushLabEdited==false and A.brushDiameter==129,
        'Repor must restore focused preset without changing applied brush')
    love.draw()
    assert(A.brushSampleCache.inspector.key==
        Samples.key(A.brushLabDraft,A.color) and
        Native.bytes(A.layerSession.composite)==pixels and
        A.layerSession:historyStats().undo==history,
        'Restored preview must redraw native sample without editing raster')
    -- Edits can still be abandoned with Escape after a reset.
    love.mousepressed(again.x,again.y+7,1,false)
    love.mousereleased(again.x,again.y+7,1,false)
    assert(A.brushLabDraft.diameter==1,
        'Reset did not leave the inspector editable')
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
-- real LÖVE draw callback using the same independent native Lua raster.
-- Never runs without --showcase-dir and does not touch normal user projects.
-- O showcase testa cliques reais sobre os ícones da barra superior,
-- sem escrever nos projetos nem criar entradas de histórico.
local function showcaseTopClick(id,expectedTool,expectedPanel)
    assert(A.screen=='editor' and A.compactUi
        and A.layerSession and not A.modal and not A.brushLibrary)
    local before=Native.bytes(A.buffer)
    local edits=A.layerSession:historyStats().undo
    A.compactPanel=nil
    love.draw()
    local slot
    for _,item in ipairs(TopToolbar.toolbar(
        love.graphics.getDimensions())) do
        if item.id==id then slot=item;break end
    end
    assert(slot,'Ícone superior não encontrado: '..id)
    love.mousepressed(slot.x+slot.w/2,
        slot.y+slot.h/2,1,false)
    assert(A.compactPanel==expectedPanel,
        'Clique na barra superior não abriu '..expectedPanel)
    if expectedTool then
        assert(A.tool==expectedTool,
            'Ferramenta superior não selecionada: '..expectedTool)
    end
    assert(A.layerSession:historyStats().undo==edits,
        'A navegação visual não pode editar o histórico')
    assert(Native.bytes(A.buffer)==before,
        'O clique na interface alterou os pixels')
end
-- Exercita o seletor HSB como um utilizador: roda, losango e
-- slider de saturação. Os dados RBD2 e o histórico ficam intactos.
local function showcaseHSBClicks()
    assert(A.screen=='editor' and A.compactUi
        and A.compactPanel=='color' and A.colorMode=='hsb')
    local before=Native.bytes(A.buffer)
    local edits=A.layerSession:historyStats().undo
    local width,height=love.graphics.getDimensions()
    local rect=Compact.popup(width,height,'color')
    local function click(x,y)
        love.draw()
        love.mousepressed(x,y,1,false)
        love.mousereleased(x,y,1,false)
        assert(A.compactPanel=='color',
            'Ajuste de cor fechou seu próprio painel')
    end
    local wx,wy=IbisPanels.wheelPoint(rect,0)
    click(wx,wy)
    local dx,dy=ColorPanel.svPoint(rect,100,100)
    click(dx,dy)
    assert(A.color==0xff0000ff,
        'Roda e losango não selecionaram vermelho HSB puro')
    local mini=ColorPanel.hsbMiniRect(rect,'S')
    click(mini.x+mini.w*.5,mini.y+mini.h/2)
    local hue,sat,bright,alpha=ColorPanel.hsb(A.color)
    assert(hue<=1 and math.abs(sat-50)<=1 and
        bright>=99 and alpha==255,
        'Slider de saturação HSB não acompanha a prévia')
    assert(Native.bytes(A.buffer)==before,
        'Seletor HSB modificou o desenho original')
    assert(A.layerSession:historyStats().undo==edits,
        'Seleção de cor criou uma edição de raster')
end
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
        status('Ajustes compactos · prévia nativa de pincel Lua')
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
    elseif sh.stage==10 then
        A.compactPanel='tools'
        A.visualPendingTool=nil
        status('Seletor visual · 15 ferramentas e motores Lua disponíveis')
    elseif sh.stage==11 then
        toGallery()
        A.galleryFilter='all'
        modal('new')
        status('Nova tela · visualizacao de proporcao e tamanhos predefinidos')
    elseif sh.stage==12 then
        A.modal=nil
        love.keyboard.setTextInput(false)
        A.galleryFilter='works'
        status('A Minha Galeria · filtro apenas desenhos')
    elseif sh.stage==13 then
        openDoc(A.store:openProject(sh.projectId))
        A.compactUi=true
        selectTool('brush')
        showcaseTopClick('view','brush','view')
        status('Controles superiores · menu de visualização')
    elseif sh.stage==14 then
        A.stabilization=3
        showcaseTopClick('stabilizer','brush','stabilizer')
        status('Estabilização Lua · nível 3 / 5')
    elseif sh.stage==15 then
        showcaseTopClick('shape','shape','properties')
        status('Ferramentas de formas · configurações do motor Lua')
    elseif sh.stage==16 then
        showcaseTopClick('materials','shape','materials')
        status('Materiais · aparência disponível, motor pendente')
    elseif sh.stage==17 then
        selectTool('brush')
        openCompactColor()
        showcaseHSBClicks()
        status('HSB: roda, losango e saturação · clique real aprovado')
    elseif sh.stage==18 then
        A.colorMode='rgb'
        status('Cores · canais RGBA Lua')
    elseif sh.stage==19 then
        A.colorMode='palette'
        A.paletteTab='standard'
        local before=Native.bytes(A.buffer)
        local edits=A.layerSession:historyStats().undo
        local w,h=love.graphics.getDimensions()
        local p=Compact.popup(w,h,'color')
        local swatch=PaletteUI.swatch(p,7)
        love.draw()
        love.mousepressed(swatch.x+swatch.w/2,
            swatch.y+swatch.h/2,1,false)
        love.mousereleased(swatch.x+swatch.w/2,
            swatch.y+swatch.h/2,1,false)
        assert(A.color==PaletteUI.standard[7] and
            Native.bytes(A.buffer)==before and
            A.layerSession:historyStats().undo==edits,
            'Paleta básica não seleciona cor ou altera a obra')
        status('Cores básicas · 36 amostras, clique real aprovado')
    elseif sh.stage==20 then
        A.paletteTab='personal'
        status('Cores pessoais · vazia até guardar a primeira cor')
    elseif sh.stage==21 then
        A.compactPanel='layers'
        A.compactLayerStart=nil
        A.selection=nil
        status('Janela de camadas · seleção separada e raster preservado')
    elseif sh.stage==22 then
        A.compactPanel='layers'
        local w,h=love.graphics.getDimensions()
        local p=Compact.popup(w,h,'layers')
        local start,stop=Thumbnails.window(#A.doc.layers,
            A.doc.active_layer,Compact.layerRows(p),A.compactLayerStart)
        local position=stop-A.doc.active_layer+1
        assert(position>=1 and position<=stop-start+1,
            'Camada ativa deve aparecer no painel')
        local r=IbisPanels.layerRow(p,position)
        local before=Native.bytes(A.buffer)
        local undo=A.layerSession:historyStats().undo
        love.draw()
        love.mousepressed(r.x+92,r.y+35,1,false)
        love.mousereleased(r.x+92,r.y+35,1,false)
        assert(A.compactPanel=='blends',
            'Clicar no modo Normal não abriu os modos de mesclagem')
        local modes=Compact.popup(w,h,'blends')
        local pending=LayerUI.blendRow(modes,2)
        love.draw()
        love.mousepressed(pending.x+40,pending.y+17,1,false)
        love.mousereleased(pending.x+40,pending.y+17,1,false)
        assert(A.compactPanel=='blends',
            'Modo sem motor não pode mudar de painel')
        assert(Native.bytes(A.buffer)==before and
            A.layerSession:historyStats().undo==undo,
            'A navegação de mistura não pode editar a obra')
        status('Mesclagem · Normal ativo, demais modos pendentes')
    elseif sh.stage==23 then
        A.compactPanel='layers'
        A.selection={x=44,y=56,w=92,h=74}
        status('Camada de seleção · visual atualiza com área ativa')
    elseif sh.stage==24 then
        A.compactPanel='tools'
        A.visualPendingTool=nil
        local before=Native.bytes(A.buffer)
        local edits=A.layerSession:historyStats().undo
        local tool=A.tool
        local w,h=love.graphics.getDimensions()
        local panel=Compact.popup(w,h,'tools')
        local cell=IbisTools.grid(panel,4)
        love.draw()
        love.mousepressed(cell.x+cell.w/2,cell.y+cell.h/2,1,false)
        love.mousereleased(cell.x+cell.w/2,cell.y+cell.h/2,1,false)
        assert(A.compactPanel=='filters' and
            A.visualPendingTool=='filter',
            'Filtro não abriu o catálogo a partir do seletor')
        local filters=Compact.popup(w,h,'filters')
        local category=FilterUI.categoryRect(filters,2)
        love.draw()
        love.mousepressed(category.x+category.w/2,
            category.y+category.h/2,1,false)
        love.mousereleased(category.x+category.w/2,
            category.y+category.h/2,1,false)
        assert(A.filterCategory=='blur' and A.filterPage==1,
            'Categoria Desfoque não foi selecionada')
        local first=FilterUI.filterRow(filters,1)
        love.draw()
        love.mousepressed(first.x+first.w/2,first.y+first.h/2,1,false)
        love.mousereleased(first.x+first.w/2,first.y+first.h/2,1,false)
        assert(A.filterPendingId==FilterUI.pageItems('blur',1)[1].id
            and A.compactPanel=='filters' and A.tool==tool,
            'Filtro pendente não preservou o estado do editor')
        assert(Native.bytes(A.buffer)==before and
            A.layerSession:historyStats().undo==edits,
            'A navegação em filtros alterou pixels ou histórico')
        status('Filtros: categorias e lista visual · motores pendentes')
    elseif sh.stage==25 then
        A.compactPanel='tools'
        A.visualPendingTool=nil
        local before=Native.bytes(A.buffer)
        local edits=A.layerSession:historyStats().undo
        local dirty=A.dirty
        local tool=A.tool
        local w,h=love.graphics.getDimensions()
        local panel=Compact.popup(w,h,'tools')
        local cell=IbisTools.grid(panel,12)
        love.draw()
        love.mousepressed(cell.x+cell.w/2,cell.y+cell.h/2,1,false)
        love.mousereleased(cell.x+cell.w/2,cell.y+cell.h/2,1,false)
        assert(A.compactPanel=='text' and
            A.visualPendingTool=='text' and A.tool==tool,
            'Texto nao abriu painel sem mudar ferramenta')
        local p=Compact.popup(w,h,'text')
        local field=TextUI.inputRect(p)
        love.draw()
        love.mousepressed(field.x+24,field.y+24,1,false)
        love.mousereleased(field.x+24,field.y+24,1,false)
        assert(A.textUi.focused,'Editor de rascunho nao recebeu foco')
        love.textinput('Olá ibis')
        love.keypressed('backspace')
        love.textinput('!')
        assert(A.textUi.value=='Olá ibi!',
            'Entrada de texto Unicode e backspace falharam')
        local right=TextUI.alignmentRect(p,3)
        love.draw()
        love.mousepressed(right.x+right.w/2,
            right.y+right.h/2,1,false)
        love.mousereleased(right.x+right.w/2,
            right.y+right.h/2,1,false)
        assert(A.textUi.alignment=='right','Alinhamento falhou')
        assert(Native.bytes(A.buffer)==before and
            A.layerSession:historyStats().undo==edits and
            A.dirty==dirty,'Rascunho alterou desenho')
        A.showcaseTextCheck={rgba=before,undo=edits,dirty=dirty,tool=tool}
        status('Texto: entrada e alinhamento locais, sem motor')
    elseif sh.stage==26 then
        assert(A.compactPanel=='text' and A.showcaseTextCheck,
            'Painel de Texto perdido entre capturas')
        local previous=A.showcaseTextCheck
        local w,h=love.graphics.getDimensions()
        local p=Compact.popup(w,h,'text')
        local tab=TextUI.tabRect(p,3)
        love.draw()
        love.mousepressed(tab.x+tab.w/2,tab.y+tab.h/2,1,false)
        love.mousereleased(tab.x+tab.w/2,tab.y+tab.h/2,1,false)
        assert(A.textUi.tab=='style','Aba de Estilo nao abriu')
        local stroke=TextUI.propertyRow(p,3)
        love.draw()
        love.mousepressed(stroke.x+stroke.w-20,
            stroke.y+36,1,false)
        love.mousereleased(stroke.x+stroke.w-20,
            stroke.y+36,1,false)
        assert(A.textUi.stroke==1,'Controle visual de contorno falhou')
        assert(Native.bytes(A.buffer)==previous.rgba and
            A.layerSession:historyStats().undo==previous.undo and
            A.dirty==previous.dirty and A.tool==previous.tool,
            'Estilo de texto alterou o documento')
        status('Texto: parametros visuais; aplicacao pendente')
    elseif sh.stage==27 then
        local before=Native.bytes(A.buffer)
        local edits=A.layerSession:historyStats().undo
        local dirty=A.dirty
        local tool=A.tool
        showcaseTopClick('ruler',tool,'ruler')
        A.rulerUi=RulerUI.new()
        assert(A.rulerUi.previewId==nil,
            'Regua nao pode ligar guia sem motor')
        A.showcaseRulerCheck={rgba=before,undo=edits,
            dirty=dirty,tool=tool}
        status('Réguas · 8 tipos documentados, sem aplicação')
    elseif sh.stage==28 then
        assert(A.compactPanel=='ruler' and A.showcaseRulerCheck)
        local old=A.showcaseRulerCheck
        local w,h=love.graphics.getDimensions()
        local p=Compact.popup(w,h,'ruler')
        local row=RulerUI.cell(p,5)
        love.draw()
        love.mousepressed(row.x+row.w/2,row.y+row.h/2,1,false)
        love.mousereleased(row.x+row.w/2,row.y+row.h/2,1,false)
        assert(A.rulerUi.previewId=='mirror' and A.compactPanel=='ruler',
            'Espelho nao ganhou destaque visual')
        local clear=RulerUI.clear(p)
        love.draw()
        love.mousepressed(clear.x+clear.w/2,clear.y+clear.h/2,1,false)
        love.mousereleased(clear.x+clear.w/2,clear.y+clear.h/2,1,false)
        assert(A.rulerUi.previewId==nil,
            'Limpar deve remover apenas selecao visual')
        love.draw()
        love.mousepressed(row.x+row.w/2,row.y+row.h/2,1,false)
        love.mousereleased(row.x+row.w/2,row.y+row.h/2,1,false)
        assert(A.rulerUi.previewId=='mirror',
            'Selecao visual nao restaurada')
        assert(Native.bytes(A.buffer)==old.rgba
            and A.layerSession:historyStats().undo==old.undo
            and A.dirty==old.dirty and A.tool==old.tool,
            'Régua pendente alterou obra ou historico')
        status('Régua Espelho · opção destacada, motor pendente')
    elseif sh.stage==29 then
        local before=Native.bytes(A.buffer)
        local undo=A.layerSession:historyStats().undo
        local dirty=A.dirty
        local tool=A.tool
        showcaseTopClick('materials',tool,'materials')
        A.materialUi=MaterialUI.new()
        assert(#MaterialUI.items(A.materialUi)==0,
            'Nao deve existir catalogo de materiais inventado')
        A.showcaseMaterialCheck={rgba=before,undo=undo,
            dirty=dirty,tool=tool}
        status('Materiais: categorias, nenhum item local carregado')
    elseif sh.stage==30 then
        assert(A.compactPanel=='materials' and A.showcaseMaterialCheck)
        local old=A.showcaseMaterialCheck
        local w,h=love.graphics.getDimensions()
        local p=Compact.popup(w,h,'materials')
        local category=MaterialUI.categoryRect(p,4)
        love.draw()
        love.mousepressed(category.x+category.w/2,
            category.y+category.h/2,1,false)
        love.mousereleased(category.x+category.w/2,
            category.y+category.h/2,1,false)
        assert(A.materialUi.category=='backgrounds',
            'A categoria Fundos nao respondeu ao clique')
        local search=MaterialUI.searchRect(p)
        love.draw()
        love.mousepressed(search.x+15,search.y+16,1,false)
        love.mousereleased(search.x+15,search.y+16,1,false)
        assert(A.materialUi.focused,'Busca de materiais nao recebeu foco')
        love.textinput('céu')
        assert(A.materialUi.query=='céu','Busca Unicode nao atualizou')
        local action=MaterialUI.searchButton(p)
        love.draw()
        love.mousepressed(action.x+action.w/2,
            action.y+action.h/2,1,false)
        love.mousereleased(action.x+action.w/2,
            action.y+action.h/2,1,false)
        assert(A.materialUi.submittedQuery=='céu'
            and A.materialUi.searchCount==1
            and not A.materialUi.focused
            and #MaterialUI.items(A.materialUi)==0,
            'Busca pendente nao preservou estado vazio')
        assert(Native.bytes(A.buffer)==old.rgba
            and A.layerSession:historyStats().undo==old.undo
            and A.dirty==old.dirty and A.tool==old.tool,
            'Janela de materiais alterou a obra original')
        status('Materiais: busca local sem catalogo, nenhum pixel alterado')
    elseif sh.stage==31 then
        A.compactPanel='tools'
        A.visualPendingTool=nil
        local old={rgba=Native.bytes(A.buffer),
            undo=A.layerSession:historyStats().undo,
            dirty=A.dirty,tool=A.tool,
            layer=A.doc.active_layer,selection=A.selection}
        local w,h=love.graphics.getDimensions()
        local rect=Compact.popup(w,h,'tools')
        local cell=IbisTools.grid(rect,1)
        love.draw()
        love.mousepressed(cell.x+cell.w/2,cell.y+cell.h/2,1,false)
        love.mousereleased(cell.x+cell.w/2,cell.y+cell.h/2,1,false)
        assert(A.compactPanel=='transform' and
            A.visualPendingTool=='transform' and
            A.transformUi and A.transformUi.mode=='translate',
            'Transformar nao abriu a janela propria')
        assert(A.tool==old.tool and A.doc.active_layer==old.layer
            and A.selection==old.selection
            and Native.bytes(A.buffer)==old.rgba
            and A.layerSession:historyStats().undo==old.undo
            and A.dirty==old.dirty,
            'Botao Transformar acionou motor indevido')
        A.showcaseTransformCheck=old
        status('Transformar: controles visuais, motor ainda pendente')
    elseif sh.stage==32 then
        assert(A.compactPanel=='transform' and A.showcaseTransformCheck)
        local old=A.showcaseTransformCheck
        local w,h=love.graphics.getDimensions()
        local rect=Compact.popup(w,h,'transform')
        local plus=TransformUI.plusRect(rect,3)
        love.draw()
        love.mousepressed(plus.x+plus.w/2,plus.y+plus.h/2,1,false)
        love.mousereleased(plus.x+plus.w/2,plus.y+plus.h/2,1,false)
        assert(A.transformUi.zoom==105,
            'Zoom do rascunho nao respondeu ao clique')
        local mode=TransformUI.modeRect(rect,2)
        love.draw()
        love.mousepressed(mode.x+mode.w/2,mode.y+mode.h/2,1,false)
        love.mousereleased(mode.x+mode.w/2,mode.y+mode.h/2,1,false)
        assert(A.transformUi.mode=='perspective'
            and not TransformUI.canApply(),
            'Perspectiva visual nao selecionada ou aplicada falsamente')
        assert(A.tool==old.tool and A.doc.active_layer==old.layer
            and A.selection==old.selection
            and Native.bytes(A.buffer)==old.rgba
            and A.layerSession:historyStats().undo==old.undo
            and A.dirty==old.dirty,
            'Rascunho de transformar alterou raster ou selecao')
        status('Transformar: perspectiva visível, operação pendente')
    elseif sh.stage==33 then
        A.compactPanel='tools'
        A.visualPendingTool=nil
        local old={rgba=Native.bytes(A.buffer),
            undo=A.layerSession:historyStats().undo,
            dirty=A.dirty,tool=A.tool,
            layer=A.doc.active_layer,selection=A.selection}
        local w,h=love.graphics.getDimensions()
        local tools=Compact.popup(w,h,'tools')
        local wand=IbisTools.grid(tools,2)
        love.draw()
        love.mousepressed(wand.x+wand.w/2,wand.y+wand.h/2,1,false)
        love.mousereleased(wand.x+wand.w/2,wand.y+wand.h/2,1,false)
        assert(A.compactPanel=='wand'
            and A.visualPendingTool=='wand'
            and A.selectionToolUi.mode=='set',
            'Varinha não abriu um painel independente')
        local p=Compact.popup(w,h,'wand')
        local add=SelectionToolUI.modeRect(p,2)
        love.draw()
        love.mousepressed(add.x+add.w/2,add.y+add.h/2,1,false)
        love.mousereleased(add.x+add.w/2,add.y+add.h/2,1,false)
        local plus=SelectionToolUI.toleranceButton(p,1)
        love.draw()
        love.mousepressed(plus.x+plus.w/2,plus.y+plus.h/2,1,false)
        love.mousereleased(plus.x+plus.w/2,plus.y+plus.h/2,1,false)
        local gap=SelectionToolUI.toggleRect(p,1)
        love.draw()
        love.mousepressed(gap.x+gap.w/2,gap.y+gap.h/2,1,false)
        love.mousereleased(gap.x+gap.w/2,gap.y+gap.h/2,1,false)
        assert(A.selectionToolUi.mode=='add'
            and A.selectionToolUi.tolerance==15
            and A.selectionToolUi.gap,
            'Controles de Varinha não atualizaram rascunho')
        assert(A.tool==old.tool and A.doc.active_layer==old.layer
            and A.selection==old.selection
            and Native.bytes(A.buffer)==old.rgba
            and A.layerSession:historyStats().undo==old.undo
            and A.dirty==old.dirty,
            'Varinha pendente alterou o projeto real')
        A.showcaseSelectionToolCheck=old
        status('Varinha: modo Adicionar, reconhecimento visual pendente')
    elseif sh.stage==34 then
        assert(A.compactPanel=='wand' and A.showcaseSelectionToolCheck)
        local old=A.showcaseSelectionToolCheck
        local w,h=love.graphics.getDimensions()
        local p=Compact.popup(w,h,'wand')
        love.draw()
        love.mousepressed(p.x+p.w-63,p.y+23,1,false)
        love.mousereleased(p.x+p.w-63,p.y+23,1,false)
        assert(A.compactPanel=='tools',
            'Voltar da Varinha não restaurou o catálogo')
        local tools=Compact.popup(w,h,'tools')
        local lasso=IbisTools.grid(tools,3)
        love.draw()
        love.mousepressed(lasso.x+lasso.w/2,lasso.y+lasso.h/2,1,false)
        love.mousereleased(lasso.x+lasso.w/2,lasso.y+lasso.h/2,1,false)
        assert(A.compactPanel=='lasso'
            and A.visualPendingTool=='lasso'
            and A.selectionToolUi.mode=='set',
            'Laço não abriu painel próprio')
        local r=Compact.popup(w,h,'lasso')
        local subtract=SelectionToolUI.modeRect(r,3)
        love.draw()
        love.mousepressed(subtract.x+subtract.w/2,
            subtract.y+subtract.h/2,1,false)
        love.mousereleased(subtract.x+subtract.w/2,
            subtract.y+subtract.h/2,1,false)
        assert(A.selectionToolUi.mode=='subtract'
            and not SelectionToolUI.canApply(),
            'Laço não mudou modo ou aplicou seleção falsa')
        assert(A.tool==old.tool and A.doc.active_layer==old.layer
            and A.selection==old.selection
            and Native.bytes(A.buffer)==old.rgba
            and A.layerSession:historyStats().undo==old.undo
            and A.dirty==old.dirty,
            'Laço pendente alterou o projeto real')
        status('Laço: modo Subtrair visual, seleção raster pendente')
    elseif sh.stage==35 then
        A.compactPanel='tools'
        A.visualPendingTool=nil
        local old={rgba=Native.bytes(A.buffer),
            undo=A.layerSession:historyStats().undo,
            dirty=A.dirty,tool=A.tool,
            layer=A.doc.active_layer,selection=A.selection}
        local w,h=love.graphics.getDimensions()
        local chooser=Compact.popup(w,h,'tools')
        local r=IbisTools.grid(chooser,7)
        love.draw()
        love.mousepressed(r.x+r.w/2,r.y+r.h/2,1,false)
        love.mousereleased(r.x+r.w/2,r.y+r.h/2,1,false)
        assert(A.compactPanel=='smudge' and A.visualPendingTool=='smudge'
            and A.effectUi and A.effectUi.diameter==24,
            'Borrar nao abriu painel de rascunho')
        local p=Compact.popup(w,h,'smudge')
        local plus=EffectUI.paintButton(p,1,1)
        love.draw()
        love.mousepressed(plus.x+plus.w/2,plus.y+plus.h/2,1,false)
        love.mousereleased(plus.x+plus.w/2,plus.y+plus.h/2,1,false)
        assert(A.effectUi.diameter==25,'Tamanho de Borrar nao ajustou')
        A.showcaseEffectCheck=old
        assert(A.tool==old.tool and A.doc.active_layer==old.layer
            and A.selection==old.selection
            and Native.bytes(A.buffer)==old.rgba
            and A.layerSession:historyStats().undo==old.undo
            and A.dirty==old.dirty,'Borrar alterou raster ou historico')
        status('Borrar: parametros locais e motor pendente')
    elseif sh.stage==36 then
        local old=assert(A.showcaseEffectCheck)
        assert(A.compactPanel=='smudge')
        love.keypressed('escape')
        assert(A.compactPanel=='tools','Escape de Borrar nao voltou')
        local w,h=love.graphics.getDimensions()
        local r=IbisTools.grid(Compact.popup(w,h,'tools'),8)
        love.draw()
        love.mousepressed(r.x+r.w/2,r.y+r.h/2,1,false)
        love.mousereleased(r.x+r.w/2,r.y+r.h/2,1,false)
        assert(A.compactPanel=='blur' and A.visualPendingTool=='blur',
            'Desfoque nao abriu painel independente')
        local p=Compact.popup(w,h,'blur')
        local minus=EffectUI.paintButton(p,2,-1)
        love.draw()
        love.mousepressed(minus.x+minus.w/2,minus.y+minus.h/2,1,false)
        love.mousereleased(minus.x+minus.w/2,minus.y+minus.h/2,1,false)
        assert(A.effectUi.opacity==95,'Opacidade Desfoque nao mudou')
        assert(A.tool==old.tool and A.doc.active_layer==old.layer
            and A.selection==old.selection
            and Native.bytes(A.buffer)==old.rgba
            and A.layerSession:historyStats().undo==old.undo
            and A.dirty==old.dirty,'Desfoque pendente alterou documento')
        status('Desfoque: parametros visuais, sem filtro')
    elseif sh.stage==37 then
        local old=assert(A.showcaseEffectCheck)
        love.keypressed('escape')
        assert(A.compactPanel=='tools','Escape de Desfoque nao voltou')
        local w,h=love.graphics.getDimensions()
        local r=IbisTools.grid(Compact.popup(w,h,'tools'),9)
        love.draw()
        love.mousepressed(r.x+r.w/2,r.y+r.h/2,1,false)
        love.mousereleased(r.x+r.w/2,r.y+r.h/2,1,false)
        assert(A.compactPanel=='special' and
            A.visualPendingTool=='special' and
            A.effectUi.specialId=='liquify',
            'Caneta Especial nao abriu catalogo')
        local p=Compact.popup(w,h,'special')
        local copy=EffectUI.specialRect(p,5)
        love.draw()
        love.mousepressed(copy.x+copy.w/2,copy.y+copy.h/2,1,false)
        love.mousereleased(copy.x+copy.w/2,copy.y+copy.h/2,1,false)
        assert(A.effectUi.specialId=='copy-fixed',
            'Copia Fixa nao foi destacada')
        assert(A.tool==old.tool and A.doc.active_layer==old.layer
            and A.selection==old.selection
            and Native.bytes(A.buffer)==old.rgba
            and A.layerSession:historyStats().undo==old.undo
            and A.dirty==old.dirty,'Caneta especial alterou desenho')
        status('Caneta Especial: Copia Fixa destacada, sem copiar')
    elseif sh.stage==38 then
        local old=assert(A.showcaseEffectCheck)
        assert(A.compactPanel=='special')
        local w,h=love.graphics.getDimensions()
        local p=Compact.popup(w,h,'special')
        local liquify=EffectUI.specialRect(p,1)
        love.draw()
        love.mousepressed(liquify.x+liquify.w/2,
            liquify.y+liquify.h/2,1,false)
        love.mousereleased(liquify.x+liquify.w/2,
            liquify.y+liquify.h/2,1,false)
        local smooth=EffectUI.liquifyModeRect(p,4)
        love.draw()
        love.mousepressed(smooth.x+smooth.w/2,
            smooth.y+smooth.h/2,1,false)
        love.mousereleased(smooth.x+smooth.w/2,
            smooth.y+smooth.h/2,1,false)
        local plus=EffectUI.strengthButton(p,1)
        love.draw()
        love.mousepressed(plus.x+plus.w/2,plus.y+plus.h/2,1,false)
        love.mousereleased(plus.x+plus.w/2,plus.y+plus.h/2,1,false)
        assert(A.effectUi.specialId=='liquify'
            and A.effectUi.liquifyId=='smoothen'
            and A.effectUi.strength==55
            and not EffectUI.canApply(),
            'Controles Liquify nao mudaram em rascunho')
        assert(A.tool==old.tool and A.doc.active_layer==old.layer
            and A.selection==old.selection
            and Native.bytes(A.buffer)==old.rgba
            and A.layerSession:historyStats().undo==old.undo
            and A.dirty==old.dirty,
            'Liquify visual alterou documento')
        status('Liquify: suavizar e forca visuais, sem deformacao')
    elseif sh.stage==39 then
        A.compactPanel='tools'
        A.visualPendingTool=nil
        local old={rgba=Native.bytes(A.buffer),
            undo=A.layerSession:historyStats().undo,
            dirty=A.dirty,tool=A.tool,
            layer=A.doc.active_layer,selection=A.selection,
            layers=#A.doc.layers}
        local w,h=love.graphics.getDimensions()
        local r=IbisTools.grid(Compact.popup(w,h,'tools'),11)
        love.draw()
        love.mousepressed(r.x+r.w/2,r.y+r.h/2,1,false)
        love.mousereleased(r.x+r.w/2,r.y+r.h/2,1,false)
        assert(A.compactPanel=='vector' and
            A.visualPendingTool=='vector' and
            A.vectorFrameUi and A.vectorFrameUi.tab=='select',
            'Vetor nao abriu painel independente')
        local p=Compact.popup(w,h,'vector')
        local tab=VectorFrameUI.tabRect(p,3)
        love.draw()
        love.mousepressed(tab.x+tab.w/2,tab.y+tab.h/2,1,false)
        love.mousereleased(tab.x+tab.w/2,tab.y+tab.h/2,1,false)
        assert(A.vectorFrameUi.tab=='order'
            and not VectorFrameUI.canApply(),
            'Aba Ordem do vetor nao foi selecionada')
        assert(A.tool==old.tool and A.doc.active_layer==old.layer
            and A.selection==old.selection
            and #A.doc.layers==old.layers
            and Native.bytes(A.buffer)==old.rgba
            and A.layerSession:historyStats().undo==old.undo
            and A.dirty==old.dirty,
            'Vetor visual alterou documento raster')
        A.showcaseVectorFrameCheck=old
        status('Vetor: ordem sem formas, sem alteracao de camadas')
    elseif sh.stage==40 then
        local old=assert(A.showcaseVectorFrameCheck)
        assert(A.compactPanel=='vector')
        love.keypressed('escape')
        assert(A.compactPanel=='tools','Voltar do Vetor nao funcionou')
        local w,h=love.graphics.getDimensions()
        local r=IbisTools.grid(Compact.popup(w,h,'tools'),13)
        love.draw()
        love.mousepressed(r.x+r.w/2,r.y+r.h/2,1,false)
        love.mousereleased(r.x+r.w/2,r.y+r.h/2,1,false)
        assert(A.compactPanel=='frame' and
            A.visualPendingTool=='frame' and
            A.vectorFrameUi.tab=='create',
            'Dividir Quadros nao abriu popup')
        local p=Compact.popup(w,h,'frame')
        local plus=VectorFrameUI.frameStep(p,1,1)
        love.draw()
        love.mousepressed(plus.x+plus.w/2,plus.y+plus.h/2,1,false)
        love.mousereleased(plus.x+plus.w/2,plus.y+plus.h/2,1,false)
        assert(A.vectorFrameUi.horizontal==13,
            'Espacamento horizontal nao respondeu')
        assert(A.tool==old.tool and A.doc.active_layer==old.layer
            and A.selection==old.selection
            and #A.doc.layers==old.layers
            and Native.bytes(A.buffer)==old.rgba
            and A.layerSession:historyStats().undo==old.undo
            and A.dirty==old.dirty,
            'Quadro visual criou camada ou modificou raster')
        status('Dividir Quadros: parametros de rascunho, sem criar')
    elseif sh.stage==41 then
        local old=assert(A.showcaseVectorFrameCheck)
        assert(A.compactPanel=='frame')
        local w,h=love.graphics.getDimensions()
        local p=Compact.popup(w,h,'frame')
        local tab=VectorFrameUI.tabRect(p,2)
        love.draw()
        love.mousepressed(tab.x+tab.w/2,tab.y+tab.h/2,1,false)
        love.mousereleased(tab.x+tab.w/2,tab.y+tab.h/2,1,false)
        assert(A.vectorFrameUi.tab=='divide',
            'Divisao visual nao abriu')
        local cut=VectorFrameUI.cutRect(p,2)
        love.draw()
        love.mousepressed(cut.x+cut.w/2,cut.y+cut.h/2,1,false)
        love.mousereleased(cut.x+cut.w/2,cut.y+cut.h/2,1,false)
        assert(A.vectorFrameUi.cut=='horizontal'
            and not VectorFrameUI.canApply(),
            'Direcao de corte nao atualizou estado local')
        assert(A.tool==old.tool and A.doc.active_layer==old.layer
            and A.selection==old.selection
            and #A.doc.layers==old.layers
            and Native.bytes(A.buffer)==old.rgba
            and A.layerSession:historyStats().undo==old.undo
            and A.dirty==old.dirty,
            'Divisao de quadros tentou aplicar geometria real')
        status('Quadros: divisao horizontal visual, motor pendente')
    elseif sh.stage==42 then
        local old={rgba=Native.bytes(A.buffer),undo=A.layerSession:historyStats().undo,
            dirty=A.dirty,tool=A.tool,layer=A.doc.active_layer,
            selection=A.selection}
        local w,h=love.graphics.getDimensions()
        A.compactPanel='materials'
        A.materialUi=MaterialUI.new()
        local rect=MaterialUI.searchRect(Compact.popup(w,h,'materials'))
        love.draw()
        love.mousepressed(rect.x+20,rect.y+rect.h/2,1,false)
        love.mousereleased(rect.x+20,rect.y+rect.h/2,1,false)
        assert(A.materialUi.focused and love.keyboard.hasTextInput(),
            'Campo de materiais nao recebeu foco')
        love.textinput('céu')
        assert(A.materialUi.query=='céu')
        love.draw()
        love.mousepressed(110,340,1,false)
        love.mousereleased(110,340,1,false)
        assert(A.compactPanel==nil and not A.materialUi.focused
            and not love.keyboard.hasTextInput(),
            'Clique externo deixou campo ativo')
        love.textinput('X')
        assert(A.materialUi.query=='céu',
            'Campo invisivel recebeu texto')
        assert(Native.bytes(A.buffer)==old.rgba
            and A.layerSession:historyStats().undo==old.undo
            and A.dirty==old.dirty and A.tool==old.tool
            and A.doc.active_layer==old.layer
            and A.selection==old.selection,
            'Fechar popup alterou documento')
        A.showcaseFocusCheck=old
        status('Auditoria: busca encerrada sem pintar')
    elseif sh.stage==43 then
        local old=assert(A.showcaseFocusCheck)
        local w,h=love.graphics.getDimensions()
        A.compactPanel='tools'
        local c=IbisTools.grid(Compact.popup(w,h,'tools'),12)
        love.draw()
        love.mousepressed(c.x+c.w/2,c.y+c.h/2,1,false)
        love.mousereleased(c.x+c.w/2,c.y+c.h/2,1,false)
        assert(A.compactPanel=='text' and A.textUi)
        local input=TextUI.inputRect(Compact.popup(w,h,'text'))
        love.draw()
        love.mousepressed(input.x+20,input.y+20,1,false)
        love.mousereleased(input.x+20,input.y+20,1,false)
        assert(A.textUi.focused and love.keyboard.hasTextInput())
        love.textinput('Revisão')
        assert(A.textUi.value=='Revisão')
        toggleCompactUi()
        assert(not A.compactUi and A.compactPanel==nil
            and not A.textUi.focused and not love.keyboard.hasTextInput(),
            'Modo Desktop deixou teclado ligado')
        love.textinput('X')
        assert(A.textUi.value=='Revisão',
            'Texto oculto foi alterado')
        toggleCompactUi()
        assert(A.compactUi and not love.keyboard.hasTextInput(),
            'Modo Compacto reativou teclado')
        assert(Native.bytes(A.buffer)==old.rgba
            and A.layerSession:historyStats().undo==old.undo
            and A.dirty==old.dirty and A.tool==old.tool
            and A.doc.active_layer==old.layer
            and A.selection==old.selection,
            'Troca de layout alterou documento')
        status('Auditoria: texto guardado, entrada desativada')
    elseif sh.stage==44 then
        A.compactPanel=nil
        A.visualPendingTool=nil
        A.toolRailPage=1
        selectTool('brush')
        local w,h=love.graphics.getDimensions()
        local all=EditorRail.entries(w,h,1,IbisTools.entries)
        assert(#all==#IbisTools.entries,
            'Viewport amplo deveria mostrar todas as 15 ferramentas')
        local old={rgba=Native.bytes(A.buffer),
            undo=A.layerSession:historyStats().undo,
            dirty=A.dirty,layer=A.doc.active_layer,tool=A.tool}
        A.showcaseRailCheck=old
        love.draw()
        assert(Native.bytes(A.buffer)==old.rgba
            and A.layerSession:historyStats().undo==old.undo
            and A.dirty==old.dirty,
            'Nova faixa de ferramentas alterou raster')
        status('Editor: faixa lateral, barra inferior e sliders em duas linhas')
    elseif sh.stage==45 then
        local old=assert(A.showcaseRailCheck)
        local w,h=love.graphics.getDimensions()
        local row=EditorRail.entries(w,h,1,IbisTools.entries)[7]
        assert(row.id=='smudge')
        love.draw()
        love.mousepressed(row.x+row.w/2,row.y+row.h/2,1,false)
        love.mousereleased(row.x+row.w/2,row.y+row.h/2,1,false)
        assert(A.compactPanel=='smudge' and A.visualPendingTool=='smudge',
            'Faixa lateral nao abriu o painel Borrar')
        assert(Native.bytes(A.buffer)==old.rgba
            and A.layerSession:historyStats().undo==old.undo
            and A.dirty==old.dirty and A.doc.active_layer==old.layer
            and A.tool==old.tool,
            'Barra lateral nao pode acionar outro motor')
        status('Faixa original: ferramenta Borrar aberta com clique real')
    elseif sh.stage==46 then
        local before={pixels=Native.bytes(A.buffer),
            undo=A.layerSession:historyStats().undo,
            dirty=A.dirty,layer=A.doc.active_layer,
            tool=A.tool,selection=A.selection}
        A.compactPanel='tools'
        A.visualPendingTool=nil
        A.showcasePopupVisualCheck=before
        local w,h=love.graphics.getDimensions()
        local popup=Compact.popup(w,h,'tools')
        assert(popup.w==242 and popup.h==383
            and popup.x==85 and popup.y+popup.h<=h-127,
            'Seletor de 2 colunas incorreto')
        assert(Native.bytes(A.buffer)==before.pixels
            and A.layerSession:historyStats().undo==before.undo
            and A.dirty==before.dirty,
            'Paleta de ferramentas modificou raster')
        status('Ferramentas: paleta flutuante de duas colunas')
    elseif sh.stage==47 then
        local before=assert(A.showcasePopupVisualCheck)
        A.compactPanel='layers'
        local w,h=love.graphics.getDimensions()
        local popup=Compact.popup(w,h,'layers')
        assert(popup.x>=w/2 and popup.y>=134
            and popup.y+popup.h<=h-130,
            'Janela de camadas nao acompanha canto inferior direito')
        assert(Native.bytes(A.buffer)==before.pixels
            and A.layerSession:historyStats().undo==before.undo
            and A.doc.active_layer==before.layer
            and A.dirty==before.dirty and A.tool==before.tool
            and A.selection==before.selection,
            'Navegacao de janelas alterou projeto')
        status('Camadas: janela ancorada junto ao rodape')
    elseif sh.stage==48 then
        A.compactPanel='layers'
        local w,h=love.graphics.getDimensions()
        local p=Compact.popup(w,h,'layers')
        assert(p.h>=350,'Janela de camadas precisa caber')
        A.showcaseLayerChromeCheck={pixels=Native.bytes(A.layerSession.composite),
            undo=A.layerSession:historyStats().undo,active=A.doc.active_layer}
        status('Camadas: seleção rosa e camada ativa azul')
    elseif sh.stage==49 then
        local old=assert(A.showcaseLayerChromeCheck)
        local count=#A.doc.layers
        assert(count>=2 and A.compactPanel=='layers',
            'Camadas devem continuar abertas')
        local target=A.doc.active_layer==1 and 2 or 1
        local w,h=love.graphics.getDimensions()
        local p=Compact.popup(w,h,'layers')
        local start,stop=Thumbnails.window(count,A.doc.active_layer,
            Compact.layerRows(p),A.compactLayerStart)
        local row=stop-target+1
        assert(row>=1 and row<=Compact.layerRows(p),
            'Camada alternativa nao esta visivel')
        local rect=IbisPanels.layerRow(p,row)
        love.draw()
        love.mousepressed(rect.x+rect.w/2,rect.y+14,1,false)
        love.mousereleased(rect.x+rect.w/2,rect.y+14,1,false)
        assert(A.doc.active_layer==target,
            'Clique na camada nao alterou camada ativa')
        assert(Native.bytes(A.layerSession.composite)==old.pixels,
            'Troca de camada modificou pixels compostos')
        status('Camadas: destaque acompanha a selecao real')
    elseif sh.stage==50 then
        assert(A.compactPanel=='layers')
        local w,h=love.graphics.getDimensions()
        local p=Compact.popup(w,h,'layers')
        local header=LayerChrome.toolbar(p,'top')
        local footer=LayerChrome.toolbar(p,'footer')
        assert(#header==3 and #footer==4
            and header[1].id=='add' and footer[4].id=='merge',
            'Comandos de camadas ausentes')
        A.showcaseLayerActionsCheck={
            pixels=Native.bytes(A.layerSession.composite),
            count=#A.doc.layers,
            undo=A.layerSession:historyStats().undo}
        status('Camadas: comandos compactos com callbacks originais')
    elseif sh.stage==51 then
        local old=assert(A.showcaseLayerActionsCheck)
        local w,h=love.graphics.getDimensions()
        local p=Compact.popup(w,h,'layers')
        local slot=LayerChrome.toolbar(p,'top')[1]
        love.draw()
        love.mousepressed(slot.x+slot.w/2,
            slot.y+slot.h/2,1,false)
        love.mousereleased(slot.x+slot.w/2,
            slot.y+slot.h/2,1,false)
        assert(#A.doc.layers==old.count+1,
            'Adicionar nao chamou o motor de camadas Lua')
        assert(Native.bytes(A.layerSession.composite)==old.pixels,
            'Adicionar uma camada vazia alterou pixels do desenho')
        assert(A.compactPanel=='layers',
            'Adicionar fechou a janela de camadas')
        status('Camadas: nova camada criada pelo controle visual')
    elseif sh.stage==52 then
        local old=assert(A.showcaseLayerActionsCheck)
        local w,h=love.graphics.getDimensions()
        local p=Compact.popup(w,h,'layers')
        local slot=LayerChrome.toolbar(p,'top')[2]
        love.draw()
        love.mousepressed(slot.x+slot.w/2,
            slot.y+slot.h/2,1,false)
        love.mousereleased(slot.x+slot.w/2,
            slot.y+slot.h/2,1,false)
        assert(#A.doc.layers==old.count+2,
            'Duplicar nao chamou o motor de camadas Lua')
        assert(Native.bytes(A.layerSession.composite)==old.pixels,
            'Duplicar camada vazia alterou pixels do desenho')
        assert(A.compactPanel=='layers',
            'Duplicar fechou a janela')
        status('Camadas: nova camada duplicada pela barra compacta')
    elseif sh.stage==53 then
        assert(A.compactPanel=='layers')
        local w,h=love.graphics.getDimensions()
        local p=Compact.popup(w,h,'layers')
        local footer=LayerChrome.footerControls(p)
        assert(#footer==3 and not footer[1].available
            and footer[2].available and footer[3].available,
            'Alpha Lock deve estar habilitado; Clipping continua pendente')
        local before=Native.bytes(A.layerSession.composite)
        A.showcaseFooterProof={pixels=before,
            history=A.layerSession:historyStats().undo,
            layers=#A.doc.layers,active=A.doc.active_layer}
        status('Rodape: Alpha Lock disponivel; Clipping pendente')
    elseif sh.stage==54 then
        local old=assert(A.showcaseFooterProof)
        local w,h=love.graphics.getDimensions()
        local slot=LayerChrome.footerControls(
            Compact.popup(w,h,'layers'))[3]
        love.draw()
        love.mousepressed(slot.x+slot.w/2,slot.y+slot.h/2,1,false)
        love.mousereleased(slot.x+slot.w/2,slot.y+slot.h/2,1,false)
        assert(A.compactPanel=='blends',
            'Modo Normal do rodape nao abriu mesclagem')
        assert(Native.bytes(A.layerSession.composite)==old.pixels
            and A.layerSession:historyStats().undo==old.history
            and #A.doc.layers==old.layers
            and A.doc.active_layer==old.active,
            'Abrir mesclagem pelo rodape alterou o desenho')
        status('Rodape: mesclagem abriu sem editar o documento')
    elseif sh.stage==55 then
        A.compactPanel=nil
        A.visualPendingTool='wand'
        A.selectionToolUi=SelectionToolUI.new('wand')
        A.selectionToolUi.continuous=true
        local old=Native.bytes(A.layerSession.composite)
        local edits=A.layerSession:historyStats().undo
        local w,h=love.graphics.getDimensions()
        local sx,sy=View.center(viewData(),w,h)
        love.draw()
        love.mousepressed(sx,sy,1,false)
        love.mousereleased(sx,sy,1,false)
        assert(A.wandSelection and A.wandSelection.count>0
            and A.wandOverlay,
            'Clique real da varinha nao criou a mascara')
        assert(Native.bytes(A.layerSession.composite)==old
            and A.layerSession:historyStats().undo==edits,
            'Varinha nao pode alterar composicao nem historico')
        A.showcaseWandProof={pixels=old,undo=edits}
        status(('Varinha: máscara RGBA de %d pixels'):format(A.wandSelection.count))
    elseif sh.stage==56 then
        local proof=assert(A.showcaseWandProof)
        clearWandSelection()
        A.visualPendingTool='lasso'
        A.selectionToolUi=SelectionToolUI.new('lasso')
        local w,h=love.graphics.getDimensions()
        local sx,sy=View.center(viewData(),w,h)
        local previousTool=A.tool
        love.draw()
        love.mousepressed(sx,sy,1,false)
        love.mousereleased(sx,sy,1,false)
        assert(A.tool==previousTool and not A.drawing,
            'Ferramenta pendente chamou motor do pincel')
        assert(Native.bytes(A.layerSession.composite)==proof.pixels
            and A.layerSession:historyStats().undo==proof.undo,
            'Laço pendente nao pode editar o canvas')
        status('Laço pendente: clique não aciona o pincel anterior')
    elseif sh.stage==57 then
        A.visualPendingTool=nil
        A.compactUi=true
        A.compactPanel='tools'
        A.toolPopupColumns=1
        A.toolPopupPage=1
        status('Ferramentas · uma coluna, 7 itens por pagina')
    elseif sh.stage==58 then
        local old=Native.bytes(A.layerSession.composite)
        local undo=A.layerSession:historyStats().undo
        local w,h=love.graphics.getDimensions()
        local p=Compact.popup(w,h,'tools',1)
        local nextPage=IbisTools.pageButton(p,1)
        love.draw()
        love.mousepressed(nextPage.x+nextPage.w/2,
            nextPage.y+nextPage.h/2,1,false)
        love.mousereleased(nextPage.x+nextPage.w/2,
            nextPage.y+nextPage.h/2,1,false)
        assert(A.toolPopupPage==2 and A.toolPopupColumns==1,
            'Botao de pagina nao navegou em uma coluna')
        assert(Native.bytes(A.layerSession.composite)==old and
            A.layerSession:historyStats().undo==undo,
            'Navegacao do seletor nao pode alterar o raster')
        status('Ferramentas · uma coluna, segunda pagina')
    elseif sh.stage==59 then
        local old=Native.bytes(A.layerSession.composite)
        local undo=A.layerSession:historyStats().undo
        local w,h=love.graphics.getDimensions()
        openBackMenu()
        love.draw()
        local menu=SettingsUI.menuItem(SettingsUI.menu(w,h),2)
        love.mousepressed(menu.x+menu.w/2,menu.y+menu.h/2,1,false)
        assert(A.settingsOpen and not A.backMenu,
            'Voltar nao abriu Configuracoes')
        love.draw()
        local p=SettingsUI.panel(w,h)
        local three=SettingsUI.columnRect(p,3)
        love.mousepressed(three.x+three.w/2,
            three.y+three.h/2,1,false)
        assert(A.toolPopupColumns==3 and A.toolPopupPage==1
            and A.store:getPreferences().toolPopupColumns==3,
            'Tres colunas nao foram aplicadas/persistidas')
        local close=SettingsUI.closeRect(p)
        love.draw()
        love.mousepressed(close.x+close.w/2,
            close.y+close.h/2,1,false)
        assert(not A.settingsOpen,'Concluir nao fechou Configuracoes')
        A.compactPanel='tools'
        assert(Native.bytes(A.layerSession.composite)==old and
            A.layerSession:historyStats().undo==undo,
            'Configuracao visual nao pode alterar o raster')
        status('Ferramentas · tres colunas, quinze categorias')
    elseif sh.stage==60 then
        openBackMenu()
        assert(A.backMenu and not A.compactPanel,
            'Botao Voltar deve ter menu independente')
        status('Menu Voltar: Galeria, Configurações e Cancelar')
    elseif sh.stage==61 then
        local old=Native.bytes(A.layerSession.composite)
        local undo=A.layerSession:historyStats().undo
        local w,h=love.graphics.getDimensions()
        love.draw()
        local item=SettingsUI.menuItem(SettingsUI.menu(w,h),2)
        love.mousepressed(item.x+item.w/2,
            item.y+item.h/2,1,false)
        assert(A.settingsOpen and not A.backMenu,
            'Opcao Configuracoes nao abriu')
        assert(Native.bytes(A.layerSession.composite)==old
            and A.layerSession:historyStats().undo==undo,
            'Abrir Configuracoes alterou documento')
        status('Configurações: Popup e número de colunas')
    elseif sh.stage==62 then
        local old=Native.bytes(A.layerSession.composite)
        local undo=A.layerSession:historyStats().undo
        local w,h=love.graphics.getDimensions()
        local p=SettingsUI.panel(w,h)
        local off=SettingsUI.labelRect(p,2)
        love.draw()
        love.mousepressed(off.x+off.w/2,off.y+off.h/2,1,false)
        assert(not A.toolPopupLabels and
            A.store:getPreferences().toolPopupLabels==false,
            'Opcao Mostrar Nomes nao persistiu')
        local close=SettingsUI.closeRect(p)
        love.draw()
        love.mousepressed(close.x+close.w/2,
            close.y+close.h/2,1,false)
        assert(not A.settingsOpen,'Configuracoes nao fechou')
        A.compactPanel='tools'
        assert(Native.bytes(A.layerSession.composite)==old and
            A.layerSession:historyStats().undo==undo,
            'Mudanca visual de rotulos alterou raster')
        status('Ferramentas: nomes desativados, ícones mantidos')
    elseif sh.stage==63 then
        toGallery()
        A.galleryFilter='all'
        local sample=Native.buffer(96,96)
        for i=1,18 do
            Native.clear(sample,0)
            Native.basicStroke(sample,8,10+(i%5)*6,86,81,9,
                (i%2==0) and 0x338adfff or 0xe17caaff,1)
            A.store:createProject(('Ilustração %02d'):format(i),
                96,96,'',Native.bytes(sample))
        end
        refreshGallery()
        assert(#A.projects>=18,'Galeria nao criou obras de prova')
        A.galleryScroll=0
        status('Galeria em grade compacta · miniaturas reais')
    elseif sh.stage==64 then
        local before=Native.bytes(A.layerSession.composite)
        local history=A.layerSession:historyStats().undo
        love.wheelmoved(0,-7)
        assert((A.galleryScroll or 0)>0,
            'Roda do mouse nao percorreu a galeria')
        assert(Native.bytes(A.layerSession.composite)==before
            and A.layerSession:historyStats().undo==history,
            'Scroll de galeria nao pode alterar documento')
        status('Galeria: rolagem independente das obras')
    elseif sh.stage==65 then
        A.galleryScroll=0
        love.draw()
        local w,h=love.graphics.getDimensions()
        love.mousepressed(w-82,27,1,false)
        assert(A.gallerySelecting,
            'Selecionar nao ativou o estado visual')
        love.draw()
        local r=GalleryShell.card(w,h,1,0)
        love.mousepressed(r.x+r.w/2,r.y+r.h/2,1,false)
        local selected=0
        for _,v in pairs(A.gallerySelected) do
            if v then selected=selected+1 end
        end
        assert(selected==1 and A.screen=='gallery',
            'Selecao visual nao deve abrir nem editar obra')
        status('Galeria: seleção visual · ações em lote pendentes')
    elseif sh.stage==66 then
        openDoc(A.store:openProject(sh.projectId))
        A.compactUi=true
        selectTool('brush')
        A.stabilization=2
        A.stabilizerVisual=IbisPanels.stabilizer.new()
        A.compactPanel='stabilizer'
        status('14.1 · Tempo real com Constante e Traços rápidos')
    elseif sh.stage==67 then
        local old=Native.bytes(A.layerSession.composite)
        local history=A.layerSession:historyStats().undo
        -- Usa a geometria real do popup da barra superior.
        local w,h=love.graphics.getDimensions()
        local p=Compact.popup(w,h,'stabilizer')
        local tab=IbisPanels.stabilizer.tabRect(p,2)
        love.draw()
        love.mousepressed(tab.x+tab.w/2,tab.y+tab.h/2,1,false)
        assert(A.stabilizerVisual.tab=='fade',
            'Aba Fade nao abriu com clique real')
        assert(Native.bytes(A.layerSession.composite)==old
            and A.layerSession:historyStats().undo==history,
            'Navegacao Fade nao pode alterar raster')
        status('14.1 · Fade e comprimentos (prévia pendente)')
    elseif sh.stage==68 then
        local before=Native.bytes(A.layerSession.composite)
        local history=A.layerSession:historyStats().undo
        local previous=A.stabilization
        local w,h=love.graphics.getDimensions()
        local p=Compact.popup(w,h,'stabilizer')
        local tab=IbisPanels.stabilizer.tabRect(p,1)
        love.draw()
        love.mousepressed(tab.x+tab.w/2,tab.y+tab.h/2,1,false)
        assert(A.stabilizerVisual.tab=='stabilization')
        for i=1,2 do
            local step=IbisPanels.stabilizer.draftButton(p,i,1)
            love.draw()
            love.mousepressed(step.x+step.w/2,
                step.y+step.h/2,1,false)
        end
        assert(A.stabilizerVisual.constant==10 and
            A.stabilizerVisual.fast==10 and A.stabilization==previous,
            'Ajustes novos nao podem fingir aplicacao no motor Lua')
        assert(Native.bytes(A.layerSession.composite)==before
            and A.layerSession:historyStats().undo==history,
            'Rascunho de estabilizador modificou pixels')
        status('14.1 · rascunho dos dois modos, motor preservado')
    elseif sh.stage==69 then
        local w,h=love.graphics.getDimensions()
        local p=Compact.popup(w,h,'stabilizer')
        local legacy=IbisPanels.stabilizer.legacyRow(p)
        local before=Native.bytes(A.layerSession.composite)
        local history=A.layerSession:historyStats().undo
        local old=A.stabilization
        love.draw()
        love.mousepressed(legacy.x+legacy.w-18,
            legacy.y+30,1,false)
        assert(A.stabilization==old+1,
            'Estabilizador legado deixou de ser funcional')
        assert(Native.bytes(A.layerSession.composite)==before
            and A.layerSession:historyStats().undo==history,
            'Ajuste legado nao deve modificar pixels existentes')
        status(('Legado Lua: nível %d / 5 aplicado'):format(A.stabilization))
    elseif sh.stage==70 then
        toGallery()
        A.galleryFilter='all'
        modal('new')
        assert(A.modal and A.modal.kind=='new' and
            A.modal.canvasListScroll==0,
            'A lista original nao abriu no topo')
        A.showcaseCanvasProof={
            count=#A.projects,
            pixels=Native.bytes(A.layerSession.composite),
            undo=A.layerSession:historyStats().undo}
        local w,h=love.graphics.getDimensions()
        local rect=IbisPanels.canvasReference.layout(w,h)
        -- Clique e arraste no W/H; mesmos controles funcionais
        -- do formulario anterior, mas na geometria da lista.
        local plus=IbisPanels.canvasReference.stepper(rect,2,1)
        love.draw()
        love.mousepressed(plus.x+15,plus.y+14,1,false)
        assert(A.modal.values[2]=='528','W + nao atualizou largura')
        local minus=IbisPanels.canvasReference.stepper(rect,2,-1)
        love.draw()
        love.mousepressed(minus.x+15,minus.y+14,1,false)
        assert(A.modal.values[2]=='512','W - nao restaurou largura')
        for _,axis in ipairs({2,3}) do
            local track=IbisPanels.canvasReference.slider(rect,axis)
            local cy=track.y+track.h/2
            love.draw()
            love.mousepressed(track.x+track.w,cy,1,false)
            assert(A.canvasDimensionDrag==axis and
                A.modal.values[axis]=='2048',
                'Slider nao alcancou o limite do motor Lua')
            love.mousemoved(track.x-30,cy,0,0,false)
            assert(A.modal.values[axis]=='1',
                'Slider nao respeitou o minimo de 1 pixel')
            local restore=GalleryUI.sliderPosition(track,512)
            love.mousemoved(restore,cy,0,0,false)
            love.mousereleased(restore,cy,1,false)
            assert(A.canvasDimensionDrag==nil
                and A.modal.values[axis]=='512',
                'Slider nao restaurou o tamanho inicial')
        end
        assert(#A.projects==A.showcaseCanvasProof.count
            and Native.bytes(A.layerSession.composite)==
                A.showcaseCanvasProof.pixels
            and A.layerSession:historyStats().undo==
                A.showcaseCanvasProof.undo,
            'Escolher tamanho alterou Store, raster ou undo')
        status('Nova tela: lista de formatos do tutorial publico')
    elseif sh.stage==71 then
        local w,h=love.graphics.getDimensions()
        local r=IbisPanels.canvasReference.layout(w,h)
        local proof=assert(A.showcaseCanvasProof)
        love.draw()
        assert(IbisPanels.canvasReference.item('square-sd').w==1280
            and IbisPanels.canvasReference.item('sd').h==1344
            and not IbisPanels.canvasReference.allowed(
                IbisPanels.canvasReference.item('vertical')),
            'Lista oficial nao possui formatos e limites corretos')
        local row,visible=IbisPanels.canvasReference.row(
            r,'square-sd',A.modal.canvasListScroll)
        assert(visible,'Formato 1:1 nao aparece no inicio')
        love.mousepressed(row.x+row.w/2,row.y+row.h/2,1,false)
        assert(A.modal.values[2]=='1280'
            and A.modal.values[3]=='1280',
            'Formato 1:1 SD nao atualizou o formulario')
        assert(#A.projects==proof.count,
            'Escolha de formato criou projeto sem confirmacao')
        status('Nova tela: formato 1:1 SD 1280×1280')
    elseif sh.stage==72 then
        local w,h=love.graphics.getDimensions()
        local r=IbisPanels.canvasReference.layout(w,h)
        local row,visible=IbisPanels.canvasReference.row(
            r,'portrait-sd',A.modal.canvasListScroll)
        assert(visible,'Formato 3:4 fora da lista visivel')
        love.draw()
        love.mousepressed(row.x+row.w/2,row.y+row.h/2,1,false)
        assert(A.modal.values[2]=='768'
            and A.modal.values[3]=='1024',
            'Formato 3:4 SD nao atualizou largura/altura')
        status('Nova tela: formato 3:4 SD 768×1024')
    elseif sh.stage==73 then
        local w,h=love.graphics.getDimensions()
        local r=IbisPanels.canvasReference.layout(w,h)
        A.modal.canvasListScroll=IbisPanels.canvasReference.maxScroll(r)
        local row,visible=IbisPanels.canvasReference.row(
            r,'a4',A.modal.canvasListScroll)
        assert(visible,'A4 nao ficou visivel apos rolagem')
        love.draw()
        love.mousepressed(row.x+row.w/2,row.y+row.h/2,1,false)
        assert(A.modal.values[2]=='1240'
            and A.modal.values[3]=='1754',
            'A4 nao atualizou dimensoes')
        status('Nova tela: A4 1240×1754, sem DPI operacional')
    elseif sh.stage==74 then
        local w,h=love.graphics.getDimensions()
        local r=IbisPanels.canvasReference.layout(w,h)
        local proof=assert(A.showcaseCanvasProof)
        A.modal.canvasListScroll=IbisPanels.canvasReference.maxScroll(r)
        local row,visible=IbisPanels.canvasReference.row(
            r,'legacy-square',A.modal.canvasListScroll)
        assert(visible,'Preset legado nao visivel no fim da lista')
        love.draw()
        love.mousepressed(row.x+row.w/2,row.y+row.h/2,1,false)
        assert(A.modal.values[2]=='512'
            and A.modal.values[3]=='512',
            'Preset legado 512×512 deixou de funcionar')
        assert(#A.projects==proof.count
            and Native.bytes(A.layerSession.composite)==proof.pixels
            and A.layerSession:historyStats().undo==proof.undo,
            'Navegacao de formatos alterou raster ou historico')
        status('Nova tela: formatos anteriores preservados')
    elseif sh.stage==75 then
        -- Verificar o X novo pela GUI real, sem cancelar por atribuicao.
        assert(A.modal and A.modal.kind=='new',
            'Nova tela desapareceu antes da prova de fechar')
        local w,h=love.graphics.getDimensions()
        local close=IbisPanels.canvasReference.close(IbisPanels.canvasReference.layout(w,h))
        local proof=assert(A.showcaseCanvasProof)
        love.draw()
        love.mousepressed(close.x+close.w/2,
            close.y+close.h/2,1,false)
        assert(A.modal==nil and #A.projects==proof.count
            and Native.bytes(A.layerSession.composite)==proof.pixels
            and A.layerSession:historyStats().undo==proof.undo,
            'Fechar X nao encerrou Nova tela ou alterou RBD2')
        love.keyboard.setTextInput(false)
        A.galleryScroll=0
        A.galleryFilter='all'
        A.gallerySelecting=true
        A.gallerySelected={}
        local r=GalleryShell.card(w,h,1,0)
        A.showcaseGallerySelection={
            projects=#A.projects,
            folders=#A.folders,
            pixels=Native.bytes(A.layerSession.composite),
            undo=A.layerSession:historyStats().undo}
        love.draw()
        love.mousepressed(r.x+r.w/2,r.y+r.h/2,1,false)
        local keys=GalleryShell.selectionKeys(
            A.folders,A.projects,A.galleryFilter)
        assert(GalleryShell.selectionCount(A.gallerySelected,keys)==1,
            'Modo selecao nao marcou a miniatura')
        status('Galeria: 1 selecionado; Mover/Excluir pendentes')
    elseif sh.stage==76 then
        local w,h=love.graphics.getDimensions()
        local r=GalleryShell.selectionAction(w,h,'all')
        love.draw()
        love.mousepressed(r.x+r.w/2,r.y+r.h/2,1,false)
        local keys=GalleryShell.selectionKeys(
            A.folders,A.projects,A.galleryFilter)
        assert(#keys>1 and GalleryShell.selectionCount(
            A.gallerySelected,keys)==#keys,
            'Selecionar Todos nao marcou o catalogo visivel')
        local proof=assert(A.showcaseGallerySelection)
        assert(#A.projects==proof.projects and
            #A.folders==proof.folders and
            Native.bytes(A.layerSession.composite)==proof.pixels and
            A.layerSession:historyStats().undo==proof.undo,
            'Selecao multipla alterou arquivos ou raster')
        status('Galeria: todos os itens visiveis marcados')
    elseif sh.stage==77 then
        local w,h=love.graphics.getDimensions()
        local r=GalleryShell.selectionAction(w,h,'clear')
        love.draw()
        love.mousepressed(r.x+r.w/2,r.y+r.h/2,1,false)
        local keys=GalleryShell.selectionKeys(
            A.folders,A.projects,A.galleryFilter)
        assert(GalleryShell.selectionCount(A.gallerySelected,keys)==0
            and A.gallerySelecting,
            'Limpar selecao alterou o modo ou manteve marcas')
        status('Galeria: selecao limpa sem perder o modo')
    elseif sh.stage==78 then
        local w,h=love.graphics.getDimensions()
        local card=GalleryShell.card(w,h,1,0)
        love.draw()
        love.mousepressed(card.x+card.w/2,card.y+card.h/2,1,false)
        local keys=GalleryShell.selectionKeys(
            A.folders,A.projects,A.galleryFilter)
        assert(GalleryShell.selectionCount(A.gallerySelected,keys)==1)
        local action=GalleryShell.selectionAction(w,h,'delete')
        love.draw()
        love.mousepressed(action.x+action.w/2,
            action.y+action.h/2,1,false)
        assert(A.galleryDeleteMenu and #A.galleryDeleteMenu.ids==1,
            'Excluir deve exigir confirmacao')
        local dialog=GalleryShell.confirmPopup(w,h)
        local cancel=GalleryShell.confirmCancel(dialog)
        love.draw()
        love.mousepressed(cancel.x+cancel.w/2,
            cancel.y+cancel.h/2,1,false)
        local proof=assert(A.showcaseGallerySelection)
        assert(A.screen=='gallery' and A.gallerySelecting and
            GalleryShell.selectionCount(A.gallerySelected,keys)==1
            and not A.galleryDeleteMenu and
            not A.galleryCreateMenu and not A.galleryMoveMenu,
            'Cancelar exclusao nao retornou a selecao')
        assert(#A.projects==proof.projects and
            #A.folders==proof.folders and
            Native.bytes(A.layerSession.composite)==proof.pixels and
            A.layerSession:historyStats().undo==proof.undo,
            'Cancelar alterou documentos')
        status('Galeria: Excluir exige confirmacao e permite cancelar')
    elseif sh.stage==79 then
        A.gallerySelecting=true
        A.gallerySelected={}
        A.galleryMoveMenu=nil
        A.galleryFilter='all'
        A.galleryScroll=0
        local dest=A.store:createFolder('Arquivo Final',A.folder)
        A.showcaseDestinationId=dest
        refreshGallery()
        local w,h=love.graphics.getDimensions()
        local item=GalleryShell.card(w,h,#A.folders+1,0)
        local first=A.projects[1]
        assert(first,'Nenhuma obra de teste para mover')
        A.showcaseMoveId=first.id
        love.draw()
        love.mousepressed(item.x+item.w/2,item.y+item.h/2,1,false)
        assert(A.gallerySelected['p:'..first.id],
            'Obra nao selecionada antes de mover')
        love.draw()
        local move=GalleryShell.selectionAction(w,h,'move')
        love.mousepressed(move.x+move.w/2,move.y+move.h/2,1,false)
        assert(A.galleryMoveMenu and #A.galleryMoveMenu.ids==1,
            'Mover nao abriu escolha de pasta')
        status('Mover desenho · selecionar pasta de destino')
    elseif sh.stage==80 then
        local w,h=love.graphics.getDimensions()
        local p=GalleryShell.movePopup(w,h)
        local list=GalleryShell.folderChoices(
            A.store.catalog.folders,A.folder)
        assert(#list==1 and list[1].id==A.showcaseDestinationId,
            'Destino de teste nao encontrado')
        local row=GalleryShell.moveRow(p,1)
        love.draw()
        love.mousepressed(row.x+row.w/2,row.y+row.h/2,1,false)
        assert(A.galleryMoveMenu.target==A.showcaseDestinationId,
            'Escolha de destino nao registrada')
        assert(A.store:openProject(A.showcaseMoveId).folder==A.folder,
            'Selecao de destino moveu projeto prematuramente')
        status('Destino escolhido · aguardando confirmacao')
    elseif sh.stage==81 then
        local before=A.store:openProject(A.showcaseMoveId)
        local rev=before.revision
        local w,h=love.graphics.getDimensions()
        local p=GalleryShell.movePopup(w,h)
        local ok=GalleryShell.moveConfirmRect(p)
        love.draw()
        love.mousepressed(ok.x+ok.w/2,ok.y+ok.h/2,1,false)
        local moved=A.store:openProject(A.showcaseMoveId)
        assert(moved.folder==A.showcaseDestinationId and
            moved.revision==rev+1 and
            not A.galleryMoveMenu and not A.gallerySelecting,
            'Movimento nao persistiu ou manteve modal aberto')
        assert(moved.pixels==before.pixels or
            (moved.layers and before.layers and
                moved.layers[1].pixels==before.layers[1].pixels),
            'Movimento modificou raster do desenho')
        for _,doc in ipairs(A.projects) do
            assert(doc.id~=A.showcaseMoveId,
                'Obra movida continua listada na pasta de origem')
        end
        status('Movimento concluido · obra saiu da origem')
    elseif sh.stage==82 then
        local w,h=love.graphics.getDimensions()
        local folderIndex
        for i,folder in ipairs(A.folders) do
            if folder.id==A.showcaseDestinationId then
                folderIndex=i;break
            end
        end
        assert(folderIndex,'Pasta de destino nao aparece na galeria')
        local item=GalleryShell.card(w,h,folderIndex,0)
        love.draw()
        love.mousepressed(item.x+item.w/2,item.y+item.h/2,1,false)
        assert(A.folder==A.showcaseDestinationId and
            #A.projects==1 and A.projects[1].id==A.showcaseMoveId,
            'Obra movida nao foi reencontrada na pasta destino')
        local reopened=A.store:openProject(A.showcaseMoveId)
        assert(reopened.folder==A.folder,
            'Documento reaberto nao preservou localizacao')
        status('Destino verificado · obra RBD2 preservada')
    elseif sh.stage==83 then
        local w,h=love.graphics.getDimensions()
        A.gallerySelecting=true
        A.gallerySelected={}
        A.galleryScroll=0
        love.draw()
        local r=GalleryShell.card(w,h,1,0)
        love.mousepressed(r.x+r.w/2,r.y+r.h/2,1,false)
        assert(A.gallerySelected['p:'..A.showcaseMoveId],
            'Projeto da pasta atual nao foi selecionado')
        love.draw()
        local move=GalleryShell.selectionAction(w,h,'move')
        love.mousepressed(move.x+move.w/2,move.y+move.h/2,1,false)
        local p=GalleryShell.movePopup(w,h)
        love.draw()
        local action=GalleryShell.moveNewFolderRect(p)
        love.mousepressed(action.x+action.w/2,
            action.y+action.h/2,1,false)
        assert(A.galleryMoveMenu and A.galleryMoveMenu.creating
            and A.galleryMoveMenu.createParent==A.folder,
            'Nova pasta nao foi aberta sob a pasta de origem')
        A.showcaseSecondMoveRevision=
            A.store:openProject(A.showcaseMoveId).revision
        status('Criar pasta durante a movimentação')
    elseif sh.stage==84 then
        local state=assert(A.galleryMoveMenu)
        local w,h=love.graphics.getDimensions()
        local p=GalleryShell.movePopup(w,h)
        love.textinput('Pasta Nova 🎨')
        assert(state.createName=='Pasta Nova 🎨')
        love.draw()
        love.keypressed('return')
        local folderId=state.target
        assert(folderId and not state.creating and
            A.store:_folder(folderId)==folderId,
            'Pasta nao foi persistida no catalogo')
        A.showcaseNewDestination=folderId
        local found=false
        for _,f in ipairs(A.store.catalog.folders) do
            if f.id==folderId and f.parent==A.folder then
                found=true;break
            end
        end
        assert(found and
            A.store:openProject(A.showcaseMoveId).revision==
                A.showcaseSecondMoveRevision and
            A.store:openProject(A.showcaseMoveId).folder==A.folder,
            'Criar pasta mudou prematuramente o documento')
        status('Pasta criada, obra ainda na origem')
    elseif sh.stage==85 then
        local w,h=love.graphics.getDimensions()
        local p=GalleryShell.movePopup(w,h)
        local btn=GalleryShell.moveConfirmRect(p)
        local before=A.store:openProject(A.showcaseMoveId)
        love.draw()
        love.mousepressed(btn.x+btn.w/2,
            btn.y+btn.h/2,1,false)
        local moved=A.store:openProject(A.showcaseMoveId)
        assert(moved.folder==A.showcaseNewDestination
            and moved.revision==before.revision+1
            and not A.galleryMoveMenu,
            'Nova pasta nao recebeu a obra')
        assert(moved.pixels==before.pixels or
            (moved.layers and before.layers
            and moved.layers[1].pixels==before.layers[1].pixels),
            'Movimentar para nova pasta mudou pixels')
        status('Obra movida para pasta criada no seletor')
    elseif sh.stage==86 then
        local w,h=love.graphics.getDimensions()
        local folderIndex
        for i,folder in ipairs(A.folders) do
            if folder.id==A.showcaseNewDestination then
                folderIndex=i;break
            end
        end
        assert(folderIndex,'Pasta nova nao aparece na origem')
        love.draw()
        local r=GalleryShell.card(w,h,folderIndex,0)
        love.mousepressed(r.x+r.w/2,r.y+r.h/2,1,false)
        assert(A.folder==A.showcaseNewDestination
            and #A.projects==1
            and A.projects[1].id==A.showcaseMoveId,
            'Projeto nao aparece ao entrar na nova pasta')
        status('Novo destino verificado na galeria')
    elseif sh.stage==87 then
        local w,h=love.graphics.getDimensions()
        A.gallerySelecting=true
        A.gallerySelected={}
        love.draw()
        local r=GalleryShell.card(w,h,1,0)
        love.mousepressed(r.x+r.w/2,r.y+r.h/2,1,false)
        love.draw()
        local move=GalleryShell.selectionAction(w,h,'move')
        love.mousepressed(move.x+move.w/2,move.y+move.h/2,1,false)
        local p=GalleryShell.movePopup(w,h)
        love.draw()
        local create=GalleryShell.moveNewFolderRect(p)
        love.mousepressed(create.x+create.w/2,
            create.y+create.h/2,1,false)
        local count=#A.store.catalog.folders
        love.textinput('Nao salvar')
        love.keypressed('escape')
        assert(A.galleryMoveMenu and not A.galleryMoveMenu.creating
            and A.galleryMoveMenu.target==nil
            and #A.store.catalog.folders==count,
            'Cancelar digitacao criou pasta ou fechou movimento')
        status('Criacao cancelada sem alterar catalogo')
    elseif sh.stage==88 then
        A.galleryMoveMenu=nil
        A.gallerySelected={}
        A.gallerySelecting=true
        A.galleryScroll=0
        local id=assert(A.projects[1] and A.projects[1].id,
            'Obra para exclusao nao encontrada')
        A.showcaseTrashId=id
        A.showcaseTrashFile=A.store.fs:read(
            'projects/'..id..'.rbd')
        local w,h=love.graphics.getDimensions()
        love.draw()
        local item=GalleryShell.card(w,h,1,0)
        love.mousepressed(item.x+item.w/2,
            item.y+item.h/2,1,false)
        love.draw()
        local del=GalleryShell.selectionAction(w,h,'delete')
        love.mousepressed(del.x+del.w/2,
            del.y+del.h/2,1,false)
        assert(A.galleryDeleteMenu and
            #A.galleryDeleteMenu.ids==1,
            'Selecionar Excluir nao abre confirmacao')
        assert(A.store:openProject(id).folder==A.folder,
            'Abrir confirmacao alterou projeto')
        status('Exclusão recuperável: confirmação obrigatória')
    elseif sh.stage==89 then
        local w,h=love.graphics.getDimensions()
        local p=GalleryShell.confirmPopup(w,h)
        local cancel=GalleryShell.confirmCancel(p)
        love.draw()
        love.mousepressed(cancel.x+cancel.w/2,
            cancel.y+cancel.h/2,1,false)
        assert(not A.galleryDeleteMenu
            and A.store:openProject(A.showcaseTrashId).folder==A.folder,
            'Cancelar exclusao alterou projeto')
        status('Cancelar não exclui a obra')
    elseif sh.stage==90 then
        local w,h=love.graphics.getDimensions()
        love.draw()
        local del=GalleryShell.selectionAction(w,h,'delete')
        love.mousepressed(del.x+del.w/2,
            del.y+del.h/2,1,false)
        assert(A.galleryDeleteMenu)
        local p=GalleryShell.confirmPopup(w,h)
        local confirm=GalleryShell.confirmAction(p)
        love.draw()
        love.mousepressed(confirm.x+confirm.w/2,
            confirm.y+confirm.h/2,1,false)
        assert(not A.galleryDeleteMenu and not A.gallerySelecting,
            'Confirmacao de exclusao nao encerrou selecao')
        for _,entry in ipairs(A.projects) do
            assert(entry.id~=A.showcaseTrashId,
                'Obra excluida permanece visivel na galeria')
        end
        assert(A.store.fs:read('projects/'..
            A.showcaseTrashId..'.rbd')==A.showcaseTrashFile,
            'Exclusao mudou arquivo RBD')
        status('Obra oculta, bytes RBD preservados')
    elseif sh.stage==91 then
        local w,h=love.graphics.getDimensions()
        love.draw()
        love.mousepressed(166,27,1,false)
        assert(A.galleryMoreMenu,
            'Menu de tres pontos nao abriu')
        local p=IbisPanels.trash.morePopup(w,h)
        local item=IbisPanels.trash.moreItem(p)
        love.draw()
        love.mousepressed(item.x+item.w/2,
            item.y+item.h/2,1,false)
        assert(A.galleryTrash and #A.trashProjects>=1,
            'Excluídos recentemente não abriu')
        local found=false
        for _,entry in ipairs(A.trashProjects) do
            if entry.id==A.showcaseTrashId then
                found=true;break end
        end
        assert(found,'Obra não encontrada na recuperação')
        status('Excluídos recentemente · obra recuperável')
    elseif sh.stage==92 then
        local w,h=love.graphics.getDimensions()
        local index
        for i,entry in ipairs(A.trashProjects) do
            if entry.id==A.showcaseTrashId then index=i;break end
        end
        assert(index,'Obra não está na lista de recuperação')
        A.galleryScroll=0
        love.draw()
        love.mousepressed(w-82,27,1,false)
        assert(A.gallerySelecting,
            'Selecionar nao ativou recuperacao')
        love.draw()
        local item=GalleryShell.card(w,h,index,0)
        assert(item.visible,'Obra de recuperação fora da viewport')
        love.mousepressed(item.x+item.w/2,
            item.y+item.h/2,1,false)
        assert(A.gallerySelected['p:'..A.showcaseTrashId],
            'Miniatura nao foi marcada para recuperar')
        love.draw()
        local action=IbisPanels.trash.trashAction(w,h,'recover')
        love.mousepressed(action.x+action.w/2,
            action.y+action.h/2,1,false)
        assert(A.galleryRestoreMenu and
            #A.galleryRestoreMenu.ids==1 and
            A.galleryRestoreMenu.ids[1]==A.showcaseTrashId,
            'Recuperar nao abriu confirmacao')
        status('Seleção e recuperação exigem confirmação')
    elseif sh.stage==93 then
        local w,h=love.graphics.getDimensions()
        local p=GalleryShell.confirmPopup(w,h)
        local yes=GalleryShell.confirmAction(p)
        love.draw()
        love.mousepressed(yes.x+yes.w/2,
            yes.y+yes.h/2,1,false)
        assert(not A.galleryRestoreMenu and
            A.store.fs:read('projects/'..
            A.showcaseTrashId..'.rbd')==A.showcaseTrashFile,
            'Recuperação alterou bytes do arquivo')
        love.draw()
        love.mousepressed(48,27,1,false)
        assert(not A.galleryTrash,
            'Voltar não saiu da pasta de excluídos')
        local found=false
        for _,entry in ipairs(A.projects) do
            if entry.id==A.showcaseTrashId then
                found=true;break end
        end
        assert(found and
            A.store:openProject(A.showcaseTrashId).folder==A.folder,
            'Obra recuperada não aparece na pasta anterior')
        status('Recuperação concluída · RBD intacto')
    elseif sh.stage==94 then
        local rgba=string.rep(string.char(0,0,0,0),4)
        local first=A.store:createProject('Descartável A',
            2,2,A.folder,rgba)
        local second=A.store:createProject('Descartável B',
            2,2,A.folder,rgba)
        A.showcaseBatchTrashIds={first.id,second.id}
        local outcome=A.store:deleteProjects(
            A.showcaseBatchTrashIds,A.folder)
        assert(outcome.deleted==2,'Nao preparou duas obras excluidas')
        A.showcaseBatchRBD={
            A.store.fs:read('projects/'..first.id..'.rbd'),
            A.store.fs:read('projects/'..second.id..'.rbd')}
        refreshGallery()
        local w,h=love.graphics.getDimensions()
        love.draw()
        love.mousepressed(166,27,1,false)
        assert(A.galleryMoreMenu,'Menu de tres pontos ausente')
        status('Galeria · menu de mais opções')
    elseif sh.stage==95 then
        local w,h=love.graphics.getDimensions()
        local p=IbisPanels.trash.morePopup(w,h)
        local item=IbisPanels.trash.moreItem(p)
        love.draw()
        love.mousepressed(item.x+item.w/2,
            item.y+item.h/2,1,false)
        assert(A.galleryTrash and #A.trashProjects==2,
            'Navegacao recente nao preservou dois itens')
        for _,doc in ipairs(A.trashProjects) do
            assert(doc.retention_days==30 and
                not doc.retention_expired,
                'Prazo inicial de recuperacao nao exibido')
        end
        status('Itens excluidos: 30 dias · sem apagamento automatico')
    elseif sh.stage==96 then
        local w,h=love.graphics.getDimensions()
        love.draw()
        love.mousepressed(w-82,27,1,false)
        assert(A.gallerySelecting)
        love.draw()
        local all=IbisPanels.trash.trashAction(w,h,'all')
        love.mousepressed(all.x+all.w/2,
            all.y+all.h/2,1,false)
        local keys=GalleryShell.selectionKeys(
            {},A.trashProjects,'works')
        assert(GalleryShell.selectionCount(A.gallerySelected,keys)==2,
            'Selecionar Todos nao funciona em Excluidos')
        status('Excluidos: duas obras marcadas para recuperar')
    elseif sh.stage==97 then
        local w,h=love.graphics.getDimensions()
        love.draw()
        local action=IbisPanels.trash.trashAction(w,h,'recover')
        love.mousepressed(action.x+action.w/2,
            action.y+action.h/2,1,false)
        assert(A.galleryRestoreMenu and
            #A.galleryRestoreMenu.ids==2,
            'Recuperar lote nao abriu confirmacao')
        local popup=GalleryShell.confirmPopup(w,h)
        local yes=GalleryShell.confirmAction(popup)
        love.draw()
        love.mousepressed(yes.x+yes.w/2,
            yes.y+yes.h/2,1,false)
        assert(not A.galleryRestoreMenu and
            not A.gallerySelecting and #A.trashProjects==0,
            'Restauracao em lote nao limpou itens excluidos')
        for i,id in ipairs(A.showcaseBatchTrashIds) do
            local doc=A.store:openProject(id)
            assert(doc.folder==A.folder and
                A.store.fs:read('projects/'..id..'.rbd')==
                    A.showcaseBatchRBD[i],
                'Recuperacao lote alterou arquivo RBD')
        end
        status('Duas obras recuperadas em lote · RBD intactos')
    elseif sh.stage==98 then
        toGallery()
        setFolder('')
        A.galleryFilter='all'
        A.galleryScroll=0
        local w,h=love.graphics.getDimensions()
        local layout=GalleryShell.layout(w,h)
        assert(layout.top==66
            and GalleryShell.card(w,h,1,0).y==66,
            'Miniaturas nao ocupam faixa antes reservada aos filtros')
        local before=Native.bytes(A.layerSession.composite)
        local undo=A.layerSession:historyStats().undo
        love.draw()
        for _,hit in ipairs(A.buttons) do
            assert(not (hit.y==70 and hit.w==101
                and hit.h==33),
                'Abas inventadas ainda recebem cliques invisiveis')
        end
        assert(Native.bytes(A.layerSession.composite)==before and
            A.layerSession:historyStats().undo==undo,
            'Retirar filtros alterou raster ou historico')
        status('Galeria oficial: miniaturas sob a barra superior')
    elseif sh.stage==99 then
        local before=Native.bytes(A.layerSession.composite)
        local undo=A.layerSession:historyStats().undo
        love.wheelmoved(0,-7)
        assert(A.galleryScroll>0,
            'Galeria sem abas nao rolou')
        assert(Native.bytes(A.layerSession.composite)==before and
            A.layerSession:historyStats().undo==undo,
            'Rolagem da galeria alterou os pixels')
        status('Galeria oficial: rolagem com grade expandida')
    elseif sh.stage==100 then
        A.galleryScroll=0
        local w,h=love.graphics.getDimensions()
        love.draw()
        love.mousepressed(w-82,27,1,false)
        assert(A.gallerySelecting,
            'Selecionar deixou de funcionar sem abas')
        local first=GalleryShell.card(w,h,1,0)
        love.draw()
        love.mousepressed(first.x+first.w/2,
            first.y+first.h/2,1,false)
        local keys=GalleryShell.selectionKeys(
            A.folders,A.projects,'all')
        assert(GalleryShell.selectionCount(A.gallerySelected,keys)==1
            and not A.galleryDeleteMenu and not A.galleryMoveMenu,
            'Marcar miniatura abriu operacao indevida')
        status('Galeria oficial: selecao intacta sem filtros locais')
    elseif sh.stage==101 then
        A.gallerySelecting=false;A.gallerySelected={}
        A.galleryScroll=0;A.galleryFilter='all'
        refreshGallery()
        local w,h=love.graphics.getDimensions()
        local first=#A.folders+1
        local second=first+1
        local source=A.galleryItems[second]
        local target=A.galleryItems[first]
        assert(source and target and
            source.type=='project' and target.type=='project',
            'Prova de arrasto precisa de duas obras')
        A.showcaseReorderSource=source.key
        A.showcaseReorderTarget=target.key
        A.showcaseReorderPixels=Native.bytes(A.layerSession.composite)
        A.showcaseReorderUndo=A.layerSession:historyStats().undo
        A.showcaseReorderRBD=A.store.fs:read(
            'projects/'..source.value.id..'.rbd')
        love.draw()
        local start=GalleryShell.card(w,h,second,0)
        love.mousepressed(start.x+start.w/2,
            start.y+start.h/2,1,false)
        assert(A.galleryGesture and
            A.galleryGesture.key==source.key,
            'Galeria abriu imagem antes de pressao prolongada')
        A.galleryGesture.started=love.timer.getTime()-1
        local dest=GalleryShell.card(w,h,first,0)
        love.mousemoved(dest.x+7,dest.y+dest.h/2,
            dest.x+7-start.x-start.w/2,
            dest.y-start.y,false)
        assert(A.galleryGesture and A.galleryGesture.active,
            'Pressao prolongada nao ativou arrasto')
        status('Galeria: arrastando miniatura sobre outra')
    elseif sh.stage==102 then
        local w,h=love.graphics.getDimensions()
        local target=GalleryShell.card(w,h,#A.folders+1,0)
        love.mousereleased(target.x+7,
            target.y+target.h/2,1,false)
        assert(not A.galleryGesture
            and A.galleryItems[#A.folders+1].key==
                A.showcaseReorderSource,
            'Soltar nao mudou a ordem')
        assert(A.store.fs:read('projects/'..
            A.showcaseReorderSource:sub(3)..'.rbd')==
                A.showcaseReorderRBD,
            'Arrasto regravou bytes RBD')
        assert(Native.bytes(A.layerSession.composite)==
                A.showcaseReorderPixels and
            A.layerSession:historyStats().undo==
                A.showcaseReorderUndo,
            'Arrasto alterou raster ou historico')
        status('Galeria: ordem de obras alterada sem regravar RBD')
    elseif sh.stage==103 then
        local reopened=Store.open(A.store.root)
        local items=reopened:galleryItems(A.folder)
        assert(items[#A.folders+1].key==A.showcaseReorderSource,
            'Ordem nao sobreviveu a reinicializacao do Store')
        assert(A.store.fs:read('projects/'..
            A.showcaseReorderSource:sub(3)..'.rbd')==
                A.showcaseReorderRBD,
            'Reabrir ordem alterou projeto')
        status('Galeria: ordem persistida apos reabrir')
    elseif sh.stage==104 then
        local w,h=love.graphics.getDimensions()
        local before=A.galleryItems[#A.folders+1].key
        local source=GalleryShell.card(w,h,#A.folders+1,0)
        local target=GalleryShell.card(w,h,#A.folders+2,0)
        love.draw()
        love.mousepressed(source.x+source.w/2,
            source.y+source.h/2,1,false)
        love.mousemoved(target.x+target.w/2,target.y+target.h/2,
            160,0,false)
        love.mousereleased(target.x+target.w/2,
            target.y+target.h/2,1,false)
        assert(not A.galleryGesture and
            A.galleryItems[#A.folders+1].key==before and
            A.screen=='gallery',
            'Arrasto curto deve cancelar sem abrir obra')
        status('Galeria: movimento precoce nao altera ordem')
    elseif sh.stage==105 then
        local w,h=love.graphics.getDimensions()
        assert(#A.folders>0,'Falta pasta para arrasto misto')
        local folderIndex
        for i,item in ipairs(A.galleryItems) do
            if item.type=='folder' then folderIndex=i;break end
        end
        assert(folderIndex,'Pasta nao encontrada na grade')
        local folderKey=A.galleryItems[folderIndex].key
        local other=#A.folders+1
        local targetKey=A.galleryItems[other].key
        assert(targetKey~=folderKey and
            A.galleryItems[other].type=='project',
            'Arrasto precisa de pasta e obra distintas')
        local start=GalleryShell.card(w,h,folderIndex,0)
        local dest=GalleryShell.card(w,h,other,0)
        love.draw()
        love.mousepressed(start.x+start.w/2,
            start.y+start.h/2,1,false)
        A.galleryGesture.started=love.timer.getTime()-1
        love.mousemoved(dest.x+dest.w/2,dest.y+dest.h/2,
            dest.x-start.x,dest.y-start.y,false)
        love.mousereleased(dest.x+dest.w/2,
            dest.y+dest.h/2,1,false)
        local found=false
        for i,item in ipairs(Store.open(A.store.root):galleryItems('')) do
            if item.key==folderKey and i==other then
                found=true;break end
        end
        assert(found and not A.galleryGesture,
            'Ordem mista de pasta e obra nao persistiu')
        status('Galeria: pastas e desenhos reordenados juntos')
    elseif sh.stage==106 then
        -- The gallery contains mixed artworks and folders after stage 105.
        A.gallerySelecting=false;A.gallerySelected={}
        A.galleryScroll=0;A.galleryFilter='all'
        refreshGallery()
        local folderIndex,projectIndex
        for i,entry in ipairs(A.galleryItems) do
            if entry.type=='folder' and not folderIndex then
                folderIndex=i
            elseif entry.type=='project' and not projectIndex then
                projectIndex=i
            end
        end
        assert(folderIndex and projectIndex and
            folderIndex<=5 and projectIndex<=5,
            'Prova requer pasta e desenho visiveis na galeria')
        local folder=A.galleryItems[folderIndex]
        local project=A.galleryItems[projectIndex]
        A.showcaseFolderDropId=project.value.id
        A.showcaseFolderDropFolder=folder.value.id
        local opened=A.store:openProject(project.value.id)
        A.showcaseFolderDropRev=opened.revision
        A.showcaseFolderDropPixels=opened.pixels or
            opened.layers[1].pixels
        local w,h=love.graphics.getDimensions()
        local src=GalleryShell.card(w,h,projectIndex,0)
        local dest=GalleryShell.card(w,h,folderIndex,0)
        love.draw()
        love.mousepressed(src.x+src.w/2,src.y+src.h/2,1,false)
        assert(A.galleryGesture and
            A.galleryGesture.key==project.key,
            'Pressionar obra nao iniciou gesto')
        A.galleryGesture.started=love.timer.getTime()-1
        love.mousemoved(dest.x+dest.w/2,dest.y+dest.h/2,
            dest.x-src.x,dest.y-src.y,false)
        local action=GalleryShell.dropAction(A.folder,nil,
            A.galleryGesture.key,folder.key,w,h,
            dest.x+dest.w/2,dest.y+dest.h/2)
        assert(A.galleryGesture.active and
            action.kind=='move' and action.folder==folder.value.id,
            'Soltar sobre pasta nao oferece destino correto')
        status('Arrastar desenho sobre pasta: alvo de movimentacao')
    elseif sh.stage==107 then
        local w,h=love.graphics.getDimensions()
        local index
        for i,entry in ipairs(A.galleryItems) do
            if entry.key=='f:'..A.showcaseFolderDropFolder then
                index=i;break
            end
        end
        assert(index,'Pasta alvo nao esta visivel')
        local dest=GalleryShell.card(w,h,index,0)
        love.draw()
        love.mousereleased(dest.x+dest.w/2,
            dest.y+dest.h/2,1,false)
        local opened=A.store:openProject(A.showcaseFolderDropId)
        assert(opened.folder==A.showcaseFolderDropFolder and
            opened.revision==A.showcaseFolderDropRev+1,
            'Soltar sobre pasta nao moveu desenho')
        assert((opened.pixels or opened.layers[1].pixels)==
            A.showcaseFolderDropPixels,
            'Movimento para pasta alterou pixels')
        local reopened=Store.open(A.store.root):openProject(
            A.showcaseFolderDropId)
        assert(reopened.folder==opened.folder and
            reopened.revision==opened.revision,
            'Mover para pasta nao persistiu apos reinicio')
        status('Desenho movido e preservado dentro da pasta')
    elseif sh.stage==108 then
        setFolder(A.showcaseFolderDropFolder)
        local index
        for i,entry in ipairs(A.galleryItems) do
            if entry.key=='p:'..A.showcaseFolderDropId then
                index=i;break
            end
        end
        assert(index and index<=5,
            'Desenho movido nao esta visivel na pasta destino')
        local w,h=love.graphics.getDimensions()
        local src=GalleryShell.card(w,h,index,0)
        love.draw()
        love.mousepressed(src.x+src.w/2,src.y+src.h/2,1,false)
        assert(A.galleryGesture and A.galleryGesture.key==
            'p:'..A.showcaseFolderDropId,
            'Pressionar desenho na pasta nao iniciou gesto')
        A.galleryGesture.started=love.timer.getTime()-1
        love.mousemoved(46,27,46-src.x-src.w/2,
            27-src.y-src.h/2,false)
        local parent=''
        for _,entry in ipairs(A.store.catalog.folders) do
            if entry.id==A.folder then parent=entry.parent;break end
        end
        A.showcaseParentDropFolder=parent
        local action=GalleryShell.dropAction(A.folder,parent,
            A.galleryGesture.key,nil,w,h,46,27)
        assert(A.galleryGesture.active and
            action.kind=='move' and action.folder==parent,
            'Arrastar sobre Voltar nao selecionou pasta pai')
        status('Arrastar desenho sobre Voltar: mover a pasta superior')
    elseif sh.stage==109 then
        love.draw()
        love.mousereleased(46,27,1,false)
        local moved=A.store:openProject(A.showcaseFolderDropId)
        assert(moved.folder==A.showcaseParentDropFolder and
            moved.revision==A.showcaseFolderDropRev+2,
            'Soltar sobre Voltar nao moveu obra a pasta pai')
        assert((moved.pixels or moved.layers[1].pixels)==
            A.showcaseFolderDropPixels,
            'Mover a pasta superior alterou os pixels')
        setFolder(A.showcaseParentDropFolder)
        local found=false
        for _,entry in ipairs(A.galleryItems) do
            if entry.key=='p:'..A.showcaseFolderDropId then
                found=true;break
            end
        end
        assert(found and Store.open(A.store.root):openProject(
            A.showcaseFolderDropId).folder==A.folder,
            'Obra nao reapareceu na pasta pai apos reiniciar')
        status('Obra devolvida a pasta pai; dados RBD intactos')
    elseif sh.stage==110 then
        local rgbaA=string.rep(string.char(250,34,77,255),4)
        local rgbaB=string.rep(string.char(38,167,231,255),4)
        local root=A.folder
        A.showcaseGroupParent=A.store:createFolder(
            'Agrupamento com gesto',root)
        A.showcaseGroupSource=A.store:createProject(
            'Fonte do grupo',2,2,A.showcaseGroupParent,rgbaA)
        A.showcaseGroupTarget=A.store:createProject(
            'Alvo do grupo',2,2,A.showcaseGroupParent,rgbaB)
        A.showcaseGroupPixels={rgbaA,rgbaB}
        setFolder(A.showcaseGroupParent)
        A.galleryFilter='all'
        assert(#A.projects==2 and #A.folders==0,
            'Teste de agrupamento nao comecou com duas obras')
        local w,h=love.graphics.getDimensions()
        local source=GalleryShell.card(w,h,1,0)
        local destination=GalleryShell.card(w,h,2,0)
        A.showcaseGroupDragKey=A.galleryItems[1].key
        A.showcaseGroupDropKey=A.galleryItems[2].key
        love.draw()
        love.mousepressed(source.x+source.w/2,
            source.y+source.h/2,1,false)
        assert(A.galleryGesture and
            A.galleryGesture.key==A.showcaseGroupDragKey,
            'Gesto de grupo nao iniciou pressionamento')
        A.galleryGesture.started=love.timer.getTime()-1
        love.mousemoved(destination.x+destination.w/2,
            destination.y+destination.h/2,
            destination.x-source.x,
            destination.y-source.y,false)
        local action=GalleryShell.dropAction(
            A.folder,nil,A.showcaseGroupDragKey,
            A.showcaseGroupDropKey,w,h,
            destination.x+destination.w/2,
            destination.y+destination.h/2,destination)
        assert(A.galleryGesture.active and
            action.kind=='group',
            'Sobreposicao central nao criou alvo de agrupamento')
        status('Arrastar desenho sobre outro: criar nova pasta')
    elseif sh.stage==111 then
        local w,h=love.graphics.getDimensions()
        local destination=GalleryShell.card(w,h,2,0)
        love.draw()
        love.mousereleased(destination.x+destination.w/2,
            destination.y+destination.h/2,1,false)
        assert(not A.galleryGesture and #A.projects==0
            and #A.folders==1 and
            A.folders[1].name=='Nova pasta',
            'Agrupar nao criou pasta com as duas obras')
        A.showcaseGroupedFolder=A.folders[1].id
        for _,doc in ipairs({
            A.showcaseGroupSource,A.showcaseGroupTarget}) do
            local saved=A.store:openProject(doc.id)
            assert(saved.folder==A.showcaseGroupedFolder
                and saved.revision==doc.revision+1,
                'Agrupamento nao persistiu ambos os documentos')
        end
        assert(A.store:openProject(A.showcaseGroupSource.id).pixels==
            A.showcaseGroupPixels[1] and
            A.store:openProject(A.showcaseGroupTarget.id).pixels==
            A.showcaseGroupPixels[2],
            'Agrupar regravou o raster original')
        status('Nova pasta criada com duas obras reais')
    elseif sh.stage==112 then
        setFolder(A.showcaseGroupedFolder)
        local fromDisk=Store.open(A.store.root)
        local projects=fromDisk:listProjects(A.showcaseGroupedFolder)
        assert(#A.projects==2 and #projects==2
            and A.folder==A.showcaseGroupedFolder,
            'Obras nao aparecem na pasta depois da reabertura')
        assert(fromDisk:openProject(A.showcaseGroupSource.id).pixels==
            A.showcaseGroupPixels[1] and
            fromDisk:openProject(A.showcaseGroupTarget.id).pixels==
            A.showcaseGroupPixels[2],
            'Reabrir a pasta perdeu os pixels')
        status('Galeria agrupada: duas miniaturas persistidas')
    elseif sh.stage==113 then
        setFolder(A.showcaseGroupParent)
        local rgba=string.rep(string.char(10,20,30,255),4)
        local one=A.store:createProject('Outro desenho A',
            2,2,A.folder,rgba)
        local two=A.store:createProject('Outro desenho B',
            2,2,A.folder,rgba)
        refreshGallery()
        local sourceIndex,targetIndex
        for i,item in ipairs(A.galleryItems) do
            if item.key=='p:'..one.id then sourceIndex=i end
            if item.key=='p:'..two.id then targetIndex=i end
        end
        assert(sourceIndex and targetIndex,
            'Faltam desenhos para segundo agrupamento')
        local w,h=love.graphics.getDimensions()
        local src=GalleryShell.card(w,h,sourceIndex,0)
        local dst=GalleryShell.card(w,h,targetIndex,0)
        love.draw()
        love.mousepressed(src.x+src.w/2,
            src.y+src.h/2,1,false)
        A.galleryGesture.started=love.timer.getTime()-1
        love.mousemoved(dst.x+dst.w/2,dst.y+dst.h/2,
            dst.x-src.x,dst.y-src.y,false)
        love.mousereleased(dst.x+dst.w/2,
            dst.y+dst.h/2,1,false)
        assert(#A.folders==2 and #A.projects==0
            and A.folders[1].name=='Nova pasta'
            and A.folders[2].name=='Nova pasta (2)',
            'Segundo agrupamento nao gerou nome exclusivo')
        assert(A.store:openProject(one.id).folder==A.folders[2].id
            and A.store:openProject(two.id).folder==A.folders[2].id,
            'Segundo grupo nao moveu os dois projetos')
        status('Agrupar obras: pastas com nomes unicos')
    elseif sh.stage==114 then
        toGallery();setFolder('');A.galleryFilter='all'
        A.galleryScroll=0
        local w,h=love.graphics.getDimensions()
        local l=GalleryShell.layout(w,h)
        while GalleryShell.maxScroll(
            w,h,#A.galleryItems)<240 do
            A.store:createProject('Rolagem extra '..#A.galleryItems,
                2,2,'',string.rep(string.char(31,90,150,255),4))
            refreshGallery()
        end
        local index
        for i,item in ipairs(A.galleryItems) do
            if item.type=='project' and
                GalleryShell.card(w,h,i,0).visible then
                index=i;break
            end
        end
        assert(index,'Rolagem precisa de uma obra visivel')
        local project=A.galleryItems[index]
        A.showcaseScrollKey=project.key
        A.showcaseScrollRBD=A.store.fs:read(
            'projects/'..project.value.id..'.rbd')
        A.showcaseScrollOrder=A.galleryItems[1].key
        love.draw()
        local r=GalleryShell.card(w,h,index,0)
        love.mousepressed(r.x+r.w/2,r.y+r.h/2,1,false)
        assert(A.galleryGesture and
            A.galleryGesture.key==project.key,
            'Pressionar obra nao iniciou arrasto')
        A.galleryGesture.started=love.timer.getTime()-1
        love.mousemoved(5,l.bottom-3,
            5-r.x-r.w/2,l.bottom-3-r.y-r.h/2,false)
        assert(A.galleryGesture.active and
            A.galleryGesture.moved,
            'Arrasto nao ativou antes da rolagem')
        A.showcaseScrollMax=GalleryShell.maxScroll(
            w,h,#A.galleryItems)
        status('Arrasto ativo: rolagem na borda inferior')
    elseif sh.stage==115 then
        assert(A.galleryScroll>0 and
            A.galleryScroll<=A.showcaseScrollMax,
            'Arrasto parado na borda inferior nao rolou')
        local w,h=love.graphics.getDimensions()
        local l=GalleryShell.layout(w,h)
        A.galleryScroll=A.showcaseScrollMax
        love.mousemoved(5,l.top+3,0,
            l.top+3-A.galleryGesture.py,false)
        assert(A.galleryGesture and A.galleryGesture.active,
            'Rolagem perdeu o arrasto')
        status('Arrasto ativo: rolagem na borda superior')
    elseif sh.stage==116 then
        assert(A.galleryScroll<A.showcaseScrollMax and
            A.galleryScroll>=0,
            'Arrasto parado na borda superior nao rolou')
        local w,h=love.graphics.getDimensions()
        local l=GalleryShell.layout(w,h)
        love.draw()
        love.mousereleased(5,l.top+3,1,false)
        assert(not A.galleryGesture and
            A.galleryItems[1].key==A.showcaseScrollOrder,
            'Soltar fora da grade alterou a ordem')
        assert(A.store.fs:read('projects/'..
            A.showcaseScrollKey:sub(3)..'.rbd')==
                A.showcaseScrollRBD,
            'Rolagem modificou bytes RBD')
        status('Arrasto cancelado: catalogo e RBD preservados')
    elseif sh.stage==117 then
        openDoc(A.store:openProject(sh.projectId))
        A.compactUi=true;A.compactPanel='layers'
        A.layerSession:select(1)
        local ls=A.layerSession
        ls:beginEdit()
        ls:pixel(1,1,0x23456780)
        ls:pixel(4,4,0x00000000)
        assert(ls:finishEdit(),'Alpha Lock demo requires source pixels')
        A.showcaseAlphaBase=Native.readPixel(
            ls:activeBuffer(),1,1)
        local w,h=love.graphics.getDimensions()
        love.draw()
        local p=Compact.popup(w,h,'layers')
        local slot=LayerChrome.footerControls(p)[2]
        assert(slot.available and slot.id=='alpha',
            'Alpha Lock visual still disabled')
        love.mousepressed(slot.x+slot.w/2,
            slot.y+slot.h/2,1,false)
        love.mousereleased(slot.x+slot.w/2,
            slot.y+slot.h/2,1,false)
        assert(A.doc.layers[1].alpha_lock and
            ls.buffers[1].alphaLock and A.compactPanel=='layers',
            'Alpha Lock button did not toggle actual layer state')
        status('Camadas: Alpha Lock real ativado pelo rodape')
    elseif sh.stage==118 then
        local ls=A.layerSession
        ls:beginEdit()
        ls:beginStrokeAccum()
        ls:pressureStroke(1.5,1.5,4.5,4.5,
            8,8,0xff0000ff,1,1,1,0,0,0,true)
        assert(ls:finishEdit(),'Alpha Lock brush made no RGB edit')
        ls:recompose()
        A.dirty=true;rebuildImage()
        local changed=Native.readPixel(ls:activeBuffer(),1,1)
        local untouched=Native.readPixel(ls:activeBuffer(),4,4)
        assert(changed%256==128 and changed~=A.showcaseAlphaBase
            and untouched==0,
            'Alpha Lock changed original alpha or painted empty area')
        A.showcaseAlphaPainted=changed
        assert(ls:undo(),'Alpha Lock stroke undo unavailable')
        assert(Native.readPixel(ls:activeBuffer(),1,1)==
            A.showcaseAlphaBase and
            ls.doc.layers[1].alpha_lock,
            'Undo did not restore RGB or lock state')
        assert(ls:redo(),'Alpha Lock stroke redo unavailable')
        assert(Native.readPixel(ls:activeBuffer(),1,1)==
            A.showcaseAlphaPainted,
            'Redo did not restore locked brush')
        A.dirty=true;rebuildImage()
        status('Alpha Lock: RGB pintado, alfa 128 preservado')
    elseif sh.stage==119 then
        saveDoc()
        local reread=Store.open(A.store.root):openProject(
            A.doc.id)
        local alphaOffset=(reread.width+1)*4+4
        assert(reread.format==2 and reread.layers[1].alpha_lock
            and reread.layers[1].pixels:byte(alphaOffset)==128,
            'RBD2 saved layer lock or original alpha incorrectly')
        local reopened=Layers.open(A.store,reread)
        assert(reopened.buffers[1].alphaLock and
            Native.readPixel(reopened:activeBuffer(),1,1)==
                A.showcaseAlphaPainted and
            Native.readPixel(reopened:activeBuffer(),4,4)==0,
            'Reopening RBD2 lost Alpha Lock or transparent pixels')
        local w,h=love.graphics.getDimensions()
        love.draw()
        status('Alpha Lock reaberto em RBD2 com pixels intactos')
    elseif sh.stage==120 then
        assert(A.screen=='editor' and A.compactUi and A.layerSession,
            'Faixa direita exige editor compacto')
        local before=Native.bytes(A.layerSession.composite)
        local undo=A.layerSession:historyStats().undo
        saveToolPreference('toolRailPosition','right')
        A.compactPanel=nil;A.toolRailPage=1
        love.draw()
        local w,h=love.graphics.getDimensions()
        local entries=EditorRail.entries(w,h,1,
            IbisTools.entries,'right')
        assert(entries[1].x>w-80 and entries[1].y>=64,
            'Faixa direita sobrepoe barra superior')
        local found=false
        for _,button in ipairs(A.buttons) do
            if button.x==entries[1].x and
                button.y==entries[1].y then found=true end
        end
        assert(found,'Ferramenta direita nao possui hitbox real')
        assert(Native.bytes(A.layerSession.composite)==before and
            A.layerSession:historyStats().undo==undo,
            'Mudar faixa alterou obra ou historico')
        status('Ferramentas na direita: hitboxes ativas e obra intacta')
    elseif sh.stage==121 then
        local before=Native.bytes(A.layerSession.composite)
        local undo=A.layerSession:historyStats().undo
        saveToolPreference('toolRailPosition','popup')
        A.compactPanel=nil
        love.draw()
        local w,h=love.graphics.getDimensions()
        local right=EditorRail.entries(w,h,1,
            IbisTools.entries,'right')
        for _,button in ipairs(A.buttons) do
            for _,entry in ipairs(right) do
                assert(not (button.x==entry.x and button.y==entry.y
                    and button.w==entry.w and button.h==entry.h),
                    'Popup manteve hitbox invisivel da faixa')
            end
        end
        A.compactPanel='tools'
        love.draw()
        assert(Native.bytes(A.layerSession.composite)==before and
            A.layerSession:historyStats().undo==undo,
            'Seletor popup alterou obra ou historico')
        status('Seletor em popup: sem faixa lateral invisivel')
    elseif sh.stage==122 then
        toGallery();A.galleryFilter='works';A.galleryScroll=0
        local selected=IbisPanels.galleryDetail.artworks(A.galleryItems,'works')
        assert(#selected>=2,
            'Showcase precisa de duas obras para ampliar')
        A.galleryExpandedProof={
            bytes=Native.bytes(A.layerSession.composite),
            undo=A.layerSession:historyStats().undo,
            first=selected[1].id,second=selected[2].id
        }
        local w,h=love.graphics.getDimensions()
        local card=GalleryShell.card(w,h,1,0)
        love.draw()
        love.mousepressed(card.x+card.w/2,card.y+card.h/2,1,false)
        love.mousereleased(card.x+card.w/2,card.y+card.h/2,1,false)
        assert(A.galleryDetailId==selected[1].id and
            A.screen=='gallery',
            'Clique na miniatura deve ampliar antes de editar')
        assert(Native.bytes(A.layerSession.composite)==
            A.galleryExpandedProof.bytes and
            A.layerSession:historyStats().undo==
                A.galleryExpandedProof.undo,
            'Abrir ampliacao alterou os pixels')
        status('Galeria ampliada: thumbnail real, editor ainda fechado')
    elseif sh.stage==123 then
        local old=assert(A.galleryExpandedProof)
        local w,h=love.graphics.getDimensions()
        -- As setas de mouse so existem sob hover. O showcase de
        -- navegacao usa a tecla real, sem forcar click invisivel.
        love.draw()
        love.keypressed('right')
        assert(A.galleryDetailId==old.second,
            'Tecla direita nao navegou para a segunda obra')
        assert(Native.bytes(A.layerSession.composite)==old.bytes
            and A.layerSession:historyStats().undo==old.undo,
            'Navegacao da galeria alterou documento')
        status('Galeria: segunda obra, navegacao sem alterar RBD2')
    elseif sh.stage==124 then
        local old=assert(A.galleryExpandedProof)
        local w,h=love.graphics.getDimensions()
        love.draw()
        love.mousepressed(w/2,h/2-90,1,false)
        love.mousereleased(w/2,h/2+70,1,false)
        assert(not A.galleryDetailId and A.screen=='gallery',
            'Gesto vertical nao voltou a grade da galeria')
        assert(Native.bytes(A.layerSession.composite)==old.bytes
            and A.layerSession:historyStats().undo==old.undo,
            'Retorno a grade alterou pixels ou historico')
        status('Galeria: gesto vertical real voltou a grade')
    elseif sh.stage==125 then
        local old=assert(A.galleryExpandedProof)
        local w,h=love.graphics.getDimensions()
        local card=GalleryShell.card(w,h,1,0)
        love.draw()
        love.mousepressed(card.x+card.w/2,card.y+card.h/2,1,false)
        love.mousereleased(card.x+card.w/2,card.y+card.h/2,1,false)
        assert(A.galleryDetailId==old.first,
            'Retornar a grade impediu reabrir a miniatura')
        local edit=IbisPanels.galleryDetail.edit(w,h)
        love.draw()
        love.mousepressed(edit.x+edit.w/2,edit.y+edit.h/2,1,false)
        love.mousereleased(edit.x+edit.w/2,edit.y+edit.h/2,1,false)
        assert(A.screen=='editor' and A.doc.id==old.first
            and not A.galleryDetailId,
            'Editar nao abriu a obra ampliada no editor real')
        status('Galeria: Editar abriu projeto RBD2 no motor Lua')
    elseif sh.stage>#showcaseNames then
        externalWrite(sh.directory..'/showcase-report.json',
            JSON.encode({ok=true,real_love_render=true,
                lua_renderer=Native.implementation=='lua',
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
-- Stage 40: actual compact properties popup and native Lua swatch.
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
        'Compact swatch does not reflect currently active Lua brush')
    love.mousepressed(p.x+17+73+25,p.y+54+29+15,1,false)
    assert(A.brushDiameter==26,'Compact diameter adjustment broke')
    love.draw()
    local second=assert(A.brushSampleCache.compact_preview)
    assert(second.key~=first.key and
        second.key==Samples.key(Inspector.settings(A),A.color),
        'Diameter change did not invalidate Lua preview cache')
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
        'Undo must exactly restore original Lua RGBA composite')
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
        'Opacity undo must exactly restore Lua composite')
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
-- Stage 43: real Windows classic-sidebar controls for pressure response.
-- Cycling is configuration-only, and must never modify raster/history.
local function verifyPressureCurveControls()
    assert(A.screen=='editor' and not A.compactUi and
        not A.focusMode,'Pressure curve controls require classic editor')
    local w=love.graphics.getWidth()
    local previousTool,previousTab=A.tool,A.sideTab
    local previousCurve,previousDirty=A.pressureCurve,A.dirty
    local pixels=Native.bytes(A.layerSession.composite)
    local history=A.layerSession:historyStats().undo
    finishStroke()
    A.pressureCurve='linear'
    selectTool('brush')
    A.sideTab='brush'
    for _,expected in ipairs({'soft','firm','linear'}) do
        love.draw()
        love.mousepressed(w-268+185,430,1,false)
        assert(A.pressureCurve==expected,
            'Brush pressure response button failed to advance')
    end
    selectTool('erase')
    A.sideTab='brush'
    love.draw()
    love.mousepressed(w-268+185,430,1,false)
    assert(A.pressureCurve=='soft',
        'Eraser must offer the same pressure response selector')
    assert(A.dirty==previousDirty and
        A.layerSession:historyStats().undo==history and
        Native.bytes(A.layerSession.composite)==pixels,
        'Changing pressure response must not edit pixels/history')
    A.pressureCurve=previousCurve
    selectTool(previousTool)
    A.sideTab=previousTab
end
-- Stage 44: real Windows GUI regression of independent pressure switches.
-- View-only setting changes must not create raster or undo transactions.
local function verifyPressureInfluenceControls()
    assert(A.screen=='editor' and not A.compactUi and
        not A.focusMode,'Pressure channel test needs desktop editor')
    finishStroke()
    local oldTool,oldTab=A.tool,A.sideTab
    local oldSize,oldOpacity=A.pressureSize,A.pressureOpacity
    local oldScroll,oldDirty=A.sidebarScroll,A.dirty
    local pixels=Native.bytes(A.layerSession.composite)
    local undo=A.layerSession:historyStats().undo
    A.pressureSize=true
    A.pressureOpacity=true
    A.sidebarScroll=0
    selectTool('brush')
    A.sideTab='brush'
    local panel=love.graphics.getWidth()-268
    local function click(x,y)
        love.draw()
        love.mousepressed(x,y,1,false)
    end
    click(panel+159,471)
    assert(not A.pressureSize and A.pressureOpacity,
        'Size button must disable only size response')
    click(panel+175,637)
    assert(not A.pressureSize and not A.pressureOpacity,
        'Opacity button must disable only alpha response')
    click(panel+159,471)
    assert(A.pressureSize and not A.pressureOpacity,
        'Size-only brush response must be selectable')
    click(panel+175,637)
    assert(A.pressureSize and A.pressureOpacity,
        'Default two-channel response must be restorable')
    selectTool('erase')
    A.sideTab='brush'
    click(panel+175,637)
    assert(A.pressureSize and not A.pressureOpacity,
        'Eraser must expose independent alpha response')
    click(panel+175,637)
    assert(A.pressureSize and A.pressureOpacity,
        'Eraser opacity response must be restorable')
    assert(Native.bytes(A.layerSession.composite)==pixels and
        A.layerSession:historyStats().undo==undo and
        A.dirty==oldDirty,
        'Switching pressure channels must not paint or change history')
    A.pressureSize=oldSize
    A.pressureOpacity=oldOpacity
    selectTool(oldTool)
    A.sideTab=oldTab
    A.sidebarScroll=Sidebar.clamp(love.graphics.getHeight(),oldScroll or 0)
end
local function nativeSelfTest()
    assert(Native.available,'Lua indisponível; não é permitido substituir por um mock Lua')
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
    assert(Native.readPixel(stroke,4,2)==0xaabbccff,'Traço básico contínuo Lua falhou')
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
    -- Lua erases only selected layer, then undo/redo restores its exact RGBA bytes.
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
    A.fonts={micro=love.graphics.newFont(10),small=love.graphics.newFont(12),body=love.graphics.newFont(14),title=love.graphics.newFont(25),large=love.graphics.newFont(40)}
    local options={}
    for i=1,#args do
        if args[i]=='--data-dir' then options.data=args[i+1]
        elseif args[i]=='--report' then options.report=args[i+1]
        elseif args[i]=='--capture' then options.capture=args[i+1]
        elseif args[i]=='--showcase-dir' then options.showcaseDir=args[i+1]
        elseif args[i]=='--lua-test' then options.luaTest=true
        elseif args[i]=='--self-test' then options.selfTest=true
        elseif args[i]=='--lua-gui-smoke' then options.luaGuiSmoke=true
        elseif args[i]=='--no-windows-ink' then options.noWindowsInk=true end
    end
    A.options=options;local base=love.filesystem.getSourceBaseDirectory()
    package.path=base..'/?.lua;'..base..'/?/init.lua;'..package.path
    Native.load(base)
    A.inkAttached=not options.noWindowsInk and Ink.init(Native) or false
    A.root=options.data or (base..'/user-data');A.store=Store.open(A.root)
    A.preferences=A.store:getPreferences() or {};A.brushes=A.store:getBrushes() or {}
    local cols=A.preferences.toolPopupColumns
    A.toolPopupColumns=SettingsUI.normalizeColumns(cols)
    A.toolRailPosition=SettingsUI.normalizePosition(
        A.preferences.toolRailPosition)
    A.toolPopupLabels=SettingsUI.labelsVisible(A.preferences.toolPopupLabels)
    A.toolPopupPage=1
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
    refreshGallery();status(Native.available and
        ('Motor Lua v1 carregado · '..(A.inkAttached and
            'Windows Ink Lua ativo' or 'mouse/toque LÖVE')) or
        'Galeria disponível · motor Lua indisponível')
    if options.showcaseDir then
        assert(Native.available,'Visual showcase requires the real Lua raster engine')
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
    if options.luaGuiSmoke then
        assert(Native.implementation=='lua' and Native.available,
            'Teste grafico requer o motor Lua')
        local canvas=Native.buffer(64,64)
        local project=A.store:createProject('Lua GUI Smoke',64,64,'',Native.bytes(canvas))
        openDoc(project)
        A.luaGuiSmoke={frames=0}
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
    -- Smoke grafico: exercita a GUI real do LÖVE e a textura GPU com
    -- o rasterizador Lua, sem ponte compilada ou motor simulado.
    if A.luaGuiSmoke then
        A.luaGuiSmoke.frames=A.luaGuiSmoke.frames+1
        if A.luaGuiSmoke.frames>=3 then
            local ok,err=xpcall(function()
                assert(A.screen=='editor' and A.image and A.layerSession,
                    'Projeto Lua nao abriu no editor')
                assert(A.image:getWidth()==64 and A.image:getHeight()==64,
                    'Textura inicial do editor invalida')
                local texture=A.image
                local layers=A.layerSession
                layers:beginEdit()
                layers:beginStrokeAccum()
                layers:pressureStroke(16.5,16.5,24.5,24.5,9,9,
                    0x4cab93ff,.45,.45,1,0,0,0,true)
                -- Duas regioes da mesma entrega WM_POINTER viram
                -- uma unica composicao/envio GPU no final do pacote.
                local oldUploads=gpuUpload:stats().uploads
                A.deferInkUploads=true
                updateImageRegion({x=1,y=2,w=12,h=10})
                updateImageRegion({x=9,y=8,w=11,h=10})
                assert(gpuUpload:stats().uploads==oldUploads,
                    'Upload prematuro antes do fim do pacote Ink')
                local batched=A.pendingInkRect
                assert(batched.x==1 and batched.y==2 and
                    batched.w==19 and batched.h==16,
                    'Uniao de eventos Ink incorreta')
                A.deferInkUploads=false
                A.pendingInkRect=nil
                updateImageRegion(batched)
                assert(gpuUpload:stats().uploads==oldUploads+1,
                    'Eventos Ink nao foram enviados em um so pacote')
                local region={x=10,y=10,w=24,h=24}
                local beforeStats=gpuUpload:stats()
                updateImageRegion(region)
                local firstStats=gpuUpload:stats()
                assert(firstStats.uploads==beforeStats.uploads+1 and
                    firstStats.copiedBytes==beforeStats.copiedBytes+
                        region.w*region.h*4,
                    'Envio FFI nao registrou bytes da regiao')
                updateImageRegion(region)
                local reused=gpuUpload:stats()
                assert(reused.hits==firstStats.hits+1 and
                    reused.allocations==firstStats.allocations,
                    'ImageData RGBA nao foi reutilizado')
                assert(A.image==texture and A.partialCanvasUpdates>=2,
                    'Upload parcial recriou a textura GPU')
                local alpha=Native.readPixel(layers:activeBuffer(),20,20)%256
                -- Leitura da textura GPU real, em modo de blend replace,
                -- para comparar o alfa final com a composicao CPU.
                local canvas=love.graphics.newCanvas(64,64,{format='rgba8'})
                love.graphics.push('all')
                love.graphics.setCanvas(canvas)
                love.graphics.clear(0,0,0,0)
                love.graphics.setBlendMode('replace')
                love.graphics.setColor(1,1,1,1)
                love.graphics.draw(A.image,0,0)
                love.graphics.setCanvas()
                love.graphics.pop()
                local rendered=canvas:newImageData()
                local _,_,_,gpuAlpha=rendered:getPixel(20,20)
                assert(math.abs(gpuAlpha-alpha/255)<=2/255,
                    'Regiao enviada nao corresponde ao alfa GPU real')
                rendered:release()
                canvas:release()
                assert(alpha>0 and alpha<255,'Trajeto Lua sem opacidade')
                assert(layers:finishEdit(),'Pincelada nao entrou no historico')
                assert(layers:undo(),'Desfazer grafico indisponivel')
                assert(Native.readPixel(layers:activeBuffer(),20,20)==0,
                    'Undo nao limpou o pixel')
                assert(layers:redo(),'Refazer grafico indisponivel')
                assert(Native.readPixel(layers:activeBuffer(),20,20)%256==alpha,
                    'Redo nao restaurou o pixel')
                layers:recompose()
                rebuildImage()
                saveDoc()
                local loaded=A.store:openProject(A.doc.id)
                assert(loaded and loaded.layers and
                    loaded.layers[1].pixels==Native.bytes(layers:activeBuffer()),
                    'Persistencia RBD2 divergente apos editor grafico')
                assert(Native.implementation=='lua',
                    'GUI deixou de usar raster Lua')
                if A.options.noWindowsInk then
                    assert(not A.inkAttached and not Ink.mouseGuard(),
                        'Entrada mouse/toque deve funcionar sem Windows Ink')
                else
                    assert(Ink.abiValid and A.inkAttached and Ink.available,
                        'Ponte Windows Ink em Lua nao anexou a janela real')
                    assert(Ink.probe(),
                        'WndProc Lua nao repassou a mensagem WM_NULL')
                end
                print('GUI LUA SMOKE OK: canvas, GPU, undo/redo, RBD2')
            end,debug.traceback)
            if not ok then io.stderr:write('GUI LUA SMOKE FALHOU: '..tostring(err)..'\n') end
            love.event.quit(ok and 0 or 1)
        end
        return
    end
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
    -- The pointer is stationary at the viewport edge while the
    -- thumbnails move beneath it; scrolling therefore belongs to the
    -- frame update, not mousemoved or the document renderer.
    if A.screen=='gallery' and A.galleryGesture and
        A.galleryGesture.active and A.galleryGesture.moved and
        not A.galleryTrash and not A.gallerySelecting and
        not A.galleryMoveMenu and not A.galleryCreateMenu and
        not A.galleryMoreMenu and not A.galleryDeleteMenu then
        local w,h=love.graphics.getDimensions()
        A.galleryScroll=GalleryShell.dragAutoScroll(
            w,h,#(A.galleryItems or {}),A.galleryScroll or 0,
            A.galleryGesture.py,dt)
    end
    if A.inkAttached and dispatchInkEvent then
        local events=Ink.poll()
        if #events>0 then
            A.deferInkUploads=true
            local ok,err=pcall(function()
                for _,event in ipairs(events) do dispatchInkEvent(event) end
            end)
            A.deferInkUploads=false
            local region=A.pendingInkRect
            A.pendingInkRect=nil
            if region then updateImageRegion(region) end
            if not ok then status('Windows Ink: '..tostring(err)) end
        end
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
                assert(A.inkAttached and Ink.available and Ink.abiValid,
                    'A ponte Lua Windows Ink nao anexou a janela LÖVE real')
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
                    'Linha Lua não desenhou ambas as extremidades')
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
                local persistentImage=A.image
                local uploadsBefore=A.partialCanvasUpdates or 0
                love.draw();love.mousepressed(sx,sy,1)
                love.mousemoved(tx,ty,tx-sx,ty-sy)
                love.mousereleased(tx,ty,1)
                assert(A.image==persistentImage,
                    'Traço curto recriou a textura inteira em vez de replacePixels')
                assert((A.partialCanvasUpdates or 0)>uploadsBefore,
                    'Pintura não enviou atualizações de retângulos para GPU')
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
                    'Touch test requires the hard Lua brush')
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
                    'Full pressure should produce stronger Lua paint')
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
                    'Native pen pressure not passed into Lua brush')
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
                -- Stage 19: real panel duplicate, new Lua pixel allocation,
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
                    'Refazer Mesclar não reproduziu o resultado Lua')
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
                -- Stage 23: GUI button uses Lua to mirror the active layer.
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
                verifyPressureCurveControls()
                verifyPressureInfluenceControls()
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
local function galleryPreview(doc,maxWidth,maxHeight)
    maxWidth,maxHeight=maxWidth or 140,maxHeight or 130
    if not Native.available then return nil end
    A.galleryPreviewCache=A.galleryPreviewCache or {order={},entries={}}
    local cache=A.galleryPreviewCache
    local key=GalleryThumb.key(doc)..':'..maxWidth..'x'..maxHeight
    if cache.entries[key] then
        return cache.entries[key].image
    end
    if (A.galleryPreviewBudget or 0)<=0 then return nil end
    A.galleryPreviewBudget=A.galleryPreviewBudget-1
    local ok,item=pcall(function()
        local saved=doc.deleted and A.store:_readProject(doc.id,true)
            or A.store:openProject(doc.id)
        local session=Layers.open(A.store,saved)
        local width,height=GalleryThumb.size(saved.width,saved.height,
            maxWidth,maxHeight)
        local data=love.image.newImageData(width,height,'rgba8')
        local sampler=(width>176 or height>126)
            and GalleryThumb.sampleLarge or GalleryThumb.sample
        sampler(Native.bytes(session.composite),
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
-- Visualizacao ampliada entre a galeria e o editor.
-- O raster de preview vem dos dados RBD2, nao de imagens ficticias.
function IbisPanels.drawGalleryExpanded(w,h)
    local doc,index,total=IbisPanels.galleryDetail.find(A.galleryItems or {},
        A.galleryDetailId,A.galleryFilter)
    if not doc then A.galleryDetailId=nil;return false end
    local lg=love.graphics
    local image=IbisPanels.galleryDetail.imageRect(w,h,doc.width,doc.height)
    lg.setColor(.94,.94,.92,1)
    lg.rectangle('fill',image.x-2,image.y-2,
        image.w+4,image.h+4)
    local preview=galleryPreview(doc,
        math.min(768,math.floor(image.w)),
        math.min(768,math.floor(image.h)))
    if preview then
        local pw,ph=preview:getDimensions()
        lg.setColor(1,1,1,1)
        lg.draw(preview,image.x,image.y,0,
            image.w/pw,image.h/ph)
    else
        lg.setColor(.55,.57,.59,1)
        lg.rectangle('line',image.x,image.y,image.w,image.h)
    end
    -- Titulo e dimensoes acompanham os limites da imagem, como
    -- no tutorial #20; nao inventar duracao de desenho no Store.
    local label=IbisPanels.galleryDetail.captionForImage(w,h,image)
    lg.setColor(.19,.20,.22,1)
    lg.setFont(A.fonts.small)
    local dimensions=('%d × %d'):format(doc.width,doc.height)
    local metaWidth=math.ceil(A.fonts.small:getWidth(dimensions))+4
    local title=TextFit.truncate('Título: '..doc.name,
        math.max(1,label.w-metaWidth-12),function(t)
            return A.fonts.small:getWidth(t) end)
    lg.print(title,label.x,label.y)
    lg.printf(dimensions,label.x+label.w-metaWidth,
        label.y,metaWidth,'right')
    -- Sem setas fixas de desktop sobre a galeria Android.
    -- Apenas a area visivel sob hover recebe callback de mouse.
    local pointerX,pointerY=love.mouse.getPosition()
    for _,direction in ipairs({-1,1}) do
        local available=direction==-1 and index>1 or index<total
        local shown=available and IbisPanels.galleryDetail.navRevealed(
            w,h,direction,pointerX,pointerY)
        if shown then
            local nav=IbisPanels.galleryDetail.nav(w,h,direction)
            lg.setColor(.26,.29,.32,.42)
            lg.rectangle('fill',nav.x,nav.y,nav.w,nav.h,5,5)
            lg.setColor(.94,.96,.98,1)
            Icons.draw(direction==-1 and 'gallery-prev'
                or 'gallery-next',nav.x+nav.w/2,
                nav.y+nav.h/2,19)
            A.buttons[#A.buttons+1]={x=nav.x,y=nav.y,
                w=nav.w,h=nav.h,fn=function()
                    A.galleryDetailId=IbisPanels.galleryDetail.step(
                        A.galleryItems,A.galleryDetailId,
                        A.galleryFilter,direction)
                end}
        end
    end
    local footerY=h-52
    lg.setColor(.17,.18,.19,1)
    lg.rectangle('fill',0,footerY,w,52)
    -- Acoes pendentes sao vetores cinza sem hitboxes; Criar
    -- reutiliza o menu funcional da grade sem tocar no RBD2.
    for _,entry in ipairs(IbisPanels.galleryDetail.footerIcons(w,h)) do
        if entry.actionable then
            lg.setColor(.36,.70,1,1)
            A.buttons[#A.buttons+1]={
                x=entry.x-22,y=footerY,w=44,h=52,
                fn=function() A.galleryCreateMenu=true end}
        else
            lg.setColor(.54,.57,.60,1)
        end
        Icons.draw(entry.id,entry.x,entry.y,19)
    end
    local edit=IbisPanels.galleryDetail.edit(w,h)
    lg.setColor(.36,.70,1,1)
    lg.setFont(A.fonts.body)
    lg.printf('Editar',edit.x,edit.y+14,edit.w,'center')
    A.buttons[#A.buttons+1]={x=edit.x,y=edit.y,w=edit.w,h=edit.h,
        fn=guard(function()
            local target=A.galleryDetailId
            A.galleryDetailId=nil;A.galleryDetailSwipe=nil
            openDoc(A.store:openProject(target))
        end)}
    return true
end
local function drawGallery(w,h)
    -- Galeria com barra escura, miniaturas rolaveis e rodape proprio.
    -- Os arquivos permanecem no Store/RBD2; sem ordenacao inventada.
    local lg=love.graphics
    local l=GalleryShell.layout(w,h)
    local folders=not A.galleryTrash and
        GalleryUI.filter(A.galleryFilter,'folder')
        and #A.folders or 0
    local works=A.galleryTrash and #(A.trashProjects or {})
        or (GalleryUI.filter(A.galleryFilter,'work')
        and #A.projects or 0)
    local total=folders+works
    A.galleryScroll=math.min(A.galleryScroll or 0,
        GalleryShell.maxScroll(w,h,total))
    -- Barra superior do My Gallery (oficial); sem cabeçalho desktop.
    lg.setColor(.18,.19,.20,1)
    lg.rectangle('fill',0,0,w,54)
    lg.setColor(.95,.96,.97,1)
    lg.setFont(A.fonts.body)
    lg.printf(A.galleryTrash and
        ('Excluídos recentemente (%d)'):format(total)
        or ('A Minha Galeria (%d)'):format(total),
        math.floor((w-390)/2),16,390,'center')
    lg.setColor(.45,.74,.94,1)
    lg.print('‹ Voltar',18,17)
    if A.galleryDetailId then
        A.buttons[#A.buttons+1]={x=10,y=7,w=112,h=42,
            fn=function()
                A.galleryDetailId=nil;A.galleryDetailSwipe=nil
            end}
    elseif A.galleryTrash then
        A.buttons[#A.buttons+1]={x=10,y=7,w=112,h=42,
            fn=function()
                A.galleryTrash=false
                A.galleryFilter=A.galleryBeforeTrash or 'all'
                A.galleryBeforeTrash=nil;A.galleryScroll=0
                refreshGallery()
            end}
    elseif A.folder~='' then
        A.buttons[#A.buttons+1]={x=10,y=7,w=112,h=42,
            fn=guard(function()
                local parent=''
                for _,f in ipairs(A.store.catalog.folders) do
                    if f.id==A.folder then parent=f.parent;break end
                end
                setFolder(parent)
            end)}
    end
    lg.setColor(.45,.74,.94,1)
    lg.printf(A.gallerySelecting and 'Concluir' or 'Selecionar',
        w-156,17,136,'right')
    A.buttons[#A.buttons+1]={x=w-166,y=7,w=152,h=42,
        fn=function()
            A.gallerySelecting=not A.gallerySelecting
            A.galleryDetailId=nil;A.galleryDetailSwipe=nil
            A.gallerySelected={}
        end}
    if not A.galleryTrash and not A.galleryDetailId then
        -- O glifo de reticencias da fonte Windows virava quadrado.
        -- Preservar hitbox e callback do menu existente.
        lg.setColor(.45,.74,.94,1)
        Icons.draw('gallery-more',168,26,22)
        A.buttons[#A.buttons+1]={x=138,y=6,w=64,h=42,
            fn=function()A.galleryMoreMenu=true end}
    end
    -- A galeria original vai diretamente da barra de titulo para
    -- as miniaturas. As abas Tudo/Desenhos/Pastas eram particulares
    -- do rebuild e nao existem na referencia oficial.
    lg.setColor(.96,.95,.92,1)
    lg.rectangle('fill',0,54,w,l.footerY-54)
    lg.setColor(.71,.70,.68,1)
    lg.rectangle('fill',0,53,w,1)
    if A.galleryGesture then
        GalleryShell.dragAdvance(A.galleryGesture,
            A.galleryGesture.px,A.galleryGesture.py,
            love.timer.getTime())
    end
    if A.galleryDetailId and IbisPanels.drawGalleryExpanded(w,h) then return end
    local index=0
    lg.setScissor(0,l.top,w,l.bottom-l.top)
    local function card(label,sub,folder,fn,project,identifier)
        index=index+1
        local r=GalleryShell.card(w,h,index,A.galleryScroll)
        if not r.visible then return end
        local px,py=love.mouse.getPosition()
        local hovered=GalleryShell.hit(w,h,index,A.galleryScroll,px,py)
        local selected=A.gallerySelected and A.gallerySelected[identifier]
        -- A26: hierarquia simples da galeria, sem caixa desktop
        -- ao redor de cada titulo; hitboxes permanecem inalteradas.
        IbisPanels.galleryCardChrome.drawBacking(r,selected,hovered)
        if folder then
            lg.setColor(.58,.70,.82,1)
            lg.rectangle('fill',r.preview.x+35,r.preview.y+42,
                r.preview.w-70,50,5,5)
            lg.rectangle('fill',r.preview.x+35,r.preview.y+32,
                31,17,3,3)
        else
            local preview=project and galleryPreview(project)
            if preview then
                local pw,ph=preview:getDimensions()
                local left=r.preview.x+(r.preview.w-pw)/2
                local top=r.preview.y+(r.preview.h-ph)/2
                lg.setColor(1,1,1,1)
                lg.draw(preview,left,top)
            else
                lg.setColor(.58,.61,.64,1)
                lg.rectangle('line',r.preview.x+42,
                    r.preview.y+39,56,52)
            end
        end
        IbisPanels.galleryCardChrome.drawCaption(
            r,label,sub,A.fonts.small,A.fonts.micro,A.galleryTrash)
        if selected then
            lg.setColor(.14,.43,.80,1)
            lg.circle('fill',r.x+r.w-13,r.y+14,9)
            lg.setColor(1,1,1,1)
            lg.setFont(A.fonts.micro)
            lg.print('✓',r.x+r.w-17,r.y+8)
        end
        local hitTop=math.max(r.y,l.top)
        local hitBottom=math.min(r.y+r.h,l.bottom)
        A.buttons[#A.buttons+1]={x=r.x,y=hitTop,w=r.w,
            h=hitBottom-hitTop,galleryKey=identifier,
            fn=guard(function()
                if A.gallerySelecting then
                    A.gallerySelected=A.gallerySelected or {}
                    A.gallerySelected[identifier]=not
                        A.gallerySelected[identifier] or nil
                else
                    fn()
                end
            end)}
    end
    if A.galleryTrash then
        for _,doc in ipairs(A.trashProjects or {}) do
            card(doc.name,IbisPanels.trash.label(
                doc.deleted_at,os.time()),false,function()
                status('Use Selecionar para recuperar desenhos')
            end,doc,'p:'..doc.id)
        end
    else
        for _,entry in ipairs(A.galleryItems or {}) do
            if GalleryUI.filter(A.galleryFilter,
                entry.type=='folder' and 'folder' or 'work') then
                if entry.type=='folder' then
                    local folder=entry.value
                    card(folder.name,'Pasta',true,
                        function()setFolder(folder.id)end,
                        nil,entry.key)
                else
                    local doc=entry.value
                    card(doc.name,doc.width..'×'..doc.height,
                        false,function()
                            A.galleryDetailId=doc.id
                            A.galleryDetailSwipe=nil
                        end,doc,entry.key)
                end
            end
        end
    end
    if A.galleryGesture and A.galleryGesture.active then
        local gesture=A.galleryGesture
        local key=GalleryShell.dragTarget(w,h,A.galleryScroll,
            A.galleryItems or {},gesture.px,gesture.py)
        if key then
            for i,item in ipairs(A.galleryItems or {}) do
                if item.key==key then
                    local r=GalleryShell.card(w,h,i,A.galleryScroll)
                    local action=GalleryShell.dropAction(
                        A.folder,nil,gesture.key,key,w,h,
                        gesture.px,gesture.py,r)
                    local grouping=action and action.kind=='group'
                    local intoFolder=action and action.kind=='move'
                    if grouping then
                        lg.setColor(.63,.36,.86,.95)
                    elseif intoFolder then
                        lg.setColor(.12,.65,.38,.95)
                    else
                        lg.setColor(.20,.51,.92,.95)
                    end
                    lg.setLineWidth(4)
                    lg.rectangle('line',r.x+2,r.y+2,
                        r.w-4,r.h-4,5,5)
                    if grouping or intoFolder then
                        lg.setColor(grouping and .35 or .07,
                            grouping and .17 or .34,
                            grouping and .55 or .19,.96)
                        lg.rectangle('fill',r.x+8,r.y+r.h-39,
                            r.w-16,27,4,4)
                        lg.setColor(1,1,1,1)
                        lg.setFont(A.fonts.micro)
                        lg.printf(grouping and 'Criar pasta'
                            or 'Mover para pasta',r.x+10,
                            r.y+r.h-32,r.w-20,'center')
                    end
                    break
                end
            end
        end
    end
    lg.setScissor()
    if A.galleryGesture and A.galleryGesture.active
        and A.galleryGesture.key:sub(1,2)=='p:'
        and A.folder~='' and
        GalleryShell.parentDrop(w,h,
            A.galleryGesture.px,A.galleryGesture.py) then
        lg.setColor(.12,.65,.38,1)
        lg.setLineWidth(3)
        lg.rectangle('line',11,8,110,39,5,5)
        lg.setColor(.12,.43,.28,1)
        lg.rectangle('fill',125,8,232,39,5,5)
        lg.setColor(1,1,1,1)
        lg.setFont(A.fonts.small)
        lg.printf('Mover à pasta superior',130,20,222,'center')
    end
    if total==0 then
        lg.setColor(.45,.47,.49,1)
        lg.setFont(A.fonts.body)
        lg.printf(A.galleryTrash and 'Nenhuma obra excluída' or
            A.galleryFilter=='folders' and 'Nenhuma pasta' or
            A.galleryFilter=='works' and 'Nenhum desenho' or
            'A Minha Galeria está vazia',
            0,math.floor((l.top+l.bottom)/2)-24,w,'center')
    end
    -- Rodape dedicado ao modo de selecao; nao altera bytes RBD.
    lg.setColor(.18,.19,.20,1)
    lg.rectangle('fill',0,l.footerY,w,h-l.footerY)
    if A.galleryTrash then
        local keys=GalleryShell.selectionKeys(
            {},A.trashProjects or {},'works')
        local count=GalleryShell.selectionCount(
            A.gallerySelected or {},keys)
        lg.setColor(.84,.87,.91,1)
        lg.setFont(A.fonts.small)
        if A.gallerySelecting then
            lg.print(('%d de %d selecionados'):format(count,#keys),
                20,l.footerY+18)
            for _,item in ipairs({
                {id='all',label='Todos'},
                {id='clear',label='Limpar'},
                {id='recover',label='Recuperar'}}) do
                local r=IbisPanels.trash.trashAction(w,h,item.id)
                local enabled=item.id=='all' and count<#keys
                    or item.id=='clear' and count>0
                    or item.id=='recover' and count>0
                lg.setColor(enabled and .24 or .23,
                    enabled and .46 or .26,
                    enabled and .72 or .29,1)
                lg.rectangle('fill',r.x,r.y,r.w,r.h,4,4)
                lg.setColor(enabled and .96 or .57,
                    enabled and .97 or .61,
                    enabled and .99 or .66,1)
                lg.printf(item.label,r.x,r.y+9,r.w,'center')
                if enabled then
                    local command=item.id
                    A.buttons[#A.buttons+1]={
                        x=r.x,y=r.y,w=r.w,h=r.h,fn=function()
                        if command=='all' then
                            A.gallerySelected=GalleryShell.selectAll(keys)
                        elseif command=='clear' then
                            A.gallerySelected={}
                        else
                            local ids=GalleryShell.selectedProjectIds(
                                A.gallerySelected,keys)
                            if ids then A.galleryRestoreMenu={ids=ids} end
                        end
                    end}
                end
            end
        else
            lg.print('Selecione desenhos para recuperar',
                20,l.footerY+18)
            lg.printf('30 dias · limpeza automática pendente',
                w-340,l.footerY+18,324,'right')
        end
    elseif A.gallerySelecting then
        local keys=GalleryShell.selectionKeys(
            A.folders,A.projects,A.galleryFilter)
        local count=GalleryShell.selectionCount(
            A.gallerySelected or {},keys)
        lg.setColor(.89,.93,.97,1)
        lg.setFont(A.fonts.small)
        lg.print(('%d de %d selecionados'):format(count,#keys),
            20,l.footerY+18)
        for _,item in ipairs({
            {id='all',label='Todos'},
            {id='clear',label='Limpar'},
            {id='move',label='Mover'},
            {id='delete',label='Excluir'}}) do
            local r=GalleryShell.selectionAction(w,h,item.id)
            local enabled=GalleryShell.selectionAvailable(item.id)
                and (item.id=='all' and count<#keys
                    or item.id=='clear' and count>0
                    or (item.id=='move' or item.id=='delete') and
                        GalleryShell.selectedProjectIds(
                            A.gallerySelected or {},keys)~=nil)
            local pending=not GalleryShell.selectionAvailable(item.id)
            lg.setColor(pending and .27 or enabled and .24 or .23,
                pending and .29 or enabled and .46 or .26,
                pending and .31 or enabled and .72 or .29,1)
            lg.rectangle('fill',r.x,r.y,r.w,r.h,4,4)
            lg.setColor(pending and .53 or enabled and .96 or .57,
                pending and .55 or enabled and .97 or .61,
                pending and .57 or enabled and .99 or .66,1)
            lg.setFont(A.fonts.small)
            lg.printf(item.label,r.x,r.y+9,r.w,'center')
            if enabled then
                local command=item.id
                A.buttons[#A.buttons+1]={x=r.x,y=r.y,
                    w=r.w,h=r.h,fn=function()
                    if command=='all' then
                        A.gallerySelected=GalleryShell.selectAll(keys)
                    elseif command=='clear' then
                        A.gallerySelected={}
                    elseif command=='move' then
                        local ids=GalleryShell.selectedProjectIds(
                            A.gallerySelected,keys)
                        if ids then
                            A.galleryMoveMenu={ids=ids,page=1}
                        end
                    elseif command=='delete' then
                        local ids=GalleryShell.selectedProjectIds(
                            A.gallerySelected,keys)
                        if ids then A.galleryDeleteMenu={ids=ids} end
                    end
                end}
            end
        end
    else
        -- Fluxo normal preservado: "+" abre nova tela/pasta.
        lg.setColor(.36,.66,.95,1)
        lg.setFont(A.fonts.title)
        lg.print('+',20,l.footerY+7)
        A.buttons[#A.buttons+1]={x=9,y=l.footerY,w=63,h=52,
            fn=function()A.galleryCreateMenu=true end}
        lg.setColor(.74,.77,.81,1)
        lg.setFont(A.fonts.small)
        lg.print(A.folder=='' and 'A Minha Galeria' or 'Pasta atual',
            85,l.footerY+18)
        if total>0 then
            lg.printf(('Itens: %d'):format(total),
                w-165,l.footerY+18,146,'right')
        end
    end
    if A.galleryScroll>0 and
        GalleryShell.maxScroll(w,h,total)>0 then
        lg.setColor(.38,.57,.75,1)
        lg.rectangle('fill',w-5,l.top+math.floor(
            A.galleryScroll/GalleryShell.maxScroll(w,h,total)*
            (l.bottom-l.top-42)),3,42,1,1)
    end
end
local function drawGalleryCreateMenu(w,h)
    local lg=love.graphics
    if A.galleryMoreMenu then
        local p=IbisPanels.trash.morePopup(w,h)
        local r=IbisPanels.trash.moreItem(p)
        lg.setColor(0,0,0,.25)
        lg.rectangle('fill',0,0,w,h)
        lg.setColor(.22,.24,.27,1)
        lg.rectangle('fill',p.x,p.y,p.w,p.h,5,5)
        button('Excluídos recentemente',r.x,r.y,r.w,r.h,
            function()
                A.galleryMoreMenu=false
                A.galleryBeforeTrash=A.galleryFilter
                A.galleryTrash=true;A.galleryFilter='works'
                A.gallerySelecting=false;A.gallerySelected={}
                A.galleryScroll=0;refreshGallery()
            end)
        return
    end
    if A.galleryDeleteMenu or A.galleryRestoreMenu then
        local deleting=A.galleryDeleteMenu~=nil
        local state=A.galleryDeleteMenu or A.galleryRestoreMenu
        local p=GalleryShell.confirmPopup(w,h)
        lg.setColor(0,0,0,.69)
        lg.rectangle('fill',0,0,w,h)
        lg.setColor(.96,.96,.96,1)
        lg.rectangle('fill',p.x,p.y,p.w,p.h,8,8)
        lg.setColor(.18,.21,.25,1)
        lg.setFont(A.fonts.title)
        lg.print(deleting and 'Excluir desenhos?' or
            'Recuperar desenhos?',p.x+23,p.y+20)
        lg.setFont(A.fonts.body)
        lg.printf(deleting and
            ('Enviar %d obra(s) para Excluídos recentemente?')
                :format(#state.ids)
            or ('Restaurar %d obra(s) às pastas originais?')
                :format(#state.ids),
            p.x+23,p.y+77,p.w-46,'left')
        lg.setFont(A.fonts.small)
        lg.setColor(.41,.44,.48,1)
        lg.printf('Os arquivos RBD serão preservados. '..
            'Limpeza automática após 30 dias: pendente.',
            p.x+23,p.y+124,p.w-46,'left')
        local cancel=GalleryShell.confirmCancel(p)
        button('Cancelar',cancel.x,cancel.y,cancel.w,cancel.h,
            function()
                A.galleryDeleteMenu=nil
                A.galleryRestoreMenu=nil
            end)
        local confirm=GalleryShell.confirmAction(p)
        button(deleting and 'Excluir' or 'Recuperar',
            confirm.x,confirm.y,confirm.w,confirm.h,
            function()
                if deleting then
                    local report=A.store:deleteProjects(
                        state.ids,A.folder)
                    A.galleryDeleteMenu=nil
                    A.gallerySelected={}
                    A.gallerySelecting=false
                    A.galleryScroll=0
                    refreshGallery()
                    status(('%d obra(s) excluída(s) recuperavelmente')
                        :format(report.deleted))
                else
                    local report=A.store:restoreProjects(state.ids)
                    A.galleryRestoreMenu=nil
                    A.galleryScroll=0
                    A.gallerySelecting=false;A.gallerySelected={}
                    refreshGallery()
                    status(('%d obra(s) recuperada(s)')
                        :format(report.restored))
                end
            end,true)
        return
    end
    if A.galleryMoveMenu then
        local state=A.galleryMoveMenu
        local p=GalleryShell.movePopup(w,h)
        local choices=GalleryShell.folderChoices(
            A.store.catalog.folders,A.folder)
        local pages=GalleryShell.movePageCount(#choices)
        state.page=math.min(state.page,pages)
        lg.setColor(0,0,0,.55)
        lg.rectangle('fill',0,0,w,h)
        lg.setColor(.95,.95,.94,1)
        lg.rectangle('fill',p.x,p.y,p.w,p.h,8,8)
        lg.setColor(.19,.24,.30,1)
        lg.setFont(A.fonts.title)
        lg.print(('Mover %d desenho(s)'):format(#state.ids),
            p.x+24,p.y+18)
        lg.setFont(A.fonts.small)
        lg.setColor(.4,.45,.49,1)
        lg.print('Selecione a pasta de destino:',p.x+24,p.y+65)
        if state.creating then
            lg.setColor(.19,.24,.30,1)
            lg.setFont(A.fonts.body)
            lg.print('Nova pasta',p.x+24,p.y+101)
            lg.setFont(A.fonts.small)
            lg.setColor(.39,.44,.49,1)
            lg.print('Criada dentro da pasta escolhida (ou da origem).',
                p.x+24,p.y+125)
            local nameRect=GalleryShell.moveFolderNameRect(p)
            button('',nameRect.x,nameRect.y,nameRect.w,nameRect.h,
                function()love.keyboard.setTextInput(true)end,true)
            fitted(state.createName..'|',
                nameRect.x+11,nameRect.y+12,'body','text',
                nameRect.w-22)
            lg.setColor(.42,.47,.51,1)
            lg.setFont(A.fonts.small)
            lg.printf('Informe um nome de 1 a 240 bytes.',
                p.x+24,p.y+206,p.w-48,'left')
            if state.createError then
                lg.setColor(.82,.27,.23,1)
                lg.printf(state.createError,
                    p.x+24,p.y+249,p.w-48,'left')
            end
            local cancel=GalleryShell.moveCancelRect(p)
            button('Voltar',cancel.x,cancel.y,
                cancel.w,cancel.h,function()
                    GalleryShell.cancelNewFolder(state)
                    love.keyboard.setTextInput(false)
                end)
            local confirm=GalleryShell.moveConfirmRect(p)
            button('Criar pasta',confirm.x,confirm.y,
                confirm.w,confirm.h,function()
                    local ok,id=GalleryShell.createDestination(
                        A.store,state,A.folder)
                    if ok then
                        love.keyboard.setTextInput(false)
                        refreshGallery()
                        status('Pasta criada e selecionada para mover')
                    else
                        status('Não foi possível criar a pasta: '..
                            tostring(id))
                    end
                end,true,state.createName=='')
            return
        end
        local create=GalleryShell.moveNewFolderRect(p)
        button('+ Nova pasta',create.x,create.y,
            create.w,create.h,function()
                GalleryShell.openNewFolder(state,A.folder)
                love.keyboard.setTextInput(true)
            end)
        if #choices==0 then
            lg.setColor(.63,.44,.20,1)
            lg.printf('Nenhuma outra pasta disponível. Crie uma pasta na galeria.',
                p.x+38,p.y+175,p.w-76,'center')
        end
        for i=1,6 do
            local entry=choices[(state.page-1)*6+i]
            if entry then
                local slot=GalleryShell.moveRow(p,i)
                local choice=entry
                button(entry.label,slot.x,slot.y,slot.w,slot.h,
                    function()state.target=choice.id end,
                    state.target==entry.id)
            end
        end
        if pages>1 then
            local back=GalleryShell.moveNavRect(p,1)
            local next=GalleryShell.moveNavRect(p,2)
            button('‹',back.x,back.y,back.w,back.h,function()
                state.page=GalleryShell.movePage(state.page,pages,-1)
            end,false,state.page==1)
            button('›',next.x,next.y,next.w,next.h,function()
                state.page=GalleryShell.movePage(state.page,pages,1)
            end,false,state.page==pages)
            lg.setColor(.25,.28,.32,1)
            lg.printf(('%d / %d'):format(state.page,pages),
                p.x+150,p.y+p.h-83,p.w-300,'center')
        end
        local cancel=GalleryShell.moveCancelRect(p)
        button('Cancelar',cancel.x,cancel.y,cancel.w,cancel.h,
            function()
                A.galleryMoveMenu=nil
                love.keyboard.setTextInput(false)
            end)
        local confirm=GalleryShell.moveConfirmRect(p)
        button('Mover',confirm.x,confirm.y,confirm.w,confirm.h,
            function()
                local report=A.store:moveProjects(
                    state.ids,state.target,A.folder)
                for _,id in ipairs(report.ids) do
                    A.gallerySelected['p:'..id]=nil
                end
                A.galleryMoveMenu=nil
                A.galleryScroll=0
                refreshGallery()
                if report.error then
                    status(('Movidos %d/%d; erro ao gravar: %s'):format(
                        report.moved,report.total,report.error))
                else
                    A.gallerySelecting=false
                    A.gallerySelected={}
                    status(('%d desenho(s) movido(s)'):format(
                        report.moved))
                end
            end,true,state.target==nil)
        return
    end
    lg.setColor(0,0,0,.36)
    lg.rectangle('fill',0,0,w,h)
    local p=GalleryShell.newMenu(w,h)
    lg.setColor(.23,.25,.28,1)
    lg.rectangle('fill',p.x,p.y,p.w,p.h,7,7)
    for i,label in ipairs({'Nova tela','Nova pasta','Cancelar'}) do
        local r=GalleryShell.newOption(p,i)
        button(label,r.x,r.y,r.w,r.h,function()
            A.galleryCreateMenu=false
            if i==1 then modal('new')
            elseif i==2 then modal('folder') end
        end,i==1)
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
    local label=kind=='diameter' and 'Espessura' or 'Opacidade'
    local valueLabel=kind=='diameter' and ('%d px'):format(value) or
        ('%.0f%%'):format(value*100)
    text(label,d.labelX,d.y-2,'small','muted')
    text(valueLabel,d.valueX,d.y-2,'small','text')
    c('line')
    love.graphics.rectangle('fill',d.x,d.y+5,d.w,5,2,2)
    c('accent')
    love.graphics.rectangle('fill',d.x,d.y+5,
        math.max(1,d.w*factor),5,2,2)
    c('text')
    love.graphics.circle('fill',d.x+d.w*factor,d.y+7,7,18)
end
local function activateIbisTool(tool)
    if tool.id~='wand' then clearWandSelection() end
    if tool.id=='vector' or tool.id=='frame' then
        A.visualPendingTool=tool.id
        A.vectorFrameUi=VectorFrameUI.new(tool.id)
        A.compactPanel=tool.id
        status(tool.label..' · interface disponivel, motor pendente')
        return
    end
    if tool.id=='smudge' or tool.id=='blur'
        or tool.id=='special' then
        A.visualPendingTool=tool.id
        A.effectUi=EffectUI.new(tool.id)
        A.compactPanel=tool.id
        status(tool.label..': interface visual, motor pendente')
        return
    end
    if tool.id=='wand' or tool.id=='lasso' then
        A.visualPendingTool=tool.id
        A.selectionToolUi=SelectionToolUI.new(tool.id)
        A.compactPanel=tool.id
        status(tool.id=='wand' and
            'Varinha: clique na tela para criar máscara RGBA'
            or 'Laço: interface visual; motor pendente')
        return
    end
    if tool.id=='transform' then
        A.visualPendingTool='transform'
        A.transformUi=TransformUI.new()
        A.compactPanel='transform'
        status('Transformar: interface independente, motor pendente')
        return
    end
    if tool.id=='text' then
        A.visualPendingTool='text'
        A.textUi=TextUI.new()
        A.compactPanel='text'
        status('Texto: interface aberta, motor Lua pendente')
        return
    end
    if tool.id=='filter' then
        A.visualPendingTool='filter'
        A.filterCategory=A.filterCategory or 'adjust'
        A.filterPage=1
        A.filterPendingId=nil
        A.compactPanel='filters'
        status('Filtros · interface disponível, motor pendente')
        return
    end
    local ok,entry=IbisTools.select(tool.id,selectTool)
    if ok then
        A.visualPendingTool=nil
        A.compactPanel=nil
    else
        A.visualPendingTool=entry.id
        status(entry.label..' · motor Lua pendente')
    end
end
local function drawEditorToolRail(w,h)
    local count=#IbisTools.entries
    local position=A.toolRailPosition or 'left'
    local rect=EditorRail.layout(w,h,A.toolRailPage or 1,count,position)
    c('panel',.78)
    love.graphics.rectangle('fill',rect.x-1,rect.y-4,
        rect.w+2,(rect.stop-rect.start+1)*rect.row+
        (rect.pages>1 and 31 or 8),6,6)
    for _,item in ipairs(EditorRail.entries(w,h,rect.page,
        IbisTools.entries,position)) do
        local tool=IbisTools.get(item.id)
        local active=(not A.visualPendingTool and tool.backend~=nil
            and tool.backend==A.tool)
            or A.visualPendingTool==item.id
        local mx,my=love.mouse.getPosition()
        local hover=mx>=item.x and mx<item.x+item.w
            and my>=item.y and my<item.y+item.h
        if active or hover then
            c(active and 'selected' or 'line')
            love.graphics.rectangle('fill',item.x+2,item.y+1,
                item.w-4,item.h-2,3,3)
        end
        c(active and 'accent' or 'text')
        Icons.draw(item.icon,item.x+item.w/2,item.y+11,16)
        love.graphics.setFont(A.fonts.micro)
        love.graphics.printf(item.shortLabel,item.x+1,
            item.y+21,item.w-2,'center')
        A.buttons[#A.buttons+1]={x=item.x,y=item.y,w=item.w,h=item.h,
            fn=guard(function()activateIbisTool(tool)end)}
    end
    local page=EditorRail.navigation(w,h,rect.page,count,position)
    if page then
        box(page.x+1,page.y,page.w-2,page.h,'card')
        fitted(('%d/%d'):format(rect.page,rect.pages),
            page.x+33,page.y+8,'small','text',40)
        for _,item in ipairs({{x=page.x,delta=-1,enabled=page.back},
            {x=page.x+page.w-30,delta=1,enabled=page.forward}}) do
            if item.enabled then
                c('text')
                love.graphics.print(item.delta==-1 and '‹' or '›',
                    item.x+7,page.y+2)
                local delta=item.delta
                A.buttons[#A.buttons+1]={x=item.x,y=page.y,w=30,h=page.h,
                    fn=guard(function()
                        A.toolRailPage=EditorRail.nextPage(w,h,
                            A.toolRailPage,count,delta,position)
                    end)}
            end
        end
    end
end
-- Seis controles no canto superior direito, com a ordem e a
-- separação de tarefas documentadas nos tutoriais do ibisPaint.
-- Ações sem backend permanecem explícitas e nunca pintam no canvas.
local function drawTopToolbar(w,h)
    for _,slot in ipairs(TopToolbar.toolbar(w,h)) do
        local active=(slot.id=='selection' and A.tool=='select')
            or (slot.id=='shape' and A.tool=='shape')
            or (slot.id=='view' and A.compactPanel=='view')
            or (slot.id=='stabilizer' and A.compactPanel=='stabilizer')
            or (slot.id=='ruler' and A.compactPanel=='ruler')
            or (slot.id=='materials' and A.compactPanel=='materials')
        local mx,my=love.mouse.getPosition()
        local hovered=mx>=slot.x and mx<=slot.x+slot.w
            and my>=slot.y and my<=slot.y+slot.h
        c(active and 'selected' or hovered and 'line' or 'panel',.84)
        love.graphics.rectangle('fill',slot.x,slot.y,
            slot.w,slot.h,slot.h/2,slot.h/2)
        c(active and 'accent' or 'line')
        love.graphics.setLineWidth(1)
        love.graphics.rectangle('line',slot.x+.5,slot.y+.5,
            slot.w-1,slot.h-1,slot.h/2,slot.h/2)
        c(active and 'accent' or 'text')
        Icons.draw(slot.icon,slot.x+slot.w/2,
            slot.y+slot.h/2,19)
        A.buttons[#A.buttons+1]={
            x=slot.x,y=slot.y,w=slot.w,h=slot.h,
            fn=guard(function()
                if slot.id=='selection' or slot.id=='shape' then
                    local target=slot.id=='selection' and 'select' or 'shape'
                    if selectTool(target) then
                        A.compactPanel='properties'
                    end
                else
                    toggleCompactPanel(slot.id)
                end
            end)}
        if hovered and not A.compactPanel then
            local labelX=math.max(10,
                math.min(w-144,slot.x-45))
            box(labelX,slot.y+slot.h+5,132,24,'panel')
            fitted(slot.label,labelX+8,slot.y+slot.h+10,
                'small','text',118)
        end
    end
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
        -- Controles compactos são desenhados depois do canvas, para não
        -- serem encobertos pelo fundo cinza nem terem hitboxes invisíveis.
    end
    if not A.compactUi then
        button('Layout compacto',w-645,15,134,33,toggleCompactUi)
        button(A.previewEnabled and 'Prévia: ligada' or 'Prévia: desligada',
            w-501,15,134,33,function()
                A.previewEnabled=not A.previewEnabled
            end,A.previewEnabled)
    end
    local cx,cy=canvasTransform()
    if A.compactUi and not A.focusMode then
        box(0,0,w,h-130,'canvas')
    else
        box(12,120,w-Workspace.panelWidth(paneHidden())-20,h-178,'canvas')
    end
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
    if A.wandOverlay then
        love.graphics.setColor(1,1,1,1)
        love.graphics.draw(A.wandOverlay,-dw/2,-dh/2)
    end
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
    if A.compactUi then
        if A.focusMode then
            button('Mostrar interface · Tab',18,8,196,36,toggleFocusMode)
        else
            -- Controles desktop ficam discretos no canto superior
            -- esquerdo, fora do seletor de ferramentas.
            button('Salvar',85,7,70,28,saveDoc,A.dirty)
            button('Desktop',161,7,79,28,toggleCompactUi)
            button('Ajustes',246,7,70,28,function()
                toggleCompactPanel('properties')
            end)
            button('−',104,48,33,29,function()
                zoomCanvas(1/1.25)
            end,false,A.zoom<=View.MIN_ZOOM)
            button('+',141,48,33,29,function()
                zoomCanvas(1.25)
            end,false,A.zoom>=View.MAX_ZOOM)
            button('Ajustar',180,48,68,29,fit)
            text(('%d%%'):format(math.floor(A.zoom*100+.5)),
                258,55,'small','muted')
            drawTopToolbar(w,h)
        end
    end
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
        text('FORMAS · RASTER Lua',panel+20,377,'small','muted')
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
            -- Keep the Camadas/Pincel tabs at y=366 unobstructed.
            -- Each parameter controls its own pressure channel below.
            if A.sideTab=='brush' then
                text('P = resposta à pressão',panel+20,401,'small','muted')
            end
            if A.tool=='brush' then
                button(A.penTiltEnabled and 'Ink: ativa'
                    or 'Ink: desligada',
                    panel+20,416,108,28,function()
                        finishStroke()
                        A.penTiltEnabled=not A.penTiltEnabled
                    end,A.penTiltEnabled)
            else
                text('BORRACHA',panel+20,424,'small','muted')
            end
            button('Curva: '..PressureCurves.LABELS[A.pressureCurve],
                panel+140,416,108,28,function()
                    finishStroke()
                    A.pressureCurve=PressureCurves.next(A.pressureCurve)
                    status('Pressão: curva '..PressureCurves.LABELS[A.pressureCurve])
                end,A.pressureCurve~='linear')
            button('−',panel+20,456,46,32,function()
                A.brushDiameter=math.max(1,A.brushDiameter-2)end)
            text(('Tam. %.0f px'):format(A.brushDiameter),panel+75,464,'small')
            button(A.pressureSize and 'P ON' or 'P OFF',
                panel+138,456,40,32,function()
                    finishStroke()
                    A.pressureSize=not A.pressureSize
                    status('Pressão no tamanho: '..
                        (A.pressureSize and 'ativa' or 'desligada'))
                end,A.pressureSize)
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
            text(('Alfa %.0f%%'):format(A.brushOpacity*100+0.01),
                panel+69,630,'small','muted')
            button(A.pressureOpacity and 'P ON' or 'P OFF',
                panel+151,622,48,30,function()
                    finishStroke()
                    A.pressureOpacity=not A.pressureOpacity
                    status('Pressão na opacidade: '..
                        (A.pressureOpacity and 'ativa' or 'desligada'))
                end,A.pressureOpacity)
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
        -- Os sliders acompanham o fundo cinza da area de desenho.
        box(0,h-130,w,70,'canvas')
        box(0,h-60,w,60,'panel')
        c('line')
        love.graphics.rectangle('fill',0,h-61,w,1)
        -- Barra de regulagens menos intrusiva, proxima do original.
        local activeName=A.visualPendingTool and
            (A.visualPendingTool=='wand' and 'Varinha Mágica'
            or A.visualPendingTool=='lasso' and 'Laço'
            or 'Ferramenta pendente')
            or EditorTools.fromId(A.tool).label
        fitted(activeName,22,h-113,'small','muted',170)
        if not A.visualPendingTool and
            (A.tool=='brush' or A.tool=='erase') then
            drawCompactQuick('diameter',w,h,A.brushDiameter)
            drawCompactQuick('opacity',w,h,A.brushOpacity)
        elseif A.visualPendingTool=='wand' then
            text('Clique no desenho para selecionar por cor',
                (w-450)/2,h-110,'small','text')
            text('A máscara ainda não restringe a pintura',
                (w-450)/2,h-84,'small','muted')
        elseif A.visualPendingTool then
            text('Ferramenta sem motor de edição',
                (w-360)/2,h-106,'small','muted')
        else
            text(('Zoom %.0f%% · %s'):format(A.zoom*100,
                EditorTools.fromId(A.tool).label),
                (w-350)/2,h-113,'small','muted')
        end
        c('line')
        love.graphics.rectangle('fill',w/2-352,h-62,704,1)
        for _,slot in ipairs(Compact.toolbar(w,h)) do
            local active=(slot.id=='brush' and not A.visualPendingTool
                and (A.tool=='brush' or A.tool=='erase')) or
                (slot.id=='tools' and A.compactPanel=='tools') or
                (slot.id=='layers' and A.compactPanel=='layers') or
                (slot.id=='properties' and A.compactPanel=='properties')
            local disabled=(slot.id=='undo' and
                not A.layerSession:canUndo()) or
                (slot.id=='redo' and not A.layerSession:canRedo())
            local mx,my=love.mouse.getPosition()
            local over=mx>=slot.x and mx<slot.x+slot.w
                and my>=slot.y and my<slot.y+slot.h
            if active or (over and not disabled) then
                c(active and 'selected' or 'line')
                love.graphics.rectangle('fill',
                    slot.x+2,slot.y+2,slot.w-4,slot.h-4,3,3)
            end
            c(disabled and 'muted' or active and 'accent' or 'text')
            Icons.draw(slot.id=='brush' and
                (A.tool=='erase' and 'erase' or 'brush') or slot.id,
                slot.x+slot.w/2,slot.y+slot.h/2,23)
            if slot.id=='color' then
                local r,g,b=Colors.channels(A.color)
                love.graphics.setColor(r/255,g/255,b/255,1)
                love.graphics.rectangle('fill',
                    slot.x+slot.w/2+13,slot.y+slot.h/2+11,12,7,1,1)
            end
            if active then
                c('accent')
                love.graphics.rectangle('fill',slot.x+13,
                    slot.y+slot.h-3,slot.w-26,2)
            end
            if not disabled then
                A.buttons[#A.buttons+1]={x=slot.x,y=slot.y,
                    w=slot.w,h=slot.h,fn=guard(function()
                    if slot.id=='brush' then
                        selectTool(A.tool=='brush' and 'erase' or 'brush')
                    elseif slot.id=='tools' or slot.id=='layers' or
                        slot.id=='properties' then
                        toggleCompactPanel(slot.id)
                    elseif slot.id=='color' then openCompactColor()
                    elseif slot.id=='fullscreen' then toggleFocusMode()
                    elseif slot.id=='undo' then undoDoc()
                    elseif slot.id=='redo' then redoDoc()
                    elseif slot.id=='back' then
                        -- Inline para nao exceder o limite de 60
                        -- upvalues do drawEditor no LuaJIT 2.1.
                        finishStroke()
                        A.shapePreview=nil;A.quickDrag=nil
                        A.panning=false;A.panButton=nil
                        A.colorDrag=nil;A.compactPanel=nil
                        A.backMenu=true;A.settingsOpen=false
                    end
                end)}
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
local function drawNewCanvasDialog(w,h)
    local r=IbisPanels.canvasReference.layout(w,h)
    local m=A.modal
    IbisPanels.canvasReferenceDraw.panel(r,A.fonts.body,A.fonts.small)
    local close=IbisPanels.canvasReference.close(r)
    A.buttons[#A.buttons+1]={
        x=close.x,y=close.y,w=close.w,h=close.h,
        fn=function()
            A.canvasDimensionDrag=nil
            A.modal=nil
            love.keyboard.setTextInput(false)
        end}
    -- W/H diretamente no inicio da lista, como na referencia.
    for _,axis in ipairs({2,3}) do
        local field=IbisPanels.canvasReference.field(r,axis)
        box(field.x,field.y,field.w,field.h,'card')
        if m.focus==axis then
            c('accent')
            love.graphics.rectangle('line',
                field.x+.5,field.y+.5,field.w-1,field.h-1)
        end
        fitted(m.values[axis]..(m.focus==axis and '|' or ''),
            field.x+9,field.y+5,'body','text',field.w-13)
        A.buttons[#A.buttons+1]={
            x=field.x,y=field.y,w=field.w,h=field.h,
            fn=function()m.focus=axis end}
        for _,direction in ipairs({-1,1}) do
            local bt=IbisPanels.canvasReference.stepper(r,axis,direction)
            local nextValue=GalleryUI.stepDimension(
                m.values[axis],direction)
            local mx,my=love.mouse.getPosition()
            IbisPanels.canvasDimensionControls.draw(bt,direction,
                nextValue~=nil,mx>=bt.x and mx<bt.x+bt.w
                    and my>=bt.y and my<bt.y+bt.h)
            if nextValue then
                A.buttons[#A.buttons+1]={
                    x=bt.x,y=bt.y,w=bt.w,h=bt.h,
                    fn=function()
                        local value=GalleryUI.stepDimension(
                            m.values[axis],direction)
                        if value then m.values[axis]=value end
                        m.focus=axis
                    end}
            end
        end
        local track=IbisPanels.canvasReference.slider(r,axis)
        local mx,my=love.mouse.getPosition()
        IbisPanels.canvasDimensionSlider.draw(track,m.values[axis],
            GalleryUI.sliderHit(track,mx,my),
            A.canvasDimensionDrag==axis,GalleryUI)
    end
    -- Lista propria do screenshot, com rolagem e recorte reais.
    local viewport=IbisPanels.canvasReference.listViewport(r)
    love.graphics.push('all')
    love.graphics.setScissor(viewport.x,viewport.y,viewport.w,viewport.h)
    for _,row in ipairs(IbisPanels.canvasReference.rows(
        r,m.canvasListScroll or 0)) do
        if row.y<viewport.y+viewport.h and
            row.y+row.h>viewport.y then
            if row.item.kind=='heading' then
                IbisPanels.canvasReferenceDraw.heading(
                    row,A.fonts.small)
            elseif IbisPanels.canvasReference.allowed(row.item) then
                local selected=m.values[2]==tostring(row.item.w)
                    and m.values[3]==tostring(row.item.h)
                local mx,my=love.mouse.getPosition()
                IbisPanels.canvasPresetRows.draw(
                    {x=row.x,y=row.y,w=row.w,h=row.h-2},
                    row.item,selected,
                    row.visible and mx>=row.x and mx<row.x+row.w
                        and my>=row.y and my<row.y+row.h,
                    A.fonts.body,A.fonts.small)
                if row.visible then
                    local id=row.item.id
                    A.buttons[#A.buttons+1]={
                        x=row.x,y=row.y,w=row.w,h=row.h-2,
                        fn=function()IbisPanels.canvasReference.choose(m,id) end}
                end
            else
                IbisPanels.canvasReferenceDraw.disabled(
                    row,A.fonts.small)
            end
        end
    end
    love.graphics.pop()
    IbisPanels.canvasReferenceDraw.footer(r,A.fonts.small)
    -- Nome permanece editavel como adaptacao ao armazenamento RBD2.
    local field=IbisPanels.canvasReference.field(r,1)
    box(field.x,field.y,field.w,field.h,'card')
    fitted(m.values[1]..(m.focus==1 and '|' or ''),
        field.x+9,field.y+5,'body','text',field.w-15)
    A.buttons[#A.buttons+1]={x=field.x,y=field.y,
        w=field.w,h=field.h,fn=function()m.focus=1 end}
    button('Cancelar',r.x+10,r.y+r.h-39,165,32,function()
        A.canvasDimensionDrag=nil
        A.modal=nil
        love.keyboard.setTextInput(false)
    end)
    button('Criar tela',r.x+181,r.y+r.h-39,r.w-191,32,
        submitModal,true,not GalleryUI.aspectViewport(
            GalleryUI.dialog(w,h),m.values[2],m.values[3]))
end
local function drawModal(w,h)
    if A.modal.kind=='new' then
        love.graphics.setColor(0,0,0,.70)
        love.graphics.rectangle('fill',0,0,w,h)
        return drawNewCanvasDialog(w,h)
    end
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
-- produced by the real Lua renderer, not a LÖVE approximation.
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
-- The larger live inspector uses the existing Lua preview renderer.
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
    local halves=Lab.comparison(rect)
    local applied=brushSampleImage('inspector_active',brushInUse())
    local currentFit=Lab.fit(applied.sample.width,
        applied.sample.height,halves.current)
    local image=brushSampleImage('inspector',draft)
    local fit=Lab.fit(image.sample.width,image.sample.height,
        halves.draft)
    local changes=Lab.differences(brushLabSource(),draft)
    love.graphics.setColor(1,1,1,1)
    love.graphics.draw(applied.image,currentFit.x,currentFit.y,
        0,currentFit.sx,currentFit.sy)
    love.graphics.draw(image.image,fit.x,fit.y,0,fit.sx,fit.sy)
    -- Legendas devem ficar visíveis mesmo sobre uma amostra de tinta.
    box(halves.current.x,halves.current.labelY-2,
        halves.current.w,18,'card')
    box(halves.draft.x,halves.draft.labelY-2,
        halves.draft.w,18,'card')
    text('EM USO',halves.current.x+4,halves.current.labelY,'small','text')
    text(('PRÉVIA · %d alterações'):format(changes),
        halves.draft.x+4,halves.draft.labelY,'small',
        changes>0 and 'accent' or 'text')
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
    local reset=Lab.resetRect(rect)
    button('Repor',reset.x,reset.y,reset.w,reset.h,
        resetBrushLab,false,changes==0)
    button(changes>0 and 'Aplicar *' or 'Aplicar',
        p.x+80,p.y+p.h-36,p.w-88,31,applyBrushLab)
end
local function drawBrushLibrary(w,h)
    local rect=Presets.layout(w,h)
    love.graphics.setColor(0,0,0,.67)
    love.graphics.rectangle('fill',0,0,w,h)
    box(rect.x,rect.y,rect.w,rect.h,'panel')
    c('line')
    love.graphics.rectangle('fill',rect.x+703,rect.y+79,1,371)
    text('Pincéis',rect.x+20,rect.y+12,'title')
    text('Básicos e personalizados · visualização de traços',
        rect.x+20,rect.y+53,'small','muted')
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
    local rows=IbisPanels.brushRows(A.brushFilter,saved)
    for row,item in ipairs(rows) do
        local i=item.index
        local r=IbisPanels.brushRow(rect,row)
        local preset=i<=4 and Presets.BUILTINS[i] or saved[i-4]
        if preset then
            local selected=Presets.matches(preset,A)
            button('',r.x,r.y,r.w,r.h,function()
                applyBrushPreset(preset)
            end,selected)
            if selected then
                c('accent')
                love.graphics.rectangle('fill',r.x,r.y,3,r.h,1,1)
            end
            fitted(preset.name,r.x+11,r.y+12,'small',
                selected and 'accent' or 'text',153)
            local preview=IbisPanels.brushPreview(rect,row)
            box(preview.x,preview.y,preview.w,preview.h,'canvas')
            local image=brushSampleImage(i,preset)
            love.graphics.setColor(1,1,1,1)
            love.graphics.draw(image.image,preview.x,preview.y,0,
                preview.w/image.sample.width,
                preview.h/image.sample.height)
            text(('%d px · %.0f%%'):format(
                preset.diameter,preset.opacity*100),
                r.x+391,r.y+12,'small','muted')
            local focus=IbisPanels.brushPreviewAction(rect,row)
            button('Editar',focus.x,focus.y,focus.w,focus.h,function()
                A.brushFocus=i
                brushLabFromFocus()
                status('Prévia: '..preset.name..' · Aplicar ajustes')
            end,A.brushFocus==i)
        else
            box(r.x,r.y,r.w,r.h,'card')
            text('Pincel pessoal '..(i-4)..' · vazio',
                r.x+13,r.y+12,'small','muted')
        end
    end
    text('Toque no traço para usar · Editar para visualizar',
        rect.x+20,rect.y+436,'small','muted')
    drawBrushLab(rect)
    text(('PINCEIS PESSOAIS  %d / %d'):format(filled,Presets.LIMIT),
        rect.x+20,rect.y+456,'small','muted')
    button('Guardar pincel atual',rect.x+20,rect.y+480,210,37,
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
-- Losango HSB independente do canvas: textura GPU regenerada somente
-- quando a matiz arredondada muda. Nenhum pixel da obra é modificado.
local function drawColorDiamond(p,hue)
    local tone=math.floor(hue+.5)%360
    local rect=ColorPanel.svRect(p)
    local cache=A.colorDiamondCache
    if not cache or cache.hue~=tone then
        if cache and cache.image then cache.image:release() end
        local pixels=love.image.newImageData(rect.w+1,rect.h+1)
        for yy=0,rect.h do
            for xx=0,rect.w do
                local px,py=rect.x+xx,rect.y+yy
                if ColorPanel.svHit(p,px,py) then
                    local sat,bright=ColorPanel.svAt(p,px,py)
                    local rgba=ColorPanel.fromHSB(tone,sat,bright,255)
                    local r,g,b=Colors.channels(rgba)
                    pixels:setPixel(xx,yy,r/255,g/255,b/255,1)
                else
                    pixels:setPixel(xx,yy,0,0,0,0)
                end
            end
        end
        local image=love.graphics.newImage(pixels)
        pixels:release()
        image:setFilter('linear','linear')
        cache={hue=tone,image=image}
        A.colorDiamondCache=cache
    end
    love.graphics.setColor(1,1,1,1)
    love.graphics.draw(cache.image,rect.x,rect.y)
    local cx,cy=rect.x+rect.w/2,rect.y+rect.h/2
    local r=rect.w/2
    love.graphics.setColor(.12,.12,.13,.85)
    love.graphics.setLineWidth(1.5)
    love.graphics.polygon('line',cx,cy-r,cx+r,cy,
        cx,cy+r,cx-r,cy)
end
local function drawHSBMiniSliders(p,hue,sat,bright)
    for _,spec in ipairs({
        {key='H',value=hue,max=360,title='H'},
        {key='S',value=sat,max=100,title='S'},
        {key='V',value=bright,max=100,title='B'}}) do
        local rail=ColorPanel.hsbMiniRect(p,spec.key)
        text(('%s: %.0f%s'):format(spec.title,spec.value,
            spec.key=='H' and '°' or '%'),
            rail.x,rail.y-24,'small','text')
        for i=0,43 do
            local t=i/43
            local value=spec.key=='H'
                and ColorPanel.fromHSB(t*360,100,100,255)
                or spec.key=='S' and ColorPanel.fromHSB(hue,t*100,100,255)
                or ColorPanel.fromHSB(hue,sat,t*100,255)
            local red,green,blue=Colors.channels(value)
            love.graphics.setColor(red/255,green/255,blue/255,1)
            love.graphics.rectangle('fill',
                rail.x+i*rail.w/44,rail.y,
                math.ceil(rail.w/44)+.1,rail.h,1,1)
        end
        local t=math.max(0,math.min(1,spec.value/spec.max))
        local dx=rail.x+rail.w*t
        love.graphics.setColor(.08,.09,.10,1)
        love.graphics.circle('fill',dx,rail.y+rail.h/2,6.5,16)
        love.graphics.setColor(1,1,1,1)
        love.graphics.circle('line',dx,rail.y+rail.h/2,5,16)
    end
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
        drawColorDiamond(p,hue)
        local selectX,selectY=ColorPanel.svPoint(p,sat,bright)
        love.graphics.setLineWidth(2)
        love.graphics.setColor(.09,.10,.11,1)
        love.graphics.circle('fill',selectX,selectY,7,20)
        love.graphics.setColor(1,1,1,1)
        love.graphics.circle('line',selectX,selectY,6,20)
        -- A roda interativa representa a matiz ao redor da caixa
        -- de saturacao/brilho. A hitbox usa a mesma geometria pura.
        local wheel=IbisPanels.wheel(p)
        for i=0,95 do
            local a0=i*math.pi/48
            local a1=(i+1)*math.pi/48
            local value=ColorPanel.fromHSB(i*360/96,100,100,255)
            local r,g,b=Colors.channels(value)
            love.graphics.setColor(r/255,g/255,b/255,1)
            love.graphics.polygon('fill',
                wheel.cx+math.cos(a0)*wheel.outer,
                wheel.cy+math.sin(a0)*wheel.outer,
                wheel.cx+math.cos(a1)*wheel.outer,
                wheel.cy+math.sin(a1)*wheel.outer,
                wheel.cx+math.cos(a1)*wheel.inner,
                wheel.cy+math.sin(a1)*wheel.inner,
                wheel.cx+math.cos(a0)*wheel.inner,
                wheel.cy+math.sin(a0)*wheel.inner)
        end
        local hx,hy=IbisPanels.wheelPoint(p,hue)
        love.graphics.setColor(.11,.12,.13,1)
        love.graphics.circle('fill',hx,hy,7,20)
        love.graphics.setColor(1,1,1,1)
        love.graphics.circle('line',hx,hy,7,20)
        drawHSBMiniSliders(p,hue,sat,bright)
        local rail=ColorPanel.hsbAlphaRect(p)
        c('line');love.graphics.rectangle('fill',rail.x,rail.y+3,
            rail.w,5,2,2)
        c('accent');love.graphics.rectangle('fill',rail.x,rail.y+3,
            rail.w*alpha/255,5,2,2)
        c('text')
        love.graphics.circle('fill',rail.x+rail.w*alpha/255,
            rail.y+5,5,18)
        text('Opacidade',x+21,y+370,'small','muted')
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
        -- O tutorial do ibisPaint mostra uma paleta inicial pronta.
        -- As amostras abaixo são nossas, não dados extraídos do APK.
        button('Cores básicas',x+22,y+169,165,31,function()
            A.paletteTab='standard'
        end,A.paletteTab=='standard')
        button(('Minhas (%d)'):format(#A.savedColors),
            x+199,y+169,189,31,function()
                A.paletteTab='personal'
            end,A.paletteTab=='personal')
        local items=PaletteUI.entries(A.paletteTab,A.savedColors)
        for i,value in ipairs(items) do
            local cell=PaletteUI.swatch(p,i)
            drawColorTile(value,cell.x,cell.y,cell.w,cell.h)
            A.buttons[#A.buttons+1]={
                x=cell.x,y=cell.y,w=cell.w,h=cell.h,
                fn=function()chooseColor(value)end}
            if A.color==value then
                c('accent')
                love.graphics.setLineWidth(2)
                love.graphics.rectangle('line',cell.x-2,cell.y-2,
                    cell.w+4,cell.h+4,3,3)
            end
        end
        if A.paletteTab=='personal' and #items==0 then
            text('Você ainda não guardou cores.',
                x+22,y+246,'body','muted')
        end
        text(('Pessoais: %d / %d'):format(#A.savedColors,
            ColorPanel.PALETTE_LIMIT),x+22,y+367,'small','muted')
        button('Guardar cor atual',x+205,y+357,183,29,
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
-- Live preview is a native Lua raster on a separate scratch buffer.
-- Its GPU image cache is shared with the stage-35 catalogue.
local function drawCompactBrushPreview(p)
    local rect=Inspector.preview(p)
    local caption=Inspector.caption(p)
    text('PRÉVIA Lua',caption.x,caption.y,'small','muted')
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
    local p=Compact.popup(w,h,kind,
        kind=='tools' and (A.toolPopupColumns or 2) or nil)
    -- Camadas tem sua propria superficie cinza e linhas claras.
    if kind=='layers' then
        LayerChrome.frame(p)
    else
        c('bg',.38)
        love.graphics.rectangle('fill',p.x+4,p.y+6,p.w,p.h,7,7)
        c('panel',kind=='tools' and .94 or .98)
        love.graphics.rectangle('fill',p.x,p.y,p.w,p.h,7,7)
        c('line',.75)
        love.graphics.setLineWidth(1)
        love.graphics.rectangle('line',p.x+.5,p.y+.5,
            p.w-1,p.h-1,7,7)
        if kind~='tools' then
            c('line',.62)
            love.graphics.rectangle('fill',p.x+1,p.y+44,p.w-2,1)
        end
    end
    if kind=='tools' then
        text('Ferramentas',p.x+12,p.y+6,'small','text')
    else
        text(kind=='tools' and 'Ferramentas' or
        kind=='layers' and 'Camadas' or
        kind=='blends' and 'Modos de mesclagem' or
        kind=='filters' and 'Filtros' or
        kind=='text' and 'Texto' or
        kind=='transform' and 'Transformar' or
        kind=='wand' and 'Varinha Mágica' or
        kind=='lasso' and 'Laço' or
        kind=='smudge' and 'Borrar' or
        kind=='blur' and 'Desfoque' or
        kind=='special' and 'Caneta Especial' or
        kind=='vector' and 'Vetor' or
        kind=='frame' and 'Dividir Quadros' or
        kind=='color' and 'Cores · RGBA' or
        kind=='view' and 'Visualização' or
        kind=='stabilizer' and 'Estabilizador' or
        kind=='ruler' and 'Régua' or
        kind=='materials' and 'Materiais' or
        A.tool=='shape' and 'Formas' or
        A.tool=='select' and 'Seleção' or
        'Ajustes',p.x+14,p.y+13,'body')
    end
    if kind=='tools' then
        -- Fechar tambem funciona por Escape, pelo dock ou clique externo.
        c('muted')
        love.graphics.setFont(A.fonts.body)
        love.graphics.print('×',p.x+p.w-20,p.y+3)
        A.buttons[#A.buttons+1]={x=p.x+p.w-30,y=p.y+2,
            w=27,h=24,fn=guard(function()
                navigateCompactPanel(nil)
            end)}
    else
        button('×',p.x+p.w-44,p.y+8,31,30,function()
            navigateCompactPanel(nil)
        end)
    end
    if kind=='blends' or kind=='filters' or kind=='text'
        or kind=='transform' or kind=='wand' or kind=='lasso'
        or kind=='smudge' or kind=='blur' or kind=='special'
        or kind=='vector' or kind=='frame' then
        button('<',p.x+p.w-79,p.y+8,31,30,function()
            navigateCompactPanel(kind=='blends' and 'layers' or 'tools')
        end)
    end
    if kind=='tools' then
        -- Colunas e exibicao dos nomes agora ficam no menu oficial
        -- Voltar > Configuracoes. O popup volta a ter cabecalho limpo.
        local columns=A.toolPopupColumns or 2
        local page=A.toolPopupPage or 1
        local mx,my=love.mouse.getPosition()
        for _,item in ipairs(IbisTools.pageItems(columns,page)) do
            local tool=item.entry
            local r=IbisTools.grid(p,item.index,columns,page)
            local active=(not A.visualPendingTool
                and tool.backend~=nil and tool.backend==A.tool)
                or A.visualPendingTool==tool.id
            local hover=mx>=r.x and mx<r.x+r.w
                and my>=r.y and my<r.y+r.h
            if active or hover then
                c(active and 'selected' or 'line',.85)
                love.graphics.rectangle('fill',r.x+1,r.y+1,
                    r.w-2,r.h-2,3,3)
            end
            c(active and 'accent' or
                tool.backend and 'text' or 'muted')
            if columns==1 and A.toolPopupLabels then
                Icons.draw(tool.icon,r.x+24,r.y+19,20)
                fitted(tool.label,r.x+49,r.y+12,
                    'small','text',r.w-54)
            else
                Icons.draw(tool.icon,r.x+r.w/2,
                    r.y+(A.toolPopupLabels and 12 or 19),19)
                if A.toolPopupLabels then
                    love.graphics.setFont(A.fonts.micro)
                    c(active and 'accent' or 'text')
                    love.graphics.printf(tool.label,r.x+3,
                        r.y+25,r.w-6,'center')
                end
            end
            A.buttons[#A.buttons+1]={x=r.x,y=r.y,w=r.w,h=r.h,
                fn=guard(function()activateIbisTool(tool)end)}
        end
        if columns==1 then
            for _,delta in ipairs({-1,1}) do
                local step=IbisTools.pageButton(p,delta)
                button(delta==-1 and '‹' or '›',
                    step.x,step.y,step.w,step.h,
                    function()
                        A.toolPopupPage=math.max(1,
                            math.min(IbisTools.pages(columns),page+delta))
                    end,false,(delta==-1 and page==1)
                        or (delta==1 and page==IbisTools.pages(columns)))
            end
            fitted(('%d / %d'):format(page,IbisTools.pages(columns)),
                p.x+88,p.y+p.h-53,'small','text',65)
        end
        c('line',.66)
        love.graphics.rectangle('fill',p.x+8,p.y+p.h-27,p.w-16,1)
        fitted('Ferramentas sem motor: prévia apenas',
            p.x+12,p.y+p.h-19,'micro','muted',p.w-24)
    elseif kind=='vector' or kind=='frame' then
        local draft=assert(A.vectorFrameUi,'Rascunho vetorial ausente')
        assert(draft.kind==kind,'Ferramenta visual divergente')
        for i,tab in ipairs(VectorFrameUI.tabs[kind]) do
            local r=VectorFrameUI.tabRect(p,i)
            button(tab.label,r.x,r.y,r.w,r.h,function()
                VectorFrameUI.chooseTab(draft,tab.id)
            end,draft.tab==tab.id)
        end
        if kind=='vector' then
            local area=VectorFrameUI.vectorPreview(p)
            box(area.x,area.y,area.w,area.h,'card')
            c('muted')
            love.graphics.setLineWidth(1.6)
            local midX,midY=area.x+area.w/2,area.y+56
            love.graphics.line(midX-75,midY+16,
                midX-44,midY-22,midX+4,midY+12,
                midX+57,midY-18,midX+74,midY+18)
            c('accent')
            for _,pt in ipairs({{-75,16},{-44,-22},{4,12},{57,-18},{74,18}}) do
                love.graphics.circle('fill',midX+pt[1],midY+pt[2],3.5,12)
            end
            fitted('Exemplo vetorial · somente interface',
                area.x+18,area.y+105,'small','muted',area.w-36)
            local first=VectorFrameUI.vectorAction(p,1)
            local second=VectorFrameUI.vectorAction(p,2)
            if draft.tab=='select' then
                button(draft.multi and 'Modo: múltiplas formas'
                    or 'Modo: uma forma',first.x,first.y,
                    first.w,first.h,function()
                    VectorFrameUI.toggleMulti(draft)
                end,draft.multi)
                button('Selecionar forma · indisponível',
                    second.x,second.y,second.w,second.h,
                    function()end,false,true)
            elseif draft.tab=='vertices' then
                button('Editar vértices · indisponível',
                    first.x,first.y,first.w,first.h,
                    function()end,false,true)
                button('Editar curvas · indisponível',
                    second.x,second.y,second.w,second.h,
                    function()end,false,true)
            else
                button('Trazer para frente · indisponível',
                    first.x,first.y,first.w,first.h,
                    function()end,false,true)
                button('Enviar para trás · indisponível',
                    second.x,second.y,second.w,second.h,
                    function()end,false,true)
            end
            text('Sem camada vetorial editável no motor.',
                p.x+16,p.y+376,'small','warn')
        else
            local fields=VectorFrameUI.fieldsFor(draft)
            for i,key in ipairs(fields) do
                local item=VectorFrameUI.fields[key]
                local r=VectorFrameUI.frameRow(p,i)
                box(r.x,r.y,r.w,r.h,'card')
                fitted(item.label,r.x+8,r.y+16,
                    'small','text',184)
                fitted(tostring(draft[key])..item.unit,
                    r.x+194,r.y+16,'small','muted',100)
                for _,direction in ipairs({-1,1}) do
                    local control=VectorFrameUI.frameStep(p,i,direction)
                    button(direction==1 and '+' or '−',
                        control.x,control.y,control.w,control.h,
                        function()
                            VectorFrameUI.adjust(draft,key,direction)
                        end,false,direction==1 and
                            draft[key]>=item.max or
                            direction==-1 and draft[key]<=item.min)
                end
            end
            if draft.tab=='divide' then
                for i,cut in ipairs({
                    {id='vertical',label='Corte vertical'},
                    {id='horizontal',label='Corte horizontal'}}) do
                    local r=VectorFrameUI.cutRect(p,i)
                    button(cut.label,r.x,r.y,r.w,r.h,function()
                        VectorFrameUI.chooseCut(draft,cut.id)
                    end,draft.cut==cut.id)
                end
            elseif draft.tab=='border' then
                local r=VectorFrameUI.frameRow(p,3)
                button('Cor da borda · pendente',
                    r.x,r.y+4,r.w,37,function()end,false,true)
            end
            local preview=VectorFrameUI.framePreview(p)
            box(preview.x,preview.y,preview.w,preview.h,'card')
            local x=preview.x+math.min(55,draft.horizontal/3+18)
            local y=preview.y+math.min(15,draft.vertical/9+8)
            local pw=preview.w-2*(x-preview.x)
            local ph=preview.h-2*(y-preview.y)
            c('muted')
            love.graphics.setLineWidth(math.min(4,draft.thickness))
            love.graphics.rectangle('line',x,y,pw,ph)
            if draft.tab=='divide' then
                c('accent')
                if draft.cut=='vertical' then
                    love.graphics.line(x+pw/2,y,x+pw/2,y+ph)
                else
                    love.graphics.line(x,y+ph/2,x+pw,y+ph/2)
                end
            end
            local action=VectorFrameUI.frameDisabledAction(p)
            button('Criar / aplicar quadro · pendente',
                action.x,action.y,action.w,action.h,
                function()end,false,true)
        end
        local footer=VectorFrameUI.footer(p)
        fitted('Estado visual apenas · motor Lua pendente.',
            footer.x,footer.y,'small','warn',footer.w)
    elseif kind=='smudge' or kind=='blur' or kind=='special' then
        local draft=assert(A.effectUi,'Rascunho de efeito ausente')
        assert(draft.kind==kind,'Painel de efeito divergente')
        if kind=='smudge' or kind=='blur' then
            text('PARÂMETROS VISUAIS',p.x+16,p.y+61,'small','muted')
            for i,item in ipairs({
                {field='diameter',name='Tamanho',unit=' px'},
                {field='opacity',name='Opacidade',unit='%' }}) do
                local r=EffectUI.paintRow(p,i)
                box(r.x,r.y,r.w,r.h,'card')
                text(item.name,r.x+12,r.y+8,'small','muted')
                fitted(tostring(draft[item.field])..item.unit,
                    r.x+150,r.y+34,'small','text',128)
                for _,dir in ipairs({-1,1}) do
                    local b=EffectUI.paintButton(p,i,dir)
                    button(dir==1 and '+' or '−',
                        b.x,b.y,b.w,b.h,function()
                        EffectUI.adjust(draft,item.field,dir)
                    end)
                end
            end
            local preview=EffectUI.paintPreview(p)
            box(preview.x,preview.y,preview.w,preview.h,'card')
            c('line')
            love.graphics.rectangle('line',preview.x+.5,preview.y+.5,
                preview.w-1,preview.h-1,5,5)
            c('muted')
            love.graphics.circle('line',preview.x+70,
                preview.y+57,math.min(36,8+draft.diameter/12),32)
            love.graphics.setLineWidth(3)
            love.graphics.line(preview.x+156,preview.y+64,
                preview.x+191,preview.y+47,preview.x+221,preview.y+69,
                preview.x+250,preview.y+44)
            fitted('Amostra vetorial; não altera a obra.',
                preview.x+115,preview.y+87,'small','muted',preview.w-125)
        else
            text('TIPOS DE CANETA ESPECIAL',p.x+16,p.y+48,
                'small','muted')
            for i,item in ipairs(EffectUI.specials) do
                local r=EffectUI.specialRect(p,i)
                button('',r.x,r.y,r.w,r.h,function()
                    EffectUI.selectSpecial(draft,item.id)
                    status(item.label..' · algoritmo ainda pendente')
                end,draft.specialId==item.id)
                c(draft.specialId==item.id and 'accent' or 'muted')
                Icons.draw('special',r.x+23,r.y+21,17)
                fitted(item.label,r.x+40,r.y+10,'small','text',r.w-47)
                text('Pendente',r.x+40,r.y+32,'small','warn')
            end
            if draft.specialId=='liquify' then
                text('LIQUIFY · OPÇÕES VISUAIS',p.x+16,
                    p.y+246,'small','muted')
                for i,item in ipairs(EffectUI.liquifyModes) do
                    local r=EffectUI.liquifyModeRect(p,i)
                    button(item.label,r.x,r.y,r.w,r.h,function()
                        EffectUI.selectLiquify(draft,item.id)
                    end,draft.liquifyId==item.id)
                end
                local strength=EffectUI.strengthRow(p)
                box(strength.x,strength.y,strength.w,strength.h,'card')
                fitted('Força: '..draft.strength..'%',
                    strength.x+10,strength.y+11,'small','text',
                    strength.w-108)
                for _,dir in ipairs({-1,1}) do
                    local b=EffectUI.strengthButton(p,dir)
                    button(dir==1 and '+' or '−',
                        b.x,b.y,b.w,b.h,function()
                        EffectUI.adjust(draft,'strength',dir)
                    end)
                end
            else
                local pnd=EffectUI.pendingRect(p)
                box(pnd.x,pnd.y,pnd.w,pnd.h,'card')
                c('muted')
                Icons.draw('special',pnd.x+35,pnd.y+35,25)
                fitted(EffectUI.special(draft.specialId).label,
                    pnd.x+69,pnd.y+25,'body','text',pnd.w-83)
                fitted('Algoritmo de edição ainda indisponível.',
                    pnd.x+14,pnd.y+80,'small','warn',pnd.w-28)
                fitted('Nenhuma operação ocorre no canvas.',
                    pnd.x+14,pnd.y+105,'small','muted',pnd.w-28)
            end
        end
        local footer=EffectUI.footer(p)
        fitted('Motor Lua de efeitos pendente · sem aplicar.',
            footer.x,footer.y,'small','warn',footer.w)
    elseif kind=='wand' or kind=='lasso' then
        local state=assert(A.selectionToolUi,
            'Estado de seleção visual ausente')
        assert(state.kind==kind,'Painel de seleção divergente')
        for i,mode in ipairs(SelectionToolUI.modes) do
            local r=SelectionToolUI.modeRect(p,i)
            button(mode.label,r.x,r.y,r.w,r.h,function()
                SelectionToolUI.selectMode(state,mode.id)
            end,state.mode==mode.id)
        end
        if kind=='wand' then
            text('REFERÊNCIA',p.x+14,p.y+109,'small','muted')
            for i,src in ipairs(SelectionToolUI.sources) do
                local r=SelectionToolUI.sourceRect(p,i)
                button(src.label,r.x,r.y,r.w,r.h,function()
                    SelectionToolUI.selectSource(state,src.id)
                end,state.source==src.id)
            end
            local row=SelectionToolUI.toleranceRow(p)
            box(row.x,row.y,row.w,row.h,'card')
            fitted(('Tolerância RGBA: %d'):format(
                state.tolerance),row.x+10,row.y+9,'small',
                'text',row.w-107)
            for _,delta in ipairs({-1,1}) do
                local r=SelectionToolUI.toleranceButton(p,delta)
                button(delta==1 and '+' or '−',
                    r.x,r.y,r.w,r.h,function()
                        SelectionToolUI.adjustTolerance(state,delta)
                    end,false,delta==1 and state.tolerance>=100
                        or delta==-1 and state.tolerance<=0)
            end
            for i,opt in ipairs(SelectionToolUI.toggles) do
                local r=SelectionToolUI.toggleRect(p,i)
                button(opt.label,r.x,r.y,r.w,r.h,function()
                    SelectionToolUI.toggle(state,opt.id)
                end,state[opt.id])
            end
        else
            local area=SelectionToolUI.lassoIllustration(p)
            box(area.x,area.y,area.w,area.h,'card')
            c('accent')
            love.graphics.setLineWidth(2)
            local cx=area.x+area.w/2
            local cy=area.y+70
            love.graphics.line(cx-56,cy+8,cx-42,cy-22,
                cx-4,cy-35,cx+41,cy-16,cx+53,cy+14,
                cx+12,cy+36,cx-30,cy+29,cx-56,cy+8)
            text('Selecione uma região desenhando um laço',
                area.x+16,area.y+131,'small','text')
            text('Captura de traçado: motor pendente',
                area.x+16,area.y+163,'small','warn')
        end
        for i,label in ipairs({'Inverter · pendente','Limpar máscara'}) do
            local r=SelectionToolUI.actionRect(p,i)
            local enabled=kind=='wand' and i==2 and A.wandSelection~=nil
            button(label,r.x,r.y,r.w,r.h,function()
                if enabled then clearWandSelection() end
            end,false,not enabled)
        end
        local footer=SelectionToolUI.footerRect(p)
        fitted(kind=='wand' and
            'Clique na tela · máscara não limita edição ainda'
            or 'Laço: captura de traçado ainda indisponível.',
            footer.x,footer.y,'small','warn',footer.w)
    elseif kind=='transform' then
        local draft=assert(A.transformUi,'Rascunho Transformar ausente')
        for i,mode in ipairs(TransformUI.modes) do
            local r=TransformUI.modeRect(p,i)
            button(mode.label,r.x,r.y,r.w,r.h,function()
                TransformUI.chooseMode(draft,mode.id)
            end,draft.mode==mode.id)
        end
        if draft.mode=='translate' then
            local toggles={{key='scaling',name='Escala'},
                {key='rotation',name='Rotação'},
                {key='repeatDisplay',name='Repetição'}}
            for i,item in ipairs(toggles) do
                local r=TransformUI.toggleRect(p,i)
                button(item.name,r.x,r.y,r.w,r.h,function()
                    TransformUI.toggle(draft,item.key)
                end,draft[item.key])
            end
            for i,item in ipairs(TransformUI.fields) do
                local r=TransformUI.fieldRow(p,i)
                box(r.x,r.y,r.w,r.h,'card')
                fitted(item.label,r.x+9,r.y+9,'small','text',115)
                fitted(tostring(draft[item.id])..item.unit,
                    r.x+132,r.y+9,'small','muted',156)
                local minus=TransformUI.minusRect(p,i)
                local plus=TransformUI.plusRect(p,i)
                button('−',minus.x,minus.y,minus.w,minus.h,function()
                    TransformUI.adjust(draft,item.id,-1)
                end,false,draft[item.id]<=item.minimum)
                button('+',plus.x,plus.y,plus.w,plus.h,function()
                    TransformUI.adjust(draft,item.id,1)
                end,false,draft[item.id]>=item.maximum)
            end
            for i,target in ipairs({
                {id='layer',name='Camada'},
                {id='canvas',name='Tela inteira'}}) do
                local r=TransformUI.targetRect(p,i)
                button(target.name,r.x,r.y,r.w,r.h,function()
                    TransformUI.chooseTarget(draft,target.id)
                end,draft.target==target.id)
            end
            local frame=TransformUI.frameRect(p)
            button('Moldura visível',frame.x,frame.y,
                frame.w,frame.h,function()
                    TransformUI.toggle(draft,'showFrame')
                end,draft.showFrame)
        else
            local area=TransformUI.pendingArea(p)
            box(area.x,area.y,area.w,area.h,'card')
            c('muted')
            Icons.draw('select',area.x+area.w/2,
                area.y+56,34)
            fitted(draft.mode=='perspective'
                and 'Transformação em perspectiva'
                or 'Transformação por malha',
                area.x+20,area.y+110,'body','text',area.w-40)
            fitted('Controles e algoritmo Lua ainda pendentes.',
                area.x+20,area.y+150,'small','warn',area.w-40)
            fitted('Nenhuma transformação será aplicada.',
                area.x+20,area.y+178,'small','muted',area.w-40)
        end
        local footer=TransformUI.footerRect(p)
        fitted('Prévia de parâmetros · aplicar indisponível',
            footer.x,footer.y,'small','warn',footer.w)
    elseif kind=='text' then
        local draft=assert(A.textUi,'Rascunho de texto ausente')
        for i,tab in ipairs(TextUI.tabs) do
            local r=TextUI.tabRect(p,i)
            button(tab.label,r.x,r.y,r.w,r.h,function()
                draft.focused=false
                love.keyboard.setTextInput(false)
                draft.tab=tab.id
            end,draft.tab==tab.id)
        end
        local x=p.x+20
        local function property(index,label,key,unit)
            local r=TextUI.propertyRow(p,index)
            text(label,r.x,r.y,'small','muted')
            button('−',r.x,r.y+22,40,29,function()
                TextUI.step(draft,key,-1)
            end)
            fitted(tostring(draft[key])..(unit or ''),
                r.x+50,r.y+28,'small','text',r.w-138)
            button('+',r.x+r.w-40,r.y+22,40,29,function()
                TextUI.step(draft,key,1)
            end)
        end
        if draft.tab=='content' then
            text('DIGITE O TEXTO',x,p.y+108,'small','muted')
            local field=TextUI.inputRect(p)
            button('',field.x,field.y,field.w,field.h,function()
                draft.focused=true
                love.keyboard.setTextInput(true)
            end,draft.focused)
            c('text')
            love.graphics.setFont(A.fonts.body)
            love.graphics.setScissor(field.x+9,field.y+8,
                field.w-18,field.h-16)
            love.graphics.printf(draft.value~='' and draft.value
                or 'Clique e digite aqui...',field.x+12,field.y+11,
                field.w-24,'left')
            love.graphics.setScissor()
            text('Texto ainda nao sera colocado na tela.',
                x,p.y+237,'small','warn')
            local alignments={{id='left',label='Esquerda'},
                {id='center',label='Centro'},
                {id='right',label='Direita'}}
            for i,a in ipairs(alignments) do
                local r=TextUI.alignmentRect(p,i)
                button(a.label,r.x,r.y,r.w,r.h,function()
                    draft.alignment=a.id
                    draft.focused=false
                    love.keyboard.setTextInput(false)
                end,draft.alignment==a.id)
            end
            for i,o in ipairs({
                {vertical=false,label='Horizontal'},
                {vertical=true,label='Vertical'}}) do
                local r=TextUI.orientationRect(p,i)
                button(o.label,r.x,r.y,r.w,r.h,function()
                    draft.vertical=o.vertical
                    draft.focused=false
                    love.keyboard.setTextInput(false)
                end,draft.vertical==o.vertical)
            end
        elseif draft.tab=='size' then
            text('FONTE',x,p.y+103,'small','muted')
            button('Fontes: pendente',x,p.y+134,p.w-40,40,
                function()end,false,true)
            text('TAMANHO (RASCUNHO)',x,p.y+193,'small','muted')
            property(3,'Tamanho visual','size',' px')
        elseif draft.tab=='style' then
            text('ESTILO DO TEXTO',x,p.y+103,'small','muted')
            button('Cor do texto: pendente',x,p.y+133,p.w-40,39,
                function()end,false,true)
            button('Cor do contorno: pendente',x,p.y+193,p.w-40,39,
                function()end,false,true)
            property(3,'Espessura do contorno','stroke',' px')
        elseif draft.tab=='background' then
            property(1,'Opacidade do fundo','bgOpacity','%')
            property(2,'Margem horizontal','marginX',' px')
            property(3,'Margem vertical','marginY',' px')
            text('Cor de fundo: seletor pendente.',
                x,p.y+348,'small','warn')
        elseif draft.tab=='spacing' then
            property(1,'Espaco entre caracteres','letterSpacing',' px')
            property(2,'Espaco entre linhas','lineSpacing',' px')
            text('Ajustes apenas de rascunho.',
                x,p.y+290,'small','muted')
        end
        fitted('Motor de texto pendente: nao aplica ao desenho.',
            x,p.y+p.h-29,'small','warn',p.w-40)
    elseif kind=='filters' then
        local current=A.filterCategory or 'adjust'
        local page=A.filterPage or 1
        local totalPages=FilterUI.pageCount(current)
        for i,category in ipairs(FilterUI.categories) do
            local r=FilterUI.categoryRect(p,i)
            button(category.label,r.x,r.y,r.w,r.h,function()
                A.filterCategory=category.id
                A.filterPage=1
                A.filterPendingId=nil
            end,current==category.id)
        end
        for i,item in ipairs(FilterUI.pageItems(current,page)) do
            local r=FilterUI.filterRow(p,i)
            button('',r.x,r.y,r.w,r.h,function()
                -- Seleção é visual: nenhuma API de raster é acionada.
                A.filterPendingId=item.id
                status(item.label..' · motor Lua pendente')
            end,A.filterPendingId==item.id)
            box(r.x+6,r.y+6,41,37,'panel')
            c('muted')
            Icons.draw('filter',r.x+26,r.y+24,18)
            fitted(item.label,r.x+54,r.y+7,'small','text',r.w-64)
            text('Pendente',r.x+54,r.y+29,'small','warn')
        end
        button('‹',p.x+151,p.y+346,35,29,function()
            A.filterPage=page-1
            A.filterPendingId=nil
        end,false,page==1)
        fitted(('Página %d / %d'):format(page,totalPages),
            p.x+194,p.y+353,'small','text',133)
        button('›',p.x+p.w-47,p.y+346,35,29,function()
            A.filterPage=page+1
            A.filterPendingId=nil
        end,false,page==totalPages)
        fitted('Prévia e aplicação: motor Lua pendente.',
            p.x+151,p.y+p.h-29,'small','muted',p.w-163)
    elseif kind=='view' then
        local x,y=p.x+16,p.y+53
        text('TELA',x,y,'small','muted')
        button('Ajustar ao espaço',x,y+30,p.w-32,36,fit)
        button('−',x,y+83,44,34,
            function()zoomCanvas(1/1.25)end)
        text(('Zoom: %.0f%%'):format(A.zoom*100),
            x+54,y+91,'small','text')
        button('+',x+p.w-76,y+83,44,34,
            function()zoomCanvas(1.25)end)
        text('ROTAÇÃO',x,y+137,'small','muted')
        iconButton('rotate-left',x,y+162,54,34,
            function()rotateCanvas(-math.pi/12)end)
        button('0°',x+65,y+162,p.w-162,34,resetCanvasRotation)
        iconButton('rotate-right',x+p.w-86,y+162,54,34,
            function()rotateCanvas(math.pi/12)end)
        button(A.previewEnabled and 'Prévia: ligada'
            or 'Prévia: desligada',x,y+213,p.w-32,34,function()
                A.previewEnabled=not A.previewEnabled
            end,A.previewEnabled)
    elseif kind=='stabilizer' then
        -- ibisPaint 14.1: Real Time Constant/Fast Strokes e Fade.
        -- So a regulagem Legado Lua 0..5 e conectada ao raster.
        local draft=A.stabilizerVisual or IbisPanels.stabilizer.new()
        A.stabilizerVisual=draft
        for i,tab in ipairs(IbisPanels.stabilizer.tabs) do
            local r=IbisPanels.stabilizer.tabRect(p,i)
            button(tab.label,r.x,r.y,r.w,r.h,function()
                IbisPanels.stabilizer.tab(draft,tab.id)
            end,draft.tab==tab.id)
        end
        local scope=IbisPanels.stabilizer.scopeRect(p)
        local scopeKey=draft.tab=='fade' and 'fadeScope' or 'scope'
        button('Apenas para este pincel · prévia',
            scope.x,scope.y,scope.w,scope.h,function()
                IbisPanels.stabilizer.toggle(draft,scopeKey)
                status('Escopo por pincel: apenas estado visual')
            end,draft[scopeKey])
        if draft.tab=='stabilization' then
            for i,method in ipairs({
                {label='Tempo real',id='realtime'},
                {label='Após · pendente',id='after'}}) do
                local r=IbisPanels.stabilizer.methodRect(p,i)
                button(method.label,r.x,r.y,r.w,r.h,
                    function()end,i==1,i==2)
            end
            local legacy=IbisPanels.stabilizer.legacyRow(p)
            text('MOTOR LUA · ESTABILIZAÇÃO LEGADA',
                legacy.x,legacy.y,'small','muted')
            button('−',legacy.x,legacy.y+17,36,27,function()
                finishStroke()
                A.stabilization=math.max(0,A.stabilization-1)
            end,false,A.stabilization==0)
            fitted(('Nível %d / 5 · aplicado'):format(A.stabilization),
                legacy.x+47,legacy.y+23,'small','text',178)
            button('+',legacy.x+legacy.w-36,legacy.y+17,
                36,27,function()
                finishStroke()
                A.stabilization=math.min(5,A.stabilization+1)
            end,false,A.stabilization==5)
            for i,field in ipairs({
                {id='constant',label='Constante'},
                {id='fast',label='Traços rápidos'}}) do
                local r=IbisPanels.stabilizer.draftRow(p,i)
                fitted(field.label..' · prévia',
                    r.x,r.y,'small','text',r.w-90)
                fitted(draft[field.id]==0 and 'OFF'
                    or tostring(draft[field.id]),
                    r.x+175,r.y+6,'small','muted',55)
                for _,delta in ipairs({-1,1}) do
                    local b=IbisPanels.stabilizer.draftButton(p,i,delta)
                    button(delta==-1 and '−' or '+',
                        b.x,b.y,b.w,b.h,function()
                        IbisPanels.stabilizer.step(draft,field.id,delta)
                    end,false,delta==-1 and draft[field.id]==0
                        or delta==1 and draft[field.id]==100)
                end
            end
            local note=IbisPanels.stabilizer.footerRect(p)
            fitted('Modos 14.1: sem efeito no motor atual',
                note.x,note.y,'small','warn',note.w)
        else
            local toggle=IbisPanels.stabilizer.fadeToggleRect(p)
            button('Forçar Fade · prévia',
                toggle.x,toggle.y,toggle.w,toggle.h,
                function()IbisPanels.stabilizer.toggle(draft,'fadeEnabled')end,
                draft.fadeEnabled)
            for i,field in ipairs({
                {id='start',label='Comprimento inicial'},
                {id='end',label='Comprimento final'}}) do
                local r=IbisPanels.stabilizer.fadeRow(p,i)
                fitted(field.label,r.x,r.y,
                    'small','text',r.w-90)
                fitted(tostring(draft[field.id]),
                    r.x+175,r.y+5,'small','muted',55)
                for _,delta in ipairs({-1,1}) do
                    local b=IbisPanels.stabilizer.fadeButton(p,i,delta)
                    button(delta==-1 and '−' or '+',
                        b.x,b.y,b.w,b.h,function()
                        IbisPanels.stabilizer.step(draft,field.id,delta)
                    end,false,delta==-1 and draft[field.id]==0
                        or delta==1 and draft[field.id]==100)
                end
            end
            for i,item in ipairs({
                {id='smooth',label='Suave'},
                {id='linear',label='Linear'}}) do
                local r=IbisPanels.stabilizer.shapeRect(p,i)
                button(item.label,r.x,r.y,r.w,r.h,function()
                    IbisPanels.stabilizer.shape(draft,item.id)
                end,draft.shape==item.id)
            end
            local note=IbisPanels.stabilizer.footerRect(p)
            fitted('Fade: somente controles visuais',
                note.x,note.y,'small','warn',note.w)
        end
    elseif kind=='ruler' then
        -- Icones simbolicos, todos locais ao painel, sem guias no canvas.
        local draft=A.rulerUi or RulerUI.new()
        A.rulerUi=draft
        for i,item in ipairs(RulerUI.types) do
            local r=RulerUI.cell(p,i)
            local active=draft.previewId==item.id
            button('',r.x,r.y,r.w,r.h,function()
                RulerUI.select(draft,item.id)
                status(item.name..' · régua não aplicada, motor pendente')
            end,active)
            local sx,sy=r.x+26,r.y+23
            box(r.x+5,r.y+7,41,40,'panel')
            c(active and 'accent' or 'muted')
            love.graphics.push()
            love.graphics.translate(sx,sy)
            love.graphics.scale(1.65,1.65)
            love.graphics.setLineWidth(1.1)
            for _,cmd in ipairs(RulerUI.symbol(item.id)) do
                if cmd.op=='line' then
                    love.graphics.line(unpack(cmd.a))
                elseif cmd.op=='circle' then
                    love.graphics.circle('line',unpack(cmd.a))
                elseif cmd.op=='ellipse' then
                    love.graphics.ellipse('line',unpack(cmd.a))
                elseif cmd.op=='rectangle' then
                    love.graphics.rectangle('line',unpack(cmd.a))
                end
            end
            love.graphics.pop()
            fitted(item.name,r.x+53,r.y+8,'small','text',r.w-61)
            text('Pendente',r.x+53,r.y+33,'small','warn')
        end
        local clear=RulerUI.clear(p)
        button('Limpar',clear.x,clear.y,clear.w,clear.h,function()
            RulerUI.select(draft,nil)
        end,false,draft.previewId==nil)
        local caption=RulerUI.caption(p)
        local current=RulerUI.get(draft.previewId)
        fitted(current and ('Opção: '..current.name) or 'Nenhuma régua',
            caption.x,caption.y,'small','text',caption.w)
        fitted('Guias não implementadas · apenas aparência.',
            p.x+14,p.y+p.h-28,'small','warn',p.w-28)
    elseif kind=='materials' then
        local state=A.materialUi or MaterialUI.new()
        A.materialUi=state
        local search=MaterialUI.searchRect(p)
        button('',search.x,search.y,search.w,search.h,function()
            state.focused=true
            love.keyboard.setTextInput(true)
        end,state.focused)
        fitted(state.query~='' and state.query or 'Pesquisar materiais...',
            search.x+11,search.y+11,'small',
            state.query~='' and 'text' or 'muted',search.w-22)
        local searchButton=MaterialUI.searchButton(p)
        button('Buscar',searchButton.x,searchButton.y,
            searchButton.w,searchButton.h,function()
            MaterialUI.submit(state)
            love.keyboard.setTextInput(false)
            status('Busca local: catálogo de materiais ainda indisponível')
        end,false,state.query=='')
        for i,category in ipairs(MaterialUI.categories) do
            local cell=MaterialUI.categoryRect(p,i)
            button(category.label,cell.x,cell.y,cell.w,cell.h,function()
                MaterialUI.setCategory(state,category.id)
                state.focused=false
                love.keyboard.setTextInput(false)
                status(category.label..' · sem arquivos locais')
            end,state.category==category.id)
        end
        local area=MaterialUI.emptyRect(p)
        box(area.x,area.y,area.w,area.h,'card')
        c('line')
        love.graphics.rectangle('line',area.x+.5,area.y+.5,
            area.w-1,area.h-1,4,4)
        c('muted')
        Icons.draw('top-material',area.x+area.w/2,
            area.y+28,28)
        local active=MaterialUI.category(state.category)
        fitted(active.label..' · nenhuma miniatura carregada',
            area.x+14,area.y+52,'small','text',area.w-28)
        fitted(state.submittedQuery~='' and
            ('Busca "'..state.submittedQuery..'": 0 resultados locais')
            or 'Catálogo original ainda não importado.',
            area.x+14,area.y+80,'small','muted',area.w-28)
        fitted('Seleção e aplicação de material: pendentes.',
            area.x+14,area.y+103,'small','warn',area.w-28)
        local footer=MaterialUI.footerRect(p)
        fitted('Nenhuma camada será alterada ao navegar.',
            footer.x,footer.y,'small','muted',footer.w)
    elseif kind=='properties' then
        local x,y=p.x+17,p.y+54
        if A.tool=='shape' then
            text('TIPO DE FORMA',x,y,'small','muted')
            button('Retângulo',x,y+28,125,34,
                function()A.shapeKind=0 end,A.shapeKind==0)
            button('Elipse',x+139,y+28,125,34,
                function()A.shapeKind=1 end,A.shapeKind==1)
            button('Linha',x,y+74,125,34,
                function()A.shapeKind=2 end,A.shapeKind==2)
            button('Contorno',x,y+130,125,34,
                function()A.shapeFilled=false end,not A.shapeFilled)
            button('Preencher',x+139,y+130,125,34,
                function()A.shapeFilled=true end,A.shapeFilled)
            text(('Espessura: %d px'):format(A.shapeWidth),
                x,y+189,'small','muted')
            button('−',x,y+213,62,31,function()
                A.shapeWidth=math.max(1,A.shapeWidth-1)
            end,false,A.shapeWidth==1)
            button('+',x+79,y+213,62,31,function()
                A.shapeWidth=math.min(128,A.shapeWidth+1)
            end,false,A.shapeWidth==128)
        elseif A.tool=='select' then
            local rect=A.selection
            text('SELEÇÃO RETANGULAR',x,y,'small','muted')
            text(rect and ('Área: '..rect.w..' × '..rect.h..' px')
                or 'Arraste na tela para selecionar.',
                x,y+31,'small','muted')
            button('Girar -90°',x,y+73,125,34,
                function()applySelectionTransform(3,1)end,
                false,not rect or rect.h>A.doc.width or
                    rect.w>A.doc.height)
            button('Girar +90°',x+139,y+73,125,34,
                function()applySelectionTransform(1,1)end,
                false,not rect or rect.h>A.doc.width or
                    rect.w>A.doc.height)
            button('Diminuir 50%',x,y+125,125,34,
                function()applySelectionTransform(0,.5)end,false,not rect)
            button('Ampliar 200%',x+139,y+125,125,34,
                function()applySelectionTransform(0,2)end,
                false,not rect or rect.w*2>A.doc.width
                    or rect.h*2>A.doc.height)
            text('Ctrl+D remove a seleção.',x,y+193,'small','muted')
        elseif A.tool=='fill' then
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
        if A.tool=='brush' or A.tool=='erase' then
            button('Biblioteca de pincéis',x,p.y+p.h-54,p.w-34,34,
                openBrushLibrary)
        end
    elseif kind=='color' then
        drawColorPopup(p)
    elseif kind=='blends' then
        text('MODO DA CAMADA ATIVA',p.x+15,p.y+48,'small','muted')
        for i,mode in ipairs(LayerUI.modes) do
            local r=LayerUI.blendRow(p,i)
            button(mode.label,r.x,r.y,r.w,r.h,function()
                if mode.available then A.compactPanel='layers' end
            end,mode.id=='normal',not mode.available)
            if not mode.available then
                text('Pendente',r.x+r.w-89,r.y+10,'small','warn')
            end
        end
        fitted('Demais modos: motor Lua pendente.',
            p.x+14,p.y+p.h-27,'small','muted',p.w-28)
    elseif kind=='layers' then
        local ls=A.layerSession
        local count=#A.doc.layers
        local active=A.doc.active_layer
        for _,item in ipairs(LayerChrome.toolbar(p,'top')) do
            local disabled=(item.id=='delete' and count<=1)
                or (item.id~='delete' and count>=Store.MAX_LAYERS)
            LayerChrome.paintAction(item,disabled,A.fonts.small)
            if not disabled then
                A.buttons[#A.buttons+1]={x=item.x,y=item.y,
                    w=item.w,h=item.h,fn=guard(function()
                    if item.id=='add' then
                        finishStroke();ls:add();A.compactLayerStart=nil
                        A.dirty=true;rebuildImage()
                    elseif item.id=='duplicate' then
                        duplicateActiveLayer()
                    elseif item.id=='delete' then
                        finishStroke();ls:remove(A.doc.active_layer)
                        clearLayerThumbs();A.compactLayerStart=nil
                        A.dirty=true;rebuildImage()
                    end
                end)}
            end
        end
        -- Linha distinta para seleção: existe na janela original,
        -- mas não fingimos que o raster atual tem uma camada especial.
        local selection=LayerUI.selectionRow(p)
        local area=A.selection
        local selectionInfo=area and
            ('Seleção: '..area.w..' × '..area.h..' px')
            or 'Nenhuma área selecionada'
        LayerChrome.selection(selection,selectionInfo,A.fonts.small)
                local start,stop,maxStart=Thumbnails.window(count,active,
            Compact.layerRows(p),A.compactLayerStart)
        local row=0
        for index=stop,start,-1 do
            row=row+1
            local i=index
            local layer=A.doc.layers[i]
            local visual=LayerRowVisual.presentation(layer.visible,
                active==i,layer.opacity)
            local r=IbisPanels.layerRow(p,row)
            A.buttons[#A.buttons+1]={x=r.x,y=r.y,w=r.w-35,h=r.h,
                fn=guard(function()
                    if i~=A.doc.active_layer then
                        finishStroke();ls:select(i);A.dirty=true
                    end
                    A.compactLayerStart=start
                end)}
            LayerChrome.row(r,active==i)
            for ty=0,3 do for tx=0,3 do
                local bright=(tx+ty)%2==0
                love.graphics.setColor(bright and .8 or .59,
                    bright and .81 or .61,bright and .82 or .63,1)
                love.graphics.rectangle('fill',r.x+6+tx*10,
                    r.y+5+ty*10,10,10)
            end end
            local thumb=layerThumb(i)
            local tw,th=thumb:getDimensions()
            love.graphics.setColor(1,1,1,visual.thumbnailAlpha)
            love.graphics.draw(thumb,r.x+6,r.y+5,0,40/tw,40/th)
            love.graphics.setColor(1,1,1,1)
            LayerChrome.label(r,i,layer.name,layer.opacity,
                A.fonts.body,A.fonts.small)
            local eye=LayerChrome.eye(r,layer.visible,Icons.draw)
            A.buttons[#A.buttons+1]={x=eye.x,y=eye.y,w=eye.w,
                h=eye.h,fn=guard(function()
                    finishStroke();ls:setVisible(i,not layer.visible)
                    A.dirty=true;rebuildImage()
                end)}
            if i==active then
                A.buttons[#A.buttons+1]={x=r.x+54,y=r.y+26,w=90,h=21,
                    fn=guard(function()A.compactPanel='blends'end)}
                love.graphics.setColor(.19,.43,.71,1)
                love.graphics.rectangle('fill',
                    r.x+54,r.y+26,90,20,3,3)
                love.graphics.setColor(1,1,1,1)
                love.graphics.setFont(A.fonts.small)
                love.graphics.print('Normal',r.x+60,r.y+28)
            else
                love.graphics.setColor(LayerChrome.colors.muted)
                love.graphics.setFont(A.fonts.small)
                love.graphics.print('Normal',r.x+57,r.y+29)
            end
        end
        local bg=LayerChrome.backgroundRow(p,stop-start+1)
        if bg then LayerChrome.background(bg,A.fonts.small) end
        -- O grupo de acoes fica junto aos botoes superiores.
        -- O rodape segue a hierarquia oficial: clipping/bloqueio,
        -- modo de mistura e barra de opacidade.
        for _,item in ipairs(LayerChrome.toolbar(p,'footer')) do
            local disabled=(item.id=='previous' and start>=maxStart)
                or (item.id=='next' and start<=1)
                or (item.id=='merge' and active<=1)
            LayerChrome.paintAction(item,disabled,A.fonts.small)
            if not disabled then
                A.buttons[#A.buttons+1]={x=item.x,y=item.y,
                    w=item.w,h=item.h,fn=guard(function()
                    if item.id=='previous' then
                        A.compactLayerStart=Thumbnails.scroll(
                            start,maxStart,1)
                    elseif item.id=='next' then
                        A.compactLayerStart=Thumbnails.scroll(
                            start,maxStart,-1)
                    elseif item.id=='rename' then
                        openLayerRename()
                    elseif item.id=='merge' then
                        mergeActiveLayerDown()
                    end
                end)}
            end
        end
        for _,slot in ipairs(LayerChrome.footerControls(p)) do
            slot.selected=slot.id=='alpha' and
                A.doc.layers[A.doc.active_layer].alpha_lock==true
            LayerChrome.paintFooterControl(slot,A.fonts.small)
            if slot.available and slot.id=='alpha' then
                A.buttons[#A.buttons+1]={x=slot.x,y=slot.y,
                    w=slot.w,h=slot.h,fn=guard(function()
                    finishStroke()
                    local index=A.doc.active_layer
                    local enabled=A.doc.layers[index].alpha_lock~=true
                    if ls:setAlphaLock(index,enabled) then
                        A.dirty=true
                        status(enabled and 'Alpha Lock ativado'
                            or 'Alpha Lock desativado')
                    end
                end)}
            elseif slot.available and slot.id=='blend' then
                A.buttons[#A.buttons+1]={x=slot.x,y=slot.y,
                    w=slot.w,h=slot.h,
                    fn=guard(function()A.compactPanel='blends'end)}
            end
        end
        local mx,my=love.mouse.getPosition()
        local hint=LayerChrome.actionHint(p,mx,my)
        if hint then
            fitted(hint,p.x+94,p.y+15,'small','muted',145)
        end
        local layer=A.doc.layers[A.doc.active_layer]
        local drag=A.compactLayerOpacityDrag
        local shown=drag and drag.index==A.doc.active_layer and
            drag.value or layer.opacity
        love.graphics.setColor(1,1,1,1)
        love.graphics.setFont(A.fonts.small)
        love.graphics.print(('%.0f%%'):format(shown*100),
            p.x+7,p.y+p.h-29)
        local track=LayerOpacity.rect(p)
        love.graphics.setColor(.54,.56,.58,1)
        love.graphics.rectangle('fill',track.x,track.y+4,
            track.w,5,2,2)
        love.graphics.setColor(.93,.94,.96,1)
        love.graphics.rectangle('fill',track.x,track.y+4,
            math.max(1,track.w*LayerOpacity.fraction(shown)),5,2,2)
        love.graphics.setColor(1,1,1,1)
        love.graphics.circle('fill',
            track.x+track.w*LayerOpacity.fraction(shown),
            track.y+6.5,7,20)
        for _,direction in ipairs({-1,1}) do
            local item=LayerChrome.step(p,direction)
            local disabled=not LayerOpacitySteps.canChange(
                layer.opacity,direction)
            LayerChrome.paintAction(item,disabled,A.fonts.small)
            if not disabled then
                A.buttons[#A.buttons+1]={x=item.x,y=item.y,
                    w=item.w,h=item.h,fn=guard(function()
                    finishStroke()
                    ls:setOpacity(A.doc.active_layer,
                        LayerOpacitySteps.change(
                            A.doc.layers[A.doc.active_layer].opacity,
                            direction))
                    A.dirty=true;rebuildImage()
                end)}
            end
        end
    end
end
-- Painel de navegacao do botao Voltar e Definicoes.
-- Controle de selecao configuravel sem manipular canvas ou historico.
local function drawNavigationChoice(label,r,callback,active,disabled)
    local lg=love.graphics
    if disabled then lg.setColor(.80,.82,.84,1)
    elseif active then lg.setColor(.64,.78,.95,1)
    else lg.setColor(.96,.97,.98,1) end
    lg.rectangle('fill',r.x,r.y,r.w,r.h,5,5)
    lg.setColor(.62,.66,.70,1)
    lg.rectangle('line',r.x+.5,r.y+.5,r.w-1,r.h-1,5,5)
    lg.setColor(disabled and .54 or .13,
        disabled and .55 or .17,disabled and .56 or .22,1)
    lg.setFont(A.fonts.body)
    lg.printf(label,r.x+4,r.y+(r.h-A.fonts.body:getHeight())/2,
        r.w-8,'center')
    if not disabled then
        A.buttons[#A.buttons+1]={x=r.x,y=r.y,w=r.w,h=r.h,
            fn=guard(callback)}
    end
end
local function drawBackMenu(w,h)
    local lg=love.graphics
    lg.setColor(0,0,0,.68)
    lg.rectangle('fill',0,0,w,h)
    local p=SettingsUI.menu(w,h)
    lg.setColor(.91,.92,.94,1)
    lg.rectangle('fill',p.x,p.y,p.w,p.h,7,7)
    lg.setColor(.19,.21,.24,1)
    lg.rectangle('fill',p.x,p.y,p.w,50,7,7)
    lg.setColor(1,1,1,1)
    lg.setFont(A.fonts.title)
    lg.print('Voltar',p.x+22,p.y+11)
    drawNavigationChoice('Voltar para A Minha Galeria',
        SettingsUI.menuItem(p,1),toGallery)
    drawNavigationChoice('Configurações',
        SettingsUI.menuItem(p,2),function()
            A.backMenu=false;A.settingsOpen=true
        end)
    drawNavigationChoice('Cancelar',
        SettingsUI.menuItem(p,3),function()
            A.backMenu=false
        end)
end
local function drawIbisSettings(w,h)
    local lg=love.graphics
    lg.setColor(0,0,0,.75)
    lg.rectangle('fill',0,0,w,h)
    local p=SettingsUI.panel(w,h)
    lg.setColor(.92,.93,.95,1)
    lg.rectangle('fill',p.x,p.y,p.w,p.h,7,7)
    lg.setColor(.19,.21,.24,1)
    lg.rectangle('fill',p.x,p.y,p.w,55,7,7)
    lg.setColor(1,1,1,1)
    lg.setFont(A.fonts.title)
    lg.print('Configurações',p.x+24,p.y+11)
    lg.setFont(A.fonts.small)
    lg.setColor(.29,.33,.37,1)
    lg.print('INTERFACE DO USUÁRIO',p.x+29,p.y+69)
    lg.print('Posição da seleção de ferramentas',
        p.x+29,p.y+96)
    for i,item in ipairs({
        {id='left',label='Esquerda'},
        {id='right',label='Direita'},
        {id='popup',label='Popup'}}) do
        local choice=item
        drawNavigationChoice(item.label,SettingsUI.positionRect(p,i),
            function()
                saveToolPreference('toolRailPosition',choice.id)
            end,A.toolRailPosition==choice.id,
            not SettingsUI.positionAvailable(choice.id))
    end
    lg.setColor(.29,.33,.37,1)
    lg.print('Número de colunas no seletor popup',
        p.x+29,p.y+192)
    for i=1,3 do
        local count=i
        drawNavigationChoice(tostring(count),
            SettingsUI.columnRect(p,i),function()
                saveToolPreference('toolPopupColumns',count)
            end,A.toolPopupColumns==count)
    end
    lg.setColor(.29,.33,.37,1)
    lg.print('Mostrar nomes das ferramentas',
        p.x+29,p.y+285)
    for i=1,2 do
        local show=(i==1)
        drawNavigationChoice(show and 'Ativado' or 'Desativado',
            SettingsUI.labelRect(p,i),function()
                saveToolPreference('toolPopupLabels',show)
            end,A.toolPopupLabels==show)
    end
    lg.setColor(.45,.48,.52,1)
    lg.setFont(A.fonts.small)
    lg.print('Esquerda/Direita: faixa; Popup: barra inferior.',
        p.x+29,p.y+370)
    drawNavigationChoice('Concluir',SettingsUI.closeRect(p),
        function()A.settingsOpen=false end,true)
end
function love.draw()
    A.buttons={};A.galleryPreviewBudget=A.screen=='gallery' and 5 or 1
    local w,h=love.graphics.getDimensions()
    local theme=A.screen=='gallery' and galleryPalette
        or (A.compactUi and compactPalette or palette)
    love.graphics.clear(theme.bg)
    if A.screen=='editor' and not A.compactUi then
        box(0,0,w,64,'panel')
        c('accent');love.graphics.rectangle('fill',0,62,w,2)
        text('Ibis Rebuild',24,15,'title')
    end
    if A.screen=='editor' and not A.compactUi and A.doc and w>=1120 then
        fitted(A.doc.name,232,24,'body','muted',
            Visual.headerNameWidth(w))
    end
    if A.screen=='gallery' then drawGallery(w,h)else drawEditor(w,h)end
    -- Faixa lateral e overlay visual sobre o canvas, fora da funcao
    -- monolitica drawEditor (limite LuaJIT de 60 upvalues).
    if A.screen=='editor' and A.compactUi and not A.focusMode
        and (A.toolRailPosition or 'left')~='popup' then
        drawEditorToolRail(w,h)
    end
    -- O rodape legado cobre os icones inferiores do editor compacto.
    -- Seu fundo ja e desenhado por drawEditor: nao sobrepor controles.
    if A.screen=='editor' and not A.compactUi then
        box(0,h-48,w,48,'panel')
        fitted(A.message or '',20,h-33,'small','muted',w-260)
    end
    if A.testReport and (A.screen~='editor' or not A.compactUi) then
        text(A.testReport.ok and 'TESTES LUA OK' or 'FALHA NOS TESTES',
            w-220,h-32,'small',A.testReport.ok and 'accent' or 'warn')
    end
    if (A.galleryCreateMenu or A.galleryMoveMenu
        or A.galleryDeleteMenu or A.galleryRestoreMenu
        or A.galleryMoreMenu)
        and A.screen=='gallery' then
        A.buttons={}
        drawGalleryCreateMenu(w,h)
    elseif A.settingsOpen then
        A.buttons={}
        drawIbisSettings(w,h)
    elseif A.backMenu then
        A.buttons={}
        drawBackMenu(w,h)
    elseif A.modal then A.buttons={};drawModal(w,h)
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
    if (A.galleryCreateMenu or A.galleryMoveMenu
        or A.galleryDeleteMenu or A.galleryRestoreMenu
        or A.galleryMoreMenu)
        and A.screen=='gallery' then
        if buttonNumber==1 then
            for i=#A.buttons,1,-1 do
                local b=A.buttons[i]
                if x>=b.x and x<b.x+b.w and
                    y>=b.y and y<b.y+b.h then b.fn();return end
            end
            A.galleryCreateMenu=false
            A.galleryMoreMenu=false
            A.galleryDeleteMenu=nil;A.galleryRestoreMenu=nil
            if A.galleryMoveMenu then
                if A.galleryMoveMenu.creating then
                    GalleryShell.cancelNewFolder(A.galleryMoveMenu)
                else A.galleryMoveMenu=nil end
                love.keyboard.setTextInput(false)
            end
        end
        return -- Fechar nao dispara clique na obra sob o popup.
    end
    if A.backMenu or A.settingsOpen then
        if buttonNumber==1 then
            for i=#A.buttons,1,-1 do
                local b=A.buttons[i]
                if x>=b.x and x<b.x+b.w
                    and y>=b.y and y<b.y+b.h then
                    b.fn();return
                end
            end
        end
        return -- Navegacao nunca transmite cliques para a tela.
    end
    if A.screen=='gallery' and A.galleryDetailId then
        if buttonNumber==1 then
            for i=#A.buttons,1,-1 do
                local b=A.buttons[i]
                if x>=b.x and x<b.x+b.w and
                    y>=b.y and y<b.y+b.h then b.fn();return end
            end
            A.galleryDetailSwipe={x=x,y=y}
        end
        return -- Nenhum clique ampliado alcança canvas ou arrasto.
    end
    if buttonNumber==1 and A.modal and A.modal.kind=='new' then
        local w,h=love.graphics.getDimensions()
        local rect=GalleryUI.dialog(w,h)
        for _,axis in ipairs({2,3}) do
            local track=IbisPanels.canvasReference.slider(
                IbisPanels.canvasReference.layout(w,h),axis)
            if GalleryUI.sliderHit(track,x,y) then
                A.canvasDimensionDrag=axis
                A.modal.values[axis]=GalleryUI.sliderValue(track,x)
                A.modal.focus=axis
                return -- O slider jamais alcanca canvas nem galeria.
            end
        end
    end
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
                local alpha=ColorPanel.hsbAlphaRect(p)
                if ColorPanel.svHit(p,x,y) then
                    kind='sv'
                elseif IbisPanels.wheelHit(p,x,y) then
                    kind='wheel'
                else
                    local mini=ColorPanel.hsbMiniHit(p,x,y)
                    if mini then kind='mini-'..mini
                    elseif x>=alpha.x-3 and x<=alpha.x+alpha.w+3 and
                        y>=alpha.y-5 and y<=alpha.y+alpha.h+5 then
                        kind='alpha'
                    end
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
        -- Presses em áreas internas desabilitadas (ex.: modos de
        -- mistura sem motor) não devem fechar o popup nem pintar.
        local ww,hh=love.graphics.getDimensions()
        if Compact.contains(Compact.popup(ww,hh,A.compactPanel),x,y) then
            return
        end
        navigateCompactPanel(nil);A.colorDrag=nil
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
        for i=#A.buttons,1,-1 do
            local b=A.buttons[i]
            if x>=b.x and x<=b.x+b.w and
                y>=b.y and y<=b.y+b.h then
                A.shapePreview=nil
                if A.screen=='gallery' and not A.gallerySelecting
                    and not A.galleryTrash and b.galleryKey
                    and (not A.showcase or A.showcase.stage>100) then
                    A.galleryGesture=GalleryShell.dragBegin(
                        b.galleryKey,x,y,love.timer.getTime(),b.fn)
                else b.fn() end
                return
            end
        end
        -- An unimplemented visual tool must NEVER fall through to the
        -- previously active brush. Magic Wand is the first pixel-mask
        -- engine here; other pending modes consume the click safely.
        if A.screen=='editor' and A.compactUi and
            A.visualPendingTool and not A.modal then
            if Workspace.contains(love.graphics.getWidth(),
                love.graphics.getHeight(),paneHidden(),x,y,
                not A.focusMode) then
                if A.visualPendingTool=='wand' then
                    guard(function()
                        local vx,vy=canvasPoint(x,y)
                        if vx>=0 and vy>=0 and vx<A.doc.width
                            and vy<A.doc.height then
                            local state=assert(A.selectionToolUi)
                            local source=state.source=='current'
                                and A.layerSession:activeBuffer()
                                or A.layerSession.composite
                            local mask=A.wandEngine.select(
                                source,math.floor(vx),math.floor(vy),
                                state.tolerance,state.mode,
                                state.continuous,A.wandSelection)
                            local preview=A.wandEngine.preview(mask)
                            clearWandSelection()
                            A.wandSelection=mask
                            A.wandOverlay=preview
                            status(('Varinha: %d pixels na máscara · edição mascarada pendente'):format(mask.count))
                        end
                    end)()
                else
                    status('Ferramenta visual pendente · nenhum pixel modificado')
                end
            end
            return
        end
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
                        status(('Balde Lua · %d pixels preenchidos · Ctrl+Z desfaz'):format(changed))
                    else
                        status('Balde: nenhum pixel alterado')
                    end
                elseif A.tool=='pixel' and px>=0 and py>=0 and px<A.doc.width and py<A.doc.height then
                    A.layerSession:beginEdit()
                    A.layerSession:pixel(math.floor(px),math.floor(py),A.color)
                    A.layerSession:finishEdit()
                    A.dirty=true;rebuildImage()
                    status('Pixel gravado pelo Lua · Ctrl+Z para desfazer')
                elseif A.tool=='brush' or A.tool=='erase' then
                    A.layerSession:beginEdit()
                    A.layerSession:beginStrokeAccum()
                    local diameter,opacity=PressureInfluence.resolve(
                        A.brushDiameter,A.brushOpacity,pressure,A.pressureCurve,
                        A.pressureSize,A.pressureOpacity)
                    local isTilt=A.tool=='brush' and A.inkPenId~=nil and
                        A.penTiltEnabled and (A.inkTiltX~=0 or A.inkTiltY~=0)
                    local style=A.tool=='erase' and 2 or
                        isTilt and 3 or A.brushStyle=='soft' and 1 or 0
                    A.layerSession:pressureStroke(px,py,px,py,
                        diameter,diameter,A.color,opacity,opacity,
                        A.brushStyle=='soft' and 0.25 or 1,
                        isTilt and A.inkTiltX or 0,
                        isTilt and A.inkTiltY or 0,style,true)
                    updateImageRegion(DirtyRegion.segment(
                        A.doc.width,A.doc.height,px,py,px,py,
                        diameter,diameter))
                    A.lastPressure=pressure
                    A.drawing=true;A.lastStrokeX=px;A.lastStrokeY=py
                    A.stabilizer=Stabilizer.new(A.stabilization,px,py)
                    A.strokePath=StrokePath.new(px,py,pressure)
                    A.pendingBrushRect=nil
                    status(A.tool=='erase' and 'Borracha Lua · apaga a camada ativa'
                        or 'Pincel Lua · histórico por pincelada · Ctrl+Z')
                end
            end)()
        end
    end
end
local function pointerReleased(x,y,b,pressure)
    if b==1 and A.canvasDimensionDrag then
        local axis=A.canvasDimensionDrag
        A.canvasDimensionDrag=nil
        if A.modal and A.modal.kind=='new' then
            local w,h=love.graphics.getDimensions()
            local track=IbisPanels.canvasReference.slider(IbisPanels.canvasReference.layout(w,h),axis)
            A.modal.values[axis]=GalleryUI.sliderValue(track,x)
        end
        return
    end
    if A.screen=='gallery' and b==1 and A.galleryDetailSwipe then
        local swipe=A.galleryDetailSwipe
        A.galleryDetailSwipe=nil
        if A.galleryDetailId then
            local direction=IbisPanels.galleryDetail.swipe(swipe.x,swipe.y,x,y)
            if direction==0 then A.galleryDetailId=nil
            elseif direction then
                A.galleryDetailId=IbisPanels.galleryDetail.step(
                    A.galleryItems,A.galleryDetailId,
                    A.galleryFilter,direction)
            end
        end
        return
    end
    if A.screen=='gallery' and b==1 and A.galleryGesture then
        local gesture=A.galleryGesture
        A.galleryGesture=nil
        GalleryShell.dragAdvance(gesture,x,y,love.timer.getTime())
        if gesture.active then
            local w,h=love.graphics.getDimensions()
            local target=GalleryShell.dragTarget(w,h,A.galleryScroll,
                A.galleryItems or {},x,y)
            local parent
            if A.folder~='' then
                for _,folder in ipairs(A.store.catalog.folders) do
                    if folder.id==A.folder then
                        parent=folder.parent;break
                    end
                end
            end
            local targetRect
            if target then
                for i,item in ipairs(A.galleryItems or {}) do
                    if item.key==target then
                        targetRect=GalleryShell.card(
                            w,h,i,A.galleryScroll)
                        break
                    end
                end
            end
            local action=GalleryShell.dropAction(
                A.folder,parent,gesture.key,target,w,h,x,y,targetRect)
            if action then
                guard(function()
                    if action.kind=='group' then
                        local report=A.store:groupArtworks(
                            gesture.key:sub(3),action.target:sub(3),
                            A.folder)
                        refreshGallery()
                        if report.moved==2 and not report.error then
                            status(('Pasta %s criada com duas obras')
                                :format(report.name))
                        else
                            status(('Agrupamento incompleto (%d/2): %s')
                                :format(report.moved,
                                    tostring(report.error)))
                        end
                    elseif action.kind=='move' then
                        local report=A.store:moveProjects(
                            {gesture.key:sub(3)},action.folder,A.folder)
                        assert(report.moved==1 and not report.error,
                            report.error or 'Falha ao mover obra')
                        refreshGallery()
                        status('Obra movida para a pasta de destino')
                    elseif A.store:reorderGallery(
                        A.folder,gesture.key,action.target) then
                        refreshGallery()
                        status('Ordem das obras salva na galeria')
                    end
                end)()
            else
                status('Arrasto cancelado; ordem preservada')
            end
        elseif not gesture.moved and gesture.callback then
            gesture.callback()
        end
        return
    end
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
    if A.canvasDimensionDrag then
        if A.modal and A.modal.kind=='new' then
            local w,h=love.graphics.getDimensions()
            local axis=A.canvasDimensionDrag
            local track=IbisPanels.canvasReference.slider(
                IbisPanels.canvasReference.layout(w,h),axis)
            A.modal.values[axis]=GalleryUI.sliderValue(track,x)
        else
            A.canvasDimensionDrag=nil
        end
        return
    end
    if A.screen=='gallery' and A.galleryGesture then
        GalleryShell.dragAdvance(A.galleryGesture,x,y,
            love.timer.getTime())
        return
    end
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
            paintBrushPath(sx,sy,pressure)
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
        A.galleryGesture=nil;A.galleryDetailSwipe=nil
        A.panning=false;A.panButton=nil;A.spaceHeld=false
        A.toolHelp=false;A.contextMenu=nil;A.brushLibrary=false;A.brushLabDrag=nil;A.sliderDrag=nil
        navigateCompactPanel(nil)
        if A.inkPreviousTool then A.tool=A.inkPreviousTool;A.inkPreviousTool=nil end
        guard(finishSelection)()
        guard(finishStroke)()
    end
end
function love.wheelmoved(x,y)
    if A.modal and A.modal.kind=='new' then
        local w,h=love.graphics.getDimensions()
        local rect=IbisPanels.canvasReference.layout(w,h)
        A.modal.canvasListScroll=IbisPanels.canvasReference.scroll(
            rect,A.modal.canvasListScroll or 0,y)
        return -- Nao rolar galeria nem zoom por baixo da janela.
    end
    if A.screen=='gallery' then
        if A.galleryDetailId then return end
        A.galleryGesture=nil
        if A.modal or A.galleryCreateMenu or A.galleryMoveMenu
            or A.galleryMoreMenu or A.galleryDeleteMenu
            or A.galleryRestoreMenu then return end
        local total=A.galleryTrash and #(A.trashProjects or {})
            or ((GalleryUI.filter(A.galleryFilter,'folder')
                and #A.folders or 0)+
                (GalleryUI.filter(A.galleryFilter,'work')
                and #A.projects or 0))
        local w,h=love.graphics.getDimensions()
        A.galleryScroll=GalleryShell.scroll(w,h,total,
            A.galleryScroll or 0,y)
        return
    end
    if A.backMenu or A.settingsOpen then return end
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
    if A.screen=='gallery' and A.galleryMoveMenu and
        A.galleryMoveMenu.creating then
        GalleryShell.appendFolderName(A.galleryMoveMenu,t)
        A.galleryMoveMenu.createError=nil
        return
    end
    if A.modal then
        local i=A.modal.focus
        A.modal.values[i]=A.modal.values[i]..t
    elseif A.screen=='editor' and A.compactPanel=='text'
        and A.textUi and A.textUi.focused then
        A.textUi.value=TextUI.append(A.textUi.value,t)
    elseif A.screen=='editor' and A.compactPanel=='materials'
        and A.materialUi and A.materialUi.focused then
        MaterialUI.appendQuery(A.materialUi,t)
    end
end
function love.keypressed(key)
    if A.screen=='gallery' and A.galleryDetailId then
        if key=='escape' or key=='backspace' then
            A.galleryDetailId=nil;A.galleryDetailSwipe=nil
        elseif key=='left' or key=='right' then
            A.galleryDetailId=IbisPanels.galleryDetail.step(
                A.galleryItems,A.galleryDetailId,A.galleryFilter,
                key=='left' and -1 or 1)
        elseif key=='return' or key=='kpenter' then
            local target=A.galleryDetailId
            A.galleryDetailId=nil;A.galleryDetailSwipe=nil
            guard(function()
                openDoc(A.store:openProject(target))
            end)()
        end
        return
    end
    if A.screen=='gallery' and A.galleryMoveMenu and
        A.galleryMoveMenu.creating then
        local state=A.galleryMoveMenu
        if key=='escape' then
            GalleryShell.cancelNewFolder(state)
            love.keyboard.setTextInput(false)
        elseif key=='backspace' then
            GalleryShell.backspaceFolderName(state)
            state.createError=nil
        elseif key=='return' or key=='kpenter' then
            if state.createName~='' then
                local ok,id=GalleryShell.createDestination(
                    A.store,state,A.folder)
                if ok then
                    love.keyboard.setTextInput(false)
                    refreshGallery()
                    status('Pasta criada e selecionada para mover')
                else status('Não foi possível criar a pasta: '..
                    tostring(id)) end
            end
        end
        return -- Nenhum atalho do editor durante edicao de nome.
    end
    if A.screen=='gallery' and A.gallerySelecting and
        not A.modal and not A.galleryCreateMenu
        and not A.galleryMoveMenu and not A.galleryMoreMenu
        and not A.galleryDeleteMenu and not A.galleryRestoreMenu and
        love.keyboard.isDown('lctrl','rctrl') then
        if key=='a' then
            A.gallerySelected=GalleryShell.selectAll(
                GalleryShell.selectionKeys(
                    A.folders,A.projects,A.galleryFilter))
            return
        elseif key=='d' then
            A.gallerySelected={}
            return
        end
    end
    if A.screen=='gallery' and key=='escape' then
        if A.galleryGesture then
            A.galleryGesture=nil
            status('Reorganização cancelada')
        elseif A.modal then
            A.modal=nil;love.keyboard.setTextInput(false)
        elseif A.galleryCreateMenu then A.galleryCreateMenu=false
        elseif A.galleryMoreMenu then A.galleryMoreMenu=false
        elseif A.galleryDeleteMenu then A.galleryDeleteMenu=nil
        elseif A.galleryRestoreMenu then A.galleryRestoreMenu=nil
        elseif A.galleryMoveMenu then
            A.galleryMoveMenu=nil
            love.keyboard.setTextInput(false)
        elseif A.gallerySelecting then
            A.gallerySelecting=false;A.gallerySelected={}
        elseif A.galleryTrash then
            A.galleryDetailId=nil
            A.galleryTrash=false
            A.galleryFilter=A.galleryBeforeTrash or 'all'
            A.galleryBeforeTrash=nil;A.galleryScroll=0
            refreshGallery()
        elseif A.folder~='' then
            local parent=''
            for _,f in ipairs(A.store.catalog.folders) do
                if f.id==A.folder then parent=f.parent;break end
            end
            setFolder(parent)
        end
        return
    end
    if A.backMenu or A.settingsOpen then
        if key=='escape' then
            if A.settingsOpen then A.settingsOpen=false
            else A.backMenu=false end
        end
        return -- Nenhum atalho pode editar pixels sob Configuracoes.
    end
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
        if A.compactPanel=='vector' or A.compactPanel=='frame' then
            if key=='escape' then navigateCompactPanel('tools') end
            return
        end
        if A.compactPanel=='smudge' or A.compactPanel=='blur'
            or A.compactPanel=='special' then
            if key=='escape' then navigateCompactPanel('tools') end
            return
        end
        if A.compactPanel=='wand' or A.compactPanel=='lasso' then
            if key=='escape' then navigateCompactPanel('tools') end
            return
        end
        if A.compactPanel=='transform' then
            if key=='escape' then
                navigateCompactPanel('tools')
            end
            return
        end
        if A.compactPanel=='materials' then
            if key=='escape' then
                navigateCompactPanel(nil)
            elseif A.materialUi and A.materialUi.focused then
                if key=='backspace' then
                    MaterialUI.backspace(A.materialUi)
                elseif key=='return' or key=='kpenter' then
                    MaterialUI.submit(A.materialUi)
                    love.keyboard.setTextInput(false)
                end
            end
            return
        end
        if A.compactPanel=='text' then
            if key=='escape' then
                navigateCompactPanel('tools')
            elseif A.textUi and A.textUi.focused then
                if key=='backspace' then
                    A.textUi.value=TextUI.backspace(A.textUi.value)
                elseif key=='return' or key=='kpenter' then
                    A.textUi.value=TextUI.newline(A.textUi.value)
                end
            end
            return
        end
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
            if A.compactPanel=='filters' then
                navigateCompactPanel('tools')
            else
                navigateCompactPanel(nil)
            end
            A.colorDrag=nil
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
        guard(finishSelection)();A.selection=nil;clearWandSelection()
        status('Seleção desmarcada')
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
    gpuUpload:clear()
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
