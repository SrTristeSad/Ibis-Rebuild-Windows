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
            seen[#seen+1]=slot
        end
        for _,slot in ipairs(bottom) do
            seen[#seen+1]=slot
        end
        check(#seen==7,'Sete acoes anteriores devem permanecer')
        for i,slot in ipairs(seen) do
            check(slot.y>=p.y+44 and slot.y+slot.h<=p.y+84,
                'Comando invade cabecalho ou camada de selecao')
            check(slot.x>=p.x+10 and slot.x+slot.w<p.x+p.w-9,
                'Comando sai da janela')
            if i>1 then
                check(seen[i-1].x+seen[i-1].w<=slot.x,
                    'Comandos de camada sobrepostos')
            end
            check(Chrome.actionHint(p,slot.x+slot.w/2,
                slot.y+slot.h/2)==slot.hint,
                'Tooltip do comando nao coincide com clique')
        end
        local foot=Chrome.footerControls(p)
        check(#foot==3 and foot[3].id=='blend',
            'Rodape deve conter Clipping, Alpha Lock, Normal')
        check(not foot[1].available and foot[2].available
            and foot[3].available,
            'Alpha Lock real deve estar habilitado; Clipping nao')
        for i,slot in ipairs(foot) do
            check(slot.y>=reg.footer.y and
                slot.y+slot.h<=reg.footer.y+37,
                'Comando do rodape extrapola faixa superior')
            if i>1 then
                check(foot[i-1].x+foot[i-1].w<slot.x,
                    'Comandos do rodape sobrepostos')
            end
        end
        local minus=Chrome.step(p,-1)
        local plus=Chrome.step(p,1)
        check(minus.x+minus.w<plus.x
            and minus.y>=reg.footer.y+45
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
    check(Chrome.actionHint(UI.popup(960,640,'layers'),0,0)==nil)
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
        printf=function()end,
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
    for _,slot in ipairs(Chrome.footerControls(p)) do
        glyphMarks=0
        Chrome.paintFooterControl(slot,fakeFont)
        check(glyphMarks>=2,
            'Rodape nao desenhou o botao: '..slot.id)
    end
    love=previous
    return {suite='ibis-layer-chrome',passed=true,assertions=n,
        visual_only=true,icon_primitives_verified=true}
end
return T
