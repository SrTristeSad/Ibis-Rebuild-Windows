-- Liga o Ibis-Lua (interface intacta) ao motor Lua/LÖVE.
local Engine = require("lua_engine")
local Bridge = {}
local ROOT = "lua-artworks"
local records, project, gallery_ref, drawing = {}, nil, nil, nil
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
    for line in data:gmatch("[^\r\n]+") do
        local id, name, visible, opacity = line:match("^(%d+)\t([^\t]*)\t([01])\t(%d+)$")
        id, opacity = tonumber(id), tonumber(opacity)
        if id and opacity and opacity <= 100 and #layers < 32 then
            layers[#layers + 1] = {id = id, name = name, visible = visible == "1",
                opacity = opacity, blending = "Normal", clipping = false,
                alpha_lock = false, locked = false}
        end
    end
    if #layers == 0 then return end
    model.layers, model.next_layer_id = layers, 1
    for _, info in ipairs(layers) do
        model.next_layer_id = math.max(model.next_layer_id, info.id + 1)
        Engine.load_layer(p, info.id, path .. "/layer_" .. info.id .. ".png")
    end
    model.active_layer_id = layers[#layers].id
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
                tostring(info.opacity or 100)}, "\t")
        end
    end
    assert(love.filesystem.write(path .. "/layers.tsv", table.concat(lines, "\n")))
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
                  d.opacity, d.eraser)
    d.x, d.y = x, y
end

function Bridge.mousepressed(model, id, x, y, w, h, view, preferences, color, size, opacity)
    if model.screen ~= "editor" or
        (model.active_tool ~= "brush" and model.active_tool ~= "eraser") or
        love.keyboard.isDown("space") then return false end
    local p = ensure(model)
    if not p then return false end
    local px, py = canvas_point(model, x, y, w, h, view, preferences)
    if not px then return false end
    local info = model:active_layer()
    if not info or info.locked or not info.visible then return false end
    Engine.begin_stroke(p, info.id)
    local rgb = {0, 0, 0}
    for i = 1, 3 do rgb[i] = math.max(0, math.min(1, (color[i] or 0) / 255)) end
    drawing = {layer = info.id, x = px, y = py, w = w, h = h,
               view = view, preferences = preferences,
               color = rgb, size = size,
               opacity = math.max(0, math.min(100, opacity)) / 100,
               eraser = model.active_tool == "eraser"}
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
