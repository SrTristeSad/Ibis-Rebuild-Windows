-- Sem LÖVE: valida math e estados do atalho específico Windows.
package.path='app/?.lua;'..package.path
local M=require('ibis_windows_brush_size')
local T={}
function T.run()
    local n=0
    local function check(v,message) n=n+1;assert(v,message) end
    check(M.MIN==1 and M.MAX==256,'Limites do motor alterados')
    check(M.keyDirection('leftbracket')==-1
        and M.keyDirection('rightbracket')==1
        and M.keyDirection('brush')==nil,
        'Atalhos de colchetes incorretos')
    local initial=M.begin(310,24)
    check(initial.originX==310 and initial.origin==24,
        'Origem do ajuste incorreta')
    check(M.move(initial,310)==24,'Clique sem movimento mudou tamanho')
    check(M.move(initial,326)==28,'Arrasto horizontal positivo')
    check(M.move(initial,294)==20,'Arrasto horizontal negativo')
    check(M.move(initial,310+4*3)==27,'Delta acumulado incorreto')
    check(M.move(initial,311)==24,'Movimento subpixel vira passo')
    check(M.move(initial,100000)==256,'Limite superior ultrapassado')
    check(M.move(initial,-100000)==1,'Limite inferior ultrapassado')
    check(M.move(initial,326)==28 and initial.origin==24,
        'Arrasto anterior mudou origem e acumulou erro')
    local left=M.begin(80,1)
    local right=M.begin(80,256)
    check(M.move(left,0)==1 and M.move(right,1000)==256,
        'Pincel nas bordas extrapolou limites')
    check(M.step(24,-1)==23 and M.step(24,1)==25,
        'Colchetes nao executam passos de 1 px')
    check(M.step(1,-1)==1 and M.step(256,1)==256,
        'Colchetes extrapolaram limites')
    for diameter=1,256 do
        local g=M.begin(77,diameter)
        check(M.move(g,77)==diameter,'Arrasto neutro instavel')
        check(M.move(g,77+4)==M.step(diameter,1),
            'Arrasto e tecla + divergiram')
        check(M.move(g,77-4)==M.step(diameter,-1),
            'Arrasto e tecla - divergiram')
    end
    for _,bad in ipairs({0/0,math.huge,-math.huge}) do
        check(not pcall(M.begin,10,bad),
            'Tamanho nao-finito foi aceito')
    end
    check(not pcall(M.step,20,0),'Passo arbitrario aceito')
    check(not pcall(M.move,initial,0/0),'Posicao NaN aceita')
    check(not pcall(M.move,{},17),'Estado invalido aceito')
    check(not pcall(M.begin,0/0,24),'Origem NaN aceita')
    return {suite='windows-brush-size-gestures',passed=true,
        assertions=n,windows_shortcut=true,
        no_interface_added=true,clamped=true}
end
return T
