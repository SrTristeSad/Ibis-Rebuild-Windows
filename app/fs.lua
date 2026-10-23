-- Windows-wide filesystem adapter, confined to an explicit portable data root.
local ffi=require('ffi')
local bit=require('bit')
ffi.cdef[[
typedef struct { unsigned long low, high; } RBFS_FILETIME;
typedef struct {
 unsigned long attributes; RBFS_FILETIME creation, access, write;
 unsigned long sizeHigh,sizeLow,reserved0,reserved1;
 unsigned short name[260], alternateName[14];
} RBFS_FIND_DATAW;
int MultiByteToWideChar(unsigned int,unsigned long,const char*,int,unsigned short*,int);
int WideCharToMultiByte(unsigned int,unsigned long,const unsigned short*,int,char*,int,const char*,int*);
unsigned long GetLastError(void);
unsigned long GetCurrentProcessId(void);
unsigned long GetFileAttributesW(const unsigned short*);
int CreateDirectoryW(const unsigned short*,void*);
void* CreateFileW(const unsigned short*,unsigned long,unsigned long,void*,unsigned long,unsigned long,void*);
int CloseHandle(void*);
int GetFileSizeEx(void*,long long*);
int SetFilePointerEx(void*,long long,long long*,unsigned long);
int ReadFile(void*,void*,unsigned long,unsigned long*,void*);
int WriteFile(void*,const void*,unsigned long,unsigned long*,void*);
int FlushFileBuffers(void*);
int MoveFileExW(const unsigned short*,const unsigned short*,unsigned long);
int DeleteFileW(const unsigned short*);
void* FindFirstFileW(const unsigned short*,RBFS_FIND_DATAW*);
int FindNextFileW(void*,RBFS_FIND_DATAW*);
int FindClose(void*);
]]
local C=ffi.load('kernel32')
local FS={}; FS.__index=FS
local invalid=ffi.cast('void*',-1)
local counter=0
local function fail(label) error(label..' (Windows '..tonumber(C.GetLastError())..')',3) end
local function wide(s)
    assert(type(s)=='string' and not s:find('\0',1,true),'filesystem: invalid string')
    local n=C.MultiByteToWideChar(65001,8,s,#s,nil,0)
    assert(n>0,'filesystem: invalid UTF-8 path')
    local b=ffi.new('unsigned short[?]',n+1)
    assert(C.MultiByteToWideChar(65001,8,s,#s,b,n)==n,'filesystem: path conversion failed')
    return b
end
local function utf8(w)
    local n=0; while w[n]~=0 do n=n+1 end
    if n==0 then return '' end
    local z=C.WideCharToMultiByte(65001,0,w,n,nil,0,nil,nil); assert(z>0,'filesystem: invalid UTF-16 name')
    local b=ffi.new('char[?]',z); C.WideCharToMultiByte(65001,0,w,n,b,z,nil,nil); return ffi.string(b,z)
end
local function components(path)
    assert(type(path)=='string' and not path:find('[%z\1-\31:]'),'filesystem: invalid relative path')
    assert(not path:match('^[\\/]'),'filesystem: absolute child path rejected')
    local out={}
    for part in path:gmatch('[^\\/]+') do
        assert(part~='.' and part~='..' and not part:match('[ .]$'),'filesystem: traversal or ambiguous name rejected')
        assert(not part:find('[<>"|?*]'),'filesystem: invalid filename')
        local stem=part:match('^[^.]+'):upper()
        assert(stem~='CON' and stem~='PRN' and stem~='AUX' and stem~='NUL' and not stem:match('^COM[1-9]$') and not stem:match('^LPT[1-9]$'),'filesystem: reserved filename')
        out[#out+1]=part
    end
    return out
end
local function attrs(path)
    local a=tonumber(C.GetFileAttributesW(wide(path)))
    if a==4294967295 then
        local e=tonumber(C.GetLastError()); if e==2 or e==3 then return nil end; fail('filesystem: attributes failed')
    end
    assert(bit.band(a,1024)==0,'filesystem: reparse points are not allowed')
    return a
end
local function mkdirAbsolute(path)
    local drive,tail=path:match('^([A-Za-z]:)\\(.*)$'); assert(drive,'filesystem: absolute drive path required')
    local current=drive..'\\'
    for part in tail:gmatch('[^\\]+') do
        current=current:gsub('\\$','')..'\\'..part
        local a=attrs(current)
        if not a then if C.CreateDirectoryW(wide(current),nil)==0 then fail('filesystem: create directory failed') end
        else assert(bit.band(a,16)~=0,'filesystem: directory expected') end
    end
end
function FS.new(root)
    assert(type(root)=='string' and root:match('^[A-Za-z]:[\\/]'),'filesystem: root must be absolute')
    root=root:gsub('/','\\'):gsub('\\+$','')
    local drive=root:sub(1,2); local tail=root:sub(4); components(tail)
    root=drive..'\\'..table.concat(components(tail),'\\')
    mkdirAbsolute(root)
    return setmetatable({root=root},FS)
end
function FS:absolute(relative)
    local parts=components(relative or ''); local current=self.root
    for i,part in ipairs(parts) do
        current=current..'\\'..part
        local a=attrs(current); if a and i<#parts then assert(bit.band(a,16)~=0,'filesystem: parent is not a directory') end
    end
    return current
end
function FS:join(relative) return self:absolute(relative) end
function FS:mkdir(relative)
    local path=self:absolute(relative); mkdirAbsolute(path); return path
end
function FS:exists(relative) return attrs(self:absolute(relative))~=nil end
local function openRead(path)
    local h=C.CreateFileW(wide(path),2147483648,1,nil,3,128,nil)
    if h==invalid then fail('filesystem: open read failed') end; return h
end
local function withRead(path, fn)
    local h=openRead(path); local result={pcall(fn,h)}; C.CloseHandle(h)
    if not result[1] then error(result[2],2) end; return unpack(result,2)
end
local function fileSize(h)
    local n=ffi.new('long long[1]'); if C.GetFileSizeEx(h,n)==0 then fail('filesystem: file size failed') end
    local size=tonumber(n[0]); assert(size>=0 and size<=9007199254740991,'filesystem: invalid file size'); return size
end
function FS:size(relative) return withRead(self:absolute(relative),fileSize) end
function FS:readRange(relative,offset,count,maxFileBytes)
    assert(type(offset)=='number' and offset>=0 and offset%1==0 and type(count)=='number' and count>=0 and count%1==0 and count<=67108864,'filesystem: invalid range')
    return withRead(self:absolute(relative),function(h)
        local size=fileSize(h); assert(size<=(maxFileBytes or 67108864),'filesystem: file size limit')
        assert(offset<=size and count<=size-offset,'filesystem: truncated file')
        if count==0 then return '' end
        if C.SetFilePointerEx(h,offset,nil,0)==0 then fail('filesystem: seek failed') end
        local b=ffi.new('unsigned char[?]',count); local got=ffi.new('unsigned long[1]')
        if C.ReadFile(h,b,count,got,nil)==0 then fail('filesystem: read failed') end
        assert(tonumber(got[0])==count,'filesystem: truncated read'); return ffi.string(b,count)
    end)
end
function FS:read(relative,maxBytes)
    local size=self:size(relative); assert(size<=(maxBytes or 67108864),'filesystem: file size limit')
    return self:readRange(relative,0,size,maxBytes)
end
function FS:writeAtomic(relative,data)
    assert(type(data)=='string' and #data<=67108864,'filesystem: invalid or oversized write')
    local parts=components(relative); assert(#parts>0,'filesystem: filename required')
    if #parts>1 then local parent={}; for i=1,#parts-1 do parent[i]=parts[i] end; self:mkdir(table.concat(parent,'/')) end
    local target=self:absolute(relative)
    counter=counter+1
    local temporary=relative..string.format('.tmp-%08x-%08x',tonumber(C.GetCurrentProcessId()),counter)
    local tempPath=self:absolute(temporary)
    local h=C.CreateFileW(wide(tempPath),1073741824,0,nil,1,128,nil)
    if h==invalid then fail('filesystem: open atomic temporary failed') end
    local ok,err=pcall(function()
        local wrote=ffi.new('unsigned long[1]')
        if #data>0 and (C.WriteFile(h,data,#data,wrote,nil)==0 or tonumber(wrote[0])~=#data) then fail('filesystem: write failed') end
        if C.FlushFileBuffers(h)==0 then fail('filesystem: flush failed') end
    end)
    C.CloseHandle(h)
    if not ok then C.DeleteFileW(wide(tempPath)); error(err,2) end
    if C.MoveFileExW(wide(tempPath),wide(target),9)==0 then
        local code=tonumber(C.GetLastError()); C.DeleteFileW(wide(tempPath)); error('filesystem: atomic replacement failed (Windows '..code..')',2)
    end
    return true
end
function FS:list(relative)
    local base=self:absolute(relative or ''); local a=attrs(base); assert(a and bit.band(a,16)~=0,'filesystem: directory does not exist')
    local data=ffi.new('RBFS_FIND_DATAW[1]'); local h=C.FindFirstFileW(wide(base..'\\*'),data)
    if h==invalid then local e=tonumber(C.GetLastError()); if e==2 then return {} end; fail('filesystem: list failed') end
    local rows={}; local ok,err=pcall(function()
        repeat
            local name=utf8(data[0].name); local flags=tonumber(data[0].attributes)
            if name~='.' and name~='..' and bit.band(flags,1024)==0 then
                rows[#rows+1]={name=name,isDirectory=bit.band(flags,16)~=0,bytes=tonumber(data[0].sizeHigh)*4294967296+tonumber(data[0].sizeLow)}
            end
            local more=C.FindNextFileW(h,data)
            if more==0 then assert(tonumber(C.GetLastError())==18,'filesystem: list failed'); break end
        until false
    end)
    C.FindClose(h); if not ok then error(err,2) end
    table.sort(rows,function(x,y)return x.name<y.name end); return rows
end
function FS:delete(relative)
    local path=self:absolute(relative); local a=attrs(path); if not a then return false end
    assert(bit.band(a,16)==0,'filesystem: recursive deletion is not supported')
    if C.DeleteFileW(wide(path))==0 then fail('filesystem: delete failed') end; return true
end
function FS.processId() return tonumber(C.GetCurrentProcessId()) end
return FS
