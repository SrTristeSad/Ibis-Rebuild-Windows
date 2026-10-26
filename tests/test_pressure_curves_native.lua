-- Native C++ smoke test: selectable response changes stroke geometry
-- and alpha, while history, undo and RBD2 stay exactly compatible.
local C=require('pressure_curves')
local Pressure=require('touch_pressure')
local Native=require('native')
local Store=require('store')
local Layers=require('layers')
local T={}
function T.run(root)
    assert(Native.available,'Compiled native raster core required')
    local n=0
    local function check(ok,msg)n=n+1;assert(ok,msg)end
    local store=Store.open(root)
    local doc=store:createProject('Curvas de pressão',64,16,'',
        string.rep('\0',64*16*4))
    local scene=Layers.open(store,store:openProject(doc.id))
    local centers={firm=9,linear=31,soft=53}
    local alphas={}
    for _,mode in ipairs({'firm','linear','soft'}) do
        local p=C.apply(.25,mode)
        scene:beginEdit()
        local cx=centers[mode]+.5
        scene:stroke(cx,7.5,cx,7.5,Pressure.diameter(10,p),
            0xb333e1ff,Pressure.opacity(1,p))
        check(scene:finishEdit(),'Native stroke should create undo entry')
        alphas[mode]=Native.readPixel(scene:activeBuffer(),
            centers[mode],7)%256
        check(alphas[mode]>0 and alphas[mode]<255,
            'Partial-pressure stroke must have transparent coverage')
    end
    check(alphas.firm<alphas.linear and
        alphas.linear<alphas.soft,
        'Native alpha response must track selected curve')
    check(scene:historyStats().undo==3,
        'Each complete stroke should be one undo step')
    local center=centers.soft
    local softPixel=Native.readPixel(scene:activeBuffer(),center,7)
    check(scene:undo() and
        Native.readPixel(scene:activeBuffer(),center,7)==0,
        'Undo must erase only last curve stroke')
    check(scene:redo() and
        Native.readPixel(scene:activeBuffer(),center,7)==softPixel,
        'Redo must restore exact C++ RGBA data')
    scene:save()
    local reopened=Layers.open(Store.open(root),
        Store.open(root):openProject(doc.id))
    check(Native.bytes(reopened:activeBuffer())==
        Native.bytes(scene:activeBuffer()),
        'RBD2 must persist exact pressure-curve raster bytes')
    check(not reopened:canUndo(),'Undo history must not persist in RBD2')
    return {suite='native-pressure-curves',passed=true,
        assertions=n,alpha_response=true,undo_redo=true,
        rbd2_roundtrip=true}
end
return T
