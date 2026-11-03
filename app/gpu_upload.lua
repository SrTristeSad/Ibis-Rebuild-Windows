-- Upload de regioes RGBA8 para o Image do LOVE 11.5 em LuaJIT.
-- Evita string RGBA temporaria e reutiliza ImageData de tamanhos repetidos.
-- O ponteiro FFI nao sobrevive ao ImageData que o possui.
local ffi=require('ffi')
local Upload={}
Upload.__index=Upload

local function integer(n)
    return type(n)=='number' and n==n and n%1==0
end
local function checked(source,rect,image)
    assert(type(source)=='table' and source.bytes and
        integer(source.width) and integer(source.height) and
        source.width>0 and source.height>0 and
        source.size==source.width*source.height*4,
        'Buffer RGBA de upload invalido')
    assert(type(rect)=='table' and integer(rect.x) and
        integer(rect.y) and integer(rect.w) and integer(rect.h) and
        rect.x>=0 and rect.y>=0 and rect.w>0 and rect.h>0 and
        rect.x+rect.w<=source.width and
        rect.y+rect.h<=source.height,'Regiao de upload invalida')
    assert(image and type(image.replacePixels)=='function' and
        image:getWidth()==source.width and
        image:getHeight()==source.height,'Image GPU nao corresponde ao canvas')
end

function Upload.new(options)
    options=options or {}
    local entries=options.maxEntries or 4
    local bytes=options.maxCacheBytes or 1024*1024
    assert(integer(entries) and entries>=1 and entries<=32,
        'Limite de entradas de upload invalido')
    assert(integer(bytes) and bytes>=4 and bytes<=32*1024*1024,
        'Limite de memoria de upload invalido')
    return setmetatable({
        slots={},maxEntries=entries,maxCacheBytes=bytes,
        cacheBytes=0,clock=0,uploads=0,allocations=0,
        hits=0,evictions=0,copiedBytes=0
    },Upload)
end

function Upload:clear()
    for _,entry in ipairs(self.slots) do entry.data:release() end
    self.slots={}
    self.cacheBytes=0
end

local function create(w,h)
    local size=w*h*4
    local data=love.image.newImageData(w,h,'rgba8')
    local ok,ptr=pcall(function() return data:getFFIPointer() end)
    if not ok or ptr==nil then
        data:release()
        error('LOVE ImageData:getFFIPointer indisponivel')
    end
    if data:getSize()~=size then
        data:release()
        error('ImageData deve ser RGBA8 contiguo')
    end
    return {w=w,h=h,size=size,data=data,
        pointer=ffi.cast('uint8_t*',ptr)}
end

local function evictOldest(self)
    local oldest,index
    for i,entry in ipairs(self.slots) do
        if not oldest or entry.lastUsed<oldest then
            oldest=entry.lastUsed;index=i
        end
    end
    if not index then return end
    local entry=table.remove(self.slots,index)
    self.cacheBytes=self.cacheBytes-entry.size
    self.evictions=self.evictions+1
    entry.data:release()
end

function Upload:_acquire(w,h)
    self.clock=self.clock+1
    for _,entry in ipairs(self.slots) do
        if entry.w==w and entry.h==h then
            entry.lastUsed=self.clock
            self.hits=self.hits+1
            return entry,false
        end
    end
    local entry=create(w,h)
    entry.lastUsed=self.clock
    self.allocations=self.allocations+1
    if entry.size>self.maxCacheBytes then
        return entry,true -- imagem temporaria; liberar apos upload
    end
    while #self.slots>=self.maxEntries or
        self.cacheBytes+entry.size>self.maxCacheBytes do
        evictOldest(self)
    end
    self.slots[#self.slots+1]=entry
    self.cacheBytes=self.cacheBytes+entry.size
    return entry,false
end

function Upload:send(image,source,rect)
    checked(source,rect,image) -- falhas de validacao nao alteram o cache
    local entry,temporary=self:_acquire(rect.w,rect.h)
    local ok,err=pcall(function()
        local stride=rect.w*4
        for y=0,rect.h-1 do
            ffi.copy(entry.pointer+y*stride,
                source.bytes+((rect.y+y)*source.width+rect.x)*4,
                stride)
        end
        -- O LOVE copia os pixels para a textura neste metodo.
        -- A origem ImageData continua viva ate o fim de replacePixels.
        image:replacePixels(entry.data,nil,1,rect.x,rect.y)
    end)
    if temporary then entry.data:release() end
    if not ok then error(err,0) end
    self.uploads=self.uploads+1
    self.copiedBytes=self.copiedBytes+rect.w*rect.h*4
    return true
end

function Upload:stats()
    return {uploads=self.uploads,allocations=self.allocations,
        hits=self.hits,evictions=self.evictions,
        cachedEntries=#self.slots,cacheBytes=self.cacheBytes,
        copiedBytes=self.copiedBytes}
end

return Upload
