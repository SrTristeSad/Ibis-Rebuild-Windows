local Native=require('native')
local Store=require('store')
local Layers=require('layers')
local FS=require('fs')
local JSON=require('json')
local Colors=require('colors')
local A={screen='gallery',folder='',dirty=false,buttons={},zoom=1,rotation=0,panX=0,panY=0,tool='inspect',color=0x192d40ff,view='grid',brushDiameter=12,fillTolerance=0,shapeKind=0,pickerSource='composite',shapeFilled=false,shapeWidth=2,shapePreview=nil,drawing=false,sideTab='layers'}
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
    A.selection=nil;A.selectAction=nil;A.movePreview=nil;A.shapePreview=nil
    rebuildImage();fit()
    status('Projeto raster aberto · camadas próprias RBD2 disponíveis')
end
local function finishStroke()
    if A.layerSession and A.layerSession.pending then A.layerSession:finishEdit() end
    A.drawing=false;A.lastStrokeX=nil;A.lastStrokeY=nil
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
    A.shapePreview=nil
    finishStroke()
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
    elseif m.kind=='color' then
        local value,err=Colors.parseHex(m.values[1])
        assert(value,err)
        A.color=value;A.modal=nil
        status('Cor personalizada aplicada: '..Colors.format(value))
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
                local lx0,ly0=point(1,7)
                local lx1,ly1=point(5,7)
                local oldLine=Native.readPixel(A.layerSession:activeBuffer(),1,7)
                love.draw();love.mousepressed(lx0,ly0,1)
                love.mousemoved(lx1,ly1,lx1-lx0,ly1-ly0)
                assert(A.shapePreview and A.shapePreview.x1==5 and
                    A.shapePreview.y1==7,'Prévia de linha não seguiu o arraste')
                assert(Native.readPixel(A.layerSession:activeBuffer(),1,7)==oldLine,
                    'Prévia da linha alterou o raster antes de soltar')
                love.mousereleased(lx1,ly1,1)
                assert(Native.readPixel(A.layerSession:activeBuffer(),1,7)==0xe14922ff
                    and Native.readPixel(A.layerSession:activeBuffer(),5,7)==0xe14922ff,
                    'Linha C++ não desenhou ambas as extremidades')
                undoDoc()
                assert(Native.readPixel(A.layerSession:activeBuffer(),1,7)==oldLine,
                    'Undo da linha falhou')
                redoDoc()
                assert(Native.readPixel(A.layerSession:activeBuffer(),5,7)==0xe14922ff,
                    'Redo da linha falhou')
                saveDoc()
                local lineSaved=A.store:openProject(A.doc.id)
                local lineOffset=(7*A.doc.width+5)*4+1
                assert(lineSaved.layers[2].pixels:sub(lineOffset,lineOffset+3)==
                    string.char(225,73,34,255),'Linha não persistiu no RBD2')
                -- Explicit two-layer sample fixture: sampling must not draw.
                Native.pixel(A.layerSession.buffers[1],1,8,0x246a90cc)
                Native.pixel(A.layerSession:activeBuffer(),1,8,0)
                A.layerSession:recompose();rebuildImage()
                A.dirty=true;saveDoc()
                love.draw();love.mousepressed(571,90,1)
                assert(A.tool=='picker','Conta-gotas não ativado')
                local pickX,pickY=point(1,8)
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
                assert(Native.readPixel(A.layerSession.buffers[1],1,8)==0x246a90cc
                    and Native.readPixel(A.layerSession:activeBuffer(),1,8)==0,
                    'Capturar cor modificou uma camada')
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
    button('Ver',116,78,53,34,function()finishStroke();A.tool='inspect'end,A.tool=='inspect')
    button('Pixel',173,78,45,34,function()finishStroke();A.tool='pixel'end,A.tool=='pixel')
    button('Pincel',222,78,57,34,function()finishStroke();A.tool='brush';A.sideTab='brush'end,A.tool=='brush')
    button('Apagar',283,78,61,34,function()finishStroke();A.tool='erase';A.sideTab='brush'end,A.tool=='erase')
    button('Balde',348,78,53,34,function()finishStroke();A.tool='fill';A.sideTab='brush'end,A.tool=='fill')
    button('Seleção',405,78,61,34,function()finishStroke();A.tool='select'end,A.tool=='select')
    button('Formas',470,78,62,34,function()finishStroke();A.tool='shape'end,A.tool=='shape')
    button('Gotas',536,78,79,34,function()finishStroke();A.tool='picker'end,A.tool=='picker')
    button('Ajustar',619,78,67,34,fit)
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
    box(panel,64,268,h-112,'panel')
    text('PROJETO',panel+20,88,'small','muted');text(A.doc.name:sub(1,28),panel+20,115,'title')
    text(dw..' × '..dh..' · RGBA8',panel+20,150,'body','muted')
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
                panel+20,y,228,27,function()if A.doc.active_layer~=i then finishStroke();ls:select(i);A.dirty=true end end,A.doc.active_layer==i)
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
            text('PINCEL PRÓPRIO · NÃO EQUIVALENTE',panel+20,429,'small','muted')
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
        text('ENTRADA',panel+20,589,'small','muted')
        text('Mouse · pressão 1 · ângulos 0',panel+20,616,'small','muted')
        if A.lastPacket then
            local f=A.lastPacket.floats
            text(('x %.1f  y %.1f · p %.3f'):format(f[1],f[2],f[5]),
                panel+20,646,'small','muted')
        end
        editShapeColorButton(panel,669)
        text(A.tool=='fill' and 'Tolerância por canal RGBA · camada ativa'
            or 'Rasterização Android desconhecida',panel+20,705,'small','muted')
    end
    end
    text(('Zoom %.0f%% · rotação %.0f°'):format(A.zoom*100,math.deg(A.rotation)),22,h-72,'small','muted')
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
        m.kind=='color' and 'Editar cor RGBA' or 'Renomear projeto'
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
    end
    button('Cancelar',x+24,y+357,150,38,function()A.modal=nil;love.keyboard.setTextInput(false)end)
    button('Criar / confirmar',x+190,y+357,226,38,submitModal,true)
end
function love.draw()
    A.buttons={};local w,h=love.graphics.getDimensions();c('bg');love.graphics.clear(palette.bg)
    box(0,0,w,64,'panel');text('DESKTOP REBUILD',24,17,'title')
    text('ibisPaint Android 14.1.2 · reconstrução progressiva',285,24,'body','muted')
    text(Native.available and 'Lua ↔ C++ · offline' or 'Lua · C++ indisponível',w-222,24,'small',Native.available and 'accent' or 'warn')
    if A.screen=='gallery' then drawGallery(w,h)else drawEditor(w,h)end
    box(0,h-48,w,48,'panel');text(A.message or '',20,h-33,'small','muted')
    if A.testReport then text(A.testReport.ok and 'TESTES LUA OK' or 'FALHA NOS TESTES',w-220,h-32,'small',A.testReport.ok and 'accent' or 'warn')end
    if A.modal then A.buttons={};drawModal(w,h)end
end
function love.mousepressed(x,y,buttonNumber)
    if buttonNumber==1 then
        for i=#A.buttons,1,-1 do local b=A.buttons[i];if x>=b.x and x<=b.x+b.w and y>=b.y and y<=b.y+b.h then A.shapePreview=nil;b.fn();return end end
        if A.screen=='editor' and not A.modal and x<love.graphics.getWidth()-280 and y>125 and y<love.graphics.getHeight()-78 then
            guard(function()
                local px,py=canvasPoint(x,y)
                A.lastPacket=Native.pack({{id=1,info=0,x=px,y=py,pressure=Native.pressure(1,false,0,1),time=math.floor(love.timer.getTime()*1000)}})
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
                    if A.tool=='erase' then
                        A.layerSession:erase(px,py,px,py,A.brushDiameter,1)
                    else
                        A.layerSession:stroke(px,py,px,py,A.brushDiameter,A.color,1)
                    end
                    A.drawing=true;A.lastStrokeX=px;A.lastStrokeY=py
                    A.dirty=true;rebuildImage()
                    status(A.tool=='erase' and 'Borracha C++ · apaga a camada ativa'
                        or 'Pincel C++ · histórico por pincelada · Ctrl+Z')
                end
            end)()
        end
    elseif buttonNumber==3 and A.screen=='editor' then A.panning=true end
end
function love.mousereleased(x,y,b)
    if b==3 then A.panning=false end
    if b==1 then
        guard(finishShape)()
        guard(finishSelection)()
        guard(finishStroke)()
    end
end
function love.mousemoved(x,y,dx,dy)
    if A.panning then A.panX=A.panX+dx;A.panY=A.panY+dy end
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
            if A.tool=='erase' then
                A.layerSession:erase(A.lastStrokeX,A.lastStrokeY,px,py,A.brushDiameter,1)
            else
                A.layerSession:stroke(A.lastStrokeX,A.lastStrokeY,px,py,A.brushDiameter,A.color,1)
            end
            A.lastStrokeX=px;A.lastStrokeY=py
            A.dirty=true;rebuildImage()
        end)()
    end
end
function love.focus(focused)
    if not focused then
        A.shapePreview=nil
        guard(finishSelection)()
        guard(finishStroke)()
    end
end
function love.wheelmoved(x,y)
    if A.screen=='editor' and not A.modal then
        local mx=love.mouse.getPosition()
        if mx>=love.graphics.getWidth()-268 and A.sideTab=='layers' then
            local count=#A.doc.layers
            local index=math.max(1,math.min(count,A.doc.active_layer+(y>0 and 1 or -1)))
            if y~=0 and index~=A.doc.active_layer then
                finishStroke();A.layerSession:select(index);A.dirty=true
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
