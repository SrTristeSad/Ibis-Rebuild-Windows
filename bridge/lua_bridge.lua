-- Liga o Ibis-Lua (interface intacta) ao motor Lua/LÖVE.
local Engine = require("lua_engine")
local Bridge = {}
local ROOT = "lua-artworks"
local records, project, gallery_ref, drawing = {}, nil, nil, nil
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
    gallery_ref = gallery
    project = Engine.new(model.document.width, model.document.height)
    project.model, project.document, project.id = model, model.document, id
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
    local record = records[id]
    project = Engine.new(model.document.width, model.document.height)
    project.model, project.document, project.id = model, model.document, id
    if record then saved_layers(model, project_path(record.key), project) end
    Engine.sync(project, model)
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
            safe(project.model.background_mode or "white")}, "\t")))
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
            Bridge.save()
        end
        return original(self, ...)
    end
end

function Bridge.draw(model, visual)
    local p = ensure(model)
    if p then Engine.draw(p, model, visual and visual.interpolation) end
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

local function canvas_point(model, x, y, w, h, view, preferences)
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
    if px < 0 or px >= dw or py < 0 or py >= dh then return nil end
    return px, py
end

local function paint(p, d, x, y)
    Engine.stroke(p, d.layer, d.x, d.y, x, y, d.size, d.color,
                  d.opacity, d.eraser, d.alpha_lock)
    d.x, d.y = x, y
end

function Bridge.mousepressed(model, id, x, y, w, h, view, preferences,
                             color, size, opacity, colors, notice)
    if model.screen ~= "editor" or love.keyboard.isDown("space") then return false end
    local tool = model.active_tool
    if tool ~= "brush" and tool ~= "eraser" and
       tool ~= "bucket" and tool ~= "eyedropper" then return false end
    local p = ensure(model)
    if not p then return false end
    local px, py = canvas_point(model, x, y, w, h, view, preferences)
    if not px then return false end

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
        local _, reason = Engine.fill(p, info.id, px, py, rgb,
            normalized_opacity, info.alpha_lock)
        if reason and notice then notice(reason) end
        return true
    end

    Engine.begin_stroke(p, info.id)
    drawing = {layer = info.id, x = px, y = py, w = w, h = h,
               view = view, preferences = preferences,
               color = rgb, size = size, opacity = normalized_opacity,
               eraser = tool == "eraser", alpha_lock = info.alpha_lock}
    paint(p, drawing, px, py)
    return true
end

function Bridge.mousemoved(model, rx, ry, scale)
    if not drawing or not project or project.model ~= model then return false end
    local d = drawing
    local px, py = canvas_point(model, rx / scale, ry / scale,
                                d.w, d.h, d.view, d.preferences)
    if px then paint(project, d, px, py) end
    return true
end

function Bridge.mousereleased() drawing = nil end
function Bridge.undo() if project then return Engine.undo(project) end return false end
function Bridge.redo() if project then return Engine.redo(project) end return false end

function Bridge.keypressed(key, model)
    if model.screen ~= "editor" or
       not love.keyboard.isDown("lctrl", "rctrl") then return false end
    if key == "z" then return Bridge.undo()
    elseif key == "y" then return Bridge.redo()
    elseif key == "s" then Bridge.save(); return true end
    return false
end

return Bridge
