package.path='app/?.lua;'..package.path
local ffi=require('ffi')
local Raster=require('raster_lua')
local Upload=require('gpu_upload')

-- Stand-in deterministico de LÖVE ImageData; compara os bytes de upload
-- contra Raster.regionBytes, sem simular resultados de desempenho de GPU.
local oldLove=rawget(_G,'love')
local allocated,released,live=0,0,0
local fakeLove={image={}}
function fakeLove.image.newImageData(w,h,format)
    assert(format=='rgba8')
    allocated=allocated+1
    live=live+1
    local storage=ffi.new('uint8_t[?]',w*h*4)
    local obj={width=w,height=h,released=false,bytes=w*h*4,
        storage=storage}
    function obj:getFFIPointer()
        assert(not self.released)
        return ffi.cast('void*',self.storage)
    end
    function obj:getSize() return self.bytes end
    function obj:release()
        assert(not self.released,'ImageData liberado duas vezes')
        self.released=true
        released=released+1
        live=live-1
    end
    return obj
end
_G.love=fakeLove

local w,h=19,12
local source=Raster.buffer(w,h)
for y=0,h-1 do
    for x=0,w-1 do
        local r=(x*13+y*11)%256
        local g=(x*7+y*37)%256
        local b=(x*41+y*19)%256
        local a=(x*29+y*3)%256
        Raster.pixel(source,x,y,r*16777216+g*65536+b*256+a)
    end
end
local original=Raster.bytes(source)
local sends={}
local image={width=w,height=h}
function image:getWidth() return self.width end
function image:getHeight() return self.height end
function image:replacePixels(patch,slice,mip,x,y)
    assert(slice==nil and mip==1)
    assert(not patch.released,'Patch liberado durante replacePixels')
    local got=ffi.string(patch:getFFIPointer(),patch:getSize())
    local expected=Raster.regionBytes(source,
        {x=x,y=y,w=patch.width,h=patch.height})
    assert(got==expected,'Upload GPU continha linhas fora de ordem')
    sends[#sends+1]={x=x,y=y,w=patch.width,h=patch.height,bytes=got}
end

local uploader=Upload.new({maxEntries=2,maxCacheBytes=200})
local a={x=0,y=0,w=5,h=4}
local b={x=11,y=6,w=5,h=4}
local c={x=8,y=1,w=6,h=5}
assert(uploader:send(image,source,a))
assert(uploader:send(image,source,b))
local stats=uploader:stats()
assert(stats.allocations==1 and stats.hits==1 and stats.uploads==2)
assert(stats.cachedEntries==1 and stats.cacheBytes==80)
assert(uploader:send(image,source,c))
assert(uploader:stats().cachedEntries==2 and allocated==2)
assert(uploader:send(image,source,a))
assert(uploader:stats().hits==2)
local d={x=1,y=2,w=4,h=3}
assert(uploader:send(image,source,d))
stats=uploader:stats()
assert(stats.evictions==1 and stats.cachedEntries==2)
assert(stats.cacheBytes==80+48 and released==1)
assert(uploader:send(image,source,{x=0,y=0,w=11,h=5}))
stats=uploader:stats()
assert(stats.allocations==4 and stats.cachedEntries==2)
assert(released==2 and stats.cacheBytes==128,
    'Patch maior que limite nao pode ficar retido')
assert(Raster.bytes(source)==original,'Upload alterou fonte raster')

local before=uploader:stats().uploads
local function invalid(rect,wrongImage)
    assert(not pcall(function()
        uploader:send(wrongImage or image,source,rect)
    end),'Regiao invalida foi aceita')
    assert(uploader:stats().uploads==before,
        'Upload parcial na falha de validacao')
end
invalid({x=-1,y=0,w=1,h=2})
invalid({x=0,y=0,w=20,h=1})
invalid({x=0,y=1,w=0,h=1})
invalid({x=0,y=1,w=1.5,h=1})
invalid({x=1,y=0,w=1,h=1},
    {getWidth=function()return 4 end,getHeight=function()return h end,
    replacePixels=image.replacePixels})
local savedCounts=uploader:stats().uploads
local failure={width=w,height=h}
function failure:getWidth()return self.width end
function failure:getHeight()return self.height end
function failure:replacePixels() error('GPU falhou intencionalmente') end
assert(not pcall(uploader.send,uploader,failure,source,a))
assert(uploader:stats().uploads==savedCounts)
assert(uploader:send(image,source,a),
    'Upload nao se recuperou depois de falha de GPU')
assert(uploader:stats().uploads==savedCounts+1)

uploader:clear()
assert(live==0 and released==allocated,'Vazamento de ImageData')
assert(uploader:stats().cachedEntries==0 and uploader:stats().cacheBytes==0)
assert(#sends==7,'Contagem incorreta de uploads')
_G.love=oldLove
print('GPU upload Lua: RGBA, reuse, LRU, fallback, validation and release OK')
