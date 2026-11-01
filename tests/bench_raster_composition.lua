-- Benchmark informativo (nao e teste de velocidade minima).
-- CPU: os.clock mede processamento local, nao latencia de tela / GPU.
package.path='app/?.lua;'..package.path
local R=require('raster_lua')
local function timer(fn,iterations)
    collectgarbage('collect')
    local start=os.clock()
    for _=1,iterations do fn() end
    return (os.clock()-start)*1000/iterations
end
for _,n in ipairs({256,1024,2048}) do
    local base=R.buffer(n,n)
    local overlay=R.buffer(n,n)
    local output=R.buffer(n,n)
    R.clear(base,0x233447ff)
    R.clear(overlay,0x5ba4c466)
    local patch={x=math.floor(n/2)-32,y=math.floor(n/2)-32,w=64,h=64}
    local full=timer(function()
        R.clear(output,0)
        R.composite(output,base,1)
        R.composite(output,overlay,0.65)
    end,2)
    local partial=timer(function()
        R.clearRect(output,patch)
        R.compositeRect(output,base,1,patch)
        R.compositeRect(output,overlay,0.65,patch)
    end,20)
    assert(full>=0 and partial>=0)
    print(('Lua raster CPU %dx%d: full 2 layers %.3f ms; dirty 64x64 %.3f ms'):format(n,n,full,partial))
end
print('Benchmark de composicao concluido (valores de CI nao equivalem ao hardware local)')
