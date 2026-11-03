package.path='app/?.lua;'..package.path
local Native=require('raster_lua')
local Wand=require('wand_selection')
local T={}
function T.run()
    local checks=0
    local function check(ok,message) checks=checks+1;assert(ok,message)end
    local b=Native.buffer(7,5)
    Native.clear(b,0x00000000)
    for _,cell in ipairs({{0,0},{1,0},{1,1},{6,4},{5,4}}) do
        Native.pixel(b,cell[1],cell[2],0xff0000ff)
    end
    Native.pixel(b,2,1,0xfc0000ff)
    Native.pixel(b,3,1,0xff000080)
    local original=Native.bytes(b)
    local region=Wand.select(b,0,0,0,'set',true)
    check(region.count==3 and region.x==0 and region.y==0
        and region.w==2 and region.h==2,'Region flood mismatch')
    check(Wand.has(region,1,1) and not Wand.has(region,6,4)
        and not Wand.has(region,2,1),'Region leaks across color')
    local tolerant=Wand.select(b,0,0,2,'set',true)
    check(tolerant.count==4 and Wand.has(tolerant,2,1),
        'Tolerance should match three-unit red difference')
    local global=Wand.select(b,0,0,0,'set',false)
    check(global.count==5 and Wand.has(global,6,4),
        'Global matching should include disconnected region')
    local union=Wand.select(b,6,4,0,'add',true,region)
    check(union.count==5 and region.count==3 and Wand.has(union,5,4),
        'Add should not mutate original selection')
    local subtract=Wand.select(b,0,0,0,'subtract',true,union)
    check(subtract.count==2 and Wand.has(subtract,6,4)
        and not Wand.has(subtract,0,0),'Subtract selection mismatch')
    local zero=Wand.select(b,6,4,0,'subtract',true,nil)
    check(zero.count==0 and zero.w==0 and zero.h==0,
        'Subtract without selection must be empty')
    local trans=Wand.select(b,4,4,0,'set',true)
    check(trans.count>0 and not Wand.has(trans,0,0),
        'Alpha reference incorrectly matched opaque pixels')
    check(Native.bytes(b)==original,
        'Wand must never mutate source RGBA')
    for _,args in ipairs({
        {-1,0,0,'set',true},{7,0,0,'set',true},
        {0,0,-1,'set',true},{0,0,101,'set',true},
        {0,0,0,'merge',true},{0,0,0,'set',0}
    }) do
        check(not pcall(Wand.select,b,unpack(args)),
            'Invalid wand arguments accepted')
    end
    check(not pcall(Wand.select,b,0,0,0,'add',true,
        {width=2,height=2,bytes={}}),
        'Previous mask with wrong dimensions accepted')
    local empty=Native.buffer(1,1)
    local single=Wand.select(empty,0,0,0,'set',true)
    check(single.count==1 and Wand.has(single,0,0),
        'Single pixel canvas failed')
    return {suite='wand-selection',passed=true,
        assertions=checks,mask_without_raster_changes=true}
end
if ...==nil then
    local r=T.run()
    assert(r.passed)
    print(r.suite..' OK: '..r.assertions)
end
return T
