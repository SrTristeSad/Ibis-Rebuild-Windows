-- Persistência limitada do histórico raster para o motor Lua/LÖVE.
-- PNG por snapshot + manifesto versionado; não altera os PNGs das camadas.
local Selection = require("lua_selection")
local History = {}
local MAX_PIXELS = 1024 * 1024
local MAX_STEPS = 8
local MAX_PNG_BYTES = 16 * 1024 * 1024
local MAX_MANIFEST_BYTES = 2048
local SIGNATURE = "\137PNG\r\n\26\n"
local PREFIX = "history_"
local serial = 0

local function file_path(path, generation, side, index, mask)
    return path .. "/" .. PREFIX .. generation .. "_" .. side ..
        "_" .. index .. (mask and "_selection" or "") .. ".png"
end

local function is_history_image(name)
    return name:match("^history_%d+_%d+_undo_[1-8]%.png$") or
        name:match("^history_%d+_%d+_undo_[1-8]_selection%.png$") or
        name:match("^history_%d+_%d+_redo_[1-8]%.png$") or
        name:match("^history_%d+_%d+_redo_[1-8]_selection%.png$")
end

-- Elimina somente os arquivos próprios de histórico; não toca layers.tsv,
-- selection.png, preview.png ou arquivos de autoria do usuário.
function History.cleanup(path, keep_generation)
    for _, name in ipairs(love.filesystem.getDirectoryItems(path)) do
        if is_history_image(name) and
           (not keep_generation or not name:find("^history_" ..
                keep_generation .. "_", 1, false)) then
            love.filesystem.remove(path .. "/" .. name)
        end
    end
    if not keep_generation and love.filesystem.getInfo(path .. "/history.tsv") then
        love.filesystem.remove(path .. "/history.tsv")
    end
end

local function u32(header, offset)
    local a, b, c, d = header:byte(offset, offset + 3)
    return ((a * 256 + b) * 256 + c) * 256 + d
end

local function decode(file, w, h)
    local info = love.filesystem.getInfo(file, "file")
    if not info or info.size < 24 or info.size > MAX_PNG_BYTES then
        return nil
    end
    local header = love.filesystem.read(file, 24)
    if not header or #header ~= 24 or header:sub(1, 8) ~= SIGNATURE
        or header:sub(13, 16) ~= "IHDR" or
        u32(header, 17) ~= w or u32(header, 21) ~= h then
        return nil
    end
    local success, pixels = pcall(love.image.newImageData, file)
    if not success or pixels:getWidth() ~= w or
       pixels:getHeight() ~= h then return nil end
    return pixels
end

local function write_snapshot(snapshot, filename)
    local ok, result = pcall(function() return snapshot:encode("png", filename) end)
    if not ok then return false, tostring(result) end
    if not love.filesystem.getInfo(filename, "file") then
        return false, "Falha ao gravar o PNG do histórico."
    end
    return true
end

local function list_entries(project, selection)
    local entries = {}
    for _, side in ipairs({"undo", "redo"}) do
        local stack = project[side]
        local output_index = 0
        for i = 1, math.min(MAX_STEPS, #stack) do
            local entry = stack[i]
            -- Camadas removidas invalidam os passos correspondentes, mas
            -- nunca devem impedir o salvamento do documento.
            if project.layers[entry.id] then
                output_index = output_index + 1
                entries[#entries + 1] = {
                    side = side, index = output_index,
                    id = entry.id, pixels = entry.pixels,
                    mask = selection and entry.selection_ref == selection and
                        entry.selection_state or nil
                }
            end
        end
    end
    return entries
end

-- Publica o manifesto somente DEPOIS de gravar todos os snapshots. Cada
-- salvamento usa uma geração nova, evitando sobrescrever um pacote anterior.
function History.save(project, path, selection)
    if project.w * project.h > MAX_PIXELS or
       (#project.undo == 0 and #project.redo == 0) then
        History.cleanup(path)
        return true, 0
    end
    local entries, err = list_entries(project, selection)
    if not entries then return false, err end
    if #entries == 0 then
        History.cleanup(path)
        return true, 0
    end
    serial = serial + 1
    local generation = tostring(os.time()) .. "_" .. tostring(serial)
    -- Não reutilizar nomes que já existam (reinício dentro do mesmo segundo).
    while love.filesystem.getInfo(file_path(path, generation, "undo", 1)) or
          love.filesystem.getInfo(file_path(path, generation, "redo", 1)) do
        serial = serial + 1
        generation = tostring(os.time()) .. "_" .. tostring(serial)
    end
    local lines = {"IBIS_LUA_HISTORY_V1\t" .. project.w .. "\t" ..
                   project.h .. "\t" .. generation}
    for _, item in ipairs(entries) do
        local filename = file_path(path, generation, item.side, item.index)
        local ok, reason = write_snapshot(item.pixels, filename)
        if not ok then return false, reason end
        if item.mask then
            local mok, mreason = Selection.save(item.mask,
                file_path(path, generation, item.side, item.index, true))
            if not mok then return false, mreason end
        end
        lines[#lines + 1] = table.concat({
            item.side, tostring(item.index), tostring(item.id),
            item.mask and "1" or "0"
        }, "\t")
    end
    local wrote, reason = love.filesystem.write(path .. "/history.tsv",
                                              table.concat(lines, "\n"))
    if not wrote then return false, reason end
    History.cleanup(path, generation)
    return true, #entries
end

-- Manifesto, contagens, identidades de camada e PNGs são validados num
-- conjunto temporário. Dados inválidos nunca substituem um histórico válido.
function History.load(project, path, selection)
    local info = love.filesystem.getInfo(path .. "/history.tsv", "file")
    if not info then return false, "Histórico ausente (projeto legado)." end
    if info.size > MAX_MANIFEST_BYTES or info.size < 30 or
       project.w * project.h > MAX_PIXELS then
        return false, "Histórico excede limites de leitura."
    end
    local data = love.filesystem.read(path .. "/history.tsv")
    if not data then return false, "Falha ao ler manifesto de histórico." end
    local first, rest = data:match("^([^\r\n]+)\r?\n(.*)$")
    if not first then return false, "Manifesto de histórico inválido." end
    local width, height, generation =
        first:match("^IBIS_LUA_HISTORY_V1\t(%d+)\t(%d+)\t(%d+_%d+)$")
    if not width or tonumber(width) ~= project.w or
       tonumber(height) ~= project.h then
        return false, "Histórico pertence a outra dimensão de documento."
    end
    local stacks = {undo = {}, redo = {}}
    local total = 0
    for line in rest:gmatch("[^\r\n]+") do
        local side, index, id, flag =
            line:match("^(undo)\t([1-8])\t(%d+)\t([01])$") 
        if not side then
            side, index, id, flag =
                line:match("^(redo)\t([1-8])\t(%d+)\t([01])$")
        end
        id, index = tonumber(id), tonumber(index)
        if not side or not id or id < 1 or not project.layers[id] or
           index ~= #stacks[side] + 1 or total >= MAX_STEPS * 2 then
            return false, "Manifesto de histórico incompleto ou inconsistente."
        end
        local png = decode(file_path(path, generation, side, index),
                           project.w, project.h)
        if not png then return false, "Snapshot PNG inválido no histórico." end
        local entry = {id = id, pixels = png}
        if flag == "1" then
            if not selection then
                return false, "Histórico de seleção sem máscara ativa."
            end
            local mask = Selection.load(file_path(path, generation,
                                     side, index, true), project.w, project.h)
            if not mask then
                return false, "Máscara PNG inválida no histórico."
            end
            entry.selection_ref = selection
            entry.selection_state = mask
        end
        stacks[side][#stacks[side] + 1] = entry
        total = total + 1
    end
    if total == 0 then return false, "Manifesto sem snapshots." end
    project.undo, project.redo = stacks.undo, stacks.redo
    return true, total
end

return History
