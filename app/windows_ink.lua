-- Nao existe ponte Win32 C++ nesta implementacao em Lua.
-- Eventos de mouse/toque chegam pelas callbacks do LÖVE no app/main.lua.
-- Inclinação e pressao WM_POINTER especificas ainda nao estao disponiveis.
local Ink={available=false,attached=false,errors={}}
function Ink.init()
    Ink.available=false
    Ink.attached=false
    Ink.errors={}
    return false
end
function Ink.mouseGuard() return false end
function Ink.poll() return {} end
function Ink.close()
    Ink.attached=false
    return true
end
return Ink
