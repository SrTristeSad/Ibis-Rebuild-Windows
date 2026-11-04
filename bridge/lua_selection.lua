-- Seleção raster independente em Lua. Não altera a interface do Ibis-Lua.
-- As máscaras são voláteis; os pixels editados continuam no PNG por camada.
local Selection = {}
local MAX_PIXELS = 1024 * 1024
local MAX_OUTLINE_SEGMENTS = 10000
local TOLERANCE = 1 / 510

local function allowed(w, h)
    if w * h > MAX_PIXELS then
        return false, "Seleções Lua limitadas a documentos de até 1.048.576 pixels."
    end
    return true
end

local function index(w, x, y) return y * w + x end

function Selection.contains(s, x, y)
    if not s or x < 0 or y < 0 or x >= s.w or y >= s.h then return false end
    return s.mask[index(s.w, x, y)] == true
end

local function finalize(s)
    if s.count == 0 then return nil end
    local outline = {}
    -- Limite visual para impedir dezenas de milhares de drawcalls ao desenhar.
    for y = s.min_y, s.max_y do
        for x = s.min_x, s.max_x do
            if Selection.contains(s, x, y) then
                local function edge(x1, y1, x2, y2)
                    if #outline < MAX_OUTLINE_SEGMENTS then
                        outline[#outline + 1] = {x1, y1, x2, y2}
                    end
                end
                if not Selection.contains(s, x, y - 1) then edge(x, y, x + 1, y) end
                if not Selection.contains(s, x + 1, y) then
                    edge(x + 1, y, x + 1, y + 1)
                end
                if not Selection.contains(s, x, y + 1) then
                    edge(x, y + 1, x + 1, y + 1)
                end
                if not Selection.contains(s, x - 1, y) then edge(x, y, x, y + 1) end
            end
        end
    end
    s.outline = outline
    return s
end

local function empty(w, h, kind)
    return {
        w = w, h = h, kind = kind, mask = {}, count = 0,
        min_x = w, min_y = h, max_x = -1, max_y = -1
    }
end

local function add(s, x, y)
    if x < 0 or y < 0 or x >= s.w or y >= s.h then return end
    local k = index(s.w, x, y)
    if s.mask[k] then return end
    s.mask[k] = true
    s.count = s.count + 1
    s.min_x = math.min(s.min_x, x)
    s.max_x = math.max(s.max_x, x)
    s.min_y = math.min(s.min_y, y)
    s.max_y = math.max(s.max_y, y)
end

function Selection.rectangle(w, h, x1, y1, x2, y2)
    local ok, err = allowed(w, h)
    if not ok then return nil, err end
    local s = empty(w, h, "rectangle")
    local left = math.max(0, math.floor(math.min(x1, x2)))
    local right = math.min(w - 1, math.floor(math.max(x1, x2)))
    local top = math.max(0, math.floor(math.min(y1, y2)))
    local bottom = math.min(h - 1, math.floor(math.max(y1, y2)))
    for y = top, bottom do
        for x = left, right do add(s, x, y) end
    end
    return finalize(s)
end

-- Regra par/ímpar em coordenadas de centros de pixel (laço livre).
function Selection.lasso(w, h, points)
    local ok, err = allowed(w, h)
    if not ok then return nil, err end
    if #points < 3 then return nil end
    local s = empty(w, h, "lasso")
    local min_y, max_y = h, -1
    for _, p in ipairs(points) do
        min_y = math.min(min_y, p[2])
        max_y = math.max(max_y, p[2])
    end
    for y = math.max(0, math.floor(min_y)),
             math.min(h - 1, math.ceil(max_y)) do
        local scan_y = y + 0.5
        local cuts = {}
        for i = 1, #points do
            local a, b = points[i], points[i % #points + 1]
            if (a[2] <= scan_y and b[2] > scan_y) or
               (b[2] <= scan_y and a[2] > scan_y) then
                cuts[#cuts + 1] = a[1] +
                    (scan_y - a[2]) * (b[1] - a[1]) / (b[2] - a[2])
            end
        end
        table.sort(cuts)
        for i = 1, #cuts - 1, 2 do
            for x = math.max(0, math.ceil(cuts[i] - 0.5)),
                     math.min(w - 1, math.floor(cuts[i + 1] - 0.5)) do
                add(s, x, y)
            end
        end
    end
    return finalize(s)
end

function Selection.magic_wand(layer, w, h, x, y)
    local ok, err = allowed(w, h)
    if not ok then return nil, err end
    x, y = math.floor(x), math.floor(y)
    if x < 0 or y < 0 or x >= w or y >= h then return nil end
    local data = layer.pixels
    local tr, tg, tb, ta = data:getPixel(x, y)
    local s = empty(w, h, "magic_wand")
    local visited = {}
    local function matches(px, py)
        if px < 0 or py < 0 or px >= w or py >= h then return false end
        local key = index(w, px, py)
        if visited[key] or s.mask[key] then return false end
        local r, g, b, a = data:getPixel(px, py)
        local same = math.abs(r - tr) <= TOLERANCE and
            math.abs(g - tg) <= TOLERANCE and
            math.abs(b - tb) <= TOLERANCE and math.abs(a - ta) <= TOLERANCE
        if not same then visited[key] = true end
        return same
    end
    local stack = {{x, y}}
    while #stack > 0 do
        local p = table.remove(stack)
        local px, py = p[1], p[2]
        if matches(px, py) then
            while matches(px - 1, py) do px = px - 1 end
            local up, down = false, false
            while matches(px, py) do
                add(s, px, py)
                if matches(px, py - 1) then
                    if not up then stack[#stack + 1] = {px, py - 1} end
                    up = true
                else up = false end
                if matches(px, py + 1) then
                    if not down then stack[#stack + 1] = {px, py + 1} end
                    down = true
                else down = false end
                px = px + 1
            end
        end
    end
    return finalize(s)
end

function Selection.translate(s, dx, dy)
    dx, dy = math.floor(dx), math.floor(dy)
    if dx == 0 and dy == 0 then return s end
    local shifted = empty(s.w, s.h, s.kind)
    for y = s.min_y, s.max_y do
        for x = s.min_x, s.max_x do
            if Selection.contains(s, x, y) then add(shifted, x + dx, y + dy) end
        end
    end
    if shifted.count == 0 then
        -- Um deslocamento completamente para fora do canvas deixa a seleção vazia.
        s.mask, s.count, s.outline = {}, 0, {}
        s.min_x, s.min_y, s.max_x, s.max_y = s.w, s.h, -1, -1
        return s
    end
    finalize(shifted)
    for key, value in pairs(shifted) do s[key] = value end
    return s
end

function Selection.draw(s)
    if not s or not s.outline then return end
    love.graphics.push("all")
    love.graphics.setLineWidth(1)
    love.graphics.setColor(0.08, 0.08, 0.08, 0.9)
    for _, edge in ipairs(s.outline) do
        love.graphics.line(edge[1], edge[2], edge[3], edge[4])
    end
    love.graphics.pop()
end

return Selection
