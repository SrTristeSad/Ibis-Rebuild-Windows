-- Brush catalogue swatches rendered by the SAME independent C++ stroke
-- primitives used for actual paint, into isolated RGBA scratch buffers.
-- Scale is illustrative on the card; the numeric diameter is authoritative.
local Presets=require('brush_presets')
local Colors=require('colors')
local Samples={}
function Samples.key(preset,rgba)
    Presets.validate(preset)
    Colors.channels(rgba)
    return table.concat({preset.style,tostring(preset.diameter),
        string.format('%.4f',preset.opacity),tostring(rgba)},'|')
end
function Samples.render(native,preset,rgba)
    assert(native and native.available,'Native C++ renderer required for swatch')
    local key=Samples.key(preset,rgba)
    local size=preset.diameter
    local width=math.max(96,math.ceil(size*1.65)+28)
    local height=math.max(36,math.ceil(size+18))
    local buffer=native.buffer(width,height)
    native.clear(buffer,0)
    local centerY=math.floor(height/2)+.5
    local startX=math.floor(size*.52)+.5
    local endX=width-startX
    if preset.style=='soft' then
        native.featherStroke(buffer,startX,centerY,endX,centerY,
            size,rgba,preset.opacity,.25)
    else
        native.basicStroke(buffer,startX,centerY,endX,centerY,
            size,rgba,preset.opacity)
    end
    return {buffer=buffer,width=width,height=height,key=key,
        x0=startX,y0=centerY,x1=endX,y1=centerY,
        size=size,style=preset.style}
end
function Samples.cardRect(x,y,width)
    assert(type(x)=='number' and x==x and
        type(y)=='number' and y==y and
        type(width)=='number' and width>=180,
        'Invalid brush library card dimensions')
    return {x=x+12,y=y+51,w=width-24,h=23}
end
return Samples
