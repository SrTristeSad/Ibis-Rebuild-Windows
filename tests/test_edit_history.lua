-- LuaJIT + C++ functional stroke edit history, separate from on-disk RBD2.
local Store=require('store')
local Native=require('native')
local Layers=require('layers')
local T={}
function T.run(root)
    assert(Native.available,'Real C++ DLL required')
    local count=0
    local function check(ok,message)count=count+1;assert(ok,message)end
    local store=Store.open(root)
    local empty=string.rep('\0',7*3*4)
    local doc=store:createProject('Undo / borracha',7,3,'',empty)
    local ls=Layers.open(store,store:openProject(doc.id))
    check(not ls:canUndo() and not ls:canRedo(),'new session has history')
    ls:beginEdit()
    ls:stroke(1.5,1.5,5.5,1.5,1,0xff0000ff,1)
    check(ls:finishEdit(),'stroke not recorded')
    check(ls:historyStats().undo==1 and ls:historyStats().redo==0,'stroke not grouped')
    local red=Native.readPixel(ls.composite,3,1)
    check(red==0xff0000ff,'stroke wrong color')
    check(ls:undo(),'undo not available')
    check(Native.readPixel(ls.composite,3,1)==0,'undo not exact')
    check(ls:redo(),'redo not available')
    check(Native.readPixel(ls.composite,3,1)==red,'redo not exact')
    ls:add('Cobertura')
    check(ls:historyStats().undo==2 and not ls:canRedo(),
        'Layer insertion must join prior paint in mixed history')
    ls:beginEdit();ls:stroke(1.5,1.5,5.5,1.5,1,0x0000ffff,1)
    ls:finishEdit()
    check(Native.readPixel(ls.composite,3,1)==0x0000ffff,'top did not cover base')
    ls:beginEdit()
    ls:erase(1.5,1.5,5.5,1.5,1,1)
    check(ls:finishEdit(),'eraser must be undoable')
    check(Native.readPixel(ls.composite,3,1)==red,'erased top must reveal red underlayer')
    check(Native.readPixel(ls:activeBuffer(),3,1)==0,'top eraser did not erase')
    ls:select(1)
    check(ls:undo(),'undo eraser across selection failed')
    check(ls.doc.active_layer==2,'undo failed to find edited layer by identity')
    check(Native.readPixel(ls.composite,3,1)==0x0000ffff,'undo must restore blue top')
    check(ls:redo(),'redo across selection failed')
    check(Native.readPixel(ls.composite,3,1)==red,'redo must reveal base again')
    ls:undo()
    ls:beginEdit();ls:pixel(0,0,0x00ff00ff)
    ls:finishEdit()
    check(not ls:canRedo(),'new edit failed to discard redo branch')
    ls:save()
    local reopened=Store.open(root):openProject(doc.id)
    check(reopened.format==2 and reopened.layer_count==2,'RBD2 save changed format')
    check(reopened.layers[2].pixels:sub(1,4)==string.char(0,255,0,255),
        'active layer history pixels not saved')
    check(reopened.layers[2].pixels:sub((1*7+3)*4+1,(1*7+3)*4+4)==
        string.char(0,0,255,255),'undo state not persisted')
    local recovered=Layers.open(Store.open(root),reopened)
    check(not recovered:canUndo(),'history should not be written to RBD2')
    check(Native.readPixel(recovered.composite,3,1)==0x0000ffff,
        'persistent state changed on reopening')
    for i=1,40 do
        recovered:beginEdit()
        recovered:pixel(0,0,i*16777216+0x000000ff)
        recovered:finishEdit()
    end
    local stats=recovered:historyStats()
    check(stats.undo==Layers.MAX_HISTORY_ENTRIES and stats.redo==0,
        'undo entry cap not enforced')
    check(stats.bytes<=Layers.MAX_HISTORY_BYTES and stats.bytes>=0,
        'history byte accounting exceeded budget')
    recovered:setOpacity(2,.5)
    check(not recovered:canUndo(),'opacity mutation did not invalidate history')
    recovered:beginEdit();recovered:erase(2.5,1.5,2.5,1.5,1,0)
    check(not recovered:finishEdit(),'no-op should not create history')
    check(not recovered:canUndo(),'no-op should not mutate history')
    return {suite='layered-edit-history',passed=true,assertions=count,
        native_eraser=true,undo_redo=true,history_bounded=true,rbd2_preserved=true,
        scope='Session-local chronological raster and layer history; not Android undo model'}
end
return T
