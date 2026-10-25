local K=require('brush_keyboard')
local Presets=require('brush_presets')
local T={}
function T.run()
    local n=0
    local function check(v,msg)n=n+1;assert(v,msg)end
    local original=Presets.copy(Presets.BUILTINS[2])
    local draft=Presets.copy(original)
    check(K.select('1')=='diameter' and K.select('2')=='opacity' and
        K.select('3')=='stabilization','Three keyboard parameters')
    check(K.select('4')==nil,'Invalid key must not capture')
    local next=K.step(draft,'diameter','=')
    check(next.diameter==13 and draft.diameter==12,
        'Step must produce a new draft')
    next=K.step(next,'opacity','-')
    check(next.opacity==.99,'Opacity changes by one percent')
    next=K.step(next,'stabilization','kp+')
    check(next.stabilization==2,'Keypad adjustments work')
    check(K.step(next,'diameter','escape')==nil,
        'Escape not captured')
    for _,spec in ipairs({{'diameter',256,'='}, {'diameter',1,'-'},
        {'opacity',1,'='},{'opacity',.1,'-'},{'stabilization',5,'='},
        {'stabilization',0,'-'}}) do
        local copy=Presets.copy(next)
        copy[spec[1]]=spec[2]
        local adjusted=K.step(copy,spec[1],spec[3])
        check(adjusted[spec[1]]==spec[2],'Clamped native range')
    end
    check(original.diameter==12 and original.opacity==1 and
        original.stabilization==1,'Original preset untouched')
    return {suite='brush-keyboard-stage40',passed=true,assertions=n}
end
return T
