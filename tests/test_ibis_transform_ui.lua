package.path='app/?.lua;'..package.path
local M=require('ibis_transform_ui')
local C=require('compact_layout')
local Tools=require('ibis_visual_tools')
local T={}
function T.run()
    local checks=0
    local function check(v,msg) checks=checks+1;assert(v,msg) end
    local transform=Tools.get('transform')
    check(transform and transform.backend==nil and
        transform.id=='transform',
        'Transformar nao deve usar motor de selecao retangular')
    local invoked=false
    local done=Tools.select('transform',function()
        invoked=true;return true
    end)
    check(not done and not invoked,'Transformar acionou outro motor')
    local draft=M.new()
    check(draft.mode=='translate' and draft.target=='layer' and
        draft.zoom==100 and draft.angle==0 and not M.canApply(),
        'Estado inicial de transformacao incorreto')
    local modes={'translate','perspective','mesh'}
    for i,id in ipairs(modes) do
        check(M.modes[i].id==id and M.mode(id)==M.modes[i],
            'Modos de transformacao divergentes')
        M.chooseMode(draft,id)
        check(draft.mode==id,'Alternancia de modos falhou')
    end
    check(not pcall(M.chooseMode,draft,'unknown'))
    M.chooseMode(draft,'translate')
    M.chooseTarget(draft,'canvas')
    check(draft.target=='canvas','Alvo canvas nao selecionado')
    M.chooseTarget(draft,'layer')
    check(draft.target=='layer','Alvo layer nao restaurado')
    check(not pcall(M.chooseTarget,draft,'pixel'))
    for _,key in ipairs({'scaling','rotation','repeatDisplay','showFrame'}) do
        local old=draft[key]
        check(M.toggle(draft,key)~=old and
            M.toggle(draft,key)==old,'Toggle nao e reversivel')
    end
    check(not pcall(M.toggle,draft,'not-a-toggle'))
    local values={movementX=0,movementY=0,zoom=100,angle=0}
    for i,field in ipairs(M.fields) do
        check(M.field(field.id)==field,'Campo nao registrado')
        check(M.adjust(draft,field.id,1)==values[field.id]+field.step)
        check(M.adjust(draft,field.id,-1)==values[field.id])
        for j=1,3000 do M.adjust(draft,field.id,1) end
        check(draft[field.id]==field.maximum,'Valor excedeu maximo')
        for j=1,6000 do M.adjust(draft,field.id,-1) end
        check(draft[field.id]==field.minimum,'Valor abaixo de minimo')
        draft[field.id]=values[field.id]
    end
    check(not pcall(M.adjust,draft,'not-a-field',1))
    check(not pcall(M.adjust,draft,'angle',0))
    local function noOverlap(a,b)
        return a.x+a.w<=b.x or b.x+b.w<=a.x or
            a.y+a.h<=b.y or b.y+b.h<=a.y
    end
    for _,size in ipairs({{960,640},{1220,800},{1920,1080}}) do
        local p=C.popup(size[1],size[2],'transform')
        check(p.w==420 and p.h==440 and p.x>=0
            and p.x+p.w<=size[1] and p.y>=125
            and p.y+p.h<size[2]-48,'Popup fora da janela')
        local buttons={}
        for i=1,3 do
            buttons[#buttons+1]=M.modeRect(p,i)
            buttons[#buttons+1]=M.toggleRect(p,i)
        end
        for i=1,4 do
            local row=M.fieldRow(p,i)
            local minus,plus=M.minusRect(p,i),M.plusRect(p,i)
            check(minus.x>=row.x and plus.x+plus.w<=row.x+row.w
                and minus.y>=row.y and plus.y+plus.h<=row.y+row.h
                and noOverlap(minus,plus),
                'Controles +/- fora da linha ou sobrepostos')
            buttons[#buttons+1]=row
        end
        for i=1,2 do buttons[#buttons+1]=M.targetRect(p,i) end
        buttons[#buttons+1]=M.frameRect(p)
        local footer=M.footerRect(p)
        for i,a in ipairs(buttons) do
            check(a.x>=p.x+10 and a.x+a.w<=p.x+p.w-10 and
                a.y>=p.y+50 and a.y+a.h<footer.y-5,
                'Controle ultrapassa painel de transformacao')
            for j=1,i-1 do
                check(noOverlap(a,buttons[j]),
                    'Botoes de transformacao sobrepostos')
            end
        end
        local pending=M.pendingArea(p)
        check(pending.x>=p.x+10 and pending.x+pending.w<=p.x+p.w-10
            and pending.y>=M.modeRect(p,1).y+36
            and pending.y+pending.h<footer.y,
            'Estado pendente fora do painel')
    end
    check(not pcall(M.modeRect,{x=0,y=0,w=420,h=440},4))
    check(not pcall(M.fieldRow,{x=0,y=0,w=420,h=440},0))
    check(not pcall(M.modeRect,{x=0,y=0,w=400,h=440},1))
    return {suite='ibis-transform-ui',passed=true,
        assertions=checks,transform_raster_available=false}
end
return T
