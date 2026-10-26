-- Compare full multilayer recomposition and native dirty recomposition,
-- including alpha rounding, changing layer metadata, undo and RBD2.
local Native=require('native')
local Store=require('store')
local Layers=require('layers')
local Region=require('dirty_region')
local T={}
local function compare(session,rect,msg)
    session:recomposeRect(rect)
    local partial=Native.bytes(session.composite)
    session:recompose()
    assert(Native.bytes(session.composite)==partial,msg)
end
function T.run(root)
    assert(Native.available,'C++ renderer required')
    local store=Store.open(root)
    local doc=store:createProject('Atualização parcial',96,72,'',
        string.rep('\\0',96*72*4))
    local session=Layers.open(store,store:openProject(doc.id))
    session:stroke(6.5,6.5,74.5,60.5,15,0xca253aca,.8)
    session:add('Camada superior')
    session:stroke(15.5,11.5,72.5,55.5,20,0x25d4a5bb,.65)
    local rect=Region.segment(96,72,20.5,20.5,61.5,39.5,9,15)
    local before=Native.bytes(session.composite)
    session:beginEdit()
    session:beginStrokeAccum()
    session:pressureStroke(20.5,20.5,61.5,39.5,9,15,
        0x366fc9ff,.2,.7,.25,0,0,1,true)
    compare(session,rect,'Partial compose differs from full layered render')
    assert(session:finishEdit(),'Painting did not change the top layer')
    local chunk=Native.regionBytes(session.composite,rect)
    assert(#chunk==rect.w*rect.h*4,'Patch byte length mismatch')
    for y=0,rect.h-1 do
        for x=0,rect.w-1 do
            local rgba=Native.readPixel(session.composite,rect.x+x,rect.y+y)
            local p=(y*rect.w+x)*4+1
            local r=chunk:byte(p)*16777216+
                chunk:byte(p+1)*65536+chunk:byte(p+2)*256+chunk:byte(p+3)
            assert(rgba==r,'Packed patch does not match native composite')
        end
    end
    assert(before~=Native.bytes(session.composite),
        'Partial painting must actually modify pixels')
    local after=Native.bytes(session.composite)
    assert(session:undo(),'Undo after partial painter failed')
    assert(session:redo(),'Redo after partial painter failed')
    assert(Native.bytes(session.composite)==after,'Redo changed composited output')
    session:save()
    local fresh=Store.open(root)
    local reopened=Layers.open(fresh,fresh:openProject(doc.id))
    assert(Native.bytes(reopened.composite)==after,'RBD2 changed partial pixels')
    local corner={x=0,y=0,w=2,h=2}
    compare(reopened,corner,'Partial compose at canvas corner diverged')
    return {suite='native-partial-canvas',passed=true,
        rgba_identical=true,rbd2_roundtrip=true,undo_redo=true}
end
return T
