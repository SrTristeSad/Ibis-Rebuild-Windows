-- Visual assets are generated from known primitives; no external images.
local Tools=require('editor_tools')
local VisualTools=require('ibis_visual_tools')
local Compact=require('compact_layout')
local Icons=require('ui_icons')
local M={}
function M.run()
    local checks=0
    local function check(v,message)checks=checks+1;assert(v,message)end
    local expected={line=true,rectangle=true,circle=true,polygon=true}
    local ids={}
    local function validate(id)
        local commands=Icons.commands(id)
        check(type(commands)=='table' and #commands>=2,
            'Every tool needs meaningful visual glyphs: '..id)
        for _,p in ipairs(commands) do
            check(expected[p.op],'Unsupported drawing operation')
            if p.op=='line' or p.op=='polygon' then
                check(type(p.points)=='table' and #p.points>=4 and
                    #p.points%2==0,'Glyph needs coordinate pairs')
                for _,v in ipairs(p.points) do
                    check(type(v)=='number' and v>=-8 and v<=8,
                        'Glyph exceeds normalized bounds')
                end
            elseif p.op=='rectangle' then
                check((p.mode=='fill' or p.mode=='line') and
                    p.w>0 and p.h>0 and p.x>=-8 and p.y>=-8 and
                    p.x+p.w<=8 and p.y+p.h<=8,
                    'Rectangle glyph must fit normalized box')
            elseif p.op=='circle' then
                check((p.mode=='fill' or p.mode=='line') and
                    p.r>0 and p.x-p.r>=-8 and p.y-p.r>=-8 and
                    p.x+p.r<=8 and p.y+p.r<=8,'Circle glyph out of bounds')
            end
        end
    end
    for _,tool in ipairs(Tools.items) do
        check(not ids[tool.id],'Repeated icon ID')
        ids[tool.id]=true
        validate(tool.id)
    end
    check(#VisualTools.entries==15,'All fifteen PC tools must remain')
    for _,entry in ipairs(VisualTools.entries) do
        validate(entry.icon)
    end
    for _,id in ipairs(Compact.IDS) do
        validate(id)
    end
    -- Brush da barra inferior reutiliza exatamente o mesmo desenho
    -- vetorial do seletor (e nunca um ícone paralelo genérico).
    local brush=VisualTools.get('brush')
    local eraser=VisualTools.get('eraser')
    local bucket=VisualTools.get('bucket')
    check(brush.icon=='brush' and eraser.icon=='erase'
        and bucket.icon=='fill',
        'Botões de ferramenta mudaram seus ícones oficiais de referência')
    check(Compact.IDS[1]=='brush' and
        Icons.commands(Compact.IDS[1])==Icons.commands(brush.icon),
        'Barra inferior não reutiliza o ícone do pincel')
    check(Icons.commands(eraser.icon)~=Icons.commands(brush.icon)
        and Icons.commands(bucket.icon)~=Icons.commands(brush.icon),
        'Borracha ou balde aponta para ícone do pincel')
    -- A48: Camadas deve preservar o glifo documentado de tres folhas.
    -- O primeiro e segundo contornos ficam atras da folha preenchida.
    local layers=Icons.commands('layers')
    check(#layers==3,'Camadas deve manter exatamente tres folhas')
    check(layers[1].op=='line' and layers[2].op=='line',
        'Camadas perdeu os dois contornos traseiros')
    check(layers[3].op=='rectangle' and layers[3].mode=='fill',
        'Camadas perdeu a folha frontal preenchida')
    check(layers[1].points[1]>layers[2].points[1]
        and layers[2].points[1]>layers[3].x,
        'Camadas perdeu a ordem de deslocamento das folhas')
    check(Icons.commands('unknown')==nil,'Unknown tools should not have glyphs')
    check(#Tools.items==8,'Existing eight tool set must stay intact')
    return {suite='editor-vector-tool-icons',passed=true,assertions=checks,
        complete_glyph_registry=true,normalized_bounds=true,assets_required=false}
end
return M
