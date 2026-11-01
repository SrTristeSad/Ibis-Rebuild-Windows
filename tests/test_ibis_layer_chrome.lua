package.path='app/?.lua;'..package.path
local Chrome=require('ibis_layer_chrome')
local UI=require('compact_layout')
local Layer=require('ibis_layer_ui')
local Panels=require('ibis_visual_panels')
local T={}
function T.run()
    local n=0
    local function check(x,msg)n=n+1;assert(x,msg)end
    for _,size in ipairs({{960,640},{1220,800},{1920,1080}}) do
        local p=UI.popup(size[1],size[2],'layers')
        local reg=Chrome.regions(p)
        check(reg.header.h==44 and reg.header.y==p.y)
        check(reg.footer.y==p.y+p.h-91)
        local selection=Layer.selectionRow(p)
        check(selection.y>=reg.header.y+reg.header.h
            and selection.y+selection.h<Panels.layerRow(p,1).y)
        local rows=UI.layerRows(p)
        for i=1,rows do
            local r=Panels.layerRow(p,i)
            check(r.y+r.h<=reg.footer.y,
                'Camada invade controles inferiores')
        end
        for i=1,4 do
            local r=Chrome.backgroundRow(p,i)
            if r then
                local last=Panels.layerRow(p,i)
                check(r.y>=last.y+last.h
                    and r.y+r.h<=reg.footer.y,
                    'Fundo extrapola lista')
            end
        end
    end
    for _,v in pairs(Chrome.colors) do
        check(#v==3)
        for _,c in ipairs(v) do check(c>=0 and c<=1)end
    end
    check(not pcall(Chrome.backgroundRow,{x=0,y=0,w=300,h=440},0))
    check(not pcall(Chrome.regions,{x=0,y=0,w=200,h=200}))
    return {suite='ibis-layer-chrome',passed=true,assertions=n,
        visual_only=true}
end
return T
