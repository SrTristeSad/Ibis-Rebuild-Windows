-- Native-backed layer duplication and RBD2 regression tests.
local Native=require('native')
local Store=require('store')
local Layers=require('layers')
local T={}
function T.run(root)
    assert(Native.available,'Compiled C++ raster required')
    local count=0
    local function check(ok,msg)count=count+1;assert(ok,msg)end
    local store=Store.open(root)
    local base=string.rep('\0',6*6*4)
    local doc=store:createProject('Duplicação independente',6,6,'',base)
    local scene=Layers.open(store,store:openProject(doc.id))
    local source=scene:add('Tintas de fundo')
    check(source==2,'Source creation failed')
    scene:pixel(2,2,0x4477aacc)
    scene:pixel(4,3,0xe53b4499)
    local srcBytes=Native.bytes(scene.buffers[source])
    scene:setOpacity(source,0.37)
    scene:setVisible(source,false)
    local beforeComposite=Native.bytes(scene.composite)
    local oldId=scene.doc.layers[source].id
    scene:beginEdit()
    scene:pixel(5,5,0xff8800ff)
    check(scene:finishEdit(),'Prior edit must be tracked')
    check(scene:historyStats().undo==4,
        'Add, opacity, visibility and raster painting must share one history')
    local beforeHistory=scene:historyStats().undo
    local newIndex=scene:duplicate(source)
    check(newIndex==3 and scene.doc.active_layer==3 and #scene.doc.layers==3,
        'Duplicate not inserted directly above source and activated')
    check(scene.doc.layer_count==3,'Document layer_count was not updated')
    check(not scene.doc.layers[newIndex].visible and
        scene.doc.layers[newIndex].opacity==0.37,
        'Duplicate did not copy opacity/visibility')
    check(scene.doc.layers[newIndex].name=='Cópia de Tintas de fundo',
        'Duplicate name unexpected')
    check(scene.doc.layers[newIndex].id~=oldId,
        'Duplicate reused persistent layer ID')
    check(scene.doc.layers[source].id==oldId,
        'Duplicate changed source persistent layer ID')
    local editedSource=Native.bytes(scene.buffers[source])
    check(Native.bytes(scene.buffers[newIndex])==editedSource,
        'Duplicate RGBA differs from current unsaved native source buffer')
    check(Native.bytes(scene.composite)==beforeComposite,
        'Duplicating a hidden source changed visible composite')
    check(scene:historyStats().undo==beforeHistory+1 and
        scene:historyStats().redo==0,
        'Duplicating should append one reversible structural step')
    scene:pixel(2,2,0x00ff00ff)
    check(Native.readPixel(scene.buffers[source],2,2)==0x4477aacc,
        'Editing copied pixels changed source: backing buffers aliased')
    scene:beginEdit()
    scene:pixel(1,4,0xffffff80)
    check(scene:finishEdit(),'New layer history did not record painting')
    check(scene:undo(),'Could not undo paint on the duplicated layer')
    check(Native.readPixel(scene.buffers[newIndex],1,4)==0,
        'Undo did not restore copied layer pixels')
    check(scene:redo(),'Could not redo paint on duplicated layer')
    check(Native.readPixel(scene.buffers[newIndex],1,4)==0xffffff80,
        'Redo did not restore duplicated layer pixels')
    check(Native.readPixel(scene.buffers[source],1,4)==0,
        'Redo of copied layer modified original')
    scene:save()
    local saved=Store.open(root):openProject(doc.id)
    check(saved.format==2 and saved.layer_count==3 and
        saved.active_layer==3,'RBD2 duplicate metadata wrong')
    check(saved.layers[2].id==oldId and saved.layers[3].id~=oldId,
        'RBD2 reused source identity')
    check(saved.layers[3].name=='Cópia de Tintas de fundo' and
        saved.layers[3].opacity==0.37 and not saved.layers[3].visible,
        'RBD2 duplicate properties did not persist')
    check(saved.layers[2].pixels==editedSource,
        'Source pixels changed on disk after duplication')
    check(saved.layers[3].pixels==Native.bytes(scene.buffers[3]),
        'Duplicated raster did not persist independently')
    local reopened=Layers.open(Store.open(root),saved)
    check(Native.readPixel(reopened.buffers[3],1,4)==0xffffff80 and
        Native.readPixel(reopened.buffers[2],1,4)==0,
        'Reopened duplicated raster not independent')
    -- Full-capacity failure is strictly atomic and cannot delete undo items.
    for i=4,Store.MAX_LAYERS do reopened:add('Extra '..i) end
    check(#reopened.doc.layers==Store.MAX_LAYERS,
        'Could not fill layer capacity')
    reopened:beginEdit()
    reopened:pixel(0,0,0x0011eeff)
    check(reopened:finishEdit(),'Last-layer history missing')
    local snapshot=Native.bytes(reopened:activeBuffer())
    local history=reopened:historyStats().undo
    local countBefore=#reopened.doc.layers
    local lastId=reopened.doc.layers[reopened.doc.active_layer].id
    check(not pcall(function()reopened:duplicate(2)end),
        'Duplicating past eight layers unexpectedly succeeded')
    check(#reopened.doc.layers==countBefore and
        reopened.doc.layers[reopened.doc.active_layer].id==lastId and
        Native.bytes(reopened:activeBuffer())==snapshot and
        reopened:historyStats().undo==history,
        'Rejected duplicate mutated raster/metadata/history')
    check(not pcall(function()reopened:duplicate(0)end),
        'Invalid duplicate source index accepted')
    -- UTF-8 truncation must never cut a code point, even at the 240-byte cap.
    local fresh=store:createProject('Long name check',2,2,'',
        string.rep('\0',16))
    local unicode=Layers.open(store,store:openProject(fresh.id))
    local veryLong=string.rep('é',120)
    check(#veryLong==240,'Unicode fixture is not 240 bytes')
    check(unicode:rename(1,veryLong),'Could not name source UTF-8')
    local duplicated=unicode:duplicate(1)
    local newName=unicode.doc.layers[duplicated].name
    check(#newName<=240 and Store.validateName(newName)==newName,
        'UTF-8 copy name is truncated incorrectly')
    check(newName:sub(1,#'Cópia de ')=='Cópia de ',
        'Long copy name lacks recognizable prefix')
    unicode:save()
    check(Store.open(root):openProject(fresh.id).layers[2].name==newName,
        'Long UTF-8 duplicate name did not survive RBD2')
    return {suite='layer-duplicate-independent-rbd2',passed=true,
        assertions=count,deep_rgba_copy=true,properties_copied=true,
        independent_history=true,structural_undo=true,limit_atomic=true,utf8_truncation=true,
        rbd2_roundtrip=true}
end
return T
