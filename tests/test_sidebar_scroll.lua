local Sidebar=require('sidebar_scroll')
local T={}
function T.run()
    local count=0
    local function check(ok,msg)count=count+1;assert(ok,msg)end
    for _,height in ipairs({640,700,799,800,900,1080}) do
        local max=Sidebar.max(height)
        check(max==math.max(0,800-height),'Sidebar offset range')
        local p=Sidebar.viewport(height)
        check(p.top==64 and p.bottom==height-48 and
            p.height==height-112,'Viewport excludes top bar and footer')
        check(Sidebar.clamp(height,-100)==0 and
            Sidebar.clamp(height,500)==max,'Offset clamps to viewport')
        check(Sidebar.virtualHeight(height)==math.max(height,800),
            'Virtual controls must fit 800px')
        check(Sidebar.contains(960,height,950,80) and
            not Sidebar.contains(960,height,691,80) and
            not Sidebar.contains(960,height,950,height-24),
            'Scrolling must not capture canvas or footer')
        local thumb=Sidebar.thumb(960,height,max)
        if max>0 then
            check(thumb~=nil and thumb.y+thumb.h<=height-48 and
                thumb.y>=64 and thumb.w==5,'Scroll thumb must fit')
            local bottom=Sidebar.visible(height,max,705,29)
            check(bottom and bottom.y>=64 and
                bottom.y+bottom.h<=height-48,
                'Bottom stabilization adjustment must be reachable')
            local upper=Sidebar.visible(height,max,115,30)
            check(not upper or upper.y>=64,
                'Top project controls must be clipped')
        else
            check(thumb==nil,'Scrollbar must vanish on tall desktop')
        end
    end
    local height=640
    local offset=Sidebar.max(height)
    local bottom=Sidebar.visible(height,offset,705,29)
    check(bottom and math.abs(bottom.y-545)<1e-8 and
        bottom.h==29,'640px stabilized slider pixel position')
    check(Sidebar.pointerY(bottom.y,offset)==705,
        'Pointer-to-virtual-y mapping')
    check(not Sidebar.visible(640,160,100,40),
        'Hidden top buttons must not be clickable')
    local cut=Sidebar.visible(640,160,210,40)
    check(cut and cut.y==64 and cut.h==26,
        'Partially clipped buttons must have reduced hit box')
    check(not Sidebar.visible(640,0,640,32),
        'Offscreen bottom button must be inert')
    check(not pcall(Sidebar.clamp,640,0/0),
        'Invalid floating-point offset must be rejected')
    return {suite='stage39-adaptive-sidebar',passed=true,
        assertions=count,small_960x640_safe=true,
        virtual_sliders_reachable=true,
        clipped_buttons_inert=true,
        canvas_bounds_unchanged=true}
end
return T
