local Native=require('native')
local Store=require('store')
local Layers=require('layers')
local M={}
function M.run(root)
    assert(Native.available,'A DLL C++ é obrigatória')
    local checks=0
    local function ok(v,msg)checks=checks+1;assert(v,msg)end
    local store=Store.open(root)
    local data={}
    for y=0,2 do
        for x=0,3 do
            data[#data+1]=string.char(20+x*40,30+y*50,80+x+y,70+x+y*3)
        end
    end
    local pixels=table.concat(data)
    local doc=store:createProject('Espelhamento',4,3,'',pixels)
    local layer=Layers.open(store,store:openProject(doc.id))
    local first=Native.bytes(layer:activeBuffer())
    layer:add('Transparente')
    layer:beginEdit()
    layer:pixel(0,0,0xab4875cc)
    ok(layer:finishEdit(),'A camada superior precisa existir')
    layer:select(1)
    ok(layer:flip(0),'Horizontal não gerou operação')
    for y=0,2 do for x=0,3 do
        local i=(y*4+x)*4+1
        local original=(y*4+(3-x))*4+1
        ok(Native.bytes(layer.buffers[1]):sub(i,i+3)==
            first:sub(original,original+3),'Horizontal não preservou RGBA')
    end end
    ok(Native.readPixel(layer.buffers[2],0,0)==0xab4875cc,
        'Espelhamento atingiu outra camada')
    ok(layer:undo(),'Desfazer horizontal falhou')
    ok(Native.bytes(layer.buffers[1])==first,'Desfazer perdeu raster')
    ok(layer:redo(),'Refazer horizontal falhou')
    ok(layer:flip(1),'Vertical não gerou operação')
    local both=Native.bytes(layer.buffers[1])
    for y=0,2 do for x=0,3 do
        local i=(y*4+x)*4+1
        local original=((2-y)*4+(3-x))*4+1
        ok(both:sub(i,i+3)==first:sub(original,original+3),
            'Espelhamento vertical/horizontal incorreto')
    end end
    ok(layer:undo() and layer:undo(),'Undo combinado falhou')
    ok(Native.bytes(layer.buffers[1])==first,
        'Duplo undo não recuperou entrada')
    ok(layer:redo() and layer:redo(),'Redo combinado falhou')
    ok(Native.bytes(layer.buffers[1])==both,
        'Duplo redo não recuperou espelhamento')
    ok(not pcall(function()layer:flip(2)end),'Eixo inválido aceito')
    ok(Native.bytes(layer.buffers[1])==both,
        'Rejeição inválida alterou pixels')
    layer:save()
    local saved=Store.open(root):openProject(doc.id)
    ok(saved.format==2 and saved.layer_count==2 and
        saved.layers[1].pixels==both,'RBD2 perdeu pixels espelhados')
    ok(saved.layers[2].pixels:sub(1,4)==string.char(0xab,0x48,0x75,0xcc),
        'RBD2 alterou camada não selecionada')
    return {suite='native-layer-flip-rbd2',passed=true,
        assertions=checks,exact_rgba=true,undo_redo=true,
        layer_isolation=true,rbd2_roundtrip=true}
end
return M
