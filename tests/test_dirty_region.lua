local R=require('dirty_region')
local T={}
function T.run()
    local n=0
    local function check(v,s)n=n+1;assert(v,s)end
    local a=R.segment(100,100,10.5,10.5,10.5,10.5,2,2)
    check(a and a.x<=10 and a.x+a.w>11 and a.y<=10 and
        a.y+a.h>11,'Point omitted by dirty bounds')
    local edge=R.segment(100,100,-5,3,5,3,10,10)
    check(edge and edge.x==0 and edge.y==0,'Edge clipping incorrect')
    local br=R.segment(100,100,95,95,105,105,256,256)
    check(br.x==0 and br.y==0 and br.w==100 and br.h==100,
        'Huge tilted brush not clipped')
    local none=R.segment(100,100,-1000,-1000,-900,-900,1,1)
    check(none==nil,'Offscreen brush should not allocate texture patch')
    check(R.segment(100,100,90,30,110,30,1,1).x<=90,
        'Cross-boundary segment missing start')
    local merged=R.union({x=2,y=4,w=3,h=5},{x=8,y=1,w=2,h=2})
    check(merged.x==2 and merged.y==1 and merged.w==8 and merged.h==8,
        'Curve packet did not union all dirty segments')
    check(R.union(nil,a)==a and R.union(a,nil)==a,
        'Empty union cannot discard a valid rectangle')
    for x=0,20 do
        local rect=R.segment(20,20,x,x,x+2,x+1,1,6)
        if rect then
            check(rect.x>=0 and rect.y>=0 and rect.x+rect.w<=20 and
                rect.y+rect.h<=20,'Dirty rectangle exceeded the document')
        end
    end
    for _,args in ipairs({{0,10,0,0,0,0,1,1},
        {10,10,0/0,0,0,0,1,1},
        {10,10,0,0,0,0,0,2},
        {10,10,0,0,0,0,257,1}}) do
        check(not pcall(R.segment,unpack(args)),
            'Invalid brush geometry accepted')
    end
    -- Conservative swept capsule: bound all integer samples around endpoints.
    for d=1,256,17 do
        local box=R.segment(360,360,150,125,210,185,d,d)
        for _,p in ipairs({{150,125},{210,185}}) do
            local r=d*.875+1
            check(box.x<=math.floor(p[1]-r) and box.x+box.w>=math.ceil(p[1]+r)
                and box.y<=math.floor(p[2]-r) and
                box.y+box.h>=math.ceil(p[2]+r),
                'Native tilted edge exceeds dirty box')
        end
    end
    return {suite='dirty-region-spatial-bounds',passed=true,
        assertions=n,bounds_clamped=true,curves_bounded=true}
end
return T
