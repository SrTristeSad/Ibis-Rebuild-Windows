local Sliders=require('brush_sliders')
local T={}
function T.run()
    local checks=0
    local function check(ok,message)
        checks=checks+1;assert(ok,message)
    end
    local panel=1220-268
    local specs={
        {id='diameter',lo=1,hi=256},
        {id='opacity',lo=.1,hi=1},
        {id='stabilization',lo=0,hi=5},
        {id='tolerance',lo=0,hi=255}
    }
    for _,entry in ipairs(specs) do
        local rail=Sliders.rail(entry.id,panel)
        check(rail.x==panel+72 and rail.w==105,'Stable centered rail')
        check(Sliders.hit(entry.id,panel,rail.x,rail.y+rail.h/2),
            'Slider target must accept center press')
        check(not Sliders.hit(entry.id,panel,rail.x,rail.y+rail.h+20),
            'Slider target must reject outside row')
        local a=Sliders.value(entry.id,rail.x-10000,panel)
        local b=Sliders.value(entry.id,rail.x+rail.w+10000,panel)
        check(a==entry.lo and b==entry.hi,'Drag must clamp both ends')
        local mid=Sliders.value(entry.id,rail.x+rail.w*.5,panel)
        check(mid>=entry.lo and mid<=entry.hi,'Middle position out of range')
        local prev=entry.lo
        for i=0,105 do
            local value=Sliders.value(entry.id,rail.x+i,panel)
            check(value>=prev,'Slider must increase monotonically')
            check(value>=entry.lo and value<=entry.hi,
                'Slider value must stay in native range')
            prev=value
        end
        check(Sliders.fraction(entry.id,entry.lo)==0,
            'Slider start does not match the minimum')
        check(Sliders.fraction(entry.id,entry.hi)==1,
            'Slider end does not match the maximum')
    end
    local r=Sliders.rail('opacity',panel)
    local value=Sliders.value('opacity',r.x+r.w/2,panel)
    check(value==.55,'Opacity must quantize in 1% increments')
    check(Sliders.value('diameter',Sliders.rail('diameter',panel).x+
        105*.5,panel)==129,'Diameter center should round to integer')
    check(Sliders.value('stabilization',Sliders.rail('stabilization',panel).x+
        105*.5,panel)==3,'Stabilization center should round integer')
    local kinds=Sliders.activeKind('brush','brush',false)
    check(#kinds==3 and kinds[1]=='diameter' and
        kinds[2]=='opacity' and kinds[3]=='stabilization',
        'Brush must expose three adjustments')
    check(Sliders.kindAt('fill','brush',false,panel,
        Sliders.rail('tolerance',panel).x+5,483)=='tolerance',
        'Fill must use tolerance rail')
    check(Sliders.kindAt('erase','brush',false,panel,r.x+5,
        r.y+4)=='opacity','Eraser must have opacity rail')
    check(Sliders.kindAt('brush','layers',false,panel,r.x+5,
        r.y+4)==nil,'Inactive side tab must not capture input')
    check(Sliders.kindAt('brush','brush',true,panel,r.x+5,
        r.y+4)==nil,'Focus must not activate hidden panel rails')
    check(Sliders.kindAt('picker','brush',false,panel,r.x+5,
        r.y+4)==nil,'Other tools must not capture slider clicks')
    check(not pcall(Sliders.spec,'fake'),'Invalid slider must be rejected')
    check(not pcall(Sliders.value,'opacity',0/0,panel),
        'NaN pointer cannot propagate into editing state')
    return {suite='desktop-precision-brush-sliders',passed=true,
        assertions=checks,bounded_values=true,one_percent_opacity=true,
        native_range=true,panel_isolation=true}
end
return T
