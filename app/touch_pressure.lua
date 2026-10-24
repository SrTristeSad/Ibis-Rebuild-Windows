-- Desktop LÖVE touch pressure policy. Most devices report constant pressure 1.
-- This is not a Windows Ink / Wintab reader and does not identify a stylus.
local Pressure={}
function Pressure.normalize(value)
    if type(value)~='number' or value~=value or
        value==math.huge or value==-math.huge then return 1 end
    if value<0 then return 0 end
    if value>1 then return 1 end
    return value
end
function Pressure.diameter(base,value)
    assert(type(base)=='number' and base>=1 and base<=256 and
        base==base,'Diâmetro base inválido')
    local strength=Pressure.normalize(value)
    return math.max(1,base*(0.25+0.75*strength))
end
function Pressure.opacity(base,value)
    assert(type(base)=='number' and base>=0 and base<=1 and
        base==base,'Opacidade base inválida')
    local strength=Pressure.normalize(value)
    return base*(0.2+0.8*strength)
end
return Pressure
