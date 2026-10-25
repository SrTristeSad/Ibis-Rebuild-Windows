-- Keyboard navigation for compact layer panel. Pure UI logic.
local Keys={}
function Keys.target(key,current,count)
    assert(type(current)=='number' and current%1==0 and current>=1 and
        type(count)=='number' and count%1==0 and count>=1 and
        current<=count,'Invalid layer stack selection')
    if key=='up' then return math.min(count,current+1) end
    if key=='down' then return math.max(1,current-1) end
    if key=='home' then return count end
    if key=='end' then return 1 end
    return nil
end
function Keys.hint()
    return '↑/↓ navegar · V visibilidade · Home/End extremos'
end
return Keys
