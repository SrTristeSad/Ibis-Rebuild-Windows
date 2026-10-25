local Rail=require('desktop_layer_opacity')
local Sidebar=require('sidebar_scroll')
local T={}
function T.run()
    local count=0
    local function check(v,msg) count=count+1;assert(v,msg) end
    for _,viewport in ipairs({{960,640},{1220,800},{1920,1080}}) do
        local w,h=viewport[1],viewport[2]
        local scroll=Sidebar.max(h)
        local r=Rail.rect(w,h)
        local screenY=r.y-scroll+2
        check(Sidebar.contains(w,h,r.x,screenY),
            'Scrolled opacity rail must remain inside sidebar viewport')
        check(Rail.hit(w,h,r.x,screenY,scroll) and
            Rail.hit(w,h,r.x+r.w,screenY,scroll),
            'Rail endpoints must be clickable')
        check(not Rail.hit(w,h,r.x-30,screenY,scroll) and
            not Rail.hit(w,h,r.x+20,screenY-38,scroll) and
            not Rail.hit(w,h,w-280,screenY,scroll),
            'Rail cannot capture buttons or the canvas')
        check(Rail.value(w,h,r.x-200)==0 and
            Rail.value(w,h,r.x+r.w+200)==1,'Rail clamps to legal opacity')
        check(Rail.value(w,h,r.x+r.w*.37)==.37,
            'Rail maps pointer to one-percent increments')
        local old=-1
        for i=0,100 do
            local v=Rail.value(w,h,r.x+r.w*i/100)
            check(v>=old and v<=1,'Opacity track must be monotonic')
            old=v
        end
    end
    check(not Rail.hit(960,640,0/0,550,160),'NaN must not capture')
    check(not Rail.hit(960,640,710,0/0,160),'NaN y must not capture')
    local draft=Rail.draft(2,1,.37)
    check(draft.index==2 and draft.initial==1 and
        draft.value==.37 and Rail.changed(draft),'Draft stores original value')
    check(not Rail.changed(Rail.draft(1,.5,.5)),
        'No-op release creates no metadata entry')
    check(not pcall(Rail.draft,9,.5,.4),'Invalid layer rejected')
    return {suite='desktop-layer-opacity',passed=true,
        assertions=count,scrolled_960x640=true,
        single_commit_on_release=true}
end
return T
