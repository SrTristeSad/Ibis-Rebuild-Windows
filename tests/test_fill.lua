-- Real LuaJIT FFI and compiled C++ RGBA bucket fill, no Lua raster fallback.
local Native=require('native')
local Layers=require('layers')
local Store=require('store')
local T={}
function T.run(root)
    assert(Native.available,'C++ kernel required for bucket fill')
    local n=0
    local function check(value,message)n=n+1;assert(value,message)end
    local store=Store.open(root)
    local w,h=4,3
    local doc=store:createProject('Balde',w,h,'',string.rep('\0',w*h*4))
    local scene=Layers.open(store,store:openProject(doc.id))
    scene:pixel(0,1,0x0000ffff)
    scene:add('Tinta')
    for y=0,2 do scene:pixel(1,y,0x000000ff) end
    check(scene:fill(0,1,0xff0000ff,0)==3,'Fill crossed black border')
    check(Native.readPixel(scene.composite,0,1)==0xff0000ff,'Fill not visible')
    check(Native.readPixel(scene.composite,2,1)==0,'Fill reached separated region')
    check(Native.readPixel(scene:activeBuffer(),1,1)==0x000000ff,'Border changed')
    check(scene:canUndo(),'Fill did not register history')
    check(scene:undo(),'Fill undo unavailable')
    check(Native.readPixel(scene.composite,0,1)==0x0000ffff,'Undo did not reveal lower layer')
    check(scene:redo(),'Fill redo unavailable')
    check(Native.readPixel(scene.composite,0,1)==0xff0000ff,'Redo wrong')
    scene:save()
    local reopened=Store.open(root):openProject(doc.id)
    check(reopened.format==2 and reopened.layer_count==2,'RBD2 changed schema')
    local again=Layers.open(Store.open(root),reopened)
    check(Native.readPixel(again.composite,0,1)==0xff0000ff,
        'Fill missing after RBD2 reopen')
    check(Native.readPixel(again.composite,2,1)==0,'Reopen damaged other region')
    check(not again:canUndo(),'Undo history incorrectly persisted')
    again:pixel(2,0,0x10101000)
    again:pixel(3,0,0x12121200)
    check(again:fill(2,0,0x44cc88ff,2)==2,'RGBA tolerance not respected')
    check(Native.readPixel(again:activeBuffer(),3,0)==0x44cc88ff,
        'Second within-tolerance pixel not filled')
    check(Native.readPixel(again:activeBuffer(),2,1)==0,
        'Tolerance fill crossed nonmatching transparent neighbor')
    local before=again:historyStats().undo
    check(again:fill(2,0,0x44cc88ff,0)==0,'Identical color created fake edit')
    check(again:historyStats().undo==before,'No-op changed undo stack')
    again:save()
    local final=Store.open(root):openProject(doc.id)
    check(final.layers[2].pixels:sub(9,12)==string.char(68,204,136,255),
        'Tolerance fill not saved')
    return {suite='native-bucket-fill-rbd2',passed=true,assertions=n,
        connectivity=4,tolerance=true,undo_redo=true,rbd2_roundtrip=true,
        scope='Independent RGBA flood fill; Android parity unverified'}
end
return T
