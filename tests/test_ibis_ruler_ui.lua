package.path='app/?.lua;'..package.path
local R=require('ibis_ruler_ui')
local C=require('compact_layout')
local T={}
function T.run()
    local checks=0
    local function check(value,msg)
        checks=checks+1
        assert(value,msg)
    end
    local expected={'straight','circle','ellipse','radial',
        'mirror','kaleidoscope','array','perspective-array'}
    check(#R.types==#expected,'Catalogo de reguas incompleto')
    local draft=R.new()
    check(draft.previewId==nil,'Regua nao pode iniciar ativa')
    for i,id in ipairs(expected) do
        local item=R.types[i]
        check(item.id==id and R.get(id)==item,
            'Ordem das reguas difere dos tutoriais')
        check(type(item.name)=='string' and #item.name>0,
            'Rotulo de regua ausente')
        local symbol=R.symbol(id)
        check(type(symbol)=='table' and #symbol>=1,
            'Icone vetorial da regua ausente')
        local selected=R.select(draft,id)
        check(selected==item and draft.previewId==id,
            'Selecao de pre-visualizacao divergente')
        check(not R.canApply(id),'Regua sem motor foi marcada funcional')
    end
    R.select(draft,nil)
    check(draft.previewId==nil,'Limpar nao removeu escolha visual')
    check(R.get('unknown')==nil and R.symbol('unknown')==nil)
    check(not R.canApply('unknown'))
    check(not pcall(R.select,draft,'unknown'))
    check(not pcall(R.select,nil,'straight'))
    for _,screen in ipairs({{960,640},{1220,800},{1920,1080}}) do
        local w,h=screen[1],screen[2]
        local p=C.popup(w,h,'ruler')
        check(p.w==390 and p.h==402 and p.x>=w/2
            and p.x+p.w<=w and p.y>=120
            and p.y+p.h<h-48,'Janela fora da tela')
        local cells={}
        for i=1,#R.types do
            local a=R.cell(p,i)
            check(a.x>=p.x+10 and a.x+a.w<=p.x+p.w-10
                and a.y>=p.y+54 and a.y+a.h<=p.y+p.h-80,
                'Regua cruza borda ou rodape')
            for _,b in ipairs(cells) do
                check(a.x+a.w<=b.x or b.x+b.w<=a.x
                    or a.y+a.h<=b.y or b.y+b.h<=a.y,
                    'Hitboxes de reguas colidem')
            end
            cells[#cells+1]=a
        end
        local clear=R.clear(p)
        local caption=R.caption(p)
        check(clear.x>=p.x+10 and clear.y>cells[7].y+cells[7].h
            and clear.y+clear.h<p.y+p.h-30,
            'Limpar cruza lista ou aviso')
        check(caption.x>=clear.x+clear.w and
            caption.x+caption.w<=p.x+p.w-10 and
            caption.y>=clear.y and caption.y+caption.h<=clear.y+clear.h,
            'Legenda invade botao')
        check(not pcall(R.cell,{x=0,y=0,w=318,h=222},1))
    end
    check(not pcall(R.cell,{x=0,y=0,w=390,h=402},9))
    return {suite='ibis-ruler-ui',passed=true,assertions=checks,
        selectable_visual_types=8,operational_guides=0}
end
return T
