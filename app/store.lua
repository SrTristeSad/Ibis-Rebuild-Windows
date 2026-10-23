-- Editable research document storage. This is deliberately not an IPV encoder.
local JSON=require('json')
local FS=require('fs')
local Store={}; Store.__index=Store
local MAGIC='RBD1\r\n\26\n'
local HEADER_LIMIT=65536
local MAX_AXIS=2048
local MAX_PROJECT_BYTES=12+HEADER_LIMIT+MAX_AXIS*MAX_AXIS*4
local serial=0
local function integer(n,lo,hi)
    return type(n)=='number' and JSON.finite(n) and n%1==0 and n>=lo and n<=hi
end
local function textName(name)
    assert(type(name)=='string' and #name>=1 and #name<=240 and JSON.validUTF8(name),'store: name must be 1..240 valid UTF-8 bytes')
    assert(not name:find('[%z\1-\31]') and name:match('%S'),'store: empty/control name')
    return name
end
local function validId(id,prefix)
    assert(type(id)=='string' and #id<=80 and id:match('^'..prefix..'_[A-Za-z0-9_%-]+$'),'store: invalid '..prefix..' identifier')
    return id
end
local function dimensions(w,h)
    assert(integer(w,1,MAX_AXIS) and integer(h,1,MAX_AXIS),'store: dimensions outside engineering limit 1..2048')
    return w*h*4
end
local function le32(n)
    return string.char(n%256,math.floor(n/256)%256,math.floor(n/65536)%256,math.floor(n/16777216)%256)
end
local function from32(s)
    assert(#s==4,'store: truncated length'); local a,b,c,d=s:byte(1,4); return a+b*256+c*65536+d*16777216
end
local function clone(value) return JSON.decode(JSON.encode(value)) end
local function object(t)
    assert(type(t)=='table' and t~=JSON.null,'store: object required')
    for key in pairs(t) do assert(type(key)=='string','store: object keys must be strings') end
    return t
end
local function array(t)
    assert(type(t)=='table' and t~=JSON.null,'store: array required')
    local n=0; for k in pairs(t) do assert(integer(k,1,65536),'store: invalid array key'); n=n+1 end
    assert(n==#t,'store: sparse array'); return t
end
function Store.open(rootPath)
    local self=setmetatable({fs=FS.new(rootPath),lastErrors={}},Store)
    self.root=self.fs.root; self.fs:mkdir('projects'); self.fs:mkdir('exports')
    if self.fs:exists('catalog.json') then
        self.catalog=JSON.decode(self.fs:read('catalog.json',1048576))
        object(self.catalog); assert(self.catalog.version==1,'store: unsupported catalog version')
        array(self.catalog.folders)
    else self.catalog={version=1,folders=JSON.array()} end
    local map={}
    for _,folder in ipairs(self.catalog.folders) do
        object(folder); validId(folder.id,'f'); textName(folder.name)
        assert(not map[folder.id],'store: duplicate folder id'); map[folder.id]=folder
        assert(type(folder.parent)=='string','store: invalid folder parent')
        if folder.parent~='' then validId(folder.parent,'f') end
    end
    for _,folder in ipairs(self.catalog.folders) do
        local seen={}; local cur=folder
        while cur.parent~='' do
            assert(not seen[cur.id],'store: folder cycle'); seen[cur.id]=true
            cur=assert(map[cur.parent],'store: missing folder parent')
        end
    end
    if not self.fs:exists('catalog.json') then self.fs:writeAtomic('catalog.json',JSON.encode(self.catalog)) end
    if not self.fs:exists('preferences.json') then self.fs:writeAtomic('preferences.json',JSON.encode({version=1,values={}})) end
    if not self.fs:exists('brushes.json') then self.fs:writeAtomic('brushes.json',JSON.encode({version=1,items=JSON.array()})) end
    return self
end
function Store:_folder(id)
    id=id or ''; if id=='' then return '' end; validId(id,'f')
    for _,f in ipairs(self.catalog.folders) do if f.id==id then return id end end
    error('store: folder does not exist',2)
end
function Store:_id(prefix)
    for _=1,100 do
        serial=serial+1
        local id=string.format('%s_%08x_%08x_%08x',prefix,os.time(),FS.processId(),serial)
        local found=false
        if prefix=='p' then found=self.fs:exists('projects/'..id..'.rbd')
        else for _,f in ipairs(self.catalog.folders) do if f.id==id then found=true; break end end end
        if not found then return id end
    end
    error('store: failed to allocate identifier')
end
function Store:folders(parent)
    parent=self:_folder(parent); local rows={}
    for _,f in ipairs(self.catalog.folders) do if f.parent==parent then rows[#rows+1]={id=f.id,name=f.name,parent=f.parent} end end
    table.sort(rows,function(a,b) if a.name==b.name then return a.id<b.id else return a.name<b.name end end)
    return rows
end
function Store:createFolder(name,parent)
    name=textName(name); parent=self:_folder(parent)
    for _,f in ipairs(self.catalog.folders) do assert(f.parent~=parent or f.name~=name,'store: folder name already exists') end
    local nextCatalog=clone(self.catalog); local id=self:_id('f')
    nextCatalog.folders[#nextCatalog.folders+1]={id=id,name=name,parent=parent}
    self.fs:writeAtomic('catalog.json',JSON.encode(nextCatalog)); self.catalog=nextCatalog
    return id
end
function Store:_path(id) return 'projects/'..validId(id,'p')..'.rbd' end
local function validateHeader(h,id)
    object(h)
    assert(h.version==1 and h.pixel_format=='RGBA8' and h.layer_count==1,'store: unsupported document schema')
    assert(h.id==id,'store: document identifier mismatch'); validId(h.id,'p'); textName(h.name)
    local expected=dimensions(h.width,h.height)
    assert(type(h.folder)=='string','store: invalid document folder'); if h.folder~='' then validId(h.folder,'f') end
    assert(integer(h.revision,1,2147483647),'store: invalid revision')
    assert(integer(h.saved_at,0,9007199254740991),'store: invalid saved timestamp')
    return expected
end
function Store:_readProject(id,withPixels)
    local path=self:_path(id)
    local prefix=self.fs:readRange(path,0,12,MAX_PROJECT_BYTES)
    assert(prefix:sub(1,8)==MAGIC,'store: unsupported document magic')
    local length=from32(prefix:sub(9,12)); assert(length>=2 and length<=HEADER_LIMIT,'store: invalid header length')
    local header=JSON.decode(self.fs:readRange(path,12,length,MAX_PROJECT_BYTES),{maxBytes=HEADER_LIMIT})
    local expected=validateHeader(header,id)
    assert(self.fs:size(path)==12+length+expected,'store: incorrect pixel payload size')
    local doc={id=header.id,name=header.name,width=header.width,height=header.height,folder=header.folder,revision=header.revision,saved_at=header.saved_at}
    if withPixels then doc.pixels=self.fs:readRange(path,12+length,expected,MAX_PROJECT_BYTES) end
    return doc
end
function Store:createProject(name,width,height,folder,rgbaBytes)
    name=textName(name); local expected=dimensions(width,height); folder=self:_folder(folder)
    assert(type(rgbaBytes)=='string' and #rgbaBytes==expected,'store: RGBA byte count mismatch')
    local doc={id=self:_id('p'),name=name,width=width,height=height,folder=folder,pixels=rgbaBytes,revision=0}
    self:saveProject(doc); return doc
end
function Store:saveProject(doc)
    object(doc); local path=self:_path(doc.id); textName(doc.name)
    local expected=dimensions(doc.width,doc.height); assert(type(doc.folder)=='string','store: invalid document folder'); self:_folder(doc.folder)
    assert(type(doc.pixels)=='string' and #doc.pixels==expected,'store: RGBA byte count mismatch')
    assert(integer(doc.revision,0,2147483646),'store: invalid revision')
    if self.fs:exists(path) then
        local old=self:_readProject(doc.id,false)
        assert(old.revision==doc.revision,'store: stale project revision; reopen before saving')
    else assert(doc.revision==0,'store: missing project with nonzero revision') end
    local header={version=1,pixel_format='RGBA8',layer_count=1,id=doc.id,name=doc.name,width=doc.width,height=doc.height,folder=doc.folder,revision=doc.revision+1,saved_at=os.time()}
    local encoded=JSON.encode(header,{maxBytes=HEADER_LIMIT})
    self.fs:writeAtomic(path,MAGIC..le32(#encoded)..encoded..doc.pixels)
    doc.revision=header.revision; doc.saved_at=header.saved_at
    return doc
end
function Store:openProject(id)
    return self:_readProject(id,true)
end
function Store:listProjects(folder)
    folder=self:_folder(folder); local rows,errors={},{}
    for _,entry in ipairs(self.fs:list('projects')) do
        if not entry.isDirectory and entry.name:match('%.rbd$') then
            local id=entry.name:sub(1,-5)
            local ok,doc=pcall(self._readProject,self,id,false)
            if ok then if doc.folder==folder then rows[#rows+1]=doc end
            else errors[#errors+1]={file=entry.name,error=tostring(doc)} end
        end
    end
    table.sort(rows,function(a,b) if a.saved_at==b.saved_at then return a.id<b.id else return a.saved_at>b.saved_at end end)
    self.lastErrors=errors; return rows,errors
end
function Store:setPreferences(values)
    object(values)
    self.fs:writeAtomic('preferences.json',JSON.encode({version=1,values=values})); return true
end
function Store:getPreferences()
    local data=JSON.decode(self.fs:read('preferences.json',1048576)); object(data)
    assert(data.version==1,'store: unsupported preference version'); return object(data.values)
end
local function validateBrushes(items)
    array(items); local ids={}
    for _,b in ipairs(items) do
        object(b); assert(type(b.id)=='string' and #b.id>=1 and #b.id<=80 and b.id:match('^[A-Za-z0-9_%-]+$'),'store: invalid brush identifier')
        assert(not ids[b.id],'store: duplicate brush identifier'); ids[b.id]=true; textName(b.name)
        if b.thicknessToPressure~=nil then assert(type(b.thicknessToPressure)=='number' and JSON.finite(b.thicknessToPressure) and math.abs(b.thicknessToPressure)<=2,'store: brush thicknessToPressure outside observed setter range') end
    end
    return items
end
function Store:saveBrushes(items)
    validateBrushes(items)
    self.fs:writeAtomic('brushes.json',JSON.encode({version=1,items=JSON.array(items)})); return true
end
function Store:getBrushes()
    local data=JSON.decode(self.fs:read('brushes.json',1048576)); object(data)
    assert(data.version==1,'store: unsupported brush library version'); return validateBrushes(data.items)
end
Store.MAX_AXIS=MAX_AXIS
Store.MAGIC=MAGIC
return Store
