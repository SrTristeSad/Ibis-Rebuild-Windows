package.path='app/?.lua;'..package.path
local P=require('ibis_visual_panels')
local UI=require('compact_layout')
local Color=require('color_window')
local T={}
function T.run()
    local checks=0
    local function verify(v,message)
        checks=checks+1
        assert(v,message)
    end
    local saved={[1]={name='personal'},[3]={name='personal'}}
    for _,mode in ipairs({'all','builtin','personal'}) do
        local rows=P.brushRows(mode,saved)
        verify(#rows==(mode=='all' and 8 or 4),
            'Contagem de pincéis visuais incoerente')
        for _,viewport in ipairs({{960,640},{1220,800},{1920,1080}}) do
            local w,h=viewport[1],viewport[2]
            local outer={x=50,y=47,w=1040,h=546}
            local last=0
            for line,item in ipairs(rows) do
                local r=P.brushRow(outer,line)
                local preview=P.brushPreview(outer,line)
                local action=P.brushPreviewAction(outer,line)
                verify(r.x==outer.x+20 and r.y>last,'Linha de pincel sobreposta')
                verify(preview.x>r.x+145 and
                    preview.x+preview.w<action.x and
                    action.x+action.w<=r.x+r.w,
                    'Prévia e ação de pincel sobrepostas')
                verify(r.y+r.h<=outer.y+434,
                    'Pincel encobre botões de guardar/excluir')
                last=r.y
            end
            local panel=UI.popup(w,h,'layers')
            local rowsCount=UI.layerRows(panel)
            verify(rowsCount>=2 and rowsCount<=4,'Camadas visíveis inválidas')
            local lastBottom=0
            for i=1,rowsCount do
                local r=P.layerRow(panel,i)
                verify(r.y>=lastBottom,'Linhas de camadas sobrepostas')
                verify(r.y+r.h<panel.y+panel.h-86,
                    'Camadas encobrem botões de ordenação')
                lastBottom=r.y+r.h
            end
        end
    end
    for _,size in ipairs({{960,640},{1220,800},{1920,1080}}) do
        local rect=UI.popup(size[1],size[2],'color')
        local wheel=P.wheel(rect)
        local square=Color.svRect(rect)
        for _,corner in ipairs({
            {square.x,square.y},{square.x+square.w,square.y},
            {square.x,square.y+square.h},
            {square.x+square.w,square.y+square.h}}) do
            local d=math.sqrt((corner[1]-wheel.cx)^2+
                (corner[2]-wheel.cy)^2)
            verify(d<wheel.inner-3,'Caixa de brilho invade a roda')
            verify(not P.wheelHit(rect,corner[1],corner[2]),
                'Roda captura clique de saturação')
        end
        for hue=0,359,15 do
            local x,y=P.wheelPoint(rect,hue)
            verify(P.wheelHit(rect,x,y),'Ponto visível não responde ao mouse')
            local picked=P.wheelHue(rect,x,y)
            verify(math.abs(picked-hue)<=1,'Matiz não corresponde ao indicador')
        end
        local alpha=Color.hsbAlphaRect(rect)
        verify(alpha.y>wheel.cy+wheel.outer+8,
            'Controle de transparência invade anel HSB')
        verify(not P.wheelHit(rect,alpha.x,alpha.y),
            'Controle alfa interceptado por matiz')
        verify(not P.wheelHit(rect,wheel.cx,wheel.cy),
            'Centro do quadrado deve continuar independente')
    end
    verify(not pcall(P.brushRows,'invalid',{}))
    verify(not pcall(P.brushRow,{w=1040},0))
    return {suite='ibis-visual-panels',passed=true,assertions=checks}
end
return T
