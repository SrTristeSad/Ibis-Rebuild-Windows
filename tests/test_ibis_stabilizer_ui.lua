local UI=require('compact_layout')
local Stabilizer=require('ibis_stabilizer_ui')
local T={}
function T.run()
    local assertions=0
    local function check(value,message)
        assertions=assertions+1
        assert(value,message)
    end
    local draft=Stabilizer.new()
    check(draft.constant==0 and draft.fast==0 and
        draft.tab=='stabilization','14.1 deve iniciar dois ajustes OFF')
    check(Stabilizer.canApply('legacy') and
        not Stabilizer.canApply('constant') and
        not Stabilizer.canApply('fast') and
        not Stabilizer.canApply('fade'),
        'Motores pendentes foram declarados funcionais')
    check(Stabilizer.step(draft,'constant',1)==10)
    check(draft.fast==0,'Controles independentes')
    for i=1,10 do Stabilizer.step(draft,'constant',1) end
    check(draft.constant==100,'Controle nao limita valor superior')
    for i=1,11 do Stabilizer.step(draft,'constant',-1) end
    check(draft.constant==0,'Controle nao limita valor inferior')
    Stabilizer.tab(draft,'fade')
    check(draft.tab=='fade' and draft.fast==0)
    check(Stabilizer.toggle(draft,'fadeEnabled'))
    check(Stabilizer.step(draft,'start',1)==10)
    check(Stabilizer.step(draft,'end',1)==10)
    Stabilizer.shape(draft,'linear')
    check(draft.shape=='linear')
    check(not pcall(Stabilizer.step,draft,'nope',1))
    check(not pcall(Stabilizer.tab,draft,'unknown'))
    check(not pcall(Stabilizer.toggle,draft,'none'))
    for _,dim in ipairs({{960,640},{1220,800},{1920,1080}}) do
        local w,h=dim[1],dim[2]
        local p=UI.popup(w,h,'stabilizer')
        check(p.w>=348 and p.h>=430 and p.y+p.h<h-48,
            'Painel estabilizador sai da viewport')
        local tabs={}
        for i=1,2 do
            local r=Stabilizer.tabRect(p,i)
            check(r.x>=p.x and r.x+r.w<=p.x+p.w and
                r.y>=p.y+44 and r.y+r.h<p.y+p.h,
                'Aba fora da janela')
            tabs[i]=r
        end
        check(tabs[1].x+tabs[1].w<tabs[2].x,
            'Abas sobrepostas')
        local scope=Stabilizer.scopeRect(p)
        local legacy=Stabilizer.legacyRow(p)
        check(scope.y>tabs[1].y+tabs[1].h,
            'Escopo colide com abas')
        check(legacy.y>Stabilizer.methodRect(p,1).y+
            Stabilizer.methodRect(p,1).h,
            'Legado colide com metodo')
        local previous=legacy.y+legacy.h
        for i=1,2 do
            local row=Stabilizer.draftRow(p,i)
            check(row.y>previous,'Correcoes modernas sobrepostas')
            for _,direction in ipairs({-1,1}) do
                local rect=Stabilizer.draftButton(p,i,direction)
                check(rect.x>=row.x and rect.x+rect.w<=row.x+row.w
                    and rect.y>=row.y and rect.y+rect.h<=row.y+row.h,
                    'Botao modernizado fora da linha')
            end
            previous=row.y+row.h
        end
        local endRow=Stabilizer.fadeRow(p,2)
        local shape=Stabilizer.shapeRect(p,1)
        local footer=Stabilizer.footerRect(p)
        check(shape.y>endRow.y+endRow.h and
            shape.y+shape.h<footer.y and
            footer.y+footer.h<=p.y+p.h,
            'Fade colide com rodape')
        check(not UI.contains(p,0,0),
            'Hitbox estabilizador intercepta o canvas distante')
    end
    return {suite='ibis-stabilizer-14.1-visual',passed=true,
        assertions=assertions,modern_engine_pending=true,
        legacy_engine_retained=true}
end
return T
