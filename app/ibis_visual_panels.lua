-- Geometria da interface de referência, sem dependência de LÖVE.
-- Apenas apresentação: o projeto continua com motor raster e RBD2 próprios.
local Panels={}
local floor,cos,sin,pi,sqrt=math.floor,math.cos,math.sin,math.pi,math.sqrt
function Panels.brushRows(filter,presets)
    assert(filter=='all' or filter=='builtin' or filter=='personal',
        'Categoria de pincel desconhecida')
    assert(type(presets)=='table','Catálogo inválido')
    local rows={}
    for i=1,8 do
        if (filter=='all' or filter=='builtin' and i<=4
            or filter=='personal' and i>=5) then
            rows[#rows+1]={index=i,exists=i<=4 or presets[i-4]~=nil}
        end
    end
    return rows
end
function Panels.brushRow(rect,row)
    assert(type(rect)=='table' and rect.w>=840 and
        type(row)=='number' and row%1==0 and row>=1 and row<=8,
        'Linha de pincel inválida')
    return {x=rect.x+20,y=rect.y+87+(row-1)*43,
        w=682,h=40}
end
function Panels.brushPreview(rect,row)
    local r=Panels.brushRow(rect,row)
    return {x=r.x+172,y=r.y+8,w=208,h=24}
end
function Panels.brushPreviewAction(rect,row)
    local r=Panels.brushRow(rect,row)
    return {x=r.x+r.w-60,y=r.y+5,w=56,h=30}
end
function Panels.layerRow(p,row)
    assert(type(p)=='table' and p.w>=298 and p.h>=350
        and type(row)=='number' and row%1==0 and row>=1 and row<=5,
        'Linha de camada inválida')
    return {x=p.x+13,y=p.y+126+(row-1)*52,w=p.w-26,h=49}
end
function Panels.layerRows(p)
    assert(type(p)=='table' and p.h>=350,'Painel de camadas inválido')
    return math.max(2,math.min(4,floor((p.h-188)/52)))
end
function Panels.wheel(rect)
    assert(type(rect)=='table' and rect.x and rect.y,
        'Painel de cor inválido')
    return {cx=rect.x+137,cy=rect.y+265,inner=74,outer=91}
end
function Panels.wheelHit(rect,x,y)
    local w=Panels.wheel(rect)
    local d=sqrt((x-w.cx)^2+(y-w.cy)^2)
    return d>=w.inner-3 and d<=w.outer+3
end
function Panels.wheelHue(rect,x,y)
    local w=Panels.wheel(rect)
    local angle=(math.atan2(y-w.cy,x-w.cx)*180/pi)%360
    return floor(angle+.5)%360
end
function Panels.wheelPoint(rect,hue)
    assert(type(hue)=='number' and hue>=0 and hue<=360)
    local w=Panels.wheel(rect)
    local radius=(w.inner+w.outer)/2
    local a=hue*pi/180
    return w.cx+cos(a)*radius,w.cy+sin(a)*radius
end
return Panels
