-- Exact native single-dab preview and pure workspace visibility regression.
-- Scratch buffers are unrelated to any Layers session or RBD2 project.
local Native=require('native')
local Tip=require('brush_cursor')
local View=require('canvas_view')
local Test={}
function Test.run()
    assert(Native.available,'Stage 30 must test the real C++ renderer')
    local checks=0
    local function check(v,why)checks=checks+1;assert(v,why)end
    local cases={
        {'brush',12,1,0xe53b44ff,'hard',1,0,0,false},
        {'brush',40,.4,0x347ce9ff,'soft',1,0,0,false},
        {'brush',18,.7,0x20ba84ff,'soft',.5,0,0,false},
        {'brush',18,.9,0x192d40ff,'hard',1,32,-18,true},
        {'erase',24,.6,0xffaaccff,'hard',1,0,0,false},
        {'brush',1,.1,0xffffffff,'hard',1,0,0,false},
        {'brush',256,1,0xffffffff,'hard',1,0,0,false}
    }
    for _,args in ipairs(cases) do
        local o=Tip.options(unpack(args))
        local stamp=Tip.render(Native,o)
        check(stamp.size>=24 and stamp.size<=640 and
            stamp.buffer.width==stamp.size,'Native scratch size invalid')
        local manual=Native.buffer(stamp.size,stamp.size)
        Native.clear(manual,0)
        local c=stamp.center
        if o.tilted then
            Native.tiltStroke(manual,c,c,c,c,o.diameter,o.color,
                o.opacity,o.style=='soft' and .25 or 1,o.tiltX,o.tiltY)
        elseif o.tool=='brush' and o.style=='soft' then
            Native.featherStroke(manual,c,c,c,c,o.diameter,
                o.color,o.opacity,.25)
        else
            Native.basicStroke(manual,c,c,c,c,o.diameter,o.color,o.opacity)
        end
        check(Native.bytes(manual)==Native.bytes(stamp.buffer),
            'Preview must be byte-identical to actual native dab')
        check(Native.readPixel(stamp.buffer,math.floor(c),math.floor(c))%256>0,
            'Dab center must have alpha')
        check(Native.readPixel(stamp.buffer,0,0)==0,
            'Preview edges must stay transparent')
        check(stamp.key==Tip.key(o),'Stable scratch cache key')
        if o.tool=='erase' then
            check(o.color==0xffffffff,'Eraser must show a white mask')
            local opaque=Native.buffer(stamp.size,stamp.size)
            Native.clear(opaque,0xffffffff)
            Native.basicErase(opaque,c,c,c,c,o.diameter,o.opacity)
            local newAlpha=Native.readPixel(opaque,math.floor(c),
                math.floor(c))%256
            check(newAlpha<255,'Real native erase must affect original raster')
        end
    end
    local same=Tip.options('brush',12,1,0xe53b44ff,'hard',1)
    local changed=Tip.options('brush',12,.9,0xe53b44ff,'hard',1)
    check(Tip.key(same)~=Tip.key(changed),
        'Cache must invalidate when paint settings change')
    check(not pcall(Tip.options,'fill',12,1,0xffffffff,'hard',1),
        'Invalid tool rejected')
    check(not pcall(Tip.options,'brush',500,1,0xffffffff,'hard',1),
        'Invalid diameter rejected')
    local state={screen='editor',previewEnabled=true,tool='brush',
        doc={width=512,height=512},zoom=.8,rotation=.2,
        panX=0,panY=0,focusMode=false}
    local w,h=1220,800
    local cx,cy=View.center({width=512,height=512,zoom=.8,
        rotation=.2,panX=0,panY=0,focusMode=false},w,h)
    local visible,x,y=Tip.visible(state,w,h,cx,cy)
    check(visible and math.abs(x-256)<1e-6 and
        math.abs(y-256)<1e-6,'Canvas transform must locate preview center')
    local hidden={'modal','toolHelp','brushLibrary','contextMenu',
        'panning','drawing','sliderDrag','spaceHeld','mouseOutside'}
    for _,key in ipairs(hidden) do
        state[key]=true
        check(not Tip.visible(state,w,h,cx,cy),
            'Preview shown in blocking mode: '..key)
        state[key]=nil
    end
    state.inkPenId=31
    check(not Tip.visible(state,w,h,cx,cy),
        'Pen contact must not show stale mouse preview')
    state.inkPenId=nil
    state.touchId='finger'
    check(not Tip.visible(state,w,h,cx,cy),
        'Touch contact must not show stale mouse preview')
    state.touchId=nil
    check(not Tip.visible(state,w,h,15,120),
        'Preview must be clipped outside workspace bounds')
    state.previewEnabled=false
    check(not Tip.visible(state,w,h,cx,cy),'Toggle must hide preview')
    state.previewEnabled=true
    state.tool='fill'
    check(not Tip.visible(state,w,h,cx,cy),'Fill must hide tip preview')
    state.tool='erase';state.focusMode=true
    cx,cy=View.center({width=512,height=512,zoom=.8,
        rotation=.2,panX=0,panY=0,focusMode=true},w,h)
    check(Tip.visible(state,w,h,cx,cy),
        'Focus-mode eraser must display native tip')
    return {suite='native-brush-tip-cursor',passed=true,
        assertions=checks,native_pixel_equal=true,
        scratch_only=true,view_transforms=true,
        modal_and_focus_isolation=true}
end
return Test
