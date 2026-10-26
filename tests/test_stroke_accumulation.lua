-- Stage 47: the same C++ kernel used by real brush input should not
-- accumulate opacity at overlapping segments, including eraser, and must
-- retain a single per-gesture history record and unmodified RBD2 bytes.
local Native=require('native')
local Store=require('store')
local Layers=require('layers')
local T={}
function T.run(root)
    assert(Native.available,'Compiled C++ renderer required')
    local checks=0
    local function check(ok,msg) checks=checks+1;assert(ok,msg) end
    local store=Store.open(root)
    local doc=store:createProject('Opacidade unificada',80,50,'',
        string.rep('\0',80*50*4))
    local session=Layers.open(store,store:openProject(doc.id))
    check(not pcall(function()session:beginStrokeAccum()end),
        'Coverage must not start outside edit transaction')
    session:beginEdit()
    session:beginStrokeAccum()
    local color=0x6d3abbff
    session:pressureStroke(15.5,15.5,15.5,15.5,9,9,
        color,.4,.4,1,0,0,0,true)
    local initial=Native.readPixel(session:activeBuffer(),15,15)%256
    check(initial>0 and initial<255,'Initial translucent dab missing')
    session:pressureStroke(10.5,15.5,20.5,15.5,9,9,
        color,.4,.4,1,0,0,0,true)
    session:pressureStroke(15.5,10.5,15.5,20.5,9,9,
        color,.4,.4,1,0,0,0,true)
    session:recompose()
    check(Native.readPixel(session:activeBuffer(),15,15)%256==initial,
        'Straight segment crossing darkened the common pixel')
    check(not pcall(function()session:beginStrokeAccum()end),
        'Duplicate coverage state accepted')
    check(session:finishEdit(),'Gesture did not change the raster')
    check(session:historyStats().undo==1,
        'Subsegments must create a single undo transaction')
    local original=Native.bytes(session:activeBuffer())
    check(session:undo() and
        Native.readPixel(session:activeBuffer(),15,15)==0,
        'Undo must revert accumulated gesture')
    check(session:redo() and
        Native.bytes(session:activeBuffer())==original,
        'Redo must reproduce exact accumulated pixels')

    -- Begin a new independent gesture: coverage resets and can layer paint.
    session:beginEdit()
    session:beginStrokeAccum()
    session:pressureStroke(15.5,15.5,15.5,15.5,9,9,
        color,.4,.4,1,0,0,0)
    check(session:finishEdit(),'Second stroke was not committed')
    check(Native.readPixel(session:activeBuffer(),15,15)%256>initial,
        'Separate strokes must be allowed to build opacity')
    local beforeErase=Native.readPixel(session:activeBuffer(),15,15)%256
    session:beginEdit()
    session:beginStrokeAccum()
    session:pressureStroke(15.5,15.5,15.5,15.5,9,9,
        color,.5,.5,1,0,0,2,true)
    local erased=Native.readPixel(session:activeBuffer(),15,15)%256
    session:pressureStroke(10.5,15.5,20.5,15.5,9,9,
        color,.5,.5,1,0,0,2,true)
    session:recompose()
    check(erased>0 and erased<beforeErase and
        Native.readPixel(session:activeBuffer(),15,15)%256==erased,
        'Overlapping eraser must not erase twice')
    check(session:finishEdit(),'Eraser did not commit')
    local result=Native.bytes(session:activeBuffer())
    session:save()
    local reopened=Layers.open(Store.open(root),Store.open(root):openProject(doc.id))
    check(Native.bytes(reopened:activeBuffer())==result,
        'RBD2 round-trip modified accumulated alpha')
    check(session:historyStats().undo==3,
        'Per-gesture history count changed')
    return {suite='whole-stroke-opacity-native',passed=true,
        assertions=checks,no_darkening=true,undo_redo=true,
        rbd2_roundtrip=true,eraser=true}
end
return T
