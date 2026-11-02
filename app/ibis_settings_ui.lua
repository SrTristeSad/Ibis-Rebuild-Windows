-- Janelas de navegacao e configuracoes com geometria independente.
-- Contrato de navegacao: ibisPaint Toolbar #03 e Settings #184.
-- Sem dependencias de raster, sem simular ferramentas nao implementadas.
local M={}
local function valid(p,w,h)
    assert(type(p)=='table' and p.w>=w and p.h>=h,
        'Dimensoes do painel de configuracoes invalidas')
end
function M.menu(w,h)
    assert(w>=960 and h>=640,'Janela pequena para menu Voltar')
    return {x=math.floor((w-360)/2),y=math.floor((h-248)/2),
        w=360,h=248}
end
function M.menuItem(p,i)
    valid(p,360,248)
    assert(i==1 or i==2 or i==3,'Acao Voltar desconhecida')
    return {x=p.x+24,y=p.y+61+(i-1)*54,w=p.w-48,h=43}
end
function M.panel(w,h)
    assert(w>=960 and h>=640,'Janela pequena para configuracoes')
    return {x=math.floor((w-540)/2),y=math.floor((h-438)/2),
        w=540,h=438}
end
local function control(p,i,y)
    valid(p,540,438)
    assert(type(i)=='number' and i%1==0 and
        i>=1 and i<=3,'Opcao de configuracoes invalida')
    return {x=p.x+30+(i-1)*163,y=p.y+y,w=151,h=36}
end
function M.positionRect(p,i) return control(p,i,119) end
function M.columnRect(p,i) return control(p,i,219) end
function M.labelRect(p,i)
    valid(p,540,438)
    assert(i==1 or i==2,'Alternativa de rotulo invalida')
    return {x=p.x+30+(i-1)*248,y=p.y+311,w=237,h=36}
end
function M.closeRect(p)
    valid(p,540,438)
    return {x=p.x+p.w-178,y=p.y+p.h-47,w=148,h=34}
end
function M.normalizeColumns(value)
    return (value==1 or value==2 or value==3) and value or 2
end
function M.labelsVisible(value) return value~=false end
function M.positionAvailable(id) return id=='popup' end
return M
