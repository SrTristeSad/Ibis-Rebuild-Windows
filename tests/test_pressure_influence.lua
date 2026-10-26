local Influence=require('pressure_influence')
local Curves=require('pressure_curves')
local Pressure=require('touch_pressure')
local T={}
function T.run()
    local n=0
    local function check(value,msg)n=n+1;assert(value,msg)end
    local states={{true,true},{true,false},{false,true},{false,false}}
    for _,mode in ipairs(Curves.ORDER) do
        for _,flags in ipairs(states) do
            local sizeOn,opacityOn=flags[1],flags[2]
            for i=0,100 do
                local input=i/100
                local mapped=Curves.apply(input,mode)
                local dia,alpha=Influence.resolve(12,.8,input,mode,
                    sizeOn,opacityOn)
                check(dia==(sizeOn and Pressure.diameter(12,mapped) or 12),
                    'Diameter channel must be independently selectable')
                check(alpha==(opacityOn and Pressure.opacity(.8,mapped) or .8),
                    'Opacity channel must be independently selectable')
                check(dia>=1 and dia<=12 and alpha>=0 and alpha<=.8,
                    'Independent channel parameters must remain bounded')
                if i==100 then
                    check(dia==12 and alpha==.8,
                        'Full-pressure behavior must be backward compatible')
                end
            end
            local dia,alpha=Influence.resolve(12,.8,.25,mode,false,false)
            check(dia==12 and alpha==.8,
                'Switching both channels off must ignore partial pressure')
        end
    end
    local d,a=Influence.resolve(12,.8,.25,'linear',true,true)
    check(d==5.25 and math.abs(a-.32)<1e-9,
        'Default mode preserves original linear pressure mapping')
    d,a=Influence.resolve(12,.8,nil,'linear',true,true)
    check(d==12 and a==.8,
        'Mouse/absent pressure must remain fully opaque at base intensity')
    check(not pcall(Influence.resolve,12,.8,.5,'linear',1,true),
        'Non-boolean diameter switch must be rejected')
    check(not pcall(Influence.resolve,12,.8,.5,'linear',true,nil),
        'Missing opacity switch must be rejected')
    check(not pcall(Influence.resolve,0,.8,.5,'linear',true,true),
        'Invalid diameter must be rejected')
    check(not pcall(Influence.resolve,12,2,.5,'linear',true,true),
        'Invalid opacity must be rejected')
    check(not pcall(Influence.resolve,12,.8,.5,'wrong',true,true),
        'Unknown pressure curve must be rejected')
    return {suite='independent-pressure-size-opacity',passed=true,
        assertions=n,legacy_default=true,all_four_modes=true}
end
return T
