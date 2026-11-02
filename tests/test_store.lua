-- Called by the desktop host: require('test_store').run(absoluteIsolatedRoot).
local JSON=require('json')
local FS=require('fs')
local Store=require('store')
local Test={}
function Test.run(rootPath)
    local assertions=0
    local function check(value,message) assertions=assertions+1; assert(value,message) end
    local function rejects(fn,message) local ok=pcall(fn); check(not ok,message) end
    local sample={text='Ação 🎨 " \n',list=JSON.array({true,false,JSON.null,-2,0.25}),empty=JSON.array()}
    local round=JSON.decode(JSON.encode(sample))
    check(round.text==sample.text and round.list[3]==JSON.null and round.list[4]==-2,'JSON roundtrip')
    check(JSON.encode(round.empty)=='[]','empty array preserved')
    check(JSON.decode('"\\uD83C\\uDFA8"')=='🎨','surrogate pair')
    for _,bad in ipairs({'{"x":1,"x":2}','[1,]','{"x":}','01','1e999','"\\uD800"','true false','"'..string.char(255)..'"'}) do rejects(function() JSON.decode(bad) end,'JSON malformed accepted') end
    rejects(function() JSON.encode(0/0) end,'NaN encoded')
    rejects(function() JSON.encode(math.huge) end,'infinity encoded')
    rejects(function() JSON.decode(string.rep('[',50)..'0'..string.rep(']',50)) end,'depth limit')
    rejects(function() JSON.encode({[1]='a',[3]='b'}) end,'sparse array encoded')
    rejects(function() JSON.encode({1,2,3},{maxNodes=3}) end,'encode node limit')
    local cyclic={};cyclic.self=cyclic;rejects(function() JSON.encode(cyclic) end,'cyclic table encoded')
    local fs=FS.new(rootPath)
    for _,bad in ipairs({'../escape','projects/../escape','C:\\outside','/outside','projects/CON','projects/a.','projects/a:b'}) do rejects(function() fs:absolute(bad) end,'path traversal/ambiguity accepted') end
    fs:writeAtomic('atomic.txt','before')
    rejects(function() fs:writeAtomic('atomic.txt',{}) end,'invalid write accepted')
    check(fs:read('atomic.txt')=='before','failed write altered original')
    fs:writeAtomic('atomic.txt','after\0binary')
    check(fs:read('atomic.txt')=='after\0binary','atomic overwrite failed')
    fs:writeAtomic('unicode/arquivo-ação-🎨.txt','conteúdo')
    check(fs:read('unicode/arquivo-ação-🎨.txt')=='conteúdo','wide filename I/O')
    local store=Store.open(rootPath)
    local parent=store:createFolder('Estudos de cor 🎨','')
    local child=store:createFolder('Ação / 形',parent)
    check(#store:folders('')==1 and store:folders(parent)[1].id==child,'folder hierarchy')
    -- Artwork and folder reordering is an index-only transaction.
    local orderedA=store:createProject('Order A',2,2,'',
        string.rep(string.char(3,5,7,255),4))
    local orderedB=store:createProject('Order B',2,2,'',
        string.rep(string.char(4,6,8,255),4))
    local imageA=fs:read('projects/'..orderedA.id..'.rbd')
    local imageB=fs:read('projects/'..orderedB.id..'.rbd')
    local originalOrder=store:galleryItems('')
    check(#originalOrder==3 and originalOrder[1].key=='f:'..parent,
        'Initial mixed gallery order changed')
    check(store:reorderGallery('','p:'..orderedB.id,'f:'..parent),
        'Mixed drag did not reorder')
    check(store:galleryItems('')[1].key=='p:'..orderedB.id,
        'Artwork failed to move before folder')
    local reopened=Store.open(rootPath):galleryItems('')
    check(reopened[1].key=='p:'..orderedB.id and
        reopened[2].key=='f:'..parent,
        'Reorder did not survive reopen')
    check(fs:read('projects/'..orderedA.id..'.rbd')==imageA and
        fs:read('projects/'..orderedB.id..'.rbd')==imageB,
        'Reordering rewrote original RBD data')
    rejects(function()
        store:reorderGallery('','p:'..orderedA.id,'p:p_missing')
    end,'Unknown drop target accepted')
    rejects(function()
        store:reorderGallery(parent,'p:'..orderedA.id,
            'p:'..orderedB.id)
    end,'Cross-folder reorder accepted')
    check(not store:reorderGallery('','p:'..orderedB.id,
        'p:'..orderedB.id),'Self-drop changed order')
    local storedOrder=fs:read('gallery-order.json')
    local oldAtomic=store.fs.writeAtomic
    store.fs.writeAtomic=function(self,path,data)
        if path=='gallery-order.json' then error('disk full') end
        return oldAtomic(self,path,data)
    end
    rejects(function()
        store:reorderGallery('','f:'..parent,'p:'..orderedA.id)
    end,'Failed gallery order write was accepted')
    store.fs.writeAtomic=oldAtomic
    check(fs:read('gallery-order.json')==storedOrder and
        store:galleryItems('')[1].key=='p:'..orderedB.id,
        'Failed index write mutated gallery order')
    -- Preserve other tests that need a single project in the child
    -- folder: these dedicated reorder fixtures remain at gallery root.

    rejects(function() store:createFolder('Estudos de cor 🎨','') end,'duplicate folder accepted')
    rejects(function() store:createFolder('Nope','f_missing') end,'missing parent accepted')
    local pixels=string.char(255,0,0,255,0,255,0,128,0,0,255,64,10,20,30,0)
    local doc=store:createProject('Tela α – teste',2,2,child,pixels)
    check(doc.revision==1 and doc.width==2 and doc.height==2,'new project metadata')
    local reopened=Store.open(rootPath):openProject(doc.id)
    check(reopened.name==doc.name and reopened.folder==child and reopened.pixels==pixels,'pixel-exact persisted project')
    check(#store:listProjects(child)==1 and #store:listProjects(parent)==0,'project folder membership')
    doc.pixels=string.rep(string.char(4,5,6,7),4); store:saveProject(doc)
    check(doc.revision==2 and store:openProject(doc.id).pixels==doc.pixels,'same-ID save/reopen')
    rejects(function() store:saveProject(reopened) end,'stale revision overwrote project')
    check(store:openProject(doc.id).revision==2,'failed stale save changed revision')
    -- RBD1 and RBD2 both move by header, retaining exact raster bytes.
    local originalPixels=doc.pixels
    local layered=store:createProject('Camadas em movimento',
        2,2,child,pixels)
    layered.layers=JSON.array({{id=store:newLayerId(),name='Base',
        visible=true,opacity=1,pixels=pixels}})
    layered.active_layer=1
    layered.pixels=nil
    store:saveProject(layered)
    local layeredRevision=layered.revision
    local before=fs:read('projects/'..layered.id..'.rbd')
    local stale=store:openProject(doc.id)
    rejects(function()
        store:moveProjects({doc.id,doc.id},parent,child)
    end,'Duplicate project IDs accepted for move')
    rejects(function()
        store:moveProjects({doc.id,'p_does_not_exist'},parent,child)
    end,'Missing project was accepted in move preflight')
    rejects(function()
        store:moveProjects({doc.id},child,child)
    end,'Move accepted same source and destination')
    rejects(function()
        store:moveProjects({doc.id},'f_missing',child)
    end,'Move accepted nonexistent destination folder')
    check(store:openProject(doc.id).folder==child and
        store:openProject(layered.id).folder==child,
        'Failed move validation changed folder membership')
    local moved=store:moveProjects({doc.id,layered.id},parent,child)
    check(moved.moved==2 and moved.total==2 and not moved.error,
        'RBD1 and RBD2 batch movement failed')
    local reopenedOld=Store.open(rootPath):openProject(doc.id)
    local reopenedLayered=Store.open(rootPath):openProject(layered.id)
    check(reopenedOld.folder==parent and
        reopenedOld.pixels==originalPixels and
        reopenedOld.revision==3,'Moved RBD1 lost pixels/revision')
    check(reopenedLayered.folder==parent and
        reopenedLayered.format==2 and
        reopenedLayered.revision==layeredRevision+1 and
        #reopenedLayered.layers==1 and
        reopenedLayered.layers[1].pixels==pixels,
        'Moved RBD2 lost layer metadata or pixels')
    check(#store:listProjects(child)==0 and
        #store:listProjects(parent)==2,
        'Move changed wrong folder listing')
    check(fs:read('projects/'..layered.id..'.rbd')~=before,
        'Layered project header did not update after move')
    rejects(function()store:saveProject(stale)end,
        'Stale editor session overwrote a moved project')
    -- Simulate a later batch I/O failure: report partial success,
    -- never silently report all files moved.
    local extra=store:createProject('Parcial A',2,2,child,pixels)
    local last=store:createProject('Parcial B',2,2,child,pixels)
    local writeAtomic=store.fs.writeAtomic
    local writes=0
    store.fs.writeAtomic=function(self,path,data)
        if path:match('^projects/') then
            writes=writes+1
            if writes==2 then error('simulated disk failure') end
        end
        return writeAtomic(self,path,data)
    end
    local partial=store:moveProjects({extra.id,last.id},parent,child)
    store.fs.writeAtomic=writeAtomic
    check(partial.moved==1 and partial.total==2
        and partial.ids[1]==extra.id and partial.failedId==last.id
        and type(partial.error)=='string',
        'Partial batch failure not reported')
    check(store:openProject(extra.id).folder==parent
        and store:openProject(last.id).folder==child,
        'Batch I/O failure corrupted unaffected file')
    local retry=store:moveProjects({last.id},parent,child)
    check(retry.moved==1 and store:openProject(last.id).folder==parent,
        'Failed move cannot be retried safely')
    -- Return original fixture to child for following corruption tests.
    doc=store:openProject(doc.id)
    store:moveProjects({doc.id},child,parent)
    doc=store:openProject(doc.id)
    check(doc.pixels==originalPixels and doc.folder==child,
        'RBD1 restoration after move failed')
    local invalidFolder={id=doc.id,name=doc.name,width=2,height=2,pixels=doc.pixels,revision=doc.revision}
    rejects(function() store:saveProject(invalidFolder) end,'missing folder wrote unreadable document')
    check(store:openProject(doc.id).revision==doc.revision,
        'invalid metadata changed project')
    rejects(function() store:createProject('Too wide',2049,1,'','') end,'oversized dimensions accepted')
    rejects(function() store:createProject('No bytes',1,1,'','') end,'pixel size mismatch accepted')
    rejects(function() store:openProject('../escape') end,'project traversal accepted')
    store:setPreferences({zoom=1.25,pressureEnabled=true,theme='escuro',lastFolder=child})
    check(Store.open(rootPath):getPreferences().lastFolder==child,'preferences roundtrip')
    local brushes=JSON.array({{id='research_default',name='Parâmetro – estudo',thicknessToPressure=-1.25,status='unrendered'}})
    store:saveBrushes(brushes)
    check(Store.open(rootPath):getBrushes()[1].thicknessToPressure==-1.25,'brush library roundtrip')
    rejects(function() store:saveBrushes({{id='bad',name='Bad',thicknessToPressure=2.01}}) end,'invalid observed setter range persisted')
    check(store:getBrushes()[1].id=='research_default','failed brush write altered library')
    -- v14.1 recoverable deletion: atomic journal only, never RBD file loss.
    local recoverable=store:createProject('Recuperar RBD1',2,2,
        child,pixels)
    local layeredDeleted=store:createProject('Recuperar RBD2',
        2,2,child,pixels)
    layeredDeleted.layers=JSON.array({
        {id=store:newLayerId(),name='Overlay',
            visible=true,opacity=.65,pixels=pixels}})
    layeredDeleted.active_layer=1
    layeredDeleted.pixels=nil
    store:saveProject(layeredDeleted)
    local imageA=fs:read('projects/'..recoverable.id..'.rbd')
    local imageB=fs:read('projects/'..layeredDeleted.id..'.rbd')
    local baseline=#store:listProjects(child)
    rejects(function()store:deleteProjects(
        {recoverable.id,recoverable.id},child)end,
        'Duplicate deletion accepted')
    rejects(function()store:deleteProjects(
        {recoverable.id,'p_not_found'},child)end,
        'Missing document accepted in deletion preflight')
    rejects(function()store:deleteProjects(
        {recoverable.id},parent)end,
        'Wrong source accepted for deletion')
    check(#store:deletedProjects()==0 and
        #store:listProjects(child)==baseline,
        'Failed preflight modified gallery state')
    local del=store:deleteProjects(
        {recoverable.id,layeredDeleted.id},child)
    check(del.deleted==2 and #store:listProjects(child)==baseline-2,
        'Atomic batch deletion did not hide both projects')
    check(fs:read('projects/'..recoverable.id..'.rbd')==imageA
        and fs:read('projects/'..layeredDeleted.id..'.rbd')==imageB,
        'Deleting project changed original RBD bytes')
    rejects(function()store:openProject(recoverable.id)end,
        'Deleted project still opens in editor')
    rejects(function()store:moveProjects(
        {layeredDeleted.id},parent,child)end,
        'Deleted project accepted in move batch')
    local recordedDeletion=store.deleted.items[1].deleted_at
    local withinWindow=store:deletedProjects(recordedDeletion+86400*29)
    local outsideWindow=store:deletedProjects(recordedDeletion+86400*31)
    check(withinWindow[1].retention_days==1 and
        not withinWindow[1].retention_expired,
        '30-day retention countdown missing')
    check(outsideWindow[1].retention_days==0 and
        outsideWindow[1].retention_expired,
        'Retention end not marked')
    check(fs:read('projects/'..recoverable.id..'.rbd')==imageA
        and fs:read('projects/'..layeredDeleted.id..'.rbd')==imageB,
        'Expiration status unexpectedly deleted RBD bytes')
    local reopenedTrash=Store.open(rootPath)
    check(#reopenedTrash:deletedProjects()==2
        and #reopenedTrash:listProjects(child)==baseline-2,
        'Deleted index not persisted across restart')
    local deletedIndex=fs:read('deleted.json')
    local writeAtomic=store.fs.writeAtomic
    store.fs.writeAtomic=function(self,path,data)
        if path=='deleted.json' then error('disk error in trash') end
        return writeAtomic(self,path,data)
    end
    rejects(function()store:restoreProjects(
        {recoverable.id})end,
        'Write failure during restore not reported')
    store.fs.writeAtomic=writeAtomic
    check(fs:read('deleted.json')==deletedIndex
        and #store:deletedProjects()==2,
        'Failed recovery altered deletion index')
    local restored=store:restoreProjects(
        {recoverable.id,layeredDeleted.id})
    check(restored.restored==2 and
        #store:listProjects(child)==baseline,
        'Recover did not restore source gallery')
    check(fs:read('projects/'..recoverable.id..'.rbd')==imageA
        and fs:read('projects/'..layeredDeleted.id..'.rbd')==imageB,
        'Recover changed RBD bytes')
    check(#Store.open(rootPath):deletedProjects()==0
        and Store.open(rootPath):openProject(
            layeredDeleted.id).layers[1].opacity==.65,
        'Recovery not persisted or lost layer properties')
    -- Keep the legacy corruption fixture isolated to its sole document.
    local archived=store:moveProjects(
        {recoverable.id,layeredDeleted.id},parent,child)
    check(archived.moved==2,'Recovery fixtures not archived')
    local goodPath='projects/'..doc.id..'.rbd'; local original=fs:read(goodPath)
    fs:writeAtomic(goodPath,original:sub(1,-2))
    rejects(function() store:openProject(doc.id) end,'truncated document accepted')
    check(fs:read(goodPath)==original:sub(1,-2),'corrupt read mutated file')
    local rows,errors=store:listProjects(child)
    check(#rows==0 and #errors==1,'corrupt document was not reported separately')
    fs:writeAtomic(goodPath,original)
    local prefix=original:sub(1,8)..string.char(255,255,255,127)
    fs:writeAtomic(goodPath,prefix..original:sub(13))
    rejects(function() store:openProject(doc.id) end,'oversized header accepted')
    fs:writeAtomic(goodPath,original)
    check(store:openProject(doc.id).pixels==doc.pixels,'restored document unreadable')
    fs:writeAtomic(goodPath,original..'trailing')
    rejects(function() store:openProject(doc.id) end,'extra payload accepted')
    fs:writeAtomic(goodPath,original)
    return {suite='storage',passed=true,assertions=assertions,root=rootPath,project=doc.id,scope='Independent portable persistence; no Android runtime equivalence claimed'}
end
return Test
