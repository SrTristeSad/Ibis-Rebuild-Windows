-- Event-driven, bounded mouse stroke smoothing for desktop input.
-- Independent smoothing; rasterisation stays exclusively in the C++ core.
local Stabilizer={}
Stabilizer.__index=Stabilizer
local function valid(n)
    return type(n)=='number' and n==n and n>=-16384 and n<=16384
end
function Stabilizer.new(level,x,y)
    assert(type(level)=='number' and level%1==0 and level>=0 and level<=5,
        'Estabilização deve ser um inteiro de 0 a 5')
    assert(valid(x) and valid(y),'Origem do traço fora do limite')
    return setmetatable({level=level,x=x,y=y,rawX=x,rawY=y,finished=false},
        Stabilizer)
end
-- Discrete first-order low-pass filter, 0 = original mouse samples.
-- No hidden timers or sample interpolation; behavior is event-rate dependent.
function Stabilizer:sample(x,y)
    assert(not self.finished,'Traço já foi encerrado')
    assert(valid(x) and valid(y),'Coordenada de amostra inválida')
    self.rawX=x;self.rawY=y
    local alpha=1/(self.level+1)
    self.x=self.x+(x-self.x)*alpha
    self.y=self.y+(y-self.y)*alpha
    return self.x,self.y
end
-- The final mouse location is always retained. The caller paints the
-- closing segment before recording a single undo operation.
function Stabilizer:finish()
    assert(not self.finished,'Traço já foi encerrado')
    self.finished=true
    return self.rawX,self.rawY
end
return Stabilizer
