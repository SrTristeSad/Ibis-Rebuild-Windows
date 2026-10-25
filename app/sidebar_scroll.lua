-- Stage 39: scroll only the desktop sidebar's painted content.
-- Canvas coordinates, brush parameters and saved project pixels never move.
local Sidebar={}
Sidebar.TOP=64
Sidebar.FOOTER=48
Sidebar.VIRTUAL_HEIGHT=800
Sidebar.WIDTH=268
function Sidebar.max(h)
    assert(type(h)=='number' and h>=640,'Window below supported height')
    return math.max(0,Sidebar.VIRTUAL_HEIGHT-h)
end
function Sidebar.clamp(h,value)
    assert(type(value)=='number' and value==value,
        'Invalid scroll offset')
    return math.max(0,math.min(Sidebar.max(h),value))
end
function Sidebar.virtualHeight(h)
    return math.max(h,Sidebar.VIRTUAL_HEIGHT)
end
function Sidebar.viewport(h)
    assert(type(h)=='number' and h>=640,'Invalid panel height')
    return {top=Sidebar.TOP,bottom=h-Sidebar.FOOTER,
        height=h-Sidebar.FOOTER-Sidebar.TOP}
end
function Sidebar.visible(h,scroll,y,height)
    assert(type(y)=='number' and type(height)=='number' and
        height>=0,'Invalid sidebar button')
    local viewport=Sidebar.viewport(h)
    local start=y-scroll
    local finish=start+height
    local top=math.max(viewport.top,start)
    local bottom=math.min(viewport.bottom,finish)
    if bottom<=top then return nil end
    return {y=top,h=bottom-top}
end
function Sidebar.pointerY(screenY,scroll)
    return screenY+scroll
end
function Sidebar.contains(w,h,x,y)
    assert(type(w)=='number' and w>=960,'Invalid window width')
    local clip=Sidebar.viewport(h)
    return x>=w-Sidebar.WIDTH and x<w and
        y>=clip.top and y<clip.bottom
end
function Sidebar.thumb(w,h,scroll)
    local max=Sidebar.max(h)
    if max<=0 then return nil end
    local viewport=Sidebar.viewport(h)
    local trackTop=viewport.top+24
    local trackHeight=viewport.height-53
    local ratio=viewport.height/(viewport.height+max)
    local height=math.max(28,trackHeight*ratio)
    return {x=w-10,y=trackTop+
        (trackHeight-height)*Sidebar.clamp(h,scroll)/max,
        w=5,h=height,trackTop=trackTop,trackHeight=trackHeight}
end
return Sidebar
