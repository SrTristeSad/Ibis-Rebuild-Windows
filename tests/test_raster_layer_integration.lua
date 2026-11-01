package.path='app/?.lua;'..package.path
-- Isola o gerenciador de camadas do adaptador Win32 de disco.
-- Testa as chamadas reais de Layers com o novo modulo native.lua (Lua).
package.loaded.store={MAX_LAYERS=8}
local R=require('native')
local Layers=require('layers')
assert(R.implementation=='lua')
local width,height=32,24
local blank=string.rep('\0',width*height*4)
local doc={id='unit',width=width,height=height,active_layer=1,layer_count=1,
    layers={{id=1,name='Raster',pixels=blank,visible=true,opacity=1}}}
local saved
local store={saveProject=function(_,d) saved=d end,
    newLayerId=function() return 2 end}
local session=Layers.open(store,doc)
assert(session:activeBuffer().width==32)
session:beginEdit()
session:beginStrokeAccum()
session:pressureStroke(10.5,10.5,10.5,10.5,8,8,0xff0000ff,
    0.5,0.5,1,0,0,0,true)
local a=R.readPixel(session:activeBuffer(),10,10)%256
assert(a>0)
session:pressureStroke(8.5,10.5,14.5,10.5,8,8,0xff0000ff,
    0.5,0.5,1,0,0,0,true)
assert(R.readPixel(session:activeBuffer(),10,10)%256==a)
session:recomposeRect({x=5,y=5,w=15,h=15})
assert(R.readPixel(session.composite,10,10)%256==a)
assert(session:finishEdit())
assert(session:historyStats().undo==1)
local after=R.bytes(session:activeBuffer())
assert(session:undo())
assert(R.bytes(session:activeBuffer())==blank)
assert(session:redo())
assert(R.bytes(session:activeBuffer())==after)
session:save()
assert(saved==doc and saved.layers[1].pixels==after)
assert(session:drawShape(1,1,8,8,0,true,1,0x00ff00ff))
assert(session:fill(0,0,0x0000ffff,0)>0)
assert(session:historyStats().undo==3)
print('Lua layer integration: pressure, composite, history, RBD2 source pixels, geometry, fill OK')
