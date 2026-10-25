-- Pure layer order bounds for the desktop inspector (stage 40).
local Order={}
function Order.target(index,count,direction)
    assert(type(count)=='number' and count%1==0 and count>=1,
        'Invalid layer count')
    assert(type(index)=='number' and index%1==0 and
        index>=1 and index<=count,'Invalid active layer')
    assert(direction==1 or direction==-1,'Invalid layer direction')
    local nextIndex=index+direction
    if nextIndex<1 or nextIndex>count then return nil end
    return nextIndex
end
return Order
