-- Desktop pen/touch pressure response curves. Input only: all RGBA strokes
-- still render in the existing native C++ engine. The default preserves
-- Stage 12 pressure behaviour exactly, including mouse pressure 1.0.
local Pressure=require('touch_pressure')
local Curves={}
Curves.ORDER={'linear','soft','firm'}
Curves.LABELS={linear='Linear',soft='Suave',firm='Firme'}
function Curves.apply(raw,mode)
    assert(Curves.LABELS[mode],'Curva de pressão inválida')
    local p=Pressure.normalize(raw)
    if mode=='soft' then return math.sqrt(p) end
    if mode=='firm' then return p*p end
    return p
end
function Curves.next(mode)
    for i,value in ipairs(Curves.ORDER) do
        if value==mode then
            return Curves.ORDER[i%#Curves.ORDER+1]
        end
    end
    error('Curva de pressão inválida')
end
return Curves
