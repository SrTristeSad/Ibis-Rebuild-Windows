package.path='app/?.lua;'..package.path
local L=require('ibis_layer_ui')
local UI=require('compact_layout')
local P=require('ibis_visual_panels')
local T={}
function T.run()
    local checks=0
    local function check(v,msg)
        checks=checks+1
        assert(v,msg)
    end
    check(#L.modes>=8,'Faltam modos de mesclagem visíveis')
    check(L.canApply('normal'),'Compositor Lua deve manter Normal')
    for _,mode in ipairs(L.modes) do
        check(L.mode(mode.id)==mode,'Catálogo de mesclagem inconsistente')
        check(L.canApply(mode.id)==mode.available,
            'Modos sem motor não podem ser selecionáveis')
        if mode.id~='normal' then
            check(not mode.available,'Motor não implementado marcado funcional')
        end
    end
    check(L.mode('unknown')==nil and not L.canApply('unknown'),
        'Modo inválido tratado como editável')
    for _,size in ipairs({{960,640},{1220,800},{1920,1080}}) do
        local w,h=size[1],size[2]
        local p=UI.popup(w,h,'layers')
        local blend=UI.popup(w,h,'blends')
        local selection=L.selectionRow(p)
        check(selection.x>=p.x and selection.x+selection.w<=p.x+p.w,
            'Camada de seleção extrapola painel')
        check(selection.y>=p.y+80 and
            selection.y+selection.h<=p.y+123,
            'Camada de seleção colide com barra de ações')
        local rows=UI.layerRows(p)
        check(rows>=2 and rows<=4,'Capacidade do painel errada')
        local previous=selection.y+selection.h
        for i=1,rows do
            local r=P.layerRow(p,i)
            check(r.y>previous,'Camadas raster colidem com seleção')
            check(r.y+r.h<p.y+p.h-86,
                'Camadas raster colidem com controles inferiores')
            previous=r.y+r.h
        end
        local prev=blend.y
        for i=1,#L.modes do
            local r=L.blendRow(blend,i)
            check(r.x>=blend.x and r.x+r.w<=blend.x+blend.w,
                'Modo de mesclagem fora do painel')
            check(r.y>=prev and r.y+r.h<blend.y+blend.h-25,
                ('Lista de mesclagem colide com o rodape: %dx%d linha %d (y=%d, end=%d, limite=%d, popupH=%d)'):format(
                    w,h,i,r.y,r.y+r.h,blend.y+blend.h-25,blend.h))
            prev=r.y+r.h
        end
        check(blend.x>=w/2 and blend.x+blend.w<=w,
            'Menu de mesclagem deve estar na borda direita')
    end
    check(not pcall(L.blendRow,{x=0,y=0,w=300,h=400},9))
    check(not pcall(L.selectionRow,{x=0,y=0,w=250,h=100}))
    return {suite='ibis-layer-ui',passed=true,assertions=checks,
        selected_layer_visual=true,pending_blend_modes_disabled=true}
end
return T
