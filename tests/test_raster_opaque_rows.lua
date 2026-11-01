-- Comparacao independente com a formula source-over anterior.
-- Inclui linhas 100% opacas, misturadas e com RGB oculto sob alfa zero.
package.path='app/?.lua;'..package.path
local R=require('raster_lua')
local floor=math.floor
local W,H=47,29
local rects={{x=0,y=0,w=W,h=H},{x=3,y=2,w=17,h=12},
    {x=0,y=H-1,w=W,h=1},{x=W-1,y=0,w=1,h=H}}
local function reference(dst,src,opacity,rect)
    for y=rect.y,rect.y+rect.h-1 do
        for x=rect.x,rect.x+rect.w-1 do
            local p=(y*W+x)*4
            local sa=(src.bytes[p+3]/255)*opacity
            local da=dst.bytes[p+3]/255
            local oa=sa+da*(1-sa)
            if oa>0 then
                for k=0,2 do
                    local value=(src.bytes[p+k]*sa
                        +dst.bytes[p+k]*da*(1-sa))/oa
                    dst.bytes[p+k]=floor(value+0.5)
                end
            else
                dst.bytes[p],dst.bytes[p+1],dst.bytes[p+2]=0,0,0
            end
            dst.bytes[p+3]=floor(oa*255+0.5)
        end
    end
end
local function scene(layer,seed)
    local buffer=R.buffer(W,H)
    for y=0,H-1 do
        for x=0,W-1 do
            local i=(y*W+x+seed*11)
            local mode=(y+layer)%5
            local alpha
            if mode==0 then alpha=255
            elseif mode==1 then alpha=0
            elseif mode==2 then alpha=(x%2==0) and 255 or 0
            elseif mode==3 then alpha=({1,127,254,255})[(i%4)+1]
            else alpha=(i*13)%256 end
            local r=(i*31)%256
            local g=(i*43)%256
            local b=(i*67)%256
            R.pixel(buffer,x,y,r*16777216+g*65536+b*256+alpha)
        end
    end
    return buffer
end
local layers={}
for n=1,8 do layers[n]=scene(n,n+2) end
local base=scene(0,17)
local cases=0
for _,rect in ipairs(rects) do
    for _,opacity in ipairs({0,0.25,0.75,1}) do
        local got=R.buffer(W,H,R.bytes(base))
        local expected=R.buffer(W,H,R.bytes(base))
        local snapshot=R.bytes(layers[1])
        R.compositeRect(got,layers[1],opacity,rect)
        reference(expected,layers[1],opacity,rect)
        assert(R.bytes(got)==R.bytes(expected),
            ('RGBA mismatch: rect %dx%d opacity %.2f'):format(rect.w,rect.h,opacity))
        assert(R.bytes(layers[1])==snapshot,'Source was modified')
        cases=cases+1
    end
end
-- Ordem e arredondamento sao importantes em multiplas camadas.
for _,number in ipairs({2,4,8}) do
    for _,rect in ipairs(rects) do
        local got=R.buffer(W,H,R.bytes(base))
        local expected=R.buffer(W,H,R.bytes(base))
        for i=1,number do
            local opacity=(i%3==1) and 1 or ((i%3==2) and .3 or .85)
            R.compositeRect(got,layers[i],opacity,rect)
            reference(expected,layers[i],opacity,rect)
        end
        assert(R.bytes(got)==R.bytes(expected),
            ('Multi-layer RGBA mismatch: %d layers %dx%d'):format(number,rect.w,rect.h))
        cases=cases+1
    end
end
local first=R.buffer(7,3)
local second=R.buffer(7,3)
R.clear(first,0x245610ff)
R.clear(second,0x72c3faff)
R.composite(first,second,1)
assert(R.bytes(first)==R.bytes(second),'Opaque full layer copy differs')
local normal=R.buffer(3,2)
local clear=R.buffer(3,2)
R.clear(normal,0xaabbcc00)
R.clear(clear,0x77777700)
R.composite(normal,clear,1)
assert(R.readPixel(normal,0,0)==0,'Transparent hidden RGB not cleared')
print(('RGBA opaque-row compositor: %d reference comparisons, 2/4/8 layers: OK'):format(cases))
