local Store=require('store')
local Native=require('native')
local Layers=require('layers')
local T={}
function T.run(root)
    assert(Native.available,'C++ DLL required')
    local checks=0
    local function check(v,m) checks=checks+1;assert(v,m) end
    local store=Store.open(root)
    local doc=store:createProject('Selecionar e mover',6,3,'',string.rep('\0',6*3*4))
    local scene=Layers.open(store,store:openProject(doc.id))
    scene:pixel(2,1,0x00ff00ff)
    scene:add('Rastro vermelho')
    scene:pixel(0,0,0xff0000ff)
    scene:pixel(1,0,0x800000ff)
    local red=Native.readPixel(scene.composite,0,0)
    check(red==0xff0000ff,'source not painted')
    check(not scene:moveSelection(0,0,2,1,0,0),'zero move should be no-op')
    check(scene:moveSelection(0,0,2,1,1,0),'rect move was not applied')
    check(Native.readPixel(scene:activeBuffer(),0,0)==0,'old source not cut')
    check(Native.readPixel(scene:activeBuffer(),1,0)==red,'destination not red')
    check(Native.readPixel(scene:activeBuffer(),2,0)==0x800000ff,'second moved pixel lost')
    check(Native.readPixel(scene.composite,2,1)==0x00ff00ff,
        'underlying layer was modified')
    check(scene:undo(),'selection move cannot be undone')
    check(Native.readPixel(scene.composite,0,0)==red,'selection undo wrong')
    check(Native.readPixel(scene.composite,2,0)==0,'selection undo residue')
    check(scene:redo(),'selection move cannot be redone')
    check(Native.readPixel(scene.composite,1,0)==red,'selection redo wrong')
    check(scene:historyStats().undo==1,'move should be one undo step')
    scene:save()
    local reopened=Store.open(root):openProject(doc.id)
    check(reopened.format==2 and reopened.layer_count==2,'RBD2 structure not preserved')
    local recovered=Layers.open(Store.open(root),reopened)
    check(Native.readPixel(recovered.composite,1,0)==red,'selection not saved')
    check(Native.readPixel(recovered.composite,0,0)==0,'old selection unexpectedly restored')
    local bad=Native.buffer(2,2,string.rep(string.char(18,32,55,255),4))
    local original=Native.bytes(bad)
    local valid=pcall(Native.moveRect,bad,0,0,3,1,0,0)
    check(not valid and Native.bytes(bad)==original,'invalid move wrote RGBA')
    check(recovered:transformSelection(1,0,2,1,1,0,1,2,1),
        'Clockwise quarter-turn should commit one raster edit')
    check(Native.readPixel(recovered:activeBuffer(),1,0)==red,
        'Rotated top-left pixel incorrect')
    check(Native.readPixel(recovered:activeBuffer(),1,1)==0x800000ff,
        'Rotated lower pixel incorrect')
    check(Native.readPixel(recovered:activeBuffer(),2,0)==0,
        'Rotation failed to clear old selected pixel')
    check(Native.readPixel(recovered.composite,2,1)==0x00ff00ff,
        'Rotation affected independent lower layer')
    check(recovered:undo(),'Rotation could not be undone')
    check(Native.readPixel(recovered:activeBuffer(),2,0)==0x800000ff,
        'Undo did not restore rectangle orientation')
    check(recovered:redo(),'Rotation could not be redone')
    check(recovered:transformSelection(1,0,1,2,1,0,2,2,0),
        'Nearest-neighbor scaling should change layer')
    check(Native.readPixel(recovered:activeBuffer(),1,1)==0x800000ff and
        Native.readPixel(recovered:activeBuffer(),2,1)==0x800000ff,
        'Nearest-neighbor scaling failed to duplicate bottom pixel')
    local beforeInvalid=Native.bytes(recovered:activeBuffer())
    check(not pcall(recovered.transformSelection,recovered,
        1,0,2,2,5,0,2,2,0),
        'Out-of-bounds destination transform accepted')
    check(Native.bytes(recovered:activeBuffer())==beforeInvalid,
        'Invalid transform wrote to original layer')
    recovered:save()
    local scaled=Layers.open(Store.open(root),Store.open(root):openProject(doc.id))
    check(Native.readPixel(scaled.composite,2,1)==0x800000ff,
        'Scaled layer was not preserved through RBD2 save/reopen')
    check(Native.readPixel(scaled.buffers[1],2,1)==0x00ff00ff,
        'Scale modified underlying layer pixels')
    return {suite='rectangle-selection-rbd2',passed=true,assertions=checks,
        move_native=true,rotation_native=true,scale_native=true,undo_redo=true,reopen=true,source_isolated=true,
        scope='Independent rectangle cut-move; no Android selection equivalence'}
end
return T
