-- Native brush catalogue inspector. Pure, bounds-checked UI geometry
-- and draft configuration updates, with NO document or preference writes.
local Presets=require('brush_presets')
local Lab={}
Lab.CATALOGUE_WIDTH=720
function Lab.layout(rect)
    assert(type(rect)=='table' and type(rect.x)=='number' and
        type(rect.y)=='number' and type(rect.w)=='number' and
        rect.w>=840 and rect.h>=546,'Invalid brush inspector window')
    local x=rect.x+Lab.CATALOGUE_WIDTH+4
    local width=rect.w-Lab.CATALOGUE_WIDTH-17
    return {x=x,y=rect.y+82,w=width,h=rect.h-162}
end
function Lab.preview(rect)
    local p=Lab.layout(rect)
    return {x=p.x+8,y=p.y+42,w=p.w-16,h=160}
end
function Lab.rail(rect,key)
    local p=Lab.layout(rect)
    local order={diameter=0,opacity=1,stabilization=2}
    local i=assert(order[key],'Unknown brush adjustment')
    return {x=p.x+11,y=p.y+234+i*44,w=p.w-24,h=14}
end
function Lab.hit(rect,x,y)
    assert(type(x)=='number' and type(y)=='number' and x==x and y==y,
        'Invalid pointer position')
    for _,key in ipairs({'diameter','opacity','stabilization'}) do
        local r=Lab.rail(rect,key)
        if x>=r.x-5 and x<=r.x+r.w+5 and
            y>=r.y-5 and y<=r.y+r.h+5 then return key end
    end
    return nil
end
function Lab.value(rect,key,x)
    assert(type(x)=='number' and x==x,'Invalid slider pointer')
    local r=Lab.rail(rect,key)
    local ratio=math.max(0,math.min(1,(x-r.x)/r.w))
    if key=='diameter' then return 1+math.floor(ratio*255+.5) end
    if key=='opacity' then
        return (10+math.floor(ratio*90+.5))/100
    end
    if key=='stabilization' then return math.floor(ratio*5+.5) end
    error('Invalid slider key')
end
function Lab.fraction(key,value)
    assert(type(value)=='number' and value==value,
        'Invalid adjustment value')
    if key=='diameter' then return (value-1)/255 end
    if key=='opacity' then return (value-.1)/.9 end
    if key=='stabilization' then return value/5 end
    error('Invalid adjustment key')
end
function Lab.adjust(draft,key,value)
    local updated=Presets.copy(draft)
    if key=='diameter' or key=='stabilization' or key=='opacity' then
        updated[key]=value
    else error('Unknown brush adjustment') end
    return Presets.validate(updated)
end
function Lab.draft(preset)
    return Presets.copy(preset)
end
-- Two separate native RGBA samples share the existing 160px preview:
-- applied brush on top, draft below. Never paint into the document.
function Lab.comparison(rect)
    local p=Lab.preview(rect)
    return {
        current={x=p.x+4,y=p.y+21,w=p.w-8,h=52,
            labelY=p.y+3},
        draft={x=p.x+4,y=p.y+102,w=p.w-8,h=52,
            labelY=p.y+84}
    }
end
-- All edits are reversible local previews until the user clicks Aplicar.
function Lab.differences(original,draft)
    Presets.validate(original)
    Presets.validate(draft)
    local fields={'style','diameter','opacity','stabilization'}
    local count=0
    for _,key in ipairs(fields) do
        if key=='opacity' and math.abs(original[key]-draft[key])>1e-6 or
            key~='opacity' and original[key]~=draft[key] then
            count=count+1
        end
    end
    return count
end
function Lab.source(focus,saved,current)
    assert(type(saved)=='table','Invalid saved brush collection')
    local chosen
    if focus~=nil then
        assert(type(focus)=='number' and focus%1==0 and
            focus>=1 and focus<=8,'Invalid focused brush')
        chosen=focus<=4 and Presets.BUILTINS[focus] or saved[focus-4]
    end
    return Presets.copy(chosen or current)
end
function Lab.resetRect(rect)
    local p=Lab.layout(rect)
    return {x=p.x+8,y=p.y+p.h-36,w=49,h=31}
end
function Lab.fit(imageWidth,imageHeight,rect)
    assert(type(imageWidth)=='number' and imageWidth>0 and
        type(imageHeight)=='number' and imageHeight>0 and
        type(rect)=='table' and rect.w>0 and rect.h>0,
        'Invalid brush preview dimensions')
    local scale=math.min(rect.w/imageWidth,rect.h/imageHeight)
    return {x=rect.x+(rect.w-imageWidth*scale)/2,
        y=rect.y+(rect.h-imageHeight*scale)/2,
        sx=scale,sy=scale}
end
return Lab
