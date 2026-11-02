-- Ferramentas raster em LuaJIT; FFI usado somente como memoria de bytes.
local ffi=require('ffi')
local bit=require('bit')
local band,rshift=bit.band,bit.rshift
local floor,min,max,abs=math.floor,math.min,math.max,math.abs
local function int(n) return type(n)=='number' and n%1==0 end
local function rect(b,x,y,w,h)
    assert(b and b.bytes and int(b.width) and int(b.height)
        and b.size==b.width*b.height*4,'Buffer invalido')
    assert(int(x) and int(y) and int(w) and int(h) and
        x>=0 and y>=0 and w>0 and h>0 and
        x+w<=b.width and y+h<=b.height,'Selecao fora do canvas')
end
local function color(c)
    assert(int(c) and c>=0 and c<=4294967295,'Cor invalida')
    return band(rshift(c,24),255),band(rshift(c,16),255),
        band(rshift(c,8),255),band(c,255)
end
local function composite(p,i,source,s)
    local sa=source[s+3]/255
    if sa<=0 then return end
    local da=p[i+3]/255
    local remain=da*(1-sa)
    local out=sa+remain
    for k=0,2 do
        p[i+k]=floor((source[s+k]*sa+p[i+k]*remain)/out+0.5)
    end
    p[i+3]=floor(out*255+0.5)
end
local function compositeRGBA(p,i,r,g,b,a)
    if a<=0 then return end
    local da=p[i+3]/255
    local remain=da*(1-a)
    local out=a+remain
    p[i]=floor((r*a+p[i]*remain)/out+0.5)
    p[i+1]=floor((g*a+p[i+1]*remain)/out+0.5)
    p[i+2]=floor((b*a+p[i+2]*remain)/out+0.5)
    p[i+3]=floor(out*255+0.5)
end
local function snapshot(b,sx,sy,sw,sh)
    local bytes=ffi.new('uint8_t[?]',sw*sh*4)
    for y=0,sh-1 do
        ffi.copy(bytes+y*sw*4,b.bytes+((sy+y)*b.width+sx)*4,sw*4)
    end
    return bytes
end
local function clearSelection(b,sx,sy,sw,sh)
    for y=sy,sy+sh-1 do
        ffi.fill(b.bytes+(y*b.width+sx)*4,sw*4)
    end
end
return function(R)
    function R.moveRect(b,sx,sy,sw,sh,tx,ty)
        rect(b,sx,sy,sw,sh)
        assert(int(tx) and int(ty) and abs(tx)<=16384 and abs(ty)<=16384,
            'Destino invalido')
        if sx==tx and sy==ty then return end
        local stored=snapshot(b,sx,sy,sw,sh)
        clearSelection(b,sx,sy,sw,sh)
        for y=0,sh-1 do
            local dy=ty+y
            if dy>=0 and dy<b.height then
                for x=0,sw-1 do
                    local dx=tx+x
                    if dx>=0 and dx<b.width then
                        composite(b.bytes,(dy*b.width+dx)*4,stored,(y*sw+x)*4)
                    end
                end
            end
        end
    end
    function R.transformRect(b,sx,sy,sw,sh,tx,ty,tw,th,turns)
        rect(b,sx,sy,sw,sh)
        rect(b,tx,ty,tw,th)
        assert(int(turns) and turns>=0 and turns<=3,'Rotacao invalida')
        if sx==tx and sy==ty and sw==tw and sh==th and turns==0 then return end
        local stored=snapshot(b,sx,sy,sw,sh)
        clearSelection(b,sx,sy,sw,sh)
        for y=0,th-1 do
            for x=0,tw-1 do
                local ox,oy
                if turns==0 then
                    ox=floor(x*sw/tw);oy=floor(y*sh/th)
                elseif turns==1 then
                    ox=floor(y*sw/th);oy=sh-1-floor(x*sh/tw)
                elseif turns==2 then
                    ox=sw-1-floor(x*sw/tw);oy=sh-1-floor(y*sh/th)
                else
                    ox=sw-1-floor(y*sw/th);oy=floor(x*sh/tw)
                end
                composite(b.bytes,((ty+y)*b.width+tx+x)*4,stored,(oy*sw+ox)*4)
            end
        end
    end
    function R.bucketFill(b,x,y,rgba,tolerance)
        rect(b,x,y,1,1)
        assert(int(tolerance) and tolerance>=0 and tolerance<=255,
            'Tolerancia invalida')
        local r,g,blue,a=color(rgba)
        local w,h,p=b.width,b.height,b.bytes
        local n=w*h
        local seed=(y*w+x)*4
        local sr,sg,sb,sa=p[seed],p[seed+1],p[seed+2],p[seed+3]
        if b.alphaLock and (sa==0 or
            (sr==r and sg==g and sb==blue)) then return 0 end
        if tolerance==0 and sr==r and sg==g and sb==blue and sa==a then
            return 0
        end
        local visited=ffi.new('uint8_t[?]',n)
        local queue=ffi.new('uint32_t[?]',n)
        local start=y*w+x
        visited[start]=1;queue[0]=start
        local head,tail=0,1
        local changed=0
        while head<tail do
            local at=queue[head]
            head=head+1
            local i=at*4
            if not b.alphaLock or p[i]~=r or
                p[i+1]~=g or p[i+2]~=blue then
                p[i],p[i+1],p[i+2]=r,g,blue
                if not b.alphaLock then p[i+3]=a end
                changed=changed+1
            end
            local xx=at%w
            local yy=floor(at/w)
            local function consider(other)
                if visited[other]~=0 then return end
                local pos=other*4
                if b.alphaLock and p[pos+3]==0 then return end
                if abs(p[pos]-sr)<=tolerance and
                    abs(p[pos+1]-sg)<=tolerance and
                    abs(p[pos+2]-sb)<=tolerance and
                    abs(p[pos+3]-sa)<=tolerance then
                    visited[other]=1
                    queue[tail]=other;tail=tail+1
                end
            end
            if xx>0 then consider(at-1) end
            if xx<w-1 then consider(at+1) end
            if yy>0 then consider(at-w) end
            if yy<h-1 then consider(at+w) end
        end
        return changed
    end
    function R.basicShape(b,x0,y0,x1,y1,shape,filled,thickness,rgba)
        assert(int(shape) and shape>=0 and shape<=1
            and type(filled)=='boolean'
            and int(thickness) and thickness>=1 and thickness<=128
            and int(x0) and int(x1) and int(y0) and int(y1)
            and abs(x0)<=16384 and abs(x1)<=16384
            and abs(y0)<=16384 and abs(y1)<=16384,'Forma invalida')
        assert(b and b.bytes and b.size==b.width*b.height*4,'Buffer invalido')
        local r,g,blue,a=color(rgba)
        if a==0 then return end
        local left,right=min(x0,x1),max(x0,x1)
        local top,bottom=min(y0,y1),max(y0,y1)
        if right<0 or bottom<0 or left>=b.width or top>=b.height then return end
        local cx=(left+right+1)/2
        local cy=(top+bottom+1)/2
        local rx=(right-left+1)/2
        local ry=(bottom-top+1)/2
        local irx,iry=rx-thickness,ry-thickness
        for y=max(0,top),min(b.height-1,bottom) do
            for x=max(0,left),min(b.width-1,right) do
                local covered
                if shape==0 then
                    covered=filled or x-left<thickness or right-x<thickness
                        or y-top<thickness or bottom-y<thickness
                else
                    local dx,dy=x+0.5-cx,y+0.5-cy
                    local outer=(dx*dx)/(rx*rx)+(dy*dy)/(ry*ry)
                    covered=outer<=1 and (filled or irx<=0 or iry<=0
                        or (dx*dx)/(irx*irx)+(dy*dy)/(iry*iry)>=1)
                end
                if covered then
                    local pos=(y*b.width+x)*4
                    if b.alphaLock then
                        if b.bytes[pos+3]>0 then
                            local fraction=a/255
                            for k,v in ipairs({r,g,blue}) do
                                b.bytes[pos+k-1]=floor(
                                    v*fraction+
                                    b.bytes[pos+k-1]*(1-fraction)+.5)
                            end
                        end
                    else
                        compositeRGBA(b.bytes,pos,r,g,blue,a/255)
                    end
                end
            end
        end
    end
end
