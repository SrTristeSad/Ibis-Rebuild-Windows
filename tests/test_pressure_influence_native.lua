-- Exact C++ raster tests for the four independent pressure channels.
local Influence=require('pressure_influence')
local Native=require('native')
local Store=require('store')
local Layers=require('layers')
local T={}
function T.run(root)
    assert(Native.available,'Compiled C++ rasterizer required')
    local n=0
    local function check(ok,why)n=n+1;assert(ok,why)end
    local store=Store.open(root)
    local doc=store:createProject('Influência separada',70,17,'',
        string.rep('\0',70*17*4))
    local scene=Layers.open(store,store:openProject(doc.id))
    local modes={
        {name='both',size=true,alpha=true,x=8},
        {name='size',size=true,alpha=false,x=25},
        {name='alpha',size=false,alpha=true,x=42},
        {name='none',size=false,alpha=false,x=59}
    }
    local alphas={}
    for _,mode in ipairs(modes) do
        local diameter,opacity=Influence.resolve(12,.8,.25,
            'linear',mode.size,mode.alpha)
        scene:beginEdit()
        scene:stroke(mode.x+.5,8.5,mode.x+.5,8.5,
            diameter,0x7294c8ff,opacity)
        check(scene:finishEdit(),'Stroke must commit exactly once')
        local center=Native.readPixel(scene:activeBuffer(),mode.x,8)
        alphas[mode.name]=center%256
        check(alphas[mode.name]>0,
            'Real C++ engine must paint the pressure-adjusted center')
        local border=Native.readPixel(scene:activeBuffer(),mode.x+4,8)
        check((border~=0)==(not mode.size),
            'Real C++ brush diameter must depend only on size channel')
    end
    check(alphas.both==alphas.alpha and
        alphas.size==alphas.none and
        alphas.both<alphas.size,
        'Real C++ alpha must depend only on opacity channel')
    check(scene:historyStats().undo==4,
        'Each mode must be one undoable stroke')
    local last=Native.bytes(scene:activeBuffer())
    check(scene:undo() and scene:redo() and
        Native.bytes(scene:activeBuffer())==last,
        'Undo/redo must restore every RGBA channel byte')
    scene:save()
    local restored=Layers.open(Store.open(root),
        Store.open(root):openProject(doc.id))
    check(Native.bytes(restored:activeBuffer())==last,
        'RBD2 reopen must retain independent pressure strokes exactly')
    return {suite='independent-pressure-native-rbd2',
        passed=true,assertions=n,raster_modes=true,
        undo_redo=true,rbd2_roundtrip=true}
end
return T
