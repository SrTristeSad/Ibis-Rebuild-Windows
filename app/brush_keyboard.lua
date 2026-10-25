-- Stage 40: keyboard-accessible, draft-only brush inspector adjustments.
-- Never alters pixels, history or persisted presets.
local Keyboard={}
local keys={['1']='diameter',['2']='opacity',['3']='stabilization'}
local steps={diameter=1,opacity=.01,stabilization=1}
local bounds={diameter={1,256},opacity={.1,1},stabilization={0,5}}
function Keyboard.select(key)
    return keys[key]
end
function Keyboard.step(draft,kind,key)
    local Lab=require('brush_lab')
    if not steps[kind] then return nil end
    local direction=(key=='-' or key=='kp-') and -1 or
        (key=='=' or key=='+' or key=='kp+') and 1 or nil
    if not direction then return nil end
    local lower,upper=bounds[kind][1],bounds[kind][2]
    local value=math.max(lower,math.min(upper,
        draft[kind]+direction*steps[kind]))
    if kind=='opacity' then value=math.floor(value*100+.5)/100 end
    return Lab.adjust(draft,kind,value)
end
return Keyboard
