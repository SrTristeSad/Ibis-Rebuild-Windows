package.path='app/?.lua;'..package.path
-- Testes apenas de amostras de caneta sinteticas; hardware real nao simulado.
local Ink=require('windows_ink')
local eq=function(a,b,label)
    assert(a==b,(label or 'valor')..': '..tostring(a)..' ~= '..tostring(b))
end
eq(Ink.normalizePressure(500,0),1,'sem campo de pressao')
eq(Ink.normalizePressure(0,1),0,'pressao zero')
eq(Ink.normalizePressure(1024,1),1,'pressao maxima')
eq(Ink.normalizePressure(2048,1),1,'pressao saturada')
eq(Ink.normalizePressure(512,1),0.5,'pressao media')
Ink._resetTest()
assert(Ink._drainTest()==nil)
Ink._offerTest({kind=1,id=11,x=10,y=20,pressure=.8,tiltX=-20,tiltY=10})
Ink._offerTest({kind=2,id=11,x=11,y=21,pressure=.5,tiltX=-20,tiltY=10})
Ink._offerTest({kind=3,id=11,x=12,y=22,pressure=.1,tiltX=0,tiltY=0})
local a,b,c=Ink._drainTest(),Ink._drainTest(),Ink._drainTest()
eq(a.kind,1);eq(a.id,11);eq(a.pressure,.8)
eq(b.kind,2);eq(b.pressure,.5);eq(c.kind,3)
eq(Ink._drainTest(),nil)
Ink._resetTest()
-- Lotacao nunca pode impedir inserir um evento de soltura.
for i=1,600 do
    Ink._offerTest({kind=2,id=4,pressure=.3,x=i,y=10})
end
Ink._offerTest({kind=3,id=4,x=600,y=10,pressure=0})
local last,seenEnd=nil,false
while true do
    local event=Ink._drainTest()
    if not event then break end
    last=event
    if event.kind==3 then seenEnd=true end
end
assert(Ink.dropped>0 and seenEnd and last.kind==3,'soltura perdida na fila cheia')
-- Um DOWN no inicio nunca deve ser expulso por centenas de MOVE.
Ink._resetTest()
Ink._offerTest({kind=1,id=4,x=1,y=10,pressure=.4})
for i=1,600 do
    Ink._offerTest({kind=2,id=4,pressure=.3,x=i,y=10})
end
Ink._offerTest({kind=3,id=4,x=600,y=10,pressure=0})
local first=Ink._drainTest()
eq(first.kind,1,'DOWN foi perdido com fila saturada')
local final=nil
repeat
    local event=Ink._drainTest()
    if event then final=event end
until not event
assert(final and final.kind==3,'UP deve ser entregue mesmo na saturacao')
Ink._resetTest()
Ink._resetTest()
assert(Ink.dropped==0)
print('Lua Windows Ink: pressure mask, FIFO, overflow and release: OK')
