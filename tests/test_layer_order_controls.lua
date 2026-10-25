local Order=require('layer_order_controls')
local T={}
function T.run()
    local n=0
    local function check(ok,msg)n=n+1;assert(ok,msg)end
    check(Order.target(2,4,1)==3,'Move up')
    check(Order.target(2,4,-1)==1,'Move down')
    check(Order.target(4,4,1)==nil,'Cannot pass top')
    check(Order.target(1,4,-1)==nil,'Cannot pass bottom')
    check(Order.target(1,1,1)==nil,'Single layer top')
    check(Order.target(1,1,-1)==nil,'Single layer bottom')
    check(not pcall(Order.target,0,3,1),'Invalid active layer')
    check(not pcall(Order.target,4,3,-1),'Out-of-range active layer')
    check(not pcall(Order.target,1,3,0),'Invalid direction')
    check(not pcall(Order.target,1,0,1),'Invalid layer count')
    return {suite='layer-order-controls',passed=true,assertions=n}
end
return T
