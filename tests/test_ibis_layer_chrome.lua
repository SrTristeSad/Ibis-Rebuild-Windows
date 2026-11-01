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
        local top=Chrome.toolbar(p,'top')
        local bottom=Chrome.toolbar(p,'footer')
        check(#top==3 and #bottom==4)
        local seen={}
        for _,slot in ipairs(top) do
            check(slot.y>=p.y+44 and slot.y+slot.h<=p.y+84,
                'Controle superior colide com cabecalho ou selecao')
            check(slot.x>=p.x+10 and
                slot.x+slot.w<=p.x+p.w-10,
                'Controle superior extrapola largura')
            for _,prev in ipairs(seen) do
                check(prev.x+prev.w<=slot.x,
                    'Controles superiores sobrepostos')
            end
            seen[#seen+1]=slot
        end
        seen={}
        for _,slot in ipairs(bottom) do
            check(slot.y>=reg.footer.y and
                slot.y+slot.h<reg.footer.y+38,
                'Controle inferior fora do rodape')
            check(slot.x>=p.x+10 and
                slot.x+slot.w<=p.x+p.w-10)
            for _,prev in ipairs(seen) do
                check(prev.x+prev.w<=slot.x,
                    'Controles inferiores sobrepostos')
            end
            seen[#seen+1]=slot
        end
        local minus=Chrome.step(p,-1)
        local plus=Chrome.step(p,1)
        check(minus.x+minus.w<plus.x
            and minus.y>=reg.footer.y+38
            and plus.x+plus.w<=p.x+p.w-10,
            'Passos de opacidade colidem')
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
    check(not pcall(Chrome.toolbar,{x=0,y=0,w=298,h=440},'unknown'))
    check(not pcall(Chrome.step,{x=0,y=0,w=298,h=440},0))
    -- Regression real: cada icone deve produzir primitivas graficas.
    -- Isto detecta o antigo bug de nome local `icon` que comparava
    -- a propria funcao com uma string e desenhava botoes vazios.
    local previous=love
    local glyphMarks=0
    local fakeFont={getHeight=function()return 12 end}
    love={graphics={
        setColor=function()end,
        setLineWidth=function()end,
        setFont=function()end,
        print=function()end,
        rectangle=function()glyphMarks=glyphMarks+1 end,
        line=function()glyphMarks=glyphMarks+1 end
    }}
    local p=UI.popup(1220,800,'layers')
    local buttons=Chrome.toolbar(p,'top')
    for _,v in ipairs(Chrome.toolbar(p,'footer')) do
        buttons[#buttons+1]=v
    end
    buttons[#buttons+1]=Chrome.step(p,-1)
    buttons[#buttons+1]=Chrome.step(p,1)
    for _,slot in ipairs(buttons) do
        glyphMarks=0
        Chrome.paintAction(slot,false,fakeFont)
        check(glyphMarks>=3,'Icone nao produziu nenhum traco: '..slot.id)
    end
    love=previous
    return {suite='ibis-layer-chrome',passed=true,assertions=n,
        visual_only=true,icon_primitives_verified=true}
end
return T
