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
        local keys={}
        for i=1,count do
            local r=Catalog.grid(popup,i)
            assert(r.x>=popup.x and r.y>=popup.y+48
                and r.x+r.w<popup.x+popup.w
                and r.y+r.h<popup.y+popup.h-42,
                'Ferramenta fora do seletor em '..size[1]..'x'..size[2])
            for _,prev in ipairs(keys) do
                assert(r.x+r.w<=prev.x or prev.x+prev.w<=r.x
                    or r.y+r.h<=prev.y or prev.y+prev.h<=r.y,
                    'Botoes de ferramentas sobrepostos')
            end
            keys[#keys+1]=r
        end
    end
    assert(not pcall(Catalog.grid,{x=0,y=0},16))
    assert(not pcall(Catalog.select,'__inexistente',function()end))
    return {suite='ibis-tool-catalogue',passed=true,
        categories=count,mapped_to_lua=implemented,pending=15-implemented}
end
return T
