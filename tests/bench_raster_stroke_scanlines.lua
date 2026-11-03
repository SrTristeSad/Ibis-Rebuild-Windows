-- Medicao informativa: mesma entrada, mesma CPU, mesmo motor LuaJIT.
-- Sem compromissos de FPS, sem subir a prioridade do processo.
package.path='app/?.lua;'..package.path
local R=require('raster_lua')
local W,H=1024,1024
local baseline=R.buffer(W,H)
R.clear(baseline,0)
local paths={
    {24.5,32.5,978.5,958.5},
    {960.5,16.5,32.5,1000.5},
    {32.5,32.5,980.5,32.5}, -- horizontal: nenhum ganho esperado
    {400.5,15.5,400.5,1000.5}, -- vertical: varredura ja curta
}
local function run(path)
    local b=R.buffer(W,H)
    R.pressureStroke(b,path[1],path[2],path[3],path[4],
        12,12,0x77c9b6ff,.7,.7,.6,0,0,1)
    return R.bytes(b)
end
local function measure(path,enabled)
    R.setStrokeScanlineEnabled(enabled)
    collectgarbage('collect')
    local start=os.clock()
    for i=1,3 do
        local b=R.buffer(W,H)
        R.pressureStroke(b,path[1],path[2],path[3],path[4],
            12,12,0x77c9b6ff,.7,.7,.6,0,0,1)
    end
    return (os.clock()-start)*1000/3
end
for label,path in ipairs(paths) do
    R.setStrokeScanlineEnabled(false)
    local before=run(path)
    R.setStrokeScanlineEnabled(true)
    local after=run(path)
    assert(before==after,'Benchmark generated different pixels')
    local rectangular=measure(path,false)
    local clipped=measure(path,true)
    print(('Lua stroke %d: rectangular %.3f ms, clipped %.3f ms, ratio %.2fx'):format(
        label,rectangular,clipped,clipped>0 and rectangular/clipped or 0))
end
R.setStrokeScanlineEnabled(true)
print('Stroke benchmark CPU only; not end-to-end pen latency or FPS')
