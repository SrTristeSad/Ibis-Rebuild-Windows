-- Stage 46: bounded, curvature-aware spatial reconstruction of pointer samples.
-- Coordinates and pressures remain in document space. This module never paints;
-- its callbacks feed the existing C++ rasterizer.
local Path={}
Path.__index=Path
local MAX_STEPS=12
local MAX_ERROR=0.5
local function coordinate(n)
    return type(n)=='number' and n==n and n>=-16384 and n<=16384
end
local function pressure(n)
    return type(n)=='number' and n==n and n>=0 and n<=1
end
local function checkPoint(x,y,p)
    assert(coordinate(x) and coordinate(y),'Coordenada do caminho inválida')
    assert(pressure(p),'Pressão do caminho inválida')
end
function Path.new(x,y,p)
    checkPoint(x,y,p)
    return setmetatable({
        cx=x,cy=y,cp=p,rawX=x,rawY=y,rawP=p,
        finished=false,emitted=0
    },Path)
end
-- The perpendicular deviation, not segment length, controls subdivision:
-- long straight motions stay ONE C++ segment; tight bends gain accuracy.
local function curve(self,ex,ey,ep,kx,ky,kp,emit)
    local dx,dy=ex-self.cx,ey-self.cy
    if dx==0 and dy==0 then
        self.cp=ep
        return 0
    end
    local length=math.sqrt(dx*dx+dy*dy)
    local deviation=math.abs((kx-self.cx)*dy-(ky-self.cy)*dx)/
        (2*length)
    local steps=math.min(MAX_STEPS,math.max(1,
        math.ceil(math.sqrt(deviation/MAX_ERROR))))
    local x0,y0,p0=self.cx,self.cy,self.cp
    for i=1,steps do
        local t=i/steps
        local a=(1-t)*(1-t)
        local b=2*(1-t)*t
        local c=t*t
        emit(a*x0+b*kx+c*ex,
            a*y0+b*ky+c*ey,
            a*p0+b*kp+c*ep)
    end
    self.cx=ex;self.cy=ey;self.cp=ep
    self.emitted=self.emitted+steps
    return steps
end
function Path:sample(x,y,p,emit)
    assert(not self.finished,'Caminho encerrado')
    checkPoint(x,y,p)
    assert(type(emit)=='function','Saída do caminho inválida')
    if x==self.rawX and y==self.rawY then
        self.rawP=p
        return 0
    end
    -- Quadratic between successive midpoints: a new pointer packet only
    -- adds a bounded curve, with no prediction outside received coordinates.
    local ex,ey=(self.rawX+x)*0.5,(self.rawY+y)*0.5
    local ep=(self.rawP+p)*0.5
    local steps=curve(self,ex,ey,ep,
        self.rawX,self.rawY,self.rawP,emit)
    self.rawX=x;self.rawY=y;self.rawP=p
    return steps
end
function Path:finish(x,y,p,emit)
    assert(not self.finished,'Caminho encerrado')
    assert(type(emit)=='function','Saída do caminho inválida')
    local count=0
    if x~=nil or y~=nil then
        assert(x~=nil and y~=nil,'Coordenada final incompleta')
        count=self:sample(x,y,p or self.rawP,emit)
    end
    -- The real release/cancel endpoint must never be discarded by the
    -- midpoint approximation, including a single high-speed sample.
    count=count+curve(self,self.rawX,self.rawY,self.rawP,
        self.rawX,self.rawY,self.rawP,emit)
    self.finished=true
    return count
end
return Path
