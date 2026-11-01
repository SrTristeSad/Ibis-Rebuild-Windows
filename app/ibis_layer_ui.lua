-- Apresentação de camadas e modos de mesclagem para o editor Lua.
-- Interfaces referenciadas ao tutorial oficial de Layer Window do
-- ibisPaint. Não implementa motor, blending, clipping ou alpha lock.
local M={}
M.modes={
    {id='normal',label='Normal',available=true},
    {id='multiply',label='Multiplicar',available=false},
    {id='screen',label='Tela',available=false},
    {id='overlay',label='Sobrepor',available=false},
    {id='add',label='Adicionar',available=false},
    {id='subtract',label='Subtrair',available=false},
    {id='darken',label='Escurecer',available=false},
    {id='lighten',label='Clarear',available=false}
}
function M.selectionRow(p)
    assert(type(p)=='table' and p.w>=298 and p.h>=350,
        'Painel de camadas inválido')
    return {x=p.x+13,y=p.y+84,w=p.w-26,h=35}
end
function M.blendRow(p,i)
    assert(type(p)=='table' and p.w>=298 and p.h>=350
        and type(i)=='number' and i%1==0
        and i>=1 and i<=#M.modes,'Linha de mistura inválida')
    return {x=p.x+14,y=p.y+64+(i-1)*37,w=p.w-28,h=34}
end
function M.mode(id)
    for _,value in ipairs(M.modes) do
        if value.id==id then return value end
    end
    return nil
end
function M.canApply(id)
    local value=M.mode(id)
    return value~=nil and value.available
end
return M
