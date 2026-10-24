-- Tiny RGBA thumbnails generated from caller-owned native raster buffers.
-- Samples at most 28*28 pixels; never copies a full source image to Lua.
-- This is independent desktop UI functionality, not the Android algorithm.
local Thumb={}
Thumb.SIZE=28
local function integer(v,low,high)
    return type(v)=='number' and v==v and v%1==0 and v>=low and v<=high
end
function Thumb.sample(buffer,size)
    size=size or Thumb.SIZE
    assert(integer(size,1,64),'Tamanho de miniatura inválido')
    assert(buffer and integer(buffer.width,1,8192) and
        integer(buffer.height,1,8192) and buffer.bytes and
        buffer.size>=buffer.width*buffer.height*4,
        'Buffer RGBA8 nativo inválido')
    local w,h=buffer.width,buffer.height
    local factor=math.min(size/w,size/h)
    local drawW=math.min(size,math.max(1,math.floor(w*factor+0.5)))
    local drawH=math.min(size,math.max(1,math.floor(h*factor+0.5)))
    local offsetX=math.floor((size-drawW)/2)
    local offsetY=math.floor((size-drawH)/2)
    local chunks={}
    local n=0
    for y=0,size-1 do
        for x=0,size-1 do
            n=n+1
            if x>=offsetX and x<offsetX+drawW and
                y>=offsetY and y<offsetY+drawH then
                local srcX=math.min(w-1,math.floor((x-offsetX+0.5)*w/drawW))
                local srcY=math.min(h-1,math.floor((y-offsetY+0.5)*h/drawH))
                local at=(srcY*w+srcX)*4
                chunks[n]=string.char(buffer.bytes[at],buffer.bytes[at+1],
                    buffer.bytes[at+2],buffer.bytes[at+3])
            else
                chunks[n]='\0\0\0\0'
            end
        end
    end
    return table.concat(chunks),drawW,drawH
end
function Thumb.rows(height)
    assert(type(height)=='number' and height==height and
        height>=640 and height<=32768,'Altura do editor inválida')
    return math.max(1,math.min(5,math.floor((height-131-475)/37)))
end
function Thumb.window(count,selected,rows,start)
    assert(integer(count,1,8) and integer(selected,1,count) and
        integer(rows,1,5),'Intervalo de camadas inválido')
    local visible=math.min(count,rows)
    local maximum=count-visible+1
    if start==nil then
        start=selected-math.floor(visible/2)
    end
    assert(integer(start,-16,32),'Deslocamento de camadas inválido')
    start=math.max(1,math.min(maximum,start))
    return start,start+visible-1,maximum
end
function Thumb.scroll(start,maxStart,step)
    assert(integer(start,1,8) and integer(maxStart,1,8) and
        integer(step,-8,8),'Rolagem de camadas inválida')
    return math.max(1,math.min(maxStart,start+step))
end
return Thumb
