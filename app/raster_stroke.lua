-- Rasterizador de pinceladas em LuaJIT. Nenhum codigo C/C++ proprio.
-- Coordenadas usam centros dos pixels (x+0.5,y+0.5); RGBA 0xRRGGBBAA.
local ffi = require('ffi')
local bit = require('bit')
local floor, min, max, abs = math.floor, math.min, math.max, math.abs
local rshift, band = bit.rshift, bit.band
-- Benchmark/regressao podem restaurar a varredura retangular original.
local scanlineEnabled=true

local function inRange(value, low, high)
    return type(value)=='number' and value>=low and value<=high
end
local function valid(b)
    assert(type(b)=='table' and b.bytes and b.width and b.height
        and b.size==b.width*b.height*4, 'Buffer RGBA invalido')
end
local function round(x)
    return floor(x+0.5)
end
local function colors(rgba)
    assert(inRange(rgba,0,4294967295) and rgba%1==0,'Cor RGBA invalida')
    return band(rshift(rgba,24),255),band(rshift(rgba,16),255),
        band(rshift(rgba,8),255),band(rgba,255)
end
local function clamp(n, low, high)
    return max(low,min(high,n))
end
local function checkStroke(b,x0,y0,x1,y1,d0,d1,o0,o1,hardness,tiltX,tiltY,style)
    valid(b)
    assert(inRange(x0,-16384,16384) and inRange(y0,-16384,16384)
        and inRange(x1,-16384,16384) and inRange(y1,-16384,16384)
        and inRange(d0,1,256) and inRange(d1,1,256)
        and inRange(o0,0,1) and inRange(o1,0,1)
        and inRange(hardness,0,1) and inRange(tiltX,-90,90)
        and inRange(tiltY,-90,90)
        and type(style)=='number' and style%1==0 and style>=0 and style<=3,
        'Parametros da pincelada invalidos')
end
local function blend(dst,offset,red,green,blue,alpha)
    local da=dst[offset+3]/255
    local remain=da*(1-alpha)
    local outAlpha=alpha+remain
    if outAlpha<=0 then return end
    local inverse=1/outAlpha
    dst[offset]=round(clamp((red*alpha+dst[offset]*remain)*inverse,0,255))
    dst[offset+1]=round(clamp((green*alpha+dst[offset+1]*remain)*inverse,0,255))
    dst[offset+2]=round(clamp((blue*alpha+dst[offset+2]*remain)*inverse,0,255))
    dst[offset+3]=round(clamp(outAlpha*255,0,255))
end
local function erase(dst,offset,alpha)
    local a=round(clamp(dst[offset+3]*(1-alpha),0,255))
    dst[offset+3]=a
    if a==0 then dst[offset],dst[offset+1],dst[offset+2]=0,0,0 end
end
-- O kernel percorre somente a caixa afetada, nao o canvas inteiro.
-- 'baseline' e a imagem RGBA antes do gesto; 'mask' memoriza a maior
-- cobertura por pixel. Ambos sao opcionais apenas para gestos simples.
local function stroke(b,baseline,mask,x0,y0,x1,y1,d0,d1,rgba,o0,o1,hardness,tx,ty,style)
    checkStroke(b,x0,y0,x1,y1,d0,d1,o0,o1,hardness,tx,ty,style)
    -- Locking transparency makes erasing an intentional no-op.
    if b.alphaLock and style==2 then return end
    local r,g,blue,ca=colors(rgba)
    if o0==0 and o1==0 then return end
    if style~=2 and ca==0 then return end
    local oriented=(style==3 and (tx~=0 or ty~=0))
    local strength=oriented and max(abs(tx),abs(ty))/90 or 0
    local major=1+0.75*strength
    local minor=1-0.15*strength
    local border=max(d0,d1)*0.5*major+1
    local left=max(0,floor(min(x0,x1)-border))
    local top=max(0,floor(min(y0,y1)-border))
    local right=min(b.width-1,math.ceil(max(x0,x1)+border))
    local bottom=min(b.height-1,math.ceil(max(y0,y1)+border))
    if right<left or bottom<top then return end

    local dx,dy=x1-x0,y1-y0
    local seg2=dx*dx+dy*dy
    local tilt2=tx*tx+ty*ty
    local alongScale=oriented and (1/(tilt2*major*major)) or 0
    local acrossScale=oriented and (1/(tilt2*minor*minor)) or 0
    local segAlong=dx*tx+dy*ty
    local segAcross=dy*tx-dx*ty
    local metric2=segAlong*segAlong*alongScale+segAcross*segAcross*acrossScale
    local base=baseline and ffi.cast('const uint8_t*',baseline) or nil
    local pixels=b.bytes

    for y=top,bottom do
        local cy=y+0.5-y0
        local rowLeft,rowRight=left,right
        if scanlineEnabled and dy~=0 then
            -- Qualquer pixel atingido precisa estar a menos de border do
            -- eixo do segmento. Para esta linha, somente pontos cujo Y
            -- esteja em [y+0.5-border,y+0.5+border] podem contribuir.
            -- A banda e conservadora inclusive no pincel inclinado:
            -- border usa o maior raio do elipsoide.
            local ta=(cy-border)/dy
            local tb=(cy+border)/dy
            if ta>tb then ta,tb=tb,ta end
            if tb<0 or ta>1 then
                rowRight=left-1
            else
                ta=clamp(ta,0,1)
                tb=clamp(tb,0,1)
                local xa=x0+dx*ta
                local xb=x0+dx*tb
                -- Margem adicional de um pixel preserva fronteiras
                -- submetidas a arredondamento de ponto flutuante.
                rowLeft=max(left,floor(min(xa,xb)-border)-1)
                rowRight=min(right,math.ceil(max(xa,xb)+border)+1)
            end
        end
        for x=rowLeft,rowRight do
            local cx=x+0.5-x0
            local t=0
            if oriented and metric2>0 then
                local along=cx*tx+cy*ty
                local across=cy*tx-cx*ty
                t=(along*segAlong*alongScale+across*segAcross*acrossScale)/metric2
            elseif seg2>0 then
                t=(cx*dx+cy*dy)/seg2
            end
            t=clamp(t,0,1)
            local diameter=d0+(d1-d0)*t
            local radius2=diameter*diameter*0.25
            local ex,ey=cx-t*dx,cy-t*dy
            local distance2=ex*ex+ey*ey
            if oriented then
                local along=ex*tx+ey*ty
                local across=ey*tx-ex*ty
                distance2=along*along*alongScale+across*across*acrossScale
            end
            local hard=style==0 or style==2 or hardness==1
            if (hard and distance2<=radius2) or
                (not hard and distance2<radius2) then
                local coverage=1
                if not hard then
                    local inner2=radius2*hardness*hardness
                    if distance2>inner2 then
                        coverage=(radius2-distance2)/(radius2-inner2)
                    end
                end
                local alpha=(o0+(o1-o0)*t)*coverage
                if style~=2 then alpha=alpha*(ca/255) end
                if alpha>0 then
                    local index=y*b.width+x
                    local pos=index*4
                    if mask then
                        local weight=round(clamp(alpha*255,0,255))
                        if weight>mask.bytes[index] then
                            mask.bytes[index]=weight
                            local effective=weight/255
                            if style==2 then
                                local a=round(base[pos+3]*(1-effective))
                                pixels[pos+3]=a
                                if a==0 then
                                    pixels[pos],pixels[pos+1],pixels[pos+2]=0,0,0
                                else
                                    pixels[pos],pixels[pos+1],pixels[pos+2]=
                                        base[pos],base[pos+1],base[pos+2]
                                end
                            elseif b.alphaLock then
                                -- Recolor existing pixels without changing
                                -- their original (possibly partial) alpha.
                                if base[pos+3]>0 then
                                    pixels[pos]=round(clamp(r*effective+
                                        base[pos]*(1-effective),0,255))
                                    pixels[pos+1]=round(clamp(g*effective+
                                        base[pos+1]*(1-effective),0,255))
                                    pixels[pos+2]=round(clamp(blue*effective+
                                        base[pos+2]*(1-effective),0,255))
                                    pixels[pos+3]=base[pos+3]
                                end
                            else
                                local da=base[pos+3]/255
                                local remain=da*(1-effective)
                                local oa=effective+remain
                                if oa>0 then
                                    pixels[pos]=round(clamp((r*effective+base[pos]*remain)/oa,0,255))
                                    pixels[pos+1]=round(clamp((g*effective+base[pos+1]*remain)/oa,0,255))
                                    pixels[pos+2]=round(clamp((blue*effective+base[pos+2]*remain)/oa,0,255))
                                    pixels[pos+3]=round(clamp(oa*255,0,255))
                                end
                            end
                        end
                    elseif style==2 then
                        erase(pixels,pos,alpha)
                    elseif b.alphaLock then
                        if pixels[pos+3]>0 then
                            pixels[pos]=round(clamp(r*alpha+
                                pixels[pos]*(1-alpha),0,255))
                            pixels[pos+1]=round(clamp(g*alpha+
                                pixels[pos+1]*(1-alpha),0,255))
                            pixels[pos+2]=round(clamp(blue*alpha+
                                pixels[pos+2]*(1-alpha),0,255))
                        end
                    else
                        blend(pixels,pos,r,g,blue,alpha)
                    end
                end
            end
        end
    end
end

return function(R)
    function R.setStrokeScanlineEnabled(enabled)
        assert(type(enabled)=='boolean','Configuracao de varredura invalida')
        scanlineEnabled=enabled
    end
    function R.strokeScanlineEnabled() return scanlineEnabled end
    function R.basicStroke(b,x0,y0,x1,y1,d,rgba,opacity)
        stroke(b,nil,nil,x0,y0,x1,y1,d,d,rgba,opacity,opacity,1,0,0,0)
    end
    function R.featherStroke(b,x0,y0,x1,y1,d,rgba,opacity,hardness)
        stroke(b,nil,nil,x0,y0,x1,y1,d,d,rgba,opacity,opacity,hardness,0,0,1)
    end
    function R.tiltStroke(b,x0,y0,x1,y1,d,rgba,opacity,hardness,tx,ty)
        stroke(b,nil,nil,x0,y0,x1,y1,d,d,rgba,opacity,opacity,hardness,tx,ty,3)
    end
    function R.basicErase(b,x0,y0,x1,y1,d,opacity)
        stroke(b,nil,nil,x0,y0,x1,y1,d,d,0,opacity,opacity,1,0,0,2)
    end
    function R.pressureStroke(b,x0,y0,x1,y1,d0,d1,rgba,o0,o1,hardness,tx,ty,style)
        stroke(b,nil,nil,x0,y0,x1,y1,d0,d1,rgba,o0,o1,hardness,tx,ty,style)
    end
    function R.strokeCoverage(b)
        valid(b)
        return {bytes=ffi.new('uint8_t[?]',b.width*b.height),
            size=b.width*b.height,width=b.width,height=b.height}
    end
    function R.accumulatedStroke(b,baseline,mask,x0,y0,x1,y1,
            d0,d1,rgba,o0,o1,hardness,tx,ty,style)
        valid(b)
        assert(type(baseline)=='string' and #baseline==b.size
            and type(mask)=='table' and mask.bytes
            and mask.width==b.width and mask.height==b.height
            and mask.size==b.width*b.height, 'Acumulador invalido')
        stroke(b,baseline,mask,x0,y0,x1,y1,d0,d1,rgba,o0,o1,hardness,tx,ty,style)
    end
    function R.flip(b,axis)
        valid(b)
        assert(axis==0 or axis==1,'Eixo de espelhamento invalido')
        local w,h,p=b.width,b.height,b.bytes
        if axis==0 then
            for y=0,h-1 do
                for x=0,floor(w/2)-1 do
                    local a=(y*w+x)*4
                    local c=(y*w+w-1-x)*4
                    for k=0,3 do p[a+k],p[c+k]=p[c+k],p[a+k] end
                end
            end
        else
            for y=0,floor(h/2)-1 do
                for x=0,w-1 do
                    local a=(y*w+x)*4
                    local c=((h-1-y)*w+x)*4
                    for k=0,3 do p[a+k],p[c+k]=p[c+k],p[a+k] end
                end
            end
        end
    end
    function R.pressure(raw,enabled,low,high)
        if not enabled then return 1 end
        assert(type(raw)=='number' and type(low)=='number' and type(high)=='number',
            'Pressao invalida')
        if high==low then return raw<low and 0 or 1 end
        return clamp((raw-low)/(high-low),0,1)
    end
    function R.thickness(current,proposed)
        if inRange(proposed,-2,2) then return proposed,true end
        return current,false
    end
    function R.pack(points)
        assert(type(points)=='table','Amostras invalidas')
        local out={ints={},floats={},times={}}
        for _,p in ipairs(points) do
            out.ints[#out.ints+1]=p.id or 0
            out.ints[#out.ints+1]=p.info or 0
            local stylus=p.stylus and true or false
            for _,v in ipairs({p.x,p.y,p.previous_x or p.x,p.previous_y or p.y,
                p.pressure or 1,stylus and (p.altitude or 0) or 0,
                stylus and (p.azimuth or 0) or 0}) do
                out.floats[#out.floats+1]=v
            end
            out.times[#out.times+1]=tostring(p.time or 0)
        end
        return out
    end
end
