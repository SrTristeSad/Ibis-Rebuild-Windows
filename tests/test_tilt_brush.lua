-- Real x64 native C++ tilted pen stroke, LuaJIT FFI and RBD2 layered history.
local Native=require('native')
local Layers=require('layers')
local Store=require('store')
local T={}
function T.run(root)
    assert(Native.available,'Real DLL required')
    local count=0
    local function check(ok,msg) count=count+1;assert(ok,msg) end
    local store=Store.open(root)
    local doc=store:createProject('Pincel inclinado',25,25,'',
        string.rep('\0',25*25*4))
    local scene=Layers.open(store,store:openProject(doc.id))
    scene:pixel(2,2,0x00ff00ff)
    scene:add('Caneta em ângulo')
    scene:beginEdit()
    scene:tiltStroke(12.5,12.5,12.5,12.5,8,0x3366aaff,1,1,90,0)
    check(scene:finishEdit(),'Tilted paint did not commit')
    check(Native.readPixel(scene:activeBuffer(),18,12)==0x3366aaff,
        'Horizontal tilt missing major-axis pixel')
    check(Native.readPixel(scene:activeBuffer(),12,18)==0,
        'Horizontal tilt leaked into minor-axis pixel')
    check(Native.readPixel(scene.buffers[1],2,2)==0x00ff00ff,
        'Tilt stroke modified underlying layer')
    check(scene:historyStats().undo==2,'Tilted pen must append one step after Add')
    check(scene:undo(),'Tilted pen undo failed')
    check(Native.readPixel(scene:activeBuffer(),18,12)==0,
        'Undo left tilted pixel')
    check(scene:redo(),'Tilted pen redo failed')
    check(Native.readPixel(scene:activeBuffer(),18,12)==0x3366aaff,
        'Redo lost tilted pixel')
    scene:beginEdit()
    scene:tiltStroke(12.5,12.5,12.5,12.5,8,0xe53b44ff,.6,.25,0,90)
    check(scene:finishEdit(),'Soft tilted pen did not commit')
    local edge=Native.readPixel(scene:activeBuffer(),12,18)
    check(edge%256>0 and edge%256<255,
        'Feathered Y-axis tilted pen lost alpha gradient')
    scene:save()
    local saved=Store.open(root):openProject(doc.id)
    check(saved.format==2 and saved.layer_count==2,'RBD2 changed format')
    local again=Layers.open(Store.open(root),saved)
    check(Native.readPixel(again:activeBuffer(),18,12)==0x3366aaff,
        'Horizontal pen mark missing after reopening')
    check(Native.readPixel(again:activeBuffer(),12,18)==edge,
        'Tilted soft alpha not saved')
    check(Native.readPixel(again.buffers[1],2,2)==0x00ff00ff,
        'Reload altered underlying raster')
    check(not again:canUndo(),'Undo history should not be persisted')
    return {suite='tilted-pen-native-rbd2',passed=true,assertions=count,
        ellipse_orientation=true,pressure_alpha=true,
        undo_redo=true,layer_isolation=true,rbd2_roundtrip=true}
end
return T
