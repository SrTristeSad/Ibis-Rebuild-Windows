package.path='app/?.lua;'..package.path
-- Isola o gerenciador de camadas do adaptador Win32 de disco.
-- Testa as chamadas reais de Layers com o novo modulo native.lua (Lua).
local previousStore=package.loaded.store
local previousLayers=package.loaded.layers
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
-- Alpha Lock: pixel-perfect original alpha, no paint on transparency,
-- coverage accumulation, bucket, eraser, shape and chronological history.
local seed=string.char(20,40,60,255,0,0,0,0,
    25,50,75,128,0,0,0,0)
local lockedDoc={id='locked',width=4,height=1,
    active_layer=1,layer_count=1,layers={{
        id=1,name='Pintura',visible=true,opacity=1,
        alpha_lock=false,pixels=seed}}}
local locked=Layers.open(store,lockedDoc)
assert(locked:setAlphaLock(1,true))
assert(locked.buffers[1].alphaLock)
assert(locked:historyStats().undo==1)
assert(locked:undo())
assert(not locked.doc.layers[1].alpha_lock and
    not locked.buffers[1].alphaLock)
assert(locked:redo())
assert(locked.doc.layers[1].alpha_lock and
    locked.buffers[1].alphaLock)
locked:beginEdit()
locked:beginStrokeAccum()
locked:pressureStroke(.5,.5,3.5,.5,3,3,0xff0000ff,
    1,1,1,0,0,0,true)
locked:pressureStroke(.5,.5,3.5,.5,3,3,0xff0000ff,
    1,1,1,0,0,0,true)
assert(locked:finishEdit())
local painted=R.bytes(locked:activeBuffer())
assert(painted:byte(1)==255 and painted:byte(4)==255
    and painted:byte(5)==0 and painted:byte(8)==0
    and painted:byte(9)==255 and painted:byte(12)==128
    and painted:byte(16)==0,
    'Alpha lock stroke modified transparent or partial alpha')
assert(locked:undo())
assert(R.bytes(locked:activeBuffer())==seed and
    locked.doc.layers[1].alpha_lock,
    'Undo stroke lost alpha lock')
assert(locked:redo())
assert(R.bytes(locked:activeBuffer())==painted,
    'Redo stroke lost locked RGB')
locked:beginEdit()
locked:beginStrokeAccum()
locked:pressureStroke(.5,.5,3.5,.5,4,4,0x00000000,
    1,1,1,0,0,2,true)
assert(not locked:finishEdit(),
    'Eraser must not change pixels when alpha is locked')
locked:beginEdit()
locked:pixel(1,0,0xffffffff)
locked:pixel(2,0,0x00ff00ff)
assert(locked:finishEdit())
assert(R.readPixel(locked:activeBuffer(),1,0)==0)
assert(R.readPixel(locked:activeBuffer(),2,0)==0x00ff0080,
    'Pixel tool failed to preserve 128/255 alpha')
assert(locked:drawShape(0,0,3,0,0,true,1,0x0000ffff))
assert(R.readPixel(locked:activeBuffer(),1,0)==0 and
    R.readPixel(locked:activeBuffer(),2,0)%256==128,
    'Shape tool modified transparency on alpha lock')
local filled=locked:fill(2,0,0xff00ffff,0)
assert(filled>0 and
    R.readPixel(locked:activeBuffer(),2,0)%256==128
    and R.readPixel(locked:activeBuffer(),1,0)==0,
    'Bucket fill ignored alpha lock')
locked:save()
assert(saved.layers[1].alpha_lock==true,
    'Save dropped alpha lock flag')
package.loaded.store=previousStore
package.loaded.layers=previousLayers
print('Lua layer integration: pressure, composite, history, RBD2 source pixels, geometry, fill OK')
