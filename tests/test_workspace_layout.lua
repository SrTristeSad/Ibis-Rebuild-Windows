-- Headless focus-mode layout/view invariants; no graphics or raster.
local W=require('workspace_layout')
local View=require('canvas_view')
local T={}
function T.run()
    local n=0
    local function ok(value,why)n=n+1;assert(value,why)end
    local function near(x,y,why)
        ok(math.abs(x-y)<1e-7,why..': '..tostring(x)..' ~= '..tostring(y))
    end
    for _,sz in ipairs({{960,640},{1220,800},{1920,1080}}) do
        local w,h=sz[1],sz[2]
        ok(W.panelWidth(false)==268 and W.panelWidth(true)==0,
            'Only side-panel width should change')
        local normal=W.bounds(w,h,false)
        local focus=W.bounds(w,h,true)
        ok(normal.right==w-280 and focus.right==w-16,
            'Focus must expand the interactive right edge')
        ok(normal.left==focus.left and normal.top==focus.top and
            normal.bottom==focus.bottom,'Focus must not move other bounds')
        ok(W.contains(w,h,true,w-100,180) and
            not W.contains(w,h,false,w-100,180),
            'Area formerly occupied by pane should be canvas in focus')
        ok(not W.contains(w,h,true,15,180) and
            not W.contains(w,h,true,w-15,180),
            'Canvas must respect side margins')
        local x,y,sw,sh=W.scissor(w,h,true)
        ok(x==focus.left and y==focus.top and
            sw==focus.right-focus.left and sh==focus.bottom-focus.top,
            'Scissor and input bounds must be congruent')
        local base={width=300,height=200,zoom=1,rotation=.3,panX=37,
            panY=-12,focusMode=false}
        local origX,origY=View.center(base,w,h)
        near(origX,(w-280)/2+37,'Legacy center must not shift')
        near(origY,(h+56)/2-12,'Legacy vertical center')
        local sx,sy=View.toScreen(base,w,h,155,80)
        base.focusMode=true
        local newX,newY=View.center(base,w,h)
        near(newX-origX,134,'Canvas recenters as pane hides')
        near(newY-origY,0,'Focus must not move canvas vertically')
        near(View.toScreen(base,w,h,155,80),sx+134,
            'Scene coordinate must shift only by viewport-center delta')
        local cx,cy=View.toCanvas(base,w,h,sx+134,sy)
        near(cx,155,'Focused inverse transform X')
        near(cy,80,'Focused inverse transform Y')
        local ax,ay=w-100,h/2
        local docX,docY=View.toCanvas(base,w,h,ax,ay)
        ok(View.zoomAt(base,w,h,ax,ay,1.3),'Focus zoom must work')
        local tx,ty=View.toScreen(base,w,h,docX,docY)
        near(tx,ax,'Focus zoom anchor X')
        near(ty,ay,'Focus zoom anchor Y')
        View.fit(base,w,h)
        local focusZoom=base.zoom
        base.focusMode=false
        View.fit(base,w,h)
        ok(focusZoom>=base.zoom,
            'Fitting the same canvas should not shrink in focus mode')
    end
    ok(not pcall(W.panelWidth,'yes'),'Non-boolean focus rejected')
    ok(not pcall(W.bounds,800,600,false),'Invalid geometry rejected')
    return {suite='focus-workspace-layout',passed=true,assertions=n,
        expanded_canvas=true,invertible_focus=true,legacy_geometry=true,
        focus_zoom_anchor=true}
end
return T
