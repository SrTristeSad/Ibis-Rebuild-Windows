-- Actual gallery thumbnail pixels sampled from the native C++ RGBA
-- composite. Independent, no copied Android assets, no WebView.
local Thumb={}
local function positive(n)
    return type(n)=='number' and n%1==0 and n>0 and n<=2048
end
function Thumb.size(width,height,maxWidth,maxHeight)
    assert(positive(width) and positive(height) and
        positive(maxWidth) and positive(maxHeight),
        'Thumbnail dimensions must be positive integers <=2048')
    local factor=math.min(maxWidth/width,maxHeight/height)
    return math.max(1,math.floor(width*factor+.5)),
        math.max(1,math.floor(height*factor+.5))
end
function Thumb.source(x,y,tw,th,width,height)
    assert(type(x)=='number' and x%1==0 and x>=0 and x<tw and
        type(y)=='number' and y%1==0 and y>=0 and y<th and
        positive(tw) and positive(th) and positive(width) and
        positive(height),'Invalid thumbnail sample')
    return math.min(width-1,math.floor((x+.5)*width/tw)),
        math.min(height-1,math.floor((y+.5)*height/th))
end
-- Calls pixel(r,g,b,a,x,y) for each target pixel, no native writes.
-- The source is the *composite* produced by native C++; alpha is retained.
function Thumb.sample(rgba,width,height,tw,th,pixel)
    assert(type(rgba)=='string' and positive(width) and
        positive(height) and #rgba==width*height*4,
        'Expected exact native RGBA bytes')
    assert(positive(tw) and positive(th) and tw<=176 and
        th<=126 and type(pixel)=='function',
        'Invalid thumbnail canvas')
    for y=0,th-1 do
        for x=0,tw-1 do
            local srcX,srcY=Thumb.source(x,y,tw,th,width,height)
            local offset=(srcY*width+srcX)*4+1
            local r,g,b,a=rgba:byte(offset,offset+3)
            pixel(r,g,b,a,x,y)
        end
    end
end
function Thumb.key(doc)
    assert(type(doc)=='table' and type(doc.id)=='string' and
        type(doc.revision)=='number' and doc.revision>=1,
        'Invalid saved project thumbnail key')
    return doc.id..':'..doc.revision
end
return Thumb
