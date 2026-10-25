-- Interactive opacity rail for the classic desktop layer sidebar.
-- Geometry is in virtual sidebar coordinates; values are preview-only until
-- mouse release, preventing hundreds of metadata undo entries while dragging.
local Sidebar=require('sidebar_scroll')
local Opacity=require('compact_layer_opacity')
local Rail={}
function Rail.rect(width,height)
    assert(type(width)=='number' and width>=960 and
        type(height)=='number' and height>=640,
        'Unsupported desktop opacity viewport')
    return {x=width-Sidebar.WIDTH+20,
        y=Sidebar.virtualHeight(height)-58,w=228,h=4}
end
function Rail.hit(width,height,x,y,scroll)
    if type(x)~='number' or type(y)~='number' or
        x~=x or y~=y then return false end
    if not Sidebar.contains(width,height,x,y) then return false end
    local r=Rail.rect(width,height)
    local virtualY=Sidebar.pointerY(y,Sidebar.clamp(height,scroll or 0))
    return x>=r.x-3 and x<=r.x+r.w+3 and
        virtualY>=r.y-4 and virtualY<=r.y+r.h+6
end
function Rail.value(width,height,x)
    assert(type(x)=='number' and x==x,'Invalid slider position')
    local r=Rail.rect(width,height)
    return math.floor(math.max(0,math.min(1,
        (x-r.x)/r.w))*100+.5)/100
end
function Rail.draft(index,initial,value)
    return Opacity.draft(index,initial,value)
end
function Rail.changed(draft)
    return Opacity.changed(draft)
end
return Rail
