-- Real native brush preview in the compact properties popover.
-- Pure geometry: positioned beside the existing parameter controls.
local Inspector={}
function Inspector.preview(p)
    assert(type(p)=='table' and type(p.x)=='number' and
        type(p.y)=='number' and p.w>=298 and p.h>=354,
        'Unsupported compact properties popover')
    return {x=p.x+164,y=p.y+176,w=103,h=65}
end
function Inspector.caption(p)
    local r=Inspector.preview(p)
    return {x=r.x,y=r.y-18,w=r.w}
end
function Inspector.rowLabelWidth()
    return 122
end
function Inspector.settings(state)
    assert(type(state)=='table' and
        (state.brushStyle=='hard' or state.brushStyle=='soft'),
        'Invalid brush style')
    return {style=state.brushStyle,diameter=state.brushDiameter,
        opacity=state.brushOpacity,
        stabilization=state.stabilization}
end
function Inspector.fitted(imageWidth,imageHeight,rect)
    assert(imageWidth>0 and imageHeight>0 and
        rect.w>0 and rect.h>0,'Invalid C++ preview shape')
    local scale=math.min(rect.w/imageWidth,rect.h/imageHeight)
    return {x=rect.x+(rect.w-imageWidth*scale)/2,
        y=rect.y+(rect.h-imageHeight*scale)/2,
        scale=scale}
end
return Inspector
