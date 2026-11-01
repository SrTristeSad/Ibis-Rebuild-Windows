-- A nova varredura por linha deve produzir EXATAMENTE os mesmos bytes
-- da varredura retangular anterior: cores, alpha, pressao e cobertura.
package.path='app/?.lua;'..package.path
local R=require('raster_lua')
assert(R.strokeScanlineEnabled(),'varredura de linha deveria iniciar ativa')
local W,H=176,132
local paths={
    {0.5,0.5,175.5,131.5},
    {175.5,0.5,0.5,131.5},
    {15.5,126.5,167.5,6.5},
    {28.5,4.5,148.5,128.5},
    {0.5,60.5,175.5,60.5},
    {80.5,0.5,80.5,131.5},
    {78.5,66.5,78.5,66.5},
    {-120,40.5,235,99.5},
    {75.5,-100,109.5,240},
    {-60,-100,260,250},
}
local trials=0
local function source()
    local b=R.buffer(W,H)
    for y=0,H-1 do
        for x=0,W-1 do
            if (x+y)%7==0 then
                R.pixel(b,x,y,0x456cae7f)
            elseif (x*13+y*5)%9==0 then
                R.pixel(b,x,y,0x225577ff)
            end
        end
    end
    return R.bytes(b)
end
local sourceBytes=source()
local function withMode(enabled,func)
    R.setStrokeScanlineEnabled(enabled)
    local result=func()
    return result
end
for _,points in ipairs(paths) do
    for _,brush in ipairs({
        {diameter=2,style=0,hardness=1,tiltX=0,tiltY=0},
        {diameter=17,style=1,hardness=.25,tiltX=0,tiltY=0},
        {diameter=39,style=2,hardness=1,tiltX=0,tiltY=0},
        {diameter=23,style=3,hardness=.6,tiltX=77,tiltY=-43},
        {diameter=64,style=3,hardness=.15,tiltX=-85,tiltY=12},
    }) do
        for _,opacity in ipairs({0,.25,.75,1}) do
            local function render()
                local b=R.buffer(W,H,sourceBytes)
                R.pressureStroke(b,
                    points[1],points[2],points[3],points[4],
                    brush.diameter,brush.diameter*0.65,
                    0x9c35e1e4,opacity,opacity*.75,
                    brush.hardness,brush.tiltX,brush.tiltY,brush.style)
                return R.bytes(b)
            end
            local expected=withMode(false,render)
            local actual=withMode(true,render)
            assert(actual==expected,('brush diverged at trial %d, style=%d'):format(trials,brush.style))
            trials=trials+1
        end
    end
end
-- Cobertura unica por gesto, inclusive sobreposicao e borracha.
for _,style in ipairs({0,1,2,3}) do
    local function gesture()
        local b=R.buffer(W,H,sourceBytes)
        local baseline=R.bytes(b)
        local mask=R.strokeCoverage(b)
        for _,path in ipairs(paths) do
            R.accumulatedStroke(b,baseline,mask,
                path[1],path[2],path[3],path[4],
                13,23,0x1199bbff,.35,.73,.3,60,30,style)
        end
        return R.bytes(b), require('ffi').string(mask.bytes,mask.size)
    end
    R.setStrokeScanlineEnabled(false)
    local before,maskBefore=gesture()
    R.setStrokeScanlineEnabled(true)
    local after,maskAfter=gesture()
    assert(before==after and maskBefore==maskAfter,
        'Accumulated brush or mask differs for style '..style)
end
R.setStrokeScanlineEnabled(true)
assert(R.strokeScanlineEnabled())
print(('Lua brush scanline: %d independent RGBA trials and 4 accumulated gestures identical'):format(trials))
