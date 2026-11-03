local Catalog=require('ibis_visual_tools')
local Icons=require('ui_icons')
local UI=require('compact_layout')
local Tools=require('editor_tools')
local T={}
function T.run()
    assert(#Catalog.entries==15,'A interface deve listar as 15 ferramentas')
    local count,implemented=0,0
    local reference={'transform','wand','lasso','filter','brush','eraser',
        'smudge','blur','special','bucket','vector','text','frame',
        'picker','canvas'}
    local seen={}
    assert(Catalog.entries[1].icon=='transform' and
        Icons.commands('transform')~=Icons.commands('select'),
        'Transformar nao pode parecer seletor retangular')
    -- A46: as tres silhuetas PC precisam ser distinguiveis,
    -- sem trocar os IDs/callbacks das ferramentas.
    local wand=Icons.commands('magic')
    local lasso=Icons.commands('lasso')
    local fx=Icons.commands('filter')
    assert(Catalog.get('wand').icon=='magic' and
        Catalog.get('lasso').icon=='lasso' and
        Catalog.get('filter').icon=='filter',
        'Correspondencia entre categoria e icon foi alterada')
    assert(#wand>=7 and wand[1].op=='line' and
        wand[2].op=='line' and wand[3].op=='line',
        'Varinha precisa de cabo e estrela, nao um traco generico')
    assert(lasso[1].op=='line' and #lasso[1].points>=16
        and lasso[2].op=='line',
        'Laco precisa de contorno irregular e cordao, nao lupa')
    assert(fx[1].op=='circle' and fx[1].r>=6 and
        fx[2].op=='line' and fx[3].op=='line' and
        fx[4].op=='line' and fx[5].op=='line',
        'Filtro precisa de FX dentro de um circulo')
    -- A47: o pincel e a borracha no PC sao silhuetas de
    -- ferramentas diagonais; Balde deve ter lata e gota.
    -- Os IDs/callbacks sao os mesmos, sem novos modos visuais.
    assert(Catalog.get('brush').icon=='brush' and
        Catalog.get('brush').backend=='brush' and
        Catalog.get('eraser').icon=='erase' and
        Catalog.get('eraser').backend=='erase' and
        Catalog.get('bucket').icon=='fill' and
        Catalog.get('bucket').backend=='fill',
        'Catalogo/callback de pincel, borracha ou balde foi modificado')
    local brushGlyph=Icons.commands('brush')
    local eraserGlyph=Icons.commands('erase')
    local bucketGlyph=Icons.commands('fill')
    assert(brushGlyph[1].op=='polygon' and
        brushGlyph[1].mode=='fill' and
        brushGlyph[3].op=='polygon' and
        brushGlyph[3].mode=='fill',
        'Pincel precisa de cabo e cerdas reconheciveis')
    assert(eraserGlyph[1].op=='polygon' and
        eraserGlyph[1].mode=='fill' and
        #eraserGlyph[1].points>=10,
        'Borracha precisa de silhueta preenchida inclinada')
    assert(bucketGlyph[1].op=='polygon' and
        bucketGlyph[1].mode=='line' and
        bucketGlyph[4].op=='polygon' and
        bucketGlyph[4].mode=='fill',
        'Balde precisa de recipiente e gota separados')
    for i,entry in ipairs(Catalog.entries) do
        assert(entry.id==reference[i],'Ordem visual de ferramentas divergente')
        assert(not seen[entry.id] and Catalog.get(entry.id)==entry,
            'Ferramenta visual duplicada')
        seen[entry.id]=true
        assert(type(entry.label)=='string' and #entry.label>0)
        assert(Icons.commands(entry.icon)~=nil,
            'Icone vetorial ausente: '..entry.id)
        if entry.backend then
            implemented=implemented+1
            assert(Tools.fromId(entry.backend)~=nil,
                'Backend Lua ausente: '..entry.backend)
            local invoked
            local ok=Catalog.select(entry.id,function(backend)
                invoked=backend
                return true
            end)
            assert(ok and invoked==entry.backend)
        else
            local called=false
            local ok=Catalog.select(entry.id,function()
                called=true
                return true
            end)
            assert(not ok and not called,
                'Ferramenta pendente nao pode executar outro motor')
        end
        count=count+1
    end
    for _,size in ipairs({{960,640},{1220,800},{1920,1080}}) do
        local popup=UI.popup(size[1],size[2],'tools')
        assert(popup.w==242 and popup.h==383
            and popup.x==85 and popup.y>=125
            and popup.y+popup.h<=size[2]-125,
            'Paleta de duas colunas fora do canvas seguro')
        local keys={}
        for i=1,count do
            local r=Catalog.grid(popup,i)
            assert(r.x>=popup.x+8 and r.y>=popup.y+26
                and r.x+r.w<popup.x+popup.w
                and r.y+r.h<=popup.y+popup.h-25,
                'Ferramenta fora do seletor em '..size[1]..'x'..size[2])
            for _,prev in ipairs(keys) do
                assert(r.x+r.w<=prev.x or prev.x+prev.w<=r.x
                    or r.y+r.h<=prev.y or prev.y+prev.h<=r.y,
                    'Botoes de ferramentas sobrepostos')
            end
            keys[#keys+1]=r
            if i>=3 then
                assert(r.y>keys[i-2].y and r.x==keys[i-2].x,
                    'Paleta nao tem duas colunas de grade')
            end
        end
    end
    assert(not pcall(Catalog.grid,{x=0,y=0},16))
    assert(not pcall(Catalog.select,'__inexistente',function()end))
    return {suite='ibis-tool-catalogue',passed=true,
        categories=count,mapped_to_lua=implemented,pending=15-implemented}
end
return T
