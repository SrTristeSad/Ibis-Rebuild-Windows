-- Motor de pixels Lua/LÖVE. Nenhuma DLL do projeto é carregada.
local Engine = {}
local Selection = require("lua_selection")
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

local function restore(project, from, to, selection)
    local entry = table.remove(from)
    if not entry then return false end
    local layer = project.layers[entry.id]
    if not layer then return false end
    local current = {id = entry.id, pixels = clone_pixels(project, layer)}
    if entry.selection_ref and entry.selection_state then
        current.selection_ref = entry.selection_ref
        -- Captura a geometria presente ANTES da restauração, para redo.
        if selection == entry.selection_ref then
            current.selection_state = Selection.clone(selection)
        else
            -- A seleção atual pode ter sido desmarcada ou substituída.
            -- Nesse caso só os pixels do documento são revertidos.
            current.selection_state = entry.selection_state
        end
    end
    to[#to + 1] = current
    if #to > HISTORY_STEPS then table.remove(to, 1) end
    layer.pixels = entry.pixels
    layer.image:replacePixels(entry.pixels)
    if selection and selection == entry.selection_ref and entry.selection_state then
        Selection.restore(selection, entry.selection_state)
    end
    project.dirty = true
    return true
end

function Engine.undo(project, selection)
    return restore(project, project.undo, project.redo, selection)
end
function Engine.redo(project, selection)
    return restore(project, project.redo, project.undo, selection)
end

-- Composição source-over com RGB não pré-multiplicado, em canais 0..1.
local function dab(layer, w, h, x, y, radius, rgb, alpha, eraser, alpha_lock, selection)
    local data = layer.pixels
    local xmin = math.max(0, math.floor(x - radius))
    local xmax = math.min(w - 1, math.ceil(x + radius))
    local ymin = math.max(0, math.floor(y - radius))
    local ymax = math.min(h - 1, math.ceil(y + radius))
    local rr = radius * radius
    for py = ymin, ymax do
        for px = xmin, xmax do
            local dx, dy = px + 0.5 - x, py + 0.5 - y
            local effective_alpha = alpha * Selection.coverage(selection, px, py)
            if dx * dx + dy * dy <= rr and effective_alpha > 0 then
                local dr, dg, db, da = data:getPixel(px, py)
                local alpha = effective_alpha
                if alpha_lock then
                    -- Alpha Lock changes RGB only where alpha already exists.
                    -- The alpha channel is preserved exactly; erasing is a no-op.
                    if da > 0 and not eraser then
                        data:setPixel(px, py,
                            dr * (1 - alpha) + rgb[1] * alpha,
                            dg * (1 - alpha) + rgb[2] * alpha,
                            db * (1 - alpha) + rgb[3] * alpha, da)
                    end
                elseif eraser then
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

function Engine.stroke(project, id, x0, y0, x1, y1, diameter, rgb, alpha, eraser, alpha_lock, selection)
    local layer = assert(project.layers[id], "Camada inexistente")
    local radius = math.max(0.75, math.min(256, diameter) / 2)
    alpha = math.max(0, math.min(1, alpha))
    if alpha == 0 then return end
    local dx, dy = x1 - x0, y1 - y0
    local steps = math.max(1, math.ceil(math.sqrt(dx * dx + dy * dy) / math.max(0.5, radius * 0.5)))
    for i = 0, steps do
        local t = i / steps
        dab(layer, project.w, project.h, x0 + dx * t, y0 + dy * t,
            radius, rgb, alpha, eraser, alpha_lock, selection)
    end
    layer.image:replacePixels(layer.pixels)
    project.dirty = true
end

-- O recorte usa o alfa da camada-base mais próxima abaixo das camadas
-- marcadas como Clipping. O raster original da camada superior não muda.
local function clip_base(model, index)
    if not model.layers[index].clipping then return nil end
    for i = index - 1, 1, -1 do
        if not model.layers[i].clipping then return model.layers[i] end
    end
    return nil
end

-- Nomes do seletor original do Ibis-Lua. Não inventar modos de UI.
local blend_ids = {
    Normal = 0, Multiply = 1, Screen = 2, Overlay = 3, Darken = 4,
    Lighten = 5, ["Color Burn"] = 6, ["Color Dodge"] = 7,
    ["Soft Light"] = 8
}
Engine.blend_ids = blend_ids

local function clamp01(x) return math.max(0, math.min(1, x)) end

local function blend_channel(mode, base, top)
    if mode == 1 then return base * top end
    if mode == 2 then return base + top - base * top end
    if mode == 3 then
        return base <= 0.5 and 2 * base * top or
            1 - 2 * (1 - base) * (1 - top)
    end
    if mode == 4 then return math.min(base, top) end
    if mode == 5 then return math.max(base, top) end
    if mode == 6 then
        if top <= 0 then return 0 end
        return math.max(0, 1 - (1 - base) / top)
    end
    if mode == 7 then
        if top >= 1 then return 1 end
        return math.min(1, base / (1 - top))
    end
    if mode == 8 then
        if top <= 0.5 then
            return base - (1 - 2 * top) * base * (1 - base)
        end
        local d = base <= 0.25 and ((16 * base - 12) * base + 4) * base
            or math.sqrt(base)
        return base + (2 * top - 1) * (d - base)
    end
    return top
end

-- Composição de blend com alfa straight, segundo a fórmula source-over
-- separável. Compartilhada entre o conta-gotas/preview CPU e shader GPU.
local function compose_channel(base, top, base_alpha, top_alpha, mode, out_alpha)
    if out_alpha <= 0 then return 0 end
    local mixed = blend_channel(mode, base, top)
    return clamp01((
        top_alpha * (1 - base_alpha) * top +
        base_alpha * (1 - top_alpha) * base +
        top_alpha * base_alpha * mixed
    ) / out_alpha)
end

local blending_shader
local function shader_for_layers()
    if not blending_shader then
        blending_shader = love.graphics.newShader([[
            extern Image backdropImage;
            extern Image clipImage;
            extern number sourceOpacity;
            extern number clipOpacity;
            extern number clipEnabled;
            extern number blendMode;

            float blendComponent(float b, float t, float mode) {
                if (mode < 0.5) return t;
                if (mode < 1.5) return b * t;
                if (mode < 2.5) return b + t - b * t;
                if (mode < 3.5) return b <= 0.5 ? 2.0 * b * t
                    : 1.0 - 2.0 * (1.0 - b) * (1.0 - t);
                if (mode < 4.5) return min(b, t);
                if (mode < 5.5) return max(b, t);
                if (mode < 6.5) return t <= 0.0 ? 0.0
                    : max(0.0, 1.0 - (1.0 - b) / t);
                if (mode < 7.5) return t >= 1.0 ? 1.0
                    : min(1.0, b / (1.0 - t));
                float d = b <= 0.25 ? ((16.0 * b - 12.0) * b + 4.0) * b
                    : sqrt(b);
                return t <= 0.5 ? b - (1.0 - 2.0 * t) * b * (1.0 - b)
                    : b + (2.0 * t - 1.0) * (d - b);
            }

            vec4 effect(vec4 color, Image sourceImage,
                        vec2 uv, vec2 pixelCoords) {
                vec4 base = Texel(backdropImage, uv);
                vec4 top = Texel(sourceImage, uv) * color;
                float ta = top.a * sourceOpacity;
                if (clipEnabled > 0.5) {
                    ta *= Texel(clipImage, uv).a * clipOpacity;
                }
                float ba = base.a;
                float outAlpha = ta + ba * (1.0 - ta);
                if (outAlpha <= 0.0) return vec4(0.0);
                vec3 mixed;
                for (int i = 0; i < 3; i++) {
                    float blendValue = blendComponent(base[i], top[i], blendMode);
                    mixed[i] = (
                        ta * (1.0 - ba) * top[i] +
                        ba * (1.0 - ta) * base[i] +
                        ta * ba * blendValue
                    ) / outAlpha;
                }
                return vec4(clamp(mixed, 0.0, 1.0), outAlpha);
            }
        ]])
    end
    return blending_shader
end

local function composite_canvases(project)
    if not project.compose_canvases then
        project.compose_canvases = {
            love.graphics.newCanvas(project.w, project.h),
            love.graphics.newCanvas(project.w, project.h)
        }
    end
    return project.compose_canvases
end

function Engine.draw(project, model, interpolation)
    local destination = love.graphics.getCanvas()
    love.graphics.push("all")
    love.graphics.setShader()
    local filter = interpolation == "pixelated" and "nearest" or "linear"
    local needs_compositing = false
    for _, info in ipairs(model.layers) do
        if info.visible and (info.clipping or
           (info.blending or "Normal") ~= "Normal") then
            needs_compositing = true
            break
        end
    end

    if not needs_compositing then
        -- Preserva o caminho rápido das camadas normais já testado.
        love.graphics.setBlendMode("alpha", "alphamultiply")
        for _, info in ipairs(model.layers) do
            if info.visible then
                local layer = project.layers[info.id]
                if layer then
                    local opacity = clamp01((info.opacity or 100) / 100)
                    layer.image:setFilter(filter)
                    love.graphics.setColor(1, 1, 1, opacity)
                    love.graphics.draw(layer.image,
                        -project.w / 2, -project.h / 2)
                end
            end
        end
        love.graphics.pop()
        return
    end

    local canvases = composite_canvases(project)
    -- A UI do Ibis-Lua aplica zoom, rotação e pan ao canvas principal.
    -- Renderizar as camadas offscreen requer coordenadas locais não transformadas.
    love.graphics.push()
    love.graphics.origin()
    local front, back = canvases[1], canvases[2]
    love.graphics.setCanvas(front)
    love.graphics.clear(0, 0, 0, 0)
    -- Canvas intermediário guarda RGB straight: o modo alpha padrão
    -- premultiplica RGB mesmo quando o BlendMode é "replace".
    love.graphics.setBlendMode("replace", "premultiplied")
    local shader = shader_for_layers()

    for index, info in ipairs(model.layers) do
        local layer = project.layers[info.id]
        local base = clip_base(model, index)
        local mask = base and project.layers[base.id] or nil
        if info.visible and layer and
           (not info.clipping or (mask and base.visible)) then
            layer.image:setFilter(filter)
            front:setFilter(filter)
            if mask then mask.image:setFilter(filter) end
            love.graphics.setCanvas(back)
            love.graphics.setShader(shader)
            shader:send("backdropImage", front)
            shader:send("clipImage", mask and mask.image or layer.image)
            shader:send("clipEnabled", mask and 1 or 0)
            shader:send("clipOpacity", mask and
                clamp01((base.opacity or 100) / 100) or 1)
            shader:send("sourceOpacity", clamp01((info.opacity or 100) / 100))
            shader:send("blendMode", assert(blend_ids[info.blending or "Normal"],
                "Modo de mesclagem não suportado"))
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.draw(layer.image, 0, 0)
            front, back = back, front
        end
    end
    love.graphics.setShader()
    love.graphics.pop()
    love.graphics.setCanvas(destination)
    love.graphics.setBlendMode("alpha", "alphamultiply")
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(front, -project.w / 2, -project.h / 2)
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


-- Fonte de pixels virtual para seleção e conta-gotas: prepara uma única
-- vez a pilha visível, sem criar uma textura composta nem tocar no raster.
-- Usa a mesma matemática RGBA, mesclagem e clipping da composição CPU.
function Engine.composite_pixel_source(project, model, include_background)
    local sources = {}
    for index, info in ipairs(model.layers) do
        local layer = project.layers[info.id]
        if layer and info.visible then
            local clip_pixels, clip_opacity
            if info.clipping then
                local base = clip_base(model, index)
                local mask = base and project.layers[base.id] or nil
                if base and base.visible and mask then
                    clip_pixels = mask.pixels
                    clip_opacity = clamp01((base.opacity or 100) / 100)
                end
            end
            -- Sem base visível, a camada clipada é invisível.
            if not info.clipping or clip_pixels then
                sources[#sources + 1] = {
                    pixels = layer.pixels,
                    opacity = clamp01((info.opacity or 100) / 100),
                    mode = assert(blend_ids[info.blending or "Normal"],
                        "Modo de mesclagem não suportado"),
                    clip_pixels = clip_pixels,
                    clip_opacity = clip_opacity or 1
                }
            end
        end
    end
    local white = include_background and model.background_mode == "white"
    local pixels = {}
    function pixels:getPixel(x, y)
        local r, g, b, a = 0, 0, 0, 0
        for _, source in ipairs(sources) do
            local sr, sg, sb, sa = source.pixels:getPixel(x, y)
            sa = sa * source.opacity
            if source.clip_pixels then
                local _, _, _, base_a = source.clip_pixels:getPixel(x, y)
                sa = sa * base_a * source.clip_opacity
            end
            if sa > 0 then
                local next_a = sa + a * (1 - sa)
                r = compose_channel(r, sr, a, sa, source.mode, next_a)
                g = compose_channel(g, sg, a, sa, source.mode, next_a)
                b = compose_channel(b, sb, a, sa, source.mode, next_a)
                a = next_a
            end
        end
        -- O fundo branco é visível (como no conta-gotas); os dois
        -- fundos quadriculados preservam a transparência real do canvas.
        if white then
            return r * a + (1 - a), g * a + (1 - a),
                   b * a + (1 - a), 1
        end
        return r, g, b, a
    end
    return {pixels = pixels}
end

-- Mantém a API pública de conta-gotas, sem misturar o fundo de exibição.
function Engine.sample(project, model, x, y)
    x, y = math.floor(x), math.floor(y)
    if x < 0 or y < 0 or x >= project.w or y >= project.h then return nil end
    return Engine.composite_pixel_source(project, model, false).pixels:getPixel(x, y)
end

-- Balde contíguo, cor RGBA exata (tolerância de 1/510 por canal).
-- Algoritmo scanline sem recursão; não extrapola os limites do buffer.
-- Impõe teto conservador de pixels para evitar travamentos da UI Lua.
function Engine.fill(project, id, x, y, rgb, alpha, alpha_lock, selection)
    if project.w * project.h > 1024 * 1024 then
        return false, "Balde Lua limitado a documentos de até 1.048.576 pixels."
    end
    x, y = math.floor(x), math.floor(y)
    if x < 0 or y < 0 or x >= project.w or y >= project.h or
       (selection and not Selection.contains(selection, x, y)) then
        return false
    end
    alpha = math.max(0, math.min(1, alpha))
    local seed_alpha = alpha * Selection.coverage(selection, x, y)
    if seed_alpha <= 0 then return false end
    local layer = assert(project.layers[id], "Camada inexistente")
    local data = layer.pixels
    local tr, tg, tb, ta = data:getPixel(x, y)
    if alpha_lock and ta <= 0 then return false end
    local na = alpha_lock and ta or seed_alpha + ta * (1 - seed_alpha)
    local nr, ng, nb
    if alpha_lock then
        nr, ng, nb = tr * (1 - seed_alpha) + rgb[1] * seed_alpha,
            tg * (1 - seed_alpha) + rgb[2] * seed_alpha,
            tb * (1 - seed_alpha) + rgb[3] * seed_alpha
    else
        nr = (rgb[1] * seed_alpha + tr * ta * (1 - seed_alpha)) / na
        ng = (rgb[2] * seed_alpha + tg * ta * (1 - seed_alpha)) / na
        nb = (rgb[3] * seed_alpha + tb * ta * (1 - seed_alpha)) / na
    end
    local epsilon = 0.5 / 255
    if math.abs(nr - tr) < epsilon and math.abs(ng - tg) < epsilon
       and math.abs(nb - tb) < epsilon and math.abs(na - ta) < epsilon then
        return false
    end

    local w, h = project.w, project.h
    local function matches(px, py)
        if px < 0 or py < 0 or px >= w or py >= h or
           (selection and not Selection.contains(selection, px, py)) then
            return false
        end
        local r, g, b, a = data:getPixel(px, py)
        if alpha_lock and a <= 0 then return false end
        local tolerance = 1 / 510
        return math.abs(r - tr) <= tolerance and math.abs(g - tg) <= tolerance
           and math.abs(b - tb) <= tolerance and math.abs(a - ta) <= tolerance
    end
    local function paint(px, py)
        local alpha = alpha * Selection.coverage(selection, px, py)
        if alpha <= 0 then return end
        local dr, dg, db, da = data:getPixel(px, py)
        if alpha_lock then
            data:setPixel(px, py,
                dr * (1 - alpha) + rgb[1] * alpha,
                dg * (1 - alpha) + rgb[2] * alpha,
                db * (1 - alpha) + rgb[3] * alpha, da)
        else
            local out_a = alpha + da * (1 - alpha)
            data:setPixel(px, py,
                (rgb[1] * alpha + dr * da * (1 - alpha)) / out_a,
                (rgb[2] * alpha + dg * da * (1 - alpha)) / out_a,
                (rgb[3] * alpha + db * da * (1 - alpha)) / out_a, out_a)
        end
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
    local source = Engine.composite_pixel_source(project, model, false).pixels
    for py = 0, th - 1 do
        for px = 0, tw - 1 do
            local sx = math.min(project.w - 1, math.floor((px + 0.5) * project.w / tw))
            local sy = math.min(project.h - 1, math.floor((py + 0.5) * project.h / th))
            local r, g, b, a = source:getPixel(sx, sy)
            pixels:setPixel(px, py, r, g, b, a)
        end
    end
    return pixels
end


-- Usa o MESMO arredondamento/clamp no caminho CPU e na prévia GPU.
function Engine.move_delta(project, selected, dx, dy)
    if not selected or selected.count == 0 then return 0, 0 end
    local function round_int(value)
        if value >= 0 then return math.floor(value + 0.5) end
        return math.ceil(value - 0.5)
    end
    dx, dy = round_int(dx), round_int(dy)
    dx = math.max(-selected.min_x, math.min(project.w - 1 - selected.max_x, dx))
    dy = math.max(-selected.min_y, math.min(project.h - 1 - selected.max_y, dy))
    return dx, dy
end

-- Move apenas os pixels selecionados da camada ativa, sem modificar outras
-- camadas e sem mudar a seleção por fora do canvas. É um único passo de undo.
function Engine.move_selection(project, id, selected, dx, dy)
    if not selected or selected.count == 0 then return false end
    local ok, reason = project.w * project.h <= 1024 * 1024,
        "Transformação Lua limitada a documentos de até 1.048.576 pixels."
    if not ok then return false, reason end
    local layer = assert(project.layers[id], "Camada inexistente")
    dx, dy = Engine.move_delta(project, selected, dx, dy)
    if dx == 0 and dy == 0 then return false end
    local snapshot = clone_pixels(project, layer)
    local data = layer.pixels
    local visible = false
    for y = selected.min_y, selected.max_y do
        for x = selected.min_x, selected.max_x do
            if Selection.contains(selected, x, y) then
                local _, _, _, a = snapshot:getPixel(x, y)
                if a > 0 then visible = true; break end
            end
        end
        if visible then break end
    end
    if visible then
        -- Snapshot ANTES de remover os pixels, para undo restaurar a origem.
        Engine.begin_stroke(project, id)
        local entry = project.undo[#project.undo]
        if entry then
            entry.selection_state = Selection.clone(selected)
            entry.selection_ref = selected
        end
    end
    for y = selected.min_y, selected.max_y do
        for x = selected.min_x, selected.max_x do
            if Selection.contains(selected, x, y) then
                local r, g, b, a = snapshot:getPixel(x, y)
                local remaining = a * (1 - Selection.coverage(selected, x, y))
                if remaining <= 0 then data:setPixel(x, y, 0, 0, 0, 0)
                else data:setPixel(x, y, r, g, b, remaining) end
            end
        end
    end
    for y = selected.min_y, selected.max_y do
        for x = selected.min_x, selected.max_x do
            if Selection.contains(selected, x, y) then
                local sr, sg, sb, sa = snapshot:getPixel(x, y)
                sa = sa * Selection.coverage(selected, x, y)
                if sa > 0 then
                    local tx, ty = x + dx, y + dy
                    local dr, dg, db, da = data:getPixel(tx, ty)
                    local out_a = sa + da * (1 - sa)
                    data:setPixel(tx, ty,
                        (sr * sa + dr * da * (1 - sa)) / out_a,
                        (sg * sa + dg * da * (1 - sa)) / out_a,
                        (sb * sa + db * da * (1 - sa)) / out_a, out_a)
                end
            end
        end
    end
    layer.image:replacePixels(data)
    Selection.translate(selected, dx, dy)
    if visible then project.dirty = true end
    return true
end


local MAX_TRANSFORM_PIXELS = 1024 * 1024
local LIMIT_MESSAGE = "Transformações Lua limitadas a documentos de até 1.048.576 pixels."

-- Área selecionada copiada para o clipboard INTERNO (não para a área de
-- transferência do sistema operacional). Preserva a máscara e o alfa.
function Engine.copy_selection(project, id, selected)
    if not selected or selected.count == 0 then return nil end
    if project.w * project.h > MAX_TRANSFORM_PIXELS then
        return nil, LIMIT_MESSAGE
    end
    local layer = assert(project.layers[id], "Camada inexistente")
    local x0, y0 = selected.min_x, selected.min_y
    local width = selected.max_x - x0 + 1
    local height = selected.max_y - y0 + 1
    local pixels = love.image.newImageData(width, height)
    local mask = {}
    for y = y0, selected.max_y do
        for x = x0, selected.max_x do
            if Selection.contains(selected, x, y) then
                local u, v = x - x0, y - y0
                local r, g, b, a = layer.pixels:getPixel(x, y)
                local coverage = Selection.coverage(selected, x, y)
                pixels:setPixel(u, v, r, g, b, a * coverage)
                mask[v * width + u] = coverage
            end
        end
    end
    return {pixels = pixels, mask = mask, w = width, h = height,
            x = x0, y = y0}
end

-- Fórmula source-over usada na colagem e nas transformações.
local function over_pixel(data, x, y, sr, sg, sb, sa)
    if sa <= 0 then return end
    local dr, dg, db, da = data:getPixel(x, y)
    local out_a = sa + da * (1 - sa)
    data:setPixel(x, y,
        (sr * sa + dr * da * (1 - sa)) / out_a,
        (sg * sa + dg * da * (1 - sa)) / out_a,
        (sb * sa + db * da * (1 - sa)) / out_a, out_a)
end

function Engine.paste_selection(project, id, clip, x, y, selected)
    if not clip then return false, "Não existe uma seleção copiada." end
    if project.w * project.h > MAX_TRANSFORM_PIXELS then
        return false, LIMIT_MESSAGE
    end
    x, y = math.floor(x or clip.x), math.floor(y or clip.y)
    if x < 0 or y < 0 or x + clip.w > project.w or
       y + clip.h > project.h then
        return false, "Cole dentro dos limites da tela."
    end
    local layer = assert(project.layers[id], "Camada inexistente")
    local newmask = {}
    for key in pairs(clip.mask) do
        local u, v = key % clip.w, math.floor(key / clip.w)
        newmask[(y + v) * project.w + x + u] = clip.mask[key]
    end
    local next_selection = assert(Selection.from_mask(project.w, project.h,
        newmask, "paste"))
    Engine.begin_stroke(project, id)
    local entry = project.undo[#project.undo]
    if entry and selected then
        entry.selection_ref = selected
        entry.selection_state = Selection.clone(selected)
    end
    for key in pairs(clip.mask) do
        local u, v = key % clip.w, math.floor(key / clip.w)
        local sr, sg, sb, sa = clip.pixels:getPixel(u, v)
        over_pixel(layer.pixels, x + u, y + v, sr, sg, sb, sa)
    end
    layer.image:replacePixels(layer.pixels)
    if selected then
        Selection.restore(selected, next_selection)
        next_selection = selected
    end
    project.dirty = true
    return true, next_selection
end

-- Corte de pixels: Ctrl+X copia primeiro, depois remove apenas a máscara.
function Engine.cut_selection(project, id, selected)
    local clip, reason = Engine.copy_selection(project, id, selected)
    if not clip then return false, reason end
    local layer = assert(project.layers[id], "Camada inexistente")
    Engine.begin_stroke(project, id)
    for y = selected.min_y, selected.max_y do
        for x = selected.min_x, selected.max_x do
            if Selection.contains(selected, x, y) then
                local r, g, b, a = layer.pixels:getPixel(x, y)
                local remaining = a * (1 - Selection.coverage(selected, x, y))
                if remaining <= 0 then
                    layer.pixels:setPixel(x, y, 0, 0, 0, 0)
                else
                    layer.pixels:setPixel(x, y, r, g, b, remaining)
                end
            end
        end
    end
    layer.image:replacePixels(layer.pixels)
    project.dirty = true
    return true, clip
end

-- Rotações ortogonais, espelhamento H/V e escalas nearest-neighbour.
-- O espelhamento atua nos pixels E na geometria da máscara irregular.
-- O retângulo de destino fica ancorado no canto superior esquerdo da seleção;
-- se ultrapassar o canvas, a operação falha sem tocar no documento.
function Engine.reshape_selection(project, id, selected, operation)
    if not selected or selected.count == 0 then return false, "Selecione uma área." end
    if project.w * project.h > MAX_TRANSFORM_PIXELS then
        return false, LIMIT_MESSAGE
    end
    if operation ~= "rotate_cw" and operation ~= "rotate_ccw" and
       operation ~= "scale_half" and operation ~= "scale_double" and
       operation ~= "flip_horizontal" and operation ~= "flip_vertical" then
        return false, "Transformação desconhecida."
    end
    local layer = assert(project.layers[id], "Camada inexistente")
    local x0, y0 = selected.min_x, selected.min_y
    local sw = selected.max_x - x0 + 1
    local sh = selected.max_y - y0 + 1
    local tw, th
    if operation == "rotate_cw" or operation == "rotate_ccw" then
        tw, th = sh, sw
    elseif operation == "flip_horizontal" or operation == "flip_vertical" then
        if (operation == "flip_horizontal" and sw < 2) or
           (operation == "flip_vertical" and sh < 2) then
            return false, "Espelhamento sem deslocamento de pixels."
        end
        tw, th = sw, sh
    else
        local factor = operation == "scale_half" and 0.5 or 2
        tw = math.max(1, math.floor(sw * factor + 0.5))
        th = math.max(1, math.floor(sh * factor + 0.5))
    end
    if x0 + tw > project.w or y0 + th > project.h then
        return false, "A seleção transformada ultrapassaria a tela."
    end
    local snapshot = clone_pixels(project, layer)
    local output = {}
    local newmask = {}
    for v = 0, th - 1 do
        for u = 0, tw - 1 do
            local su, sv
            if operation == "rotate_cw" then
                su, sv = v, sh - 1 - u
            elseif operation == "rotate_ccw" then
                su, sv = sw - 1 - v, u
            elseif operation == "flip_horizontal" then
                su, sv = sw - 1 - u, v
            elseif operation == "flip_vertical" then
                su, sv = u, sh - 1 - v
            else
                su = math.min(sw - 1, math.floor(u * sw / tw))
                sv = math.min(sh - 1, math.floor(v * sh / th))
            end
            if Selection.contains(selected, x0 + su, y0 + sv) then
                local tx, ty = x0 + u, y0 + v
                local coverage = Selection.coverage(selected, x0 + su, y0 + sv)
                newmask[ty * project.w + tx] = coverage
                local sr, sg, sb, sa = snapshot:getPixel(x0 + su, y0 + sv)
                output[#output + 1] = {tx, ty, sr, sg, sb, sa * coverage}
            end
        end
    end
    local replacement = Selection.from_mask(project.w, project.h,
        newmask, operation)
    if not replacement then
        return false, "A transformação não preservou pixels selecionados."
    end

    Engine.begin_stroke(project, id)
    local entry = project.undo[#project.undo]
    if entry then
        entry.selection_ref = selected
        entry.selection_state = Selection.clone(selected)
    end
    for y = selected.min_y, selected.max_y do
        for x = selected.min_x, selected.max_x do
            if Selection.contains(selected, x, y) then
                local r, g, b, a = snapshot:getPixel(x, y)
                local remaining = a * (1 - Selection.coverage(selected, x, y))
                if remaining <= 0 then
                    layer.pixels:setPixel(x, y, 0, 0, 0, 0)
                else
                    layer.pixels:setPixel(x, y, r, g, b, remaining)
                end
            end
        end
    end
    for _, p in ipairs(output) do
        over_pixel(layer.pixels, p[1], p[2], p[3], p[4], p[5], p[6])
    end
    layer.image:replacePixels(layer.pixels)
    Selection.restore(selected, replacement)
    project.dirty = true
    return true
end


-- Transformação raster livre sobre a máscara atual (amostragem nearest).
-- A origem é o centro geométrico da seleção e ângulos são em graus.
-- Prepara a máscara completa antes de apagar qualquer pixel; falhas de
-- parâmetro/limite não modificam documento, histórico ou seleção.
-- Preparação pura: pixels e máscara são calculados em buffers temporários.
-- Nenhuma operação de pré-visualização altera camadas, dirty ou undo/redo.
-- Validação compartilhada entre a prévia GPU e o commit CPU. O retângulo
-- de destino é conservador: não recorta nenhum pixel fora do canvas.
local function affine_geometry(project, selected, degrees, sx, sy, filter)
    if not selected or selected.count == 0 then
        return nil, "Selecione uma área antes de transformar."
    end
    if project.w * project.h > MAX_TRANSFORM_PIXELS then
        return nil, LIMIT_MESSAGE
    end
    local function finite(x)
        return type(x) == "number" and x == x and
            x ~= math.huge and x ~= -math.huge
    end
    if not finite(degrees) or math.abs(degrees) > 3600 or
       not finite(sx) or not finite(sy) or
       sx < 0.1 or sx > 8 or sy < 0.1 or sy > 8 or
       (filter ~= nil and filter ~= "nearest" and filter ~= "bilinear") then
        return nil, "Ângulo, escala ou interpolação inválidos."
    end
    local angle = math.rad(degrees % 360)
    if math.abs(angle) < 1e-10 and sx == 1 and sy == 1 then
        return nil, "A transformação não altera a seleção."
    end
    local cx = (selected.min_x + selected.max_x + 1) / 2
    local cy = (selected.min_y + selected.max_y + 1) / 2
    local co, si = math.cos(angle), math.sin(angle)
    local left, top = math.huge, math.huge
    local right, bottom = -math.huge, -math.huge
    for _, corner in ipairs({
        {selected.min_x, selected.min_y},
        {selected.max_x + 1, selected.min_y},
        {selected.max_x + 1, selected.max_y + 1},
        {selected.min_x, selected.max_y + 1}
    }) do
        local dx, dy = (corner[1] - cx) * sx, (corner[2] - cy) * sy
        local tx = cx + co * dx - si * dy
        local ty = cy + si * dx + co * dy
        left, right = math.min(left, tx), math.max(right, tx)
        top, bottom = math.min(top, ty), math.max(bottom, ty)
    end
    local xmin, xmax = math.floor(left + 1e-8), math.ceil(right - 1e-8) - 1
    local ymin, ymax = math.floor(top + 1e-8), math.ceil(bottom - 1e-8) - 1
    if xmin < 0 or ymin < 0 or xmax >= project.w or ymax >= project.h then
        return nil, "Transformação ultrapassaria os limites do canvas."
    end
    return {cx = cx, cy = cy, co = co, si = si, angle = angle,
            xmin = xmin, ymin = ymin, xmax = xmax, ymax = ymax}
end

local function prepare_affine(project, id, selected, degrees, sx, sy, filter)
    local geometry, reason = affine_geometry(project, selected,
                                            degrees, sx, sy, filter)
    if not geometry then return nil, reason end
    local layer = assert(project.layers[id], "Camada inexistente")
    local cx, cy, co, si = geometry.cx, geometry.cy, geometry.co, geometry.si
    local xmin, xmax = geometry.xmin, geometry.xmax
    local ymin, ymax = geometry.ymin, geometry.ymax
    local function source_at(x, y)
        local dx, dy = x + 0.5 - cx, y + 0.5 - cy
        return (co * dx + si * dy) / sx + cx,
            (-si * dx + co * dy) / sy + cy
    end
    local next_mask = {}
    for y = ymin, ymax do
        for x = xmin, xmax do
            local src_x, src_y = source_at(x, y)
            if Selection.contains(selected, math.floor(src_x),
                                  math.floor(src_y)) then
                next_mask[y * project.w + x] = Selection.coverage(selected,
                        math.floor(src_x), math.floor(src_y))
            end
        end
    end
    local replacement = Selection.from_mask(project.w, project.h,
                                            next_mask, "affine")
    if not replacement then
        return nil, "A transformação eliminaria todos os pixels da seleção."
    end

    local output = clone_pixels(project, layer)
    for y = selected.min_y, selected.max_y do
        for x = selected.min_x, selected.max_x do
            if Selection.contains(selected, x, y) then
                local r, g, b, a = output:getPixel(x, y)
                local remaining = a * (1 - Selection.coverage(selected, x, y))
                if remaining <= 0 then output:setPixel(x, y, 0, 0, 0, 0)
                else output:setPixel(x, y, r, g, b, remaining) end
            end
        end
    end
    local function filtered_pixel(src_x, src_y)
        if filter ~= "bilinear" then
            local ix, iy = math.floor(src_x), math.floor(src_y)
            local r, g, b, a = layer.pixels:getPixel(ix, iy)
            return r, g, b, a * Selection.coverage(selected, ix, iy)
        end
        -- Interpolação em RGB pré-multiplicado: evita halos RGB nas bordas.
        -- Vizinhos não selecionados contribuem como transparentes.
        local fx, fy = src_x - 0.5, src_y - 0.5
        local x0, y0 = math.floor(fx), math.floor(fy)
        local dx, dy = fx - x0, fy - y0
        local rp, gp, bp, alpha = 0, 0, 0, 0
        for j = 0, 1 do
            for i = 0, 1 do
                local px, py = x0 + i, y0 + j
                if Selection.contains(selected, px, py) then
                    local r, g, b, a = layer.pixels:getPixel(px, py)
                    local weight = (i == 0 and 1 - dx or dx) *
                                   (j == 0 and 1 - dy or dy) * a *
                                   Selection.coverage(selected, px, py)
                    rp, gp, bp = rp + r * weight, gp + g * weight,
                                 bp + b * weight
                    alpha = alpha + weight
                end
            end
        end
        if alpha <= 1e-12 then return 0, 0, 0, 0 end
        return rp / alpha, gp / alpha, bp / alpha, alpha
    end
    for key in pairs(next_mask) do
        local x, y = key % project.w, math.floor(key / project.w)
        local source_x, source_y = source_at(x, y)
        local r, g, b, a = filtered_pixel(source_x, source_y)
        over_pixel(output, x, y, r, g, b, a)
    end
    return {pixels = output, selection = replacement}
end

-- A prévia usa uma imagem LÖVE própria; o chamador deve liberá-la ao
-- substituir/cancelar a prévia. Não grava nenhum pixel no documento real.
function Engine.preview_affine(project, id, selected, degrees, sx, sy, filter)
    local preview, reason = prepare_affine(project, id, selected,
        degrees, sx, sy, filter or "bilinear")
    if not preview then return nil, reason end
    preview.image = love.graphics.newImage(preview.pixels)
    return preview
end

-- A assinatura anterior continua válida: nearest por padrão para chamadas
-- legadas; os gestos novos usam "bilinear" explicitamente.
function Engine.affine_selection(project, id, selected, degrees, sx, sy, filter)
    local computed, reason = prepare_affine(project, id, selected,
                                             degrees, sx, sy, filter)
    if not computed then return false, reason end
    Engine.begin_stroke(project, id)
    local entry = project.undo[#project.undo]
    if entry then
        entry.selection_ref = selected
        entry.selection_state = Selection.clone(selected)
    end
    local layer = assert(project.layers[id], "Camada inexistente")
    layer.pixels = computed.pixels
    layer.image:replacePixels(computed.pixels)
    Selection.restore(selected, computed.selection)
    project.dirty = true
    return true
end



-- Pré-visualização de MOVIMENTO é feita na GPU, não via cópia de pixels a
-- cada mousemoved. Máscara e Canvas são alocados somente uma vez por gesto.
-- O shader calcula: pixel original menos a máscara + seleção transladada
-- em RGBA source-over, sem modificar a camada usada pelo projeto.
local move_preview_shader

local function moving_shader()
    if not move_preview_shader then
        move_preview_shader = love.graphics.newShader([[
            extern Image selectionMask;
            extern vec2 displacement;
            vec4 effect(vec4 vertexColor, Image texture,
                        vec2 textureCoords, vec2 screenCoords) {
                vec4 original = Texel(texture, textureCoords);
                float erased = Texel(selectionMask, textureCoords).a;
                vec4 destination = vec4(original.rgb,
                                         original.a * (1.0 - erased));
                vec2 sourceCoords = textureCoords - displacement;
                vec4 source = vec4(0.0);
                if (sourceCoords.x >= 0.0 && sourceCoords.x < 1.0 &&
                    sourceCoords.y >= 0.0 && sourceCoords.y < 1.0 &&
                    Texel(selectionMask, sourceCoords).a > 0.0) {
                    source = Texel(texture, sourceCoords);
                    source.a *= Texel(selectionMask, sourceCoords).a;
                }
                float a = source.a + destination.a * (1.0 - source.a);
                vec3 rgb = vec3(0.0);
                if (a > 0.0) {
                    rgb = (source.rgb * source.a +
                        destination.rgb * destination.a * (1.0 - source.a)) / a;
                }
                return vec4(rgb, a);
            }
        ]])
    end
    return move_preview_shader
end

function Engine.begin_move_preview(project, id, selected)
    if not selected or selected.count == 0 or
       project.w * project.h > MAX_TRANSFORM_PIXELS then
        return nil, LIMIT_MESSAGE
    end
    local layer = assert(project.layers[id], "Camada inexistente")
    local mask_data = love.image.newImageData(project.w, project.h)
    for key in pairs(selected.mask) do
        mask_data:setPixel(key % project.w, math.floor(key / project.w),
                           1, 1, 1, selected.weights and selected.weights[key] or 1)
    end
    local mask_image = love.graphics.newImage(mask_data)
    mask_image:setFilter("nearest", "nearest")
    local canvas = love.graphics.newCanvas(project.w, project.h)
    canvas:setFilter("nearest", "nearest")
    return {kind = "move", image = canvas, mask_image = mask_image,
            source_image = layer.image, dx = 0, dy = 0,
            active = false, renders = 0}
end

function Engine.update_move_preview(project, selected, preview, dx, dy)
    assert(preview and preview.kind == "move", "Prévia incompatível.")
    dx, dy = Engine.move_delta(project, selected, dx, dy)
    if preview.dx == dx and preview.dy == dy then return true end
    preview.dx, preview.dy = dx, dy
    if dx == 0 and dy == 0 then
        preview.active = false
        return true
    end
    local shader = moving_shader()
    love.graphics.push("all")
    love.graphics.origin()
    love.graphics.setCanvas(preview.image)
    -- Canvas intermediário deve guardar canais RGB straight.
    love.graphics.setBlendMode("replace", "premultiplied")
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setShader(shader)
    shader:send("selectionMask", preview.mask_image)
    shader:send("displacement", {dx / project.w, dy / project.h})
    preview.source_image:setFilter("nearest", "nearest")
    love.graphics.draw(preview.source_image, 0, 0)
    love.graphics.pop()
    preview.active = true
    preview.renders = preview.renders + 1
    return true
end


-- Prévia GPU da transformação afim: máscara raster e Canvas só são
-- alocados UMA vez por gesto; atualização usa uniforme e shader bilinear.
-- Os pixels de commit continuam vindo do caminho CPU prepare_affine.
local affine_preview_shader

local function affine_shader()
    if not affine_preview_shader then
        affine_preview_shader = love.graphics.newShader([[
            extern Image selectionMask;
            extern vec2 dimensions;
            extern vec2 pivot;
            extern vec2 rotationTrig;
            extern vec2 inverseScale;

            // Seleção e pixels fora do documento são transparentes.
            float membership(vec2 q) {
                if (q.x < 0.0 || q.y < 0.0 ||
                    q.x >= dimensions.x || q.y >= dimensions.y) return 0.0;
                return Texel(selectionMask, (floor(q) + vec2(0.5)) /
                    dimensions).a;
            }
            vec4 effect(vec4 vertexColor, Image texture,
                        vec2 textureCoords, vec2 screenCoords) {
                vec2 destination = textureCoords * dimensions;
                vec4 original = Texel(texture, textureCoords);
                vec4 base = vec4(original.rgb,
                                 original.a * (1.0 - membership(destination)));

                vec2 delta = destination - pivot;
                float c = rotationTrig.x;
                float s = rotationTrig.y;
                vec2 src = vec2(c * delta.x + s * delta.y,
                                -s * delta.x + c * delta.y);
                src = src * inverseScale + pivot;
                // Máscara transformada usa nearest, igual ao CPU.
                if (membership(src) <= 0.0) return base;

                // Bilinear com RGBA premultiplicado, sem vazamento
                // de pixels vizinhos fora da seleção.
                vec2 corner = src - vec2(0.5);
                vec2 p0 = floor(corner);
                vec2 fraction = corner - p0;
                vec3 premul = vec3(0.0);
                float accumulatedAlpha = 0.0;
                for (int j = 0; j < 2; ++j) {
                    for (int i = 0; i < 2; ++i) {
                        vec2 samplePixel = p0 + vec2(float(i), float(j));
                        if (membership(samplePixel) > 0.0) {
                            float weight = (i == 0 ? 1.0 - fraction.x :
                                                       fraction.x) *
                                           (j == 0 ? 1.0 - fraction.y :
                                                       fraction.y);
                            vec4 sampleColor = Texel(texture,
                                 (samplePixel + vec2(0.5)) / dimensions);
                            float contribution = weight * sampleColor.a *
                                                 membership(samplePixel);
                            premul += sampleColor.rgb * contribution;
                            accumulatedAlpha += contribution;
                        }
                    }
                }
                vec3 sourceRgb = accumulatedAlpha > 0.0000001
                    ? premul / accumulatedAlpha : vec3(0.0);
                float outAlpha = accumulatedAlpha +
                    base.a * (1.0 - accumulatedAlpha);
                vec3 outRgb = vec3(0.0);
                if (outAlpha > 0.0000001) {
                    outRgb = (sourceRgb * accumulatedAlpha +
                        base.rgb * base.a * (1.0 - accumulatedAlpha)) /
                        outAlpha;
                }
                return vec4(outRgb, outAlpha);
            }
        ]])
    end
    return affine_preview_shader
end

function Engine.begin_affine_gpu_preview(project, id, selected)
    if not selected or selected.count == 0 or
       project.w * project.h > MAX_TRANSFORM_PIXELS then
        return nil, LIMIT_MESSAGE
    end
    local layer = assert(project.layers[id], "Camada inexistente")
    local mask_data = love.image.newImageData(project.w, project.h)
    for key in pairs(selected.mask) do
        mask_data:setPixel(key % project.w, math.floor(key / project.w),
                           1, 1, 1, selected.weights and selected.weights[key] or 1)
    end
    local mask_image = love.graphics.newImage(mask_data)
    mask_image:setFilter("nearest", "nearest")
    local canvas = love.graphics.newCanvas(project.w, project.h)
    canvas:setFilter("nearest", "nearest")
    return {kind = "affine_gpu", image = canvas,
            mask_image = mask_image, source_image = layer.image,
            active = false, renders = 0, degrees = nil}
end

function Engine.update_affine_gpu_preview(project, selected, preview,
                                         degrees, sx, sy)
    assert(preview and preview.kind == "affine_gpu",
           "Prévia afim GPU incompatível.")
    local geometry, reason = affine_geometry(project, selected,
                                             degrees, sx, sy, "bilinear")
    if not geometry then
        preview.active = false
        return false, reason
    end
    if preview.active and preview.degrees == degrees and
       preview.sx == sx and preview.sy == sy then
        return true
    end
    local shader = affine_shader()
    love.graphics.push("all")
    love.graphics.origin()
    love.graphics.setCanvas(preview.image)
    love.graphics.setBlendMode("replace", "premultiplied")
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setShader(shader)
    shader:send("selectionMask", preview.mask_image)
    shader:send("dimensions", {project.w, project.h})
    shader:send("pivot", {geometry.cx, geometry.cy})
    shader:send("rotationTrig", {geometry.co, geometry.si})
    shader:send("inverseScale", {1 / sx, 1 / sy})
    preview.source_image:setFilter("nearest", "nearest")
    love.graphics.draw(preview.source_image, 0, 0)
    love.graphics.pop()
    preview.active = true
    preview.degrees, preview.sx, preview.sy = degrees, sx, sy
    preview.cx, preview.cy = geometry.cx, geometry.cy
    preview.renders = preview.renders + 1
    return true
end

return Engine
