-- Empacotamento Windows inteiramente orquestrado em Lua.
-- Usa LÖVE/LuaJIT existente e os comandos do sistema para enumerar
-- arquivos. Nao invoca Python, CMake ou compilador C++.
local bit=require('bit')
local band,bxor,rshift,bnot=bit.band,bit.bxor,bit.rshift,bit.bnot
local floor=math.floor
local function u32(n) return n<0 and n+4294967296 or n end
local function le16(n)
    return string.char(n%256,floor(n/256)%256)
end
local function le32(n)
    return le16(n%65536)..le16(floor(n/65536)%65536)
end
local function crc32(data)
    local crc=0xffffffff
    for i=1,#data do
        crc=bxor(crc,data:byte(i))
        for _=1,8 do
            if band(crc,1)~=0 then crc=bxor(rshift(crc,1),0xedb88320)
            else crc=rshift(crc,1) end
        end
    end
    return u32(bnot(crc))
end
local function normalized(path)
    return (path:gsub('/','\\'):gsub('\\+$',''))
end
local function read(path)
    local f,err=io.open(path,'rb')
    assert(f,'Falha ao ler '..path..': '..tostring(err))
    local bytes=f:read('*a');f:close()
    return bytes
end
local function write(path,bytes)
    local f,err=io.open(path,'wb')
    assert(f,'Falha ao gravar '..path..': '..tostring(err))
    assert(f:write(bytes));f:close()
end
local function files(directory,recursive)
    -- O diretorio e informado pelo usuario por meio do build.ps1.
    local glob=directory..'\\*'
    local cmd='dir /b /a-d '..(recursive and '/s ' or '')..'"'..glob..'" 2>nul'
    local pipe,err=io.popen(cmd,'r')
    assert(pipe,'Nao foi possivel listar arquivos: '..tostring(err))
    local out={}
    for full in pipe:lines() do
        full=normalized(full:gsub('\r
            local relative=full:sub(#directory+2):gsub('\\','/')
            if relative~='' and relative~='.' and not relative:match('^%.git/') then
                out[#out+1]={full=full,relative=relative}
            end
        end
    end
    pipe:close()
    table.sort(out,function(a,b)return a.relative<b.relative end)
    return out
end
local function makeLove(app,archive)
    local entries=files(app,true)
    assert(#entries>0,'Diretorio app vazio')
    local found=false
    local zip,err=io.open(archive,'wb')
    assert(zip,err)
    local directory={}
    local size=0
    local function append(bytes)
        assert(zip:write(bytes))
        size=size+#bytes
    end
    for _,entry in ipairs(entries) do
        local name=entry.relative
        assert(#name<65536 and not name:find('%.%./',1,true),
            'Nome ZIP invalido: '..name)
        if name=='main.lua' then found=true end
        local bytes=read(entry.full)
        local crc=crc32(bytes)
        assert(#bytes<4294967296 and size<4294967296,
            'O pacote ultrapassou ZIP32')
        local offset=size
        -- Local header: ZIP stored; LÖVE nao exige compressao dos fontes.
        append(le32(0x04034b50)..le16(20)..le16(0)..le16(0)
            ..le16(0)..le16(0)..le32(crc)..le32(#bytes)
            ..le32(#bytes)..le16(#name)..le16(0)..name)
        append(bytes)
        directory[#directory+1]={name=name,crc=crc,length=#bytes,offset=offset}
    end
    assert(found,'app/main.lua nao encontrado')
    local central=size
    for _,entry in ipairs(directory) do
        local name=entry.name
        append(le32(0x02014b50)..le16(20)..le16(20)
            ..le16(0)..le16(0)..le16(0)..le16(0)
            ..le32(entry.crc)..le32(entry.length)..le32(entry.length)
            ..le16(#name)..le16(0)..le16(0)..le16(0)
            ..le16(0)..le32(0)..le32(entry.offset)..name)
    end
    local centralSize=size-central
    assert(#directory<65536,'Numero de arquivos acima do limite ZIP32')
    append(le32(0x06054b50)..le16(0)..le16(0)
        ..le16(#directory)..le16(#directory)
        ..le32(centralSize)..le32(central)..le16(0))
    zip:close()
    return #entries,size
end
local function fuse(runtime,archive,target)
    local binary=io.open(target,'wb')
    assert(binary,'Falha ao criar executavel')
    for _,path in ipairs({runtime..'\\love.exe',archive}) do
        local input=assert(io.open(path,'rb'),'Arquivo nao encontrado: '..path)
        while true do
            local chunk=input:read(65536)
            if not chunk then break end
            assert(binary:write(chunk))
        end
        input:close()
    end
    binary:close()
end
local function build()
    assert(jit and jit.version,'O empacotador exige LuaJIT do LÖVE')
    local root=os.getenv('IBIS_PROJECT_ROOT')
    local runtime=os.getenv('IBIS_LOVE_RUNTIME')
    assert(root and root~='' and runtime and runtime~='',
        'Configure IBIS_PROJECT_ROOT e IBIS_LOVE_RUNTIME no build.ps1')
    root=normalized(root);runtime=normalized(runtime)
    local dist=root..'\\dist'
    local ok=os.execute('if not exist "'..dist..'" mkdir "'..dist..'"')
    assert(ok==true or ok==0,'Nao foi possivel criar dist')
    local archive=dist..'\\Android1412Rebuild.love'
    local exe=dist..'\\Android1412Rebuild.exe'
    local count,bytes=makeLove(root..'\\app',archive)
    fuse(runtime,archive,exe)
    -- Nenhuma DLL compilada pelo projeto integra a distribuicao Lua.
    os.remove(dist..'\\rebuild_core.dll')
    local dlls=0
    for _,entry in ipairs(files(runtime,false)) do
        if entry.relative:lower():match('%.dll$') then
            write(dist..'\\'..entry.relative,read(entry.full))
            dlls=dlls+1
        end
    end
    assert(dlls>0,'Nenhuma DLL do runtime LÖVE encontrada; pacote incompleto')
    print(('Lua build: %d fontes, ZIP %d bytes, %d DLLs oficiais.'):format(count,bytes,dlls))
    print('Executavel: '..exe)
end
function love.load()
    local ok,err=xpcall(build,debug.traceback)
    if not ok then
        io.stderr:write('ERRO build Lua: '..tostring(err)..'\n')
        love.event.quit(1)
    else
        love.event.quit(0)
    end
end
,''))
        -- "dir /b" retorna so o nome; "dir /s /b" retorna o caminho.
        if not recursive and not full:find('\\',1,true) then
            full=directory..'\\'..full
        end
        if full:sub(1,#directory):lower()==directory:lower() then
            local relative=full:sub(#directory+2):gsub('\\','/')
            if relative~='' and relative~='.' and not relative:match('^%.git/') then
                out[#out+1]={full=full,relative=relative}
            end
        end
    end
    pipe:close()
    table.sort(out,function(a,b)return a.relative<b.relative end)
    return out
end
local function makeLove(app,archive)
    local entries=files(app,true)
    assert(#entries>0,'Diretorio app vazio')
    local found=false
    local zip,err=io.open(archive,'wb')
    assert(zip,err)
    local directory={}
    local size=0
    local function append(bytes)
        assert(zip:write(bytes))
        size=size+#bytes
    end
    for _,entry in ipairs(entries) do
        local name=entry.relative
        assert(#name<65536 and not name:find('%.%./',1,true),
            'Nome ZIP invalido: '..name)
        if name=='main.lua' then found=true end
        local bytes=read(entry.full)
        local crc=crc32(bytes)
        assert(#bytes<4294967296 and size<4294967296,
            'O pacote ultrapassou ZIP32')
        local offset=size
        -- Local header: ZIP stored; LÖVE nao exige compressao dos fontes.
        append(le32(0x04034b50)..le16(20)..le16(0)..le16(0)
            ..le16(0)..le16(0)..le32(crc)..le32(#bytes)
            ..le32(#bytes)..le16(#name)..le16(0)..name)
        append(bytes)
        directory[#directory+1]={name=name,crc=crc,length=#bytes,offset=offset}
    end
    assert(found,'app/main.lua nao encontrado')
    local central=size
    for _,entry in ipairs(directory) do
        local name=entry.name
        append(le32(0x02014b50)..le16(20)..le16(20)
            ..le16(0)..le16(0)..le16(0)..le16(0)
            ..le32(entry.crc)..le32(entry.length)..le32(entry.length)
            ..le16(#name)..le16(0)..le16(0)..le16(0)
            ..le16(0)..le32(0)..le32(entry.offset)..name)
    end
    local centralSize=size-central
    assert(#directory<65536,'Numero de arquivos acima do limite ZIP32')
    append(le32(0x06054b50)..le16(0)..le16(0)
        ..le16(#directory)..le16(#directory)
        ..le32(centralSize)..le32(central)..le16(0))
    zip:close()
    return #entries,size
end
local function fuse(runtime,archive,target)
    local binary=io.open(target,'wb')
    assert(binary,'Falha ao criar executavel')
    for _,path in ipairs({runtime..'\\love.exe',archive}) do
        local input=assert(io.open(path,'rb'),'Arquivo nao encontrado: '..path)
        while true do
            local chunk=input:read(65536)
            if not chunk then break end
            assert(binary:write(chunk))
        end
        input:close()
    end
    binary:close()
end
local function build()
    assert(jit and jit.version,'O empacotador exige LuaJIT do LÖVE')
    local root=os.getenv('IBIS_PROJECT_ROOT')
    local runtime=os.getenv('IBIS_LOVE_RUNTIME')
    assert(root and root~='' and runtime and runtime~='',
        'Configure IBIS_PROJECT_ROOT e IBIS_LOVE_RUNTIME no build.ps1')
    root=normalized(root);runtime=normalized(runtime)
    local dist=root..'\\dist'
    local ok=os.execute('if not exist "'..dist..'" mkdir "'..dist..'"')
    assert(ok==true or ok==0,'Nao foi possivel criar dist')
    local archive=dist..'\\Android1412Rebuild.love'
    local exe=dist..'\\Android1412Rebuild.exe'
    local count,bytes=makeLove(root..'\\app',archive)
    fuse(runtime,archive,exe)
    local dlls=0
    for _,entry in ipairs(files(runtime,false)) do
        if entry.relative:lower():match('%.dll$') then
            write(dist..'\\'..entry.relative,read(entry.full))
            dlls=dlls+1
        end
    end
    assert(dlls>0,'Nenhuma DLL do runtime LÖVE encontrada; pacote incompleto')
    print(('Lua build: %d fontes, ZIP %d bytes, %d DLLs oficiais.'):format(count,bytes,dlls))
    print('Executavel: '..exe)
end
function love.load()
    local ok,err=xpcall(build,debug.traceback)
    if not ok then
        io.stderr:write('ERRO build Lua: '..tostring(err)..'\n')
        love.event.quit(1)
    else
        love.event.quit(0)
    end
end
