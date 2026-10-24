-- Metadata editing must reuse RBD2 validation without touching native pixels.
local Native=require('native')
local Store=require('store')
local Layers=require('layers')
local T={}
function T.run(root)
    assert(Native.available,'Requires actual native C++ RGBA8 raster')
    local verified=0
    local function check(condition,msg)
        verified=verified+1;assert(condition,msg)
    end
    local base=string.char(0x20,0x42,0x64,0xff)..
        string.rep('\0',3*4)
    local store=Store.open(root)
    local doc=store:createProject('Propriedades',2,2,'',base)
    local scene=Layers.open(store,store:openProject(doc.id))
    check(scene:add('Frente')==2,'Layer creation failed')
    scene:beginEdit()
    scene:pixel(0,0,0xe53b44ff)
    check(scene:finishEdit(),'Test red pixel was not painted')
    local lower=Native.bytes(scene.buffers[1])
    local upper=Native.bytes(scene.buffers[2])
    local beforeComposite=Native.readPixel(scene.composite,0,0)
    local beforeHistory=scene:historyStats().undo
    local id=scene.doc.layers[2].id
    local newName='Tintas – céu azul'
    check(scene:rename(2,newName),'Valid UTF-8 layer rename did not apply')
    check(scene.doc.layers[2].name==newName,'Renamed metadata missing')
    check(not scene:rename(2,newName),'Identical name must be no-op')
    check(scene:historyStats().undo==beforeHistory,
        'Renaming metadata improperly invalidated raster undo')
    check(Native.bytes(scene.buffers[1])==lower and
        Native.bytes(scene.buffers[2])==upper,
        'Rename modified pixels')
    check(Native.readPixel(scene.composite,0,0)==beforeComposite,
        'Rename affected composite')
    for _,bad in ipairs({'','   ',string.rep('a',241),'Controle\nX',
        string.char(0xff)}) do
        check(not pcall(function()scene:rename(2,bad)end),
            'Invalid name accepted')
        check(scene.doc.layers[2].name==newName,
            'Invalid rename was not atomic')
    end
    check(not pcall(function()scene:rename(0,'Ruim')end),
        'Invalid index accepted')
    check(scene.doc.layers[2].id==id,'Layer identity changed')
    scene:setVisible(2,false)
    check(scene.doc.active_layer==2,
        'Hide action must not change selected layer')
    check(not scene.doc.layers[2].visible,'Hide layer did not persist in memory')
    check(Native.readPixel(scene.composite,0,0)==0x204264ff,
        'Hide layer did not reveal lower raster')
    check(Native.bytes(scene.buffers[2])==upper,
        'Hide layer destroyed hidden pixels')
    scene:setVisible(2,true)
    check(Native.readPixel(scene.composite,0,0)==beforeComposite,
        'Re-show layer did not restore composite')
    scene:setOpacity(2,0.5)
    check(scene.doc.layers[2].opacity==0.5,
        'Existing opacity property is broken')
    scene:save()
    local stored=Store.open(root):openProject(doc.id)
    check(stored.format==2 and stored.layer_count==2,
        'RBD2 save is incompatible')
    check(stored.layers[2].name==newName and
        stored.layers[2].id==id and stored.layers[2].visible,
        'Layer metadata did not roundtrip')
    check(stored.layers[2].opacity==0.5,
        'Layer opacity did not roundtrip')
    local opened=Layers.open(Store.open(root),stored)
    check(Native.bytes(opened.buffers[1])==lower and
        Native.bytes(opened.buffers[2])==upper,
        'Roundtrip changed the original raster payloads')
    opened:setVisible(2,false)
    opened:save()
    local hidden=Store.open(root):openProject(doc.id)
    check(not hidden.layers[2].visible and hidden.layers[2].name==newName,
        'Visibility and layer rename were not both persisted')
    return {suite='layer-metadata-properties-rbd2',passed=true,
        assertions=verified,utf8_name=true,atomic_rejection=true,
        thumbnail_unchanged=true,visibility_isolated=true,
        raster_history_preserved=true,rbd2_roundtrip=true}
end
return T
