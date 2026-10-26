-- Stage 46: geometry, pressure bounds, rate-independent straight segments
-- and native one-edit integration with persistent raster layers.
local Path=require('stroke_path')
local T={}
local function near(a,b) return math.abs(a-b)<0.0001 end
function T.run()
    local checks=0
    local function check(ok,msg) checks=checks+1;assert(ok,msg) end
    local points={}
    local function collect(x,y,p)
        points[#points+1]={x=x,y=y,p=p}
    end
    local line=Path.new(4.5,6.5,.2)
    check(line:sample(1004.5,6.5,.8,collect)==1,
        'A straight fast move must require only one native segment')
    check(near(points[1].x,504.5) and near(points[1].y,6.5)
        and near(points[1].p,.5),'First midpoint/pressure wrong')
    check(line:finish(1004.5,6.5,.8,collect)==1,
        'Release should close a straight line in one segment')
    check(near(points[#points].x,1004.5)
        and near(points[#points].p,.8),
        'Release must retain the exact raw point and pressure')
    check(not pcall(function()line:sample(1005,6.5,.8,collect)end),
        'Finished path accepted more packets')
    check(not pcall(function()line:finish(nil,nil,nil,collect)end),
        'Finished path accepted another release')
    local bend=Path.new(0,0,.1)
    local bent={}
    local function record(x,y,p) bent[#bent+1]={x=x,y=y,p=p} end
    bend:sample(40,0,.3,record)
    local before=#bent
    local steps=bend:sample(40,40,.9,record)
    check(steps>1 and steps<=12,
        'Right-angle bend must adaptively subdivide')
    check(#bent==before+steps,'Curve callback count differs from step count')
    check(bent[before+1].x>20 and bent[before+1].y>=0,
        'Curve skipped its incoming tangent')
    check(near(bent[#bent].x,40) and near(bent[#bent].y,20),
        'Curve midpoint endpoint incorrect')
    for _,v in ipairs(bent) do
        check(v.p>=.1 and v.p<=.9 and
            v.x>=0 and v.x<=40 and v.y>=0 and v.y<=40,
            'Quadratic must not overshoot geometry or pressure')
    end
    bend:finish(40,40,.9,record)
    check(near(bent[#bent].x,40) and near(bent[#bent].y,40)
        and near(bent[#bent].p,.9),
        'Curved stroke did not finish at the raw endpoint')
    local fast=Path.new(-10000,-10000,0)
    local n=fast:sample(10000,-10000,1,function()end)
    check(n==1,'Long straight high-speed path grew with distance')
    n=fast:sample(10000,10000,1,function()end)
    check(n>=1 and n<=12,'High-curvature work exceeded packet cap')
    check(fast:finish(nil,nil,nil,function()end)<=12,
        'Final high-speed tail exceeded cap')
    local duplicate=Path.new(3,5,.2)
    check(duplicate:sample(3,5,.7,collect)==0,
        'Stationary pressure packet must not repaint the tip')
    check(duplicate:finish(nil,nil,nil,collect)==0,
        'Stationary release must not repaint the initial dot')
    check(not pcall(Path.new,math.huge,0,.5),
        'Infinite coordinate accepted')
    check(not pcall(Path.new,0,0,1.01),'Invalid pressure accepted')
    check(not pcall(function()
        Path.new(0,0,.4):sample(0/0,0,.5,collect)
    end),'NaN packet accepted')
    return {suite='curved-spatial-resampling',passed=true,
        assertions=checks,adaptive=true,straight_constant_work=true,
        exact_release=true,pressure_bounded=true}
end
function T.runNative(root)
    local Native=require('native')
    local Store=require('store')
    local Layers=require('layers')
    assert(Native.available,'Native C++ required for curve integration')
    local store=Store.open(root)
    local doc=store:createProject('Curvas rápidas',128,88,'',
        string.rep('\0',128*88*4))
    local session=Layers.open(store,store:openProject(doc.id))
    local path=Path.new(10.5,10.5,.3)
    local lastX,lastY,lastP=10.5,10.5,.3
    local color=0x37a4ddff
    local function paint(x,y,p)
        session:pressureStroke(lastX,lastY,x,y,5,5,color,
            lastP,p,1,0,0,0,true)
        lastX=x;lastY=y;lastP=p
    end
    session:beginEdit()
    session:stroke(10.5,10.5,10.5,10.5,5,color,.3)
    path:sample(95.5,10.5,.7,paint)
    session:recompose()
    path:sample(95.5,70.5,1,paint)
    session:recompose()
    path:finish(95.5,70.5,1,paint)
    session:recompose()
    assert(session:finishEdit(),'Path did not create one native edit')
    assert(Native.readPixel(session:activeBuffer(),95,70)%256>0,
        'Curved path lost the true release endpoint')
    assert(session:historyStats().undo==1,
        'Multiple subsegments must remain one undo item')
    local raster=Native.bytes(session:activeBuffer())
    assert(session:undo(),'Curved native path undo failed')
    assert(Native.readPixel(session:activeBuffer(),95,70)==0,
        'Undo retained the final pixel')
    assert(session:redo() and Native.bytes(session:activeBuffer())==raster,
        'Redo did not restore byte-exact curved path')
    session:save()
    local fresh=Store.open(root)
    local reopened=Layers.open(fresh,fresh:openProject(doc.id))
    assert(Native.bytes(reopened:activeBuffer())==raster,
        'RBD2 did not preserve curved native path')
    return {suite='native-curved-spatial-rbd2',passed=true,
        undo_redo=true,rbd2_roundtrip=true,exact_release=true}
end
return T
