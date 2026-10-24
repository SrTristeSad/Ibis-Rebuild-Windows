-- Functional shapes: LuaJIT FFI -> native MSVC RGBA8 -> RBD2 layers.
local Native=require('native')
local Layers=require('layers')
local Store=require('store')
local T={}
function T.run(root)
    assert(Native.available,'Real C++ kernel required')
    local assertions=0
    local function check(ok,msg)assertions=assertions+1;assert(ok,msg)end
    local store=Store.open(root)
    local doc=store:createProject('Formas',9,9,'',string.rep('\0',9*9*4))
    local scene=Layers.open(store,store:openProject(doc.id))
    scene:pixel(4,4,0x00ff00ff)
    scene:add('Formas em cima')
    check(scene:drawShape(2,2,6,6,0,false,1,0xff0000ff),
        'Outline rectangle should be recorded')
    check(Native.readPixel(scene.composite,2,2)==0xff0000ff,
        'Rectangle border missing')
    check(Native.readPixel(scene.composite,4,4)==0x00ff00ff,
        'Outline incorrectly covered lower layer center')
    check(Native.readPixel(scene:activeBuffer(),4,4)==0,
        'Outline must not touch center pixel on active layer')
    check(scene:historyStats().undo==2,'Shape should append one step after Add')
    check(scene:undo(),'Rectangle undo failed')
    check(Native.readPixel(scene.composite,2,2)==0,
        'Rectangle undo left pixels')
    check(scene:redo(),'Rectangle redo failed')
    check(Native.readPixel(scene.composite,2,2)==0xff0000ff,
        'Rectangle redo lost border')
    check(scene:drawShape(2,2,6,6,1,true,1,0x0000ffff),
        'Filled ellipse should be recorded')
    check(Native.readPixel(scene.composite,4,4)==0x0000ffff,
        'Ellipse did not cover center')
    check(Native.readPixel(scene.composite,2,2)==0xff0000ff,
        'Ellipse must not cover outer corner')
    check(Native.readPixel(scene.buffers[1],4,4)==0x00ff00ff,
        'Drawing shapes modified lower layer')
    check(scene:undo(),'Ellipse undo failed')
    check(Native.readPixel(scene.composite,4,4)==0x00ff00ff,
        'Ellipse undo did not reveal underlayer')
    check(scene:redo(),'Ellipse redo failed')
    check(Native.readPixel(scene.composite,4,4)==0x0000ffff,
        'Ellipse redo missing')
    local history=scene:historyStats().undo
    check(not scene:drawShape(0,0,0,0,0,true,1,0xff884400),
        'Transparent shape must not create history')
    check(scene:historyStats().undo==history,
        'Transparent no-op affected undo')
    scene:save()
    local reopen=Store.open(root):openProject(doc.id)
    check(reopen.format==2 and reopen.layer_count==2,
        'Shapes changed the RBD2 document format')
    local again=Layers.open(Store.open(root),reopen)
    check(Native.readPixel(again.composite,4,4)==0x0000ffff,
        'Ellipse pixels were not saved')
    check(Native.readPixel(again.composite,2,2)==0xff0000ff,
        'Rectangle border was not saved')
    check(Native.readPixel(again.buffers[1],4,4)==0x00ff00ff,
        'Lower layer not preserved')
    check(not again:canUndo(),
        'History must remain session-local')
    return {suite='native-shapes-rbd2',passed=true,assertions=assertions,
        rectangle=true,ellipse=true,undo_redo=true,layer_isolation=true,
        rbd2_roundtrip=true,scope='Independent desktop shapes, not Android parity'}
end
return T
