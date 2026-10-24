-- Mixed chronological raster/structure history, tested against the real
-- compiled C++ raster and durable RBD2. No all-layer image snapshots.
local Native=require('native')
local Store=require('store')
local Layers=require('layers')
local T={}
function T.run(root)
    assert(Native.available,'Tests require native Windows C++ renderer')
    local checked=0
    local function ok(value,message)
        checked=checked+1;assert(value,message)
    end
    local store=Store.open(root)
    local project=store:createProject('Histórico misto',8,8,'',
        string.rep('\0',8*8*4))
    local scene=Layers.open(store,store:openProject(project.id))
    local baseId=scene.doc.layers[1].id
    -- Paint -> add -> paint -> duplicate -> paint -> move -> remove. Undo all.
    scene:beginEdit();scene:pixel(1,1,0xff3300ff)
    ok(scene:finishEdit(),'First paint did not enter history')
    local second=scene:add('Azul')
    local blueId=scene.doc.layers[second].id
    ok(scene:historyStats().undo==2,'Add must preserve prior paint history')
    scene:beginEdit();scene:pixel(2,2,0x1133aacc)
    ok(scene:finishEdit(),'Second layer paint did not enter history')
    local copy=scene:duplicate(second)
    local copyId=scene.doc.layers[copy].id
    local clonedStart=Native.bytes(scene.buffers[copy])
    ok(copy==3 and scene:historyStats().undo==4,
        'Duplicate must extend mixed history')
    scene:beginEdit();scene:pixel(3,3,0x77e244ff)
    ok(scene:finishEdit(),'Copied paint not recorded')
    local clonedEdited=Native.bytes(scene.buffers[3])
    ok(Native.readPixel(scene.buffers[2],3,3)==0,
        'Copy and original buffers are aliased')
    ok(scene:move(3,1),'Reorder should have changed layer order')
    ok(scene.doc.layers[1].id==copyId and scene.doc.active_layer==1,
        'Moved copy not selected in new position')
    scene:remove(2) -- remove the base layer
    ok(#scene.doc.layers==2 and scene.doc.layers[1].id==copyId and
        scene.doc.layers[2].id==blueId,
        'Remove did not remove original base')
    ok(scene:historyStats().undo==7 and not scene:canRedo(),
        'Mixed history count was not preserved')
    local changed,struct=scene:undo()
    ok(changed and struct and #scene.doc.layers==3 and
        scene.doc.layers[2].id==baseId and scene.doc.active_layer==1,
        'Undo remove failed to restore original identity/order/selection')
    changed,struct=scene:undo()
    ok(changed and struct and scene.doc.layers[3].id==copyId and
        scene.doc.active_layer==3,
        'Undo move did not restore order and selected layer')
    changed,struct=scene:undo()
    ok(changed and not struct and
        Native.bytes(scene.buffers[3])==clonedStart,
        'Undo copied paint failed')
    changed,struct=scene:undo()
    ok(changed and struct and #scene.doc.layers==2 and
        scene.doc.layers[2].id==blueId and scene.doc.active_layer==2,
        'Undo duplication failed to remove its own copy')
    changed,struct=scene:undo()
    ok(changed and not struct and
        Native.readPixel(scene.buffers[2],2,2)==0,
        'Undo original blue-layer paint failed')
    changed,struct=scene:undo()
    ok(changed and struct and #scene.doc.layers==1 and
        scene.doc.layers[1].id==baseId and scene.doc.active_layer==1,
        'Undo Add did not restore one-layer project')
    changed,struct=scene:undo()
    ok(changed and not struct and
        Native.readPixel(scene.buffers[1],1,1)==0,
        'Undo first paint failed')
    ok(not scene:canUndo() and scene:historyStats().redo==7,
        'All seven operations should now be redoable')
    -- Replay every operation; pixel modifications must remain independent.
    for i=1,7 do
        local redone=scene:redo()
        ok(redone,'Redo sequence stopped at position '..i)
    end
    ok(#scene.doc.layers==2 and scene.doc.layers[1].id==copyId and
        scene.doc.layers[2].id==blueId and
        Native.bytes(scene.buffers[1])==clonedEdited,
        'Redo all did not reproduce last state and copy pixels')
    ok(Native.readPixel(scene.buffers[2],3,3)==0,
        'Redo all altered source layer pixels')
    ok(scene:historyStats().undo==7 and not scene:canRedo(),
        'Redo all must restore mixed undo count')
    -- Save must serialize only document contents; no history on disk.
    scene:save()
    local reopenedDoc=Store.open(root):openProject(project.id)
    ok(reopenedDoc.format==2 and reopenedDoc.layer_count==2 and
        reopenedDoc.layers[1].id==copyId and
        reopenedDoc.layers[2].id==blueId and
        reopenedDoc.layers[1].pixels==clonedEdited,
        'RBD2 serialized incorrect mixed-history state')
    local reopened=Layers.open(Store.open(root),reopenedDoc)
    ok(not reopened:canUndo() and not reopened:canRedo(),
        'Session-only history leaked into RBD2')
    -- A divergent structural edit must discard all redo operations.
    changed,struct=scene:undo()
    ok(changed and struct,'Undo delete before divergence failed')
    ok(scene:canRedo(),'Redo should be present before divergent change')
    scene:add('Novo rumo')
    ok(not scene:canRedo() and scene:historyStats().redo==0,
        'New Add did not invalidate redo branch')
    -- A paint operation also has to clear a structural redo branch.
    scene:undo()
    ok(scene:canRedo(),'Redo structural insertion missing')
    scene:beginEdit();scene:pixel(0,0,0x22cc77ff)
    scene:finishEdit()
    ok(not scene:canRedo(),'New painting should clear structural redo')
    -- Rejected over-capacity insertion cannot truncate undo/redo.
    for i=#scene.doc.layers+1,Store.MAX_LAYERS do scene:add('Extra '..i) end
    local before=scene:historyStats()
    local raster=Native.bytes(scene:activeBuffer())
    local selected=scene.doc.active_layer
    local layerId=scene.doc.layers[selected].id
    ok(not pcall(function()scene:duplicate(selected)end),
        'Full 8-layer duplicate should fail')
    ok(not pcall(function()scene:add('Nona camada')end),
        'Full 8-layer Add should fail')
    ok(scene:historyStats().undo==before.undo and
        scene:historyStats().redo==before.redo and
        scene:historyStats().bytes==before.bytes and
        scene.doc.active_layer==selected and
        scene.doc.layers[selected].id==layerId and
        Native.bytes(scene:activeBuffer())==raster,
        'Rejected structural operation mutated history or raster')
    ok(not scene:move(1,1),
        'Reorder to same index should be no-op')
    ok(scene:historyStats().undo==before.undo,
        'No-op reorder should not create history')
    -- Total entry and byte bounds remain identical to prior raster budget.
    for i=1,40 do
        scene:move(1,2)
    end
    local bound=scene:historyStats()
    ok(bound.undo==Layers.MAX_HISTORY_ENTRIES and
        bound.bytes<=Layers.MAX_HISTORY_BYTES and bound.redo==0,
        'Repeated structural events bypassed history limits')
    local restored=0
    while scene:canUndo() do
        ok(scene:undo(),'Bounded structural undo failed')
        restored=restored+1
    end
    ok(restored==Layers.MAX_HISTORY_ENTRIES,
        'Exceeded maximum undo entry count')
    return {suite='mixed-structural-and-raster-history',
        passed=true,assertions=checked,chronological_undo_redo=true,
        add_remove_duplicate_reorder=true,independent_pixels=true,
        memory_bounded=true,redo_branching=true,
        invalid_actions_atomic=true,rbd2_roundtrip=true}
end
return T
