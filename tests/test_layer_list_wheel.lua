local Wheel=require('layer_list_wheel')
local Sidebar=require('sidebar_scroll')
local Thumbnails=require('layer_thumbnails')
local T={}
function T.run()
    local n=0
    local function check(v,msg)n=n+1;assert(v,msg)end
    for _,size in ipairs({{960,640},{1220,800},{1920,1080}}) do
        local w,h=size[1],size[2]
        local scroll=Sidebar.max(h)
        local virtualHeight=Sidebar.virtualHeight(h)
        local rows=Thumbnails.rows(virtualHeight)
        local listY=Wheel.TOP-scroll+8
        local panel=w-Sidebar.WIDTH
        check(Wheel.hit(w,h,panel+30,listY,scroll),
            'List row is accessible in this viewport')
        check(Wheel.hit(w,h,panel+232,listY,scroll),
            'List eye icon remains within list region')
        check(not Wheel.hit(w,h,panel+30,listY-45,scroll),
            'Layer action buttons are not list rows')
        check(not Wheel.hit(w,h,panel-5,listY,scroll),
            'Canvas must not scroll layers')
        check(not Wheel.hit(w,h,panel+30,h-20,scroll),
            'Footer must not scroll layers')
        check(not Wheel.hit(w,h,panel+30,
            Wheel.TOP+rows*Wheel.ROW_HEIGHT-scroll+2,scroll),
            'Area after last row must not capture layer scroll')
        local start,_,maxStart=Thumbnails.window(8,4,rows,nil)
        check(Wheel.scroll(8,4,h,start,1)==
            math.min(maxStart,start+1),
            'Up wheel moves list toward higher indexed layers')
        check(Wheel.scroll(8,4,h,start,-1)==
            math.max(1,start-1),
            'Down wheel moves list toward lower indexed layers')
        check(Wheel.scroll(8,4,h,start,0)==start,
            'Zero wheel displacement is inert')
        check(Wheel.scroll(8,4,h,start,999)==maxStart and
            Wheel.scroll(8,4,h,start,-999)==1,
            'Large mouse wheels clamp to valid range')
        check(Wheel.scroll(1,1,h,nil,1)==1,
            'Single layer cannot scroll')
    end
    check(not Wheel.hit(960,640,0/0,400,160),
        'NaN pointer cannot capture layers')
    check(not Wheel.hit(960,640,760,0/0,160),
        'NaN vertical pointer cannot capture layers')
    check(not pcall(Wheel.scroll,4,1,640,nil,0/0),
        'NaN wheel delta rejected')
    check(not pcall(Wheel.scroll,4,1,640,nil,math.huge),
        'Infinite wheel delta rejected')
    return {suite='layer-list-wheel-stage40',passed=true,
        assertions=n,sidebar_independent=true,selection_unchanged=true}
end
return T
