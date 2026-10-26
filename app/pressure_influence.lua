-- Independent, opt-in response channels for the existing C++ brush core.
-- Defaults (true/true) exactly preserve pressure handling from Stage 43.
local Pressure=require('touch_pressure')
local Curves=require('pressure_curves')
local Influence={}
function Influence.resolve(baseDiameter,baseOpacity,raw,curve,affectSize,affectOpacity)
    assert(type(affectSize)=='boolean' and
        type(affectOpacity)=='boolean',
        'Pressure channels require boolean switches')
    assert(type(baseDiameter)=='number' and
        baseDiameter>=1 and baseDiameter<=256 and baseDiameter==baseDiameter,
        'Invalid base brush diameter')
    assert(type(baseOpacity)=='number' and
        baseOpacity>=0 and baseOpacity<=1 and baseOpacity==baseOpacity,
        'Invalid base brush opacity')
    local mapped=Curves.apply(raw,curve)
    local diameter=affectSize and Pressure.diameter(baseDiameter,mapped)
        or baseDiameter
    local opacity=affectOpacity and Pressure.opacity(baseOpacity,mapped)
        or baseOpacity
    return diameter,opacity
end
return Influence
