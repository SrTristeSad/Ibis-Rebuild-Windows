-- Stage 40: scroll the layer list independently from the outer sidebar.
-- Geometry uses the same virtual positions as the classic desktop renderer.
-- Scrolling changes ONLY the visible list start, never the selected layer.
local Sidebar=require('sidebar_scroll')
local Thumbnails=require('layer_thumbnails')
local Wheel={}
Wheel.TOP=475
Wheel.ROW_HEIGHT=37
function Wheel.hit(width,height,x,y,sidebarScroll)
    if not Sidebar.contains(width,height,x,y) then return false end
    local virtualY=Sidebar.pointerY(y,
        Sidebar.clamp(height,sidebarScroll or 0))
    local rows=Thumbnails.rows(Sidebar.virtualHeight(height))
    return x>=width-Sidebar.WIDTH+20 and
        x<width-Sidebar.WIDTH+248 and
        virtualY>=Wheel.TOP and
        virtualY<Wheel.TOP+Wheel.ROW_HEIGHT*rows
end
function Wheel.scroll(count,selected,height,start,delta)
    assert(type(delta)=='number' and delta==delta and
        delta~=math.huge and delta~=-math.huge,
        'Invalid wheel displacement')
    local rows=Thumbnails.rows(Sidebar.virtualHeight(height))
    local first,_,maximum=Thumbnails.window(count,selected,rows,start)
    if delta==0 or maximum==1 then return first end
    -- Small trackpad movements still move one row; bound huge deltas.
    local amount=math.min(8,math.max(1,math.ceil(math.abs(delta))))
    return Thumbnails.scroll(first,maximum,
        delta>0 and amount or -amount)
end
return Wheel
