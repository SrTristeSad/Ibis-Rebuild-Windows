-- Conservative brush swept bounds in native document coordinates.
-- Expands for the worst-case 90-degree tilted major radius (1.75x).
-- No allocation proportional to stroke length or canvas area.
local Region={}
local function finite(n)
    return type(n)=='number' and n==n and n>-math.huge and n<math.huge
end
function Region.segment(w,h,x0,y0,x1,y1,d0,d1)
    assert(finite(w) and finite(h) and w%1==0 and h%1==0 and
        w>0 and h>0 and finite(x0) and finite(y0) and
        finite(x1) and finite(y1) and finite(d0) and finite(d1) and
        d0>=1 and d0<=256 and d1>=1 and d1<=256,
        'Região do pincel inválida')
    -- Stage 45 native border = diameter*0.5*majorScale + 1.
    -- majorScale <= 1.75; 2px is a conservative pixel-grid margin.
    local pad=math.max(d0,d1)*0.875+2
    local x=math.max(0,math.floor(math.min(x0,x1)-pad))
    local y=math.max(0,math.floor(math.min(y0,y1)-pad))
    local right=math.min(w,math.ceil(math.max(x0,x1)+pad))
    local bottom=math.min(h,math.ceil(math.max(y0,y1)+pad))
    if right<=x or bottom<=y then return nil end
    return {x=x,y=y,w=right-x,h=bottom-y}
end
function Region.union(a,b)
    if not a then return b end
    if not b then return a end
    local x=math.min(a.x,b.x)
    local y=math.min(a.y,b.y)
    return {x=x,y=y,
        w=math.max(a.x+a.w,b.x+b.w)-x,
        h=math.max(a.y+a.h,b.y+b.h)-y}
end
return Region
