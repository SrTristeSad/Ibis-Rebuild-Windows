-- Pure viewport transformations, tested without graphics or any raster mutation.
local View=require('canvas_view')
local T={}
function T.run()
    local assertions=0
    local function check(ok,message)assertions=assertions+1;assert(ok,message)end
    local function approx(a,b,why)
        check(math.abs(a-b)<1e-6,why..' '..tostring(a)..' != '..tostring(b))
    end
    local v={zoom=1,rotation=0,panX=0,panY=0,width=512,height=300}
    local w,h=1220,800
    local mx,my=367.25,254.75
    local a,b=View.toCanvas(v,w,h,mx,my)
    local sx,sy=View.toScreen(v,w,h,a,b)
    approx(mx,sx,'Unrotated inverse X')
    approx(my,sy,'Unrotated inverse Y')
    check(View.zoomAt(v,w,h,mx,my,2),'Zoom should modify view')
    sx,sy=View.toScreen(v,w,h,a,b)
    approx(mx,sx,'Cursor-anchored zoom X')
    approx(my,sy,'Cursor-anchored zoom Y')
    check(View.rotateAt(v,w,h,mx,my,math.pi/4),'Rotation should modify view')
    sx,sy=View.toScreen(v,w,h,a,b)
    approx(mx,sx,'Cursor-anchored rotation X')
    approx(my,sy,'Cursor-anchored rotation Y')
    local cx,cy=View.toCanvas(v,w,h,mx,my)
    approx(a,cx,'Rotated inverse X')
    approx(b,cy,'Rotated inverse Y')
    check(View.zoomAt(v,w,h,mx,my,.5),'Reverse zoom should work')
    sx,sy=View.toScreen(v,w,h,a,b)
    approx(mx,sx,'Reverse cursor zoom X')
    approx(my,sy,'Reverse cursor zoom Y')
    check(View.resetRotation(v,w,h,mx,my),'Reset rotation should modify view')
    approx(v.rotation,0,'Reset rotation should be zero')
    sx,sy=View.toScreen(v,w,h,a,b)
    approx(mx,sx,'Cursor anchored rotation reset X')
    approx(my,sy,'Cursor anchored rotation reset Y')
    check(not View.resetRotation(v,w,h,mx,my),'Second reset is no-op')
    local px,py=v.panX,v.panY
    View.pan(v,31,-17)
    approx(v.panX,px+31,'Pan X')
    approx(v.panY,py-17,'Pan Y')
    local qx,qy=View.toScreen(v,w,h,a,b)
    approx(qx,mx+31,'Pan screen delta X')
    approx(qy,my-17,'Pan screen delta Y')
    check(not pcall(View.pan,v,0/0,1),'Reject NaN without mutating pan')
    approx(v.panX,px+31,'Atomic invalid pan X')
    approx(v.panY,py-17,'Atomic invalid pan Y')
    check(not pcall(View.zoomAt,v,w,h,mx,my,-1),'Reject negative zoom')
    check(not pcall(View.rotateAt,v,w,h,mx,my,math.huge),'Reject infinite rotation')
    local before=v.zoom
    check(not View.zoomAt(v,w,h,mx,my,1),'Unity scale should not mutate view')
    approx(v.zoom,before,'Unity scale no-op')
    for i=1,18 do View.zoomAt(v,w,h,mx,my,2) end
    approx(v.zoom,View.MAX_ZOOM,'Zoom upper clamp')
    check(not View.zoomAt(v,w,h,mx,my,2),'Max zoom no-op')
    for i=1,18 do View.zoomAt(v,w,h,mx,my,.5) end
    approx(v.zoom,View.MIN_ZOOM,'Zoom lower clamp')
    check(not View.zoomAt(v,w,h,mx,my,.5),'Min zoom no-op')
    View.fit(v,w,h)
    approx(v.panX,0,'Fit clears X pan')
    approx(v.panY,0,'Fit clears Y pan')
    approx(v.rotation,0,'Fit resets rotation')
    check(v.zoom>=View.MIN_ZOOM and v.zoom<=View.MAX_ZOOM,'Fit zoom bounded')
    local centerX,centerY=View.center(v,w,h)
    approx(centerX,(w-280)/2,'Fit screen center X')
    approx(centerY,(h+56)/2,'Fit screen center Y')
    -- Expected same object coordinate under cursor after zoom + rotation even
    -- at negative rotation and at 2048 x 2048 dimensions.
    v.width=2048;v.height=2048;View.fit(v,960,640)
    View.rotateAt(v,960,640,85,490,-math.pi*0.8)
    local aa,bb=View.toCanvas(v,960,640,85,490)
    View.zoomAt(v,960,640,85,490,1.3)
    local xx,yy=View.toScreen(v,960,640,aa,bb)
    approx(xx,85,'Small window zoom anchor X')
    approx(yy,490,'Small window zoom anchor Y')
    return {suite='canvas-view-math',passed=true,assertions=assertions,
        invertible=true,cursor_anchor=true,rotation_anchor=true,
        bounds=true,pan_only=true,fit=true}
end
return T
