package.path='app/?.lua;'..package.path
local M=require('ibis_windows_pen_view')
local T={}
function T.run()
    local n=0
    local function check(ok,message)n=n+1;assert(ok,message)end
    check(M.mode(true,true,true,false)=='zoom',
        'Alt+Space com caneta nao ativa zoom')
    check(M.mode(true,true,false,true)=='rotate',
        'Shift+Space com caneta nao ativa rotacao')
    for _,opts in ipairs({{false,true,true,false},
        {true,false,true,false},{true,true,true,true},
        {true,true,false,false}}) do
        check(M.mode(unpack(opts))==nil,
            'Gesto ambiguo, mouse ou sem Space foi capturado')
    end
    local z=M.begin('zoom',100,200,90,100)
    check(M.move(z,100,200)==1,'Zoom sem arrasto mudou')
    local plus=M.move(z,100,180)
    check(plus>1 and plus<2,'Zoom para cima nao aproximou')
    local minus=M.move(z,100,200)
    check(minus<1 and math.abs(plus*minus-1)<1e-12,
        'Zoom reverso nao restaurou escala')
    check(M.move(z,100,100000)<math.exp(1),
        'Saltos de zoom enormes precisam de clamp')
    local r=M.begin('rotate',100,0,0,0)
    check(math.abs(M.move(r,0,100)-math.pi/2)<1e-10,
        'Giro circular anti-horario incorreto')
    check(math.abs(M.move(r,-100,0)-math.pi/2)<1e-10,
        'Segundo quadrante calculado incorretamente')
    check(math.abs(M.move(r,0,-100)-math.pi/2)<1e-10,
        'Passagem do quadrante 3 para 4 incorreta')
    check(math.abs(M.move(r,100,0)-math.pi/2)<1e-10,
        'Wrap 2pi calculado incorretamente')
    check(M.move(r,100,0)==0,'Rotacao neutra mudou')
    check(M.begin('rotate',0,0,0,0)==nil,
        'Rotacao centrada deveria ser ignorada')
    check(not pcall(M.begin,'pan',1,2,3,4),
        'Modo nao documentado foi aceito')
    check(not pcall(M.begin,'zoom',0/0,2,3,4),
        'Input NaN foi aceito')
    check(not pcall(M.move,{},0,0),
        'Estado invalido foi aceito')
    return {suite='windows-pen-view',passed=true,assertions=n}
end
return T
