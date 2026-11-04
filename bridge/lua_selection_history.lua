-- Persistência independente da timeline de máscara; nunca altera raster.
-- O manifesto é publicado por último e referencia uma geração de PNGs
-- validada integralmente antes de adotar qualquer estado.
local Selection = require("lua_selection")
local SelectionHistory = {}

local MAX_PIXELS = 1024 * 1024
local MAX_STEPS = 8
local MAX_MANIFEST_BYTES = 4096
local MANIFEST = "selection_history.tsv"
local HEADER = "IBIS_LUA_SELECTION_HISTORY_V1"
local serial = 0

local function supported(w, h)
    return type(w) == "number" and type(h) == "number" and
        w == math.floor(w) and h == math.floor(h) and
        w > 0 and h > 0 and w * h <= MAX_PIXELS
end

local function filename(path, generation, side, index)
    return string.format("%s/selection_history_%s_%s_%d.png",
                         path, generation, side, index)
end

local function is_snapshot(name)
    local generation, side, index =
        name:match("^selection_history_(%d+_%d+)_(undo)_(%d+)%.png$")
    if not generation then
        generation, side, index =
            name:match("^selection_history_(%d+_%d+)_(redo)_(%d+)%.png$")
    end
    return generation, side, tonumber(index)
end

local function clean_generation(path, generation)
    if not love.filesystem.getInfo(path, "directory") then return end
    for _, name in ipairs(love.filesystem.getDirectoryItems(path)) do
        local found = is_snapshot(name)
        if found and found == generation then
            love.filesystem.remove(path .. "/" .. name)
        end
    end
end

-- Descarta somente arquivos desta funcionalidade. Nunca toca em
-- history.tsv, PNGs das camadas, selection.png nem outros arquivos.
function SelectionHistory.cleanup(path, keep_generation)
    if not love.filesystem.getInfo(path, "directory") then return end
    for _, name in ipairs(love.filesystem.getDirectoryItems(path)) do
        local generation = is_snapshot(name)
        if generation and generation ~= keep_generation then
            love.filesystem.remove(path .. "/" .. name)
        end
    end
    if not keep_generation and
       love.filesystem.getInfo(path .. "/" .. MANIFEST, "file") then
        love.filesystem.remove(path .. "/" .. MANIFEST)
    end
end

-- Checksum determinístico da cobertura quantizada, indiferente à ordem
-- de iteração da tabela Lua. Evita aceitar PNGs trocados ou snapshots
-- de uma seleção diferente como parte de uma geração. Não é criptográfico.
local function signature(s, w, h)
    if not s then return "empty" end
    if s.w ~= w or s.h ~= h or not s.mask or
       not s.count or s.count <= 0 then return nil end
    local count, sum, mixed = 0, 0, 0
    for key in pairs(s.mask) do
        if type(key) ~= "number" or key ~= math.floor(key) or
           key < 0 or key >= w * h then return nil end
        local weight = s.weights and s.weights[key] or 1
        if type(weight) ~= "number" or weight ~= weight or
           weight <= 0 or weight > 1 then return nil end
        local byte = math.floor(weight * 255 + 0.5)
        count = count + 1
        sum = (sum + (key + 1) * 257 + byte) % 2147483647
        mixed = (mixed + ((key + 1) % 104729) * byte) % 2147483647
    end
    if count ~= s.count then return nil end
    return string.format("%d_%d_%d", count, sum, mixed)
end

local function validate_stack(stack, w, h)
    if type(stack) ~= "table" or #stack > MAX_STEPS then return false end
    local pixels = 0
    for _, entry in ipairs(stack) do
        if type(entry) ~= "table" then return false end
        local value = entry.mask
        local sign = signature(value, w, h)
        if not sign then return false end
        if value then pixels = pixels + value.count end
    end
    return pixels <= MAX_PIXELS or #stack <= 1
end

function SelectionHistory.save(path, w, h, current, undo, redo)
    if not supported(w, h) or not validate_stack(undo, w, h) or
       not validate_stack(redo, w, h) then
        return false, "Histórico de máscara excede os limites."
    end
    if #undo + #redo == 0 then
        SelectionHistory.cleanup(path)
        return true, 0
    end
    local current_sign = signature(current, w, h)
    if not current_sign then return false, "Máscara atual inválida." end
    if not love.filesystem.getInfo(path, "directory") then
        return false, "Pasta da obra não encontrada."
    end

    local existing = love.filesystem.read(path .. "/" .. MANIFEST)
    local old_generation = existing and existing:match(
        "^IBIS_LUA_SELECTION_HISTORY_V1\t%d+\t%d+\t(%d+_%d+)")
    serial = serial + 1
    local generation = tostring(os.time()) .. "_" .. tostring(serial)
    while generation == old_generation or
          love.filesystem.getInfo(filename(path, generation, "undo", 1)) or
          love.filesystem.getInfo(filename(path, generation, "redo", 1)) do
        serial = serial + 1
        generation = tostring(os.time()) .. "_" .. tostring(serial)
    end

    local lines = {table.concat({HEADER, w, h, generation,
                                current_sign}, "\t")}
    for _, side in ipairs({"undo", "redo"}) do
        local stack = side == "undo" and undo or redo
        for index, entry in ipairs(stack) do
            local mask = entry.mask
            local sign = signature(mask, w, h)
            if mask then
                local ok, reason = Selection.save(mask,
                                  filename(path, generation, side, index))
                if not ok then
                    clean_generation(path, generation)
                    return false, reason
                end
            end
            lines[#lines + 1] = table.concat(
                {side, tostring(index), mask and "1" or "0", sign}, "\t")
        end
    end

    local ok, reason = love.filesystem.write(path .. "/" .. MANIFEST,
                                             table.concat(lines, "\n"))
    if not ok then
        clean_generation(path, generation)
        return false, reason
    end
    SelectionHistory.cleanup(path, generation)
    return true, #undo + #redo
end

-- Falhas de leitura são opcionais: o chamador conserva a seleção PNG
-- atual e simplesmente inicia pilhas vazias, sem bloquear a obra.
function SelectionHistory.load(path, w, h, current)
    if not supported(w, h) then return nil, "Dimensão inválida." end
    local path_manifest = path .. "/" .. MANIFEST
    local info = love.filesystem.getInfo(path_manifest, "file")
    if not info then return nil, "Histórico de seleção ausente." end
    if info.size < 45 or info.size > MAX_MANIFEST_BYTES then
        return nil, "Manifesto de seleção fora do limite."
    end
    local contents = love.filesystem.read(path_manifest)
    if not contents then return nil, "Falha ao ler manifesto de seleção." end
    local head, rest = contents:match("^([^\r\n]+)\r?\n(.*)$")
    if not head then return nil, "Manifesto de seleção incompleto." end
    local sw, sh, generation, current_sign = head:match(
        "^IBIS_LUA_SELECTION_HISTORY_V1\t(%d+)\t(%d+)\t(%d+_%d+)\t([%w_]+)$")
    if not sw or tonumber(sw) ~= w or tonumber(sh) ~= h or
       current_sign ~= signature(current, w, h) then
        return nil, "Histórico de seleção não corresponde à obra atual."
    end

    local stacks = {undo = {}, redo = {}}
    for line in rest:gmatch("[^\r\n]+") do
        local side, index, active, sign = line:match(
            "^(%a+)\t(%d+)\t([01])\t([%w_]+)$")
        index = tonumber(index)
        if (side ~= "undo" and side ~= "redo") or not index or
           index ~= #stacks[side] + 1 or index > MAX_STEPS then
            return nil, "Ordem inválida de snapshots da seleção."
        end
        local mask
        if active == "1" then
            mask = Selection.load(filename(path, generation, side, index),
                                  w, h)
            if not mask then
                return nil, "PNG de snapshot da seleção ausente ou inválido."
            end
        elseif active ~= "0" or sign ~= "empty" then
            return nil, "Tipo de snapshot da seleção inválido."
        end
        if not sign or sign ~= signature(mask, w, h) then
            return nil, "Checksum de snapshot da seleção incompatível."
        end
        stacks[side][#stacks[side] + 1] = {mask = mask}
    end
    if #stacks.undo + #stacks.redo == 0 or
       not validate_stack(stacks.undo, w, h) or
       not validate_stack(stacks.redo, w, h) then
        return nil, "Histórico de seleção vazio ou acima do limite."
    end
    return stacks
end

return SelectionHistory
