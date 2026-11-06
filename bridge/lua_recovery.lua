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

-- Adler-32 incremental, para detectar truncamentos e alterações de bytes
-- com memória constante. Checksum de integridade, não criptográfico.
local function adler_update(a, b, bytes)
    for i = 1, #bytes do
        a = (a + bytes:byte(i)) % 65521
        b = (b + a) % 65521
    end
    return a, b
end

local function checksum_file(filename)
    local file = love.filesystem.newFile(filename)
    local opened, err = file:open("r")
    if not opened then return nil, nil, err or "Arquivo inacessível" end
    local size = file:getSize()
    if not size or size < 0 then
        file:close()
        return nil, nil, "Tamanho de arquivo inválido"
    end
    local a, b, remaining = 1, 0, size
    local valid = true
    while remaining > 0 do
        local bytes = file:read(math.min(COPY_CHUNK, remaining))
        if not bytes or #bytes == 0 then valid = false; break end
        a, b = adler_update(a, b, bytes)
        remaining = remaining - #bytes
    end
    local closed = file:close()
    if not valid or not closed then
        return nil, nil, "Leitura incompleta ao verificar backup"
    end
    return size, string.format("%08x", b * 65536 + a)
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
    if not contents or not contents:match("^v[12]\n") then
        return false, "Manifesto de recuperação inválido"
    end
    -- v1 foi usado nas obras anteriores; v2 adiciona tamanho + Adler-32.
    local version = contents:match("^(v[12])\n")
    if not version then return false, "Versão de recuperação inválida" end
    local existing, names = {}, {}
    for line in contents:gmatch("([^\n]+)") do
        if line ~= version then
            local name, size, hash
            if version == "v2" then
                name, size, hash = line:match("^([^\t]+)\t(%d+)\t(%x%x%x%x%x%x%x%x)$")
            else
                name = line
            end
            if not name or not managed(name) or existing[name] then
                return false, "Arquivo inesperado na recuperação"
            end
            local info = love.filesystem.getInfo(dir .. "/" .. name, "file")
            if not info or type(info.size) ~= "number" then
                return false, "Cópia de recuperação incompleta"
            end
            if version == "v2" then
                local expected = tonumber(size)
                if not expected or expected ~= info.size then
                    return false, "Tamanho do backup não confere"
                end
                local measured, actual, err = checksum_file(dir .. "/" .. name)
                if not measured or measured ~= expected or actual ~= hash then
                    return false, err or "Checksum de recuperação divergente"
                end
            end
            existing[name] = version == "v2" and
                {size = tonumber(size), checksum = hash} or true
            names[#names + 1] = name
        end
    end
    table.sort(names)
    for _, name in ipairs(names) do
        local target = path .. "/" .. name
        local ok, err = copy_file(dir .. "/" .. name, target)
        if not ok then return false, err or "Falha ao restaurar obra" end
        -- Uma falha silenciosa na gravação pode conservar o tamanho correto.
        -- Conferir o destino ANTES de remover o marcador de recuperação:
        -- se houver divergência, a próxima tentativa ainda tem o backup.
        if version == "v2" then
            local size, hash, check_err = checksum_file(target)
            local expected = existing[name]
            if not size or size ~= expected.size or
               hash ~= expected.checksum then
                return false, check_err or
                    "Arquivo restaurado diverge do backup"
            end
        end
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
    local entries = {}
    for _, name in ipairs(names) do
        ok, err = copy_file(path .. "/" .. name, dir .. "/" .. name)
        if not ok then return false, err end
        local size, hash, check_err = checksum_file(dir .. "/" .. name)
        if not size then return false, check_err end
        entries[#entries + 1] = name .. "\t" .. size .. "\t" .. hash
    end
    -- Só publica o marcador após verificar todas as cópias.
    return love.filesystem.write(dir .. "/" .. MARKER,
        "v2\n" .. table.concat(entries, "\n") .. "\n")
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


-- Primeira gravação: a obra ainda não tem snapshot confirmado para rollback.
-- Gravar primeiro em um diretório oculto evita publicar camadas/TSVs parciais.
-- Um marcador "ready" guarda metadados suficientes para concluir a publicação
-- no próximo início, mesmo se a execução terminar antes de atualizar index.tsv.
local FIRST_DIRECTORY = ".first-save"
local FIRST_MARKER = "ready.tsv"
local FIRST_HEADER = "IBIS_LUA_FIRST_SAVE_V1"

local function first_dir(path) return path .. "/" .. FIRST_DIRECTORY end

local function clear_directory(dir)
    if not love.filesystem.getInfo(dir, "directory") then return true end
    for _, name in ipairs(love.filesystem.getDirectoryItems(dir)) do
        if not love.filesystem.remove(dir .. "/" .. name) then
            return false, "Falha ao limpar diretório da primeira gravação"
        end
    end
    if not love.filesystem.remove(dir) then
        return false, "Falha ao remover diretório da primeira gravação"
    end
    return true
end

function Recovery.begin_first(path)
    local dir = first_dir(path)
    if love.filesystem.getInfo(dir .. "/" .. FIRST_MARKER, "file") then
        return nil, "Primeiro salvamento anterior aguarda publicação"
    end
    local ok, err = clear_directory(dir)
    if not ok then return nil, err end
    if not love.filesystem.createDirectory(dir) then
        return nil, "Falha ao preparar primeira gravação"
    end
    return dir
end

function Recovery.ready_first(path, width, height, title)
    if type(width) ~= "number" or type(height) ~= "number" or
       width < 1 or height < 1 or width % 1 ~= 0 or height % 1 ~= 0 or
       type(title) ~= "string" or title == "" or
       title:find("[\t\r\n]") then
        return false, "Metadados inválidos da primeira gravação"
    end
    local dir = first_dir(path)
    if not love.filesystem.getInfo(dir .. "/layers.tsv", "file") or
       not love.filesystem.getInfo(dir .. "/document.tsv", "file") then
        return false, "Manifestos incompletos da primeira gravação"
    end
    local names = snapshot_names(dir)
    local has_layer = false
    local lines = {FIRST_HEADER,
        table.concat({width, height, title}, "\t")}
    for _, name in ipairs(names) do
        if name:match("^layer_%d+%.png$") then has_layer = true end
        local size, hash, err = checksum_file(dir .. "/" .. name)
        if not size then return false, err end
        lines[#lines + 1] = name .. "\t" .. size .. "\t" .. hash
    end
    if not has_layer then return false, "Primeira gravação sem PNG de camada" end
    return love.filesystem.write(dir .. "/" .. FIRST_MARKER,
        table.concat(lines, "\n") .. "\n")
end

local function first_snapshot(path)
    local dir = first_dir(path)
    local marker = dir .. "/" .. FIRST_MARKER
    local data = love.filesystem.read(marker)
    if not data or data:sub(-1) ~= "\n" then
        return nil, "Marcador incompleto da primeira gravação"
    end
    local lines = {}
    for line in data:gmatch("([^\r\n]+)") do
        lines[#lines + 1] = line
    end
    if #lines < 4 or lines[1] ~= FIRST_HEADER then
        return nil, "Marcador inválido da primeira gravação"
    end
    local width, height, title =
        lines[2]:match("^(%d+)\t(%d+)\t([^\t]+)$")
    width, height = tonumber(width), tonumber(height)
    if not width or not height or width < 1 or height < 1 or
       not title or title == "" then
        return nil, "Dimensões inválidas da primeira gravação"
    end
    local names, seen, has_layer = {}, {}, false
    local required = {["layers.tsv"] = false, ["document.tsv"] = false}
    for i = 3, #lines do
        local name, size, hash =
            lines[i]:match("^([^\t]+)\t(%d+)\t(%x%x%x%x%x%x%x%x)$")
        if not name or not managed(name) or seen[name] then
            return nil, "Arquivo inválido no primeiro salvamento"
        end
        local expected = tonumber(size)
        local measured, actual, err = checksum_file(dir .. "/" .. name)
        if not measured or measured ~= expected or actual ~= hash then
            return nil, err or "Backup inicial corrompido"
        end
        if required[name] ~= nil then required[name] = true end
        if name:match("^layer_%d+%.png$") then has_layer = true end
        seen[name] = {size = expected, checksum = hash}
        names[#names + 1] = name
    end
    if not required["layers.tsv"] or not required["document.tsv"] or
       not has_layer then
        return nil, "Primeira gravação sem arquivos essenciais"
    end
    table.sort(names)
    return {width = width, height = height, title = title,
            names = names, files = seen}
end

function Recovery.publish_first(path)
    local snapshot, err = first_snapshot(path)
    if not snapshot then return nil, err end
    local dir = first_dir(path)
    -- Validar TUDO antes de alterar qualquer arquivo publicado. O marcador
    -- só será removido depois do índice, permitindo repetir cópias falhas.
    for _, name in ipairs(snapshot.names) do
        local target = path .. "/" .. name
        local ok, copy_err = copy_file(dir .. "/" .. name, target)
        if not ok then return nil, copy_err or "Falha ao publicar obra" end
        local size, hash, check_err = checksum_file(target)
        local expected = snapshot.files[name]
        if not size or size ~= expected.size or hash ~= expected.checksum then
            return nil, check_err or "Arquivo publicado difere do original"
        end
    end
    for _, name in ipairs(snapshot_names(path)) do
        if not snapshot.files[name] and
           not love.filesystem.remove(path .. "/" .. name) then
            return nil, "Falha ao limpar gravação inicial incompleta"
        end
    end
    return snapshot
end

function Recovery.commit_first(path)
    local dir = first_dir(path)
    local marker = dir .. "/" .. FIRST_MARKER
    if love.filesystem.getInfo(marker, "file") and
       not love.filesystem.remove(marker) then
        return false, "Falha ao concluir primeira gravação"
    end
    -- Uma limpeza posterior pode remover sobras sem reabrir a transação.
    clear_directory(dir)
    return true
end

local function read_index(root)
    local path = root .. "/index.tsv"
    if not love.filesystem.getInfo(path, "file") then return "" end
    local data = love.filesystem.read(path)
    if not data then return nil, "Falha ao ler índice da galeria" end
    return data
end

local function has_key(index, key)
    for line in index:gmatch("[^\r\n]+") do
        if line:match("^([%w_%-]+)\t") == key then return true end
    end
    return false
end

-- Reexecutável após falha de publicação ou do índice. Se a obra já aparece
-- no índice, a publicação terminou; não substituir uma versão mais recente.
function Recovery.recover_first(root)
    local entries = love.filesystem.getDirectoryItems(root)
    table.sort(entries)
    for _, key in ipairs(entries) do
        local path = root .. "/" .. key
        if key:match("^art_%d+_%d+$") and
           love.filesystem.getInfo(path, "directory") and
           love.filesystem.getInfo(first_dir(path) .. "/" ..
                                   FIRST_MARKER, "file") then
            local index, read_err = read_index(root)
            if not index then return false, read_err end
            if not has_key(index, key) then
                local snapshot, err = Recovery.publish_first(path)
                if not snapshot then return false, err end
                local entry = table.concat({key, snapshot.width,
                    snapshot.height, snapshot.title}, "\t")
                local new_index = index == "" and entry or
                    (index:gsub("\n+$", "") .. "\n" .. entry)
                local ok, write_err = love.filesystem.write(
                    root .. "/index.tsv", new_index)
                if not ok then return false, write_err end
            end
            local ok, err = Recovery.commit_first(path)
            if not ok then return false, err end
        end
    end
    return true
end

function Recovery.first_indexed(root, key)
    local index = read_index(root)
    return index and has_key(index, key) or false
end

return Recovery
