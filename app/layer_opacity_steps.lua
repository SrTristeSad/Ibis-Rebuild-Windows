-- Stage 40: bounded 10% opacity controls for the desktop layer panel.
-- Pure functions: the caller owns undo, raster rebuilding and persistence.
local Steps={}
function Steps.change(value,direction)
    assert(type(value)=='number' and value==value and
        value>=0 and value<=1,'Invalid layer opacity')
    assert(direction==1 or direction==-1,'Invalid opacity direction')
    local percent=math.floor(value*100+0.5)
    return math.max(0,math.min(100,percent+direction*10))/100
end
function Steps.canChange(value,direction)
    return Steps.change(value,direction)~=value
end
return Steps
