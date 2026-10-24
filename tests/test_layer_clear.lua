-- Stage 24: clearing pixels never deletes layers or mutates metadata.
local Native=require('native')
local Store=require('store')
local Layers=require('layers')
local M={}
function M.run(root)
    assert(Native.available,'Requires compiled native C++ raster')
    local n=0
    local function ok(value,message)n=n+1;assert(value,message)end
    local original=string.char(0x24,0x38,0x68,0x8e)..
        string.char(0xab,0x04,0x03,0x00)..
        string.rep(string.char(0),4*4)
    local store=Store.open(root)
    local project=store:createProject('LimparCamada',3,2,'',original)
    local layers=Layers.open(store,store:openProject(project.id))
    layers:add('Superior')
    ok(layers.doc.active_layer==2,'New layer not selected')
    local empty=string.rep(string.char(0),3*2*4)
    local startHistory=layers:historyStats().undo
    ok(not layers:clearActive(),'Clearing transparent layer should be a no-op')
    ok(layers:historyStats().undo==startHistory,'Empty clear created history')
    layers:beginEdit()
    layers:pixel(0,0,0x765432a1)
    layers:pixel(2,1,0x11223344)
    ok(layers:finishEdit(),'Fixture must produce a raster history entry')
    local painted=Native.bytes(layers:activeBuffer())
    local background=Native.bytes(layers.buffers[1])
    local id=layers.doc.layers[2].id
    ok(layers:rename(2,'Cor – transparente'),'Rename fixture failed')
    local historyBefore=layers:historyStats().undo
    ok(layers:clearActive(),'Clear non-empty layer did not change raster')
    ok(layers:historyStats().undo==historyBefore+1,'Clear must add one undo step')
    ok(Native.bytes(layers.buffers[2])==empty,'Clear did not zero every RGBA byte')
    ok(Native.bytes(layers.buffers[1])==background,'Clear affected lower layer')
    ok(layers.doc.layers[2].id==id and
        layers.doc.layers[2].name=='Cor – transparente' and
        layers.doc.layers[2].visible and layers.doc.layers[2].opacity==1,
        'Clear altered layer metadata or persistent ID')
    ok(layers:undo(),'Undo clear failed')
    ok(Native.bytes(layers.buffers[2])==painted,'Undo did not restore exact RGBA')
    ok(layers:undo(),'Undo rename failed')
    ok(layers.doc.layers[2].name=='Superior','History lost property ordering')
    ok(layers:redo() and layers:redo(),'Chronological redo failed')
    ok(Native.bytes(layers.buffers[2])==empty,'Redo clear failed')
    ok(layers.doc.layers[2].name=='Cor – transparente','Redo rename failed')
    local beforeNoop=layers:historyStats().undo
    ok(not layers:clearActive(),'Second clear should be a no-op')
    ok(layers:historyStats().undo==beforeNoop,'Repeated clear must not add history')
    layers:save()
    local saved=Store.open(root):openProject(project.id)
    ok(saved.format==2 and saved.layer_count==2,'RBD2 format changed')
    ok(saved.layers[1].pixels==original and saved.layers[2].pixels==empty,
        'RBD2 layer isolation/persistence failed')
    ok(saved.layers[2].id==id and saved.layers[2].name=='Cor – transparente',
        'RBD2 metadata not retained')
    return {suite='native-layer-clear-rbd2',passed=true,assertions=n,
        exact_rgba=true,undo_redo=true,layer_isolation=true,
        no_op_empty=true,rbd2_roundtrip=true}
end
return M
