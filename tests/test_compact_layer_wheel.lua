local Wheel=require('compact_layer_wheel')
local Compact=require('compact_layout')
local Thumbnails=require('layer_thumbnails')
local T={}
function T.run()
    local n=0
    local function check(v,msg)n=n+1;assert(v,msg)end
    for _,size in ipairs({{960,640},{1220,800},{1920,1080}}) do
        local w,h=size[1],size[2]
        local p=Compact.popup(w,h,'layers')
        local y=p.y+87+12
        check(Wheel.hit(w,h,p.x+17,y,8),'Thumbnail accepts wheel')
        check(Wheel.hit(w,h,p.x+264,y,8),'Eye action within rows')
        check(not Wheel.hit(w,h,p.x+16,p.y+60,8),
            'Top action buttons must not scroll layers')
        check(not Wheel.hit(w,h,p.x-4,y,8),
            'Canvas must not capture list scroll')
        check(not Wheel.hit(w,h,p.x+16,p.y+p.h-35,8),
            'Opacity slider must not scroll layers')
        check(not Wheel.hit(w,h,p.x+16,y+41,1),
            'Single layer has no extra row hitbox')
        local rows=Compact.layerRows(p)
        local first,_,maximum=Thumbnails.window(8,4,rows,1)
        check(Wheel.scroll(8,4,w,h,first,1)==math.min(maximum,first+1),
            'Upward wheel shows higher-index layers')
        check(Wheel.scroll(8,4,w,h,maximum,-1)==
            math.max(1,maximum-1),
            'Downward wheel shows lower-index layers')
        check(Wheel.scroll(8,4,w,h,first,0)==first,
            'Zero delta does not scroll')
        check(Wheel.scroll(8,4,w,h,first,100)==maximum and
            Wheel.scroll(8,4,w,h,maximum,-100)==1,
            'Large wheel deltas clamp to list bounds')
        check(Wheel.scroll(1,1,w,h,nil,1)==1,
            'Single layer remains at only row')
    end
    check(not Wheel.hit(960,640,0/0,250,8),
        'NaN horizontal pointer rejected')
    check(not Wheel.hit(960,640,800,0/0,8),
        'NaN vertical pointer rejected')
    check(not pcall(Wheel.scroll,8,4,960,640,1,0/0),
        'NaN delta rejected')
    check(not pcall(Wheel.scroll,8,4,960,640,1,math.huge),
        'Infinite delta rejected')
    return {suite='stage41-compact-layer-wheel',passed=true,
        assertions=n,selection_unchanged=true,canvas_untouched=true}
end
return T
