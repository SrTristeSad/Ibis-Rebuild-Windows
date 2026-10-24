-- LÖVE touch pressure normalization + actual compiled C++ stroke and RBD2.
local Pressure=require('touch_pressure')
local Native=require('native')
local Layers=require('layers')
local Store=require('store')
local T={}
function T.run(root)
    assert(Native.available,'Test requires the compiled Windows C++ DLL')
    local count=0
    local function check(ok,why) count=count+1;assert(ok,why) end
    for _,entry in ipairs({
        {input=0,expected=0},{input=.35,expected=.35},
        {input=1,expected=1},{input=-5,expected=0},
        {input=8,expected=1},{input=math.huge,expected=1},
        {input=-math.huge,expected=1},
    }) do
        check(Pressure.normalize(entry.input)==entry.expected,
            'Incorrect pressure normalization')
    end
    check(Pressure.normalize(nil)==1,'Absent pressure should be full strength')
    check(Pressure.normalize(0/0)==1,'NaN pressure must not propagate to C++')
    check(Pressure.normalize('bad')==1,'Non-numeric input must fall back')
    check(Pressure.diameter(10,0)==2.5,'Minimum width scaling wrong')
    check(Pressure.diameter(10,1)==10,'Maximum width scaling wrong')
    check(Pressure.opacity(.6,0)==.12,'Minimum opacity scaling wrong')
    check(Pressure.opacity(.6,1)==.6,'Maximum opacity scaling wrong')
    check(Pressure.diameter(1,0)==1,'Diameter minimum must be 1')
    check(not pcall(Pressure.diameter,0,1),'Invalid brush base accepted')
    check(not pcall(Pressure.opacity,1.1,.5),'Invalid base opacity accepted')

    local store=Store.open(root)
    local doc=store:createProject('Pressão de toque',32,12,'',
        string.rep('\0',32*12*4))
    local scene=Layers.open(store,store:openProject(doc.id))
    scene:pixel(4,9,0x00ff00ff)
    scene:add('Traço sob pressão')
    local color=0xe53b44ff
    scene:beginEdit()
    scene:stroke(5.5,4.5,5.5,4.5,Pressure.diameter(8,.2),color,
        Pressure.opacity(1,.2))
    check(scene:finishEdit(),'Light touch did not create a stroke')
    scene:beginEdit()
    scene:stroke(20.5,4.5,20.5,4.5,Pressure.diameter(8,1),color,
        Pressure.opacity(1,1))
    check(scene:finishEdit(),'Strong touch did not create a stroke')
    local low=Native.readPixel(scene:activeBuffer(),5,4)
    local high=Native.readPixel(scene:activeBuffer(),20,4)
    check(low%256>0 and low%256<high%256,
        'Real C++ alpha does not respond to touch pressure')
    check(high%256==255,'Full-pressure core did not paint opaque pixels')
    check(Native.readPixel(scene:activeBuffer(),23,4)%256>0,
        'Full pressure did not expand the brush radius')
    check(Native.readPixel(scene:activeBuffer(),8,4)==0,
        'Light pressure incorrectly used full brush radius')
    check(Native.readPixel(scene.buffers[1],4,9)==0x00ff00ff,
        'Pressure stroke modified background layer')
    check(scene:historyStats().undo==2,'Touches should form individual history entries')
    check(scene:undo(),'Strong-touch undo failed')
    check(Native.readPixel(scene:activeBuffer(),20,4)==0,
        'Undo left strong-pressure stroke')
    check(scene:redo(),'Strong-touch redo failed')
    check(Native.readPixel(scene:activeBuffer(),20,4)==high,
        'Redo did not recover pressure-dependent alpha')
    scene:save()
    local restored=Store.open(root):openProject(doc.id)
    check(restored.format==2 and restored.layer_count==2,
        'Pressure added incompatible RBD2 metadata')
    local again=Layers.open(Store.open(root),restored)
    check(Native.readPixel(again:activeBuffer(),5,4)==low,
        'Light pressure alpha did not persist')
    check(Native.readPixel(again:activeBuffer(),20,4)==high,
        'Strong pressure alpha did not persist')
    check(Native.readPixel(again.buffers[1],4,9)==0x00ff00ff,
        'Background layer damaged by pressure roundtrip')
    check(not again:canUndo(),'Session history leaked into RBD2')
    return {suite='touch-pressure-rbd2',passed=true,assertions=count,
        pressure_levels=true,touch_width=true,touch_opacity=true,
        undo_redo=true,rbd2_roundtrip=true,
        scope='LÖVE pressure event path; real Windows pen drivers not verified'}
end
return T
