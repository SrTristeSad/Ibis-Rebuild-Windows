-- True C++ RGBA merge-down, native metadata/history and durable RBD2.
local Native=require('native')
local Store=require('store')
local Layers=require('layers')
local T={}
local function channels(pixel)
    return math.floor(pixel/0x1000000)%256,
        math.floor(pixel/0x10000)%256,
        math.floor(pixel/0x100)%256,pixel%256
end
function T.run(root)
    assert(Native.available,'Merge test requires real C++ DLL')
    local count=0
    local function check(ok,why) count=count+1;assert(ok,why) end
    local store=Store.open(root)
    local doc=store:createProject('Mesclar abaixo',5,5,'',
        string.rep('\0',5*5*4))
    local ls=Layers.open(store,store:openProject(doc.id))
    local backgroundId=ls.doc.layers[1].id
    ls:pixel(2,2,0x224466ff)
    local background=Native.bytes(ls.buffers[1])
    ls:add('Aquarela')
    local below=2
    ls:pixel(2,2,0x11dd4488)
    ls:pixel(1,1,0xabcdef99)
    ls:setOpacity(2,0.7)
    local bottom=Native.bytes(ls.buffers[below])
    local bottomId=ls.doc.layers[2].id
    ls:add('Acabamento')
    ls:pixel(2,2,0xe53b44bb)
    ls:pixel(3,3,0x773311ff)
    ls:setOpacity(3,0.8)
    local upper=Native.bytes(ls.buffers[3])
    local topId=ls.doc.layers[3].id
    local originalComposite=Native.bytes(ls.composite)
    local beforeHistory=ls:historyStats().undo
    local newIndex=ls:mergeDown(3)
    check(newIndex==2 and #ls.doc.layers==2 and ls.doc.active_layer==2,
        'Merge did not remove upper/activate lower')
    check(ls.doc.layers[2].id==bottomId and
        ls.doc.layers[2].opacity==1 and ls.doc.layers[2].visible,
        'Merged layer metadata is not normalized')
    check(ls.doc.layers[2].name=='Aquarela' and
        ls.doc.layers[1].id==backgroundId,
        'Merge incorrectly changed surviving layer identity/name')
    local merged=Native.bytes(ls.buffers[2])
    check(merged~=bottom and merged~=upper,'Merged raster was not composited')
    check(ls:historyStats().undo==beforeHistory+1,
        'Merge must create one structural history entry')
    check(ls.undoStack[#ls.undoStack].size==#bottom+#upper+256,
        'Merge history stores more than two layer images')
    local afterComposite=Native.bytes(ls.composite)
    -- 8-bit compositing at two intermediate boundaries can differ by a
    -- channel unit due to round-to-nearest: no strict byte-perfect claim.
    for p=1,#originalComposite do
        check(math.abs(originalComposite:byte(p)-afterComposite:byte(p))<=2,
            'Merge visibly changed the RGBA composition')
    end
    local changed,struct=ls:undo()
    check(changed and struct and #ls.doc.layers==3 and
        ls.doc.active_layer==3,'Undo merge did not restore layer count/selection')
    check(ls.doc.layers[2].id==bottomId and ls.doc.layers[3].id==topId and
        ls.doc.layers[2].opacity==.7 and ls.doc.layers[3].opacity==.8,
        'Undo merge lost source layer IDs and opacity')
    check(Native.bytes(ls.buffers[2])==bottom and
        Native.bytes(ls.buffers[3])==upper and
        Native.bytes(ls.buffers[1])==background,
        'Undo merge did not restore both source buffers')
    changed,struct=ls:redo()
    check(changed and struct and #ls.doc.layers==2 and
        Native.bytes(ls.buffers[2])==merged,
        'Redo merge did not reproduce C++ composite deterministically')
    ls:save()
    local persisted=Store.open(root):openProject(doc.id)
    check(persisted.format==2 and persisted.layer_count==2 and
        persisted.layers[2].pixels==merged and
        persisted.layers[2].id==bottomId,
        'RBD2 merge result did not persist')
    local reopened=Layers.open(Store.open(root),persisted)
    check(not reopened:canUndo(),'Merge history leaked into persistent RBD2')

    -- Hidden source contributes nothing, but its original pixel payload
    -- must remain recoverable through Undo.
    ls:undo()
    ls:setVisible(3,false)
    local lowerBytes=Native.bytes(ls.buffers[2])
    ls:mergeDown(3)
    check(Native.readPixel(ls.buffers[2],3,3)==0,
        'Hidden upper layer contributed colored pixels to merged raster')
    ls:undo()
    check(not ls.doc.layers[3].visible and
        Native.bytes(ls.buffers[3])==upper and
        Native.bytes(ls.buffers[2])==lowerBytes,
        'Undo hidden merge failed to restore source metadata/pixels')
    -- No lower layer is a strict no-op (does not alter history or bytes).
    ls:select(1)
    local stats=ls:historyStats()
    local zero=Native.bytes(ls:activeBuffer())
    check(not pcall(function()ls:mergeDown(1)end),
        'Base layer was merged without a lower destination')
    check(ls:historyStats().undo==stats.undo and
        ls:historyStats().redo==stats.redo and
        Native.bytes(ls:activeBuffer())==zero,
        'Rejected merge changed pixels or history')
    -- A new paint on the restored source clears merge redo.
    ls:select(3)
    ls:beginEdit()
    ls:pixel(0,0,0xff3300ff)
    ls:finishEdit()
    check(not ls:canRedo(),'Divergent paint failed to invalidate merge redo')
    -- Merge must work at full eight-layer capacity and Undo restores eight.
    for i=#ls.doc.layers+1,Store.MAX_LAYERS do
        ls:add('Extra '..i)
    end
    check(#ls.doc.layers==8,'Unable to reach 8-layer cap')
    local sourceId=ls.doc.layers[8].id
    local belowId=ls.doc.layers[7].id
    ls:mergeDown(8)
    check(#ls.doc.layers==7 and ls.doc.layers[7].id==belowId,
        'Merge at capacity failed')
    ls:undo()
    check(#ls.doc.layers==8 and ls.doc.layers[8].id==sourceId,
        'Undo merge did not restore max capacity')
    ls:redo()
    check(#ls.doc.layers==7,'Redo after restoring capacity failed')
    return {suite='native-merge-down-rbd2',passed=true,assertions=count,
        native_source_over=true,restores_both_sources=true,
        history_two_layer_budget=true,hidden_layers=true,
        capacity_bound=true,redo_branching=true,rbd2_roundtrip=true}
end
return T
