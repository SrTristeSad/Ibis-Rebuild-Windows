package.path='app/?.lua;'..package.path
local Selection=require('ibis_selection_tool_ui')
local Compact=require('compact_layout')
local Tools=require('ibis_visual_tools')
local T={}
function T.run()
    local checks=0
    local function check(condition,message)
        checks=checks+1;assert(condition,message)
    end
    check(#Selection.modes==3 and #Selection.sources==2
        and #Selection.toggles==3,'Catalogo de selecao incompleto')
    check(Selection.canApply('wand') and
        not Selection.canApply('lasso') and not Selection.canApply(),
        'Varinha deve ter motor de mascara; Laco segue pendente')
    for _,kind in ipairs({'wand','lasso'}) do
        local d=Selection.new(kind)
        check(d.kind==kind and d.mode=='set',
            'Estado inicial de ferramenta incorreto')
        check(Tools.get(kind).backend==nil,
            'Ferramenta pendente ligada a motor raster')
        local called=false
        local ok=Tools.select(kind,function()
            called=true;return true
        end)
        check(not ok and not called,'Motor indevido foi executado')
        for _,mode in ipairs(Selection.modes) do
            Selection.selectMode(d,mode.id)
            check(d.mode==mode.id,'Mudanca de modo nao salva')
        end
        check(not pcall(Selection.selectMode,d,'unknown'),
            'Modo nao documentado foi aceito')
        check(not pcall(Selection.new,'shape'))
        if kind=='wand' then
            for _,source in ipairs(Selection.sources) do
                Selection.selectSource(d,source.id)
                check(d.source==source.id,'Origem de referencia nao mudou')
            end
            check(not pcall(Selection.selectSource,d,'something'))
            for _,opt in ipairs(Selection.toggles) do
                check(Selection.toggle(d,opt.id)==true and
                    Selection.toggle(d,opt.id)==false,
                    'Reconhecimento de varinha nao alterna')
            end
            check(not pcall(Selection.toggle,d,'nonsense'))
            for i=1,30 do Selection.adjustTolerance(d,1) end
            check(d.tolerance==100,'Tolerancia acima de 100')
            for i=1,30 do Selection.adjustTolerance(d,-1) end
            check(d.tolerance==0,'Tolerancia abaixo de 0')
            check(not pcall(Selection.adjustTolerance,d,0))
        else
            check(not pcall(Selection.selectSource,d,'current'),
                'Laco aceitou controle exclusivo de varinha')
            check(not pcall(Selection.toggle,d,'gap'),
                'Laco aceitou controle de preenchimento')
            check(not pcall(Selection.adjustTolerance,d,1),
                'Laco aceitou tolerancia de varinha')
        end
    end
    local function separated(a,b)
        return a.x+a.w<=b.x or b.x+b.w<=a.x
            or a.y+a.h<=b.y or b.y+b.h<=a.y
    end
    for _,size in ipairs({{960,640},{1220,800},{1920,1080}}) do
        for _,kind in ipairs({'wand','lasso'}) do
            local p=Compact.popup(size[1],size[2],kind)
            check(p.w==420 and p.h==440 and p.x>=0
                and p.x+p.w<=size[1] and p.y>=120
                and p.y+p.h<size[2]-48,
                'Painel ultrapassou viewport')
            local sections={}
            for i=1,3 do
                sections[#sections+1]=Selection.modeRect(p,i)
            end
            if kind=='wand' then
                for i=1,2 do
                    sections[#sections+1]=Selection.sourceRect(p,i)
                end
                sections[#sections+1]=Selection.toleranceRow(p)
                local minus=Selection.toleranceButton(p,-1)
                local plus=Selection.toleranceButton(p,1)
                local row=sections[#sections]
                check(minus.x>=row.x and plus.x+plus.w<=row.x+row.w
                    and minus.y>=row.y and plus.y+plus.h<=row.y+row.h
                    and separated(minus,plus),
                    'Tolerancia ultrapassa a linha')
                for i=1,3 do
                    sections[#sections+1]=Selection.toggleRect(p,i)
                end
            else
                sections[#sections+1]=Selection.lassoIllustration(p)
            end
            for i=1,2 do
                sections[#sections+1]=Selection.actionRect(p,i)
            end
            local footer=Selection.footerRect(p)
            for i,a in ipairs(sections) do
                check(a.x>=p.x+10 and a.x+a.w<=p.x+p.w-10
                    and a.y>=p.y+55 and a.y+a.h<footer.y-5,
                    'Controle fora da janela')
                for j=1,i-1 do
                    check(separated(a,sections[j]),
                        'Controles da mesma tela se sobrepoem')
                end
            end
            check(footer.y+footer.h<p.y+p.h and
                footer.y>=sections[#sections].y+sections[#sections].h,
                'Rodape colide com acoes')
        end
    end
    check(not pcall(Selection.modeRect,
        {x=0,y=0,w=420,h=440},4))
    check(not pcall(Selection.sourceRect,
        {x=0,y=0,w=420,h=440},3))
    check(not pcall(Selection.actionRect,
        {x=0,y=0,w=420,h=440},0))
    check(not pcall(Selection.modeRect,
        {x=0,y=0,w=318,h=440},1))
    return {suite='ibis-selection-tool-ui',passed=true,
        assertions=checks,active_selection_engines=1}
end
return T
