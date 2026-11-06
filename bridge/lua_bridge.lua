-- Liga o Ibis-Lua (interface intacta) ao motor Lua/LÖVE.
local Engine = require("lua_engine")
local Selection = require("lua_selection")
local History = require("lua_history")
local SelectionHistory = require("lua_selection_history")
local Bridge = {}
local ROOT = "lua-artworks"
local records, project, gallery_ref, drawing = {}, nil, nil, nil
local selection, gesture, clipboard = nil, nil, nil
local function discard_preview(d)
    if d and d.preview then
        if d.preview.image then d.preview.image:release() end
        if d.preview.mask_image then d.preview.mask_image:release() end
        d.preview = nil
    end
end

-- Histórico EXCLUSIVO de máscaras. Pilhas independentes dos snapshots
-- raster, agora persistidas em PNG/TSV por geração com validação integral.
-- O teto por pilha é 8 estados / 1 Mi de pixels selecionados ao todo.
local mask_undo, mask_redo = {}, {}
local MASK_HISTORY_STEPS = 8
local MASK_HISTORY_PIXELS = 1024 * 1024

local function clear_mask_history()
    mask_undo, mask_redo = {}, {}
end

local function push_mask_state(stack, mask)
    stack[#stack + 1] = {mask = Selection.clone(mask)}
    local used = 0
    for _, entry in ipairs(stack) do
        if entry.mask then used = used + entry.mask.count end
    end
    while #stack > MASK_HISTORY_STEPS or
          (used > MASK_HISTORY_PIXELS and #stack > 1) do
        local old = table.remove(stack, 1)
        if old.mask then used = used - old.mask.count end
    end
end

local function same_mask(a, b)
    if a == b then return true end
    if not a or not b or a.w ~= b.w or a.h ~= b.h or
       a.count ~= b.count then return false end
    for key in pairs(a.mask) do
        if not b.mask[key] then return false end
        local wa = a.weights and a.weights[key] or 1
        local wb = b.weights and b.weights[key] or 1
        if math.abs(wa - wb) > 1e-8 then return false end
    end
    return true
end

-- previous_is_explicit permite usar nil como estado anterior a um
-- arraste que criou uma seleção (ou que limpou a anterior no mousepress).
local function set_mask(next_mask, previous, previous_is_explicit)
    local before = selection
    if previous_is_explicit then before = previous end
    if not same_mask(before, next_mask) then
        push_mask_state(mask_undo, before)
        mask_redo = {}
    end
    selection = next_mask
end

-- Navegar em qualquer histórico encerra primeiro as interações em curso.
-- Isso impede que um mousemoved posterior pinte DEPOIS do undo/redo.
-- Uma seleção em construção (retângulo/laço) ainda não foi confirmada:
-- restaurar o objeto original, sem criar um passo de histórico de máscara.
local function interrupt_active_gesture()
    drawing = nil
    local pending = gesture
    if not pending then return end
    gesture = nil
    discard_preview(pending)
    if pending.kind == "rectangle" or pending.kind == "lasso" then
        selection = pending.before_selection_ref
    end
end

-- Os eventos seguintes de um arraste podem chegar depois de o usuário
-- mudar ferramenta/camada, visibilidade ou Alpha Lock. Nunca pintar
-- novamente no estado antigo nem confirmar uma prévia desatualizada.
local function stroke_context_valid(model, d)
    local info = model:active_layer()
    return model.screen == "editor" and model.active_tool == d.tool
       and info and info.id == d.layer and info.visible and not info.locked
       and (info.alpha_lock == true) == (d.alpha_lock == true)
       and selection == d.selection_at_start
       and project and project.layers[d.layer] ~= nil
end

local function gesture_context_valid(model, d)
    local info = model:active_layer()
    if model.screen ~= "editor" or model.active_tool ~= d.tool or
       not info or info.id ~= d.active_layer_id then return false end
    if d.kind == "move" or d.kind == "rotate_free" or
       d.kind == "scale_free" then
        return not info.locked and info.visible and not info.alpha_lock
           and project and project.layers[d.layer] ~= nil
    end
    return true
end

local function mask_history_step(from, to)
    interrupt_active_gesture()
    if #from == 0 then return false end
    local entry = table.remove(from)
    push_mask_state(to, selection)
    selection = entry.mask
    return true
end

-- A mesma matemática orienta a prévia e o resultado final.
local function affine_gesture_args(d)
    if not selection or not d then return nil end
    if d.kind == "rotate_free" then
        local cx = (selection.min_x + selection.max_x + 1) / 2
        local cy = (selection.min_y + selection.max_y + 1) / 2
        local begin_x, begin_y = d.x - cx, d.y - cy
        local end_x, end_y = d.end_x - cx, d.end_y - cy
        if begin_x * begin_x + begin_y * begin_y < 0.25 or
           end_x * end_x + end_y * end_y < 0.25 then return nil end
        return math.deg(math.atan2(end_y, end_x) -
                        math.atan2(begin_y, begin_x)), 1, 1
    elseif d.kind == "scale_free" then
        local sw = selection.max_x - selection.min_x + 1
        local sh = selection.max_y - selection.min_y + 1
        return 0, math.max(0.1, math.min(8, 1 + (d.end_x - d.x) / sw)),
                  math.max(0.1, math.min(8, 1 + (d.end_y - d.y) / sh))
    end
    return nil
end

-- Ctrl+Shift soma, Ctrl+Alt subtrai, ambos intersectam.
-- Shift/Alt sozinhos continuam reservados ao redimensionamento e giro.
local function selection_merge_mode()
    if not love.keyboard.isDown("lctrl", "rctrl") then return "replace" end
    local shift = love.keyboard.isDown("lshift", "rshift")
    local alt = love.keyboard.isDown("lalt", "ralt")
    if shift and alt then return "intersect" end
    if shift then return "add" end
    if alt then return "subtract" end
    return "replace"
end

local gallery_images = {}
local counter = 0

local function safe(text)
    return tostring(text or ""):gsub("[\t\r\n]", " ")
end
local function project_path(key)
    assert(type(key) == "string" and key:match("^[%w_%-]+$"))
    return ROOT .. "/" .. key
end
local function ensure(model)
    if not model or model.screen ~= "editor" or not model.document then return nil end
    if not project or project.model ~= model or project.document ~= model.document then
        project = Engine.new(model.document.width, model.document.height)
        project.model, project.document = model, model.document
    end
    Engine.sync(project, model)
    return project
end

function Bridge.supports(w, h) return Engine.supports(w, h) end

function Bridge.create(model, id, gallery)
    discard_preview(gesture)
    selection, gesture, drawing = nil, nil, nil
    clear_mask_history()
    gallery_ref = gallery
    project = Engine.new(model.document.width, model.document.height)
    project.model, project.document, project.id = model, model.document, id
    project.wand_tolerance = 0
    project.wand_global = false
    project.wand_sample_all = false
    project.wand_diagonal = false
    project.wand_rgb_only = false
    project.bucket_tolerance = 0
    project.bucket_global = false
    project.bucket_rgb_only = false
    project.bucket_diagonal = false
    project.bucket_sample_all = false
    Engine.sync(project, model)
    counter = counter + 1
    local key = string.format("art_%d_%d", os.time(), counter)
    local item = gallery:get(id)
    records[id] = {key = key, w = project.w, h = project.h,
                   name = item and item.name or "Untitled"}
    project.dirty = true
end

local function saved_layers(model, path, p)
    local data = love.filesystem.read(path .. "/layers.tsv")
    if not data then return end
    local layers = {}
    local valid_blending = {
        Normal = true, Multiply = true, Screen = true, Overlay = true,
        Darken = true, Lighten = true, ["Color Burn"] = true,
        ["Color Dodge"] = true, ["Soft Light"] = true
    }
    local ids = {}
    for line in data:gmatch("[^\r\n]+") do
        -- Compatibilidade: arquivos antigos possuem somente quatro colunas.
        local id, name, visible, opacity, blending, clipping, alpha_lock, locked =
            line:match("^(%d+)\t([^\t]*)\t([01])\t(%d+)\t([^\t]+)\t([01])\t([01])\t([01])$")
        if not id then
            id, name, visible, opacity =
                line:match("^(%d+)\t([^\t]*)\t([01])\t(%d+)$")
            blending, clipping, alpha_lock, locked = "Normal", "0", "0", "0"
        end
        id, opacity = tonumber(id), tonumber(opacity)
        if id and id >= 1 and not ids[id] and opacity and opacity <= 100
           and #layers < 32 and name and #name >= 1 and
           valid_blending[blending] then
            ids[id] = true
            layers[#layers + 1] = {
                id = id, name = name, visible = visible == "1",
                opacity = opacity, blending = blending,
                clipping = clipping == "1", alpha_lock = alpha_lock == "1",
                locked = locked == "1"
            }
        end
    end
    if #layers == 0 then return end
    model.layers, model.next_layer_id = layers, 1
    for _, info in ipairs(layers) do
        model.next_layer_id = math.max(model.next_layer_id, info.id + 1)
        Engine.load_layer(p, info.id, path .. "/layer_" .. info.id .. ".png")
    end
    model.active_layer_id = layers[#layers].id
    local metadata = love.filesystem.read(path .. "/document.tsv")
    if metadata then
        local active_id, background =
            metadata:match("^(%d+)\t([%a_]+)")
        local stored_tolerance, stored_global, stored_sample_all,
              stored_diagonal, stored_rgb_only, stored_bucket_tolerance,
              stored_bucket_global, stored_bucket_rgb_only,
              stored_bucket_diagonal, stored_bucket_sample_all = metadata:match(
            "^%d+\t[%a_]+\t(%d+)\t([^\t\r\n]+)\t([^\t\r\n]+)\t([^\t\r\n]+)\t([^\t\r\n]+)\t([^\t\r\n]+)\t([^\t\r\n]+)\t([^\t\r\n]+)\t([^\t\r\n]+)\t([^\t\r\n]+)%s*$")
        if not stored_tolerance then
            stored_tolerance, stored_global, stored_sample_all,
                stored_diagonal, stored_rgb_only, stored_bucket_tolerance,
                stored_bucket_global, stored_bucket_rgb_only,
                stored_bucket_diagonal = metadata:match(
                "^%d+\t[%a_]+\t(%d+)\t([^\t\r\n]+)\t([^\t\r\n]+)\t([^\t\r\n]+)\t([^\t\r\n]+)\t([^\t\r\n]+)\t([^\t\r\n]+)\t([^\t\r\n]+)\t([^\t\r\n]+)%s*$")
        end
        if not stored_tolerance then
            stored_tolerance, stored_global, stored_sample_all,
                stored_diagonal, stored_rgb_only, stored_bucket_tolerance,
                stored_bucket_global, stored_bucket_rgb_only = metadata:match(
                "^%d+\t[%a_]+\t(%d+)\t([^\t\r\n]+)\t([^\t\r\n]+)\t([^\t\r\n]+)\t([^\t\r\n]+)\t([^\t\r\n]+)\t([^\t\r\n]+)\t([^\t\r\n]+)%s*$")
        end
        if not stored_tolerance then
            stored_tolerance, stored_global, stored_sample_all,
                stored_diagonal, stored_rgb_only, stored_bucket_tolerance,
                stored_bucket_global = metadata:match(
                "^%d+\t[%a_]+\t(%d+)\t([^\t\r\n]+)\t([^\t\r\n]+)\t([^\t\r\n]+)\t([^\t\r\n]+)\t([^\t\r\n]+)\t([^\t\r\n]+)%s*$")
        end
        if not stored_tolerance then
            stored_tolerance, stored_global, stored_sample_all,
                stored_diagonal, stored_rgb_only, stored_bucket_tolerance =
                metadata:match(
                "^%d+\t[%a_]+\t(%d+)\t([^\t\r\n]+)\t([^\t\r\n]+)\t([^\t\r\n]+)\t([^\t\r\n]+)\t([^\t\r\n]+)%s*$")
        end
        if not stored_tolerance then
            stored_tolerance, stored_global, stored_sample_all,
                stored_diagonal, stored_rgb_only = metadata:match(
                "^%d+\t[%a_]+\t(%d+)\t([^\t\r\n]+)\t([^\t\r\n]+)\t([^\t\r\n]+)\t([^\t\r\n]+)%s*$")
        end
        if not stored_tolerance then
            stored_tolerance, stored_global, stored_sample_all,
                stored_diagonal = metadata:match(
                "^%d+\t[%a_]+\t(%d+)\t([^\t\r\n]+)\t([^\t\r\n]+)\t([^\t\r\n]+)%s*$")
        end
        if not stored_tolerance then
            stored_tolerance, stored_global, stored_sample_all = metadata:match(
                "^%d+\t[%a_]+\t(%d+)\t([^\t\r\n]+)\t([^\t\r\n]+)%s*$")
        end
        if not stored_tolerance then
            stored_tolerance, stored_global = metadata:match(
                "^%d+\t[%a_]+\t(%d+)\t([^\t\r\n]+)%s*$")
        end
        if not stored_tolerance then
            stored_tolerance = metadata:match("^%d+\t[%a_]+\t(%d+)%s*$")
        end
        local numeric_tolerance = tonumber(stored_tolerance)
        -- Arquivos legados com duas ou três colunas continuam válidos.
        -- Campos inválidos usam zero/contíguo sem afetar a pintura.
        p.wand_tolerance = numeric_tolerance and
            numeric_tolerance >= 0 and numeric_tolerance <= 255 and
            numeric_tolerance == math.floor(numeric_tolerance)
            and numeric_tolerance or 0
        p.wand_global = stored_global == "1"
        p.wand_sample_all = stored_sample_all == "1"
        p.wand_diagonal = stored_diagonal == "1"
        p.wand_rgb_only = stored_rgb_only == "1"
        local bucket_number = tonumber(stored_bucket_tolerance)
        p.bucket_tolerance = bucket_number and
            bucket_number >= 0 and bucket_number <= 255 and
            bucket_number == math.floor(bucket_number) and bucket_number or 0
        p.bucket_global = stored_bucket_global == "1"
        p.bucket_rgb_only = stored_bucket_rgb_only == "1"
        p.bucket_diagonal = stored_bucket_diagonal == "1"
        p.bucket_sample_all = stored_bucket_sample_all == "1"
        active_id = tonumber(active_id)
        if active_id then
            for _, info in ipairs(layers) do
                if info.id == active_id then model.active_layer_id = active_id; break end
            end
        end
        if background == "white" or background == "transparent_light"
           or background == "transparent_dark" then
            model.background_mode = background
        end
    end
end

function Bridge.open(model, id)
    discard_preview(gesture)
    selection, gesture, drawing = nil, nil, nil
    clear_mask_history()
    local record = records[id]
    project = Engine.new(model.document.width, model.document.height)
    project.model, project.document, project.id = model, model.document, id
    project.wand_tolerance = 0
    project.wand_global = false
    project.wand_sample_all = false
    project.wand_diagonal = false
    project.wand_rgb_only = false
    project.bucket_tolerance = 0
    project.bucket_global = false
    project.bucket_rgb_only = false
    project.bucket_diagonal = false
    project.bucket_sample_all = false
    if record then saved_layers(model, project_path(record.key), project) end
    Engine.sync(project, model)
    if record then
        -- Arquivos antigos não possuem selection.png e seguem abrindo.
        -- Máscaras inválidas são ignoradas sem comprometer a obra.
        local path = project_path(record.key)
        selection = Selection.load(path .. "/selection.png",
                                   project.w, project.h)
        -- O histórico é opcional e só é aplicado após validar TODOS
        -- os PNGs: um arquivo inválido nunca impede abrir a pintura.
        History.load(project, path, selection)
        local saved_mask_history = SelectionHistory.load(
            path, project.w, project.h, selection)
        if saved_mask_history then
            mask_undo, mask_redo =
                saved_mask_history.undo, saved_mask_history.redo
        end
    end
    project.dirty = false
end

function Bridge.restore_gallery(gallery)
    gallery_ref = gallery
    local index = love.filesystem.read(ROOT .. "/index.tsv")
    if not index then return end
    for line in index:gmatch("[^\r\n]+") do
        local key, width, height, title = line:match("^([%w_%-]+)\t(%d+)\t(%d+)\t(.*)$")
        width, height = tonumber(width), tonumber(height)
        if key and width and height and title ~= "" then
            local ok, id = pcall(function() return gallery:add_artwork(width, height, title) end)
            if ok then records[id] = {key = key, w = width, h = height, name = title} end
        end
    end
end

function Bridge.save()
    if not project or not project.id or not project.model then return false end
    local record = records[project.id]
    if not record then return false end
    -- A máscara de um retângulo/laço replace pode estar oculta até mouseup.
    -- Salvar deve persistir somente o último estado confirmado, nunca a
    -- seleção provisória; os pixels já pintados conservam seu undo raster.
    interrupt_active_gesture()
    local path = project_path(record.key)
    assert(love.filesystem.createDirectory(path), "Não foi possível criar diretório da obra")
    Engine.sync(project, project.model)
    local lines = {}
    for _, info in ipairs(project.model.layers) do
        local layer = project.layers[info.id]
        if layer then
            layer.pixels:encode("png", path .. "/layer_" .. info.id .. ".png")
            lines[#lines + 1] = table.concat({
                tostring(info.id), safe(info.name), info.visible and "1" or "0",
                tostring(info.opacity or 100), info.blending or "Normal",
                info.clipping and "1" or "0",
                info.alpha_lock and "1" or "0",
                info.locked and "1" or "0"}, "\t")
        end
    end
    local preview = Engine.thumbnail(project, project.model)
    preview:encode("png", path .. "/preview.png")
    gallery_images[project.id] = nil
    assert(love.filesystem.write(path .. "/layers.tsv", table.concat(lines, "\n")))
    assert(love.filesystem.write(path .. "/document.tsv",
        table.concat({tostring(project.model.active_layer_id or 0),
            safe(project.model.background_mode or "white"),
            tostring(project.wand_tolerance or 0),
            project.wand_global and "1" or "0",
            project.wand_sample_all and "1" or "0",
            project.wand_diagonal and "1" or "0",
            project.wand_rgb_only and "1" or "0",
            tostring(project.bucket_tolerance or 0),
            project.bucket_global and "1" or "0",
            project.bucket_rgb_only and "1" or "0",
            project.bucket_diagonal and "1" or "0",
            project.bucket_sample_all and "1" or "0"}, "\t")))
    -- Salvar a máscara separadamente mantém o formato PNG/TSV das obras
    -- retrocompatível e evita que a seleção contamine qualquer camada.
    local mask_path = path .. "/selection.png"
    if selection and selection.count > 0 and
       selection.w == project.w and selection.h == project.h then
        local ok, reason = Selection.save(selection, mask_path)
        assert(ok, reason)
    elseif love.filesystem.getInfo(mask_path) then
        assert(love.filesystem.remove(mask_path),
            "Não foi possível limpar seleção anterior.")
    end
    local history_ok, history_error = History.save(project, path, selection)
    assert(history_ok, history_error)
    local mask_history_ok, mask_history_error = SelectionHistory.save(
        path, project.w, project.h, selection, mask_undo, mask_redo)
    assert(mask_history_ok, mask_history_error)
    local item = gallery_ref and gallery_ref:get(project.id)
    if item then record.name = item.name end
    record.saved = true
    local index = {}
    for _, r in pairs(records) do
        if r.saved or love.filesystem.getInfo(project_path(r.key) .. "/layers.tsv") then
            index[#index + 1] = table.concat({r.key, r.w, r.h, safe(r.name)}, "\t")
        end
    end
    table.sort(index)
    assert(love.filesystem.write(ROOT .. "/index.tsv", table.concat(index, "\n")))
    project.dirty = false
    return true
end

function Bridge.install(Model)
    local original = Model.open_gallery
    function Model:open_gallery(...)
        if self.screen == "editor" and project and project.model == self then
            -- Não abandonar a obra quando a persistência recusou salvar.
            -- Erros de escrita seguem propagados sem trocar de tela.
            if not Bridge.save() then return false end
        end
        return original(self, ...)
    end
end

function Bridge.draw(model, visual)
    local p = ensure(model)
    if not p then return end
    local d = gesture
    if d and d.preview and d.preview.active and
       d.layer and p.layers[d.layer] then
        -- Projeta uma camada alternativa em memória, sem tocar em p.layers,
        -- nas pilhas undo/redo, em dirty ou nas miniaturas persistidas.
        local temporary = {w = p.w, h = p.h, layers = {},
                           compose_canvases = p.compose_canvases}
        for id, layer in pairs(p.layers) do temporary.layers[id] = layer end
        temporary.layers[d.layer] = d.preview
        Engine.draw(temporary, model, visual and visual.interpolation)
        if not p.compose_canvases then
            p.compose_canvases = temporary.compose_canvases
        end
        -- O canvas é centrado, mas a máscara raster usa (0,0) no canto.
        -- Transformar o CONTORNO no shader/draw evita construir outra
        -- Selection.from_mask em cada movimento.
        love.graphics.push()
        love.graphics.translate(-p.w / 2, -p.h / 2)
        if d.preview.kind == "move" then
            love.graphics.translate(d.preview.dx, d.preview.dy)
        elseif d.preview.kind == "affine_gpu" then
            love.graphics.translate(d.preview.cx, d.preview.cy)
            love.graphics.rotate(math.rad(d.preview.degrees))
            love.graphics.scale(d.preview.sx, d.preview.sy)
            love.graphics.translate(-d.preview.cx, -d.preview.cy)
        end
        Selection.draw(selection)
        love.graphics.pop()
    else
        Engine.draw(p, model, visual and visual.interpolation)
        love.graphics.push()
        love.graphics.translate(-p.w / 2, -p.h / 2)
        Selection.draw(selection)
        love.graphics.pop()
    end
end

-- Desenha os pixels REAIS na área da miniatura já presente na interface.
function Bridge.draw_layer_thumbnail(model, id, x, y, w, h)
    local p = ensure(model)
    local layer = p and p.layers[id]
    if not layer then return false end
    local ratio = math.min(w / p.w, h / p.h)
    love.graphics.push("all")
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(layer.image,
        x + (w - p.w * ratio) / 2, y + (h - p.h * ratio) / 2,
        0, ratio, ratio)
    love.graphics.pop()
    return true
end

function Bridge.draw_gallery_thumbnail(id, x, y, w, h)
    local record = records[id]
    if not record then return false end
    local cached = gallery_images[id]
    if cached == nil then
        local file = project_path(record.key) .. "/preview.png"
        if love.filesystem.getInfo(file) then
            local ok, image = pcall(love.graphics.newImage, file)
            cached = ok and image or false
        else cached = false end
        gallery_images[id] = cached
    end
    if not cached then return false end
    love.graphics.push("all")
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(cached, x, y, 0,
        w / cached:getWidth(), h / cached:getHeight())
    love.graphics.pop()
    return true
end

local function canvas_point(model, x, y, w, h, view, preferences,
                            allow_outside)
    local dw, dh = model.document.width, model.document.height
    local left = preferences.tool_position == "left" and 62 or 0
    local right = preferences.tool_position == "right" and 75 or 34
    local aw, ah = w - left - right, h - 160
    local factor = math.min(aw / dw, ah / dh, 1.1) * view.zoom
    if factor <= 0 then return nil end
    local cx, cy = left + aw / 2 + view.pan_x, 62 + ah / 2 + view.pan_y
    local dx, dy = x - cx, y - cy
    local co, si = math.cos(view.rotation), math.sin(view.rotation)
    local px = (co * dx + si * dy) / factor + dw / 2
    local py = (-si * dx + co * dy) / factor + dh / 2
    if not allow_outside and
       (px < 0 or px >= dw or py < 0 or py >= dh) then
        return nil
    end
    return px, py
end

local function paint(p, d, x, y, start_x, start_y)
    Engine.stroke(p, d.layer, start_x or d.x, start_y or d.y,
                  x, y, d.size, d.color,
                  d.opacity, d.eraser, d.alpha_lock, d.selection_at_start,
                  function()
                      -- O snapshot só existe se algum pixel realmente
                      -- mudar. Um gesto inteiro sem efeito preserva redo.
                      if not d.history_started then
                          Engine.begin_stroke(p, d.layer)
                          d.history_started = true
                      end
                  end, d.covered_pixels)
    d.x, d.y = x, y
end

-- Recorte paramétrico dos CENTROS do pincel. Um centro fora do
-- canvas ainda deve pintar enquanto seu círculo atingir algum
-- centro de pixel interno; por isso expandimos os limites pelo
-- raio efetivo usado por Engine.stroke. O rasterizador continua
-- impedindo qualquer escrita fora do canvas.
-- A posição CRUA do cursor é mantida fora para evitar diagonais
-- artificiais ao reentrar.
local function clip_stroke_segment(x0, y0, x1, y1, w, h, radius)
    local dx, dy = x1 - x0, y1 - y0
    local start_t, end_t = 0, 1
    local function bound(p, q)
        if p == 0 then return q >= 0 end
        local t = q / p
        if p < 0 then
            if t > end_t then return false end
            if t > start_t then start_t = t end
        else
            if t < start_t then return false end
            if t < end_t then end_t = t end
        end
        return true
    end
    -- Centros de pixels vão de 0,5 até largura/altura - 0,5.
    -- Fora desse retângulo ampliado, nenhum dab pode atingir pixel.
    local xmin, ymin = 0.5 - radius, 0.5 - radius
    local xmax, ymax = w - 0.5 + radius, h - 0.5 + radius
    if not bound(-dx, x0 - xmin) or not bound(dx, xmax - x0) or
       not bound(-dy, y0 - ymin) or not bound(dy, ymax - y0) then
        return nil
    end
    return x0 + start_t * dx, y0 + start_t * dy,
           x0 + end_t * dx, y0 + end_t * dy
end

-- Deslocamentos sem efeito não reaplicam tinta nem multiplicam alfa.
-- Armazenar o ponto cru MESMO se o segmento não intersectar o canvas.
local function continue_stroke(p, d, x, y)
    local old_x, old_y = d.raw_x, d.raw_y
    d.raw_x, d.raw_y = x, y
    if math.abs(x - old_x) + math.abs(y - old_y) <= 0.005 then
        return
    end
    -- Usar exatamente o mesmo raio limitado do motor Lua.
    local radius = math.max(0.75, math.min(256, d.size) / 2)
    local x0, y0, x1, y1 = clip_stroke_segment(
        old_x, old_y, x, y, p.w, p.h, radius)
    if x0 and math.abs(x1 - x0) + math.abs(y1 - y0) > 0.005 then
        paint(p, d, x1, y1, x0, y0)
    end
end

function Bridge.mousepressed(model, id, x, y, w, h, view, preferences,
                             color, size, opacity, colors, notice)
    if model.screen ~= "editor" or love.keyboard.isDown("space") then return false end
    local tool = model.active_tool
    if tool ~= "brush" and tool ~= "eraser" and
       tool ~= "bucket" and tool ~= "eyedropper" and
       tool ~= "transform" and tool ~= "lasso" and
       tool ~= "magic_wand" then return false end
    local p = ensure(model)
    if not p then return false end
    local px, py = canvas_point(model, x, y, w, h, view, preferences)
    if not px then return false end

    -- Um novo mousepress válido substitui qualquer gesto anterior.
    -- Eventos de release perdidos ou pressões consecutivas não podem
    -- deixar a pintura antiga coexistir com uma seleção/transformação.
    -- Preserva pixels já pintados e seu histórico; seleções provisórias
    -- são canceladas sem criar entradas na linha do tempo.
    interrupt_active_gesture()

    if tool == "magic_wand" then
        discard_preview(gesture)
        gesture = nil
        local info = model:active_layer()
        local layer = info and p.layers[info.id]
        if not layer then return true end
        -- A referência pode ser a composição visível, mas a seleção
        -- continua sendo apenas uma máscara; pintar edita a camada ativa.
        local reference = p.wand_sample_all and
            Engine.composite_pixel_source(p, model, true) or layer
        local mask, reason = Selection.magic_wand(
            reference, p.w, p.h, px, py, p.wand_tolerance or 0,
            p.wand_global or false, p.wand_diagonal or false,
            p.wand_rgb_only or false)
        if mask then
            local combined, err = Selection.combine(selection, mask,
                                          selection_merge_mode(), p.w, p.h)
            if not err then set_mask(combined) end
            if err and notice then notice(err) end
        elseif reason and notice then notice(reason) end
        return true
    end
    if tool == "lasso" then
        discard_preview(gesture)
        local mode = selection_merge_mode()
        local before_ref = selection
        local before = Selection.clone(selection)
        if mode == "replace" then selection = nil end
        local info = model:active_layer()
        gesture = {kind = "lasso", w = w, h = h, view = view,
                   tool = tool, active_layer_id = info and info.id,
                   preferences = preferences, points = {{px, py}},
                   mode = mode, before_selection = before,
                   before_selection_ref = before_ref,
                   x = px, y = py, end_x = px, end_y = py}
        return true
    end
    if tool == "transform" then
        discard_preview(gesture)
        local info = model:active_layer()
        local mode = selection_merge_mode()
        local before_ref = selection
        local before = Selection.clone(selection)
        -- Com Ctrl+Shift/Alt, inicia um novo retângulo inclusive dentro
        -- da área já marcada; não desloca nem transforma pixels.
        local moving = mode == "replace" and selection and
            Selection.contains(selection, math.floor(px), math.floor(py))
        if moving and info and (info.locked or info.alpha_lock) then
            if notice then
                notice("Desbloqueie a camada e desative Alpha Lock para mover pixels.")
            end
            return true
        end
        local action = "rectangle"
        if moving then
            if love.keyboard.isDown("lalt", "ralt") then
                action = "rotate_free"
            elseif love.keyboard.isDown("lshift", "rshift") then
                action = "scale_free"
            else
                action = "move"
            end
        end
        gesture = {
            kind = action, x = px, y = py, w = w, h = h, view = view,
            tool = tool, active_layer_id = info and info.id,
            preferences = preferences, layer = info and info.id,
            mode = mode, before_selection = before,
            before_selection_ref = before_ref,
            end_x = px, end_y = py
        }
        if not moving and mode == "replace" then selection = nil end
        return true
    end

    if tool == "eyedropper" then
        local r, g, b, a = Engine.sample(p, model, px, py)
        if not r then return true end
        if model.background_mode == "white" then
            r, g, b = r * a + (1 - a), g * a + (1 - a), b * a + (1 - a)
        elseif a == 0 then return true end
        local red = math.floor(r * 255 + 0.5)
        local green = math.floor(g * 255 + 0.5)
        local blue = math.floor(b * 255 + 0.5)
        colors:set_rgb(red, green, blue)
        model:set_color(red, green, blue)
        return true
    end

    local info = model:active_layer()
    if not info or info.locked or not info.visible then return false end
    -- O Balde usa o ponto clicado como semente: fora da máscara
    -- continua sem efeito. Pincel e borracha são áreas circulares e
    -- podem tocar a seleção mesmo com o centro fora dela; deixar o
    -- Engine.stroke aplicar Selection.coverage a cada pixel e
    -- acompanhar o gesto caso ele entre na região selecionada.
    if tool == "bucket" and selection and
       not Selection.contains(selection,
           math.floor(px), math.floor(py)) then return true end
    -- Evitar prometer efeitos que o motor Lua ainda não suporta.
    if info.alpha_lock and tool == "eraser" then
        -- Alpha Lock não permite remover nem criar transparência.
        if notice then notice("Borracha desativada enquanto Alpha Lock está ativo.") end
        return true
    end
    local rgb = {0, 0, 0}
    for i = 1, 3 do rgb[i] = math.max(0, math.min(1, (color[i] or 0) / 255)) end
    local normalized_opacity = math.max(0, math.min(100, opacity)) / 100

    if tool == "bucket" then
        -- A fonte composta é somente leitura; a aplicação e o histórico
        -- permanecem restritos à camada ativa, inclusive com Alpha Lock.
        local reference = p.bucket_sample_all and
            Engine.composite_pixel_source(p, model, true) or nil
        local _, reason = Engine.fill(p, info.id, px, py, rgb,
            normalized_opacity, info.alpha_lock, selection,
            p.bucket_tolerance or 0, p.bucket_global or false,
            p.bucket_rgb_only or false, p.bucket_diagonal or false,
            reference)
        if reason and notice then notice(reason) end
        return true
    end

    drawing = {layer = info.id, tool = tool, selection_at_start = selection,
               x = px, y = py, raw_x = px, raw_y = py,
               w = w, h = h, history_started = false,
               view = view, preferences = preferences,
               color = rgb, size = size, opacity = normalized_opacity,
               eraser = tool == "eraser", alpha_lock = info.alpha_lock,
               -- Em tinta parcial ou seleção feather, aplicar uma vez
               -- por pixel/gesto. Em tinta 100% com máscara binária,
               -- a repetição é naturalmente um no-op: evita mapa
               -- desnecessário em pinceladas grandes.
               covered_pixels = (normalized_opacity < 1 or
                   (selection and Selection.is_soft(selection)))
                   and {} or nil}
    paint(p, drawing, px, py)
    return true
end

function Bridge.mousemoved(model, rx, ry, scale)
    if project and project.model == model and
       ((drawing and not stroke_context_valid(model, drawing)) or
        (gesture and not gesture_context_valid(model, gesture))) then
        interrupt_active_gesture()
        return false
    end
    if gesture and project and project.model == model then
        local d = gesture
        local px, py = canvas_point(model, rx / scale, ry / scale,
                                    d.w, d.h, d.view, d.preferences)
        if px then
            local changed = math.abs(px - d.end_x) + math.abs(py - d.end_y) > 0.005
            d.end_x, d.end_y = px, py
            if d.kind == "move" and selection and d.layer then
                local dx, dy = Engine.move_delta(project, selection,
                                                  d.end_x - d.x, d.end_y - d.y)
                if (dx ~= 0 or dy ~= 0) and not d.preview then
                    d.preview = Engine.begin_move_preview(project, d.layer, selection)
                end
                if d.preview then
                    Engine.update_move_preview(project, selection, d.preview,
                                               d.end_x - d.x, d.end_y - d.y)
                end
            end
            if changed and (d.kind == "rotate_free" or
                            d.kind == "scale_free") then
                local degrees, sx, sy = affine_gesture_args(d)
                if degrees and selection and d.layer then
                    if not d.preview then
                        d.preview = Engine.begin_affine_gpu_preview(
                            project, d.layer, selection)
                    end
                    if d.preview then
                        Engine.update_affine_gpu_preview(project, selection,
                            d.preview, degrees, sx, sy)
                    end
                elseif d.preview then
                    d.preview.active = false
                end
            end
            if d.kind == "lasso" then
                local last = d.points[#d.points]
                if (px - last[1]) ^ 2 + (py - last[2]) ^ 2 >= 2.25 then
                    d.points[#d.points + 1] = {px, py}
                end
            end
        end
        return true
    end
    if not drawing or not project or project.model ~= model then return false end
    local d = drawing
    local px, py = canvas_point(model, rx / scale, ry / scale,
                                d.w, d.h, d.view, d.preferences, true)
    if px then continue_stroke(project, d, px, py) end
    return true
end

function Bridge.mousereleased(model, rx, ry, scale)
    -- O último segmento no mouseup também precisa do mesmo contexto
    -- válido; não pintar/confirmar com ferramenta ou camada trocada.
    if project and project.model == model and
       ((drawing and not stroke_context_valid(model, drawing)) or
        (gesture and not gesture_context_valid(model, gesture))) then
        interrupt_active_gesture()
        return false
    end
    local stroke = drawing
    drawing = nil
    -- A UI pode entregar o último movimento apenas no mouse release.
    -- Finalizar antes de descartar a pincelada mantém sua ponta e um
    -- único snapshot de histórico, sem duplicar o último dab.
    if stroke and project and project.model == model and
       rx and ry and scale then
        local x, y = canvas_point(model, rx / scale, ry / scale,
                                  stroke.w, stroke.h, stroke.view,
                                  stroke.preferences, true)
        if x then continue_stroke(project, stroke, x, y) end
    end
    local d = gesture
    gesture = nil
    if not d or not project or project.model ~= model then return end
    if rx and ry and scale then
        local x, y = canvas_point(model, rx / scale, ry / scale,
                                 d.w, d.h, d.view, d.preferences)
        if x then d.end_x, d.end_y = x, y end
    end
    -- Prévia é apenas uma textura de trabalho, liberada no fim do gesto.
    discard_preview(d)
    local mask, reason
    if d.kind == "rectangle" then
        mask, reason = Selection.rectangle(project.w, project.h,
                            d.x, d.y, d.end_x, d.end_y)
    elseif d.kind == "lasso" then
        if d.end_x then
            local last = d.points[#d.points]
            if not last or (d.end_x - last[1]) ^ 2 +
                    (d.end_y - last[2]) ^ 2 >= 2.25 then
                d.points[#d.points + 1] = {d.end_x, d.end_y}
            end
        end
        mask, reason = Selection.lasso(project.w, project.h, d.points)
    elseif d.kind == "move" and selection and d.layer then
        local ok, reason = Engine.move_selection(project, d.layer, selection,
            d.end_x - d.x, d.end_y - d.y)
        if ok then clear_mask_history() end
        return ok, reason
    elseif (d.kind == "rotate_free" or d.kind == "scale_free")
           and selection and d.layer then
        local degrees, sx, sy = affine_gesture_args(d)
        if not degrees then return false end
        local ok, reason = Engine.affine_selection(project, d.layer, selection,
                                       degrees, sx, sy, "bilinear")
        if ok then clear_mask_history() end
        return ok, reason
    end
    if mask then
        local combined, err = Selection.combine(selection, mask,
                                        d.mode or "replace",
                                        project.w, project.h)
        if err then return false, err end
        set_mask(combined, d.before_selection, true)
        return true
    end
    -- Um gesto inválido não deve consumir a seleção anterior nem
    -- criar um item de histórico pela limpeza inicial de replace.
    if d.kind == "rectangle" or d.kind == "lasso" then
        selection = d.before_selection
    end
    return false, reason
end

-- API de leitura para testes e extensões futuras; nunca expõe a máscara mutável.
function Bridge.selection_snapshot()
    return Selection.clone(selection)
end

function Bridge.clear_selection()
    -- Desmarcar durante um retângulo/laço replace deve partir da máscara
    -- anterior, não do nil provisório. Também encerra pintura pendente.
    interrupt_active_gesture()
    set_mask(nil)
end

function Bridge.selection_history_snapshot()
    return {undo = #mask_undo, redo = #mask_redo}
end

function Bridge.selection_undo()
    return mask_history_step(mask_undo, mask_redo)
end

function Bridge.selection_redo()
    return mask_history_step(mask_redo, mask_undo)
end

-- Estado de prévia somente leitura para testes de integração.
function Bridge.preview_snapshot()
    local d = gesture
    if not d or not d.preview then return nil end
    if d.preview.kind == "move" then
        local mask = Selection.clone(selection)
        if d.preview.active then
            Selection.translate(mask, d.preview.dx, d.preview.dy)
        end
        return {
            kind = "move", selection = mask, image = d.preview.image,
            active = d.preview.active, dx = d.preview.dx, dy = d.preview.dy,
            renders = d.preview.renders, mask_image = d.preview.mask_image
        }
    end
    if d.preview.kind == "affine_gpu" then
        return {
            kind = "affine_gpu", active = d.preview.active,
            image = d.preview.image, mask_image = d.preview.mask_image,
            degrees = d.preview.degrees, sx = d.preview.sx, sy = d.preview.sy,
            cx = d.preview.cx, cy = d.preview.cy,
            renders = d.preview.renders
        }
    end
    return {
        kind = "affine", selection = Selection.clone(d.preview.selection),
        pixels = d.preview.pixels
    }
end

function Bridge.undo()
    interrupt_active_gesture()
    if not project then return false end
    local before = Selection.clone(selection)
    local ok = Engine.undo(project, selection)
    if ok and not same_mask(before, selection) then clear_mask_history() end
    return ok
end
function Bridge.redo()
    interrupt_active_gesture()
    if not project then return false end
    local before = Selection.clone(selection)
    local ok = Engine.redo(project, selection)
    if ok and not same_mask(before, selection) then clear_mask_history() end
    return ok
end

-- Comandos de edição sobre a máscara atual, sem mudar o frontend.
-- Clipboard interno: não afirma integração com a área de transferência Windows.
function Bridge.selection_command(model, command, notice)
    if model.screen ~= "editor" then return false end
    local p = ensure(model)
    if not p then return false end
    -- Comandos de teclado/botão substituem a interação em andamento.
    -- Restaurar a seleção temporariamente oculta antes de aplicar
    -- Inverter/Selecionar tudo/Feather/Copiar/Colar/transformações.
    interrupt_active_gesture()

    -- São mudanças de máscara, NÃO operações raster: permitidas inclusive
    -- em camadas bloqueadas / Alpha Lock e sem adicionar passos ao histórico.
    if command == "select_all" or command == "invert_selection" or
       command == "expand_selection" or command == "contract_selection" or
       command == "feather_selection" then
        if (command == "expand_selection" or command == "contract_selection" or
            command == "feather_selection") and not selection then
            if notice then notice("Selecione uma área antes de expandir, contrair ou suavizar.") end
            return false
        end
        if command == "select_all" and selection and
           selection.count == p.w * p.h and
           not Selection.is_soft(selection) then return true end
        local next_mask, reason
        if command == "select_all" then
            next_mask, reason = Selection.all(p.w, p.h)
        elseif command == "invert_selection" then
            next_mask, reason = Selection.invert(selection, p.w, p.h)
        elseif command == "feather_selection" then
            -- Raio fixo conservador: o painel original não tem slider
            -- de feather. A API Selection.feather aceita 1..8.
            next_mask, reason = Selection.feather(selection, 2)
        else
            next_mask, reason = Selection.morph(selection,
                   command == "expand_selection" and "expand" or "contract")
        end
        if reason then
            if notice then notice(reason) end
            return false
        end
        -- Máscara nula válida: inversão integral ou contração até desaparecer.
        set_mask(next_mask)
        return true
    end

    local info = model:active_layer()
    if not info then return false end

    if command == "copy" then
        if not selection then
            if notice then notice("Selecione uma área antes de copiar.") end
            return false
        end
        local copied, reason = Engine.copy_selection(p, info.id, selection)
        if copied then clipboard = copied end
        if reason and notice then notice(reason) end
        return copied ~= nil
    end

    if info.locked or info.alpha_lock then
        if notice then notice("Desbloqueie a camada e desative Alpha Lock para editar a seleção.") end
        return false
    end
    if command == "cut" then
        if not selection then return false end
        local ok, result = Engine.cut_selection(p, info.id, selection)
        if ok then clipboard = result
        elseif notice and result then notice(result) end
        return ok
    elseif command == "paste" then
        local ok, result = Engine.paste_selection(p, info.id, clipboard,
                                                 nil, nil, selection)
        if ok then
            selection = result
            clear_mask_history()
        elseif notice and result then notice(result) end
        return ok
    elseif command == "rotate_cw" or command == "rotate_ccw" or
           command == "scale_half" or command == "scale_double" or
           command == "flip_horizontal" or command == "flip_vertical" then
        if not selection then return false end
        local ok, reason = Engine.reshape_selection(p, info.id, selection, command)
        if ok then clear_mask_history() end
        if not ok and notice and reason then notice(reason) end
        return ok
    end
    return false
end

-- Tolerância de varinha, por obra, em unidades de cor RGBA 8 bits.
-- Preferência de ferramenta: não marca pixels dirty nem cria histórico
-- de máscara/raster, e é persistida na terceira coluna de document.tsv.
function Bridge.wand_tolerance(model)
    local p = ensure(model)
    return p and (p.wand_tolerance or 0) or nil
end

function Bridge.adjust_wand_tolerance(model, delta, notice)
    local p = ensure(model)
    if not p or type(delta) ~= "number" or
       delta ~= math.floor(delta) then return false end
    local value = math.max(0, math.min(255, (p.wand_tolerance or 0) + delta))
    p.wand_tolerance = value
    if notice then
        notice(string.format("Varinha Mágica: tolerância %d/255", value))
    end
    return true
end

-- A Varinha Mágica pode selecionar apenas a ilha contígua ou todas as
-- regiões semelhantes da camada. É preferência por obra, não uma
-- modificação de pixels/máscara: não cria histórico nem marca dirty.
function Bridge.wand_global(model)
    local p = ensure(model)
    if not p then return nil end
    return p.wand_global == true
end

function Bridge.toggle_wand_global(model, notice)
    local p = ensure(model)
    if not p then return false end
    p.wand_global = not p.wand_global
    if notice then
        notice(p.wand_global and
            "Varinha Mágica: todas as regiões da camada" or
            "Varinha Mágica: somente região contígua")
    end
    return true
end

-- Fonte de referência independente do modo contíguo/global. Nenhum
-- raster, máscara ou histórico é alterado pelo atalho.
function Bridge.wand_sample_all(model)
    local p = ensure(model)
    if not p then return nil end
    return p.wand_sample_all == true
end

function Bridge.toggle_wand_sample_all(model, notice)
    local p = ensure(model)
    if not p then return false end
    p.wand_sample_all = not p.wand_sample_all
    if notice then
        notice(p.wand_sample_all and
            "Varinha Mágica: amostrar todas as camadas visíveis" or
            "Varinha Mágica: amostrar somente a camada ativa")
    end
    return true
end

-- 4-vizinhos é a conectividade histórica. 8-vizinhos inclui somente
-- os cantos na varinha CONTÍGUA; modo global não usa conectividade.
function Bridge.wand_diagonal(model)
    local p = ensure(model)
    if not p then return nil end
    return p.wand_diagonal == true
end

function Bridge.toggle_wand_diagonal(model, notice)
    local p = ensure(model)
    if not p then return false end
    p.wand_diagonal = not p.wand_diagonal
    if notice then
        notice(p.wand_diagonal and
            "Varinha Mágica: contiguidade por 8 vizinhos (diagonais)" or
            "Varinha Mágica: contiguidade por 4 vizinhos")
    end
    return true
end

-- Comparação RGB-only independente da fonte e da conectividade.
-- Continua selecionando geometria, sem alterar alfa ou pixels da obra.
function Bridge.wand_rgb_only(model)
    local p = ensure(model)
    if not p then return nil end
    return p.wand_rgb_only == true
end

function Bridge.toggle_wand_rgb_only(model, notice)
    local p = ensure(model)
    if not p then return false end
    p.wand_rgb_only = not p.wand_rgb_only
    if notice then
        notice(p.wand_rgb_only and
            "Varinha Mágica: comparar apenas RGB (ignorar alfa)" or
            "Varinha Mágica: comparar RGBA (inclui alfa)")
    end
    return true
end

-- Tolerância própria do Balde, independente da Varinha Mágica.
-- Não modifica a máscara, o histórico ou os pixels até o preenchimento.
function Bridge.bucket_tolerance(model)
    local p = ensure(model)
    return p and (p.bucket_tolerance or 0) or nil
end

function Bridge.adjust_bucket_tolerance(model, delta, notice)
    local p = ensure(model)
    if not p or type(delta) ~= "number" or
       delta ~= math.floor(delta) then return false end
    local value = math.max(0, math.min(255, (p.bucket_tolerance or 0) + delta))
    p.bucket_tolerance = value
    if notice then
        notice(string.format("Balde: tolerância RGBA %d/255", value))
    end
    return true
end

-- Seleção contígua/global do Balde, independente da Varinha.
-- Alterar o modo é uma preferência, não pinta nem altera históricos.
function Bridge.bucket_global(model)
    local p = ensure(model)
    if not p then return nil end
    return p.bucket_global == true
end

function Bridge.toggle_bucket_global(model, notice)
    local p = ensure(model)
    if not p then return false end
    p.bucket_global = not p.bucket_global
    if notice then
        notice(p.bucket_global and
            "Balde: preencher todas as regiões de cor semelhante" or
            "Balde: preencher somente região contígua")
    end
    return true
end

-- Comparação independente do modo global/contíguo do Balde e da Varinha.
-- Altera somente a preferência; a transparência dos pixels permanece.
function Bridge.bucket_rgb_only(model)
    local p = ensure(model)
    if not p then return nil end
    return p.bucket_rgb_only == true
end

function Bridge.toggle_bucket_rgb_only(model, notice)
    local p = ensure(model)
    if not p then return false end
    p.bucket_rgb_only = not p.bucket_rgb_only
    if notice then
        notice(p.bucket_rgb_only and
            "Balde: comparar apenas RGB (ignorar transparência)" or
            "Balde: comparar RGBA (incluir transparência)")
    end
    return true
end

-- 8 vizinhos (diagonais) só afeta o preenchimento contíguo.
-- No modo global a conectividade não altera os pixels encontrados.
function Bridge.bucket_diagonal(model)
    local p = ensure(model)
    if not p then return nil end
    return p.bucket_diagonal == true
end

function Bridge.toggle_bucket_diagonal(model, notice)
    local p = ensure(model)
    if not p then return false end
    p.bucket_diagonal = not p.bucket_diagonal
    if notice then
        notice(p.bucket_diagonal and
            "Balde: conectividade por 8 vizinhos (diagonais)" or
            "Balde: conectividade por 4 vizinhos")
    end
    return true
end

-- Fonte da comparação do Balde (camada ativa ou composição visível).
-- Mudar a fonte é uma preferência e não escreve pixels nem máscara.
function Bridge.bucket_sample_all(model)
    local p = ensure(model)
    if not p then return nil end
    return p.bucket_sample_all == true
end

function Bridge.toggle_bucket_sample_all(model, notice)
    local p = ensure(model)
    if not p then return false end
    p.bucket_sample_all = not p.bucket_sample_all
    if notice then
        notice(p.bucket_sample_all and
            "Balde: amostrar todas as camadas visíveis" or
            "Balde: amostrar somente a camada ativa")
    end
    return true
end

function Bridge.keypressed(key, model, notice)
    if model.screen ~= "editor" then return false end
    if key == "escape" then
        if gesture or drawing then
            -- Esc interrompe o gesto em curso (inclusive pincel/borracha)
            -- sem remover a seleção já confirmada. Pixels que foram
            -- pintados antes do Esc mantêm seu histórico reversível.
            interrupt_active_gesture()
            return true
        elseif selection then
            Bridge.clear_selection()
            return true
        end
    end
    if not love.keyboard.isDown("lctrl", "rctrl") then return false end
    if key == "d" then Bridge.clear_selection(); return true end
    local shift = love.keyboard.isDown("lshift", "rshift")
    local alt = love.keyboard.isDown("lalt", "ralt")
    if alt and (key == "z" or key == "y") then
        -- Capturar também com pilha vazia: nunca deixar Ctrl+Alt+Z/Y
        -- cair nos atalhos de histórico raster da interface original.
        if key == "z" then Bridge.selection_undo()
        else Bridge.selection_redo() end
        return true
    end
    if alt and not shift then
        if key == "g" then
            return Bridge.toggle_wand_global(model, notice)
        elseif key == "t" then
            return Bridge.toggle_wand_sample_all(model, notice)
        elseif key == "8" then
            return Bridge.toggle_wand_diagonal(model, notice)
        elseif key == "r" then
            return Bridge.toggle_wand_rgb_only(model, notice)
        elseif key == "b" then
            return Bridge.toggle_bucket_global(model, notice)
        elseif key == "m" then
            return Bridge.toggle_bucket_rgb_only(model, notice)
        elseif key == "9" then
            return Bridge.toggle_bucket_diagonal(model, notice)
        elseif key == "v" then
            return Bridge.toggle_bucket_sample_all(model, notice)
        elseif key == "pageup" then
            return Bridge.adjust_bucket_tolerance(model, 16, notice)
        elseif key == "pagedown" then
            return Bridge.adjust_bucket_tolerance(model, -16, notice)
        elseif key == "home" then
            local current = Bridge.bucket_tolerance(model)
            return current ~= nil and
                Bridge.adjust_bucket_tolerance(model, -current, notice)
        elseif key == "right" then
            return Bridge.adjust_wand_tolerance(model, 16, notice)
        elseif key == "left" then
            return Bridge.adjust_wand_tolerance(model, -16, notice)
        elseif key == "0" then
            local current = Bridge.wand_tolerance(model)
            return current ~= nil and
                Bridge.adjust_wand_tolerance(model, -current, notice)
        elseif key == "f" then
            Bridge.selection_command(model, "feather_selection", notice)
            return true
        elseif key == "up" then
            Bridge.selection_command(model, "expand_selection", notice)
            return true
        elseif key == "down" then
            Bridge.selection_command(model, "contract_selection", notice)
            return true
        end
    end
    if not shift and key == "a" then
        return Bridge.selection_command(model, "select_all", notice)
    end
    if shift then
        if key == "i" then
            return Bridge.selection_command(model, "invert_selection", notice)
        end
        if key == "r" then
            Bridge.selection_command(model, "rotate_cw", notice)
            return true
        elseif key == "l" then
            Bridge.selection_command(model, "rotate_ccw", notice)
            return true
        elseif key == "up" then
            Bridge.selection_command(model, "scale_double", notice)
            return true
        elseif key == "down" then
            Bridge.selection_command(model, "scale_half", notice)
            return true
        elseif key == "h" then
            Bridge.selection_command(model, "flip_horizontal", notice)
            return true
        elseif key == "v" then
            Bridge.selection_command(model, "flip_vertical", notice)
            return true
        end
    end
    if key == "c" then Bridge.selection_command(model, "copy", notice); return true end
    if key == "x" then Bridge.selection_command(model, "cut", notice); return true end
    if key == "v" then Bridge.selection_command(model, "paste", notice); return true end
    if key == "z" then return Bridge.undo()
    elseif key == "y" then return Bridge.redo()
    elseif key == "s" then Bridge.save(); return true end
    return false
end

return Bridge
