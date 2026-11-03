package.path='app/?.lua;'..package.path
local E=require('ibis_effect_tools_ui')
local UI=require('compact_layout')
local Catalog=require('ibis_visual_tools')
local T={}
function T.run()
    local count=0
    local function check(x,msg) count=count+1;assert(x,msg) end
    check(#E.specials==6 and #E.liquifyModes==5,
        'Catalogo da caneta especial incompleto')
    check(not E.canApply(),'Efeito nao deve aplicar')
    for _,kind in ipairs({'smudge','blur','special'}) do
        local d=E.new(kind)
        check(d.kind==kind and d.diameter==24 and d.opacity==100
            and d.strength==50 and d.specialId=='liquify',
            'Estado visual inicial incorreto')
        check(Catalog.get(kind).backend==nil,
            'Nao deve associar motor de pincel a efeito pendente')
        local called=false
        local ok=Catalog.select(kind,function()
            called=true;return true
        end)
        check(not ok and not called,'Ferramenta acionou raster')
        if kind~='special' then
            check(E.adjust(d,'diameter',1)==25 and
                E.adjust(d,'diameter',-1)==24)
            check(E.adjust(d,'opacity',-1)==95 and
                E.adjust(d,'opacity',1)==100)
            for i=1,300 do E.adjust(d,'diameter',-1) end
            check(d.diameter==1,'Diametro abaixo do minimo')
            for i=1,300 do E.adjust(d,'diameter',1) end
            check(d.diameter==256,'Diametro acima do maximo')
            for i=1,30 do E.adjust(d,'opacity',-1) end
            check(d.opacity==0,'Opacidade abaixo do minimo')
            check(not pcall(E.adjust,d,'strength',1),
                'Forca Liquify disponivel no pincel comum')
        else
            for _,item in ipairs(E.specials) do
                check(E.special(item.id)==item,'Subtipo desconhecido')
                E.selectSpecial(d,item.id)
                check(d.specialId==item.id,'Selecao especial nao mudou')
            end
            check(not pcall(E.selectSpecial,d,'unknown'))
            check(not pcall(E.selectLiquify,d,'drag'),
                'Liquify alterado em subtipo incompativel')
            E.selectSpecial(d,'liquify')
            for _,item in ipairs(E.liquifyModes) do
                check(E.liquifyMode(item.id)==item)
                E.selectLiquify(d,item.id)
                check(d.liquifyId==item.id)
            end
            check(not pcall(E.selectLiquify,d,'unknown'))
            check(E.adjust(d,'strength',1)==55)
            for i=1,30 do E.adjust(d,'strength',1) end
            check(d.strength==100,'Forca acima do limite')
            for i=1,30 do E.adjust(d,'strength',-1) end
            check(d.strength==0,'Forca abaixo do limite')
            check(not pcall(E.adjust,d,'diameter',1),
                'Diametro do pincel disponivel no especial')
        end
        check(not pcall(E.adjust,d,'whatever',1))
        check(not pcall(E.adjust,d,'opacity',0))
        check(not E.canApply())
    end
    check(not pcall(E.new,'filter'))
    local function apart(a,b)
        return a.x+a.w<=b.x or b.x+b.w<=a.x
            or a.y+a.h<=b.y or b.y+b.h<=a.y
    end
    for _,size in ipairs({{960,640},{1220,800},{1920,1080}}) do
        local w,h=size[1],size[2]
        for _,kind in ipairs({'smudge','blur','special'}) do
            local p=UI.popup(w,h,kind)
            check(p.w==420 and p.h==440 and p.x>=0
                and p.x+p.w<=w and p.y>=125
                and p.y+p.h<h-48,'Janela fora da tela')
            local footer=E.footer(p)
            if kind~='special' then
                local one,two=E.paintRow(p,1),E.paintRow(p,2)
                local preview=E.paintPreview(p)
                check(apart(one,two) and apart(two,preview)
                    and preview.y+preview.h<footer.y,
                    'Controles de pincel sobrepostos')
                for i=1,2 do
                    local r=E.paintRow(p,i)
                    local minus,plus=E.paintButton(p,i,-1),
                        E.paintButton(p,i,1)
                    check(apart(minus,plus) and
                        minus.x>=r.x and plus.x+plus.w<=r.x+r.w
                        and plus.y>=r.y and plus.y+plus.h<=r.y+r.h,
                        'Hitbox de ajuste fora da linha')
                end
            else
                local cells={}
                for i=1,6 do
                    local r=E.specialRect(p,i)
                    check(r.x>=p.x+12 and r.x+r.w<=p.x+p.w-12
                        and r.y>=p.y+55 and r.y+r.h<=p.y+244,
                        'Subtipo especial fora do painel')
                    for _,prev in ipairs(cells) do
                        check(apart(r,prev),'Cards especiais sobrepostos')
                    end
                    cells[#cells+1]=r
                end
                local modes={}
                for i=1,5 do
                    local r=E.liquifyModeRect(p,i)
                    check(r.x>=p.x+12 and r.x+r.w<=p.x+p.w-12
                        and r.y>=p.y+255 and r.y+r.h<p.y+345,
                        'Opcao Liquify fora do painel')
                    for _,prev in ipairs(modes) do
                        check(apart(r,prev),'Modos Liquify sobrepostos')
                    end
                    modes[#modes+1]=r
                end
                local strength=E.strengthRow(p)
                check(strength.y>modes[5].y+modes[5].h
                    and strength.y+strength.h<footer.y,
                    'Forca fora da area segura')
                local minus=E.strengthButton(p,-1)
                local plus=E.strengthButton(p,1)
                check(apart(minus,plus)
                    and minus.x>=strength.x
                    and plus.x+plus.w<=strength.x+strength.w,
                    'Botoes de forca sobrepostos')
                local pending=E.pendingRect(p)
                check(pending.y>cells[6].y+cells[6].h
                    and pending.y+pending.h<footer.y,
                    'Estado pendente fora da janela')
            end
            check(footer.x>=p.x+12 and
                footer.x+footer.w<=p.x+p.w-12
                and footer.y+footer.h<p.y+p.h,
                'Aviso final fora do painel')
        end
    end
    check(not pcall(E.specialRect,{x=0,y=0,w=420,h=440},7))
    check(not pcall(E.liquifyModeRect,{x=0,y=0,w=420,h=440},0))
    check(not pcall(E.paintRow,{x=0,y=0,w=380,h=440},1))
    return {suite='ibis-effect-tools-ui',passed=true,assertions=count,
        executable_effects=0}
end
return T
