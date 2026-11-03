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
-- Escalonamento com diversas camadas, inclusive sobre base opaca.
-- Relatorio informativo: nao introduz limites arbitrarios de velocidade.
for _,count in ipairs({2,4,8}) do
    local width=512
    local output=R.buffer(width,width)
    local layers={}
    for index=1,count do
        local buffer=R.buffer(width,width)
        R.clear(buffer,index==1 and 0x35526aff or
            (0x244f70a0+index*0x00010100))
        layers[index]=buffer
    end
    local localRect={x=256-32,y=256-32,w=64,h=64}
    local full=timer(function()
        R.clear(output,0)
        for _,layer in ipairs(layers) do R.composite(output,layer,1) end
    end,3)
    local dirty=timer(function()
        R.clearRect(output,localRect)
        for _,layer in ipairs(layers) do
            R.compositeRect(output,layer,1,localRect)
        end
    end,16)
    print(('Lua raster CPU 512x512: %d layers full %.3f ms; dirty 64x64 %.3f ms'):format(count,full,dirty))
end
print('Benchmark de composicao concluido (valores de CI nao equivalem ao hardware local)')
