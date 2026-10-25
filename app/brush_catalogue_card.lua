-- Stage 42: separate preview focus from immediate brush application.
-- Pure geometry, matching catalogue cards at every supported viewport.
local Card={}
function Card.previewButton(x,y,width)
    assert(type(x)=='number' and x==x and
        type(y)=='number' and y==y and
        type(width)=='number' and width>=180,
        'Invalid brush catalogue card')
    return {x=x+width-81,y=y+4,w=69,h=24}
end
function Card.inspectorName(index,saved)
    assert(type(saved)=='table','Invalid saved brush catalogue')
    if index==nil then return 'Pincel atual' end
    assert(type(index)=='number' and index%1==0 and
        index>=1 and index<=8,'Invalid brush preview focus')
    local Presets=require('brush_presets')
    local preset=index<=4 and Presets.BUILTINS[index] or saved[index-4]
    return preset and preset.name or 'Pincel atual'
end
return Card
