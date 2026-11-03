package.path='app/?.lua;'..package.path
local Top=require('ibis_top_toolbar')
local Icons=require('ui_icons')
local UI=require('compact_layout')
local Workspace=require('workspace_layout')
local T={}
function T.run()
    local count=0
    local function check(ok,msg)
        count=count+1
        assert(ok,msg)
    end
    local order={'view','selection','stabilizer','shape','ruler','materials'}
    check(#Top.items==6,'Devem existir seis controles superiores')
    for _,dim in ipairs({{960,640},{1220,800},{1920,1080}}) do
        local w,h=dim[1],dim[2]
        local slots=Top.toolbar(w,h)
        check(#slots==6,'Barra superior incompleta')
        local bounds=Workspace.bounds(w,h,true,true)
        for i,item in ipairs(slots) do
            check(item.id==order[i],'Ordem superior diferente da referencia')
            check(Top.byId(item.id)~=nil,'Acao sem catalogo')
            local glyph=Icons.commands(item.icon)
            check(type(glyph)=='table' and #glyph>=2,
                'Acao superior sem icone vetorial')
            check(item.x>=420 and item.x+item.w<=w-10,
                'Controle superior invade comandos de navegação')
            check(item.y>=4 and item.y+item.h<=55,
                'Ferramentas de topo devem flutuar junto da borda')
            check(Top.pick(w,h,item.x+item.w/2,
                item.y+item.h/2)==item.id,
                'Visual e hitbox da acao superior nao coincidem')
            if i>1 then
                local prev=slots[i-1]
                check(prev.x+prev.w<item.x,
                    'Botoes superiores colidem')
            end
        end
        check(Top.pick(w,h,w/2,h/2)==nil,
            'Canvas interceptado pela barra superior')
        check(Top.pick(w,h,20,91)==nil,
            'Barra de zoom interceptada por controles direitos')
        for _,kind in ipairs({'view','stabilizer','ruler','materials'}) do
            local p=UI.popup(w,h,kind)
            check(p.x>=w/2 and p.y>=bounds.top
                and p.x+p.w<=w
                and p.y+p.h<h-48,
                'Painel de topo encobre barra inferior ou sai da tela')
        end
        local view=UI.popup(w,h,'view')
        local stabilize=UI.popup(w,h,'stabilizer')
        local pending=UI.popup(w,h,'materials')
        check(view.h>=314 and stabilize.h>=254 and pending.h>=222,
            'Painel superior insuficiente')
    end
    -- A38: o cabeçalho desktop não intercepta o canvas compacto
    -- quando F10 estiver fechado. Todos os comandos continuam
    -- disponíveis ao abrir o painel, em três resoluções.
    local Hud=require('ibis_windows_hud')
    check(not Hud.visible('editor',true,false,false,nil),
        'Comandos Windows não devem aparecer por padrão')
    check(Hud.visible('editor',true,false,true,nil),
        'Comandos Windows F10 não aparecem ao solicitar')
    for _,screen in ipairs({'home','gallery'}) do
        check(not Hud.visible(screen,true,false,true,nil),
            'Comandos Windows surgem fora do editor')
    end
    check(not Hud.visible('editor',false,false,true,nil) and
        not Hud.visible('editor',true,true,true,nil) and
        not Hud.visible('editor',true,false,true,'tools'),
        'Comandos Windows surgem em modo inadequado')
    for _,dim in ipairs({{960,640},{1220,800},{1920,1080}}) do
        local w,h=dim[1],dim[2]
        local controls=Hud.rects(w,h)
        check(Hud.hit(w,h,105,20,false)==nil and
            Hud.hit(w,h,150,60,false)==nil,
            'Botões invisíveis estão capturando canvas')
        for _,id in ipairs({'save','desktop','properties',
            'zoomOut','zoomIn','fit'}) do
            local r=controls[id]
            check(r.x>=0 and r.y>=0 and
                r.x+r.w<=w and r.y+r.h<h-130,
                'Comando Windows não cabe na janela')
            check(Hud.hit(w,h,r.x+r.w/2,r.y+r.h/2,true)==id,
                'Comando Windows não coincide com a área visual')
        end
        check(controls.background.x>75 and
            controls.background.x+controls.background.w<
                Top.toolbar(w,h)[1].x,
            'Painel F10 invade faixa ou controles superiores')
        check(Hud.hit(w,h,w/2,h/2,true)==nil,
            'Painel F10 intercepta canvas fora da sua área')
    end
    check(not pcall(Hud.rects,320,480),
        'Viewport pequena aceita painel Windows inválido')
    check(Top.byId('made-up')==nil,
        'Nao permitir controles superiores inexistentes')
    check(not pcall(Top.toolbar,400,300),
        'Janela pequena deveria rejeitar layout')
    check(not pcall(UI.popup,1220,800,'unknown'),
        'Painel sem referencia nao deve existir')
    return {suite='ibis-top-toolbar',passed=true,assertions=count,
        upper_reference_order=true,popup_clip_safe=true,
        icons_original_lua=true,no_canvas_overlap=true}
end
return T
