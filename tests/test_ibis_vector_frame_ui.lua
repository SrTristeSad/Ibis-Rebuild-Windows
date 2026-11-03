package.path='app/?.lua;'..package.path
local M=require('ibis_vector_frame_ui')
local UI=require('compact_layout')
local Tools=require('ibis_visual_tools')
local T={}
function T.run()
    local count=0
    local function check(ok,msg)
        count=count+1;assert(ok,msg)
    end
    local vector=M.new('vector')
    local frame=M.new('frame')
    check(not M.canApply() and vector.tab=='select'
        and frame.tab=='create','Ferramentas visuais nao aplicaveis')
    check(#M.tabs.vector==3 and #M.tabs.frame==3)
    for _,id in ipairs({'vector','frame'}) do
        local entry=assert(Tools.get(id),'Entrada ausente')
        check(not entry.backend,'Ferramenta pendente acionaria backend')
        local invoked=false
        local ok=Tools.select(id,function()
            invoked=true;return true
        end)
        check(not ok and not invoked,'Backend indevido foi chamado')
    end
    check(M.toggleMulti(vector) and not M.toggleMulti(vector),
        'Alternancia de selecao nao reversivel')
    for _,tab in ipairs(M.tabs.vector) do
        check(M.chooseTab(vector,tab.id)==tab.id
            and vector.tab==tab.id,'Aba vetorial nao mudou')
    end
    check(not pcall(M.toggleMulti,vector),
        'Modo selecionar nao pode alterar outras abas')
    check(not pcall(M.chooseTab,vector,'fake'))
    check(not pcall(M.chooseCut,vector,'vertical'))
    for _,tab in ipairs(M.tabs.frame) do
        M.chooseTab(frame,tab.id)
        check(frame.tab==tab.id,'Aba de quadro nao mudou')
        for _,key in ipairs(M.fieldsFor(frame)) do
            local meta=assert(M.fields[key])
            local initial=frame[key]
            check(M.adjust(frame,key,-1)==math.max(meta.min,
                initial-meta.step),'Ajuste negativo incorreto')
            check(M.adjust(frame,key,1)==initial,
                'Ajuste positivo nao reversivel')
            for i=1,300 do M.adjust(frame,key,-1) end
            check(frame[key]==meta.min,
                'Ajuste abaixo do limite inferior')
            for i=1,300 do M.adjust(frame,key,1) end
            check(frame[key]==meta.max,
                'Ajuste acima do limite superior')
        end
    end
    M.chooseTab(frame,'divide')
    check(M.chooseCut(frame,'horizontal')=='horizontal'
        and M.chooseCut(frame,'vertical')=='vertical')
    check(not pcall(M.chooseCut,frame,'diagonal'))
    check(not pcall(M.adjust,frame,'opacity',1))
    check(not pcall(M.adjust,frame,'horizontal',0))
    check(not pcall(M.adjust,vector,'horizontal',1))
    check(not pcall(M.new,'raster'))
    check(not pcall(M.chooseTab,frame,'unknown'))
    local function separated(a,b)
        return a.x+a.w<=b.x or b.x+b.w<=a.x
            or a.y+a.h<=b.y or b.y+b.h<=a.y
    end
    for _,size in ipairs({{960,640},{1220,800},{1920,1080}}) do
        for _,kind in ipairs({'vector','frame'}) do
            local p=UI.popup(size[1],size[2],kind)
            check(p.w==420 and p.h==440 and p.x>=0
                and p.x+p.w<=size[1] and p.y>=125
                and p.y+p.h<size[2]-48,
                'Janela de ferramenta fora da viewport')
            local controls={}
            for i=1,3 do controls[#controls+1]=M.tabRect(p,i) end
            if kind=='vector' then
                controls[#controls+1]=M.vectorPreview(p)
                controls[#controls+1]=M.vectorAction(p,1)
                controls[#controls+1]=M.vectorAction(p,2)
            else
                local preview=M.framePreview(p)
                for i=1,3 do
                    local r=M.frameRow(p,i)
                    controls[#controls+1]=r
                    local minus=M.frameStep(p,i,-1)
                    local plus=M.frameStep(p,i,1)
                    check(separated(minus,plus) and minus.x>=r.x
                        and plus.x+plus.w<=r.x+r.w
                        and minus.y>=r.y and
                        minus.y+minus.h<=r.y+r.h,
                        'Controles de campo ultrapassam linha')
                end
                for i=1,2 do
                    local cut=M.cutRect(p,i)
                    check(cut.x>=controls[4].x and
                        cut.x+cut.w<=controls[4].x+controls[4].w,
                        'Orientacao fora do painel')
                end
                controls[#controls+1]=preview
                controls[#controls+1]=M.frameDisabledAction(p)
            end
            local footer=M.footer(p)
            for i,a in ipairs(controls) do
                check(a.x>=p.x+10 and a.x+a.w<=p.x+p.w-10
                    and a.y>=p.y+50 and a.y+a.h<footer.y,
                    'Controle nao cabe no painel')
                for j=1,i-1 do
                    check(separated(a,controls[j]),
                        'Controles do painel se sobrepoem')
                end
            end
            check(footer.y+footer.h<p.y+p.h)
        end
    end
    check(not pcall(M.tabRect,{x=0,y=0,w=420,h=440},4))
    check(not pcall(M.frameStep,{x=0,y=0,w=420,h=440},1,0))
    check(not pcall(M.frameRow,{x=0,y=0,w=300,h=440},1))
    return {suite='ibis-vector-frame-ui',passed=true,
        assertions=count,created_vector_layers=0,created_frames=0}
end
return T
