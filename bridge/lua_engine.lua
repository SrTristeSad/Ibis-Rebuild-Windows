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


-- Amostragem da composição visível em modo Normal, com opacidade por camada.
-- RGB retornado é não pré-multiplicado; não altera nenhum pixel do projeto.
function Engine.sample(project, model, x, y)
    x, y = math.floor(x), math.floor(y)
    if x < 0 or y < 0 or x >= project.w or y >= project.h then return nil end
    local r, g, b, a = 0, 0, 0, 0
    for _, info in ipairs(model.layers) do
        local layer = project.layers[info.id]
        if layer and info.visible then
            local sr, sg, sb, sa = layer.pixels:getPixel(x, y)
            sa = sa * math.max(0, math.min(100, info.opacity or 100)) / 100
            if sa > 0 then
                local next_a = sa + a * (1 - sa)
                r = (sr * sa + r * a * (1 - sa)) / next_a
                g = (sg * sa + g * a * (1 - sa)) / next_a
                b = (sb * sa + b * a * (1 - sa)) / next_a
                a = next_a
            end
        end
    end
    return r, g, b, a
end

-- Balde contíguo, cor RGBA exata (tolerância de 1/510 por canal).
-- Algoritmo scanline sem recursão; não extrapola os limites do buffer.
-- Impõe teto conservador de pixels para evitar travamentos da UI Lua.
function Engine.fill(project, id, x, y, rgb, alpha)
    if project.w * project.h > 1024 * 1024 then
        return false, "Balde Lua limitado a documentos de até 1.048.576 pixels."
    end
    x, y = math.floor(x), math.floor(y)
    if x < 0 or y < 0 or x >= project.w or y >= project.h then
        return false
    end
    alpha = math.max(0, math.min(1, alpha))
    if alpha <= 0 then return false end
    local layer = assert(project.layers[id], "Camada inexistente")
    local data = layer.pixels
    local tr, tg, tb, ta = data:getPixel(x, y)
    local na = alpha + ta * (1 - alpha)
    local nr = (rgb[1] * alpha + tr * ta * (1 - alpha)) / na
    local ng = (rgb[2] * alpha + tg * ta * (1 - alpha)) / na
    local nb = (rgb[3] * alpha + tb * ta * (1 - alpha)) / na
    local epsilon = 0.5 / 255
    if math.abs(nr - tr) < epsilon and math.abs(ng - tg) < epsilon
       and math.abs(nb - tb) < epsilon and math.abs(na - ta) < epsilon then
        return false
    end

    local w, h = project.w, project.h
    local function matches(px, py)
        if px < 0 or py < 0 or px >= w or py >= h then return false end
        local r, g, b, a = data:getPixel(px, py)
        local tolerance = 1 / 510
        return math.abs(r - tr) <= tolerance and math.abs(g - tg) <= tolerance
           and math.abs(b - tb) <= tolerance and math.abs(a - ta) <= tolerance
    end
    local function paint(px, py)
        local dr, dg, db, da = data:getPixel(px, py)
        local out_a = alpha + da * (1 - alpha)
        data:setPixel(px, py,
            (rgb[1] * alpha + dr * da * (1 - alpha)) / out_a,
            (rgb[2] * alpha + dg * da * (1 - alpha)) / out_a,
            (rgb[3] * alpha + db * da * (1 - alpha)) / out_a, out_a)
    end
    Engine.begin_stroke(project, id)
    local stack = {{x, y}}
    while #stack > 0 do
        local point = table.remove(stack)
        local sx, sy = point[1], point[2]
        if matches(sx, sy) then
            while matches(sx - 1, sy) do sx = sx - 1 end
            local above, below = false, false
            while matches(sx, sy) do
                paint(sx, sy)
                if matches(sx, sy - 1) then
                    if not above then stack[#stack + 1] = {sx, sy - 1} end
                    above = true
                else above = false end
                if matches(sx, sy + 1) then
                    if not below then stack[#stack + 1] = {sx, sy + 1} end
                    below = true
                else below = false end
                sx = sx + 1
            end
        end
    end
    layer.image:replacePixels(data)
    project.dirty = true
    return true
end

-- Miniatura RGBA composta somente com pixels Lua, sem alterar a obra.
function Engine.thumbnail(project, model)
    local tw, th = math.min(128, project.w), math.min(128, project.h)
    local pixels = love.image.newImageData(tw, th)
    for py = 0, th - 1 do
        for px = 0, tw - 1 do
            local sx = math.min(project.w - 1, math.floor((px + 0.5) * project.w / tw))
            local sy = math.min(project.h - 1, math.floor((py + 0.5) * project.h / th))
            local r, g, b, a = Engine.sample(project, model, sx, sy)
            pixels:setPixel(px, py, r, g, b, a)
        end
    end
    return pixels
end

return Engine
