-- Deterministic mouse input stabilization + actual native raster RBD2 lifecycle.
local Smooth=require('stroke_stabilizer')
local Native=require('native')
local Layers=require('layers')
local Store=require('store')
local T={}
function T.run(root)
    local checks=0
    local function check(v,why) checks=checks+1; assert(v,why) end
    for level=0,5 do
        local smooth=Smooth.new(level,2,3)
        local x,y=smooth:sample(8,9)
        local alpha=1/(level+1)
        check(math.abs(x-(2+6*alpha))<0.00001,'Filter X did not match strength')
        check(math.abs(y-(3+6*alpha))<0.00001,'Filter Y did not match strength')
        local x2,y2=smooth:sample(12,9)
        check(x2>=x and x2<=12 and y2>=y and y2<=9,
            'Stabilizer advanced beyond raw point')
        local fx,fy=smooth:finish()
        check(fx==12 and fy==9,'Final endpoint must equal actual raw mouse')
        check(not pcall(function()smooth:sample(13,14)end),
            'Finalized brush accepted another sample')
        check(not pcall(function()smooth:finish()end),
            'Finalized brush accepted second finish')
    end
    for _,bad in ipairs({-1,6,0.4,math.huge}) do
        check(not pcall(Smooth.new,bad,0,0),'Invalid smoothing level accepted')
    end
    check(not pcall(Smooth.new,3,math.huge,1),'Infinite origin accepted')
    check(not pcall(Smooth.new,3,0/0,1),'NaN origin accepted')
    local s=Smooth.new(0,1,2)
    local x,y=s:sample(23,10)
    check(x==23 and y==10,'Stabilizer level zero altered raw samples')
    local stop=Smooth.new(5,1,1)
    check(stop:finish()==1,'Tap ending without move must preserve coordinate')
    local store=Store.open(root)
    local doc=store:createProject('Traço estabilizado',36,18,'',
        string.rep('\0',36*18*4))
    local session=Layers.open(store,store:openProject(doc.id))
    session:pixel(10,10,0x00ff00ff)
    session:add('Traço')
    local stroke=Smooth.new(4,4.5,8.5)
    session:beginEdit()
    session:stroke(4.5,8.5,4.5,8.5,2,0xe53b44ff,1)
    local px,py=4.5,8.5
    local samples={{10.5,8.5},{15.5,8.5},{18.5,8.5},{24.5,8.5}}
    for _,xy in ipairs(samples) do
        local nextX,nextY=stroke:sample(xy[1],xy[2])
        check(nextX<=xy[1] and nextX>=px,'Smoothed point overtook raw mouse')
        session:stroke(px,py,nextX,nextY,2,0xe53b44ff,1)
        px,py=nextX,nextY
    end
    check(px<24.5,'Filter did not lag jittered mouse path')
    local ex,ey=stroke:finish()
    session:stroke(px,py,ex,ey,2,0xe53b44ff,1)
    check(session:finishEdit(),'Native stabilizer session produced no pixels')
    check(Native.readPixel(session:activeBuffer(),24,8)==0xe53b44ff,
        'Release cursor endpoint not rasterized by C++')
    check(Native.readPixel(session.buffers[1],10,10)==0x00ff00ff,
        'Active painting leaked to lower layer')
    check(session:historyStats().undo==1,'Filtered path must be one undo item')
    check(session:undo(),'Filtered brush undo failed')
    check(Native.readPixel(session.composite,24,8)==0,
        'Undo left final raster endpoint')
    check(session:redo(),'Filtered brush redo failed')
    check(Native.readPixel(session:activeBuffer(),24,8)==0xe53b44ff,
        'Redo lost exact final raster endpoint')
    session:save()
    local reopened=Store.open(root):openProject(doc.id)
    check(reopened.format==2 and reopened.layer_count==2,
        'Stabilization illegally changed RBD2 format')
    local active=Layers.open(Store.open(root),reopened)
    check(Native.readPixel(active.composite,24,8)==0xe53b44ff,
        'RBD2 roundtrip lost stabilized endpoint')
    check(Native.readPixel(active.buffers[1],10,10)==0x00ff00ff,
        'RBD2 roundtrip corrupted other layer')
    check(not active:canUndo(),'In-memory undo should not be persisted')
    return {suite='stabilized-mouse-rbd2',passed=true,assertions=checks,
        raw_mode=true,level_bounds=true,endpoint_exact=true,
        native_cpp_raster=true,undo_redo=true,rbd2_roundtrip=true}
end
return T
