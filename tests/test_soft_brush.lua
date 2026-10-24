-- Real LuaJIT FFI -> native C++ feather brush, layered RBD2 and session undo.
local Native=require('native')
local Layers=require('layers')
local Store=require('store')
local T={}
function T.run(root)
    assert(Native.available,'Compiled C++ DLL is required')
    local verified=0
    local function check(v,msg) verified=verified+1;assert(v,msg) end
    local store=Store.open(root)
    local doc=store:createProject('Pincéis rígido e suave',17,17,'',
        string.rep('\0',17*17*4))
    local scene=Layers.open(store,store:openProject(doc.id))
    scene:pixel(8,8,0x00ff00ff)
    scene:add('Pincel superior')
    scene:beginEdit()
    scene:softStroke(8.5,8.5,8.5,8.5,8,0xe53b44ff,1,0.25)
    check(scene:finishEdit(),'Soft stroke did not commit')
    local center=Native.readPixel(scene:activeBuffer(),8,8)
    local fringe=Native.readPixel(scene:activeBuffer(),11,8)
    check(center==0xe53b44ff,'Center is not full brush color')
    check(fringe%256>0 and fringe%256<255,'Soft feather fringe did not preserve alpha')
    check(Native.readPixel(scene:activeBuffer(),12,8)==0,
        'Feather brush exceeded outer radius')
    check(Native.readPixel(scene.buffers[1],8,8)==0x00ff00ff,
        'Soft stroke modified lower raster')
    check(Native.readPixel(scene.composite,8,8)==0xe53b44ff,
        'Composite did not show opaque soft brush center')
    check(scene:historyStats().undo==2,'Stroke should append one step after Add')
    check(scene:undo(),'Soft stroke could not be undone')
    check(Native.readPixel(scene.composite,8,8)==0x00ff00ff,
        'Undo did not uncover lower layer')
    check(scene:redo(),'Soft stroke could not be redone')
    check(Native.readPixel(scene:activeBuffer(),11,8)==fringe,
        'Redo did not reproduce feather transparency')
    scene:save()
    local reopened=Store.open(root):openProject(doc.id)
    check(reopened.format==2 and reopened.layer_count==2,
        'Soft stroke should not change RBD2 format')
    local again=Layers.open(Store.open(root),reopened)
    check(Native.readPixel(again:activeBuffer(),11,8)==fringe,
        'Feather brush alpha was not persisted')
    check(Native.readPixel(again.buffers[1],8,8)==0x00ff00ff,
        'Reload modified lower layer')
    check(not again:canUndo(),'History must remain session only')
    again:beginEdit()
    again:stroke(2.5,2.5,2.5,2.5,3,0xff0000ff,1)
    check(again:finishEdit(),'Existing hard stroke was affected')
    check(Native.readPixel(again:activeBuffer(),2,2)==0xff0000ff,
        'Hard brush baseline failed')
    return {suite='native-feather-brush-rbd2',passed=true,
        assertions=verified,soft_edge=true,hard_baseline=true,
        undo_redo=true,layer_isolation=true,rbd2_roundtrip=true,
        scope='Independent desktop brush, not Android brush equivalence'}
end
return T
