-- Stage 41: compact layer popup's independent mouse wheel navigation.
-- View-only: never changes the active layer, project, renderer or history.
local Compact=require('compact_layout')
local Thumbnails=require('layer_thumbnails')
local Wheel={}
function Wheel.hit(w,h,x,y,count)
    local popup=Compact.popup(w,h,'layers')
    assert(type(count)=='number' and count%1==0 and count>=1
        and count<=8,'Invalid layer count')
    if type(x)~='number' or type(y)~='number' or
        x~=x or y~=y then return false end
    local rows=math.min(count,Compact.layerRows(popup))
    return x>=popup.x+13 and x<popup.x+284 and
        y>=popup.y+87 and y<popup.y+87+rows*40
end
function Wheel.scroll(count,selected,w,h,start,delta)
    assert(type(delta)=='number' and delta==delta
        and delta~=math.huge and delta~=-math.huge,
        'Invalid layer wheel delta')
    local rows=Compact.layerRows(Compact.popup(w,h,'layers'))
    local first,_,maximum=Thumbnails.window(count,selected,rows,start)
    if delta==0 or maximum==1 then return first end
    local amount=math.min(8,math.max(1,math.ceil(math.abs(delta))))
    return Thumbnails.scroll(first,maximum,
        delta>0 and amount or -amount)
end
return Wheel
