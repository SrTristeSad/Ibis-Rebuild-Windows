-- Seleção raster independente em Lua. Não altera a interface do Ibis-Lua.
-- A máscara ativa pode ser persistida em PNG; nunca altera pixels por si só.
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

-- Máscaras existentes são binárias; pesos fracionários opcionais deixam
-- o feather compatível com qualquer código que use Selection.contains.
-- Sem seleção, toda a tela está disponível para pintar.
function Selection.coverage(s, x, y)
    if not s then return 1 end
    if not Selection.contains(s, x, y) then return 0 end
    local key = index(s.w, x, y)
    return s.weights and s.weights[key] or 1
end

function Selection.is_soft(s)
    return s ~= nil and s.weights ~= nil
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

local function add(s, x, y, coverage)
    if x < 0 or y < 0 or x >= s.w or y >= s.h then return end
    coverage = coverage or 1
    if type(coverage) ~= "number" or coverage ~= coverage or
       coverage <= 0 then return end
    coverage = math.min(1, coverage)
    local k = index(s.w, x, y)
    if s.mask[k] then return end
    s.mask[k] = true
    if coverage < 1 then
        if not s.weights then s.weights = {} end
        s.weights[k] = coverage
    elseif s.weights then
        s.weights[k] = 1
    end
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

-- Varinha usa tolerância por CANAL RGBA, em unidades inteiras 8-bit.
-- Zero mantém equivalência à seleção exata antiga (margem de
-- quantização); valor 255 inclui todas as cores/transparências.
-- Por padrão mantém flood-fill 4-conexo; global_mode=true compara todos
-- os pixels da camada ativa, inclusive ilhas desconectadas.
function Selection.magic_wand(layer, w, h, x, y, tolerance, global_mode)
    local ok, err = allowed(w, h)
    if not ok then return nil, err end
    if tolerance == nil then tolerance = 0 end
    if type(tolerance) ~= "number" or tolerance ~= math.floor(tolerance) or
       tolerance < 0 or tolerance > 255 then
        return nil, "Tolerância da varinha deve ser um inteiro de 0 a 255."
    end
    if global_mode ~= nil and type(global_mode) ~= "boolean" then
        return nil, "Modo global da varinha deve ser booleano."
    end
    x, y = math.floor(x), math.floor(y)
    if x < 0 or y < 0 or x >= w or y >= h then return nil end
    local data = layer.pixels
    local tr, tg, tb, ta = data:getPixel(x, y)
    local threshold = tolerance / 255 + TOLERANCE
    local s = empty(w, h, global_mode and "magic_wand_global" or "magic_wand")
    -- No modo global cada pixel é lido uma única vez: não alocar a
    -- tabela visited do flood-fill, que poderia ocupar 1 Mi entradas.
    local visited = not global_mode and {} or nil
    local function matches(px, py)
        if px < 0 or py < 0 or px >= w or py >= h then return false end
        local key = index(w, px, py)
        if (visited and visited[key]) or s.mask[key] then return false end
        local r, g, b, a = data:getPixel(px, py)
        local same = math.abs(r - tr) <= threshold and
            math.abs(g - tg) <= threshold and
            math.abs(b - tb) <= threshold and math.abs(a - ta) <= threshold
        if not same and visited then visited[key] = true end
        return same
    end
    if global_mode then
        -- Iteração única O(w*h), com o mesmo critério RGBA do flood-fill.
        -- Não guarda fila/stack: até 1.048.576 pixels e 4 canais.
        for py = 0, h - 1 do
            for px = 0, w - 1 do
                if matches(px, py) then add(s, px, py) end
            end
        end
        return finalize(s)
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
            if Selection.contains(s, x, y) then
                add(shifted, x + dx, y + dy, Selection.coverage(s, x, y))
            end
        end
    end
    if shifted.count == 0 then
        -- Um deslocamento completamente para fora do canvas deixa a seleção vazia.
        s.mask, s.weights, s.count, s.outline = {}, nil, 0, {}
        s.min_x, s.min_y, s.max_x, s.max_y = s.w, s.h, -1, -1
        return s
    end
    finalize(shifted)
    for key in pairs(s) do s[key] = nil end
    for key, value in pairs(shifted) do s[key] = value end
    return s
end


-- Constrói uma seleção a partir dos pixels escolhidos após uma transformação.
-- As chaves são índices 0-based (y * largura + x).
function Selection.from_mask(w, h, mask, kind)
    local ok, err = allowed(w, h)
    if not ok then return nil, err end
    local s = empty(w, h, kind or "transformed")
    for k, marked in pairs(mask) do
        if marked and type(k) == "number" and k == math.floor(k) and
           k >= 0 and k < w * h then
            add(s, k % w, math.floor(k / w),
                type(marked) == "number" and marked or 1)
        end
    end
    return finalize(s)
end

-- Selecionar todo o canvas não depende do estado da camada ativa.
-- Limite explícito evita construir tabelas de milhões de entradas.
function Selection.all(w, h)
    local result, err = Selection.rectangle(w, h, 0, 0, w - 1, h - 1)
    if result then result.kind = "all" end
    return result, err
end

-- Inverter a máscara INTEIRA do documento, não apenas seu bounding box.
-- A seleção original não é modificada: isso impede que uma edição de
-- geometria reaplique silenciosamente snapshots antigos de undo raster.
-- Inverter sem seleção equivale a selecionar tudo; inverter a tela toda
-- equivale a desmarcar (nil sem erro).
function Selection.invert(s, w, h)
    local ok, reason = allowed(w, h)
    if not ok then return nil, reason end
    if not s then return Selection.all(w, h) end
    if s.w ~= w or s.h ~= h then
        return nil, "Máscara incompatível com as dimensões do documento."
    end
    if s.count == w * h and not Selection.is_soft(s) then return nil end
    local inverse = empty(w, h, "inverted")
    for y = 0, h - 1 do
        for x = 0, w - 1 do
            add(inverse, x, y, 1 - Selection.coverage(s, x, y))
        end
    end
    return finalize(inverse)
end

-- Álgebra booleana de máscaras em TODO o documento.
-- Retorna nil sem erro quando a combinação resulta em seleção vazia.
-- As duas entradas permanecem intactas, inclusive seus contornos.
function Selection.combine(base, incoming, mode, w, h)
    local ok, reason = allowed(w, h)
    if not ok then return nil, reason end
    if mode ~= "replace" and mode ~= "add" and
       mode ~= "subtract" and mode ~= "intersect" then
        return nil, "Modo de combinação desconhecido."
    end
    if (base and (base.w ~= w or base.h ~= h)) or
       (incoming and (incoming.w ~= w or incoming.h ~= h)) then
        return nil, "Máscara incompatível com as dimensões do documento."
    end
    if mode == "replace" then return Selection.clone(incoming) end
    local next_mask = {}
    local function at(mask, key)
        if not mask or not mask.mask[key] then return 0 end
        return mask.weights and mask.weights[key] or 1
    end
    -- Percorrer a união das chaves evita varrer todo o canvas para masks
    -- pequenas. Máximo/mínimo para composição geométrica previsível;
    -- diferença usa cobertura da máscara subtraída.
    local keys = {}
    if base then for k in pairs(base.mask) do keys[k] = true end end
    if incoming then for k in pairs(incoming.mask) do keys[k] = true end end
    for k in pairs(keys) do
        local a, b = at(base, k), at(incoming, k)
        local alpha
        if mode == "add" then alpha = math.max(a, b)
        elseif mode == "subtract" then alpha = a * (1 - b)
        else alpha = math.min(a, b) end
        if alpha > 0 then next_mask[k] = alpha end
    end
    return Selection.from_mask(w, h, next_mask, "combined_" .. mode)
end

-- Morfologia binária de uma célula, com vizinhança 8-conexa (3x3).
-- Expandir adiciona os vizinhos dos pixels selecionados; contrair mantém
-- somente pixels cercados por 8 vizinhos selecionados. Fora do canvas
-- equivale a fundo vazio. Nenhum pixel do desenho é modificado.
-- A operação não muta a máscara de entrada e a contração pode gerar nil.
function Selection.morph(s, operation)
    if operation ~= "expand" and operation ~= "contract" then
        return nil, "Operação morfológica desconhecida."
    end
    if not s or s.count == 0 then
        return nil, "Selecione uma área antes de expandir ou contrair."
    end
    local ok, reason = allowed(s.w, s.h)
    if not ok then return nil, reason end
    local next_mask = {}
    for key in pairs(s.mask) do
        local x, y = key % s.w, math.floor(key / s.w)
        if operation == "expand" then
            local source_weight = Selection.coverage(s, x, y)
            for ny = math.max(0, y - 1), math.min(s.h - 1, y + 1) do
                for nx = math.max(0, x - 1), math.min(s.w - 1, x + 1) do
                    local target = index(s.w, nx, ny)
                    next_mask[target] = math.max(next_mask[target] or 0, source_weight)
                end
            end
        else
            local minimum = 1
            for dy = -1, 1 do
                for dx = -1, 1 do
                    minimum = math.min(minimum, Selection.coverage(s, x + dx, y + dy))
                    if minimum <= 0 then break end
                end
                if minimum <= 0 then break end
            end
            if minimum > 0 then next_mask[key] = minimum end
        end
    end
    return Selection.from_mask(s.w, s.h, next_mask,
                               operation == "expand" and "expanded" or "contracted")
end

-- Feather separável (box blur) com raio 1..8. Exterior do documento é
-- transparente. Os pesos são quantizados a 8 bits, o mesmo canal alfa do
-- PNG de seleção; não alteramos a máscara original nem pixels de camada.
-- Custo O(w*h), não O(w*h*raio²).
function Selection.feather(s, radius)
    if not s or s.count == 0 then
        return nil, "Selecione uma área antes de suavizar."
    end
    local ok, reason = allowed(s.w, s.h)
    if not ok then return nil, reason end
    if type(radius) ~= "number" or radius ~= math.floor(radius) or
       radius < 1 or radius > 8 then
        return nil, "Feather exige raio inteiro entre 1 e 8 pixels."
    end
    local w, h = s.w, s.h
    local kernel = 2 * radius + 1
    local horizontal = {}
    for y = 0, h - 1 do
        local sum = 0
        for x = 0, math.min(w - 1, radius) do
            sum = sum + Selection.coverage(s, x, y)
        end
        for x = 0, w - 1 do
            horizontal[y * w + x] = sum
            if x - radius >= 0 then
                sum = sum - Selection.coverage(s, x - radius, y)
            end
            if x + radius + 1 < w then
                sum = sum + Selection.coverage(s, x + radius + 1, y)
            end
        end
    end
    local weighted = {}
    for x = 0, w - 1 do
        local sum = 0
        for y = 0, math.min(h - 1, radius) do
            sum = sum + horizontal[y * w + x]
        end
        for y = 0, h - 1 do
            local alpha = math.floor(sum * 255 / (kernel * kernel) + 0.5) / 255
            if alpha > 0 then weighted[y * w + x] = alpha end
            if y - radius >= 0 then
                sum = sum - horizontal[(y - radius) * w + x]
            end
            if y + radius + 1 < h then
                sum = sum + horizontal[(y + radius + 1) * w + x]
            end
        end
    end
    return Selection.from_mask(w, h, weighted, "feathered")
end

-- Snapshot independente para restaurar contorno e posição junto com pixels.
function Selection.clone(s)
    if not s then return nil end
    local copy = {}
    for k, v in pairs(s) do
        if k ~= "mask" and k ~= "outline" and k ~= "weights" then copy[k] = v end
    end
    copy.mask = {}
    for k, v in pairs(s.mask) do copy.mask[k] = v end
    if s.weights then
        copy.weights = {}
        for k, v in pairs(s.weights) do copy.weights[k] = v end
    end
    copy.outline = {}
    for i, segment in ipairs(s.outline or {}) do
        copy.outline[i] = {segment[1], segment[2], segment[3], segment[4]}
    end
    return copy
end

function Selection.restore(destination, saved)
    assert(destination and saved and destination.w == saved.w and
        destination.h == saved.h, "Máscara incompatível")
    local state = Selection.clone(saved)
    for k in pairs(destination) do destination[k] = nil end
    for k, v in pairs(state) do destination[k] = v end
end

-- Persistência de máscaras binárias/feather em PNG, sem alterar formato.
-- O canal alfa representa a cobertura da seleção (0..1).
-- A máscara não altera diretamente os pixels da obra.
local PNG_SIGNATURE = "\137PNG\r\n\26\n"
local MAX_PNG_BYTES = 16 * 1024 * 1024

local function png_dimensions(file)
    local header = love.filesystem.read(file, 24)
    if not header or #header ~= 24 or header:sub(1, 8) ~= PNG_SIGNATURE
       or header:sub(13, 16) ~= "IHDR" then
        return nil
    end
    local function u32(offset)
        local a, b, c, d = header:byte(offset, offset + 3)
        return ((a * 256 + b) * 256 + c) * 256 + d
    end
    return u32(17), u32(21)
end

function Selection.save(s, file)
    if not s or s.count == 0 then return false, "Não há seleção ativa." end
    local ok, err = allowed(s.w, s.h)
    if not ok then return false, err end
    local pixels = love.image.newImageData(s.w, s.h)
    for key, marked in pairs(s.mask) do
        if marked then
            pixels:setPixel(key % s.w, math.floor(key / s.w), 1, 1, 1,
                            s.weights and s.weights[key] or 1)
        end
    end
    local success, result = pcall(function()
        return pixels:encode("png", file)
    end)
    if not success then return false, tostring(result) end
    if not love.filesystem.getInfo(file, "file") then
        return false, "Não foi possível salvar a máscara de seleção."
    end
    return true
end

-- Nunca confia nas dimensões ou na decodificação de arquivos persistidos.
-- A seleção inválida é ignorada sem prejudicar a abertura das camadas.
function Selection.load(file, w, h)
    local info = love.filesystem.getInfo(file, "file")
    if not info then return nil end -- Compatível com projetos anteriores.
    local ok, err = allowed(w, h)
    if not ok then return nil, err end
    if info.size > MAX_PNG_BYTES then
        return nil, "Arquivo de seleção maior que o limite de segurança."
    end
    local sw, sh = png_dimensions(file)
    if sw ~= w or sh ~= h then
        return nil, "Dimensões da máscara de seleção incompatíveis."
    end
    local decoded, pixels = pcall(love.image.newImageData, file)
    if not decoded then
        return nil, "PNG da seleção inválido."
    end
    local s = empty(w, h, "restored")
    for y = 0, h - 1 do
        for x = 0, w - 1 do
            local _, _, _, a = pixels:getPixel(x, y)
            if a > 0 then add(s, x, y, a) end
        end
    end
    return finalize(s)
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
