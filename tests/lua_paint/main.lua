-- Teste de pixels e persistência reais, executado no LÖVE 11.5 do CI Windows.
-- Testes automatizados não podem ficar presos na tela de erro gráfica do LÖVE.
function love.errorhandler(message)
    io.stderr:write("LUA_TEST_ERROR: ", tostring(message), "\n", debug.traceback(), "\n")
    io.stderr:flush()
    return function() return 1 end
end

local function close(a, b, epsilon) return math.abs(a - b) <= (epsilon or 0.02) end
local function checkpoint(name)
    io.stdout:write("LUA_STAGE ", name, "\n")
    io.stdout:flush()
end

-- Feather separável e pintura com cobertura parcial da máscara em RGBA.
local function test_feather_paint(E)
    local Selection = require("lua_selection")
    local p = E.new(32, 32)
    local model = {layers = {{id = 1, visible = true, opacity = 100}}}
    E.sync(p, model)
    local rectangle = assert(Selection.rectangle(32, 32, 4, 4, 8, 8))
    local feather = assert(Selection.feather(rectangle, 1))
    assert(feather.kind == "feathered" and Selection.is_soft(feather),
           "Feather deveria criar máscara com pesos RGBA")
    local full = Selection.coverage(feather, 6, 6)
    local corner = Selection.coverage(feather, 4, 4)
    local outer = Selection.coverage(feather, 3, 3)
    assert(close(full, 1, 1 / 255) and
           close(corner, 4 / 9, 1 / 255) and
           close(outer, 1 / 9, 1 / 255) and
           Selection.coverage(feather, 2, 2) == 0 and
           feather.count > rectangle.count and
           rectangle.count == 25 and not Selection.is_soft(rectangle),
           "Box blur radius=1 não produziu os pesos de cobertura esperados")
    assert(Selection.coverage(nil, 0, 0) == 1,
           "Sem seleção, a pintura não deve ser reduzida")
    local radius2 = assert(Selection.feather(rectangle, 2))
    assert(radius2.count > 25 and
           close(Selection.coverage(radius2, 6, 6), 1) and
           Selection.coverage(radius2, 2, 2) > 0,
           "Raio de feather 2 não suavizou a borda em duas células")
    local smaller = assert(Selection.feather(feather, 1))
    assert(Selection.is_soft(smaller) and smaller.count >= feather.count,
           "Feather repetido não manteve a máscara suave")
    local invalid, reason = Selection.feather(rectangle, 0)
    assert(not invalid and reason, "Raio 0 de feather foi aceito")
    invalid, reason = Selection.feather(rectangle, 9)
    assert(not invalid and reason, "Raio >8 de feather foi aceito")
    invalid, reason = Selection.feather(rectangle, 1.5)
    assert(not invalid and reason, "Raio fracionário de feather foi aceito")
    invalid, reason = Selection.feather(nil, 2)
    assert(not invalid and reason, "Feather sem máscara foi aceito")
    local huge = {w = 1025, h = 1025, count = 1, mask = {[0] = true}}
    invalid, reason = Selection.feather(huge, 2)
    assert(not invalid and reason, "Feather ignorou limite de canvas")

    -- DAB central com dois passos coincidentes da função stroke.
    E.stroke(p, 1, 4.5, 4.5, 4.5, 4.5, 1,
             {1, 0, 0}, 1, false, false, feather)
    local r, _, _, a = p.layers[1].pixels:getPixel(4, 4)
    local expected = 1 - (1 - corner) ^ 2
    assert(close(r, 1) and close(a, expected, 0.018) and
           select(4, p.layers[1].pixels:getPixel(3, 3)) == 0,
           "Pincel não respeitou alfa fracionário da seleção")
    assert(E.undo(p, feather) == false,
           "Stroke direto sem begin_stroke não deveria criar histórico")
    local brushmask = assert(Selection.clone(feather))
    assert(brushmask.weights ~= feather.weights and
           close(Selection.coverage(brushmask, 4, 4), corner),
           "Clone compartilhou indevidamente pesos da máscara")
    assert(Selection.save(feather, "lua-feather-weight.png"))
    local reopened = assert(Selection.load("lua-feather-weight.png", 32, 32))
    assert(Selection.is_soft(reopened) and reopened.count == feather.count and
           close(Selection.coverage(reopened, 4, 4), corner, 1 / 255) and
           close(Selection.coverage(reopened, 3, 3), outer, 1 / 255) and
           Selection.coverage(reopened, 2, 2) == 0,
           "PNG de seleção não preservou intensidade do feather")
    assert(love.filesystem.remove("lua-feather-weight.png"))

    -- Balde scanline aplica alfa independente a cada pixel sem mudar limites.
    local fill = E.new(32, 32)
    E.sync(fill, model)
    assert(E.fill(fill, 1, 6, 6, {0, 0, 1}, 1, false, feather))
    local _, _, center_b, center_a = fill.layers[1].pixels:getPixel(6, 6)
    local _, _, corner_b, corner_a = fill.layers[1].pixels:getPixel(4, 4)
    local _, _, outer_b, outer_a = fill.layers[1].pixels:getPixel(3, 3)
    assert(center_b > 0.99 and close(center_a, full, 0.018) and
           corner_b > 0.99 and close(corner_a, corner, 0.018) and
           outer_b > 0.99 and close(outer_a, outer, 0.018) and
           select(4, fill.layers[1].pixels:getPixel(2, 2)) == 0,
           "Balde não aplicou a máscara com alfa variável")

    -- Borracha reduz alfa multiplicando por (1 - cobertura).
    local erase = E.new(32, 32)
    E.sync(erase, model)
    erase.layers[1].pixels:setPixel(4, 4, 0.5, 0.8, 0.2, 1)
    E.stroke(erase, 1, 4.5, 4.5, 4.5, 4.5, 1,
             {0, 0, 0}, 1, true, false, feather)
    local er, eg, _, ea = erase.layers[1].pixels:getPixel(4, 4)
    assert(close(ea, (1 - corner) ^ 2, 0.018) and
           close(er, 0.5, 0.018) and close(eg, 0.8, 0.018),
           "Borracha modificou RGB ou apagou alfa além da cobertura")
    -- Alpha Lock mistura apenas RGB, preservando alfa original.
    local lock = E.new(32, 32)
    E.sync(lock, model)
    lock.layers[1].pixels:setPixel(4, 4, 0, 0, 1, 0.7)
    E.stroke(lock, 1, 4.5, 4.5, 4.5, 4.5, 1,
             {1, 0, 0}, 1, false, true, feather)
    local lr, _, lb, la = lock.layers[1].pixels:getPixel(4, 4)
    assert(close(lr, expected, 0.025) and
           close(lb, 1 - expected, 0.025) and close(la, 0.7),
           "Alpha Lock não respeitou feather ou modificou canal alfa")

    local inverted = assert(Selection.invert(feather, 32, 32))
    assert(close(Selection.coverage(inverted, 4, 4), 1 - corner, 1 / 255) and
           Selection.coverage(inverted, 2, 2) == 1,
           "Inversão não preservou pesos da seleção suave")
    local union = assert(Selection.combine(feather, inverted, "add", 32, 32))
    assert(close(Selection.coverage(union, 4, 4),
                 math.max(corner, 1 - corner), 1 / 255),
           "União alterou incorretamente os pesos do feather")
    local shrunk = assert(Selection.morph(feather, "contract"))
    assert(Selection.is_soft(shrunk) and
           Selection.coverage(shrunk, 5, 5) > 0 and
           Selection.coverage(shrunk, 5, 5) < 1,
           "Contração não preservou pesos graduais da máscara")
end

-- Transformações e prévia GPU preservam frações da seleção.
local function test_feather_transform(E)
    local Selection = require("lua_selection")
    local model = {layers = {{id = 1, visible = true, opacity = 100}}}
    local p = E.new(32, 32)
    E.sync(p, model)
    local mask = assert(Selection.from_mask(32, 32, {
        [5 + 5 * 32] = 0.5, [6 + 5 * 32] = true
    }, "feathered"))
    local layer = p.layers[1]
    layer.pixels:setPixel(5, 5, 1, 0, 0, 1)
    layer.pixels:setPixel(6, 5, 0, 0, 1, 1)
    layer.image:replacePixels(layer.pixels)
    p.dirty = false
    local preview = assert(E.begin_move_preview(p, 1, mask))
    assert(E.update_move_preview(p, mask, preview, 2, 0))
    local image = preview.image:newImageData()
    assert(close(select(4, image:getPixel(5, 5)), 0.5, 0.025) and
           close(select(4, image:getPixel(7, 5)), 0.5, 0.025),
           "Prévia GPU move ignorou cobertura parcial")
    assert(not p.dirty and #p.undo == 0 and
           close(select(4, layer.pixels:getPixel(5, 5)), 1),
           "Prévia modificou pixels reais")
    assert(E.move_selection(p, 1, mask, 2, 0))
    assert(close(select(4, layer.pixels:getPixel(5, 5)), 0.5) and
           close(select(4, layer.pixels:getPixel(7, 5)), 0.5) and
           close(Selection.coverage(mask, 7, 5), 0.5) and
           mask.min_x == 7,
           "Move CPU não separou conteúdo e geometria suavizados")
    assert(E.undo(p, mask) and mask.min_x == 5 and
           close(Selection.coverage(mask, 5, 5), 0.5) and
           close(select(4, layer.pixels:getPixel(5, 5)), 1),
           "Undo não restaurou pesos, posição e pixels originais")
    assert(E.redo(p, mask) and mask.min_x == 7,
           "Redo não restaurou seleção suave movida")
    preview.image:release()
    preview.mask_image:release()

    local copyproj = E.new(32, 32)
    E.sync(copyproj, model)
    copyproj.layers[1].pixels:setPixel(5, 5, 1, 0, 0, 1)
    local soft = assert(Selection.from_mask(32, 32, {[5 + 5 * 32] = 0.5},
                                         "feathered"))
    local clip = assert(E.copy_selection(copyproj, 1, soft))
    assert(close(select(4, clip.pixels:getPixel(0, 0)), 0.5) and
           close(clip.mask[0], 0.5),
           "Copiar conteúdo com feather perdeu alfa")
    local ok, cut = E.cut_selection(copyproj, 1, soft)
    assert(ok and cut and
           close(select(4, copyproj.layers[1].pixels:getPixel(5, 5)), 0.5),
           "Cut apagou conteúdo que deveria permanecer")
    assert(E.paste_selection(copyproj, 1, clip, 8, 8, soft))
    assert(close(select(4, copyproj.layers[1].pixels:getPixel(8, 8)), 0.5)
           and close(Selection.coverage(soft, 8, 8), 0.5),
           "Paste não preservou alfa ou máscara fracionária")
    assert(E.undo(copyproj, soft) and
           close(select(4, copyproj.layers[1].pixels:getPixel(8, 8)), 0),
           "Undo da colagem com feather falhou")

    local rot = E.new(32, 32)
    E.sync(rot, model)
    rot.layers[1].pixels:setPixel(8, 8, 0, 1, 0, 1)
    local rotated = assert(Selection.from_mask(32, 32, {
        [8 + 8 * 32] = 0.5, [9 + 8 * 32] = true
    }, "feathered"))
    assert(E.reshape_selection(rot, 1, rotated, "flip_horizontal"))
    assert(close(Selection.coverage(rotated, 9, 8), 0.5) and
           close(select(4, rot.layers[1].pixels:getPixel(8, 8)), 0.5) and
           close(select(4, rot.layers[1].pixels:getPixel(9, 8)), 0.5),
           "Flip não preservou pesos de máscara ou conteúdo residual")
    assert(E.undo(rot, rotated) and
           close(Selection.coverage(rotated, 8, 8), 0.5),
           "Undo de flip com feather perdeu pesos")

    local affine = E.new(32, 32)
    E.sync(affine, model)
    for y = 11, 16 do
        for x = 11, 16 do
            affine.layers[1].pixels:setPixel(x, y,
                x / 32, y / 32, 0.8, 0.9)
        end
    end
    affine.layers[1].image:replacePixels(affine.layers[1].pixels)
    local sel = assert(Selection.feather(
        assert(Selection.rectangle(32, 32, 11, 11, 16, 16)), 1))
    local gpu = assert(E.begin_affine_gpu_preview(affine, 1, sel))
    assert(E.update_affine_gpu_preview(affine, sel, gpu, 20, 1.15, 0.9))
    local expected = gpu.image:newImageData()
    assert(E.affine_selection(affine, 1, sel, 20, 1.15, 0.9, "bilinear"))
    local max_error = 0
    for y = 0, 31 do
        for x = 0, 31 do
            local cr, cg, cb, ca = affine.layers[1].pixels:getPixel(x, y)
            local pr, pg, pb, pa = expected:getPixel(x, y)
            max_error = math.max(max_error, math.abs(ca - pa),
                math.abs(cr * ca - pr * pa),
                math.abs(cg * ca - pg * pa),
                math.abs(cb * ca - pb * pa))
        end
    end
    assert(max_error < 0.07,
           string.format("Feather GPU/CPU afim divergiu: %.4f", max_error))
    assert(Selection.is_soft(sel) and E.undo(affine, sel) and
           Selection.is_soft(sel) and E.redo(affine, sel),
           "Undo/redo da transformação afim perdeu pesos")
    gpu.image:release()
    gpu.mask_image:release()
end

-- Persistência independente de undo/redo da seleção: PNGs, nil, alfa,
-- revisão de gerações e rejeição total de conjuntos inconsistentes.
local function test_selection_history_storage()
    local Selection = require("lua_selection")
    local Store = require("lua_selection_history")
    local path = "lua-selection-history-storage-test"
    assert(love.filesystem.createDirectory(path))
    local rect = assert(Selection.rectangle(16, 16, 2, 2, 6, 6))
    local soft = assert(Selection.feather(rect, 1))
    local whole = assert(Selection.all(16, 16))
    local undo = {{mask = nil}, {mask = rect}, {mask = soft}}
    local redo = {{mask = whole}, {mask = nil}}
    local saved, total = Store.save(path, 16, 16, rect, undo, redo)
    assert(saved and total == 5,
           "Falha ao salvar histórico de seleção com máscaras nil/feather")
    local current_manifest = assert(love.filesystem.read(
        path .. "/selection_history.tsv"))
    local old_generation = assert(current_manifest:match(
        "IBIS_LUA_SELECTION_HISTORY_V1\t16\t16\t(%d+_%d+)"))
    assert(love.filesystem.getInfo(path ..
        "/selection_history_" .. old_generation .. "_undo_3.png"),
        "Snapshot PNG de feather não foi gravado")
    local recovered = assert(Store.load(path, 16, 16, rect))
    assert(#recovered.undo == 3 and #recovered.redo == 2 and
           recovered.undo[1].mask == nil and
           recovered.redo[2].mask == nil and
           recovered.undo[2].mask.count == 25 and
           Selection.is_soft(recovered.undo[3].mask) and
           close(Selection.coverage(recovered.undo[3].mask, 2, 2),
                 Selection.coverage(soft, 2, 2), 1 / 255),
           "Reabertura perdeu a máscara nil, ordem ou alfa fracionário")
    -- O conjunto não pode ser usado para restaurar uma outra seleção.
    local stale, stale_reason = Store.load(path, 16, 16, whole)
    assert(not stale and stale_reason,
           "Manifesto de outra máscara foi aceito para a obra")
    assert(not Store.load(path, 15, 16, rect),
           "Histórico não rejeitou dimensões diferentes")
    assert(not Store.load(path, 1025, 1025, rect),
           "Histórico excedeu limite de 1 Mi de pixels")
    assert(not Store.save(path, 16, 16, rect,
        {{mask = rect}, {mask = rect}, {mask = rect}, {mask = rect},
         {mask = rect}, {mask = rect}, {mask = rect}, {mask = rect},
         {mask = rect}}, {}),
        "Salvamento permitiu mais de oito snapshots")
    assert(love.filesystem.read(path .. "/selection_history.tsv") ==
           current_manifest,
           "Falha de salvamento sobrescreveu um manifesto válido")

    -- Novo salvamento publica geração nova e descarta PNGs antigos.
    assert(Store.save(path, 16, 16, soft, {{mask = rect}}, {}))
    local next_manifest = assert(love.filesystem.read(
        path .. "/selection_history.tsv"))
    local next_generation = assert(next_manifest:match(
        "IBIS_LUA_SELECTION_HISTORY_V1\t16\t16\t(%d+_%d+)"))
    assert(next_generation ~= old_generation and
           not love.filesystem.getInfo(path ..
             "/selection_history_" .. old_generation .. "_undo_3.png") and
           love.filesystem.getInfo(path ..
             "/selection_history_" .. next_generation .. "_undo_1.png"),
           "Limpeza de geração de máscara não removeu PNGs antigos")
    local loaded_again = assert(Store.load(path, 16, 16, soft))
    assert(#loaded_again.undo == 1 and #loaded_again.redo == 0)

    -- PNG corrompido invalida a timeline INTEIRA, não apenas um passo.
    assert(love.filesystem.write(path ..
        "/selection_history_" .. next_generation .. "_undo_1.png",
        "isto-nao-e-um-png"))
    local invalid, message = Store.load(path, 16, 16, soft)
    assert(not invalid and message,
           "PNG de seleção corrompido não invalidou histórico")

    -- Mesmo um arquivo PNG válido, mas de outra máscara, é rejeitado.
    assert(Store.save(path, 16, 16, soft, {{mask = rect}}, {}))
    local regenerated = assert(love.filesystem.read(
        path .. "/selection_history.tsv"))
    local newgen = assert(regenerated:match(
        "IBIS_LUA_SELECTION_HISTORY_V1\t16\t16\t(%d+_%d+)"))
    assert(Selection.save(whole, path ..
        "/selection_history_" .. newgen .. "_undo_1.png"))
    assert(not Store.load(path, 16, 16, soft),
           "PNG válido trocado não foi rejeitado pela assinatura")

    assert(Store.save(path, 16, 16, soft, {{mask = rect}}, {}))
    local good = assert(love.filesystem.read(path .. "/selection_history.tsv"))
    local mismatched, changed = good:gsub(
        "undo\t1\t1\t%d+_%d+_%d+", "undo\t1\t1\t1_2_3")
    assert(changed == 1 and
           love.filesystem.write(path .. "/selection_history.tsv",
                                 mismatched))
    assert(not Store.load(path, 16, 16, soft),
           "Checksum modificado no manifesto foi aceito")
    assert(love.filesystem.write(path .. "/selection_history.tsv",
        string.rep("X", 5000)))
    assert(not Store.load(path, 16, 16, soft),
           "Manifesto excessivamente grande foi aceito")
    assert(love.filesystem.write(path .. "/selection_history.tsv",
        "IBIS_LUA_SELECTION_HISTORY_V1\t16\t16\t1_1\tbad\n" ..
        "redo\t9\t0\tempty"))
    assert(not Store.load(path, 16, 16, soft),
           "Ordem/índice de histórico inválido foi aceito")

    -- Histórico de máscara vazia (nil) é persistível e reversível.
    assert(Store.save(path, 16, 16, nil, {{mask = soft}}, {{mask = nil}}))
    local nil_current = assert(Store.load(path, 16, 16, nil))
    assert(#nil_current.undo == 1 and #nil_current.redo == 1 and
           nil_current.redo[1].mask == nil and
           Selection.is_soft(nil_current.undo[1].mask),
           "Histórico com seleção atual nil não foi restaurado")
    assert(Store.save(path, 16, 16, nil, {}, {}))
    assert(not love.filesystem.getInfo(path .. "/selection_history.tsv"))
    for _, name in ipairs(love.filesystem.getDirectoryItems(path)) do
        assert(not name:match("^selection_history_"),
               "Limpeza de histórico vazio deixou snapshot órfão")
    end
    assert(love.filesystem.remove(path))
end

-- Histórico próprio da máscara (sem criar ou reverter snapshots raster).
local function test_selection_only_history(Bridge, gallery)
    local Selection = require("lua_selection")
    local model = {
        screen = "editor", document = {width = 16, height = 16},
        layers = {{id = 1, visible = true, opacity = 100,
                   blending = "Normal", name = "Mask timeline"}},
        active_layer_id = 1, active_tool = "transform",
        background_mode = "white"
    }
    function model:active_layer() return self.layers[1] end
    local art = gallery:add_artwork(16, 16, "Selection timeline")
    Bridge.create(model, art, gallery)
    local function keys(key, alt, shift)
        local old = love.keyboard.isDown
        love.keyboard.isDown = function(...)
            for i = 1, select("#", ...) do
                local k = select(i, ...)
                if k == "lctrl" then return true end
                if alt and k == "lalt" then return true end
                if shift and k == "lshift" then return true end
            end
            return false
        end
        local consumed = Bridge.keypressed(key, model)
        love.keyboard.isDown = old
        return consumed
    end
    local function coverage(x, y)
        return Selection.coverage(Bridge.selection_snapshot(), x, y)
    end
    local function history()
        return Bridge.selection_history_snapshot()
    end
    assert(keys("z", true, false) and keys("y", true, false) and
           not Bridge.selection_undo() and not Bridge.selection_redo() and
           history().undo == 0 and history().redo == 0,
           "Novo documento não deve começar com histórico de máscara")
    assert(keys("a", false, false))
    assert(Bridge.selection_snapshot().count == 256 and
           history().undo == 1 and history().redo == 0,
           "Ctrl+A deveria criar um passo na timeline da seleção")
    assert(keys("a", false, false) and history().undo == 1,
           "Ctrl+A repetido não deveria gravar um no-op")
    model.layers[1].locked, model.layers[1].alpha_lock = true, true
    assert(keys("f", true, false))
    local soft = assert(Bridge.selection_snapshot())
    local softened = coverage(0, 0)
    assert(softened > 0 and softened < 1 and
           Selection.is_soft(soft) and history().undo == 2,
           "Feather não entrou no histórico independente")
    assert(keys("z", true, false) and
           not Selection.is_soft(Bridge.selection_snapshot()) and
           coverage(0, 0) == 1 and
           history().undo == 1 and history().redo == 1,
           "Ctrl+Alt+Z não restaurou máscara binária anterior")
    assert(keys("y", true, false) and
           close(coverage(0, 0), softened, 1 / 255) and
           Selection.is_soft(Bridge.selection_snapshot()) and
           history().redo == 0,
           "Ctrl+Alt+Y não restaurou a cobertura suave")
    assert(keys("d", false, false) and not Bridge.selection_snapshot() and
           history().undo == 3,
           "Ctrl+D deveria permitir recuperar seleção via mask undo")
    assert(keys("z", true, false) and
           close(coverage(0, 0), softened, 1 / 255),
           "Undo de desmarcar perdeu a intensidade do feather")
    assert(keys("i", false, true))
    assert(history().redo == 0,
           "Nova operação após undo precisa invalidar redo de máscara")
    assert(keys("y", true, false) and not Bridge.selection_redo(),
           "Redo obsoleto foi aceito")
    assert(Bridge.selection_snapshot() ~= nil and
           history().undo >= 3 and not Bridge.undo(),
           "Histórico de máscara deveria ser independente do raster")
    model.layers[1].locked, model.layers[1].alpha_lock = false, false

    -- Cria retângulo através dos eventos reais da ponte. O snapshot de
    -- antes do mousepress deve ser restaurável, inclusive após replace.
    local view = {zoom = 10, rotation = 0, pan_x = 0, pan_y = 0}
    local prefs = {tool_position = "left"}
    local function screen(x, y)
        return 62 + (1024 - 62 - 34) / 2 + (x + 0.5 - 8) * 11,
               62 + (768 - 160) / 2 + (y + 0.5 - 8) * 11
    end
    local function shape(x1, y1, x2, y2, ctrl, shift)
        local mx, my = screen(x1, y1)
        local nx, ny = screen(x2, y2)
        local old = love.keyboard.isDown
        love.keyboard.isDown = function(...)
            for i = 1, select("#", ...) do
                local k = select(i, ...)
                if ctrl and k == "lctrl" then return true end
                if shift and k == "lshift" then return true end
            end
            return false
        end
        local accepted = Bridge.mousepressed(model, art, mx, my, 1024, 768,
                                view, prefs, {255, 0, 0}, 2, 100, nil)
        love.keyboard.isDown = old
        assert(accepted and Bridge.mousereleased(model, nx, ny, 1),
               "Gesto de retângulo na timeline falhou")
    end
    local before = assert(Bridge.selection_snapshot())
    shape(3, 3, 6, 6, false, false)
    assert(Bridge.selection_snapshot().count == 16)
    assert(keys("z", true, false))
    local back = assert(Bridge.selection_snapshot())
    assert(back.count == before.count and
           close(Selection.coverage(back, 0, 0),
                 Selection.coverage(before, 0, 0), 1 / 255),
           "Undo de gesto replace não recuperou seleção anterior")
    assert(keys("y", true, false) and
           Bridge.selection_snapshot().count == 16,
           "Redo de gesto de retângulo falhou")
    shape(5, 5, 8, 8, true, true)
    assert(Bridge.selection_snapshot().count == 28,
           "União via Ctrl+Shift falhou antes do histórico")
    assert(keys("z", true, false) and
           Bridge.selection_snapshot().count == 16,
           "Undo de combinação booleana não restaurou área anterior")
    assert(keys("y", true, false) and
           Bridge.selection_snapshot().count == 28,
           "Redo de combinação booleana não recuperou área")

    -- Um único snapshot raster não pode ser afetado por mask undo.
    model.active_tool = "brush"
    local mx, my = screen(3, 3)
    assert(Bridge.mousepressed(model, art, mx, my, 1024, 768,
                               view, prefs, {255, 0, 0}, 2, 100, nil))
    Bridge.mousereleased()
    local before_undo_count = history().undo
    assert(keys("z", true, false) and history().undo == before_undo_count - 1,
           "Undo da máscara após pincelada falhou")
    assert(Bridge.undo(), "Ctrl+Z raster não desfez pincelada")
    assert(keys("y", true, false) and history().undo == before_undo_count,
           "Undo raster não deveria descartar histórico sem mudar geometria")
    assert(Bridge.redo(), "Ctrl+Y raster não refez pincelada")

    -- Transformar pixels com seleção ativa invalida somente a timeline
    -- de máscara, porque reverter só a geometria desalinharia a pintura.
    model.active_tool = "transform"
    shape(1, 1, 3, 3, false, false)
    assert(history().undo > 0)
    local ok = Bridge.selection_command(model, "flip_horizontal")
    assert(ok and history().undo == 0 and history().redo == 0 and
           not Bridge.selection_undo(),
           "Flip raster deveria encerrar histórico independente da máscara")
    assert(Bridge.undo(), "Flip raster perdeu o próprio undo")

    -- O orçamento é limitado a 8 passos. Ações sem efeito não aumentam
    -- a timeline e a nona operação descarta o snapshot mais antigo.
    Bridge.clear_selection()
    for i = 1, 12 do
        assert(keys("a", false, false))
        assert(keys("i", false, true))
    end
    assert(history().undo == 8 and history().redo == 0,
           "Timeline da seleção não respeitou limite de oito passos")
    for i = 1, 8 do
        assert(keys("z", true, false), "Undo de máscara limitado falhou")
    end
    assert(keys("z", true, false) and not Bridge.selection_undo() and
           history().redo == 8,
           "A pilha da seleção não limitou passos ao orçamento")
    for i = 1, 8 do assert(keys("y", true, false)) end
    assert(keys("y", true, false) and not Bridge.selection_redo(),
           "Redo ultrapassou limite da seleção")
    assert(keys("a", false, false) and Bridge.save(),
           "Salvar obra com seleção após timeline falhou")
    Bridge.open(model, art)
    assert(Bridge.selection_snapshot().count == 256 and
           history().undo == 8 and history().redo == 0,
           "A reabertura deve preservar os oito passos de máscara")
    assert(keys("z", true, false) and not Bridge.selection_snapshot() and
           history().redo == 1,
           "Undo persistente não restaurou a seleção vazia anterior")
    assert(keys("y", true, false) and
           Bridge.selection_snapshot().count == 256 and
           history().redo == 0,
           "Redo persistente não restaurou a seleção total")
    assert(Bridge.selection_command(model, "invert_selection") and
           history().undo == 8 and not Bridge.selection_snapshot(),
           "Nova alteração não continuou a timeline persistida")
    Bridge.clear_selection()

    local index_data = assert(love.filesystem.read("lua-artworks/index.tsv"))
    local key
    for line in index_data:gmatch("[^\r\n]+") do
        if line:find("Selection timeline", 1, true) then
            key = line:match("^(art_%d+_%d+)\t")
        end
    end
    assert(key, "Diretório temporário da timeline não encontrado")
    local path = "lua-artworks/" .. key
    require("lua_history").cleanup(path)
    for _, file in ipairs(love.filesystem.getDirectoryItems(path)) do
        love.filesystem.remove(path .. "/" .. file)
    end
    assert(love.filesystem.remove(path))
end

-- Ponte: Ctrl+Alt+F aplica feather de 2 px, com persistência PNG.
local function test_feather_bridge(Bridge, model, art)
    local Selection = require("lua_selection")
    local info = model.layers[1]
    local old_lock, old_alpha = info.locked, info.alpha_lock
    info.locked, info.alpha_lock = true, true
    local warnings = 0
    local function notice() warnings = warnings + 1 end
    Bridge.clear_selection()
    assert(not Bridge.selection_command(model, "feather_selection", notice)
           and warnings == 1 and not Bridge.selection_snapshot(),
           "Feather sem seleção deveria falhar sem alterar o documento")
    assert(Bridge.selection_command(model, "select_all"),
           "Ctrl+A da ponte não criou seleção")
    local hard = assert(Bridge.selection_snapshot())
    assert(hard.count == hard.w * hard.h and not Selection.is_soft(hard))
    local original_down = love.keyboard.isDown
    love.keyboard.isDown = function(...)
        for i = 1, select("#", ...) do
            local key = select(i, ...)
            if key == "lctrl" or key == "lalt" then return true end
        end
        return false
    end
    local consumed = Bridge.keypressed("f", model, notice)
    love.keyboard.isDown = original_down
    assert(consumed, "Ctrl+Alt+F não foi interceptado")
    local feather = assert(Bridge.selection_snapshot())
    local border = Selection.coverage(feather, 0, 0)
    assert(Selection.is_soft(feather) and border > 0 and border < 1 and
           Selection.coverage(feather, 8, 8) == 1 and
           Selection.coverage(feather, 0, 8) < 1 and
           hard.count == hard.w * hard.h and not Selection.is_soft(hard),
           "Feather pela ponte não respeitou bordas nem preservou máscara")
    assert(Bridge.save(), "Feather não foi salvo")
    Bridge.open(model, art)
    local reopened = assert(Bridge.selection_snapshot())
    assert(Selection.is_soft(reopened) and
           close(Selection.coverage(reopened, 0, 0), border, 1 / 255),
           "Reabrir a obra perdeu o alfa parcial da seleção")
    assert(Bridge.selection_command(model, "select_all"))
    assert(not Selection.is_soft(Bridge.selection_snapshot()) and
           Selection.coverage(Bridge.selection_snapshot(), 0, 0) == 1,
           "Ctrl+A não voltou a uma seleção binária plena")
    Bridge.clear_selection()
    info.locked, info.alpha_lock = old_lock, old_alpha
end

-- Expansão/contração morfológica 8-conexa, sem tocar no raster.
local function test_selection_morph(E)
    local Selection = require("lua_selection")
    local p = E.new(16, 16)
    E.sync(p, {layers = {{id = 1, visible = true, opacity = 100}}})
    p.layers[1].pixels:setPixel(5, 5, 0.2, 0.4, 0.9, 0.6)
    p.layers[1].image:replacePixels(p.layers[1].pixels)
    p.dirty = false

    local point = assert(Selection.rectangle(16, 16, 5, 5, 5, 5))
    local expanded = assert(Selection.morph(point, "expand"))
    assert(expanded.kind == "expanded" and expanded.count == 9 and
           expanded.min_x == 4 and expanded.max_x == 6 and
           expanded.min_y == 4 and expanded.max_y == 6 and
           Selection.contains(expanded, 4, 4) and
           Selection.contains(expanded, 6, 6) and
           point.count == 1 and point.min_x == 5,
           "Expansão 8-conexa deveria gerar 3x3 sem mudar original")
    local restored = assert(Selection.morph(expanded, "contract"))
    assert(restored.count == 1 and restored.kind == "contracted" and
           Selection.contains(restored, 5, 5),
           "Contrair 3x3 deveria voltar ao ponto central")

    local corner = assert(Selection.rectangle(16, 16, 0, 0, 0, 0))
    local clipped = assert(Selection.morph(corner, "expand"))
    assert(clipped.count == 4 and clipped.min_x == 0 and
           clipped.max_x == 1 and clipped.max_y == 1 and
           Selection.contains(clipped, 1, 1),
           "Expansão nas bordas deve recortar sem sair do canvas")
    assert(not Selection.morph(clipped, "contract"),
           "Contrair região que toca a borda deve considerar exterior vazio")
    assert(not Selection.morph(point, "contract"),
           "Contrair pixel isolado deveria desmarcar (nil, sem erro)")

    local square = assert(Selection.rectangle(16, 16, 4, 4, 8, 8))
    local contracted = assert(Selection.morph(square, "contract"))
    assert(contracted.count == 9 and contracted.min_x == 5 and
           contracted.max_x == 7 and contracted.min_y == 5 and
           contracted.max_y == 7 and
           not Selection.contains(contracted, 4, 4),
           "Contração 5x5 deveria deixar o centro 3x3")
    local recovered = assert(Selection.morph(contracted, "expand"))
    assert(recovered.count == 25 and
           Selection.contains(recovered, 4, 4) and
           Selection.contains(recovered, 8, 8),
           "Expandir após contrair bloco sólido não restaurou sua área")
    assert(square.count == 25 and Selection.contains(square, 4, 4),
           "Morfologia modificou a máscara original")

    local islands = assert(Selection.from_mask(16, 16, {
        [2 + 2 * 16] = true, [12 + 12 * 16] = true
    }, "lasso"))
    local grown = assert(Selection.morph(islands, "expand"))
    assert(grown.count == 18 and
           Selection.contains(grown, 1, 1) and
           Selection.contains(grown, 13, 13),
           "Ilhas desconectadas não expandiram independentemente")
    local shrunk = assert(Selection.morph(grown, "contract"))
    assert(shrunk.count == 2 and
           Selection.contains(shrunk, 2, 2) and
           Selection.contains(shrunk, 12, 12),
           "Contração de ilhas 3x3 não restaurou seus centros")
    local no_hole = {}
    for y = 4, 8 do
        for x = 4, 8 do
            if not (x == 6 and y == 6) then
                no_hole[y * 16 + x] = true
            end
        end
    end
    local ring = assert(Selection.from_mask(16, 16, no_hole, "lasso"))
    assert(not Selection.morph(ring, "contract"),
           "Contração deve respeitar lacunas internas da máscara")

    local whole = assert(Selection.all(16, 16))
    local inset = assert(Selection.morph(whole, "contract"))
    assert(inset.count == 196 and inset.min_x == 1 and
           inset.max_x == 14 and inset.min_y == 1 and inset.max_y == 14,
           "Contrair seleção completa deve remover a borda do canvas")
    local full_again = assert(Selection.morph(inset, "expand"))
    assert(full_again.count == 256,
           "Expandir a área interna deve restaurar a seleção total")

    local invalid, error_text = Selection.morph(point, "blur")
    assert(not invalid and error_text, "Operação não suportada foi aceita")
    local none, no_selection = Selection.morph(nil, "expand")
    assert(not none and no_selection, "Expandir sem seleção deveria falhar")
    local huge = {w = 1025, h = 1025, count = 1, mask = {[0] = true}}
    local rejected, limit = Selection.morph(huge, "expand")
    assert(not rejected and limit, "Morfologia ignorou o limite de pixels")
    assert(#p.undo == 0 and #p.redo == 0 and not p.dirty and
           select(3, p.layers[1].pixels:getPixel(5, 5)) > 0.85 and
           close(select(4, p.layers[1].pixels:getPixel(5, 5)), 0.6),
           "Operações de máscara alteraram pixels, dirty ou histórico")

    local path = "lua-morph-tests"
    assert(love.filesystem.createDirectory(path))
    assert(Selection.save(grown, path .. "/selection.png"))
    local loaded = assert(Selection.load(path .. "/selection.png", 16, 16))
    assert(loaded.count == grown.count and
           Selection.contains(loaded, 1, 1) and
           Selection.contains(loaded, 13, 13) and
           not Selection.contains(loaded, 7, 7),
           "PNG de máscara expandida não preservou regiões desconectadas")
    assert(love.filesystem.remove(path .. "/selection.png"))
    assert(love.filesystem.remove(path))
end

-- Atalhos da ponte e persistência da máscara, inclusive camadas bloqueadas.
local function test_selection_morph_bridge(Bridge, gallery)
    local Selection = require("lua_selection")
    local model = {
        screen = "editor", document = {width = 16, height = 16},
        layers = {{id = 1, visible = true, opacity = 100,
                   blending = "Normal", name = "Morph layer"}},
        active_layer_id = 1, active_tool = "transform",
        background_mode = "white"
    }
    function model:active_layer() return self.layers[1] end
    local id = gallery:add_artwork(16, 16, "Morph selection")
    Bridge.create(model, id, gallery)
    local function shortcut(key, alt, shift)
        local old = love.keyboard.isDown
        love.keyboard.isDown = function(...)
            for i = 1, select("#", ...) do
                local k = select(i, ...)
                if k == "lctrl" then return true end
                if alt and k == "lalt" then return true end
                if shift and k == "lshift" then return true end
            end
            return false
        end
        local consumed = Bridge.keypressed(key, model)
        love.keyboard.isDown = old
        return consumed
    end
    local warnings = 0
    assert(not Bridge.selection_command(model, "expand_selection",
                                      function() warnings = warnings + 1 end))
    assert(warnings == 1 and not Bridge.selection_snapshot(),
           "Expandir sem seleção deve informar falha, sem criar máscara")
    model.layers[1].locked = true
    model.layers[1].alpha_lock = true
    assert(shortcut("a", false, false), "Ctrl+A não criou máscara")
    assert(shortcut("down", true, false), "Ctrl+Alt+Down não contraiu")
    local inset = assert(Bridge.selection_snapshot())
    assert(inset.count == 196 and inset.min_x == 1 and
           inset.max_y == 14 and
           not Selection.contains(inset, 0, 0),
           "Atalho de contração não preservou geometria/bordas")
    assert(shortcut("up", true, false), "Ctrl+Alt+Up não expandiu")
    assert(Bridge.selection_snapshot().count == 256,
           "Atalho de expansão não restaurou seleção integral")
    assert(not Bridge.undo(), "Morfologia de máscara gerou undo raster")

    Bridge.clear_selection()
    local view = {zoom = 10, rotation = 0, pan_x = 0, pan_y = 0}
    local prefs = {tool_position = "left"}
    local cx = 62 + (1024 - 62 - 34) / 2
    local cy = 62 + (768 - 160) / 2
    local mx = cx + (5 + 0.5 - 8) * 11
    local my = cy + (5 + 0.5 - 8) * 11
    assert(Bridge.mousepressed(model, id, mx, my, 1024, 768, view, prefs,
                               {255, 0, 0}, 1, 100, nil))
    assert(Bridge.mousereleased(model, mx, my, 1),
           "Gesto retangular de um pixel falhou")
    local point = assert(Bridge.selection_snapshot())
    assert(point.count == 1, "Gesto de um pixel não criou máscara esperada")
    assert(shortcut("up", true, false))
    local grown = assert(Bridge.selection_snapshot())
    assert(grown.count == 9 and grown.min_x == 4,
           "Ctrl+Alt+Up não ampliou a seleção de 1 pixel")
    assert(shortcut("down", true, false))
    assert(Bridge.selection_snapshot().count == 1,
           "Ctrl+Alt+Down não restaurou pixel único")
    assert(shortcut("down", true, false) and not Bridge.selection_snapshot(),
           "Contrair um pixel isolado deveria desmarcar")
    assert(not Bridge.undo(), "Contração até vazio criou histórico raster")

    assert(shortcut("a", false, false))
    assert(shortcut("down", true, false))
    model.layers[1].locked = false
    model.layers[1].alpha_lock = false
    assert(Bridge.save(), "Salvar a seleção contraída falhou")
    local saved_mask = assert(Bridge.selection_snapshot())
    Bridge.open(model, id)
    local reloaded = assert(Bridge.selection_snapshot())
    assert(reloaded.count == saved_mask.count and
           reloaded.min_x == 1 and reloaded.max_x == 14,
           "Reabertura não restaurou a seleção contraída")
    assert(not Bridge.undo(), "Reabertura criou undo raster para seleção")
    assert(not Bridge.selection_command({screen = "gallery"},
                                        "expand_selection"),
           "Morfologia não deve atuar fora do editor")

    local index = assert(love.filesystem.read("lua-artworks/index.tsv"))
    local key
    for line in index:gmatch("[^\r\n]+") do
        if line:find("Morph selection", 1, true) then
            key = line:match("^(art_%d+_%d+)\t")
        end
    end
    assert(key, "Pasta da obra temporária não encontrada")
    local path = "lua-artworks/" .. key
    require("lua_history").cleanup(path)
    for _, filename in ipairs(love.filesystem.getDirectoryItems(path)) do
        love.filesystem.remove(path .. "/" .. filename)
    end
    assert(love.filesystem.remove(path))
end

-- Balde tolerante: região fixada ANTES da escrita, máscara, Alpha Lock,
-- no-op e histórico reversível com o mesmo critério RGBA por canal.
local function test_bucket_tolerance(E)
    local Selection = require("lua_selection")
    local function fixture()
        local p = E.new(12, 12)
        E.sync(p, {layers = {{id = 1, visible = true, opacity = 100}}})
        local d = p.layers[1].pixels
        d:setPixel(2, 3, .4, .2, .3, 1)
        d:setPixel(3, 3, .4 + 12 / 255, .2, .3, 1)
        d:setPixel(4, 3, .4, .2 + 16 / 255, .3, 1)
        d:setPixel(5, 3, .4 + 39 / 255, .2, .3, 1)
        d:setPixel(6, 3, .4, .2, .3, .75)
        d:setPixel(8, 8, .4, .2, .3, 1) -- ilha desconectada
        p.layers[1].image:replacePixels(d)
        p.dirty = false
        return p
    end
    for _, scenario in ipairs({
        {0, 2}, {16, 4}, {48, 5}, {64, 6}, {255, 144}
    }) do
        local p = fixture()
        local tol, count = scenario[1], scenario[2]
        local ok = E.fill(p, 1, 2, 3, {0, 0, 1}, 1,
                          false, nil, tol)
        assert(ok and p.dirty and #p.undo == 1 and #p.redo == 0,
               "Balde tolerante não gerou um único histórico raster")
        local d = p.layers[1].pixels
        local changed = 0
        for py = 0, 11 do
            for px = 0, 11 do
                local r, g, b, a = d:getPixel(px, py)
                if b > .99 and r < .01 and g < .01 and a > .99 then
                    changed = changed + 1
                end
            end
        end
        -- No início há 2 pixels de azul? Apenas 0: todos os originais
        -- têm B=.3, então o número de pixels alterados é determinístico.
        assert(changed == count,
               "Tolerância RGBA do balde não selecionou a região esperada")
        if tol < 255 then
            local ir = select(1, d:getPixel(8, 8))
            assert(close(ir, .4, .005), "Balde atravessou ilha desconectada")
        end
        assert(E.undo(p), "Undo do balde tolerante falhou")
        local old = p.layers[1].pixels
        assert(close(select(1, old:getPixel(2, 3)), .4, .005),
               "Undo não restaurou pixel fonte do balde")
        assert(E.redo(p), "Redo do balde tolerante falhou")
        assert(select(3, p.layers[1].pixels:getPixel(2, 3)) > .99,
               "Redo não restaurou preenchimento tolerante")
    end

    -- Cores novas próximas à cor original NÃO podem recircular pelo
    -- flood-fill. Tampouco cria histórico se o resultado for idêntico.
    local empty = E.new(16, 16)
    E.sync(empty, {layers = {{id = 1, visible = true, opacity = 100}}})
    empty.dirty = false
    assert(E.fill(empty, 1, 0, 0, {1, 0, 0}, .05, false, nil, 255),
           "Balde opaco parcial não concluiu preenchimento com tolerância 255")
    local _, _, _, partial_alpha = empty.layers[1].pixels:getPixel(15, 15)
    assert(close(partial_alpha, .05, .005) and #empty.undo == 1,
           "Balde parcial não preservou alfa ou criou múltiplos históricos")
    assert(E.undo(empty) and E.redo(empty),
           "Histórico do balde parcial não é reversível")

    local p = fixture()
    local d = p.layers[1].pixels
    local rgb = {.4, .2, .3}
    assert(E.fill(p, 1, 2, 3, rgb, 1, false, nil, 16),
           "Balde deve alterar vizinho quando cor seed já é destino")
    assert(close(select(1, d:getPixel(3, 3)), .4, .005) and
           close(select(2, d:getPixel(4, 3)), .2, .005),
           "Balde tolerante não recoloriu vizinhos próximos")
    p.dirty = false
    local before = #p.undo
    assert(not E.fill(p, 1, 2, 3, rgb, 1, false, nil, 16) and
           not p.dirty and #p.undo == before,
           "Preenchimento idêntico criou raster dirty ou histórico")
    local selection = assert(Selection.rectangle(12, 12, 2, 3, 3, 3))
    local restricted = fixture()
    assert(E.fill(restricted, 1, 2, 3, {0, 0, 1}, 1,
                  false, selection, 255),
           "Balde tolerante não preencheu área selecionada")
    assert(select(3, restricted.layers[1].pixels:getPixel(3, 3)) > .99 and
           close(select(1, restricted.layers[1].pixels:getPixel(4, 3)),
                 .4, .005),
           "Balde tolerante escapou dos limites da seleção")
    local lock = fixture()
    assert(E.fill(lock, 1, 2, 3, {0, 1, 0}, 1,
                  true, nil, 255), "Balde Alpha Lock tolerante falhou")
    assert(close(select(4, lock.layers[1].pixels:getPixel(6, 3)), .75) and
           close(select(4, lock.layers[1].pixels:getPixel(0, 0)), 0),
           "Balde tolerante ignorou restrição de alfa do Alpha Lock")
    for _, bad in ipairs({-1, 256, .5, "16", math.huge}) do
        local invalid, reason = E.fill(fixture(), 1, 2, 3,
                                      {1, 1, 1}, 1, false, nil, bad)
        assert(not invalid and reason, "Balde aceitou tolerância inválida")
    end
    local too_large, reason = E.fill({w = 1025, h = 1025}, 1, 0, 0,
                                      {0, 0, 0}, 1, false, nil, 16)
    assert(not too_large and reason,
           "Balde tolerante perdeu limite de 1.048.576 pixels")
end

-- Comparação opcional RGB: transparência diferente não separa cores.
-- Por padrão, RGBA exato continua preservado em todos os algoritmos.
local function test_magic_wand_rgb_only(E)
    local Selection = require("lua_selection")
    local p = E.new(12, 12)
    local model = {layers = {{id = 1, visible = true, opacity = 100}}}
    E.sync(p, model)
    local data = p.layers[1].pixels
    data:setPixel(2, 3, .4, .2, .3, 1)
    data:setPixel(3, 3, .4, .2, .3, .5)
    data:setPixel(4, 3, .4, .2, .3, 0)
    data:setPixel(5, 3, .4 + 12 / 255, .2, .3, .7)
    data:setPixel(6, 3, .4 + 39 / 255, .2, .3, .7)
    data:setPixel(1, 2, .4, .2, .3, .25)
    data:setPixel(8, 8, .4, .2, .3, .5)
    p.layers[1].image:replacePixels(data)
    p.dirty = false
    local legacy = assert(Selection.magic_wand(p.layers[1], 12, 12, 2, 3))
    local rgba = assert(Selection.magic_wand(
        p.layers[1], 12, 12, 2, 3, 0, false, false, false))
    local rgb = assert(Selection.magic_wand(
        p.layers[1], 12, 12, 2, 3, 0, false, false, true))
    assert(legacy.count == 1 and rgba.count == 1 and rgb.count == 3
           and Selection.contains(rgb, 4, 3)
           and not Selection.contains(rgba, 3, 3),
           "RGB-only não incluiu alfa variável, inclusive zero")
    local diagonal = assert(Selection.magic_wand(
        p.layers[1], 12, 12, 2, 3, 0, false, true, true))
    assert(diagonal.count == 4 and Selection.contains(diagonal, 1, 2),
           "RGB-only não respeitou conexidade de oito vizinhos")
    local global = assert(Selection.magic_wand(
        p.layers[1], 12, 12, 2, 3, 0, true, false, true))
    assert(global.count == 5 and Selection.contains(global, 8, 8)
           and not Selection.contains(rgb, 8, 8),
           "RGB-only global não incluiu ilha com alfa diferente")
    local ranged = assert(Selection.magic_wand(
        p.layers[1], 12, 12, 2, 3, 16, false, false, true))
    assert(ranged.count == 4 and Selection.contains(ranged, 5, 3)
           and not Selection.contains(ranged, 6, 3),
           "RGB-only não preservou tolerância por canal")
    local wide = assert(Selection.magic_wand(
        p.layers[1], 12, 12, 2, 3, 48, false, false, true))
    assert(wide.count == 5 and Selection.contains(wide, 6, 3),
           "RGB-only com tolerância 48 perdeu vizinho")
    local all = assert(Selection.magic_wand(
        p.layers[1], 12, 12, 2, 3, 255, true, true, true))
    assert(all.count == 144,
           "RGB-only não preservou tolerância máxima")
    for _, value in ipairs({1, "yes", {}, 0}) do
        local invalid, reason = Selection.magic_wand(
            p.layers[1], 12, 12, 2, 3, 0, false, false, value)
        assert(not invalid and reason, "RGB-only aceitou sinalizador inválido")
    end
    local invalid, error_message = Selection.magic_wand(
        p.layers[1], 1025, 1025, 2, 3, 0, false, false, true)
    assert(not invalid and error_message, "RGB-only ignorou limite de 1 Mi")
    assert(not p.dirty and #p.undo == 0 and #p.redo == 0
           and rgba.count == 1 and rgb.count == 3
           and close(select(4, data:getPixel(4, 3)), 0),
           "Comparação RGB-only alterou alfa original ou histórico")

    -- A opção também funciona com a mesma composição do conta-gotas.
    local composite_model = {background_mode = "transparent_dark", layers = {
        {id = 1, visible = true, opacity = 100, blending = "Normal"},
        {id = 2, visible = true, opacity = 100, blending = "Normal"}
    }}
    local composed = E.new(8, 8)
    E.sync(composed, composite_model)
    composed.layers[1].pixels:setPixel(2, 2, .4, .2, .3, 1)
    composed.layers[2].pixels:setPixel(3, 2, .4, .2, .3, .4)
    local source = E.composite_pixel_source(composed, composite_model, false)
    local strict = assert(Selection.magic_wand(
        source, 8, 8, 2, 2, 0, true, false, false))
    local matched = assert(Selection.magic_wand(
        source, 8, 8, 2, 2, 0, true, false, true))
    assert(strict.count == 1 and matched.count == 2
           and Selection.contains(matched, 3, 2),
           "Fonte composta RGB-only não ignorou alfa das camadas")
end

-- Contiguidade opcional de oito vizinhos: diagonais não viram ilhas
-- globais e a equivalência RGBA continua sendo por canal.
local function test_magic_wand_diagonal(E)
    local Selection = require("lua_selection")
    local p = E.new(12, 12)
    E.sync(p, {layers = {{id = 1, visible = true, opacity = 100}}})
    local data = p.layers[1].pixels
    data:setPixel(2, 2, .4, .2, .3, 1)
    data:setPixel(3, 3, .4, .2, .3, 1)
    data:setPixel(4, 4, .4, .2, .3, 1)
    data:setPixel(4, 5, .4 + 12 / 255, .2, .3, 1)
    data:setPixel(5, 5, .4, .2, .3, .75)
    data:setPixel(8, 8, .4, .2, .3, 1)
    p.layers[1].image:replacePixels(data)
    p.dirty = false
    local four = assert(Selection.magic_wand(
        p.layers[1], 12, 12, 2, 2, 0, false, false))
    local legacy = assert(Selection.magic_wand(p.layers[1], 12, 12, 2, 2, 0))
    local eight = assert(Selection.magic_wand(
        p.layers[1], 12, 12, 2, 2, 0, false, true))
    assert(four.count == 1 and legacy.count == 1 and eight.count == 3
           and Selection.contains(eight, 3, 3)
           and Selection.contains(eight, 4, 4)
           and not Selection.contains(eight, 8, 8),
           "Conectividade 8 não atravessou diagonais exatas")
    local tolerance = assert(Selection.magic_wand(
        p.layers[1], 12, 12, 2, 2, 16, false, true))
    assert(tolerance.count == 4 and Selection.contains(tolerance, 4, 5)
           and not Selection.contains(tolerance, 5, 5),
           "Modo 8-conexo não respeitou diferenças em RGB e alfa")
    local alpha = assert(Selection.magic_wand(
        p.layers[1], 12, 12, 2, 2, 64, false, true))
    assert(alpha.count == 5 and Selection.contains(alpha, 5, 5),
           "Alfa próximo não entrou pela conexão diagonal")
    local global_without = assert(Selection.magic_wand(
        p.layers[1], 12, 12, 2, 2, 0, true, false))
    local global_with = assert(Selection.magic_wand(
        p.layers[1], 12, 12, 2, 2, 0, true, true))
    assert(global_without.count == 4 and global_with.count == 4
           and Selection.contains(global_with, 8, 8),
           "Modo global dependeu indevidamente da conectividade")
    local wrong, reason = Selection.magic_wand(
        p.layers[1], 12, 12, 2, 2, 0, false, "yes")
    assert(not wrong and reason, "Conectividade inválida foi aceita")
    local huge, error_message = Selection.magic_wand(
        p.layers[1], 1025, 1025, 2, 2, 0, false, true)
    assert(not huge and error_message, "Limite 1 Mi ignorado no modo 8")
    assert(not p.dirty and #p.undo == 0 and #p.redo == 0 and
           four.count == 1 and eight.count == 3,
           "Varinha 8-conexa modificou pintura ou máscaras anteriores")

    local border = E.new(6, 6)
    E.sync(border, {layers = {{id = 1, visible = true, opacity = 100}}})
    local pixels = border.layers[1].pixels
    pixels:setPixel(0, 0, 1, 0, 0, 1)
    pixels:setPixel(1, 1, 1, 0, 0, 1)
    pixels:setPixel(2, 2, 1, 0, 0, 1)
    pixels:setPixel(3, 2, 1, 0, 0, 1)
    pixels:setPixel(5, 5, 1, 0, 0, 1)
    local border_four = assert(Selection.magic_wand(
        border.layers[1], 6, 6, 0, 0, 0, false, false))
    local border_eight = assert(Selection.magic_wand(
        border.layers[1], 6, 6, 0, 0, 0, false, true))
    assert(border_four.count == 1 and border_eight.count == 4
           and Selection.contains(border_eight, 3, 2)
           and not Selection.contains(border_eight, 5, 5),
           "Oito vizinhos ultrapassaram limites ou perderam cantos")
end

-- Ponte: configuração própria do balde, shortcuts e metadata legado.
local function test_bucket_tolerance_bridge(Bridge, gallery)
    local model = {
        screen = "editor", document = {width = 16, height = 16},
        layers = {{id = 1, name = "Bucket RGBA", visible = true,
                   opacity = 100, blending = "Normal"}},
        active_layer_id = 1, active_tool = "brush",
        background_mode = "transparent_dark"
    }
    function model:active_layer() return self.layers[1] end
    local id = gallery:add_artwork(16, 16, "Bucket tolerance RGBA")
    Bridge.create(model, id, gallery)
    local view = {zoom = 10, rotation = 0, pan_x = 0, pan_y = 0}
    local prefs = {tool_position = "left"}
    local function screen(x, y)
        return 62 + (1024 - 62 - 34) / 2 + (x + .5 - 8) * 11,
               62 + (768 - 160) / 2 + (y + .5 - 8) * 11
    end
    local function press(x, y, color)
        local mx, my = screen(x, y)
        assert(Bridge.mousepressed(model, id, mx, my, 1024, 768,
                                   view, prefs, color, 1, 100, nil))
        Bridge.mousereleased()
    end
    press(3, 3, {100, 50, 75})
    press(4, 3, {112, 50, 75})
    press(5, 3, {139, 50, 75})
    press(10, 10, {100, 50, 75})
    model.active_tool = "bucket"
    local notices = {}
    local function notify(msg) notices[#notices + 1] = msg end
    local function shortcut(key)
        local original = love.keyboard.isDown
        love.keyboard.isDown = function(...)
            for i = 1, select("#", ...) do
                local k = select(i, ...)
                if k == "lctrl" or k == "lalt" then return true end
            end
            return false
        end
        local handled = Bridge.keypressed(key, model, notify)
        love.keyboard.isDown = original
        return handled
    end
    local function artwork_path()
        local index = assert(love.filesystem.read("lua-artworks/index.tsv"))
        for line in index:gmatch("[^\r\n]+") do
            if line:find("Bucket tolerance RGBA", 1, true) then
                local key = line:match("^(art_%d+_%d+)\t")
                return "lua-artworks/" .. key
            end
        end
        error("Diretório da obra do Balde não foi encontrado")
    end
    local function pixel(path, x, y)
        local image = love.image.newImageData(path .. "/layer_1.png")
        return image:getPixel(x, y)
    end
    assert(Bridge.bucket_tolerance(model) == 0
           and Bridge.wand_tolerance(model) == 0,
           "Balde não iniciou com tolerância zero independente da Varinha")
    press(3, 3, {0, 0, 255})
    assert(Bridge.save(), "Balde sem persistência inicial")
    local path = artwork_path()
    assert(select(3, pixel(path, 3, 3)) > .99 and
           close(select(1, pixel(path, 4, 3)), 112 / 255, .02),
           "Balde padrão modificou cor próxima")
    assert(Bridge.undo(), "Balde não gerou undo")
    local old_mask_undo = Bridge.selection_history_snapshot().undo
    assert(shortcut("pageup") and Bridge.bucket_tolerance(model) == 16
           and Bridge.wand_tolerance(model) == 0
           and Bridge.selection_history_snapshot().undo == old_mask_undo
           and notices[#notices]:find("16/255", 1, true),
           "Ctrl+Alt+PageUp não ajustou tolerância independentemente")
    press(3, 3, {0, 0, 255})
    assert(Bridge.save(), "Balde tolerante não salvou")
    assert(select(3, pixel(path, 4, 3)) > .99 and
           close(select(1, pixel(path, 5, 3)), 139 / 255, .02)
           and close(select(1, pixel(path, 10, 10)), 100 / 255, .02),
           "Balde tolerante ultrapassou cor fronteira ou ilha")
    assert(Bridge.undo() and Bridge.redo(),
           "Preenchimento tolerante não manteve histórico raster")
    assert(shortcut("pagedown") and Bridge.bucket_tolerance(model) == 0)
    assert(Bridge.adjust_bucket_tolerance(model, 999)
           and Bridge.bucket_tolerance(model) == 255
           and Bridge.adjust_bucket_tolerance(model, -239)
           and Bridge.bucket_tolerance(model) == 16,
           "Balde não limitou tolerância entre 0 e 255")
    assert(shortcut("home") and Bridge.bucket_tolerance(model) == 0,
           "Ctrl+Alt+Home não restaurou tolerância padrão")
    assert(not Bridge.adjust_bucket_tolerance(model, 1.5)
           and not Bridge.adjust_bucket_tolerance({screen="gallery"}, 16),
           "Balde permitiu ajuste fora do editor ou fracionário")
    assert(Bridge.adjust_bucket_tolerance(model, 32) and Bridge.save())
    local metadata = assert(love.filesystem.read(path .. "/document.tsv"))
    assert(metadata:match("\t0\t0\t0\t0\t0\t32$"),
           "Balde não persistiu tolerância na oitava coluna")
    local other = gallery:add_artwork(16, 16, "Other Bucket")
    Bridge.create(model, other, gallery)
    assert(Bridge.bucket_tolerance(model) == 0,
           "Tolerância do balde vazou entre obras")
    Bridge.open(model, id)
    assert(Bridge.bucket_tolerance(model) == 32
           and Bridge.wand_tolerance(model) == 0,
           "Reabertura não restaurou tolerância do balde")
    assert(Bridge.undo() and Bridge.redo(),
           "Preferência do balde quebrou histórico raster após abertura")
    assert(love.filesystem.write(path .. "/document.tsv",
                                 "1\ttransparent_dark\t16\t1\t1\t1\t1"))
    Bridge.open(model, id)
    assert(Bridge.bucket_tolerance(model) == 0 and
           Bridge.wand_tolerance(model) == 16
           and Bridge.wand_global(model) and Bridge.wand_sample_all(model)
           and Bridge.wand_diagonal(model) and Bridge.wand_rgb_only(model),
           "Legado de sete colunas perdeu configuração da Varinha")
    for _, previous in ipairs({
        "1\ttransparent_dark\t16\t1\t1\t1",
        "1\ttransparent_dark\t16\t1\t1",
        "1\ttransparent_dark\t16\t1",
        "1\ttransparent_dark\t16",
        "1\ttransparent_dark"
    }) do
        assert(love.filesystem.write(path .. "/document.tsv", previous))
        Bridge.open(model, id)
        assert(Bridge.bucket_tolerance(model) == 0,
               "Documento legado alterou tolerância padrão do balde")
    end
    assert(love.filesystem.write(path .. "/document.tsv",
               "1\ttransparent_dark\t16\t1\t1\t1\t1\tbroken"))
    Bridge.open(model, id)
    assert(Bridge.bucket_tolerance(model) == 0 and
           Bridge.wand_tolerance(model) == 16 and Bridge.wand_global(model)
           and Bridge.wand_rgb_only(model),
           "Valor inválido do Balde alterou preferências da Varinha")
    assert(Bridge.bucket_tolerance({screen = "gallery"}) == nil)
    require("lua_history").cleanup(path)
    require("lua_selection_history").cleanup(path)
    for _, name in ipairs(love.filesystem.getDirectoryItems(path)) do
        love.filesystem.remove(path .. "/" .. name)
    end
    assert(love.filesystem.remove(path))
end

-- Ponte: atalho, independência de modos, persistência e compatibilidade.
local function test_magic_wand_rgb_only_bridge(Bridge, gallery)
    local Selection = require("lua_selection")
    local model = {
        screen = "editor", document = {width = 16, height = 16},
        layers = {{id = 1, name = "RGB only", visible = true,
                   opacity = 100, blending = "Normal"}},
        active_layer_id = 1, active_tool = "brush",
        background_mode = "transparent_dark"
    }
    function model:active_layer() return self.layers[1] end
    local id = gallery:add_artwork(16, 16, "Wand RGB only")
    Bridge.create(model, id, gallery)
    local view = {zoom = 10, rotation = 0, pan_x = 0, pan_y = 0}
    local prefs = {tool_position = "left"}
    local function screen(x, y)
        return 62 + (1024 - 62 - 34) / 2 + (x + .5 - 8) * 11,
               62 + (768 - 160) / 2 + (y + .5 - 8) * 11
    end
    local function press(x, y, color, opacity)
        local mx, my = screen(x, y)
        assert(Bridge.mousepressed(model, id, mx, my, 1024, 768,
                 view, prefs, color, 1, opacity or 100, nil))
        Bridge.mousereleased()
    end
    press(3, 3, {100, 50, 75}, 100)
    press(4, 3, {100, 50, 75}, 50)
    press(5, 3, {100, 50, 75}, 25)
    press(6, 3, {112, 50, 75}, 50)
    press(10, 10, {100, 50, 75}, 50)
    model.active_tool = "magic_wand"
    local notices = {}
    local function notify(message) notices[#notices + 1] = message end
    local function shortcut(key, shift)
        local original = love.keyboard.isDown
        love.keyboard.isDown = function(...)
            for i = 1, select("#", ...) do
                local k = select(i, ...)
                if k == "lctrl" or k == "lalt" then return true end
                if shift and k == "lshift" then return true end
            end
            return false
        end
        local handled = Bridge.keypressed(key, model, notify)
        love.keyboard.isDown = original
        return handled
    end
    local function wand(x, y)
        press(x, y, {255, 0, 0}, 100)
        return assert(Bridge.selection_snapshot())
    end
    assert(Bridge.wand_rgb_only(model) == false and
           Bridge.wand_global(model) == false and
           Bridge.wand_tolerance(model) == 0,
           "Nova obra não iniciou comparação RGBA")
    assert(wand(3, 3).count == 1,
           "Padrão RGBA selecionou alfa diferente")
    local history_before = Bridge.selection_history_snapshot().undo
    assert(shortcut("r") and Bridge.wand_rgb_only(model) and
           Bridge.selection_history_snapshot().undo == history_before
           and Bridge.selection_snapshot().count == 1
           and notices[#notices]:find("apenas RGB", 1, true),
           "Ctrl+Alt+R não preservou máscara ou histórico")
    local rgb = wand(3, 3)
    assert(rgb.count == 3 and Selection.contains(rgb, 5, 3),
           "Varinha RGB-only não selecionou faixa com transparência diferente")
    assert(shortcut("g") and Bridge.wand_global(model))
    rgb = wand(3, 3)
    assert(rgb.count == 4 and Selection.contains(rgb, 10, 10),
           "RGB-only não funcionou no modo global")
    assert(shortcut("right") and Bridge.wand_tolerance(model) == 16)
    rgb = wand(3, 3)
    assert(rgb.count == 5 and Selection.contains(rgb, 6, 3),
           "RGB-only não respeitou ajuste de tolerância")
    assert(shortcut("r") and not Bridge.wand_rgb_only(model))
    local strict = wand(3, 3)
    assert(strict.count == 1 and Selection.contains(strict, 3, 3)
           and not Selection.contains(strict, 4, 3),
           "Desligar RGB-only não restaurou comparação RGBA")
    assert(shortcut("r") and Bridge.wand_rgb_only(model))
    assert(wand(3, 3).count == 5)
    assert(Bridge.save(), "Não foi possível salvar preferência RGB")
    local index = assert(love.filesystem.read("lua-artworks/index.tsv"))
    local key
    for line in index:gmatch("[^\r\n]+") do
        if line:find("Wand RGB only", 1, true) then
            key = line:match("^(art_%d+_%d+)\t")
        end
    end
    assert(key, "Diretório da obra RGB-only não encontrado")
    local path = "lua-artworks/" .. key
    local saved = assert(love.filesystem.read(path .. "/document.tsv"))
    assert(saved:match("\t16\t1\t0\t0\t1\t0$"),
           "document.tsv não gravou sétima coluna RGB-only")
    local image = love.image.newImageData(path .. "/layer_1.png")
    local _, _, _, alpha = image:getPixel(5, 3)
    -- Um clique de pincel sobreposto pode aplicar mais de um dab; o
    -- importante é que a seleção não transformou alfa parcial em opaco.
    assert(alpha > .25 and alpha < .75,
           "RGB-only modificou transparência da pintura")
    local other = gallery:add_artwork(16, 16, "RGB other artwork")
    Bridge.create(model, other, gallery)
    assert(not Bridge.wand_rgb_only(model), "RGB-only vazou para outra obra")
    Bridge.open(model, id)
    assert(Bridge.wand_rgb_only(model) and Bridge.wand_global(model)
           and Bridge.wand_tolerance(model) == 16
           and Bridge.selection_snapshot().count == 5,
           "Reabertura não restaurou comparação RGB ou máscara")
    assert(wand(3, 3).count == 5, "Varinha não aplicou preferência restaurada")
    assert(love.filesystem.write(path .. "/document.tsv",
                                 "1\ttransparent_dark\t16\t1\t0\t1"))
    Bridge.open(model, id)
    assert(not Bridge.wand_rgb_only(model) and
           Bridge.wand_diagonal(model) and Bridge.wand_global(model),
           "Arquivo legado de seis colunas perdeu conectividade")
    assert(love.filesystem.write(path .. "/document.tsv",
                                 "1\ttransparent_dark\t16\t1\t1"))
    Bridge.open(model, id)
    assert(not Bridge.wand_rgb_only(model) and
           Bridge.wand_sample_all(model) and not Bridge.wand_diagonal(model),
           "Arquivo legado de cinco colunas perdeu fonte")
    assert(love.filesystem.write(path .. "/document.tsv",
                                 "1\ttransparent_dark\t16\t1"))
    Bridge.open(model, id)
    assert(not Bridge.wand_rgb_only(model) and Bridge.wand_global(model),
           "Arquivo legado de quatro colunas não abriu")
    assert(love.filesystem.write(path .. "/document.tsv",
                                 "1\ttransparent_dark\t16"))
    Bridge.open(model, id)
    assert(not Bridge.wand_rgb_only(model) and Bridge.wand_tolerance(model) == 16,
           "Arquivo legado de três colunas não abriu")
    assert(love.filesystem.write(path .. "/document.tsv",
                                 "1\ttransparent_dark"))
    Bridge.open(model, id)
    assert(not Bridge.wand_rgb_only(model) and Bridge.wand_tolerance(model) == 0,
           "Arquivo legado de duas colunas não abriu")
    assert(love.filesystem.write(path .. "/document.tsv",
                                 "1\ttransparent_dark\t16\t1\t0\t1\tmalformed"))
    Bridge.open(model, id)
    assert(not Bridge.wand_rgb_only(model) and Bridge.wand_diagonal(model)
           and Bridge.wand_global(model) and not Bridge.wand_sample_all(model),
           "Sinalizador RGB inválido corrompeu outras preferências")
    assert(Bridge.wand_rgb_only({screen = "gallery"}) == nil
           and not Bridge.toggle_wand_rgb_only({screen = "gallery"}),
           "Atalho RGB-only operou fora do editor")
    assert(Bridge.undo() and Bridge.redo(),
           "Alterar comparação RGB-only corrompeu histórico raster")
    require("lua_history").cleanup(path)
    require("lua_selection_history").cleanup(path)
    for _, name in ipairs(love.filesystem.getDirectoryItems(path)) do
        love.filesystem.remove(path .. "/" .. name)
    end
    assert(love.filesystem.remove(path))
end

-- Persistência independente da conectividade e atalhos na ponte real.
local function test_magic_wand_diagonal_bridge(Bridge, gallery)
    local Selection = require("lua_selection")
    local model = {
        screen = "editor", document = {width = 16, height = 16},
        layers = {{id = 1, name = "Diagonal pixels", visible = true,
                   opacity = 100, blending = "Normal"}},
        active_layer_id = 1, active_tool = "brush",
        background_mode = "transparent_dark"
    }
    function model:active_layer() return self.layers[1] end
    local id = gallery:add_artwork(16, 16, "Wand diagonal")
    Bridge.create(model, id, gallery)
    local view = {zoom = 10, rotation = 0, pan_x = 0, pan_y = 0}
    local prefs = {tool_position = "left"}
    local function screen(x, y)
        return 62 + (1024 - 62 - 34) / 2 + (x + .5 - 8) * 11,
               62 + (768 - 160) / 2 + (y + .5 - 8) * 11
    end
    local function press(x, y, color)
        local mx, my = screen(x, y)
        assert(Bridge.mousepressed(model, id, mx, my, 1024, 768,
                                   view, prefs, color, 1, 100, nil))
        Bridge.mousereleased()
    end
    press(3, 3, {100, 50, 75})
    press(4, 4, {100, 50, 75})
    press(5, 5, {100, 50, 75})
    press(5, 6, {112, 50, 75})
    press(11, 11, {100, 50, 75})
    model.active_tool = "magic_wand"
    local notices = {}
    local function notify(message) notices[#notices + 1] = message end
    local function shortcut(key)
        local original = love.keyboard.isDown
        love.keyboard.isDown = function(...)
            for i = 1, select("#", ...) do
                if select(i, ...) == "lctrl" or
                   select(i, ...) == "lalt" then return true end
            end
            return false
        end
        local handled = Bridge.keypressed(key, model, notify)
        love.keyboard.isDown = original
        return handled
    end
    local function wand(x, y)
        press(x, y, {0, 255, 0})
        return assert(Bridge.selection_snapshot())
    end
    assert(Bridge.wand_diagonal(model) == false and
           Bridge.wand_tolerance(model) == 0,
           "Modo diagonal não iniciou em quatro vizinhos")
    assert(wand(3, 3).count == 1,
           "Padrão contíguo 4-conexo incluiu cantos")
    local old_history = Bridge.selection_history_snapshot().undo
    assert(shortcut("8") and Bridge.wand_diagonal(model) and
           Bridge.selection_history_snapshot().undo == old_history and
           notices[#notices]:find("8 vizinhos", 1, true),
           "Ctrl+Alt+8 modificou seleção/histórico ou não exibiu aviso")
    local eight = wand(3, 3)
    assert(eight.count == 3 and Selection.contains(eight, 4, 4)
           and Selection.contains(eight, 5, 5)
           and not Selection.contains(eight, 11, 11),
           "Ponte 8-conexa falhou em cantos isolados")
    assert(shortcut("right") and Bridge.wand_tolerance(model) == 16)
    assert(wand(3, 3).count == 4,
           "Ponte diagonal não combinou tolerância RGBA")
    assert(shortcut("g") and Bridge.wand_global(model))
    assert(wand(3, 3).count == 5,
           "Modo global não selecionou ilha distante")
    assert(shortcut("8") and not Bridge.wand_diagonal(model) and
           wand(3, 3).count == 5,
           "Conectividade alterou indevidamente o modo global")
    assert(shortcut("g") and not Bridge.wand_global(model) and
           wand(3, 3).count == 1,
           "Voltar ao 4-conexo perdeu comportamento anterior")
    assert(shortcut("8") and Bridge.wand_diagonal(model))
    assert(wand(3, 3).count == 4)
    assert(Bridge.save())
    local index = assert(love.filesystem.read("lua-artworks/index.tsv"))
    local key
    for line in index:gmatch("[^\r\n]+") do
        if line:find("Wand diagonal", 1, true) then
            key = line:match("^(art_%d+_%d+)\t")
        end
    end
    assert(key, "Pasta do teste diagonal ausente")
    local path = "lua-artworks/" .. key
    local saved = assert(love.filesystem.read(path .. "/document.tsv"))
    assert(saved:match("\t16\t0\t0\t1\t0\t0$"),
           "Documento não salvou sexta coluna de conectividade")
    local other = gallery:add_artwork(16, 16, "Wand another diagonal")
    Bridge.create(model, other, gallery)
    assert(not Bridge.wand_diagonal(model),
           "Conectividade vazou para outra obra")
    Bridge.open(model, id)
    assert(Bridge.wand_diagonal(model) and
           Bridge.wand_tolerance(model) == 16 and
           Bridge.selection_snapshot().count == 4,
           "Reabertura perdeu conectividade ou máscara")
    assert(wand(3, 3).count == 4,
           "Reabertura não aplicou conectividade salva")
    assert(love.filesystem.write(path .. "/document.tsv",
                                 "1\twhite\t16\t1\t1"))
    Bridge.open(model, id)
    assert(not Bridge.wand_diagonal(model) and
           Bridge.wand_global(model) and Bridge.wand_sample_all(model),
           "Legado com cinco colunas alterou opções existentes")
    assert(love.filesystem.write(path .. "/document.tsv",
                                 "1\twhite\t16\t1"))
    Bridge.open(model, id)
    assert(not Bridge.wand_diagonal(model) and
           Bridge.wand_global(model) and not Bridge.wand_sample_all(model),
           "Legado de quatro colunas não foi aceito")
    assert(love.filesystem.write(path .. "/document.tsv",
                                 "1\twhite\t16"))
    Bridge.open(model, id)
    assert(not Bridge.wand_diagonal(model) and
           not Bridge.wand_global(model) and
           Bridge.wand_tolerance(model) == 16,
           "Legado de três colunas não foi aceito")
    assert(love.filesystem.write(path .. "/document.tsv", "1\twhite"))
    Bridge.open(model, id)
    assert(not Bridge.wand_diagonal(model) and
           Bridge.wand_tolerance(model) == 0,
           "Legado de duas colunas não foi aceito")
    assert(love.filesystem.write(path .. "/document.tsv",
                                 "1\twhite\t16\t1\t1\tbad"))
    Bridge.open(model, id)
    assert(not Bridge.wand_diagonal(model) and
           Bridge.wand_global(model) and Bridge.wand_sample_all(model),
           "Conectividade inválida perdeu outras preferências")
    assert(Bridge.wand_diagonal({screen = "gallery"}) == nil and
           not Bridge.toggle_wand_diagonal({screen = "gallery"}),
           "Modo diagonal operou fora da obra")
    assert(Bridge.undo() and Bridge.redo(),
           "Conectividade corrompeu histórico de pixels")
    require("lua_history").cleanup(path)
    require("lua_selection_history").cleanup(path)
    for _, name in ipairs(love.filesystem.getDirectoryItems(path)) do
        love.filesystem.remove(path .. "/" .. name)
    end
    assert(love.filesystem.remove(path))
end

-- Amostragem composta usa as mesmas cores do conta-gotas e respeita
-- visibilidade, mesclagem, clipping, opacidade e fundo transparente.
local function test_magic_wand_composite_source(E)
    local Selection = require("lua_selection")
    local model = {background_mode = "transparent_dark", layers = {
        {id = 1, visible = true, opacity = 100, blending = "Normal"},
        {id = 2, visible = true, opacity = 100, blending = "Normal"},
        {id = 3, visible = false, opacity = 100, blending = "Normal"}
    }}
    local p = E.new(12, 12)
    E.sync(p, model)
    p.dirty = false
    local bottom = p.layers[1].pixels
    local top = p.layers[2].pixels
    local hidden = p.layers[3].pixels
    bottom:setPixel(2, 2, 1, 0, 0, 1)
    bottom:setPixel(8, 8, 1, 0, 0, 1)
    top:setPixel(2, 2, 0, 0, 1, 1)
    top:setPixel(7, 7, 0, 0, 1, 1)
    hidden:setPixel(8, 8, 0, 0, 1, 1)
    local active = assert(Selection.magic_wand(p.layers[1], 12, 12,
                                                 2, 2, 0, true))
    assert(active.count == 2 and Selection.contains(active, 8, 8),
           "Fonte da camada ativa foi modificada")
    local composite = E.composite_pixel_source(p, model, false)
    local selected = assert(Selection.magic_wand(composite, 12, 12,
                                                  2, 2, 0, true))
    assert(selected.count == 2 and Selection.contains(selected, 7, 7)
           and not Selection.contains(selected, 8, 8),
           "Varinha composta não descartou cor oculta pela camada superior")
    local r, g, b, a = composite.pixels:getPixel(2, 2)
    local sr, sg, sb, sa = E.sample(p, model, 2, 2)
    assert(close(r, sr) and close(g, sg) and close(b, sb) and close(a, sa),
           "Amostragem da varinha divergiu do conta-gotas")
    model.layers[2].visible = false
    local without_top = assert(Selection.magic_wand(
        E.composite_pixel_source(p, model, false), 12, 12, 2, 2, 0, true))
    assert(without_top.count == 2 and Selection.contains(without_top, 8, 8),
           "Camada invisível contaminou a varinha composta")
    model.layers[2].visible = true
    model.layers[2].opacity = 50
    local partial = E.composite_pixel_source(p, model, false)
    r, g, b, a = partial.pixels:getPixel(2, 2)
    assert(close(r, .5) and close(g, 0) and close(b, .5) and close(a, 1),
           "Amostragem composta não aplicou opacidade da camada")
    model.layers[2].blending = "Multiply"
    local multiplied = E.composite_pixel_source(p, model, false)
    r, g, b, a = multiplied.pixels:getPixel(2, 2)
    assert(close(r, .5) and close(b, 0) and close(a, 1),
           "Amostragem composta não aplicou Multiply")
    model.layers[2].clipping = true
    local clipped = E.composite_pixel_source(p, model, false)
    local _, _, _, off_base = clipped.pixels:getPixel(7, 7)
    assert(close(off_base, 0) and
           close(select(4, clipped.pixels:getPixel(2, 2)), 1),
           "Clipping não recortou amostra fora da base")
    model.background_mode = "white"
    local white = E.composite_pixel_source(p, model, true)
    r, g, b, a = white.pixels:getPixel(0, 0)
    assert(close(r, 1) and close(g, 1) and close(b, 1) and close(a, 1),
           "Fundo branco visível não foi amostrado como opaco")
    local white_mask = assert(Selection.magic_wand(white, 12, 12,
                                                    0, 0, 0, true))
    assert(Selection.contains(white_mask, 7, 7) and
           not Selection.contains(white_mask, 8, 8),
           "Amostragem branca ignorou o fundo ou incluiu raster vermelho")
    local transparent = E.composite_pixel_source(p, model, false)
    assert(close(select(4, transparent.pixels:getPixel(0, 0)), 0),
           "Amostra transparente ficou opaca fora do modo de fundo branco")
    assert(not p.dirty and #p.undo == 0 and #p.redo == 0 and
           close(select(1, bottom:getPixel(2, 2)), 1),
           "Amostragem composta alterou pintura ou histórico")
end

-- Seleção por cor global: mesmos canais e tolerância, mas sem conexão.
local function test_magic_wand_global(E)
    local Selection = require("lua_selection")
    local model = {layers = {{id = 1, visible = true, opacity = 100}}}
    local p = E.new(12, 12)
    E.sync(p, model)
    local layer = p.layers[1]
    local data = layer.pixels
    data:setPixel(2, 3, .4, .2, .3, 1)
    data:setPixel(3, 3, .4 + 12 / 255, .2, .3, 1)
    data:setPixel(3, 4, .4, .2 + 16 / 255, .3, 1)
    data:setPixel(4, 3, .4 + 39 / 255, .2, .3, 1)
    data:setPixel(5, 3, .4, .2, .3, .75)
    data:setPixel(1, 2, .4, .2, .3, 1) -- somente diagonal
    data:setPixel(8, 8, .4, .2, .3, 1) -- ilha isolada
    layer.image:replacePixels(data)
    p.dirty = false
    local connected = assert(Selection.magic_wand(layer, 12, 12, 2, 3))
    local explicit = assert(Selection.magic_wand(layer, 12, 12, 2, 3, 0, false))
    local global = assert(Selection.magic_wand(layer, 12, 12, 2, 3, 0, true))
    assert(connected.count == 1 and explicit.count == 1 and
           global.kind == "magic_wand_global" and global.count == 3 and
           Selection.contains(global, 1, 2) and
           Selection.contains(global, 8, 8) and
           not Selection.contains(global, 3, 3),
           "Varinha global exata não selecionou ilhas/diagonais independentes")
    local omitted_tolerance = assert(
        Selection.magic_wand(layer, 12, 12, 2, 3, nil, true))
    assert(omitted_tolerance.count == 3,
           "Tolerância omitida não preservou o modo global")
    local small = assert(Selection.magic_wand(layer, 12, 12, 2, 3, 16, true))
    assert(small.count == 5 and Selection.contains(small, 3, 4) and
           not Selection.contains(small, 4, 3),
           "Varinha global não compartilhou o critério RGBA de tolerância 16")
    local mid = assert(Selection.magic_wand(layer, 12, 12, 2, 3, 48, true))
    assert(mid.count == 6 and Selection.contains(mid, 4, 3) and
           not Selection.contains(mid, 5, 3),
           "Varinha global com tolerância 48 incluiu pixel indevido")
    local alpha = assert(Selection.magic_wand(layer, 12, 12, 2, 3, 64, true))
    assert(alpha.count == 7 and Selection.contains(alpha, 5, 3),
           "Modo global ignorou diferença RGBA no canal alfa")
    local all = assert(Selection.magic_wand(layer, 12, 12, 2, 3, 255, true))
    assert(all.count == 144 and Selection.contains(all, 0, 0) and
           Selection.contains(all, 11, 11),
           "Tolerância máxima global deveria selecionar o canvas inteiro")
    for _, bad in ipairs({"global", 1, 0, {}}) do
        local invalid, reason = Selection.magic_wand(
            layer, 12, 12, 2, 3, 0, bad)
        assert(not invalid and reason,
               "Flag de modo global inválida foi aceita")
    end
    assert(not Selection.magic_wand(layer, 12, 12, -1, 3, 0, true),
           "Clique global fora do documento foi aceito")
    local huge, limit = Selection.magic_wand(
        layer, 1025, 1025, 2, 3, 0, true)
    assert(not huge and limit, "Modo global não respeitou limite de 1 Mi")
    assert(connected.count == 1 and global.count == 3 and
           #p.undo == 0 and #p.redo == 0 and not p.dirty and
           close(select(1, data:getPixel(2, 3)), .4, .005),
           "Modo global modificou a camada ou máscaras já criadas")
end

-- Atalho de fonte da varinha, edição da camada ativa e metadados
-- de cinco colunas com fallback para todos os formatos anteriores.
local function test_magic_wand_sample_all_bridge(Bridge, gallery)
    local Selection = require("lua_selection")
    local model = {
        screen = "editor", document = {width = 16, height = 16},
        layers = {
            {id = 1, visible = true, opacity = 100,
             blending = "Normal", name = "Base"},
            {id = 2, visible = true, opacity = 100,
             blending = "Normal", name = "Upper"}
        },
        active_layer_id = 1, active_tool = "brush",
        background_mode = "transparent_dark"
    }
    function model:active_layer()
        for _, info in ipairs(self.layers) do
            if info.id == self.active_layer_id then return info end
        end
    end
    local id = gallery:add_artwork(16, 16, "Wand sample visible")
    Bridge.create(model, id, gallery)
    local view = {zoom = 10, rotation = 0, pan_x = 0, pan_y = 0}
    local prefs = {tool_position = "left"}
    local function screen(x, y)
        return 62 + (1024 - 62 - 34) / 2 + (x + .5 - 8) * 11,
               62 + (768 - 160) / 2 + (y + .5 - 8) * 11
    end
    local function press(x, y, color)
        local mx, my = screen(x, y)
        assert(Bridge.mousepressed(model, id, mx, my, 1024, 768,
                                   view, prefs, color, 1, 100, nil))
        Bridge.mousereleased()
    end
    press(3, 3, {255, 0, 0})
    press(9, 9, {255, 0, 0})
    model.active_layer_id = 2
    press(3, 3, {0, 0, 255})
    press(8, 8, {0, 0, 255})
    model.active_layer_id = 1
    model.active_tool = "magic_wand"
    local notices = {}
    local function notify(message) notices[#notices + 1] = message end
    local function shortcut(key)
        local original = love.keyboard.isDown
        love.keyboard.isDown = function(...)
            for i = 1, select("#", ...) do
                local k = select(i, ...)
                if k == "lctrl" or k == "lalt" then return true end
            end
            return false
        end
        local handled = Bridge.keypressed(key, model, notify)
        love.keyboard.isDown = original
        return handled
    end
    local function wand(x, y)
        press(x, y, {0, 255, 0})
        return assert(Bridge.selection_snapshot())
    end
    assert(Bridge.wand_sample_all(model) == false and
           Bridge.wand_global(model) == false,
           "Obra nova deveria amostrar somente a camada ativa")
    assert(shortcut("g") and Bridge.wand_global(model))
    local active = wand(3, 3)
    assert(active.count == 2 and Selection.contains(active, 9, 9)
           and not Selection.contains(active, 8, 8),
           "Varinha global da camada ativa incluiu pixels de outra camada")
    local old_history = Bridge.selection_history_snapshot().undo
    assert(shortcut("t") and Bridge.wand_sample_all(model) == true
           and Bridge.selection_history_snapshot().undo == old_history
           and notices[#notices]:find("camadas visíveis", 1, true),
           "Ctrl+Alt+T não alternou a fonte independentemente do histórico")
    local all = wand(3, 3)
    assert(all.count == 2 and Selection.contains(all, 8, 8)
           and not Selection.contains(all, 9, 9),
           "Varinha não amostrou pixels azuis sobre camadas diferentes")
    assert(shortcut("g") and not Bridge.wand_global(model))
    all = wand(3, 3)
    assert(all.count == 1 and not Selection.contains(all, 8, 8),
           "Fonte composta não respeitou modo contíguo")
    assert(shortcut("g") and Bridge.wand_global(model))
    all = wand(3, 3)
    assert(all.count == 2, "Voltar a global não restaurou fonte composta")
    -- A máscara é calculada pela composição, mas a pintura subsequente
    -- deve continuar escrevendo SOMENTE na camada ativa.
    model.active_tool = "brush"
    press(8, 8, {0, 255, 0})
    assert(Bridge.save())
    local index = assert(love.filesystem.read("lua-artworks/index.tsv"))
    local key
    for line in index:gmatch("[^\r\n]+") do
        if line:find("Wand sample visible", 1, true) then
            key = line:match("^(art_%d+_%d+)\t")
        end
    end
    assert(key, "Não encontrou pasta da amostragem composta")
    local path = "lua-artworks/" .. key
    local metadata = assert(love.filesystem.read(path .. "/document.tsv"))
    assert(metadata:match("\t0\t1\t1\t0\t0\t0$"),
           "Preferência global e amostragem composta não persistiram")
    local layer1 = love.image.newImageData(path .. "/layer_1.png")
    local layer2 = love.image.newImageData(path .. "/layer_2.png")
    local _, green, _, alpha1 = layer1:getPixel(8, 8)
    local _, _, blue, alpha2 = layer2:getPixel(8, 8)
    assert(green > .9 and alpha1 > .9 and blue > .9 and alpha2 > .9,
           "Pincel após seleção composta não ficou restrito à camada ativa")
    local other = gallery:add_artwork(16, 16, "Other wand source")
    Bridge.create(model, other, gallery)
    assert(Bridge.wand_sample_all(model) == false,
           "Preferência de amostragem vazou entre obras")
    Bridge.open(model, id)
    assert(Bridge.wand_sample_all(model) == true and
           Bridge.wand_global(model) == true and
           Bridge.selection_snapshot().count == 2,
           "Reabertura não recuperou fonte e máscara composta")
    assert(shortcut("t") and not Bridge.wand_sample_all(model)
           and shortcut("t") and Bridge.wand_sample_all(model),
           "Ctrl+Alt+T não é reversível")
    assert(love.filesystem.write(path .. "/document.tsv", "1\twhite\t0\t1"))
    Bridge.open(model, id)
    assert(Bridge.wand_sample_all(model) == false and
           Bridge.wand_global(model) == true,
           "Quatro colunas perderam modo global legado")
    assert(love.filesystem.write(path .. "/document.tsv", "1\twhite\t16"))
    Bridge.open(model, id)
    assert(Bridge.wand_sample_all(model) == false and
           Bridge.wand_global(model) == false and
           Bridge.wand_tolerance(model) == 16,
           "Três colunas perderam tolerância legada")
    assert(love.filesystem.write(path .. "/document.tsv", "1\twhite"))
    Bridge.open(model, id)
    assert(Bridge.wand_sample_all(model) == false and
           Bridge.wand_tolerance(model) == 0,
           "Duas colunas deveriam restaurar preferência padrão")
    assert(love.filesystem.write(path .. "/document.tsv",
                                 "1\twhite\t0\t1\tinvalid"))
    Bridge.open(model, id)
    assert(Bridge.wand_sample_all(model) == false and
           Bridge.wand_global(model) == true,
           "Fonte inválida deveria voltar à camada ativa sem perder global")
    assert(Bridge.wand_sample_all({screen = "gallery"}) == nil and
           not Bridge.toggle_wand_sample_all({screen = "gallery"}),
           "Atalho da fonte da varinha atuou fora do editor")
    assert(Bridge.undo() and Bridge.redo(),
           "Preferência de fonte corrompeu histórico raster")
    require("lua_history").cleanup(path)
    require("lua_selection_history").cleanup(path)
    for _, name in ipairs(love.filesystem.getDirectoryItems(path)) do
        love.filesystem.remove(path .. "/" .. name)
    end
    assert(love.filesystem.remove(path))
end

-- Ponte: modo por obra, atalho, combinação, undo e metadados legados.
local function test_magic_wand_global_bridge(Bridge, gallery)
    local Selection = require("lua_selection")
    local model = {
        screen = "editor", document = {width = 16, height = 16},
        layers = {{id = 1, visible = true, opacity = 100,
                   blending = "Normal", name = "Global colors"}},
        active_layer_id = 1, active_tool = "brush",
        background_mode = "white"
    }
    function model:active_layer() return self.layers[1] end
    local id = gallery:add_artwork(16, 16, "Wand global mode")
    Bridge.create(model, id, gallery)
    local view = {zoom = 10, rotation = 0, pan_x = 0, pan_y = 0}
    local prefs = {tool_position = "left"}
    local function screen(x, y)
        return 62 + (1024 - 62 - 34) / 2 + (x + .5 - 8) * 11,
               62 + (768 - 160) / 2 + (y + .5 - 8) * 11
    end
    local function press(x, y, color)
        local mx, my = screen(x, y)
        assert(Bridge.mousepressed(model, id, mx, my, 1024, 768,
                                   view, prefs, color, 1, 100, nil))
        Bridge.mousereleased()
    end
    press(3, 3, {100, 50, 75})
    press(2, 2, {100, 50, 75}) -- só diagonal
    press(10, 10, {100, 50, 75}) -- ilha distante
    press(11, 10, {120, 50, 75}) -- cor próxima, mas diferente
    local notices = {}
    local function notify(message)
        notices[#notices + 1] = message
    end
    local function shortcut(key)
        local saved = love.keyboard.isDown
        love.keyboard.isDown = function(...)
            for i = 1, select("#", ...) do
                local k = select(i, ...)
                if k == "lctrl" or k == "lalt" then return true end
            end
            return false
        end
        local ok = Bridge.keypressed(key, model, notify)
        love.keyboard.isDown = saved
        return ok
    end
    local function wand(x, y, shift, alt)
        local mx, my = screen(x, y)
        local original = love.keyboard.isDown
        love.keyboard.isDown = function(...)
            for i = 1, select("#", ...) do
                local k = select(i, ...)
                if (shift or alt) and k == "lctrl" then return true end
                if shift and k == "lshift" then return true end
                if alt and k == "lalt" then return true end
            end
            return false
        end
        local accepted = Bridge.mousepressed(
            model, id, mx, my, 1024, 768, view, prefs,
            {255, 0, 0}, 1, 100, nil)
        love.keyboard.isDown = original
        assert(accepted, "Clique global da varinha não foi consumido")
        return Bridge.selection_snapshot()
    end
    assert(Bridge.wand_global(model) == false and
           Bridge.wand_tolerance(model) == 0,
           "Obra nova não iniciou no modo contíguo, tolerância zero")
    model.active_tool = "magic_wand"
    assert(wand(3, 3).count == 1,
           "Modo contíguo incluiu regiões separadas")
    local before = Bridge.selection_history_snapshot().undo
    assert(shortcut("g") and Bridge.wand_global(model) and
           Bridge.selection_history_snapshot().undo == before and
           notices[#notices]:find("todas as regiões", 1, true),
           "Ctrl+Alt+G não alternou modo sem alterar histórico")
    local all = assert(wand(3, 3))
    assert(all.count == 3 and
           Selection.contains(all, 10, 10) and
           Selection.contains(all, 2, 2) and
           not Selection.contains(all, 11, 10),
           "Modo global não incluiu ilhas isoladas da mesma cor")
    assert(shortcut("right") and shortcut("right") and
           Bridge.wand_tolerance(model) == 32)
    all = assert(wand(3, 3))
    assert(all.count == 4 and Selection.contains(all, 11, 10),
           "Modo global não respeitou a tolerância ajustada da varinha")
    assert(shortcut("0") and Bridge.wand_tolerance(model) == 0)
    local current_history = Bridge.selection_history_snapshot().undo
    assert(wand(11, 10, false, true).count == 3 and
           Bridge.selection_history_snapshot().undo == current_history + 1,
           "Ctrl+Alt clique não subtraiu a cor da seleção global")
    assert(wand(11, 10, true, false).count == 4,
           "Ctrl+Shift clique não somou a cor à seleção global")
    local intersection = assert(wand(11, 10, true, true))
    assert(intersection.count == 1 and
           Selection.contains(intersection, 11, 10),
           "Ctrl+Shift+Alt não intersectou a máscara global")
    assert(Bridge.selection_undo() and
           Bridge.selection_snapshot().count == 4 and
           Bridge.selection_redo() and
           Bridge.selection_snapshot().count == 1,
           "Histórico de seleção não preservou operações globais")
    assert(shortcut("right") and shortcut("right") and
           Bridge.wand_tolerance(model) == 32,
           "Modo global não restaurou a tolerância após combinação")
    assert(Bridge.save(), "Não salvou seleção e modo global")
    local index = assert(love.filesystem.read("lua-artworks/index.tsv"))
    local key
    for line in index:gmatch("[^\r\n]+") do
        if line:find("Wand global mode", 1, true) then
            key = line:match("^(art_%d+_%d+)\t")
        end
    end
    assert(key, "Obra temporária do modo global não foi localizada")
    local path = "lua-artworks/" .. key
    local meta = assert(love.filesystem.read(path .. "/document.tsv"))
    assert(meta:match("\t32\t1\t0\t0\t0\t0$"),
           "document.tsv não registrou modo global e tolerância")
    local other = gallery:add_artwork(16, 16, "Wand other mode")
    Bridge.create(model, other, gallery)
    assert(Bridge.wand_global(model) == false and
           Bridge.wand_tolerance(model) == 0,
           "Modo global vazou para outra obra")
    Bridge.open(model, id)
    assert(Bridge.wand_global(model) == true and
           Bridge.wand_tolerance(model) == 32 and
           Bridge.selection_snapshot().count == 1,
           "Abertura não restaurou seleção e modo da varinha")
    model.active_tool = "magic_wand"
    assert(wand(3, 3).count == 4,
           "Modo global salvo não foi aplicado após reabertura")
    assert(shortcut("g") and Bridge.wand_global(model) == false and
           wand(3, 3).count == 1,
           "Alternar para contíguo não preservou o comportamento original")
    -- O modo contíguo com tol 32 mantém somente o seed: 2,2 é
    -- diagonal, enquanto 10,10/11,10 formam outra região distante.
    assert(not Selection.contains(Bridge.selection_snapshot(), 10, 10) and
           not Selection.contains(Bridge.selection_snapshot(), 2, 2),
           "Modo contíguo deixou escapar pixels de regiões separadas")
    assert(Bridge.save())
    assert(love.filesystem.read(path .. "/document.tsv"):match("\t32\t0\t0\t0\t0\t0$"))
    assert(love.filesystem.write(path .. "/document.tsv", "1\twhite\t32"))
    Bridge.open(model, id)
    assert(Bridge.wand_tolerance(model) == 32 and
           Bridge.wand_global(model) == false,
           "Arquivo legado com três colunas perdeu tol ou modo padrão")
    assert(love.filesystem.write(path .. "/document.tsv", "1\twhite"))
    Bridge.open(model, id)
    assert(Bridge.wand_tolerance(model) == 0 and
           Bridge.wand_global(model) == false,
           "Arquivo legado de duas colunas não iniciou modo contíguo")
    assert(love.filesystem.write(path .. "/document.tsv", "1\twhite\t32\tinvalido"))
    Bridge.open(model, id)
    assert(Bridge.wand_global(model) == false,
           "Modo inválido da varinha não foi rejeitado")
    assert(Bridge.wand_global({screen = "gallery"}) == nil and
           not Bridge.toggle_wand_global({screen = "gallery"}),
           "Preferência da varinha atuou fora do editor")
    assert(Bridge.undo() and Bridge.redo(),
           "Modo global de seleção corrompeu histórico raster")
    require("lua_history").cleanup(path)
    require("lua_selection_history").cleanup(path)
    for _, name in ipairs(love.filesystem.getDirectoryItems(path)) do
        love.filesystem.remove(path .. "/" .. name)
    end
    assert(love.filesystem.remove(path))
end

-- Varinha contígua compara TODOS os canais RGBA com tolerância 8-bit.
local function test_magic_wand_tolerance(E)
    local Selection = require("lua_selection")
    local model = {layers = {{id = 1, visible = true, opacity = 100}}}
    local project = E.new(12, 12)
    E.sync(project, model)
    local layer = project.layers[1]
    local data = layer.pixels
    data:setPixel(2, 3, .4, .2, .3, 1)
    data:setPixel(3, 3, .4 + 12 / 255, .2, .3, 1)
    data:setPixel(3, 4, .4, .2 + 16 / 255, .3, 1)
    data:setPixel(4, 3, .4 + 39 / 255, .2, .3, 1)
    data:setPixel(5, 3, .4, .2, .3, .75)
    data:setPixel(1, 2, .4, .2, .3, 1) -- só diagonal
    data:setPixel(8, 8, .4, .2, .3, 1) -- ilha isolada
    layer.image:replacePixels(data)
    project.dirty = false
    local exact = assert(Selection.magic_wand(layer, 12, 12, 2, 3))
    local zero = assert(Selection.magic_wand(layer, 12, 12, 2, 3, 0))
    assert(exact.count == 1 and zero.count == 1 and
           Selection.contains(zero, 2, 3) and
           not Selection.contains(zero, 3, 3) and
           not Selection.contains(zero, 1, 2),
           "Tolerância zero mudou o comportamento de seleção exata")
    local step = assert(Selection.magic_wand(layer, 12, 12, 2, 3, 16))
    assert(step.count == 3 and
           Selection.contains(step, 3, 3) and
           Selection.contains(step, 3, 4) and
           not Selection.contains(step, 4, 3) and
           not Selection.contains(step, 1, 2),
           "Tolerância 16 não selecionou diferenças RGBA adjacentes")
    local mid = assert(Selection.magic_wand(layer, 12, 12, 2, 3, 48))
    assert(mid.count == 4 and
           Selection.contains(mid, 4, 3) and
           not Selection.contains(mid, 5, 3) and
           not Selection.contains(mid, 8, 8),
           "Varinha deve comparar pixels ao seed e respeitar conectividade")
    local alpha = assert(Selection.magic_wand(layer, 12, 12, 2, 3, 64))
    assert(alpha.count == 5 and
           Selection.contains(alpha, 5, 3),
           "Diferença no canal alfa não obedeceu à tolerância")
    local all = assert(Selection.magic_wand(layer, 12, 12, 2, 3, 255))
    assert(all.count == 144 and Selection.contains(all, 8, 8) and
           Selection.contains(all, 0, 0),
           "Tolerância máxima deve aceitar todo canvas conectado")
    local invalid_inputs = {-1, 256, .5, math.huge, -math.huge}
    for _, value in ipairs(invalid_inputs) do
        local invalid, reason =
            Selection.magic_wand(layer, 12, 12, 2, 3, value)
        assert(not invalid and reason,
               "Varinha aceitou tolerância RGBA inválida")
    end
    local nan = 0 / 0
    assert(not Selection.magic_wand(layer, 12, 12, 2, 3, nan))
    local edge = Selection.magic_wand(layer, 12, 12, -1, 0, 16)
    assert(not edge, "Varinha aceitou ponto fora do documento")
    assert(exact.count == 1 and step.count == 3 and
           #project.undo == 0 and #project.redo == 0 and
           not project.dirty and
           close(select(1, layer.pixels:getPixel(2, 3)), .4, .005),
           "Ajuste de tolerância modificou raster ou máscaras antigas")
end

-- Ponte: atalhos, isolamento por obra e metadados legados.
local function test_magic_wand_tolerance_bridge(Bridge, gallery)
    local Selection = require("lua_selection")
    local model = {
        screen = "editor", document = {width = 16, height = 16},
        layers = {{id = 1, visible = true, opacity = 100,
                   blending = "Normal", name = "Wand range"}},
        active_layer_id = 1, active_tool = "brush",
        background_mode = "white"
    }
    function model:active_layer() return self.layers[1] end
    local id = gallery:add_artwork(16, 16, "Wand tolerance")
    Bridge.create(model, id, gallery)
    local view = {zoom = 10, rotation = 0, pan_x = 0, pan_y = 0}
    local prefs = {tool_position = "left"}
    local function screen(x, y)
        return 62 + (1024 - 62 - 34) / 2 + (x + .5 - 8) * 11,
               62 + (768 - 160) / 2 + (y + .5 - 8) * 11
    end
    local function press(x, y, color)
        local mx, my = screen(x, y)
        assert(Bridge.mousepressed(model, id, mx, my, 1024, 768,
                                   view, prefs, color or {100, 50, 75},
                                   1, 100, nil))
        Bridge.mousereleased()
    end
    press(3, 3, {100, 50, 75})
    press(4, 3, {112, 50, 75})
    press(5, 3, {139, 50, 75})
    press(10, 10, {100, 50, 75})
    local paint_history_untouched = false
    local notices = {}
    local function notify(message) notices[#notices + 1] = message end
    local function shortcut(key)
        local original = love.keyboard.isDown
        love.keyboard.isDown = function(...)
            for i = 1, select("#", ...) do
                local k = select(i, ...)
                if k == "lctrl" or k == "lalt" then return true end
            end
            return false
        end
        local handled = Bridge.keypressed(key, model, notify)
        love.keyboard.isDown = original
        return handled
    end
    local function wand(x, y)
        local mx, my = screen(x, y)
        assert(Bridge.mousepressed(model, id, mx, my, 1024, 768,
                                   view, prefs, {255, 0, 0}, 1, 100,
                                   nil))
        return assert(Bridge.selection_snapshot())
    end
    assert(Bridge.wand_tolerance(model) == 0,
           "Nova obra deve iniciar varinha com tolerância zero")
    model.active_tool = "magic_wand"
    assert(wand(3, 3).count == 1,
           "Varinha exata inicial selecionou outras cores")
    local mask_undo = Bridge.selection_history_snapshot().undo
    assert(shortcut("right") and Bridge.wand_tolerance(model) == 16)
    assert(#notices == 1 and notices[1]:find("16/255", 1, true) and
           Bridge.selection_history_snapshot().undo == mask_undo,
           "Atalho alterou histórico de seleção ou não exibiu tolerância")
    assert(wand(3, 3).count == 2 and
           not Selection.contains(Bridge.selection_snapshot(), 5, 3),
           "Ctrl+Alt+Right não alterou tolerância aplicada ao clique")
    assert(shortcut("right") and shortcut("right") and
           Bridge.wand_tolerance(model) == 48)
    local wide = wand(3, 3)
    assert(wide.count == 3 and Selection.contains(wide, 5, 3) and
           not Selection.contains(wide, 10, 10),
           "Tolerância maior ignorou conectividade ou faixa RGB")
    assert(shortcut("left") and Bridge.wand_tolerance(model) == 32)
    assert(wand(3, 3).count == 2,
           "Ctrl+Alt+Left não reduziu corretamente a tolerância")
    assert(shortcut("0") and Bridge.wand_tolerance(model) == 0)
    assert(wand(3, 3).count == 1, "Ctrl+Alt+0 não restaurou seleção exata")
    assert(Bridge.adjust_wand_tolerance(model, -400) and
           Bridge.wand_tolerance(model) == 0 and
           Bridge.adjust_wand_tolerance(model, 999) and
           Bridge.wand_tolerance(model) == 255,
           "Tolerância não respeitou limites 0..255")
    assert(wand(3, 3).count == 256,
           "Tolerância 255 deveria selecionar o documento inteiro")
    assert(not Bridge.adjust_wand_tolerance(model, 1.5) and
           not Bridge.adjust_wand_tolerance({screen="gallery"}, 16),
           "Atalhos aceitaram incremento inválido ou tela errada")
    assert(Bridge.adjust_wand_tolerance(model, -207) and
           Bridge.wand_tolerance(model) == 48)
    assert(Bridge.selection_history_snapshot().undo > mask_undo)
    assert(Bridge.save(), "Falha ao salvar tolerância da varinha")
    local index = assert(love.filesystem.read("lua-artworks/index.tsv"))
    local key
    for line in index:gmatch("[^\r\n]+") do
        if line:find("Wand tolerance", 1, true) then
            key = line:match("^(art_%d+_%d+)\t")
        end
    end
    assert(key, "Não encontrou diretório da varinha")
    local path = "lua-artworks/" .. key
    local meta = assert(love.filesystem.read(path .. "/document.tsv"))
    assert(meta:match("\t48\t0\t0\t0\t0\t0$"),
           "document.tsv não persistiu tolerância nem modo contíguo")
    -- Abrir outra obra não pode herdar a tolerância desta.
    local id2 = gallery:add_artwork(16, 16, "Temporary wand")
    Bridge.create(model, id2, gallery)
    assert(Bridge.wand_tolerance(model) == 0,
           "Tolerância vazou entre obras diferentes")
    Bridge.open(model, id)
    assert(Bridge.wand_tolerance(model) == 48 and
           Bridge.selection_snapshot() and
           Bridge.selection_snapshot().count == 256,
           "Reabertura não recuperou preferência e máscara")
    model.active_tool = "magic_wand"
    assert(wand(3, 3).count == 3,
           "Varinha ignorou tolerância restaurada da obra")
    assert(love.filesystem.write(path .. "/document.tsv", "1\twhite\t999"))
    Bridge.open(model, id)
    assert(Bridge.wand_tolerance(model) == 0 and
           model.active_layer_id == 1,
           "Tolerância inválida não retornou ao zero")
    assert(love.filesystem.write(path .. "/document.tsv", "1\twhite"))
    Bridge.open(model, id)
    assert(Bridge.wand_tolerance(model) == 0,
           "document.tsv legado de duas colunas deixou de funcionar")
    -- Undo raster ainda desfaz traços após os ajustes de preferência.
    assert(Bridge.undo() and Bridge.redo(),
           "Ajustes de tolerância corromperam histórico raster")
    require("lua_history").cleanup(path)
    require("lua_selection_history").cleanup(path)
    for _, filename in ipairs(love.filesystem.getDirectoryItems(path)) do
        love.filesystem.remove(path .. "/" .. filename)
    end
    assert(love.filesystem.remove(path))
end

-- Combinação booleana pura de máscaras arbitrárias.
local function test_selection_boolean(E)
    local Selection = require("lua_selection")
    local contains = Selection.contains
    local project = E.new(16, 16)
    E.sync(project, {layers = {{id = 1, visible = true, opacity = 100}}})
    project.layers[1].pixels:setPixel(8, 8, 1, 0.3, 0.2, 0.65)
    project.layers[1].image:replacePixels(project.layers[1].pixels)
    project.dirty = false
    local first = assert(Selection.rectangle(16, 16, 2, 2, 4, 4))
    local second = assert(Selection.rectangle(16, 16, 4, 2, 6, 4))
    local union = assert(Selection.combine(first, second, "add", 16, 16))
    local difference = assert(Selection.combine(first, second, "subtract", 16, 16))
    local intersection = assert(Selection.combine(first, second, "intersect", 16, 16))
    assert(first.count == 9 and second.count == 9 and
           union.count == 15 and difference.count == 6 and
           intersection.count == 3 and union.kind == "combined_add",
           "Operações booleanas não obedeceram à álgebra de máscaras")
    assert(contains(union, 2, 2) and contains(union, 6, 4) and
           not contains(difference, 4, 3) and
           contains(intersection, 4, 3) and
           not contains(intersection, 3, 3),
           "Combinação não respeitou coordenadas reais dos pixels")
    assert(first.count == 9 and contains(first, 4, 3) and
           second.count == 9 and contains(second, 4, 3),
           "Combinação modificou as máscaras originais")

    local sparse = assert(Selection.from_mask(16, 16, {
        [1 + 1 * 16] = true, [8 + 6 * 16] = true,
        [15 + 15 * 16] = true
    }, "lasso"))
    local partial = assert(Selection.combine(union, sparse, "add", 16, 16))
    assert(partial.count == 18 and contains(partial, 15, 15) and
           not contains(union, 15, 15),
           "União não integrou ilhas não retangulares")
    local empty, empty_reason = Selection.combine(first, sparse,
                                                   "intersect", 16, 16)
    assert(not empty and not empty_reason,
           "Interseção sem pixels em comum deve desmarcar sem erro")
    local from_nil = assert(Selection.combine(nil, sparse, "add", 16, 16))
    assert(from_nil.count == sparse.count and from_nil ~= sparse,
           "União sem seleção não clonou a nova área")
    assert(not Selection.combine(nil, sparse, "subtract", 16, 16) and
           not Selection.combine(nil, sparse, "intersect", 16, 16),
           "Subtrair/intersectar sem seleção deve resultar em máscara vazia")
    assert(not Selection.combine(sparse, sparse, "subtract", 16, 16),
           "Subtrair a própria seleção deveria desmarcar")
    local replaced = assert(Selection.combine(first, sparse,
                                               "replace", 16, 16))
    assert(replaced.count == sparse.count and replaced ~= sparse,
           "Substituição deve manter máscara original independente")
    local invalid, err = Selection.combine(first, sparse,
                                            "xor", 16, 16)
    assert(not invalid and err, "Operação desconhecida foi aceita")
    local wrong, mismatch = Selection.combine(first, sparse,
                                               "add", 15, 16)
    assert(not wrong and mismatch, "Máscaras de dimensões erradas foram aceitas")
    local large, limit = Selection.combine(first, second,
                                            "add", 1025, 1025)
    assert(not large and limit, "Operações não respeitaram limite de 1 Mi")
    assert(#project.undo == 0 and #project.redo == 0 and
           not project.dirty and
           select(1, project.layers[1].pixels:getPixel(8, 8)) > 0.9,
           "Álgebra de máscaras alterou pixels ou histórico")

    local path = "lua-boolean-selection-tests"
    assert(love.filesystem.createDirectory(path))
    assert(Selection.save(partial, path .. "/selection.png"))
    local loaded = assert(Selection.load(path .. "/selection.png", 16, 16))
    assert(loaded.count == partial.count and
           contains(loaded, 1, 1) and contains(loaded, 15, 15) and
           not contains(loaded, 0, 0),
           "PNG da seleção combinada perdeu ilhas da máscara")
    assert(love.filesystem.remove(path .. "/selection.png"))
    assert(love.filesystem.remove(path))
end

-- Gestos reais: Ctrl+Shift soma, Ctrl+Alt subtrai, os três intersectam.
local function test_selection_boolean_bridge(Bridge, gallery)
    local Selection = require("lua_selection")
    local model = {
        screen = "editor", document = {width = 32, height = 32},
        layers = {{id = 1, visible = true, opacity = 100,
                   blending = "Normal", name = "Boolean masks"}},
        active_layer_id = 1, active_tool = "brush",
        background_mode = "white"
    }
    function model:active_layer() return self.layers[1] end
    local art = gallery:add_artwork(32, 32, "Boolean gestures")
    Bridge.create(model, art, gallery)
    local view = {zoom = 10, rotation = 0, pan_x = 0, pan_y = 0}
    local prefs = {tool_position = "left"}
    local function screen(x, y)
        return 62 + (1024 - 62 - 34) / 2 + (x + 0.5 - 16) * 11,
            62 + (768 - 160) / 2 + (y + 0.5 - 16) * 11
    end
    local function with_keys(shift, alt, fn)
        local native = love.keyboard.isDown
        love.keyboard.isDown = function(...)
            for i = 1, select("#", ...) do
                local key = select(i, ...)
                if key == "lctrl" then return true end
                if shift and key == "lshift" then return true end
                if alt and key == "lalt" then return true end
            end
            return false
        end
        local result = fn()
        love.keyboard.isDown = native
        return result
    end
    local function press(x, y, shift, alt)
        local mx, my = screen(x, y)
        return with_keys(shift, alt, function()
            return Bridge.mousepressed(model, art, mx, my, 1024, 768,
                view, prefs, {255, 0, 0}, 1, 100, nil)
        end)
    end
    local function release(x, y)
        local mx, my = screen(x, y)
        return Bridge.mousereleased(model, mx, my, 1)
    end
    local function shape()
        return Bridge.selection_snapshot()
    end

    -- Dois pontos isolados para varinha de tolerância RGBA.
    assert(press(22, 22, false, false))
    Bridge.mousereleased()
    assert(press(26, 26, false, false))
    Bridge.mousereleased()
    model.active_tool = "transform"

    assert(press(3, 3, false, false) and release(6, 6))
    assert(shape().count == 16, "Retângulo inicial incorreto")
    -- Em região parcialmente sobreposta, Ctrl+Shift substitui o move por união.
    assert(press(5, 5, true, false))
    assert(release(8, 8))
    assert(shape().count == 28 and
           Selection.contains(shape(), 8, 8),
           "Ctrl+Shift não somou um retângulo sobreposto")
    assert(press(5, 5, false, true) and release(6, 6))
    assert(shape().count == 24 and
           not Selection.contains(shape(), 5, 5),
           "Ctrl+Alt não subtraiu retângulo dentro da seleção")
    assert(press(4, 4, true, true) and release(7, 7))
    local common = assert(shape())
    assert(Selection.contains(common, 4, 4) and
           Selection.contains(common, 7, 7) and
           not Selection.contains(common, 3, 3) and
           not Selection.contains(common, 5, 5),
           "Ctrl+Shift+Alt não intersectou as regiões")

    model.active_tool = "lasso"
    assert(press(12, 12, true, false))
    local mx, my = screen(19, 12)
    assert(Bridge.mousemoved(model, mx, my, 1))
    mx, my = screen(12, 19)
    assert(Bridge.mousemoved(model, mx, my, 1))
    assert(release(12, 12))
    assert(Selection.contains(shape(), 13, 13) and
           Selection.contains(shape(), 7, 7),
           "Ctrl+Shift não somou a área criada pelo laço")
    local after_lasso = assert(shape())
    assert(after_lasso.count > common.count,
           "Laço combinado não acrescentou pixels")

    model.active_tool = "magic_wand"
    assert(press(22, 22, true, false))
    assert(Selection.contains(shape(), 22, 22),
           "Varinha com Ctrl+Shift não somou região pintada")
    local with_wand = assert(shape())
    assert(press(22, 22, false, true))
    assert(not Selection.contains(shape(), 22, 22) and
           shape().count < with_wand.count,
           "Varinha com Ctrl+Alt não subtraiu a região")
    assert(Bridge.selection_command(model, "select_all"))
    assert(press(26, 26, true, true))
    local wand_intersection = assert(shape())
    assert(Selection.contains(wand_intersection, 26, 26) and
           not Selection.contains(wand_intersection, 3, 3),
           "Varinha Ctrl+Shift+Alt não intersectou com o canvas inteiro")
    assert(press(3, 3, false, true))
    -- Subtrair outra ilha não deve apagar a seleção atual.
    assert(shape().count == wand_intersection.count,
           "Subtração de máscara disjunta deveria ser no-op")

    -- Interseção realmente vazia remove a seleção, mas não a camada.
    model.active_tool = "transform"
    assert(press(1, 1, true, true) and release(2, 2))
    assert(not shape(), "Interseção vazia deveria desmarcar")
    -- Exatamente dois históricos raster dos dois pontos pintados antes
    -- das combinações; nenhuma operação de máscara criou passo adicional.
    assert(Bridge.undo() and Bridge.undo() and not Bridge.undo() and
           Bridge.redo() and Bridge.redo(),
           "Combinações de máscara alteraram o histórico raster")
    model.layers[1].locked = true
    model.layers[1].alpha_lock = true
    assert(press(10, 10, true, false) and release(11, 11))
    assert(shape().count == 4,
           "Combinação em Layer Lock/Alpha Lock deveria operar apenas máscara")
    model.layers[1].locked = false
    model.layers[1].alpha_lock = false
    assert(Bridge.save(), "Salvamento após combinação falhou")
    local persisted_count = shape().count
    Bridge.open(model, art)
    assert(shape() and shape().count == persisted_count,
           "Reabertura não restaurou seleção combinada")
    assert(Bridge.undo() and Bridge.undo() and not Bridge.undo() and
           Bridge.redo() and Bridge.redo(),
           "Reabertura criou histórico raster para mudanças de máscara")

    -- Limpar a obra de teste e snapshots sem afetar os demais testes.
    local index = love.filesystem.read("lua-artworks/index.tsv") or ""
    local key
    for line in index:gmatch("[^\r\n]+") do
        if line:find("Boolean gestures", 1, true) then
            key = line:match("^(art_%d+_%d+)\t")
        end
    end
    assert(key, "Não localizou obra temporária da combinação")
    local path = "lua-artworks/" .. key
    require("lua_history").cleanup(path)
    for _, filename in ipairs(love.filesystem.getDirectoryItems(path)) do
        love.filesystem.remove(path .. "/" .. filename)
    end
    assert(love.filesystem.remove(path), "Falha ao remover obra de teste")
end

-- Operações puras de máscara: selecionar tudo e inverter pixels selecionados.
local function test_selection_all_invert(E)
    local Selection = require("lua_selection")
    local p = E.new(16, 16)
    E.sync(p, {layers = {{id = 1, visible = true, opacity = 100}}})
    local original = p.layers[1].pixels
    original:setPixel(2, 3, 1, 0, 0, 0.6)
    original:setPixel(8, 8, 0, 0, 1, 1)
    p.layers[1].image:replacePixels(original)
    p.dirty = false

    local full = assert(Selection.all(16, 16))
    assert(full.count == 256 and full.kind == "all" and
           full.min_x == 0 and full.min_y == 0 and
           full.max_x == 15 and full.max_y == 15 and
           Selection.contains(full, 0, 0) and
           Selection.contains(full, 15, 15),
           "Select all deve abranger todo o canvas, inclusive as bordas")
    local blank, blank_error = Selection.invert(full, 16, 16)
    assert(not blank and not blank_error,
           "Inverter seleção total deveria desmarcar sem erro")
    local from_empty = assert(Selection.invert(nil, 16, 16))
    assert(from_empty.count == 256 and
           Selection.contains(from_empty, 15, 15),
           "Inverter seleção ausente deve selecionar todo o documento")

    local nonrect = assert(Selection.from_mask(16, 16, {
        [0] = true, [2 + 3 * 16] = true, [5 + 4 * 16] = true,
        [15 + 15 * 16] = true
    }, "lasso"))
    local count = nonrect.count
    local inverted = assert(Selection.invert(nonrect, 16, 16))
    assert(inverted.kind == "inverted" and inverted.count == 256 - count and
           not Selection.contains(inverted, 0, 0) and
           not Selection.contains(inverted, 2, 3) and
           not Selection.contains(inverted, 15, 15) and
           Selection.contains(inverted, 1, 0) and
           Selection.contains(inverted, 14, 15),
           "Inversão deve contemplar TODO o documento, não o bounding box")
    assert(Selection.contains(nonrect, 2, 3) and nonrect.count == count,
           "Inverter modificou indevidamente a máscara anterior")
    local twice = assert(Selection.invert(inverted, 16, 16))
    assert(twice.count == count, "Inverter duas vezes alterou a quantidade")
    for y = 0, 15 do
        for x = 0, 15 do
            assert(Selection.contains(twice, x, y) ==
                   Selection.contains(nonrect, x, y),
                   "Dupla inversão não restaurou os pixels exatos")
        end
    end
    assert(#p.undo == 0 and #p.redo == 0 and not p.dirty and
           select(1, original:getPixel(2, 3)) > 0.9 and
           select(3, original:getPixel(8, 8)) > 0.9,
           "Operações de máscara não podem pintar nem criar histórico raster")
    local invalid, dimension_error = Selection.invert(nonrect, 15, 16)
    assert(not invalid and dimension_error and nonrect.count == count,
           "Inverter com dimensões incompatíveis deve ser rejeitado")
    local too_large, err = Selection.all(1025, 1025)
    assert(not too_large and err and
           not Selection.invert(nil, 1025, 1025),
           "Select all/invert ultrapassou o limite de 1 Mi pixels")

    local path = "lua-inverted-selection-tests"
    assert(love.filesystem.createDirectory(path))
    assert(Selection.save(inverted, path .. "/selection.png"))
    local restored = assert(Selection.load(path .. "/selection.png", 16, 16))
    assert(restored.count == inverted.count and
           not Selection.contains(restored, 2, 3) and
           Selection.contains(restored, 14, 15),
           "PNG da seleção invertida não preservou a máscara")
    assert(love.filesystem.remove(path .. "/selection.png"))
    assert(love.filesystem.remove(path))
end

-- Atalhos reais, Layer Lock/Alpha Lock e ausência de undo para máscaras.
local function test_selection_all_invert_bridge(Bridge, gallery)
    local Selection = require("lua_selection")
    local model = {
        screen = "editor", document = {width = 16, height = 16},
        layers = {{id = 1, visible = true, opacity = 100,
                   blending = "Normal", name = "Selection"}},
        active_layer_id = 1, active_tool = "transform",
        background_mode = "white"
    }
    function model:active_layer() return self.layers[1] end
    local id = gallery:add_artwork(16, 16, "Select all + invert")
    Bridge.create(model, id, gallery)
    local function shortcut(key, shift)
        local native = love.keyboard.isDown
        love.keyboard.isDown = function(...)
            for i = 1, select("#", ...) do
                local k = select(i, ...)
                if k == "lctrl" then return true end
                if shift and k == "lshift" then return true end
            end
            return false
        end
        local consumed = Bridge.keypressed(key, model)
        love.keyboard.isDown = native
        return consumed
    end

    model.layers[1].locked = true
    model.layers[1].alpha_lock = true
    assert(shortcut("a", false), "Ctrl+A não selecionou tudo")
    local all = assert(Bridge.selection_snapshot())
    assert(all.count == 256 and Selection.contains(all, 0, 0) and
           Selection.contains(all, 15, 15),
           "Ctrl+A não incluiu as bordas, mesmo com camada bloqueada")
    assert(shortcut("i", true) and not Bridge.selection_snapshot(),
           "Ctrl+Shift+I não desmarcou uma seleção completa")
    assert(shortcut("i", true), "Inversão sem seleção deveria ser permitida")
    assert(Bridge.selection_snapshot().count == 256,
           "Ctrl+Shift+I sem seleção deveria marcar o canvas inteiro")
    assert(Bridge.undo() == false, "Seleção pura criou histórico raster")
    model.layers[1].locked, model.layers[1].alpha_lock = false, false

    Bridge.clear_selection()
    local view = {zoom = 10, rotation = 0, pan_x = 0, pan_y = 0}
    local prefs = {tool_position = "left"}
    local function screen(x, y)
        return 62 + (1024 - 62 - 34) / 2 + (x + 0.5 - 8) * 11,
               62 + (768 - 160) / 2 + (y + 0.5 - 8) * 11
    end
    local x0, y0 = screen(3, 3)
    local x1, y1 = screen(5, 6)
    assert(Bridge.mousepressed(model, id, x0, y0, 1024, 768,
        view, prefs, {255, 0, 0}, 3, 100, nil))
    assert(Bridge.mousereleased(model, x1, y1, 1))
    local rect = assert(Bridge.selection_snapshot())
    assert(rect.count == 12 and Selection.contains(rect, 3, 3),
           "Ponte não criou seleção parcial retangular")
    assert(shortcut("i", true))
    local opposite = assert(Bridge.selection_snapshot())
    assert(opposite.count == 244 and
           not Selection.contains(opposite, 3, 3) and
           Selection.contains(opposite, 0, 0),
           "Ctrl+Shift+I não inverteu seleção parcial")
    assert(shortcut("i", true))
    local returned = assert(Bridge.selection_snapshot())
    assert(returned.count == rect.count and
           Selection.contains(returned, 3, 3) and
           not Selection.contains(returned, 0, 0),
           "Dupla inversão não restaurou a seleção original")
    assert(shortcut("a", false) and Bridge.selection_snapshot().count == 256)
    assert(shortcut("d", false) and not Bridge.selection_snapshot(),
           "Ctrl+D não removeu a seleção inteira")
    assert(shortcut("a", false) and Bridge.keypressed("escape", model),
           "Esc deveria continuar desmarcando")
    assert(not Bridge.selection_snapshot())
    assert(not Bridge.selection_command({screen = "gallery"}, "select_all"),
           "Seleção do canvas não pode atuar fora do editor")
end

-- Espelhamento de máscaras irregulares, alfa, histórico e persistência.
local function test_selection_flip(E)
    local Selection = require("lua_selection")
    local History = require("lua_history")
    local model = {layers = {{id = 1, visible = true, opacity = 100}}}
    local p = E.new(16, 16)
    E.sync(p, model)
    local pixels = p.layers[1].pixels
    pixels:setPixel(2, 2, 1, 0, 0, 1)
    pixels:setPixel(4, 2, 0, 0, 1, 0.5)
    pixels:setPixel(5, 3, 0, 1, 0, 1)
    pixels:setPixel(2, 4, 1, 1, 0, 0.75)
    pixels:setPixel(10, 10, 1, 0, 1, 1)
    local indices = {}
    for _, point in ipairs({{2, 2}, {4, 2}, {5, 3}, {2, 4}}) do
        indices[point[2] * 16 + point[1]] = true
    end
    local selected = assert(Selection.from_mask(16, 16, indices, "lasso"))
    assert(selected.count == 4 and selected.min_x == 2 and
           selected.max_x == 5 and selected.min_y == 2 and
           selected.max_y == 4, "Máscara irregular inicial incorreta")

    assert(E.reshape_selection(p, 1, selected, "flip_horizontal"),
        "Espelhamento horizontal falhou")
    assert(selected.count == 4 and
           Selection.contains(selected, 5, 2) and
           Selection.contains(selected, 3, 2) and
           Selection.contains(selected, 2, 3) and
           Selection.contains(selected, 5, 4) and
           not Selection.contains(selected, 2, 2) and
           not Selection.contains(selected, 4, 2),
           "Espelhamento horizontal não refletiu os buracos da máscara")
    local red, _, _, red_a = p.layers[1].pixels:getPixel(5, 2)
    local _, _, blue, blue_a = p.layers[1].pixels:getPixel(3, 2)
    local _, green, _, green_a = p.layers[1].pixels:getPixel(2, 3)
    local yellow_r, yellow_g, _, yellow_a = p.layers[1].pixels:getPixel(5, 4)
    local _, _, _, empty = p.layers[1].pixels:getPixel(2, 2)
    assert(red > 0.99 and red_a > 0.99 and
           blue > 0.99 and close(blue_a, 0.5) and
           green > 0.99 and green_a > 0.99 and
           yellow_r > 0.99 and yellow_g > 0.99 and
           close(yellow_a, 0.75) and empty == 0,
           "Espelhamento horizontal perdeu cores ou alfa")
    assert(select(1, p.layers[1].pixels:getPixel(10, 10)) > 0.99,
           "Espelhamento alterou pixel fora da seleção")
    assert(#p.undo == 1 and E.undo(p, selected),
           "Espelhamento horizontal não gerou um undo")
    assert(Selection.contains(selected, 2, 2) and
           not Selection.contains(selected, 5, 2) and
           select(1, p.layers[1].pixels:getPixel(2, 2)) > 0.99,
           "Undo não restaurou pixels e máscara originais")
    assert(E.redo(p, selected) and
           Selection.contains(selected, 5, 2) and
           select(1, p.layers[1].pixels:getPixel(5, 2)) > 0.99,
           "Redo horizontal não restaurou a seleção")
    assert(E.reshape_selection(p, 1, selected, "flip_horizontal"),
           "Segundo flip horizontal falhou")
    assert(Selection.contains(selected, 2, 2) and
           Selection.contains(selected, 4, 2) and
           select(1, p.layers[1].pixels:getPixel(2, 2)) > 0.99,
           "Dois espelhamentos horizontais não restauraram o original")

    assert(E.reshape_selection(p, 1, selected, "flip_vertical"),
           "Espelhamento vertical falhou")
    assert(selected.count == 4 and
           Selection.contains(selected, 2, 4) and
           Selection.contains(selected, 4, 4) and
           Selection.contains(selected, 5, 3) and
           Selection.contains(selected, 2, 2) and
           select(1, p.layers[1].pixels:getPixel(2, 4)) > 0.99 and
           select(3, p.layers[1].pixels:getPixel(4, 4)) > 0.99,
           "Espelhamento vertical não refletiu máscara e conteúdo")
    assert(E.undo(p, selected) and
           Selection.contains(selected, 4, 2) and
           select(3, p.layers[1].pixels:getPixel(4, 2)) > 0.99,
           "Undo vertical não restaurou geometria e pixels")
    assert(E.redo(p, selected) and
           Selection.contains(selected, 4, 4),
           "Redo vertical não restaurou geometria")
    assert(E.reshape_selection(p, 1, selected, "flip_vertical") and
           Selection.contains(selected, 4, 2),
           "Dois flips verticais não restauraram o original")

    -- Máscara com lacuna: o destino não selecionado tem azul opaco.
    local overlay = E.new(16, 16)
    E.sync(overlay, model)
    overlay.layers[1].pixels:setPixel(2, 2, 1, 0, 0, 0.5)
    overlay.layers[1].pixels:setPixel(4, 2, 0, 0, 1, 1)
    overlay.layers[1].pixels:setPixel(4, 3, 0, 1, 0, 1)
    local gap = assert(Selection.from_mask(16, 16, {
        [2 + 2 * 16] = true, [4 + 3 * 16] = true}, "lasso"))
    assert(E.reshape_selection(overlay, 1, gap, "flip_horizontal"))
    local mixed_red, mixed_green, mixed_blue, mixed_a =
        overlay.layers[1].pixels:getPixel(4, 2)
    assert(close(mixed_red, 0.5) and close(mixed_green, 0) and
           close(mixed_blue, 0.5) and close(mixed_a, 1) and
           not Selection.contains(gap, 2, 2),
           "RGBA source-over espelhado sobrescreveu pixel fora da máscara")
    assert(E.undo(overlay, gap) and
           Selection.contains(gap, 2, 2) and
           select(3, overlay.layers[1].pixels:getPixel(4, 2)) > 0.99,
           "Undo source-over não restaurou pixel de fundo")

    -- Recusa operações inócuas e desconhecidas sem criar histórico.
    local thin = assert(Selection.rectangle(16, 16, 8, 3, 8, 7))
    local before = #p.undo
    local no_horizontal = E.reshape_selection(p, 1, thin, "flip_horizontal")
    assert(not no_horizontal and #p.undo == before,
           "Espelhamento horizontal de coluna única gerou histórico")
    local line = assert(Selection.rectangle(16, 16, 3, 8, 7, 8))
    local no_vertical = E.reshape_selection(p, 1, line, "flip_vertical")
    local unknown = E.reshape_selection(p, 1, selected, "flip_diagonal")
    assert(not no_vertical and not unknown and #p.undo == before,
           "Comando inválido ou linha única alterou histórico")

    -- PNGs de seleção e do histórico preservam um flip e permitem undo/redo.
    local path = "lua-flip-tests"
    assert(love.filesystem.createDirectory(path))
    assert(p.layers[1].pixels:encode("png", path .. "/layer_1.png"))
    assert(Selection.save(selected, path .. "/selection.png"))
    local wrote, count = History.save(p, path, selected)
    assert(wrote and count > 0, "Histórico do espelhamento não foi persistido")
    local reopened = E.new(16, 16)
    E.sync(reopened, model)
    assert(E.load_layer(reopened, 1, path .. "/layer_1.png"))
    local restored = assert(Selection.load(path .. "/selection.png", 16, 16))
    local loaded = History.load(reopened, path, restored)
    assert(loaded and E.undo(reopened, restored) and
           E.redo(reopened, restored),
           "Histórico após reabertura não restaurou flip e máscara")
    History.cleanup(path)
    assert(love.filesystem.remove(path .. "/layer_1.png"))
    assert(love.filesystem.remove(path .. "/selection.png"))
    assert(love.filesystem.remove(path))
end

local function test_clipboard_transform(E)
    local Selection = require("lua_selection")
    checkpoint("before clipboard")
    -- Transformações ortogonais e clipboard INTERNO em Lua.
    local copy_project = E.new(16, 16)
    E.sync(copy_project, {layers = {{id = 1, visible = true, opacity = 100}}})
    local copy_layer = copy_project.layers[1]
    copy_layer.pixels:setPixel(2, 2, 1, 0, 0, 0.5)
    copy_layer.pixels:setPixel(3, 3, 0, 1, 0, 1)
    copy_layer.pixels:setPixel(8, 8, 0, 0, 1, 1)
    local copied_mask = assert(Selection.rectangle(16, 16, 2, 2, 3, 3))
    local copied = assert(E.copy_selection(copy_project, 1, copied_mask))
    assert(copied.w == 2 and copied.h == 2 and copied.mask[0] and copied.mask[3])
    -- O clipboard não deve referenciar pixels mutáveis da camada original.
    copy_layer.pixels:setPixel(2, 2, 0, 0, 0, 0)
    local frozen_red, _, _, frozen_a = copied.pixels:getPixel(0, 0)
    assert(frozen_red > 0.99 and close(frozen_a, 0.5),
        "Copy não congelou os pixels da máscara")
    checkpoint("before cut")
    local cut_ok, cut_clip = E.cut_selection(copy_project, 1, copied_mask)
    assert(cut_ok and cut_clip, "Cut da seleção não retornou clipboard")
    local _, _, _, cut_alpha = copy_layer.pixels:getPixel(3, 3)
    assert(cut_alpha == 0, "Cut não limpou os pixels selecionados")
    assert(E.undo(copy_project, copied_mask), "Cut não pôde ser desfeito")
    local _, restored_green = copy_layer.pixels:getPixel(3, 3)
    assert(restored_green > 0.99, "Undo do Cut não restaurou pixels")
    assert(E.redo(copy_project, copied_mask), "Cut não pôde ser refeito")
    checkpoint("before paste")
    local paste_ok, pasted = E.paste_selection(copy_project, 1, copied, 8, 8, copied_mask)
    assert(paste_ok and pasted == copied_mask, "Paste não preservou objeto seleção")
    assert(Selection.contains(copied_mask, 8, 8) and
       not Selection.contains(copied_mask, 2, 2),
       "Paste não selecionou novos pixels")
    local combined_red, combined_green, combined_blue, combined_a =
        copy_layer.pixels:getPixel(8, 8)
    assert(close(combined_red, 0.5) and close(combined_green, 0) and
           close(combined_blue, 0.5) and close(combined_a, 1),
           "Paste RGBA source-over incorreto")
    assert(E.undo(copy_project, copied_mask), "Paste sem undo")
    local undo_r, _, undo_b = copy_layer.pixels:getPixel(8, 8)
    assert(undo_r < 0.01 and undo_b > 0.99 and
        Selection.contains(copied_mask, 2, 2), "Undo do Paste falhou")
    assert(E.redo(copy_project, copied_mask), "Paste sem redo")
    assert(Selection.contains(copied_mask, 8, 8) and
           select(1, copy_layer.pixels:getPixel(8, 8)) > 0.4,
           "Redo do Paste falhou")
    local rejected_paste, paste_reason =
        E.paste_selection(copy_project, 1, copied, 15, 15, copied_mask)
    assert(not rejected_paste and paste_reason, "Paste na borda deveria falhar")
    local after_reject = select(1, copy_layer.pixels:getPixel(8, 8))
    assert(after_reject > 0.4, "Paste inválido modificou imagem")

    checkpoint("before rotate")
    local rotate_project = E.new(16, 16)
    E.sync(rotate_project, {layers = {{id = 1, visible = true, opacity = 100}}})
    local rotated_layer = rotate_project.layers[1]
    rotated_layer.pixels:setPixel(2, 2, 1, 0, 0, 1)
    rotated_layer.pixels:setPixel(3, 4, 0, 0, 1, 1)
    local shape = assert(Selection.rectangle(16, 16, 2, 2, 3, 4))
    assert(E.reshape_selection(rotate_project, 1, shape, "rotate_cw"),
        "Rotação horária de 90 graus falhou")
    assert(shape.max_x == 4 and shape.max_y == 3,
        "Rotação não atualizou dimensões da máscara")
    local moved_red = select(1, rotated_layer.pixels:getPixel(4, 2))
    local _, _, moved_blue = rotated_layer.pixels:getPixel(2, 3)
    assert(moved_red > 0.99 and moved_blue > 0.99,
        "Rotação horária posicionou pixels incorretamente")
    assert(E.undo(rotate_project, shape), "Rotação sem undo")
    assert(shape.max_x == 3 and shape.max_y == 4 and
           select(1, rotated_layer.pixels:getPixel(2, 2)) > 0.99,
           "Undo da rotação não restaurou geometria e pixels")
    assert(E.redo(rotate_project, shape), "Rotação sem redo")
    assert(shape.max_x == 4 and shape.max_y == 3 and
        select(1, rotated_layer.pixels:getPixel(4, 2)) > 0.99,
        "Redo da rotação não restaurou geometria e pixels")
    assert(E.reshape_selection(rotate_project, 1, shape, "rotate_ccw"),
           "Rotação anti-horária falhou")
    assert(shape.max_x == 3 and shape.max_y == 4 and
           select(1, rotated_layer.pixels:getPixel(2, 2)) > 0.99,
           "Rotação inversa não restaurou o desenho")

    checkpoint("before double")
    assert(E.reshape_selection(rotate_project, 1, shape, "scale_double"),
        "Escala 200% falhou")
    assert(shape.max_x == 5 and shape.max_y == 7,
        "Escala 200% não atualizou a máscara")
    assert(select(1, rotated_layer.pixels:getPixel(2, 2)) > 0.99 and
           select(1, rotated_layer.pixels:getPixel(3, 3)) > 0.99,
           "Escala nearest-neighbour não duplicou pixels")
    assert(E.reshape_selection(rotate_project, 1, shape, "scale_half"),
           "Escala 50% falhou")
    assert(shape.max_x == 3 and shape.max_y == 4,
        "Redução não restaurou as dimensões anteriores")
    local edge_mask = assert(Selection.rectangle(16, 16, 14, 14, 15, 15))
    local before_count = #rotate_project.undo
    local edge_ok, edge_reason =
        E.reshape_selection(rotate_project, 1, edge_mask, "scale_double")
    assert(not edge_ok and edge_reason and #rotate_project.undo == before_count,
        "Escala fora do canvas deveria falhar sem histórico novo")
    local selection_snapshot = Selection.clone(shape)
    Selection.translate(shape, 1, 0)
    Selection.restore(shape, selection_snapshot)
    assert(shape.min_x == selection_snapshot.min_x and
           shape.max_x == selection_snapshot.max_x,
           "Snapshot de seleção não restaurou posição")

end

-- Roundtrip real: máscara criada pela UI, salva em PNG, reaberta e removida.
local function test_selection_roundtrip(Bridge, model, id)
    local Selection = require("lua_selection")
    local before = assert(Bridge.selection_snapshot(),
        "A ponte perdeu a seleção antes do salvamento")
    assert(before.count > 0 and Bridge.save(),
        "Seleção ativa não pôde ser salva")
    local index = assert(love.filesystem.read("lua-artworks/index.tsv"))
    local key = assert(index:match("(art_%d+_%d+)\t16\t16\tSelection test"),
        "Obra de teste de seleção não entrou no índice")
    local path = "lua-artworks/" .. key
    local file = path .. "/selection.png"
    assert(love.filesystem.getInfo(file), "Máscara PNG não foi criada")
    local direct = assert(Selection.load(file, 16, 16))
    assert(direct.count == before.count, "PNG alterou a área selecionada")
    for k in pairs(before.mask) do
        assert(direct.mask[k], "PNG não preservou um pixel da seleção")
    end

    Bridge.open(model, id)
    local after = assert(Bridge.selection_snapshot(),
        "Seleção não voltou ao reabrir a obra")
    assert(after.count == before.count, "Contagem da seleção restaurada divergiu")
    for k in pairs(before.mask) do
        assert(after.mask[k], "Reabertura não restaurou geometria da seleção")
    end

    Bridge.clear_selection()
    assert(Bridge.save(), "Não foi possível salvar após desmarcar")
    assert(not love.filesystem.getInfo(file),
        "Seleção desmarcada deixou máscara PNG obsoleta")
    Bridge.open(model, id)
    assert(not Bridge.selection_snapshot(),
        "Seleção desmarcada reapareceu ao reabrir")

    -- Arquivo inválido ou de outro tamanho não bloqueia a abertura das camadas.
    assert(love.filesystem.write(file, "broken selection png"))
    local invalid, reason = Selection.load(file, 16, 16)
    assert(not invalid and reason, "Arquivo inválido não foi rejeitado")
    Bridge.open(model, id)
    assert(not Bridge.selection_snapshot(),
        "PNG inválido gerou uma seleção falsa")
    local wrong = love.image.newImageData(2, 2)
    wrong:setPixel(0, 0, 1, 1, 1, 1)
    wrong:encode("png", file)
    local mismatch, mismatch_reason = Selection.load(file, 16, 16)
    assert(not mismatch and mismatch_reason,
        "Seleção com dimensões erradas não foi rejeitada")
    Bridge.open(model, id)
    assert(not Bridge.selection_snapshot(),
        "Máscara de dimensões erradas foi importada")
    local oversized, oversized_reason =
        Selection.from_mask(1025, 1025, {[0] = true}, "oversized")
    assert(not oversized and oversized_reason,
        "Seleção excedente não respeitou limite raster")
    assert(love.filesystem.remove(file))
    require("lua_history").cleanup(path)
    require("lua_selection_history").cleanup(path)
    for _, filename in ipairs({"layer_1.png", "preview.png", "layers.tsv",
                               "document.tsv"}) do
        assert(love.filesystem.remove(path .. "/" .. filename))
    end
    assert(love.filesystem.remove(path))
end

-- Histórico separado dos pixels salvos: undo/redo, duas camadas,
-- geometria da seleção e rejeição de manifesto/snapshot corrompidos.
local function test_history_roundtrip(E)
    local History = require("lua_history")
    local Selection = require("lua_selection")
    local path = "lua-history-tests"
    assert(love.filesystem.createDirectory(path))
    local model = {layers = {
        {id = 1, visible = true, opacity = 100},
        {id = 2, visible = true, opacity = 100}
    }}
    local p = E.new(16, 16)
    E.sync(p, model)
    E.begin_stroke(p, 1)
    p.layers[1].pixels:setPixel(2, 2, 1, 0, 0, 1)
    p.layers[1].image:replacePixels(p.layers[1].pixels)
    E.begin_stroke(p, 2)
    p.layers[2].pixels:setPixel(6, 6, 0, 0, 1, 1)
    p.layers[2].image:replacePixels(p.layers[2].pixels)
    local selection = assert(Selection.rectangle(16, 16, 2, 2, 3, 3))
    assert(E.move_selection(p, 1, selection, 3, 0))
    assert(E.undo(p, selection), "Move não criou redo")
    assert(#p.undo == 2 and #p.redo == 1,
        "Pré-condições de histórico multicamada inválidas")
    for id = 1, 2 do
        p.layers[id].pixels:encode("png", path .. "/layer_" .. id .. ".png")
    end
    assert(Selection.save(selection, path .. "/selection.png"))
    local saved, count = History.save(p, path, selection)
    assert(saved and count == 3 and love.filesystem.getInfo(path .. "/history.tsv"),
        "Falha ao criar histórico separado com 3 snapshots")

    local reopened = E.new(16, 16)
    E.sync(reopened, model)
    for id = 1, 2 do
        assert(E.load_layer(reopened, id, path .. "/layer_" .. id .. ".png"))
    end
    local reopened_selection = assert(Selection.load(path .. "/selection.png", 16, 16))
    local loaded, restored = History.load(reopened, path, reopened_selection)
    assert(loaded and restored == 3 and #reopened.undo == 2 and
           #reopened.redo == 1, "Histórico não restaurou duas pilhas")
    assert(E.redo(reopened, reopened_selection),
        "Redo após reabrir não moveu pixels")
    assert(Selection.contains(reopened_selection, 5, 2) and
           select(1, reopened.layers[1].pixels:getPixel(5, 2)) > 0.99,
        "Redo da transformação não restaurou máscara e pixels")
    assert(E.undo(reopened, reopened_selection),
        "Undo após reabrir não voltou os pixels")
    assert(Selection.contains(reopened_selection, 2, 2) and
           select(1, reopened.layers[1].pixels:getPixel(2, 2)) > 0.99,
        "Undo após reabrir não restaurou contorno")
    assert(E.undo(reopened, reopened_selection),
        "Undo da segunda camada após reabrir falhou")
    local _, _, _, empty_blue = reopened.layers[2].pixels:getPixel(6, 6)
    assert(empty_blue == 0, "Histórico da outra camada não foi aplicado")
    assert(E.redo(reopened, reopened_selection))
    assert(select(3, reopened.layers[2].pixels:getPixel(6, 6)) > 0.99,
        "Redo da segunda camada falhou")

    -- Sem histórico, obras antigas abrem com pilhas vazias.
    local missing = E.new(16, 16)
    E.sync(missing, model)
    local untrusted = love.filesystem.read(path .. "/history.tsv")
    assert(untrusted and #untrusted > 20)
    assert(love.filesystem.remove(path .. "/history.tsv"))
    assert(not History.load(missing, path, reopened_selection)
       and #missing.undo == 0 and #missing.redo == 0,
       "Projeto sem histórico não deveria gerar passos")
    assert(love.filesystem.write(path .. "/history.tsv", "corrupt\nmanifest"))
    assert(not History.load(missing, path, reopened_selection)
       and #missing.undo == 0 and #missing.redo == 0,
       "Manifesto corrompido deveria ser ignorado")
    assert(love.filesystem.write(path .. "/history.tsv", untrusted))
    local gen = assert(untrusted:match("^IBIS_LUA_HISTORY_V1\t16\t16\t(%d+_%d+)"))
    local png = path .. "/history_" .. gen .. "_redo_1.png"
    assert(love.filesystem.getInfo(png))
    assert(love.filesystem.remove(png))
    assert(not History.load(missing, path, reopened_selection)
       and #missing.undo == 0 and #missing.redo == 0,
       "Snapshot ausente não deve permitir histórico parcial")
    assert(History.save(p, path, selection))
    local bad = "IBIS_LUA_HISTORY_V1\t16\t16\t../../outside\nundo\t1\t1\t0"
    assert(love.filesystem.write(path .. "/history.tsv", bad))
    assert(not History.load(missing, path, reopened_selection),
        "Manifesto com caminho malicioso não foi rejeitado")

    -- Remover uma camada não pode bloquear salvamento de outros passos.
    p.layers[2] = nil
    assert(History.save(p, path, selection))
    local filtered = E.new(16, 16)
    E.sync(filtered, {layers = {model.layers[1]}})
    assert(History.load(filtered, path, selection),
        "Histórico com camada removida não foi filtrado")

    -- Ausência de passos deve apagar o histórico anterior do disco.
    local empty = E.new(16, 16)
    E.sync(empty, model)
    assert(History.save(empty, path, nil))
    assert(not love.filesystem.getInfo(path .. "/history.tsv"),
        "Histórico antigo reapareceria em obra sem snapshots")
    History.cleanup(path)
    for id = 1, 2 do
        assert(love.filesystem.remove(path .. "/layer_" .. id .. ".png"))
    end
    assert(love.filesystem.remove(path .. "/selection.png"))
    assert(love.filesystem.remove(path))
end

-- Rotação livre e escalas não uniformes (incluindo rejeição atômica).
local function test_affine_transforms(E)
    local Selection = require("lua_selection")
    local model = {layers = {{id = 1, visible = true, opacity = 100}}}
    local p = E.new(64, 64)
    E.sync(p, model)
    local layer = p.layers[1]
    layer.pixels:setPixel(11, 11, 1, 0, 0, 1)
    layer.pixels:setPixel(16, 12, 0, 0, 1, 0.5)
    layer.pixels:setPixel(35, 35, 0, 1, 0, 1)
    layer.image:replacePixels(layer.pixels)

    local shape = assert(Selection.rectangle(64, 64, 10, 10, 17, 13))
    local original = Selection.clone(shape)
    assert(E.affine_selection(p, 1, shape, 30, 1, 1),
        "Rotação livre em 30 graus não foi aplicada")
    assert(shape.count > 0 and
           (shape.min_x ~= original.min_x or shape.min_y ~= original.min_y
            or shape.max_x ~= original.max_x or shape.max_y ~= original.max_y),
        "Rotação 30 graus não alterou a máscara raster")
    local _, green, _, alpha = layer.pixels:getPixel(35, 35)
    assert(green > 0.99 and alpha > 0.99,
        "Rotação alterou pixels fora da máscara")
    local transformed = Selection.clone(shape)
    local count_red, count_blue = 0, 0
    for y = shape.min_y, shape.max_y do
        for x = shape.min_x, shape.max_x do
            if Selection.contains(shape, x, y) then
                local r, _, b, a = layer.pixels:getPixel(x, y)
                if r > 0.9 and a > 0.9 then count_red = count_red + 1 end
                if b > 0.9 and a > 0.4 then count_blue = count_blue + 1 end
            end
        end
    end
    assert(count_red > 0 and count_blue > 0,
        "Rotação não reposicionou os pixels RGBA escolhidos")
    assert(E.undo(p, shape), "Undo de rotação livre falhou")
    assert(shape.min_x == original.min_x and shape.max_y == original.max_y and
        select(1, layer.pixels:getPixel(11, 11)) > 0.99,
        "Undo não restaurou máscara e imagem originais")
    assert(E.redo(p, shape), "Redo de rotação livre falhou")
    assert(shape.count == transformed.count and
        shape.min_x == transformed.min_x and shape.max_x == transformed.max_x,
        "Redo não restaurou a geometria livre")

    local p2 = E.new(64, 64)
    E.sync(p2, model)
    local layer2 = p2.layers[1]
    layer2.pixels:setPixel(24, 24, 0.3, 0.6, 0.9, 0.8)
    layer2.pixels:setPixel(50, 50, 1, 0, 1, 1)
    layer2.image:replacePixels(layer2.pixels)
    local area = assert(Selection.rectangle(64, 64, 20, 20, 27, 27))
    local initial = Selection.clone(area)
    assert(E.affine_selection(p2, 1, area, 0, 1.5, 0.75),
        "Escala X=150% Y=75% não foi aplicada")
    assert(area.min_x == 18 and area.max_x == 29 and
           area.min_y == 21 and area.max_y == 26,
        "Dimensões da escala não uniforme estão incorretas")
    local _, _, _, untouched = layer2.pixels:getPixel(50, 50)
    assert(untouched > 0.99, "Escala alterou pixel fora da seleção")
    local cx_r, cx_g, cx_b, cx_a = layer2.pixels:getPixel(24, 24)
    assert(cx_r > 0.25 and cx_g > 0.55 and cx_b > 0.85 and cx_a > 0.75,
        "Escala alterou indevidamente cor/alfa do pixel central")
    assert(E.undo(p2, area) and area.min_x == initial.min_x and
           area.max_x == initial.max_x, "Undo escala livre falhou")
    assert(E.redo(p2, area) and area.min_x == 18 and area.max_x == 29,
           "Redo escala livre falhou")

    -- Combinação arbitrária de giro e escalas independentes.
    assert(E.affine_selection(p2, 1, area, -27.5, 1.1, 1.2),
           "Transformação combinada não foi aceita")
    local count_after = #p2.undo
    local saved = Selection.clone(area)
    local saved_pixel = {layer2.pixels:getPixel(50, 50)}
    for _, args in ipairs({
        {math.huge, 1, 1}, {0, 0, 1}, {0, 9, 1}, {0, 1, 0 / 0}
    }) do
        local ok = E.affine_selection(p2, 1, area, args[1], args[2], args[3])
        assert(not ok and #p2.undo == count_after and
               area.count == saved.count and area.min_x == saved.min_x,
               "Parâmetros inválidos modificaram seleção ou histórico")
    end
    local sr, sg, sb, sa = layer2.pixels:getPixel(50, 50)
    assert(close(sr, saved_pixel[1]) and close(sg, saved_pixel[2]) and
           close(sb, saved_pixel[3]) and close(sa, saved_pixel[4]),
           "Parâmetros inválidos modificaram pixel não selecionado")

    local edge = assert(Selection.rectangle(64, 64, 61, 61, 63, 63))
    local before_count = #p2.undo
    local rejected, reason = E.affine_selection(p2, 1, edge, 0, 2, 2)
    assert(not rejected and reason and #p2.undo == before_count and
           edge.min_x == 61 and edge.max_x == 63,
           "Transformação além do canvas não foi rejeitada antes de escrever")
    local same, same_reason = E.affine_selection(p2, 1, edge, 0, 1, 1)
    assert(not same and same_reason and #p2.undo == before_count,
           "Transformação identidade não deveria gerar histórico")
end

-- Interpolação bilinear em RGB pré-multiplicado e paridade preview/commit.
local function test_bilinear_preview(E)
    local Selection = require("lua_selection")
    local p = E.new(32, 32)
    E.sync(p, {layers = {{id = 1, visible = true, opacity = 100}}})
    local layer = p.layers[1]
    layer.pixels:setPixel(12, 12, 1, 0, 0, 1)
    layer.pixels:setPixel(13, 12, 0, 0, 1, 1)
    -- RGB de pixels transparentes fora da máscara não pode criar halo.
    layer.pixels:setPixel(11, 12, 0, 1, 0, 0)
    layer.image:replacePixels(layer.pixels)
    p.dirty = false
    local area = assert(Selection.rectangle(32, 32, 12, 12, 15, 15))
    local initial = Selection.clone(area)
    local preview = assert(E.preview_affine(p, 1, area,
                                           15, 1.5, 1.2, "bilinear"))
    assert(preview.image and preview.selection.count > 0 and
           preview.pixels ~= layer.pixels, "Prévia não criou imagem independente")
    assert(#p.undo == 0 and #p.redo == 0 and p.dirty == false and
           Selection.contains(area, 12, 12),
           "Prévia modificou histórico, dirty ou seleção original")
    assert(select(1, layer.pixels:getPixel(12, 12)) > 0.99 and
           select(4, layer.pixels:getPixel(11, 12)) == 0,
           "Prévia modificou os pixels da camada original")

    local mixed = false
    for y = preview.selection.min_y, preview.selection.max_y do
        for x = preview.selection.min_x, preview.selection.max_x do
            if Selection.contains(preview.selection, x, y) then
                local red, green, blue, alpha = preview.pixels:getPixel(x, y)
                assert(green < 0.01, "Bilinear vazou RGB transparente não selecionado")
                if red > 0.1 and blue > 0.1 and alpha > 0.1 then
                    mixed = true
                end
            end
        end
    end
    assert(mixed, "Bilinear não interpolou cores adjacentes")

    local expected = preview.pixels
    local saved_mask = Selection.clone(preview.selection)
    assert(E.affine_selection(p, 1, area, 15, 1.5, 1.2, "bilinear"),
        "Commit bilinear recusou parâmetros válidos")
    for y = 0, 31 do
        for x = 0, 31 do
            local ar, ag, ab, aa = layer.pixels:getPixel(x, y)
            local er, eg, eb, ea = expected:getPixel(x, y)
            assert(close(ar, er, 1 / 255) and close(ag, eg, 1 / 255) and
                   close(ab, eb, 1 / 255) and close(aa, ea, 1 / 255),
                   "Prévia e pixels finais divergiram")
        end
    end
    assert(area.count == saved_mask.count and
           area.min_x == saved_mask.min_x and area.max_y == saved_mask.max_y,
           "Prévia e seleção final divergiram")
    assert(#p.undo == 1 and p.dirty and E.undo(p, area),
           "Commit bilinear não gerou exatamente um passo de histórico")
    assert(area.count == initial.count and
           layer.pixels:getPixel(12, 12) > 0.99,
           "Undo bilinear não restaurou imagem e seleção")
    assert(E.redo(p, area) and area.count == saved_mask.count,
           "Redo bilinear não restaurou geometria")
    preview.image:release()

    local edge = assert(Selection.rectangle(32, 32, 30, 30, 31, 31))
    local before = #p.undo
    local invalid, err = E.preview_affine(p, 1, edge, 45, 2, 2, "bilinear")
    assert(not invalid and err and #p.undo == before,
           "Prévia fora do canvas deveria ser recusada sem alterar histórico")
    local unknown = E.preview_affine(p, 1, edge, 0, 1.5, 1.5, "cubic")
    assert(not unknown, "Filtro desconhecido foi aceito")
end

-- Prévia GPU afim reaproveita máscaras/texturas; commit CPU mantém paridade.
local function test_affine_gpu_preview(E)
    local Selection = require("lua_selection")
    local model = {layers = {{id = 1, visible = true, opacity = 100}}}
    local p = E.new(64, 64)
    E.sync(p, model)
    local layer = p.layers[1]
    -- Bordas transparentes coloridas e amostras semitransparentes.
    layer.pixels:setPixel(24, 24, 1, 0, 0, 0.55)
    layer.pixels:setPixel(25, 24, 0, 0, 1, 1)
    layer.pixels:setPixel(23, 24, 0, 1, 0, 0)
    layer.pixels:setPixel(29, 29, 0.3, 0.6, 0.9, 0.7)
    layer.pixels:setPixel(35, 35, 0.2, 0.9, 0.3, 1)
    layer.image:replacePixels(layer.pixels)
    p.dirty = false
    local mask = assert(Selection.rectangle(64, 64, 20, 20, 31, 31))
    local initial = Selection.clone(mask)
    local preview = assert(E.begin_affine_gpu_preview(p, 1, mask))
    assert(preview.kind == "affine_gpu" and preview.image and
           preview.mask_image and preview.renders == 0 and not preview.active,
           "Prévia afim GPU não criou texturas uma vez")
    local cache_canvas, cache_mask = preview.image, preview.mask_image
    assert(E.update_affine_gpu_preview(p, mask, preview, 30, 1.35, 0.85),
           "GPU não renderizou rotação livre com escala anisotrópica")
    assert(preview.active and preview.renders == 1 and
           not p.dirty and #p.undo == 0 and #p.redo == 0 and
           Selection.contains(mask, 24, 24) and
           select(1, layer.pixels:getPixel(24, 24)) > 0.9,
           "Prévia GPU alterou o estado original do projeto")
    assert(E.update_affine_gpu_preview(p, mask, preview, 30, 1.35, 0.85))
    assert(preview.renders == 1 and preview.image == cache_canvas and
           preview.mask_image == cache_mask,
           "Mesmo parâmetro deveria reutilizar cache sem renderizar")
    local expected = preview.image:newImageData()
    assert(E.affine_selection(p, 1, mask, 30, 1.35, 0.85, "bilinear"),
           "Commit bilinear de controle não executou")
    local max_difference = 0
    local changed_pixels = 0
    for y = 0, 63 do
        for x = 0, 63 do
            local cr, cg, cb, ca = layer.pixels:getPixel(x, y)
            local pr, pg, pb, pa = expected:getPixel(x, y)
            max_difference = math.max(max_difference,
                math.abs(ca - pa), math.abs(cr * ca - pr * pa),
                math.abs(cg * ca - pg * pa), math.abs(cb * ca - pb * pa))
            if ca > 0.05 or pa > 0.05 then
                changed_pixels = changed_pixels + 1
            end
        end
    end
    assert(changed_pixels > 5 and max_difference < 0.045,
        string.format("Shader afim/CPU divergiram em RGBA: %.4f",
            max_difference))
    assert(#p.undo == 1 and p.dirty and mask.count > 0,
           "Commit afim não gerou histórico após prévia")
    assert(E.undo(p, mask) and mask.count == initial.count,
           "Undo após prévia afim não restaurou seleção")
    assert(E.redo(p, mask), "Redo após prévia afim falhou")

    -- O mesmo Canvas GPU deve ser reutilizado com novos parâmetros.
    assert(E.update_affine_gpu_preview(p, initial, preview, -17.5, 1, 1))
    assert(preview.active and preview.renders == 2 and
           preview.image == cache_canvas and preview.mask_image == cache_mask,
           "Mudança angular recriou recursos da GPU")
    local old_renders = preview.renders
    local invalid, reason = E.update_affine_gpu_preview(p, initial, preview,
                                                         math.huge, 1, 1)
    assert(not invalid and reason and not preview.active and
           preview.renders == old_renders,
           "Prévia inválida deveria ser desativada sem novo render")
    assert(E.update_affine_gpu_preview(p, initial, preview, 30, 1, 1),
           "Prévia não voltou após rejeição de parâmetros")

    preview.image:release()
    preview.mask_image:release()

    local edge = assert(Selection.rectangle(64, 64, 60, 60, 63, 63))
    local at_edge = assert(E.begin_affine_gpu_preview(p, 1, edge))
    local before = #p.undo
    local ok, err = E.update_affine_gpu_preview(p, edge, at_edge, 30, 2, 2)
    assert(not ok and err and #p.undo == before and
           edge.min_x == 60 and not at_edge.active,
           "Prévia perto da borda deveria rejeitar sem tocar a obra")
    at_edge.image:release()
    at_edge.mask_image:release()
end

-- Prévia de deslocamento usa GPU + máscara criada só uma vez por gesto.
local function test_move_preview_engine(E)
    local Selection = require("lua_selection")
    local model = {layers = {{id = 1, visible = true, opacity = 100}}}
    local p = E.new(16, 16)
    E.sync(p, model)
    local layer = p.layers[1]
    layer.pixels:setPixel(4, 4, 1, 0, 0, 0.5)
    layer.pixels:setPixel(5, 4, 0, 0, 1, 1)
    layer.pixels:setPixel(6, 4, 0, 1, 0, 1)
    layer.image:replacePixels(layer.pixels)
    p.dirty = false
    local mask = assert(Selection.rectangle(16, 16, 4, 4, 5, 5))
    local original = Selection.clone(mask)
    local preview = assert(E.begin_move_preview(p, 1, mask))
    assert(preview.image and preview.mask_image and preview.renders == 0
        and not preview.active and not p.dirty and #p.undo == 0)
    assert(E.update_move_preview(p, mask, preview, 2, 0))
    assert(preview.active and preview.dx == 2 and preview.dy == 0 and
           preview.renders == 1, "Prévia GPU não renderizou movimento")
    local gpu_first = preview.image:newImageData()
    local red, green, blue, alpha = gpu_first:getPixel(6, 4)
    assert(close(red, 0.5, 0.025) and close(green, 0.5, 0.025) and
           close(blue, 0, 0.025) and close(alpha, 1, 0.025),
           "Prévia RGBA source-over não corresponde ao destino")
    local _, _, _, src_a = gpu_first:getPixel(4, 4)
    assert(src_a < 0.01, "Prévia não limpou a origem selecionada")
    assert(not p.dirty and #p.undo == 0 and
           Selection.contains(mask, 4, 4) and
           select(1, layer.pixels:getPixel(4, 4)) > 0.9,
           "Prévia alterou a seleção, a camada ou o histórico")

    local old_image, old_mask = preview.image, preview.mask_image
    assert(E.update_move_preview(p, mask, preview, 2.2, 0.1))
    assert(preview.renders == 1 and preview.image == old_image and
           preview.mask_image == old_mask,
           "Delta fracionário não deveria recriar textura nem renderizar")
    assert(E.update_move_preview(p, mask, preview, 3, 0))
    assert(preview.renders == 2 and preview.image == old_image and
           preview.mask_image == old_mask,
           "Prévias sucessivas devem reutilizar máscara e Canvas")
    assert(E.update_move_preview(p, mask, preview, 2, 0))
    assert(preview.renders == 3 and preview.dx == 2)
    local gpu_final = preview.image:newImageData()
    assert(E.move_selection(p, 1, mask, 2, 0),
           "Movimento CPU não confirmou a posição da prévia")
    for y = 0, 15 do
        for x = 0, 15 do
            local ar, ag, ab, aa = layer.pixels:getPixel(x, y)
            local er, eg, eb, ea = gpu_final:getPixel(x, y)
            if aa > 0.01 or ea > 0.01 then
                assert(close(ar, er, 0.025) and close(ag, eg, 0.025) and
                       close(ab, eb, 0.025) and close(aa, ea, 0.025),
                       "Preview GPU e commit CPU divergiram")
            else
                assert(aa < 0.01 and ea < 0.01)
            end
        end
    end
    assert(mask.min_x == original.min_x + 2 and #p.undo == 1,
           "Movimento não gerou um único passo de histórico")
    assert(E.undo(p, mask) and mask.min_x == original.min_x,
           "Undo da prévia confirmada falhou")
    assert(E.redo(p, mask) and mask.min_x == original.min_x + 2,
           "Redo da prévia confirmada falhou")

    assert(E.update_move_preview(p, original, preview, 0, 0))
    assert(not preview.active and preview.renders == 3,
           "Retorno à posição original deve desativar preview sem render")
    preview.image:release()
    preview.mask_image:release()
end

-- Integra ponte real de mouse, tela, máscara e composição sem mutação.
local function test_move_preview_bridge(Bridge, gallery)
    local model = {
        screen = "editor", document = {width = 64, height = 64},
        layers = {{id = 1, visible = true, opacity = 100,
                   blending = "Normal", name = "Paint"}},
        active_layer_id = 1, active_tool = "brush",
        background_mode = "white"
    }
    function model:active_layer() return self.layers[1] end
    function model:set_color(r, g, b) self.color = {r, g, b} end
    local art = gallery:add_artwork(64, 64, "Move preview")
    Bridge.create(model, art, gallery)
    local view = {zoom = 10, rotation = 0, pan_x = 0, pan_y = 0}
    local prefs = {tool_position = "left"}
    local colors = {set_rgb = function() end}
    local function screen(x, y)
        return 62 + (1024 - 62 - 34) / 2 + (x + 0.5 - 32) * 11,
            62 + (768 - 160) / 2 + (y + 0.5 - 32) * 11
    end
    local function press(x, y, color, size)
        local mx, my = screen(x, y)
        assert(Bridge.mousepressed(model, art, mx, my, 1024, 768,
            view, prefs, color or {255, 0, 0}, size or 3, 100, colors))
    end
    local function release(x, y)
        local mx, my = screen(x, y)
        return Bridge.mousereleased(model, mx, my, 1)
    end
    press(30, 32)
    Bridge.mousereleased()
    model.active_tool = "transform"
    press(26, 26)
    assert(release(34, 38), "Seleção da ponte não foi criada")
    local original = assert(Bridge.selection_snapshot())
    press(30, 32)
    local sx, sy = screen(33, 34)
    assert(Bridge.mousemoved(model, sx, sy, 1),
           "Mousemoved da prévia não foi consumido")
    local draft = assert(Bridge.preview_snapshot(),
        "Arraste comum não criou prévia de movimento")
    assert(draft.kind == "move" and draft.active and draft.dx == 3
        and draft.dy == 2 and draft.renders == 1,
        "Prévia de arraste não guarda posição inteira")
    assert(draft.selection.min_x == original.min_x + 3 and
           draft.selection.min_y == original.min_y + 2 and
           Bridge.selection_snapshot().min_x == original.min_x,
        "Prévia moveu a máscara real antes da confirmação")

    local target = love.graphics.newCanvas(64, 64)
    love.graphics.push("all")
    love.graphics.setCanvas(target)
    love.graphics.clear(0, 0, 0, 0)
    love.graphics.translate(32, 32)
    Bridge.draw(model, {interpolation = "pixelated"})
    love.graphics.pop()
    local seen = target:newImageData()
    assert(select(1, seen:getPixel(33, 34)) > 0.9,
           "Renderer da ponte não mostra pintura no destino durante o arraste")
    local again_x, again_y = screen(33.05, 34.05)
    assert(Bridge.mousemoved(model, again_x, again_y, 1))
    local same = assert(Bridge.preview_snapshot())
    assert(same.renders == 1 and same.image == draft.image and
           same.mask_image == draft.mask_image,
           "Mouse em subpixel não deveria refazer Canvas/mascara")
    assert(release(33, 34), "Arraste simples não confirmou movimento")
    assert(not Bridge.preview_snapshot(), "Canvas de prévia não foi liberado")
    local moved = assert(Bridge.selection_snapshot())
    assert(moved.min_x == original.min_x + 3 and
           moved.min_y == original.min_y + 2)
    assert(Bridge.undo() and
           Bridge.selection_snapshot().min_x == original.min_x,
           "Undo do movimento não restaurou a seleção")
    assert(Bridge.redo() and
           Bridge.selection_snapshot().min_x == original.min_x + 3,
           "Redo do movimento não restaurou a seleção")
    -- Cancelar outra prévia (Ctrl+D/Esc) não pode aplicar movimento.
    press(33, 34)
    local new_x, new_y = screen(35, 35)
    Bridge.mousemoved(model, new_x, new_y, 1)
    assert(Bridge.preview_snapshot(), "Segunda prévia não surgiu")
    Bridge.clear_selection()
    assert(not Bridge.preview_snapshot() and not Bridge.selection_snapshot(),
           "Cancelamento não descartou máscara e recursos temporários")
end

-- Testa os gestos modificados no Bridge sem mexer nos botões existentes.
local function test_affine_bridge(Bridge, gallery)
    local model = {
        screen = "editor", document = {width = 64, height = 64},
        layers = {{id = 1, visible = true, opacity = 100,
                   blending = "Normal", name = "Paint"}},
        active_layer_id = 1, active_tool = "brush", background_mode = "white"
    }
    function model:active_layer() return self.layers[1] end
    function model:set_color(r, g, b) self.color = {r, g, b} end
    local id = gallery:add_artwork(64, 64, "Affine gestures")
    Bridge.create(model, id, gallery)
    local view = {zoom = 10, rotation = 0, pan_x = 0, pan_y = 0}
    local prefs = {tool_position = "left"}
    local function screen(x, y)
        return 62 + (1024 - 62 - 34) / 2 + (x + 0.5 - 32) * 11,
            62 + (768 - 160) / 2 + (y + 0.5 - 32) * 11
    end
    local function press(x, y)
        local mx, my = screen(x, y)
        assert(Bridge.mousepressed(model, id, mx, my, 1024, 768,
            view, prefs, {255, 0, 0}, 3, 100, nil))
    end
    local function release(x, y)
        local mx, my = screen(x, y)
        return Bridge.mousereleased(model, mx, my, 1)
    end
    press(30, 32)
    Bridge.mousereleased()
    model.active_tool = "transform"
    press(26, 26)
    assert(release(34, 38), "Transformar não construiu máscara de arraste")
    local selection = assert(Bridge.selection_snapshot())
    assert(selection.min_x == 26 and selection.max_x == 34 and
           selection.min_y == 26 and selection.max_y == 38,
           "Coordenadas de seleção da ponte incorretas")

    local native_is_down = love.keyboard.isDown
    love.keyboard.isDown = function(...)
        for i = 1, select("#", ...) do
            local key = select(i, ...)
            if key == "lalt" or key == "ralt" then return true end
        end
        return false
    end
    press(33, 32)
    love.keyboard.isDown = native_is_down
    local rx, ry = screen(30, 37)
    assert(Bridge.mousemoved(model, rx, ry, 1), "Prévia da rotação não consumiu gesto")
    local rotating_preview = assert(Bridge.preview_snapshot(),
        "Alt+arrastar não criou prévia antes de soltar")
    assert(rotating_preview.kind == "affine_gpu" and
           rotating_preview.active and rotating_preview.image and
           rotating_preview.mask_image and rotating_preview.renders == 1 and
           Bridge.selection_snapshot().min_x == selection.min_x,
           "Prévia GPU não surgiu ou mudou prematuramente a seleção")
    local same_rx, same_ry = screen(30, 37)
    assert(Bridge.mousemoved(model, same_rx, same_ry, 1))
    local same_rotation = assert(Bridge.preview_snapshot())
    assert(same_rotation.renders == 1 and
           same_rotation.image == rotating_preview.image and
           same_rotation.mask_image == rotating_preview.mask_image,
           "Rotação não reutilizou Canvas e máscara com mesmo ângulo")
    local preview_image = love.graphics.newCanvas(64, 64)
    love.graphics.push("all")
    love.graphics.setCanvas(preview_image)
    love.graphics.clear(0, 0, 0, 0)
    love.graphics.translate(32, 32)
    Bridge.draw(model, {interpolation = "pixelated"})
    love.graphics.pop()
    assert(Bridge.selection_snapshot().min_x == selection.min_x,
           "Renderização da prévia alterou a seleção real")
    assert(release(30, 37), "Alt+arrastar não aplicou rotação")
    assert(not Bridge.preview_snapshot(), "Prévia não foi liberada ao soltar")
    local rotated = assert(Bridge.selection_snapshot())
    assert(rotated.min_x ~= selection.min_x and rotated.count > 0,
        "Alt+arrastar não rotacionou a geometria da seleção")
    assert(Bridge.undo(), "Gesto de rotação não gerou undo")
    local undone = assert(Bridge.selection_snapshot())
    assert(undone.min_x == selection.min_x and undone.max_x == selection.max_x,
        "Undo do gesto não restaurou máscara")
    assert(Bridge.redo(), "Gesto de rotação não gerou redo")

    love.keyboard.isDown = function(...)
        for i = 1, select("#", ...) do
            local key = select(i, ...)
            if key == "lshift" or key == "rshift" then return true end
        end
        return false
    end
    press(33, 32)
    love.keyboard.isDown = native_is_down
    local sx, sy = screen(35, 34)
    assert(Bridge.mousemoved(model, sx, sy, 1), "Prévia da escala não consumiu gesto")
    local scaling_preview = assert(Bridge.preview_snapshot(),
        "Shift+arrastar não criou prévia antes de soltar")
    assert(Bridge.selection_snapshot().count == rotated.count,
           "Prévia da escala modificou a máscara antes de soltar")
    assert(release(35, 34), "Shift+arrastar não aplicou escala independente")
    local scaled = assert(Bridge.selection_snapshot())
    assert(scaling_preview.kind == "affine_gpu" and
           scaling_preview.active and scaling_preview.renders == 1 and
           not Bridge.preview_snapshot(), "Prévia GPU não foi liberada após escala")
    assert(scaled.count > rotated.count, "Escala livre não expandiu a seleção")
    assert(Bridge.undo(), "Gesto de escala não gerou undo")
    local restored = assert(Bridge.selection_snapshot())
    assert(restored.count == rotated.count and
           restored.min_x == rotated.min_x,
           "Undo escala do gesto não restaurou contorno")
    assert(Bridge.redo(), "Gesto de escala não gerou redo")
end

-- Eventos reais de teclado Ctrl+Shift+H/V, sem componentes novos.
local function test_flip_bridge(Bridge, gallery)
    local model = {
        screen = "editor", document = {width = 64, height = 64},
        layers = {{id = 1, visible = true, opacity = 100,
                   blending = "Normal", name = "Flip layer"}},
        active_layer_id = 1, active_tool = "brush",
        background_mode = "transparent_dark"
    }
    function model:active_layer() return self.layers[1] end
    local id = gallery:add_artwork(64, 64, "Mirror shortcuts")
    Bridge.create(model, id, gallery)
    local view = {zoom = 10, rotation = 0, pan_x = 0, pan_y = 0}
    local prefs = {tool_position = "left"}
    local function screen(x, y)
        return 62 + (1024 - 62 - 34) / 2 + (x + 0.5 - 32) * 11,
            62 + (768 - 160) / 2 + (y + 0.5 - 32) * 11
    end
    local function press(x, y)
        local mx, my = screen(x, y)
        assert(Bridge.mousepressed(model, id, mx, my, 1024, 768,
            view, prefs, {255, 0, 0}, 1, 100, nil))
    end
    local function release(x, y)
        local mx, my = screen(x, y)
        return Bridge.mousereleased(model, mx, my, 1)
    end
    local function rendered(x, y)
        local target = love.graphics.newCanvas(64, 64)
        love.graphics.push("all")
        love.graphics.setCanvas(target)
        love.graphics.clear(0, 0, 0, 0)
        love.graphics.translate(32, 32)
        Bridge.draw(model, {interpolation = "pixelated"})
        love.graphics.pop()
        local r, g, b, a = target:newImageData():getPixel(x, y)
        target:release()
        return r, g, b, a
    end
    local function shortcut(key)
        local old = love.keyboard.isDown
        love.keyboard.isDown = function(...)
            for i = 1, select("#", ...) do
                local named = select(i, ...)
                if named == "lctrl" or named == "lshift" then
                    return true
                end
            end
            return false
        end
        local consumed = Bridge.keypressed(key, model)
        love.keyboard.isDown = old
        return consumed
    end
    assert(not Bridge.selection_command(model, "flip_horizontal"),
        "Espelhamento sem seleção deveria falhar")
    press(28, 30)
    Bridge.mousereleased()
    local red, _, _, a = rendered(28, 30)
    assert(red > 0.9 and a > 0.9, "Pixel inicial não foi pintado")
    model.active_tool = "transform"
    press(26, 26)
    assert(release(34, 38), "Seleção da ponte não foi criada")
    assert(shortcut("h"), "Ctrl+Shift+H não foi interceptado")
    local right_r, _, _, right_a = rendered(32, 30)
    local _, _, _, left_a = rendered(28, 30)
    assert(right_r > 0.9 and right_a > 0.9 and left_a < 0.01,
           "Ctrl+Shift+H não inverteu o conteúdo selecionado")
    assert(shortcut("v"), "Ctrl+Shift+V não foi interceptado")
    local lower_r, _, _, lower_a = rendered(32, 34)
    local _, _, _, old_a = rendered(32, 30)
    assert(lower_r > 0.9 and lower_a > 0.9 and old_a < 0.01,
           "Ctrl+Shift+V não inverteu verticalmente o conteúdo")
    assert(Bridge.undo() and select(1, rendered(32, 30)) > 0.9,
           "Undo vertical da ponte falhou")
    assert(Bridge.undo() and select(1, rendered(28, 30)) > 0.9,
           "Undo horizontal da ponte falhou")
    assert(Bridge.redo() and select(1, rendered(32, 30)) > 0.9,
           "Redo horizontal da ponte falhou")
    assert(Bridge.redo() and select(1, rendered(32, 34)) > 0.9,
           "Redo vertical da ponte falhou")

    local warnings = 0
    local function notice() warnings = warnings + 1 end
    model.layers[1].locked = true
    assert(not Bridge.selection_command(model, "flip_horizontal", notice))
    model.layers[1].locked = false
    model.layers[1].alpha_lock = true
    assert(not Bridge.selection_command(model, "flip_vertical", notice))
    model.layers[1].alpha_lock = false
    assert(warnings == 2 and select(1, rendered(32, 34)) > 0.9,
           "Layer Lock/Alpha Lock não impediram espelhamento")
    Bridge.clear_selection()
    assert(not Bridge.selection_command(model, "flip_vertical"),
           "Espelhamento sem máscara foi aceito")
end

function love.load()
    checkpoint("begin")
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


    -- Alpha Lock: tinta não cria transparência, mantém alfa parcial e é reversível.
    local lock_project = E.new(16, 16)
    E.sync(lock_project, {layers = {{id = 1, visible = true, opacity = 100}}})
    local locked = lock_project.layers[1]
    locked.pixels:setPixel(4, 4, 0.2, 0.4, 0.6, 0.5)
    E.begin_stroke(lock_project, 1)
    E.stroke(lock_project, 1, 4.5, 4.5, 4.5, 4.5,
             3, {1, 0, 0}, 1, false, true)
    local lr, lg, lb, la = locked.pixels:getPixel(4, 4)
    assert(lr > 0.99 and lg < 0.01 and lb < 0.01 and close(la, 0.5),
           "Alpha Lock deve trocar RGB sem modificar alfa")
    local _, _, _, empty_a = locked.pixels:getPixel(5, 5)
    assert(empty_a < 0.01, "Alpha Lock criou pixels fora da área pintada")
    assert(E.undo(lock_project), "Alpha Lock não permite desfazer")
    local old_r, _, _, old_a = locked.pixels:getPixel(4, 4)
    assert(close(old_r, 0.2) and close(old_a, 0.5),
           "Undo do Alpha Lock não restaurou cor/alfa")
    assert(E.redo(lock_project), "Alpha Lock não permite refazer")

    -- O balde com Alpha Lock recolore apenas pixels existentes.
    assert(not E.fill(lock_project, 1, 0, 0, {0, 1, 0}, 1, true),
           "Balde Alpha Lock criou preenchimento sobre transparência")
    assert(E.fill(lock_project, 1, 4, 4, {0, 1, 0}, 1, true),
           "Balde Alpha Lock não alterou cor existente")
    local _, lock_green, _, lock_a = locked.pixels:getPixel(4, 4)
    assert(lock_green > 0.99 and close(lock_a, 0.5),
           "Balde Alpha Lock mudou alfa")
    assert(E.undo(lock_project), "Balde Alpha Lock não foi desfeito")

    -- Clipping conserva os pixels brutos; recorta a visualização à
    -- máscara alfa da camada-base, incluindo a opacidade da base.
    local clip_project = E.new(32, 32)
    local clip_model = {layers = {
        {id = 1, visible = true, opacity = 100, clipping = false},
        {id = 2, visible = true, opacity = 100, clipping = true}
    }}
    E.sync(clip_project, clip_model)
    clip_project.layers[1].pixels:setPixel(4, 4, 1, 0, 0, 0.5)
    clip_project.layers[2].pixels:setPixel(4, 4, 0, 0, 1, 1)
    clip_project.layers[2].pixels:setPixel(12, 12, 0, 0, 1, 1)
    for _, layer_id in ipairs({1, 2}) do
        local entry = clip_project.layers[layer_id]
        entry.image:replacePixels(entry.pixels)
    end
    local cl_r, cl_g, cl_b, cl_a = E.sample(clip_project, clip_model, 4, 4)
    assert(close(cl_r, 1 / 3) and close(cl_g, 0)
       and close(cl_b, 2 / 3) and close(cl_a, 0.75),
       "Clipping no conta-gotas não combina alfas corretamente")
    local _, _, _, outside = E.sample(clip_project, clip_model, 12, 12)
    assert(close(outside, 0), "Clipping não ocultou região sem base")
    local buffer = love.graphics.newCanvas(32, 32)
    love.graphics.push("all")
    love.graphics.setCanvas(buffer)
    love.graphics.clear(0, 0, 0, 0)
    love.graphics.translate(16, 16)
    E.draw(clip_project, clip_model, "pixelated")
    love.graphics.pop()
    local actual = buffer:newImageData()
    local gpu_r, _, gpu_b, gpu_a = actual:getPixel(4, 4)
    local _, _, _, gpu_out = actual:getPixel(12, 12)
    -- newCanvas:newImageData devolve RGB premultiplicado pelo alfa:
    -- o sample Lua devolve RGB straight. Compare no mesmo espaço.
    local straight_r = gpu_a > 0 and gpu_r / gpu_a or 0
    local straight_b = gpu_a > 0 and gpu_b / gpu_a or 0
    assert(close(straight_r, cl_r, 0.04)
       and close(straight_b, cl_b, 0.04)
       and close(gpu_a, cl_a, 0.04),
       string.format("Máscara GLSL/Lua divergente: GPU %.3f %.3f %.3f; CPU %.3f %.3f %.3f",
           straight_r, straight_b, gpu_a, cl_r, cl_b, cl_a))
    assert(gpu_out < 0.01, "Clipping do renderer exibiu pixels fora da máscara")
    clip_model.layers[1].visible = false
    local _, _, _, hidden = E.sample(clip_project, clip_model, 4, 4)
    assert(hidden < 0.01, "Camada-base invisível deve esconder a clipada")
    clip_model.layers[1].visible = true
    clip_model.layers[1].opacity = 50
    local _, _, _, faded = E.sample(clip_project, clip_model, 4, 4)
    assert(close(faded, 0.4375), "Clipping não respeitou opacidade da base")

    -- Modos existentes no Ibis-Lua: blend RGB CPU e GPU equivalentes.
    -- A base e o topo opacos tornam a verificação do canal vermelho exata.
    local blend_project = E.new(32, 32)
    local blend_model = {layers = {
        {id = 1, visible = true, opacity = 100, blending = "Normal"},
        {id = 2, visible = true, opacity = 100, blending = "Normal"}
    }}
    E.sync(blend_project, blend_model)
    blend_project.layers[1].pixels:setPixel(8, 8, 0.2, 0.4, 0.6, 1)
    blend_project.layers[2].pixels:setPixel(8, 8, 0.7, 0.3, 0.1, 1)
    for _, info in ipairs(blend_model.layers) do
        local entry = blend_project.layers[info.id]
        entry.image:replacePixels(entry.pixels)
    end
    local expected = {
        Normal = 0.7, Multiply = 0.14, Screen = 0.76,
        Overlay = 0.28, Darken = 0.2, Lighten = 0.7,
        ["Color Burn"] = 0, ["Color Dodge"] = 2 / 3,
        ["Soft Light"] = 0.2992
    }
    local checked = 0
    for mode, expected_red in pairs(expected) do
        blend_model.layers[2].blending = mode
        local cpu_r, _, _, cpu_a = E.sample(blend_project, blend_model, 8, 8)
        assert(close(cpu_r, expected_red, 0.025) and close(cpu_a, 1),
            "Fórmula Lua incorreta para " .. mode .. ": " .. tostring(cpu_r))
        local target = love.graphics.newCanvas(32, 32)
        love.graphics.push("all")
        love.graphics.setCanvas(target)
        love.graphics.clear(0, 0, 0, 0)
        love.graphics.translate(16, 16)
        E.draw(blend_project, blend_model, "pixelated")
        love.graphics.pop()
        local screen = target:newImageData()
        local gpu_r, _, _, gpu_a = screen:getPixel(8, 8)
        assert(close(gpu_r, cpu_r, 0.04) and close(gpu_a, cpu_a, 0.04),
            string.format("%s: shader e amostra Lua diferem: GPU %.3f / CPU %.3f",
                mode, gpu_r, cpu_r))
        checked = checked + 1
    end
    assert(checked == 9, "Nem todos os modos selecionáveis foram testados")

    -- Semitransparência nas duas camadas e clipping com blend não podem
    -- converter cores straight em premultiplicadas incorretamente.
    blend_project.layers[1].pixels:setPixel(12, 12, 0.2, 0.4, 0.6, 0.65)
    blend_project.layers[2].pixels:setPixel(12, 12, 0.7, 0.3, 0.1, 0.8)
    for _, info in ipairs(blend_model.layers) do
        local entry = blend_project.layers[info.id]
        entry.image:replacePixels(entry.pixels)
    end
    blend_model.layers[2].blending = "Overlay"
    blend_model.layers[2].clipping = true
    blend_model.layers[2].opacity = 70
    local cpu_r, cpu_g, cpu_b, cpu_a =
        E.sample(blend_project, blend_model, 12, 12)
    local target = love.graphics.newCanvas(32, 32)
    love.graphics.push("all")
    love.graphics.setCanvas(target)
    love.graphics.clear(0, 0, 0, 0)
    love.graphics.translate(16, 16)
    E.draw(blend_project, blend_model, "pixelated")
    love.graphics.pop()
    local gpu_r, gpu_g, gpu_b, gpu_a = target:newImageData():getPixel(12, 12)
    -- O framebuffer destino usa RGB pré-multiplicado pelo alpha.
    assert(close(gpu_a, cpu_a, 0.04) and
           close(gpu_r / gpu_a, cpu_r, 0.04) and
           close(gpu_g / gpu_a, cpu_g, 0.04) and
           close(gpu_b / gpu_a, cpu_b, 0.04),
           "Composição com clipping + overlay e alfa parcial divergiu")

    -- Seleção por área retangular, laço livre e varinha por cor contígua.
    local Selection = require("lua_selection")
    local rect = assert(Selection.rectangle(16, 16, 2, 2, 4, 4))
    assert(rect.count == 9 and Selection.contains(rect, 3, 3)
       and not Selection.contains(rect, 5, 5), "Seleção retangular incorreta")
    local poly = assert(Selection.lasso(16, 16, {
        {1, 1}, {11, 1}, {1, 11}
    }))
    assert(Selection.contains(poly, 2, 2)
       and not Selection.contains(poly, 12, 12), "Laço não obedeceu polígono")
    local wand = E.new(16, 16)
    E.sync(wand, {layers = {{id = 1, visible = true, opacity = 100}}})
    wand.layers[1].pixels:setPixel(1, 1, 1, 0, 0, 1)
    wand.layers[1].pixels:setPixel(2, 1, 1, 0, 0, 1)
    wand.layers[1].pixels:setPixel(7, 7, 1, 0, 0, 1)
    local contiguous = assert(Selection.magic_wand(wand.layers[1], 16, 16, 1, 1))
    assert(contiguous.count == 2 and Selection.contains(contiguous, 2, 1)
       and not Selection.contains(contiguous, 7, 7),
       "Varinha selecionou ilha desconectada")
    local too_large, rejected = Selection.rectangle(1025, 1025, 0, 0, 4, 4)
    assert(not too_large and rejected, "Faltou limite de tamanho da seleção")

    -- A seleção restringe pincel e balde à máscara (sem afetar outros pixels).
    local masked = E.new(16, 16)
    E.sync(masked, {layers = {{id = 1, visible = true, opacity = 100}}})
    local mask = assert(Selection.rectangle(16, 16, 0, 0, 3, 3))
    assert(E.fill(masked, 1, 0, 0, {0, 1, 0}, 1, false, mask),
        "Balde dentro da seleção falhou")
    local _, green_inside, _, alpha_inside = masked.layers[1].pixels:getPixel(2, 2)
    local _, _, _, alpha_outside = masked.layers[1].pixels:getPixel(4, 4)
    assert(green_inside > 0.99 and alpha_inside > 0.99
       and alpha_outside == 0, "Balde pintou fora da seleção")
    E.stroke(masked, 1, 3.5, 3.5, 6.5, 6.5, 7, {1, 0, 0}, 1,
             false, false, mask)
    local _, _, _, still_empty = masked.layers[1].pixels:getPixel(5, 5)
    assert(still_empty == 0, "Pincel ultrapassou a seleção")

    -- Mover conteúdo selecionado mantém pixels não selecionados e admite
    -- undo/redo, inclusive com a posição do contorno acompanhando os pixels.
    local move = E.new(16, 16)
    E.sync(move, {layers = {{id = 1, visible = true, opacity = 100}}})
    move.layers[1].pixels:setPixel(2, 2, 1, 0, 0, 1)
    move.layers[1].pixels:setPixel(5, 5, 0, 1, 0, 1)
    local moving = assert(Selection.rectangle(16, 16, 2, 2, 3, 3))
    assert(E.move_selection(move, 1, moving, 3, 0), "Move não executado")
    local _, _, _, empty_origin = move.layers[1].pixels:getPixel(2, 2)
    local moved_red = select(1, move.layers[1].pixels:getPixel(5, 2))
    local _, kept_green = move.layers[1].pixels:getPixel(5, 5)
    assert(empty_origin == 0 and moved_red > 0.99 and kept_green > 0.99
        and Selection.contains(moving, 5, 2),
        "Move apagou pixels fora da máscara ou não moveu o contorno")
    assert(E.undo(move, moving), "Move sem undo")
    local restored_red = select(1, move.layers[1].pixels:getPixel(2, 2))
    local _, _, _, undone_target = move.layers[1].pixels:getPixel(5, 2)
    assert(restored_red > 0.99 and undone_target == 0 and
           Selection.contains(moving, 2, 2), "Undo de movimento inconsistente")
    assert(E.redo(move, moving), "Move sem redo")
    assert(Selection.contains(moving, 5, 2) and
           select(1, move.layers[1].pixels:getPixel(5, 2)) > 0.99,
           "Redo de movimento inconsistente")

    test_clipboard_transform(E)
    checkpoint("feather alpha masks and paint")
    test_feather_paint(E)
    checkpoint("feather alpha transform and GPU parity")
    test_feather_transform(E)
    checkpoint("selection morphology expand contract")
    test_selection_morph(E)
    checkpoint("magic wand global color across disconnected regions")
    test_bucket_tolerance(E)
    test_magic_wand_rgb_only(E)
    test_magic_wand_diagonal(E)
    test_magic_wand_composite_source(E)
    test_magic_wand_global(E)
    checkpoint("magic wand RGBA tolerance and connectivity")
    test_magic_wand_tolerance(E)
    checkpoint("selection boolean algebra and PNG")
    test_selection_boolean(E)
    checkpoint("selection full canvas and inverse")
    test_selection_all_invert(E)
    checkpoint("selection horizontal and vertical mirror")
    test_selection_flip(E)
    checkpoint("affine rotation and nonuniform scaling")
    test_affine_transforms(E)
    checkpoint("GPU affine preview vs CPU bilinear")
    test_affine_gpu_preview(E)
    checkpoint("GPU move preview vs CPU commit")
    test_move_preview_engine(E)
    checkpoint("bilinear preview and commit")
    test_bilinear_preview(E)
    checkpoint("history PNG roundtrip")
    test_history_roundtrip(E)

    checkpoint("before persistence")
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
    model2.layers[1].alpha_lock = true
    model2.layers[1].blending = "Multiply"
    model2.layers[1].locked = true
    model2.background_mode = "transparent_dark"
    assert(Bridge.save(), "Falha no salvamento da obra em camadas")
    assert(love.filesystem.getInfo("lua-artworks/index.tsv"))
    local index = assert(love.filesystem.read("lua-artworks/index.tsv"))
    local key = assert(index:match("(art_%d+_%d+)"))
    local path = "lua-artworks/" .. key
    assert(love.filesystem.getInfo(path .. "/layer_1.png"))
    assert(love.filesystem.getInfo(path .. "/preview.png"))
    assert(love.filesystem.getInfo(path .. "/document.tsv"))
    local layer_metadata = assert(love.filesystem.read(path .. "/layers.tsv"))
    assert(layer_metadata:match("\tMultiply\t0\t1\t1"),
        "Modo de mesclagem, Alpha Lock e Lock não foram persistidos")
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
    assert(love.filesystem.getInfo(path .. "/history.tsv"),
        "Ponte não salvou histórico da pintura")
    assert(Bridge.undo(), "Ponte não restaurou undo do histórico")
    local _, _, _, gone = love.image.newImageData(path .. "/layer_1.png"):getPixel(8, 8)
    assert(gone > 0.9, "Undo não deveria modificar PNG já persistido")
    assert(Bridge.redo(), "Ponte não restaurou redo do histórico")
    assert(model3.layers[1].name == "Layer One", "Metadados da camada não reabertos")
    assert(model3.layers[1].alpha_lock and model3.layers[1].locked
           and model3.layers[1].blending == "Multiply",
           "Propriedades da camada e modo de mesclagem não foram reabertos")
    assert(model3.background_mode == "transparent_dark",
           "Cor do fundo não foi restaurada")
    assert(Bridge.mousepressed(model3, id, x, y, 1024, 768,
        view, prefs, {0, 0, 0}, 5, 100, colors),
        "Conta-gotas não acessou projeto reaberto")
    assert(model3.color[1] > 240 and model3.color[2] < 10,
        "Conta-gotas não encontrou os pixels após reabertura")

    -- Um arquivo antigo de quatro colunas precisa continuar abrindo.
    assert(love.filesystem.write(path .. "/layers.tsv", "1\tLegacy\t1\t80"))
    Bridge.open(model3, id)
    assert(model3.layers[1].name == "Legacy" and
           model3.layers[1].opacity == 80 and
           model3.layers[1].alpha_lock == false and
           model3.layers[1].clipping == false and
           model3.layers[1].blending == "Normal",
           "Compatibilidade com layers.tsv legado de quatro colunas falhou")

    -- Ponte real da UI: arrastar Transformar cria seleção retangular e
    -- o próximo arraste move pixels, respeitando coordenadas e undo.
    local model4 = {
        screen = "editor", document = {width = 16, height = 16},
        layers = {{id = 1, visible = true, opacity = 100,
                   blending = "Normal", name = "Layer 1"}},
        active_layer_id = 1, active_tool = "brush", background_mode = "white"
    }
    function model4:active_layer() return self.layers[1] end
    function model4:set_color(red, green_, blue_)
        self.color = {red, green_, blue_}
    end
    local art4 = gallery:add_artwork(16, 16, "Selection test")
    Bridge.create(model4, art4, gallery)
    assert(Bridge.mousepressed(model4, art4, x, y, 1024, 768,
        view, prefs, {255, 0, 0}, 3, 100, colors))
    Bridge.mousereleased()
    model4.active_tool = "transform"
    local from_x, from_y = x - 15, y - 15
    local to_x, to_y = x + 15, y + 15
    assert(Bridge.mousepressed(model4, art4, from_x, from_y, 1024, 768,
        view, prefs, {0, 0, 0}, 3, 100, colors))
    Bridge.mousemoved(model4, to_x, to_y, 1)
    Bridge.mousereleased(model4, to_x, to_y, 1)
    assert(Bridge.mousepressed(model4, art4, x, y, 1024, 768,
        view, prefs, {0, 0, 0}, 3, 100, colors))
    Bridge.mousemoved(model4, x + 20, y, 1)
    Bridge.mousereleased(model4, x + 20, y, 1)
    assert(Bridge.undo(), "Ponte não permitiu desfazer transformação")
    assert(Bridge.redo(), "Ponte não permitiu refazer transformação")
    model4.active_tool = "eyedropper"
    assert(Bridge.mousepressed(model4, art4, x + 20, y, 1024, 768,
        view, prefs, {0, 0, 0}, 3, 100, colors))
    assert(model4.color[1] > 240 and model4.color[2] < 10,
        "Transformar da UI não moveu pixels para nova posição")
    checkpoint("before bridge clipboard")
    assert(Bridge.selection_command(model4, "copy"), "Ctrl+C da ponte falhou")
    assert(Bridge.selection_command(model4, "paste"), "Ctrl+V da ponte falhou")
    assert(Bridge.undo(), "Colagem pela ponte sem undo")
    assert(Bridge.redo(), "Colagem pela ponte sem redo")
    assert(Bridge.selection_command(model4, "rotate_cw"),
        "Giro pela ponte falhou")
    assert(Bridge.selection_command(model4, "scale_half"),
        "Redução pela ponte falhou")
    assert(Bridge.undo() and Bridge.redo(),
        "A escala da ponte não manteve o histórico")
    checkpoint("selection PNG roundtrip")
    test_selection_roundtrip(Bridge, model4, art4)
    checkpoint("bridge feather shortcut and PNG")
    test_feather_bridge(Bridge, model4, art4)
    checkpoint("selection history disk and corruption")
    test_selection_history_storage()
    checkpoint("bridge selection-only undo and redo")
    test_selection_only_history(Bridge, gallery)
    checkpoint("bridge selection morphology shortcuts")
    test_selection_morph_bridge(Bridge, gallery)
    checkpoint("bridge magic wand global mode and persistence")
    test_bucket_tolerance_bridge(Bridge, gallery)
    test_magic_wand_rgb_only_bridge(Bridge, gallery)
    test_magic_wand_diagonal_bridge(Bridge, gallery)
    test_magic_wand_sample_all_bridge(Bridge, gallery)
    test_magic_wand_global_bridge(Bridge, gallery)
    checkpoint("bridge magic wand tolerance shortcuts and persistence")
    test_magic_wand_tolerance_bridge(Bridge, gallery)
    checkpoint("bridge boolean gestures rectangle lasso wand")
    test_selection_boolean_bridge(Bridge, gallery)
    checkpoint("bridge select all and invert shortcuts")
    test_selection_all_invert_bridge(Bridge, gallery)
    checkpoint("bridge selection flip shortcuts")
    test_flip_bridge(Bridge, gallery)
    checkpoint("bridge affine gestures")
    test_affine_bridge(Bridge, gallery)
    checkpoint("bridge move preview and cancel")
    test_move_preview_bridge(Bridge, gallery)

    -- Limpeza do armazenamento efêmero do teste (não é o diretório da aplicação real).
    require("lua_history").cleanup(path)
    require("lua_selection_history").cleanup(path)
    for _, filename in ipairs({"layer_1.png", "preview.png", "layers.tsv", "document.tsv"}) do
        love.filesystem.remove(path .. "/" .. filename)
    end
    love.filesystem.remove(path)
    love.filesystem.remove("lua-artworks/index.tsv")
    love.filesystem.remove("lua-artworks")
    checkpoint("complete")
    print("PASS: wand global RGBA + tolerance + persistent history + GPU")
    love.event.quit(0)
end
