-- Independent color parser + the real C++ sample/stroke paths and RBD2.
local Colors=require('colors')
local Native=require('native')
local Layers=require('layers')
local Store=require('store')
local T={}
function T.run(root)
    local checked=0
    local function check(ok,msg) checked=checked+1;assert(ok,msg) end
    local samples={
        {'#FF00CC',0xff00ccff,'#FF00CCFF'},
        {'abcd12',0xabcd12ff,'#ABCD12FF'},
        {'#aBcD12a9',0xabcd12a9,'#ABCD12A9'},
        {'00000000',0,'#00000000'},
        {'FFFFFFFF',0xffffffff,'#FFFFFFFF'},
        {'  12345678  ',0x12345678,'#12345678'}
    }
    for _,item in ipairs(samples) do
        local value,err=Colors.parseHex(item[1])
        check(value==item[2],err or 'Hex RGBA parsed incorrectly')
        check(Colors.format(value)==item[3],'Round-trip format incorrect')
    end
    for _,input in ipairs({'','bad','12345','1234567','123456789',
        '#12GG66','##123456',1,nil}) do
        local value=Colors.parseHex(input)
        check(value==nil,'Invalid hex accepted: '..tostring(input))
    end
    local store=Store.open(root)
    local project=store:createProject('Cores e linha',12,12,'',
        string.rep('\0',12*12*4))
    local scene=Layers.open(store,store:openProject(project.id))
    scene:pixel(1,2,0x1256abff)
    scene:add('Camada superior')
    check(Native.readPixel(scene.composite,1,2)==0x1256abff,
        'Composite eyedropper should see underlying color')
    check(Native.readPixel(scene:activeBuffer(),1,2)==0,
        'Active-only eyedropper must see transparency')
    scene:pixel(1,2,0xff44cc80)
    local composited=Native.readPixel(scene.composite,1,2)
    check(composited~=0xff44cc80 and composited~=0x1256abff and
        composited%256==255,
        'Composited eyedropper must read actual source-over color')
    check(Native.readPixel(scene:activeBuffer(),1,2)==0xff44cc80,
        'Active-only eyedropper must see unblended RGBA')
    check(Native.readPixel(scene.buffers[1],1,2)==0x1256abff,
        'Top-layer color modified underlying pixel')
    local red=assert(Colors.parseHex('#EE4411'))
    check(scene:straightLine(1,6,6,6,1,red),'Native straight line not committed')
    check(Native.readPixel(scene:activeBuffer(),1,6)==red,'Line start missing')
    check(Native.readPixel(scene:activeBuffer(),3,6)==red,'Line not continuous')
    check(Native.readPixel(scene:activeBuffer(),6,6)==red,'Line end missing')
    check(Native.readPixel(scene:activeBuffer(),1,5)==0,'Line drew outside thin boundary')
    check(scene:undo(),'Native line cannot be undone')
    check(Native.readPixel(scene.composite,3,6)==0,'Undo left pixels')
    check(scene:redo(),'Native line cannot be redone')
    check(Native.readPixel(scene.composite,3,6)==red,'Redo did not restore pixels')
    check(scene:historyStats().undo==1,'Straight line should be one history item')
    scene:save()
    local reopened=Store.open(root):openProject(project.id)
    check(reopened.format==2 and reopened.layer_count==2,'RBD2 structure lost')
    local again=Layers.open(Store.open(root),reopened)
    check(Native.readPixel(again.composite,3,6)==red,'Line lost on reopen')
    check(Native.readPixel(again.composite,1,2)==0xff44cc80,'Upper color lost')
    check(Native.readPixel(again.buffers[1],1,2)==0x1256abff,'Lower color lost')
    check(not again:canUndo(),'Session history must not be persisted')
    return {suite='colors-eyedropper-straight-lines',passed=true,
        assertions=checked,hex_rgba=true,native_color_sampling=true,
        line_cpp=true,line_undo_redo=true,rbd2_roundtrip=true}
end
return T
