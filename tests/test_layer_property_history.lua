-- Chronological property/raster/structural history on the actual C++ RGBA8.
local Native=require('native')
local Layers=require('layers')
local Store=require('store')
local T={}
function T.run(root)
    assert(Native.available,'Real C++ renderer required')
    local count=0
    local function check(v,msg)count=count+1;assert(v,msg)end
    local store=Store.open(root)
    local project=store:createProject('Histórico de propriedades',5,5,'',
        string.rep('\0',5*5*4))
    local scene=Layers.open(store,store:openProject(project.id))
    scene:beginEdit()
    scene:pixel(2,2,0x223344ff)
    check(scene:finishEdit(),'Base raster edit failed')
    local base=Native.bytes(scene.buffers[1])
    local top=scene:add('Tinta')
    local topId=scene.doc.layers[top].id
    scene:beginEdit()
    scene:pixel(2,2,0xff0000ff)
    check(scene:finishEdit(),'Upper raster edit failed')
    local upper=Native.bytes(scene.buffers[2])
    check(scene:rename(2,'Azul – noite'),'Rename failed')
    check(scene:setOpacity(2,.4),'Opacity change failed')
    check(scene:setVisible(2,false),'Visibility change failed')
    check(scene:move(2,1),'Reorder failed')
    check(scene:historyStats().undo==7 and scene:historyStats().redo==0,
        'All seven mixed edits should be tracked')
    check(scene.doc.layers[1].id==topId and
        scene.doc.layers[1].name=='Azul – noite' and
        scene.doc.layers[1].opacity==.4 and
        not scene.doc.layers[1].visible,
        'Initial transformed metadata not present')
    local order={'move','visible','opacity','name','raster','insert','raster'}
    for i,expected in ipairs(order) do
        local ok,structural,metadata=scene:undo()
        check(ok and structural==(expected=='move' or expected=='insert') and
            metadata==(expected=='visible' or expected=='opacity' or
                expected=='name'),
            'Wrong undo kind at step '..i..' '..expected)
        if i==1 then
            check(scene.doc.layers[2].id==topId,
                'Undo move did not restore original order')
        elseif i==2 then
            check(scene.doc.layers[2].visible and
                scene.doc.layers[2].opacity==.4,
                'Undo visibility did not restore composite metadata')
        elseif i==3 then
            check(scene.doc.layers[2].opacity==1,
                'Undo opacity did not restore 100%')
        elseif i==4 then
            check(scene.doc.layers[2].name=='Tinta',
                'Undo rename did not restore UTF-8 layer name')
        elseif i==5 then
            check(Native.readPixel(scene.buffers[2],2,2)==0,
                'Undo upper paint failed')
        elseif i==6 then
            check(#scene.doc.layers==1,
                'Undo add failed after metadata edits')
        elseif i==7 then
            check(Native.readPixel(scene.buffers[1],2,2)==0,
                'Undo base paint failed')
        end
    end
    check(scene:historyStats().redo==7 and not scene:canUndo(),
        'Mixed property redo stack was lost')
    for i=1,7 do
        local ok=scene:redo()
        check(ok,'Redo mixed edit failed at '..i)
    end
    check(#scene.doc.layers==2 and
        scene.doc.layers[1].id==topId and
        scene.doc.layers[1].name=='Azul – noite' and
        scene.doc.layers[1].opacity==.4 and
        not scene.doc.layers[1].visible and
        Native.bytes(scene.buffers[1])==upper and
        Native.bytes(scene.buffers[2])==base,
        'Redo mixed metadata/raster/structure lost content')
    check(Native.readPixel(scene.composite,2,2)==0x223344ff,
        'Hidden upper layer must not alter output')
    scene:save()
    local reopened=Store.open(root):openProject(project.id)
    check(reopened.format==2 and reopened.layers[1].id==topId and
        reopened.layers[1].name=='Azul – noite' and
        reopened.layers[1].opacity==.4 and
        not reopened.layers[1].visible,
        'RBD2 metadata failed to roundtrip')
    check(not Layers.open(Store.open(root),reopened):canUndo(),
        'History should remain session-only')
    -- Non-active layer metadata must preserve selection and source pixels.
    scene:select(2)
    local active=scene.doc.active_layer
    local pixels=Native.bytes(scene.buffers[1])
    local before=scene:historyStats()
    check(scene:rename(1,'Outra visão'),'Non-active rename failed')
    check(scene.doc.active_layer==active and
        Native.bytes(scene.buffers[1])==pixels and
        scene:historyStats().undo==before.undo+1,
        'Rename changed active selection or raster')
    local ok,structural,metadata=scene:undo()
    check(ok and not structural and metadata and
        scene.doc.layers[1].name=='Azul – noite' and
        scene.doc.active_layer==active,
        'Undo non-active rename changed selected layer')
    check(scene:canRedo(),'Property redo missing')
    check(scene:setVisible(1,true),
        'A new property edit must invalidate redo branch')
    check(not scene:canRedo(),'Divergent metadata change retained redo')
    local stats=scene:historyStats()
    check(not scene:setVisible(1,true) and
        not scene:setOpacity(1,.4) and
        not scene:rename(1,'Azul – noite') and
        scene:historyStats().undo==stats.undo,
        'No-op properties generated undo steps')
    local sameRaster=Native.bytes(scene.buffers[1])
    for _,attempt in ipairs({
        function()scene:rename(1,'')end,
        function()scene:setOpacity(1,1.5)end,
        function()scene:setVisible(1,'yes')end,
        function()scene:setOpacity(99,.5)end
    }) do
        check(not pcall(attempt),'Invalid property was accepted')
    end
    check(scene:historyStats().undo==stats.undo and
        Native.bytes(scene.buffers[1])==sameRaster,
        'Invalid property altered history or native raster')
    for i=1,40 do scene:setVisible(1,i%2==0) end
    local limited=scene:historyStats()
    check(limited.undo==Layers.MAX_HISTORY_ENTRIES and
        limited.bytes<=Layers.MAX_HISTORY_BYTES,
        'Lightweight property entries bypassed bounded history')
    return {suite='mixed-layer-property-history',passed=true,
        assertions=count,rename_reversible=true,visibility_reversible=true,
        opacity_reversible=true,mixed_chronology=true,
        nonactive_identity=true,branching=true,memory_bounded=true,
        native_pixels_preserved=true,rbd2_roundtrip=true}
end
return T
