-- Independent view transform; never mutates the document or raster.
-- Canvas coordinates are pixels at 0..width,0..height, screen coordinates
-- are logical LÖVE points. UI panel occupies the rightmost 268 pixels.
local Workspace=require('workspace_layout')
local View={}
View.MIN_ZOOM=0.05
View.MAX_ZOOM=32
local function finite(v)
    return type(v)=='number' and v==v and v>-1e12 and v<1e12
end
local function validate(v,w,h)
    assert(type(v)=='table' and finite(v.zoom) and v.zoom>0 and
        finite(v.rotation) and finite(v.panX) and finite(v.panY) and
        finite(v.width) and finite(v.height) and
        v.width>0 and v.height>0 and finite(w) and finite(h) and
        (v.focusMode==nil or type(v.focusMode)=='boolean') and
        (v.compactUi==nil or type(v.compactUi)=='boolean') and
        w>320 and h>100,'Estado de visualização inválido')
end
function View.center(v,w,h)
    validate(v,w,h)
    local cx,cy=Workspace.center(w,h,v.focusMode==true,v.compactUi==true)
    return cx+v.panX,cy+v.panY
end
function View.toCanvas(v,w,h,mx,my)
    validate(v,w,h)
    assert(finite(mx) and finite(my),'Posição da tela inválida')
    local cx,cy=View.center(v,w,h)
    local dx,dy=(mx-cx)/v.zoom,(my-cy)/v.zoom
    local ca,sa=math.cos(v.rotation),math.sin(v.rotation)
    return dx*ca+dy*sa+v.width/2,-dx*sa+dy*ca+v.height/2
end
function View.toScreen(v,w,h,x,y)
    validate(v,w,h)
    assert(finite(x) and finite(y),'Coordenada do desenho inválida')
    local dx,dy=x-v.width/2,y-v.height/2
    local ca,sa=math.cos(v.rotation),math.sin(v.rotation)
    local cx,cy=View.center(v,w,h)
    return cx+(dx*ca-dy*sa)*v.zoom,
           cy+(dx*sa+dy*ca)*v.zoom
end
local function anchorChange(v,w,h,sx,sy,update)
    local x,y=View.toCanvas(v,w,h,sx,sy)
    update()
    local nextX,nextY=View.toScreen(v,w,h,x,y)
    v.panX=v.panX+(sx-nextX)
    v.panY=v.panY+(sy-nextY)
end
function View.zoomAt(v,w,h,sx,sy,factor)
    validate(v,w,h)
    assert(finite(factor) and factor>0,'Fator de zoom inválido')
    local nextZoom=math.max(View.MIN_ZOOM,
        math.min(View.MAX_ZOOM,v.zoom*factor))
    if nextZoom==v.zoom then return false end
    anchorChange(v,w,h,sx,sy,function()v.zoom=nextZoom end)
    return true
end
function View.rotateAt(v,w,h,sx,sy,delta)
    validate(v,w,h)
    assert(finite(delta),'Rotação inválida')
    if delta==0 then return false end
    anchorChange(v,w,h,sx,sy,function()
        v.rotation=(v.rotation+delta+math.pi)%(2*math.pi)-math.pi
    end)
    return true
end
function View.resetRotation(v,w,h,sx,sy)
    validate(v,w,h)
    if v.rotation==0 then return false end
    anchorChange(v,w,h,sx,sy,function()v.rotation=0 end)
    return true
end
function View.pan(v,dx,dy)
    assert(finite(dx) and finite(dy) and finite(v.panX) and finite(v.panY),
        'Deslocamento inválido')
    v.panX=v.panX+dx
    v.panY=v.panY+dy
end
function View.fit(v,w,h)
    validate(v,w,h)
    local safeW=Workspace.fitWidth(w,v.focusMode==true)
    local safeH=math.max(1,h-(v.compactUi and 262 or 200))
    v.zoom=math.max(View.MIN_ZOOM,math.min(View.MAX_ZOOM,
        math.min(safeW/v.width,safeH/v.height)*0.84))
    v.panX=0;v.panY=0;v.rotation=0
end
return View
