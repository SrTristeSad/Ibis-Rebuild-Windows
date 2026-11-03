-- Reference-grounded visual controls: nine vector actions + quick rails.
local UI=require('compact_layout')
local Icons=require('ui_icons')
local Workspace=require('workspace_layout')
local T={}
function T.run()
    local checks=0
    local function check(ok,msg) checks=checks+1;assert(ok,msg) end
    local actions={'brush','tools','properties','color',
        'fullscreen','undo','redo','layers','back'}
    for _,name in ipairs(actions) do
        local glyph=Icons.commands(name)
        check(type(glyph)=='table' and #glyph>=2,
            'Compact action must have an original vector glyph: '..name)
        for _,cmd in ipairs(glyph) do
            check(cmd.op=='circle' or cmd.op=='line' or
                cmd.op=='rectangle' or cmd.op=='polygon',
                'Unsupported vector primitive')
        end
    end
    for _,dim in ipairs({{960,640},{1220,800},{1920,1080}}) do
        local w,h=dim[1],dim[2]
        local bar=UI.toolbar(w,h)
        check(#bar==9,'Toolbar action count changed')
        for i,item in ipairs(bar) do
            check(item.id==actions[i],'Toolbar order must match reference')
            check(item.w==72 and item.h==50,
                'Compact icon touch area must use visual contract')
            check(UI.pick(w,h,item.x+item.w/2,
                item.y+item.h/2)==item.id,
                'Hit area differs from rendered action')
        end
        local quick=UI.quick(w,h)
        check(quick.diameter.y+quick.diameter.h<quick.opacity.y,
            'Size and opacity rails must use distinct stacked rows')
        check(quick.diameter.x==quick.opacity.x and
            quick.diameter.w==quick.opacity.w,
            'The two compact rails must share a horizontal axis')
        -- A40: dois botoes (+/-) por trilho, clique isolado,
        -- sem choque horizontal com a barra ou vertical com dock.
        for _,kind in ipairs({'diameter','opacity'}) do
            local r=quick[kind]
            check(r.labelX>=0 and r.valueX<r.minus.x and
                r.x>r.minus.x+r.minus.w and
                r.plus.x>r.x+r.w and r.plus.x+r.plus.w<w,
                'Botoes e rotulos do ajuste se sobrepoem')
            for _,name in ipairs({'minus','plus'}) do
                local btn=r[name]
                local delta=name=='minus' and -1 or 1
                local got,step=UI.quickButton(w,h,
                    btn.x+btn.w/2,btn.y+btn.h/2)
                check(got==kind and step==delta,
                    'Botao visual nao coincide com hit-test')
                check(not UI.quickHit(w,h,btn.x+btn.w/2,
                    btn.y+btn.h/2),
                    'Botao +/- invadiu area de arrasto')
                check(btn.y+btn.h<bar[1].y,
                    'Botao de ajuste invade barra principal')
            end
            local lo=kind=='diameter' and 1 or .1
            local hi=kind=='diameter' and 256 or 1
            local middle=kind=='diameter' and 24 or .55
            check(UI.quickStep(kind,lo,-1)==lo and
                UI.quickStep(kind,hi,1)==hi,
                'Botao de ajuste extrapola os limites atuais')
            check(UI.quickStep(kind,middle,1)==
                middle+(kind=='diameter' and 1 or .01) and
                UI.quickStep(kind,middle,-1)==
                middle-(kind=='diameter' and 1 or .01),
                'Botoes nao obedecem incremento real do motor')
        end
        check(UI.quickButton(w,h,w/2,h/2)==nil,
            'Controles da barra interceptam o canvas')
        local bounds=Workspace.bounds(w,h,true,true)
        check(bounds.bottom==h-130 and
            bounds.bottom<quick.diameter.y-5,
            'Canvas must end before draggable settings')
        for _,kind in ipairs({'diameter','opacity'}) do
            local r=quick[kind]
            check(UI.quickHit(w,h,r.x+r.w/2,r.y+7)==kind,
                'Quick hitbox must match visible slider')
            check(not UI.quickHit(w,h,r.x+r.w/2,
                r.y-32),'Invisible part of rail captured input')
            local lo=kind=='diameter' and 1 or .1
            local hi=kind=='diameter' and 256 or 1
            check(UI.quickValue(kind,w,h,r.x-1000)==lo and
                UI.quickValue(kind,w,h,r.x+r.w+1000)==hi,
                'Drag endpoints must clamp to safe native range')
            check(UI.quickFraction(kind,lo)==0 and
                UI.quickFraction(kind,hi)==1,
                'Rendered fill must match clamped value')
            local prev=lo
            for i=0,r.w do
                local nextValue=UI.quickValue(kind,w,h,r.x+i)
                check(nextValue>=prev and nextValue>=lo and nextValue<=hi,
                    'Quick slider value must be monotonic and bounded')
                prev=nextValue
            end
        end
        local mid=UI.quickValue('opacity',w,h,
            quick.opacity.x+quick.opacity.w/2)
        check(mid==.55,'Opacity quick rail must adjust in 1% increments')
        check(not UI.quickHit(w,h,bar[3].x+20,bar[3].y+20),
            'Buttons cannot accidentally capture slider drag')
    end
    check(not pcall(UI.quickValue,'unknown',1220,800,200),
        'Unknown quick parameter cannot be set')
    check(not pcall(UI.quickStep,'diameter',24,0) and
        not pcall(UI.quickStep,'unknown',24,1),
        'Ajuste invalido nao pode modificar os parametros')
    return {suite='compact-ui-visual-controls',passed=true,
        assertions=checks,reference_order=true,
        vector_icons=true,safe_quick_hitboxes=true,one_percent_opacity=true,
        canvas_isolation=true}
end
return T
