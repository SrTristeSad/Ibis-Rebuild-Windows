-- Teste de pixels e persistência reais, executado no LÖVE 11.5 do CI Windows.
local function close(a, b, epsilon) return math.abs(a - b) <= (epsilon or 0.02) end
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

    model.layers[#model.layers + 1] = {id = 2, visible = true, opacity = 50}
    E.sync(p, model)
    assert(p.layers[2], "Segunda camada não criada")
    layer.pixels:setPixel(1, 1, 1, 0, 0, 1)
    p.layers[2].pixels:setPixel(1, 1, 0, 0, 1, 1)
    local cr, cg, cb, ca = E.sample(p, model, 1, 1)
    assert(close(cr, 0.5) and close(cg, 0) and close(cb, 0.5) and close(ca, 1),
        "Composição visível não respeitou a opacidade da camada")
    model.layers[2].visible = false
    local vr, _, vb = E.sample(p, model, 1, 1)
    assert(vr > 0.99 and vb < 0.01, "Conta-gotas ignorou visibilidade da camada")
    model.layers[2].visible = true
    local preview = E.thumbnail(p, model)
    assert(preview:getWidth() == 32 and preview:getHeight() == 32)
    local pr, _, pb = preview:getPixel(1, 1)
    assert(close(pr, 0.5) and close(pb, 0.5),
        "Miniatura não contém pixels compostos")

    local q = E.new(16, 16)
    local qm = {layers = {{id = 1, visible = true, opacity = 100}}}
    E.sync(q, qm)
    q.layers[1].pixels:setPixel(4, 4, 0, 0, 1, 1)
    assert(E.fill(q, 1, 0, 0, {0, 1, 0}, 1), "Balde não preencheu a área transparente")
    local _, green, _, filled = q.layers[1].pixels:getPixel(1, 1)
    local _, _, blue, kept = q.layers[1].pixels:getPixel(4, 4)
    assert(green > 0.99 and filled > 0.99, "Balde não pintou contiguamente")
    assert(blue > 0.99 and kept > 0.99, "Balde ultrapassou a cor fronteira")
    assert(E.undo(q), "Balde sem desfazer")
    local _, _, _, restored = q.layers[1].pixels:getPixel(1, 1)
    assert(restored < 0.01, "Desfazer o balde não restaurou transparência")
    assert(E.redo(q), "Balde sem refazer")
    local _, green_again = q.layers[1].pixels:getPixel(1, 1)
    assert(green_again > 0.99, "Refazer o balde falhou")
    assert(E.fill(q, 1, 1, 1, {0, 1, 0}, 1) == false,
        "Preenchimento idêntico deveria ser no-op")
    local denied, reason = E.fill({w = 1025, h = 1025}, 1, 0, 0, {1, 1, 1}, 1)
    assert(not denied and reason, "Balde deve proteger documentos muito grandes")

    -- Prova de persistência da obra pela ponte usada pelo Ibis-Lua.
    local Bridge = require("lua_bridge")
    local model2 = {
        screen = "editor", document = {width = 16, height = 16},
        layers = {{id = 1, visible = true, opacity = 100,
                   name = "Layer One", blending = "Normal"}},
        active_layer_id = 1, active_tool = "brush", background_mode = "white"
    }
    function model2:active_layer() return self.layers[1] end
    function model2:set_color(red, green_, blue_) self.color = {red, green_, blue_} end
    local gallery = {
        ids = 0,
        records = {},
        get = function(self, id) return self.records[id] end,
        add_artwork = function(self, width, height, name)
            self.ids = self.ids + 1
            self.records[self.ids] = {name = name, width = width, height = height}
            return self.ids
        end
    }
    local id = gallery:add_artwork(16, 16, "Lua persistent")
    Bridge.create(model2, id, gallery)
    local colors = {set_rgb = function(self, red, green_, blue_)
        self.current = {red, green_, blue_}
    end}
    local view = {zoom = 10, rotation = 0, pan_x = 0, pan_y = 0}
    local prefs = {tool_position = "left"}
    local x = 62 + (1024 - 62 - 34) / 2
    local y = 62 + (768 - 160) / 2
    assert(Bridge.mousepressed(model2, id, x, y, 1024, 768,
        view, prefs, {255, 0, 0}, 5, 100, colors))
    Bridge.mousereleased()
    assert(Bridge.save(), "Falha no salvamento da obra em camadas")
    assert(love.filesystem.getInfo("lua-artworks/index.tsv"))
    local index = assert(love.filesystem.read("lua-artworks/index.tsv"))
    local key = assert(index:match("(art_%d+_%d+)"))
    local path = "lua-artworks/" .. key
    assert(love.filesystem.getInfo(path .. "/layer_1.png"))
    assert(love.filesystem.getInfo(path .. "/preview.png"))
    local saved = love.image.newImageData(path .. "/layer_1.png")
    local sr, _, _, sa = saved:getPixel(8, 8)
    assert(sr > 0.9 and sa > 0.9, "PNG da camada não reteve pintura")
    local image = love.image.newImageData(path .. "/preview.png")
    assert(image:getWidth() == 16 and image:getHeight() == 16)
    local model3 = {
        screen = "editor", document = {width = 16, height = 16},
        layers = {{id = 1, name = "temporary", visible = true, opacity = 100,
                   blending = "Normal"}}, active_layer_id = 1,
        active_tool = "eyedropper", background_mode = "white"
    }
    function model3:active_layer() return self.layers[1] end
    function model3:set_color(red, green_, blue_) self.color = {red, green_, blue_} end
    Bridge.open(model3, id)
    assert(model3.layers[1].name == "Layer One", "Metadados da camada não reabertos")
    assert(Bridge.mousepressed(model3, id, x, y, 1024, 768,
        view, prefs, {0, 0, 0}, 5, 100, colors),
        "Conta-gotas não acessou projeto reaberto")
    assert(model3.color[1] > 240 and model3.color[2] < 10,
        "Conta-gotas não encontrou os pixels após reabertura")

    -- Limpeza do armazenamento efêmero do teste (não é o diretório da aplicação real).
    for _, filename in ipairs({"layer_1.png", "preview.png", "layers.tsv"}) do
        love.filesystem.remove(path .. "/" .. filename)
    end
    love.filesystem.remove(path)
    love.filesystem.remove("lua-artworks/index.tsv")
    love.filesystem.remove("lua-artworks")
    print("PASS: Lua brush/eraser/bucket/eyedropper/layers/preview/PNG roundtrip")
    love.event.quit(0)
end
