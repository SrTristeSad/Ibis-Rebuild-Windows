-- Magic Wand (first functional slice): exact RGBA mask, no raster changes.
-- 4-connected flood or global color match; user-selected reference buffer.
-- Explicitly does not apply the resulting mask to painting/transforms yet.
local ffi=require('ffi')
local floor,abs,min,max=math.floor,math.abs,math.min,math.max
local M={}
local function integer(v)
    return type(v)=='number' and v==v and v%1==0
end
local function validBuffer(b)
    assert(type(b)=='table' and b.bytes and integer(b.width)
        and integer(b.height) and b.width>0 and b.height>0
        and b.size==b.width*b.height*4,
        'Referencia RGBA invalida')
end
local function validMask(m,w,h)
    assert(type(m)=='table' and m.bytes and m.width==w
        and m.height==h and type(m.count)=='number',
        'Mascara anterior nao corresponde ao canvas')
end
function M.select(buffer,x,y,tolerance,mode,continuous,previous)
    validBuffer(buffer)
    local w,h=buffer.width,buffer.height
    assert(integer(x) and integer(y) and x>=0 and x<w and
        y>=0 and y<h,'Ponto da varinha fora do canvas')
    assert(integer(tolerance) and tolerance>=0 and tolerance<=100,
        'Tolerancia da varinha invalida')
    assert(mode=='set' or mode=='add' or mode=='subtract',
        'Modo de selecao invalido')
    assert(type(continuous)=='boolean','Conectividade invalida')
    if previous then validMask(previous,w,h) end
    local size=w*h
    local selected=ffi.new('uint8_t[?]',size)
    local p=buffer.bytes
    local pos=(y*w+x)*4
    local sr,sg,sb,sa=p[pos],p[pos+1],p[pos+2],p[pos+3]
    local limit=floor(tolerance*255/100+.5)
    local function matches(index)
        local q=index*4
        return abs(p[q]-sr)<=limit
            and abs(p[q+1]-sg)<=limit
            and abs(p[q+2]-sb)<=limit
            and abs(p[q+3]-sa)<=limit
    end
    if mode~='subtract' or previous then
        if continuous then
            local queue=ffi.new('uint32_t[?]',size)
            local head,tail=0,1
            local seed=y*w+x
            queue[0]=seed;selected[seed]=1
            local function consider(at)
                if selected[at]==0 and matches(at) then
                    selected[at]=1
                    queue[tail]=at
                    tail=tail+1
                end
            end
            while head<tail do
                local at=tonumber(queue[head])
                head=head+1
                local xx=at%w
                if xx>0 then consider(at-1) end
                if xx+1<w then consider(at+1) end
                if at>=w then consider(at-w) end
                if at+w<size then consider(at+w) end
            end
        else
            for i=0,size-1 do
                if matches(i) then selected[i]=1 end
            end
        end
    end
    local result=ffi.new('uint8_t[?]',size)
    local count,left,top,right,bottom=0,w,h,-1,-1
    for i=0,size-1 do
        local added=selected[i]~=0
        local previousSelected=previous and previous.bytes[i]~=0 or false
        local keep=(mode=='set' and added)
            or (mode=='add' and (added or previousSelected))
            or (mode=='subtract' and previousSelected and not added)
        if keep then
            result[i]=1
            count=count+1
            local xx=i%w
            local yy=floor(i/w)
            left=min(left,xx);right=max(right,xx)
            top=min(top,yy);bottom=max(bottom,yy)
        end
    end
    return {bytes=result,width=w,height=h,count=count,
        x=count>0 and left or 0,y=count>0 and top or 0,
        w=count>0 and right-left+1 or 0,
        h=count>0 and bottom-top+1 or 0}
end
function M.has(mask,x,y)
    validMask(mask,mask.width,mask.height)
    assert(integer(x) and integer(y),'Coordenadas invalidas')
    if x<0 or y<0 or x>=mask.width or y>=mask.height then return false end
    return mask.bytes[y*mask.width+x]~=0
end
function M.preview(mask)
    validMask(mask,mask.width,mask.height)
    assert(love and love.image and love.graphics,
        'Preview requer LÖVE real')
    local n=mask.width*mask.height
    local rgba=ffi.new('uint8_t[?]',n*4)
    for i=0,n-1 do
        if mask.bytes[i]~=0 then
            local q=i*4
            rgba[q]=55;rgba[q+1]=140;rgba[q+2]=245;rgba[q+3]=85
        end
    end
    local data=love.image.newImageData(mask.width,mask.height,
        'rgba8',ffi.string(rgba,n*4))
    local image=love.graphics.newImage(data)
    image:setFilter('nearest','nearest')
    data:release()
    return image
end
return M
