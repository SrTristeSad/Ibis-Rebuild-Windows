-- Stage 41: compact layer opacity rail. Pure geometry/value mapping.
-- Drafts are preview-only until pointer release: one metadata undo entry.
local Rail={}
function Rail.rect(p)
    assert(type(p)=='table' and type(p.x)=='number' and
        type(p.y)=='number' and type(p.w)=='number' and
        type(p.h)=='number' and p.w>=298 and p.h>=354,
        'Invalid compact layer popup')
    return {x=p.x+15,y=p.y+p.h-20,w=158,h=12}
end
function Rail.hit(p,x,y)
    if type(x)~='number' or type(y)~='number' or
        x~=x or y~=y then return false end
    local r=Rail.rect(p)
    return x>=r.x-4 and x<=r.x+r.w+4 and
        y>=r.y-5 and y<=r.y+r.h+4
end
function Rail.value(p,x)
    assert(type(x)=='number' and x==x,'Invalid slider pointer')
    local r=Rail.rect(p)
    return math.floor(math.max(0,math.min(1,(x-r.x)/r.w))*100+.5)/100
end
function Rail.fraction(value)
    assert(type(value)=='number' and value==value and
        value>=0 and value<=1,'Layer opacity must be in [0,1]')
    return value
end
function Rail.draft(index,initial,value)
    assert(type(index)=='number' and index%1==0 and index>=1 and index<=8,
        'Invalid active layer')
    Rail.fraction(initial)
    Rail.fraction(value)
    return {index=index,initial=initial,value=value}
end
function Rail.changed(draft)
    assert(type(draft)=='table' and draft.index and
        type(draft.initial)=='number' and type(draft.value)=='number',
        'Invalid opacity draft')
    return math.abs(draft.value-draft.initial)>.000001
end
return Rail
