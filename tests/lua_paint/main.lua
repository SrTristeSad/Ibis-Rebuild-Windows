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

    -- Limpeza do armazenamento efêmero do teste (não é o diretório da aplicação real).
    require("lua_history").cleanup(path)
    for _, filename in ipairs({"layer_1.png", "preview.png", "layers.tsv", "document.tsv"}) do
        love.filesystem.remove(path .. "/" .. filename)
    end
    love.filesystem.remove(path)
    love.filesystem.remove("lua-artworks/index.tsv")
    love.filesystem.remove("lua-artworks")
    checkpoint("complete")
    print("PASS: Lua history persisted undo/redo + selection/layers + corrupt recovery")
    love.event.quit(0)
end
