-- Motor raster escrito em LuaJIT. FFI apenas aloca memoria RGBA;
-- nenhuma DLL proprietaria ou funcao C/C++ de desenho e carregada.
-- Primeira etapa de migracao: buffers, pixels e composicao incremental.
local ffi = require("ffi")
local bit = require("bit")
local band, rshift = bit.band, bit.rshift
local Raster = { available = true, implementation = "lua" }

local function integer(n)
    return type(n) == "number" and n == n and n % 1 == 0
end
local function checkBuffer(b)
    assert(type(b) == "table" and b.bytes and integer(b.width)
        and integer(b.height) and b.size == b.width * b.height * 4,
        "Buffer RGBA invalido")
end
local function color(rgba)
    assert(integer(rgba) and rgba >= 0 and rgba <= 0xffffffff, "Cor RGBA invalida")
    -- Mesmo empacotamento numerico do motor anterior: 0xRRGGBBAA.
    return band(rshift(rgba, 24), 255), band(rshift(rgba, 16), 255),
        band(rshift(rgba, 8), 255), band(rgba, 255)
end
local function checkRect(b, rect)
    checkBuffer(b)
    assert(type(rect) == "table" and integer(rect.x) and integer(rect.y)
        and integer(rect.w) and integer(rect.h) and rect.w > 0 and rect.h > 0
        and rect.x >= 0 and rect.y >= 0
        and rect.x + rect.w <= b.width and rect.y + rect.h <= b.height,
        "Regiao RGBA invalida")
end
local function offset(b, x, y)
    assert(integer(x) and integer(y) and x >= 0 and y >= 0
        and x < b.width and y < b.height, "Pixel fora do canvas")
    return (y * b.width + x) * 4
end
function Raster.load()
    Raster.available = true
    return true
end
function Raster.buffer(width, height, pixels)
    assert(integer(width) and integer(height) and width >= 1 and height >= 1
        and width <= 2048 and height <= 2048, "Dimensoes invalidas")
    local size = width * height * 4
    if pixels ~= nil then
        assert(type(pixels) == "string" and #pixels == size, "Dados RGBA invalidos")
    end
    local bytes = ffi.new("uint8_t[?]", size)
    if pixels then ffi.copy(bytes, pixels, size) end
    return { bytes = bytes, width = width, height = height, size = size }
end
function Raster.bytes(b)
    checkBuffer(b)
    return ffi.string(b.bytes, b.size)
end
function Raster.clear(b, rgba)
    checkBuffer(b)
    local r, g, blue, a = color(rgba)
    if rgba == 0 then
        ffi.fill(b.bytes, b.size, 0)
        return
    end
    for p = 0, b.size - 4, 4 do
        b.bytes[p], b.bytes[p+1], b.bytes[p+2], b.bytes[p+3] = r, g, blue, a
    end
end
function Raster.pixel(b, x, y, rgba)
    checkBuffer(b)
    local p = offset(b, x, y)
    local r, g, blue, a = color(rgba)
    b.bytes[p], b.bytes[p+1], b.bytes[p+2], b.bytes[p+3] = r, g, blue, a
end
function Raster.readPixel(b, x, y)
    checkBuffer(b)
    local p = offset(b, x, y)
    return b.bytes[p] * 16777216 + b.bytes[p+1] * 65536
        + b.bytes[p+2] * 256 + b.bytes[p+3]
end
function Raster.clearRect(b, rect)
    checkRect(b, rect)
    for y = rect.y, rect.y + rect.h - 1 do
        ffi.fill(b.bytes + (y*b.width + rect.x)*4, rect.w*4, 0)
    end
end
function Raster.regionBytes(b, rect)
    checkRect(b, rect)
    local row = rect.w*4
    local region = ffi.new("uint8_t[?]", row*rect.h)
    for y = 0, rect.h-1 do
        ffi.copy(region+y*row, b.bytes+((y+rect.y)*b.width+rect.x)*4, row)
    end
    return ffi.string(region, row*rect.h)
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
        if opacity==1 then
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
                    if destPixels[p+3]==255 then
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
function Raster.compositeRect(dst, src, opacity, rect)
    compose(dst, src, opacity, rect)
end
function Raster.composite(dst, src, opacity)
    compose(dst, src, opacity, {x=0,y=0,w=dst.width,h=dst.height})
end
require('raster_stroke')(Raster)
require('raster_tools')(Raster)
return Raster
