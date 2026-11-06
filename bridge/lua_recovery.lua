-- Cópia de recuperação da última obra já confirmada.
-- Conserva os formatos PNG/TSV existentes; nada no frontend precisa mudar.
local Recovery = {}
local DIRECTORY = ".save-recovery"
local MARKER = "pending.tsv"

local function managed(name)
    return name == "layers.tsv" or name == "document.tsv" or
        name == "preview.png" or name == "selection.png" or
        name == "history.tsv" or name == "selection_history.tsv" or
        name:match("^layer_%d+%.png$") or
        name:match("^history_%d+_%d+_undo_[1-8]%.png$") or
        name:match("^history_%d+_%d+_redo_[1-8]%.png$") or
        name:match("^history_%d+_%d+_undo_[1-8]_selection%.png$") or
        name:match("^history_%d+_%d+_redo_[1-8]_selection%.png$") or
        name:match("^selection_history_%d+_%d+_[a-z]+_%d+%.png$")
end

local function snapshot_names(path)
    local names = {}
    for _, name in ipairs(love.filesystem.getDirectoryItems(path)) do
        if managed(name) and love.filesystem.getInfo(path .. "/" .. name, "file") then
            names[#names + 1] = name
        end
    end
    table.sort(names)
    return names
end

-- Mantém apenas um bloco de cada arquivo em RAM, mesmo para PNGs grandes.
-- Sem novas dependências: File:read/write/close fazem parte do LÖVE 11.5.
local COPY_CHUNK = 64 * 1024
local function copy_file(source, destination)
    local input = love.filesystem.newFile(source)
    local opened, err = input:open("r")
    if not opened then return false, err or "Falha ao abrir origem" end
    local size = input:getSize()
    if not size or size < 0 then
        input:close()
        return false, "Tamanho de origem inválido"
    end
    local output = love.filesystem.newFile(destination)
    opened, err = output:open("w")
    if not opened then
        input:close()
        return false, err or "Falha ao abrir destino"
    end
    local remaining = size
    local good, reason = true, nil
    while remaining > 0 do
        local chunk = input:read(math.min(COPY_CHUNK, remaining))
        if not chunk or #chunk == 0 then
            good, reason = false, "Leitura incompleta na cópia de recuperação"
            break
        end
        local wrote, write_err = output:write(chunk)
        if not wrote then
            good, reason = false, write_err or "Falha ao escrever cópia"
            break
        end
        remaining = remaining - #chunk
    end
    local output_closed = output:close()
    local input_closed = input:close()
    if not output_closed or not input_closed then
        good, reason = false, reason or "Falha ao fechar arquivo da cópia"
    end
    if good then
        local info = love.filesystem.getInfo(destination, "file")
        if not info or info.size ~= size then
            good, reason = false, "Tamanho da cópia divergente"
        end
    end
    return good, reason
end

local function location(path) return path .. "/" .. DIRECTORY end

local function clear_stale(path)
    local dir = location(path)
    if not love.filesystem.getInfo(dir, "directory") then return true end
    for _, name in ipairs(love.filesystem.getDirectoryItems(dir)) do
        local ok = love.filesystem.remove(dir .. "/" .. name)
        if not ok then return false, "Falha ao limpar cópia de recuperação" end
    end
    if not love.filesystem.remove(dir) then
        return false, "Falha ao remover diretório de recuperação"
    end
    return true
end

-- Se o marcador existir, um save anterior pode ter sobrescrito apenas
-- alguns arquivos. Primeiro restaura todos os anteriores; depois remove
-- quaisquer arquivos novos que o save interrompido tenha criado.
function Recovery.restore(path)
    local dir = location(path)
    local marker = dir .. "/" .. MARKER
    if not love.filesystem.getInfo(marker, "file") then return true end
    local contents = love.filesystem.read(marker)
    if not contents or not contents:match("^v1\n") then
        return false, "Manifesto de recuperação inválido"
    end
    local existing = {}
    for name in contents:gmatch("([^\n]+)\n?") do
        if name ~= "v1" then
            if not managed(name) or existing[name] then
                return false, "Arquivo inesperado na recuperação"
            end
            existing[name] = true
        end
    end
    -- Validar a presença e o tamanho dos backups antes de modificar a obra.
    -- A transferência é sequencial e nunca mantém todos os PNGs em RAM.
    local names = {}
    for name in pairs(existing) do
        local info = love.filesystem.getInfo(dir .. "/" .. name, "file")
        if not info or type(info.size) ~= "number" then
            return false, "Cópia de recuperação incompleta"
        end
        names[#names + 1] = name
    end
    table.sort(names)
    for _, name in ipairs(names) do
        local ok, err = copy_file(dir .. "/" .. name, path .. "/" .. name)
        if not ok then return false, err or "Falha ao restaurar obra" end
    end
    for _, name in ipairs(snapshot_names(path)) do
        if not existing[name] and not love.filesystem.remove(path .. "/" .. name) then
            return false, "Falha ao remover arquivo de salvamento interrompido"
        end
    end
    -- Remover o marcador primeiro: um crash durante a limpeza jamais
    -- acionará uma restauração incompleta na próxima abertura.
    if not love.filesystem.remove(marker) then
        return false, "Falha ao finalizar recuperação"
    end
    clear_stale(path)
    return true
end

function Recovery.begin(path)
    local ok, err = Recovery.restore(path)
    if not ok then return false, err end
    -- A obra ainda não possui versão anterior confirmada.
    if not love.filesystem.getInfo(path .. "/layers.tsv", "file") then
        return true
    end
    ok, err = clear_stale(path)
    if not ok then return false, err end
    local dir = location(path)
    if not love.filesystem.createDirectory(dir) then
        return false, "Falha ao criar diretório de recuperação"
    end
    local names = snapshot_names(path)
    for _, name in ipairs(names) do
        ok, err = copy_file(path .. "/" .. name, dir .. "/" .. name)
        if not ok then return false, err end
    end
    -- Só publica o marcador após copiar o conjunto inteiro.
    return love.filesystem.write(dir .. "/" .. MARKER,
        "v1\n" .. table.concat(names, "\n") .. "\n")
end

function Recovery.commit(path)
    local dir = location(path)
    local marker = dir .. "/" .. MARKER
    if not love.filesystem.getInfo(marker, "file") then return true end
    if not love.filesystem.remove(marker) then
        return false, "Falha ao concluir salvamento"
    end
    -- O backup antigo pode ser limpo mais tarde se a limpeza falhar.
    clear_stale(path)
    return true
end

return Recovery
