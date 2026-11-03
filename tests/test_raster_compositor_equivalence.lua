package.path='app/?.lua;'..package.path
local R=require('raster_lua')
local floor=math.floor

-- Oraculo: formula de composicao usada antes da otimizacao.
-- Mantem o comportamento de RGB transparente e arredondamento RGBA.
local function reference(dst,src,opacity,rect)
    local w=dst.width
    for y=rect.y,rect.y+rect.h-1 do
        for x=rect.x,rect.x+rect.w-1 do
            local p=(y*w+x)*4
            local sa=(src.bytes[p+3]/255)*opacity
            local da=dst.bytes[p+3]/255
            local oa=sa+da*(1-sa)
            if oa>0 then
                for k=0,2 do
                    local v=(src.bytes[p+k]*sa
                        +dst.bytes[p+k]*da*(1-sa))/oa
                    dst.bytes[p+k]=floor(v+0.5)
                end
            else
                dst.bytes[p],dst.bytes[p+1],dst.bytes[p+2]=0,0,0
            end
            dst.bytes[p+3]=floor(oa*255+0.5)
        end
    end
end
local w,h=32,24
local source,destination=R.buffer(w,h),R.buffer(w,h)
local alphas={0,1,35,127,200,254,255}
for y=0,h-1 do
    for x=0,w-1 do
        local i=y*w+x
        local sr=(i*37)%256
        local sg=(i*19)%256
        local sb=(i*61)%256
        local sa=alphas[i%#alphas+1]
        local dr=(i*73)%256
        local dg=(i*17)%256
        local db=(i*53)%256
        local da=alphas[(i+3)%#alphas+1]
        R.pixel(source,x,y,sr*16777216+sg*65536+sb*256+sa)
        R.pixel(destination,x,y,dr*16777216+dg*65536+db*256+da)
    end
end
local whole={x=0,y=0,w=w,h=h}
local region={x=5,y=6,w=13,h=11}
local trials=0
for _,opacity in ipairs({0,0.01,0.25,0.5,0.75,1}) do
    for _,rectangle in ipairs({whole,region}) do
        local actual=R.buffer(w,h,R.bytes(destination))
        local expected=R.buffer(w,h,R.bytes(destination))
        R.compositeRect(actual,source,opacity,rectangle)
        reference(expected,source,opacity,rectangle)
        assert(R.bytes(actual)==R.bytes(expected),
            'Mudanca RGBA na composicao: opacity='..opacity..
            ' region='..rectangle.w..'x'..rectangle.h)
        trials=trials+1
    end
end
-- Caminhos inteiramente opacos devem preservar a imagem de origem.
local opaque=R.buffer(2,2)
R.clear(opaque,0x102030ff)
local target=R.buffer(2,2)
R.clear(target,0x99ccbbaa)
R.composite(target,opaque,1)
assert(R.bytes(target)==R.bytes(opaque))
-- Fonte transparente + destino transparente colorido: RGB vira 0,
-- conforme a formula original, nao deve sobrar RGB escondido.
local zero=R.buffer(1,1)
R.pixel(zero,0,0,0xaabbcc00)
local transparent=R.buffer(1,1)
R.pixel(transparent,0,0,0x11223300)
R.composite(zero,transparent,1)
assert(R.readPixel(zero,0,0)==0)
print(('RGBA composite fast-path: %d cases byte-identical: OK'):format(trials))
