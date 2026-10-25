-- Windows color-window model inspired by the documented ibisPaint
-- HSB/RGB/palette workflow. Entirely independent of Android binaries.
local Color=require('colors')
local Picker={}
Picker.HISTORY_LIMIT=12
Picker.PALETTE_LIMIT=12
local function numeric(v,min,max)
    return type(v)=='number' and v==v and v>=min and v<=max
        and v~=math.huge and v~=-math.huge
end
local function integer(v,min,max)
    return numeric(v,min,max) and v%1==0
end
local function channel(v)
    assert(numeric(v,0,255),'Canal fora da faixa 0..255')
    return math.floor(v+.5)
end
function Picker.rgba(r,g,b,a)
    local rr,gg,bb,aa=channel(r),channel(g),channel(b),channel(a or 255)
    return rr*16777216+gg*65536+bb*256+aa
end
function Picker.hsb(rgba)
    local r,g,b,a=Color.channels(rgba)
    r=r/255;g=g/255;b=b/255
    local high=math.max(r,g,b)
    local low=math.min(r,g,b)
    local diff=high-low
    local h=0
    if diff>0 then
        if high==r then h=((g-b)/diff)%6
        elseif high==g then h=(b-r)/diff+2
        else h=(r-g)/diff+4 end
        h=h*60
    end
    local s=high==0 and 0 or diff/high
    return h,s*100,high*100,a
end
function Picker.fromHSB(h,s,b,a)
    assert(numeric(h,0,360) and numeric(s,0,100) and
        numeric(b,0,100) and integer(a or 255,0,255),
        'HSB/Alfa fora da faixa')
    local hue=(h%360)/60
    local saturation=s/100
    local brightness=b/100
    local chroma=brightness*saturation
    local secondary=chroma*(1-math.abs(hue%2-1))
    local shift=brightness-chroma
    local r,g,blue
    if hue<1 then r,g,blue=chroma,secondary,0
    elseif hue<2 then r,g,blue=secondary,chroma,0
    elseif hue<3 then r,g,blue=0,chroma,secondary
    elseif hue<4 then r,g,blue=0,secondary,chroma
    elseif hue<5 then r,g,blue=secondary,0,chroma
    else r,g,blue=chroma,0,secondary end
    return Picker.rgba((r+shift)*255,(g+shift)*255,
        (blue+shift)*255,a or 255)
end
function Picker.withRGB(color,key,value)
    local r,g,b,a=Color.channels(color)
    assert(integer(value,0,255),'RGB canal inteiro esperado')
    if key=='R' then r=value
    elseif key=='G' then g=value
    elseif key=='B' then b=value
    elseif key=='A' then a=value
    else error('Canal RGB desconhecido') end
    return Picker.rgba(r,g,b,a)
end
function Picker.withHSB(color,key,value)
    local h,s,b,a=Picker.hsb(color)
    if key=='H' then
        assert(integer(value,0,360),'Matiz inválida');h=value
    elseif key=='S' then
        assert(integer(value,0,100),'Saturação inválida');s=value
    elseif key=='V' then
        assert(integer(value,0,100),'Brilho inválido');b=value
    elseif key=='A' then
        assert(integer(value,0,255),'Alfa inválido');a=value
    else error('Canal HSB desconhecido') end
    return Picker.fromHSB(h,s,b,a)
end
function Picker.track(rect,mode,key)
    assert(mode=='rgb' or mode=='hsb','Modo não suportado')
    assert(type(rect)=='table' and numeric(rect.x,0,1e5) and
        numeric(rect.y,0,1e5),'Painel de cor inválido')
    local index
    for i,k in ipairs(mode=='rgb' and {'R','G','B','A'}
        or {'H','S','V','A'}) do
        if key==k then index=i end
    end
    assert(index,'Canal inexistente')
    return {x=rect.x+92,y=rect.y+199+(index-1)*41,w=264,h=10}
end
function Picker.trackValue(rect,mode,key,x)
    local t=Picker.track(rect,mode,key)
    assert(type(x)=='number' and x==x,'Ponteiro inválido')
    local percent=math.max(0,math.min(1,(x-t.x)/t.w))
    local max=mode=='hsb' and (key=='H' and 360
        or key=='A' and 255 or 100) or 255
    return math.floor(percent*max+.5)
end
function Picker.trackHit(rect,mode,x,y)
    for _,key in ipairs(mode=='rgb' and {'R','G','B','A'}
        or {'H','S','V','A'}) do
        local t=Picker.track(rect,mode,key)
        if x>=t.x-5 and x<=t.x+t.w+5 and
            y>=t.y-8 and y<=t.y+t.h+8 then return key end
    end
    return nil
end
function Picker.popup(w,h)
    assert(integer(w,960,10000) and integer(h,640,10000),
        'Janela insuficiente')
    return {x=w-426,y=134,w=404,h=450}
end
function Picker.history(history,color)
    assert(type(history)=='table','Histórico inválido')
    Color.channels(color)
    local result={color}
    for _,item in ipairs(history) do
        Color.channels(item)
        if item~=color and #result<Picker.HISTORY_LIMIT then
            result[#result+1]=item
        end
    end
    return result
end
function Picker.saved(items,color)
    assert(type(items)=='table' and #items<=Picker.PALETTE_LIMIT,
        'Paleta inválida')
    Color.channels(color)
    local result={}
    for _,v in ipairs(items) do
        Color.channels(v)
        if v==color then return items,false end
        result[#result+1]=v
    end
    assert(#result<Picker.PALETTE_LIMIT,'Paleta cheia: 12 cores')
    result[#result+1]=color
    return result,true
end
return Picker
