-- Motor de pixels Lua/LÖVE. Nenhuma DLL do projeto é carregada.
local Engine = {}
local MAX_AXIS = 4096
local HISTORY_BYTES = 32 * 1024 * 1024
local HISTORY_STEPS = 8

function Engine.supports(w, h)
    if type(w) ~= "number" or type(h) ~= "number"
        or w ~= math.floor(w) or h ~= math.floor(h)
        or w < 1 or h < 1 or w > MAX_AXIS or h > MAX_AXIS then
        return false, "Motor Lua: dimensões permitidas de 1 a 4096 px por eixo."
    end
    local limits = love.graphics.getSystemLimits()
    if limits.texturesize and math.max(w, h) > limits.texturesize then
        return false, "O dispositivo não suporta essa dimensão de textura."
    end
    return true
end

local function new_layer(w, h)
    local pixels = love.image.newImageData(w, h)
    local image = love.graphics.newImage(pixels)
    return {pixels = pixels, image = image}
end

function Engine.new(w, h)
    local ok, err = Engine.supports(w, h)
    assert(ok, err)
    return {w = w, h = h, layers = {}, undo = {}, redo = {}, dirty = false}
end

function Engine.sync(project, model)
    local used = {}
    for _, info in ipairs(model.layers) do
        used[info.id] = true
        if not project.layers[info.id] then
            project.layers[info.id] = new_layer(project.w, project.h)
            project.dirty = true
        end
    end
    for id in pairs(project.layers) do
        if not used[id] then project.layers[id] = nil; project.dirty = true end
    end
end

local function clone_pixels(project, layer)
    local copy = love.image.newImageData(project.w, project.h)
    copy:paste(layer.pixels, 0, 0, 0, 0, project.w, project.h)
    return copy
end

function Engine.begin_stroke(project, id)
    local layer = assert(project.layers[id], "Camada inexistente")
    if project.w * project.h * 4 > HISTORY_BYTES then return end
    project.undo[#project.undo + 1] = {id = id, pixels = clone_pixels(project, layer)}
    if #project.undo > HISTORY_STEPS then table.remove(project.undo, 1) end
    project.redo = {}
end

local function restore(project, from, to)
    local entry = table.remove(from)
    if not entry then return false end
    local layer = project.layers[entry.id]
    if not layer then return false end
    to[#to + 1] = {id = entry.id, pixels = clone_pixels(project, layer)}
    if #to > HISTORY_STEPS then table.remove(to, 1) end
    layer.pixels = entry.pixels
    layer.image:replacePixels(entry.pixels)
    project.dirty = true
    return true
end

function Engine.undo(project) return restore(project, project.undo, project.redo) end
function Engine.redo(project) return restore(project, project.redo, project.undo) end

-- Composição source-over com RGB não pré-multiplicado, em canais 0..1.
local function dab(layer, w, h, x, y, radius, rgb, alpha, eraser)
    local data = layer.pixels
    local xmin = math.max(0, math.floor(x - radius))
    local xmax = math.min(w - 1, math.ceil(x + radius))
    local ymin = math.max(0, math.floor(y - radius))
    local ymax = math.min(h - 1, math.ceil(y + radius))
    local rr = radius * radius
    for py = ymin, ymax do
        for px = xmin, xmax do
            local dx, dy = px + 0.5 - x, py + 0.5 - y
            if dx * dx + dy * dy <= rr then
                local dr, dg, db, da = data:getPixel(px, py)
                if eraser then
                    local a = da * (1 - alpha)
                    if a < 0.0001 then data:setPixel(px, py, 0, 0, 0, 0)
                    else data:setPixel(px, py, dr, dg, db, a) end
                else
                    local a = alpha + da * (1 - alpha)
                    if a > 0 then
                        data:setPixel(px, py,
                            (rgb[1] * alpha + dr * da * (1 - alpha)) / a,
                            (rgb[2] * alpha + dg * da * (1 - alpha)) / a,
                            (rgb[3] * alpha + db * da * (1 - alpha)) / a, a)
                    end
                end
            end
        end
    end
end

function Engine.stroke(project, id, x0, y0, x1, y1, diameter, rgb, alpha, eraser)
    local layer = assert(project.layers[id], "Camada inexistente")
    local radius = math.max(0.75, math.min(256, diameter) / 2)
    alpha = math.max(0, math.min(1, alpha))
    if alpha == 0 then return end
    local dx, dy = x1 - x0, y1 - y0
    local steps = math.max(1, math.ceil(math.sqrt(dx * dx + dy * dy) / math.max(0.5, radius * 0.5)))
    for i = 0, steps do
        local t = i / steps
        dab(layer, project.w, project.h, x0 + dx * t, y0 + dy * t,
            radius, rgb, alpha, eraser)
    end
    layer.image:replacePixels(layer.pixels)
    project.dirty = true
end

function Engine.draw(project, model, interpolation)
    love.graphics.push("all")
    love.graphics.setBlendMode("alpha", "alphamultiply")
    for _, info in ipairs(model.layers) do
        if info.visible then
            local layer = project.layers[info.id]
            if layer then
                local opacity = math.max(0, math.min(100, info.opacity or 100)) / 100
                layer.image:setFilter(interpolation == "pixelated" and "nearest" or "linear")
                love.graphics.setColor(1, 1, 1, opacity)
                love.graphics.draw(layer.image, -project.w / 2, -project.h / 2)
            end
        end
    end
    love.graphics.pop()
end

function Engine.load_layer(project, id, filename)
    if not love.filesystem.getInfo(filename) then return false end
    local ok, data = pcall(love.image.newImageData, filename)
    if not ok or data:getWidth() ~= project.w or data:getHeight() ~= project.h then
        return false
    end
    project.layers[id] = {pixels = data, image = love.graphics.newImage(data)}
    return true
end

return Engine
