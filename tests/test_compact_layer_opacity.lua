-- Precise compact layer opacity controls: pure geometry and draft contract.
local Rail=require('compact_layer_opacity')
local Compact=require('compact_layout')
local T={}
function T.run()
    local count=0
    local function check(value,msg) count=count+1;assert(value,msg) end
    for _,size in ipairs({{960,640},{1220,800},{1920,1080}}) do
        local w,h=size[1],size[2]
        local popup=Compact.popup(w,h,'layers')
        local r=Rail.rect(popup)
        check(r.x>=popup.x+13 and r.x+r.w<=popup.x+181 and
            r.y>popup.y+popup.h-49 and
            r.y+r.h<=popup.y+popup.h-3,
            'Opacity rail must fit below label, left of +/- buttons')
        check(Rail.hit(popup,r.x,r.y+6) and
            Rail.hit(popup,r.x+r.w,r.y+6),
            'Opacity slider endpoints must be clickable')
        check(not Rail.hit(popup,r.x+r.w+24,r.y+6) and
            not Rail.hit(popup,r.x+40,r.y-36),
            'Opacity slider cannot steal +/- button or list clicks')
        check(Rail.value(popup,r.x-100)==0 and
            Rail.value(popup,r.x+r.w+100)==1,
            'Slider clamps to 0% and 100%')
        check(Rail.value(popup,r.x+r.w*.37)==.37,
            'Exact 37% must be represented')
        local last=-1
        for i=0,100 do
            local v=Rail.value(popup,r.x+r.w*i/100)
            check(v>=last and v>=0 and v<=1 and
                math.abs(v*100-math.floor(v*100+.5))<1e-8,
                'Every percent must be bounded and monotonic')
            last=v
        end
    end
    local draft=Rail.draft(2,1,.37)
    check(draft.index==2 and draft.initial==1 and
        draft.value==.37 and Rail.changed(draft),
        'Draft must retain original value and layer identity')
    check(not Rail.changed(Rail.draft(1,.55,.55)),
        'No-op drag should create no metadata history')
    check(not pcall(Rail.draft,0,.5,.4) and
        not pcall(Rail.draft,9,.5,.4),
        'Draft cannot target nonexistent layers')
    check(not pcall(Rail.fraction,1.1) and
        not pcall(Rail.fraction,-.1),
        'Opacity values must remain in legal range')
    check(not Rail.hit(Compact.popup(960,640,'layers'),0/0,300),
        'NaN pointer cannot capture a slider')
    return {suite='compact-layer-opacity',passed=true,
        assertions=count,one_percent_precision=true,
        button_hits_preserved=true,draft_no_history=true,
        popup_960x640_safe=true}
end
return T
