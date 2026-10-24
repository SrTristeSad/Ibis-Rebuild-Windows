-- Visual assets are generated from known primitives; no external images.
local Tools=require('editor_tools')
local Icons=require('ui_icons')
local M={}
function M.run()
    local checks=0
    local function check(v,message)checks=checks+1;assert(v,message)end
    local expected={line=true,rectangle=true,circle=true,polygon=true}
    local ids={}
    for _,tool in ipairs(Tools.items) do
        check(not ids[tool.id],'Repeated icon ID')
        ids[tool.id]=true
        local commands=Icons.commands(tool.id)
        check(type(commands)=='table' and #commands>=2,
            'Every tool needs meaningful visual glyphs')
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
    check(Icons.commands('unknown')==nil,'Unknown tools should not have glyphs')
    check(#Tools.items==8,'Existing eight tool set must stay intact')
    return {suite='editor-vector-tool-icons',passed=true,assertions=checks,
        complete_glyph_registry=true,normalized_bounds=true,assets_required=false}
end
return M
