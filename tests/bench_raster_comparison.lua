-- Executa as duas implementacoes no MESMO processo/CPU do CI.
-- Comparacao informativa, sem limites rigidos ou alegacao de FPS.
package.path='app/?.lua;'..package.path
local R=require('raster_lua')
local floor=math.floor

-- Compositor por pixel da etapa imediatamente anterior ao caminho
-- otimizado por linhas. Nao usa memcpy por linha.
local function previous(dst,src,opacity)
    local target=dst.bytes
    local source=src.bytes
    for p=0,dst.size-4,4 do
        local alpha=source[p+3]
        if opacity==1 and alpha==255 then
            target[p],target[p+1],target[p+2],target[p+3]=
                source[p],source[p+1],source[p+2],255
        elseif alpha==0 and target[p+3]>0 then
            -- Fonte transparente com destino nao transparente.
        else
            local sa=(alpha/255)*opacity
            local da=target[p+3]/255
            local oa=sa+da*(1-sa)
            if oa>0 then
                for k=0,2 do
                    target[p+k]=floor((source[p+k]*sa+
                        target[p+k]*da*(1-sa))/oa+0.5)
                end
            else
                target[p],target[p+1],target[p+2]=0,0,0
            end
            target[p+3]=floor(oa*255+0.5)
        end
    end
end

local n=1024
local base,top=R.buffer(n,n),R.buffer(n,n)
local a,b=R.buffer(n,n),R.buffer(n,n)
R.clear(base,0x193e62ff)
R.clear(top,0x4b97bcbb)
-- Introduz linhas misturadas que obrigam cair no caminho por pixel.
for y=32,n-1,32 do
    R.pixel(top,16,y,0x62abef00)
end
local function legacy()
    R.clear(a,0)
    previous(a,base,1)
    previous(a,top,.65)
end
local function optimized()
    R.clear(b,0)
    R.composite(b,base,1)
    R.composite(b,top,.65)
end
legacy()
optimized()
assert(R.bytes(a)==R.bytes(b),
    'Benchmark nao compara renders RGBA identicos')
local function measure(fn,count)
    collectgarbage('collect')
    local begin=os.clock()
    for _=1,count do fn() end
    return (os.clock()-begin)*1000/count
end
local oldMs=measure(legacy,8)
local newMs=measure(optimized,8)
assert(R.bytes(a)==R.bytes(b),'Composicao alterada durante benchmark')
assert(oldMs>=0 and newMs>=0)
print(('Lua CPU 1024x1024 same runner: legacy per pixel %.3f ms, opaque row %.3f ms; ratio %.2fx'):format(oldMs,newMs,
    newMs>0 and oldMs/newMs or 0))
print('Tempos informativos; medicao nao representa latencia total nem FPS')
