-- Full layered-document integration tests, using actual LuaJIT FFI and C++.
local Store=require('store')
local Native=require('native')
local Layers=require('layers')
local JSON=require('json')
local M={}
function M.run(root)
    assert(Native.available,'C++ required for layered tests')
    local assertions=0
    local function ok(value,message) assertions=assertions+1; assert(value,message) end
    local function rejects(fn,message)
        local succeeded=pcall(fn);ok(not succeeded,message)
    end
    local store=Store.open(root)
    local base=string.char(25,35,45,255)..string.rep('\0',3*4)
    local original=store:createProject('Legado RBD1',2,2,'',base)
    local oldPath='projects/'..original.id..'.rbd'
    local oldBytes=store.fs:read(oldPath)
    ok(oldBytes:sub(1,8)==Store.MAGIC,'new project should remain RBD1')
    local session=Layers.open(store,store:openProject(original.id))
    ok(#session.doc.layers==1 and session.doc.active_layer==1,'legacy promotion failed')
    ok(store.fs:read(oldPath)==oldBytes,'opening legacy altered bytes on disk')
    local top=session:add('Tinta azul')
    ok(top==2 and #session.doc.layers==2,'layer not inserted')
    session:pixel(0,0,0x0000ffff)
    ok(Native.readPixel(session.composite,0,0)==0x0000ffff,'top layer not visible')
    session:setVisible(2,false)
    ok(Native.readPixel(session.composite,0,0)==0x19232dff,'hidden layer not skipped')
    session:setVisible(2,true)
    session:setOpacity(2,0.5)
    local merged=Native.readPixel(session.composite,0,0)
    local red=math.floor(merged/16777216)%256
    local blue=math.floor(merged/256)%256
    ok(red>=12 and red<=13 and blue>=149 and blue<=151,'opacity mix wrong')
    session:move(2,1)
    ok(session.doc.active_layer==1 and
        Native.readPixel(session.composite,0,0)==0x19232dff,'move must alter stacking')
    session:move(1,2)
    ok(session.doc.active_layer==2,'move should preserve selected identity')
    session:save()
    local contents=store.fs:read(oldPath)
    ok(contents:sub(1,8)==Store.MAGIC2 and session.doc.revision==2,
        'RBD2 migration/revision failed')
    local reopened=Store.open(root):openProject(original.id)
    ok(reopened.format==2 and reopened.layer_count==2 and
        reopened.active_layer==2 and #reopened.layers==2,'RBD2 metadata lost')
    ok(reopened.layers[1].pixels==base and
        reopened.layers[2].pixels:sub(1,4)==string.char(0,0,255,255),
        'RBD2 layered RGBA lost')
    ok(reopened.layers[2].opacity==0.5 and reopened.layers[2].visible,
        'RBD2 opacity/visibility lost')
    local reload=Layers.open(Store.open(root),reopened)
    ok(Native.readPixel(reload.composite,0,0)==merged,'composite changed after reopening')
    local previous=store:openProject(original.id)
    reload:setVisible(2,false);reload:save()
    ok(store:openProject(original.id).layers[2].visible==false,'visibility not persisted')
    rejects(function() store:saveProject(previous) end,'stale RBD2 save overwrote revision')
    reload:setVisible(2,true)
    reload:select(1);reload:remove(2)
    ok(#reload.doc.layers==1 and reload.doc.active_layer==1,'remove layer failed')
    rejects(function() reload:remove(1) end,'last layer removed')
    rejects(function() reload:setOpacity(1,0/0) end,'NaN opacity accepted')
    rejects(function() reload:setOpacity(1,1.1) end,'out-of-range opacity accepted')
    for i=2,Store.MAX_LAYERS do reload:add('Raster '..i) end
    ok(#reload.doc.layers==Store.MAX_LAYERS,'layer capacity not reachable')
    rejects(function() reload:add('Over limit') end,'layer count exceeded without error')
    local unchanged=store.fs:read(oldPath)
    local bad=store:openProject(original.id)
    bad.layers[1].pixels='oops'
    rejects(function() store:saveProject(bad) end,'truncated layer payload accepted')
    ok(store.fs:read(oldPath)==unchanged,'invalid save changed last durable project')
    local metadataLength=contents:byte(9)+contents:byte(10)*256+
        contents:byte(11)*65536+contents:byte(12)*16777216
    local header=JSON.decode(contents:sub(13,12+metadataLength))
    header.layers[2].opacity=1.25
    local altered=JSON.encode(header)
    local n=#altered
    local little=string.char(n%256,math.floor(n/256)%256,
        math.floor(n/65536)%256,math.floor(n/16777216)%256)
    store.fs:writeAtomic(oldPath,Store.MAGIC2..little..altered..
        contents:sub(13+metadataLength))
    rejects(function() store:openProject(original.id) end,'invalid layer metadata accepted')
    store.fs:writeAtomic(oldPath,unchanged)
    ok(store:openProject(original.id).revision==3,'restoration after corruption failed')
    return {suite='rbd2-native-layers',passed=true,assertions=assertions,
        migrated_from_rbd1=true,roundtrip=true,composite_native=true,
        scope='Independent desktop normal blend; Android equivalence not established'}
end
return M
