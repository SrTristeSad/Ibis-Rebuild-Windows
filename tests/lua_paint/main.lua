-- Teste de pixels reais do motor Lua no runtime oficial LÖVE 11.5.
function love.load()
    local E = require("lua_engine")
    assert(E.supports(32, 32))
    assert(not E.supports(6000, 1))
    local p = E.new(32, 32)
    local model = {layers = {{id = 1, visible = true, opacity = 100}}}
    E.sync(p, model)
    local layer = p.layers[1]
    E.begin_stroke(p, 1)
    E.stroke(p, 1, 5, 5, 18, 5, 5, {1, 0, 0}, 1, false)
    local r, g, b, a = layer.pixels:getPixel(10, 5)
    assert(r > 0.9 and g < 0.1 and b < 0.1 and a > 0.9,
        "Pincel Lua não produziu pixels vermelhos")
    assert(E.undo(p), "Undo deve funcionar")
    local _, _, _, undone = layer.pixels:getPixel(10, 5)
    assert(undone < 0.01, "Undo não restaurou pixels transparentes")
    assert(E.redo(p), "Redo deve funcionar")
    local _, _, _, redone = layer.pixels:getPixel(10, 5)
    assert(redone > 0.9, "Redo não restaurou o traço")
    E.begin_stroke(p, 1)
    E.stroke(p, 1, 10, 5, 10, 5, 6, {0, 0, 0}, 1, true)
    local _, _, _, erased = layer.pixels:getPixel(10, 5)
    assert(erased < 0.01, "Borracha Lua não removeu o alfa")
    model.layers[#model.layers + 1] = {id = 2, visible = true, opacity = 60}
    E.sync(p, model)
    assert(p.layers[2], "Segunda camada não criada")
    print("PASS: Lua brush/eraser/undo/redo/layers")
    love.event.quit(0)
end
