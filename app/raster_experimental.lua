-- Implementacao EXPERIMENTAL de composicao RGBA.
-- Nao e usada no editor por padrao: os benchmarks Windows foram regressivos.
-- Mantida isolada para testes deterministas e estudos de desempenho em Lua.
local ffi=require('ffi')
return function(Raster)
    local function checkBuffer(b)
        assert(type(b)=='table' and b.bytes and b.width and b.height
            and b.size==b.width*b.height*4,'Buffer invalido')
    end
    local function checkRect(b,r)
        checkBuffer(b)
        assert(type(r)=='table' and type(r.x)=='number' and r.x%1==0
            and type(r.y)=='number' and r.y%1==0
            and type(r.w)=='number' and r.w%1==0
            and type(r.h)=='number' and r.h%1==0
            and r.x>=0 and r.y>=0 and r.w>=1 and r.h>=1
            and r.x+r.w<=b.width and r.y+r.h<=b.height,'Regiao invalida')
    end
local function compose(dst, src, opacity, rect)
    checkBuffer(dst)
    checkBuffer(src)
    assert(dst ~= src and dst.bytes ~= src.bytes, "Buffers devem ser distintos")
    assert(dst.width == src.width and dst.height == src.height, "Dimensoes diferentes")
    assert(type(opacity) == "number" and opacity >= 0 and opacity <= 1
        and opacity == opacity, "Opacidade invalida")
    checkRect(dst, rect)
    local destPixels,sourcePixels=dst.bytes,src.bytes
    -- Em camadas opacas (ex.: fundo), a sobreposicao normal com
    -- opacidade 1 equivale a copiar a faixa RGBA inteira. O teste e
    -- feito por linha, sem confiar em flags de opacidade que poderiam
    -- ficar desatualizadas apos edicoes do raster.
    for y = rect.y, rect.y+rect.h-1 do
        local first=(y*dst.width+rect.x)*4
        local copied=false
        if Raster.opaqueRowCopyEnabled and opacity==1 then
            local last=first+rect.w*4-1
            copied=true
            for alpha=first+3,last,4 do
                if sourcePixels[alpha]~=255 then
                    copied=false
                    break
                end
            end
            if copied then
                ffi.copy(destPixels+first,sourcePixels+first,rect.w*4)
            end
        end
        if not copied then
            for x = rect.x, rect.x+rect.w-1 do
                local p = (y*dst.width+x)*4
                local sourceAlpha=sourcePixels[p+3]
                if opacity==1 and sourceAlpha==255 then
                    -- Source-over 100% opaco: copiar bytes e matematicamente
                    -- equivalente, sem divisao/normalizacao por pixel.
                    destPixels[p],destPixels[p+1],destPixels[p+2],destPixels[p+3]=
                        sourcePixels[p],sourcePixels[p+1],sourcePixels[p+2],255
                elseif sourceAlpha==0 and destPixels[p+3]>0 then
                    -- Fonte totalmente transparente nao altera destino
                    -- com alfa positivo. Se destino for transparente, devemos
                    -- normalizar seu RGB para zero como no compositor anterior.
                else
                    local sa = (sourceAlpha/255)*opacity
                    if Raster.opaqueDestFastPathEnabled and destPixels[p+3]==255 then
                        -- Fundo opaco: source-over permanece opaco.
                        -- Nao ha divisao pelo alfa de saida (igual a 1).
                        local remain=1-sa
                        for k=0,2 do
                            local v=sourcePixels[p+k]*sa+
                                destPixels[p+k]*remain
                            destPixels[p+k]=math.floor(v+0.5)
                        end
                    else
                        local da = destPixels[p+3]/255
                        local oa = sa+da*(1-sa)
                        if oa > 0 then
                            for k = 0, 2 do
                                local v = (sourcePixels[p+k]*sa
                                    +destPixels[p+k]*da*(1-sa))/oa
                                destPixels[p+k] = math.floor(v+0.5)
                            end
                        else
                            destPixels[p],destPixels[p+1],destPixels[p+2] = 0,0,0
                        end
                        destPixels[p+3] = math.floor(oa*255+0.5)
                    end
                end
            end
        end -- faixa nao totalmente opaca: composicao pixel a pixel
    end
end

    return compose
end
