-- Preview a single brush/eraser dab through the SAME native C++ raster
-- calls used by the editor. Scratch buffer only: no document/history writes.
local Pressure=require('touch_pressure')
local Workspace=require('workspace_layout')
local View=require('canvas_view')
local Tip={}
local function finite(v)
    return type(v)=='number' and v==v and v~=-math.huge and v~=math.huge
end
function Tip.options(tool,diameter,opacity,color,style,pressure,tiltX,tiltY,tiltEnabled)
    assert(tool=='brush' or tool=='erase','Preview supports brush or eraser only')
    assert(finite(diameter) and diameter>=1 and diameter<=256,
        'Invalid tip diameter')
    assert(finite(opacity) and opacity>=.1 and opacity<=1,
        'Invalid tip opacity')
    assert(type(color)=='number' and color%1==0 and
        color>=0 and color<=4294967295,'Invalid RGBA tip color')
    assert(style=='hard' or style=='soft','Invalid tip style')
    assert(finite(tiltX or 0) and finite(tiltY or 0),'Invalid tip tilt')
    local p=Pressure.normalize(pressure)
    local d=Pressure.diameter(diameter,p)
    local alpha=Pressure.opacity(opacity,p)
    local tilted=tool=='brush' and tiltEnabled==true and
        ((tiltX or 0)~=0 or (tiltY or 0)~=0)
    return {tool=tool,diameter=d,opacity=alpha,
        color=tool=='erase' and 0xffffffff or color,style=style,
        tilted=tilted,tiltX=tilted and tiltX or 0,
        tiltY=tilted and tiltY or 0}
end
function Tip.key(o)
    assert(type(o)=='table','Invalid preview settings')
    return table.concat({o.tool,tostring(o.color),o.style,
        string.format('%.4f',o.diameter),string.format('%.4f',o.opacity),
        tostring(o.tilted),tostring(o.tiltX),tostring(o.tiltY)},'|')
end
function Tip.render(native,o)
    assert(native and native.available,'Native renderer required for brush preview')
    assert(o.tool=='brush' or o.tool=='erase','Invalid tip kind')
    assert(finite(o.diameter) and o.diameter>=1 and o.diameter<=256,
        'Preview diameter outside bounds')
    local size=math.min(640,math.max(24,math.ceil(o.diameter*2)+12))
    local buffer=native.buffer(size,size)
    native.clear(buffer,0)
    -- Native C++ samples at pixel centers (x+0.5,y+0.5). Align a 1px
    -- dab to an actual pixel instead of leaving four pixels diagonally out.
    local center=math.floor(size/2)+0.5
    -- Eraser is represented as a white opacity *mask*: destination-out
    -- erasure depends on unknown pixels below the pointer.
    if o.tilted then
        native.tiltStroke(buffer,center,center,center,center,o.diameter,
            o.color,o.opacity,o.style=='soft' and .25 or 1,o.tiltX,o.tiltY)
    elseif o.tool=='brush' and o.style=='soft' then
        native.featherStroke(buffer,center,center,center,center,
            o.diameter,o.color,o.opacity,.25)
    else
        native.basicStroke(buffer,center,center,center,center,
            o.diameter,o.color,o.opacity)
    end
    return {buffer=buffer,size=size,center=center,kind=o.tool,
        key=Tip.key(o)}
end
function Tip.visible(state,w,h,x,y)
    if type(state)~='table' or state.screen~='editor'
        or not state.doc or not state.previewEnabled
        or (state.tool~='brush' and state.tool~='erase')
        or state.modal or state.toolHelp or state.brushLibrary
        or state.contextMenu or state.panning or state.drawing
        or state.sliderDrag or state.compactPanel or state.spaceHeld or
        state.inkPenId~=nil or state.touchId~=nil or
        state.mouseOutside then return false end
    if not finite(x) or not finite(y) or
        not Workspace.contains(w,h,state.focusMode==true or
            state.compactUi==true,x,y,state.compactUi==true and not state.focusMode) then
        return false
    end
    local v={zoom=state.zoom,rotation=state.rotation,
        panX=state.panX,panY=state.panY,
        width=state.doc.width,height=state.doc.height,
        focusMode=state.focusMode==true or state.compactUi==true,
        compactUi=state.compactUi==true and not state.focusMode}
    local px,py=View.toCanvas(v,w,h,x,y)
    if px<0 or py<0 or px>=state.doc.width or py>=state.doc.height then
        return false
    end
    return true,px,py
end
return Tip
