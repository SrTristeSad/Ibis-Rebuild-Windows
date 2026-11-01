-- Verifica pinceladas longas na API real de camadas:
-- cobertura por gesto, historico, persistencia RBD2 e modo anterior.
local Native=require('native')
local Store=require('store')
local Layers=require('layers')
local Suite={}
local function paint(store,doc,optimized)
    Native.setStrokeScanlineEnabled(optimized)
    local session=Layers.open(store,store:openProject(doc.id))
    session:beginEdit()
    session:beginStrokeAccum()
    -- Duas curvas com curvas de pressao e sobreposicao sobre o centro.
    for i=1,80 do
        local t=(i-1)/80
        local nextT=i/80
        session:pressureStroke(
            10.5+350*t,9.5+220*t,
            10.5+350*nextT,9.5+220*nextT,
            5+14*t,5+14*nextT,0x398fddff,
            .25+.5*t,.25+.5*nextT,.35,0,0,1,true)
    end
    for i=1,80 do
        local t=(i-1)/80
        local nextT=i/80
        session:pressureStroke(
            359.5-350*t,9.5+220*t,
            359.5-350*nextT,9.5+220*nextT,
            16,16,0xed9f3cff,.48,.48,.7,0,0,1,true)
    end
    session:recompose()
    assert(session:finishEdit(),'Pincelada longa nao entrou no historico')
    assert(session:historyStats().undo==1,'Uma pincelada criou muitos undos')
    local expected=Native.bytes(session:activeBuffer())
    assert(session:undo(),'Undo da pincelada longa falhou')
    assert(session:redo(),'Redo da pincelada longa falhou')
    assert(Native.bytes(session:activeBuffer())==expected,
        'Redo alterou bytes da pincelada longa')
    session:save()
    local reopened=Layers.open(store,store:openProject(doc.id))
    assert(Native.bytes(reopened:activeBuffer())==expected,
        'RBD2 alterou bytes da pincelada longa')
    return expected,Native.bytes(session.composite)
end
function Suite.run(root)
    local store=Store.open(root)
    local blank=string.rep('\0',384*256*4)
    local a=store:createProject('Long Stroke Reference',384,256,'',blank)
    local b=store:createProject('Long Stroke Clipped',384,256,'',blank)
    local ok,res=xpcall(function()
        local before,referenceComposite=paint(store,a,false)
        local after,clippedComposite=paint(store,b,true)
        assert(before==after,'Varredura por linha mudou o raster RBD2')
        assert(referenceComposite==clippedComposite,
            'Composicao final divergiu em pinceladas longas')
        return {suite='long-stroke-lua',passed=true,segments=160,
            byte_identical=true,undo_redo=true,rbd2_roundtrip=true}
    end,debug.traceback)
    Native.setStrokeScanlineEnabled(true)
    if not ok then error(res) end
    return res
end
return Suite
