-- Shared, strict RGBA color representation for desktop tools.
-- A scalar color is 0xRRGGBBAA. This is not an Android color parser.
local Colors={}
function Colors.parseHex(value)
    if type(value)~='string' then return nil,'Digite uma cor hexadecimal' end
    local raw=value:match('^%s*(.-)%s*$')
    if raw:sub(1,1)=='#' then raw=raw:sub(2) end
    if #raw~=6 and #raw~=8 then
        return nil,'Use exatamente 6 ou 8 dígitos: #RRGGBB ou #RRGGBBAA'
    end
    if not raw:match('^[0-9a-fA-F]+$') then
        return nil,'A cor contém caracteres não hexadecimais'
    end
    if #raw==6 then raw=raw..'FF' end
    return tonumber(raw,16)
end
function Colors.format(rgba)
    assert(type(rgba)=='number' and rgba%1==0 and rgba>=0 and
        rgba<=4294967295,'Valor RGBA inválido')
    return string.format('#%02X%02X%02X%02X',
        math.floor(rgba/16777216)%256,math.floor(rgba/65536)%256,
        math.floor(rgba/256)%256,rgba%256)
end
function Colors.channels(rgba)
    assert(type(rgba)=='number' and rgba%1==0 and rgba>=0 and rgba<=4294967295,
        'Valor RGBA inválido')
    return math.floor(rgba/16777216)%256,math.floor(rgba/65536)%256,
        math.floor(rgba/256)%256,rgba%256
end
return Colors
