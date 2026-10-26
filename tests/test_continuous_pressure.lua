-- Stage 45: real FFI / C++ continuous pressure with raster history.
local Native=require('native')
local Layers=require('layers')
local Store=require('store')
local T={}
function T.run(root)
    assert(Native.available,'Compiled C++ DLL required for pressure interpolation')
    local checks=0
    local function check(ok,msg) checks=checks+1;assert(ok,msg) end
    local store=Store.open(root)
    local doc=store:createProject('Pressão contínua',86,32,'',
        string.rep('\0',86*32*4))
    local session=Layers.open(store,store:openProject(doc.id))
    local color=0x5a99f2ff
    session:beginEdit()
    session:pressureStroke(9.5,15.5,74.5,15.5,2,14,
        color,.2,.9,1,0,0,0)
    check(session:finishEdit(),'Interpolated native stroke did not commit')
    local left=Native.readPixel(session:activeBuffer(),12,15)%256
    local center=Native.readPixel(session:activeBuffer(),42,15)%256
    local right=Native.readPixel(session:activeBuffer(),72,15)%256
    check(left>0 and left<center and center<right,
        'Endpoint alpha was not smoothly interpolated across C++ segment')
    check(Native.readPixel(session:activeBuffer(),12,20)==0,
        'Narrow start incorrectly covered a pixel outside start radius')
    check(Native.readPixel(session:activeBuffer(),72,20)%256>0,
        'Wide endpoint failed to cover its expanded radius')
    check(session:historyStats().undo==1,
        'One pressure-variable segment must be one undo operation')
    local raster=Native.bytes(session:activeBuffer())
    check(session:undo(),'Interpolated stroke cannot undo')
    check(Native.readPixel(session:activeBuffer(),42,15)==0,
        'Undo failed to remove stroke from raster')
    check(session:redo() and
        Native.bytes(session:activeBuffer())==raster,
        'Redo must restore pressure stroke byte for byte')
    -- Tilt and eraser are also routed through the same C++ primitive.
    session:beginEdit()
    session:pressureStroke(25.5,4.5,60.5,4.5,3,13,
        0xc37744ff,.35,.8,.25,90,0,3)
    check(session:finishEdit(),'Tilted variable-pressure stroke did not commit')
    check(Native.readPixel(session:activeBuffer(),58,4)%256>0,
        'Tilted variable-pressure segment missing endpoint')
    session:beginEdit()
    session:pressureStroke(9.5,15.5,74.5,15.5,3,16,
        color,.25,.9,1,0,0,2)
    check(session:finishEdit(),'Variable-pressure eraser did not commit')
    check(Native.readPixel(session:activeBuffer(),42,15)%256<center,
        'Variable-pressure eraser did not remove expected alpha')
    local after=Native.bytes(session:activeBuffer())
    session:save()
    local fresh=Store.open(root)
    local reopened=Layers.open(fresh,fresh:openProject(doc.id))
    check(Native.bytes(reopened:activeBuffer())==after,
        'RBD2 reopening changed native RGBA after tapered strokes')
    check(not reopened:canUndo(),'Session-only history must not persist')
    -- Preserve all previous constant-pressure raster results exactly.
    local sample=Native.buffer(86,32)
    local old=Native.buffer(86,32)
    Native.basicStroke(old,4.5,8.5,70.5,8.5,8,color,.5)
    Native.pressureStroke(sample,4.5,8.5,70.5,8.5,
        8,8,color,.5,.5,1,0,0,0)
    check(Native.bytes(old)==Native.bytes(sample),
        'Constant pressure must retain legacy hard-stroke bytes')
    return {suite='native-continuous-pressure-rbd2',passed=true,
        assertions=checks,gradient=true,tilt=true,eraser=true,
        undo_redo=true,rbd2_roundtrip=true,legacy_compatible=true}
end
return T
