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
    -- A49: pipeta Tabler mantem a diagonal e a base sem ponta circular.
    local picker=Icons.commands('picker')
    check(#picker==2 and picker[1].op=='line'
        and picker[2].op=='line',
        'Conta-gotas deve manter as duas linhas do modelo Tabler')
    check(#picker[2].points>=12,
        'Conta-gotas perdeu o corpo diagonal da pipeta')
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
    -- A50: disco de cor real com borda, sem simbolo abstrato de paleta.
    local staticColor=Icons.commands('color')
    check(#staticColor==2 and
        staticColor[1].op=='circle' and
        staticColor[2].op=='circle',
        'Indicador de cor deve manter dois discos concentricos')
    local geometry=Icons.colorSwatchGeometry(110,145,21)
    check(geometry.cx==110 and geometry.cy==145 and
        geometry.fillRadius>0 and
        geometry.ringRadius>geometry.fillRadius and
        geometry.ringRadius<11,
        'Indicador de cor extrapolou os 21px do botao')
    local previousLove=_G.love
    local rendered={}
    _G.love={graphics={
        push=function(mode)
            rendered[#rendered+1]={'push',mode}
        end,
        pop=function()
            rendered[#rendered+1]={'pop'}
        end,
        setColor=function(r,g,b,a)
            rendered[#rendered+1]={'color',r,g,b,a}
        end,
        setLineWidth=function(width)
            rendered[#rendered+1]={'width',width}
        end,
        circle=function(mode,cx,cy,radius,segments)
            rendered[#rendered+1]={'circle',mode,cx,cy,radius,segments}
        end}}
    local ok,err=pcall(Icons.drawColorSwatch,
        110,145,21,.25,.5,.75)
    _G.love=previousLove
    check(ok,'Falha no desenho dinamico da cor: '..tostring(err))
    check(#rendered==7 and rendered[1][1]=='push' and
        rendered[2][1]=='color' and rendered[3][1]=='circle' and
        rendered[4][1]=='color' and rendered[5][1]=='width' and
        rendered[6][1]=='circle' and rendered[7][1]=='pop',
        'Indicador de cor deve desenhar somente disco e contorno')
    check(rendered[2][2]==.25 and rendered[2][3]==.5 and
        rendered[2][4]==.75 and rendered[2][5]==1 and
        rendered[3][2]=='fill' and rendered[6][2]=='line' and
        rendered[3][3]==rendered[6][3] and
        rendered[3][4]==rendered[6][4],
        'Disco nao reflete os canais RGB ou perdeu a centralizacao')
    check(not pcall(Icons.drawColorSwatch,110,145,21,1.5,0,0),
        'Canal de cor fora de [0,1] nao pode ser aceito')
    -- A51: a acao Tela da barra Windows e representada por seta
    -- para baixo; a antiga caixa de quatro cantos nao deve voltar.
    local screen=Icons.commands('fullscreen')
    check(#screen==2 and screen[1].op=='line' and
        screen[2].op=='line',
        'Tela deve usar haste e ponta, sem cantos de enquadramento')
    local shaft,head=screen[1].points,screen[2].points
    check(#shaft==4 and shaft[1]==0 and shaft[3]==0 and
        shaft[2]<0 and shaft[4]>0,
        'Haste de Tela deve ser vertical e apontar para baixo')
    check(#head==6 and head[1]<0 and head[5]>0 and
        head[2]==head[6] and head[4]>head[2] and
        head[3]==0 and head[4]==shaft[4],
        'Ponta de Tela deve formar um V centralizado para baixo')
    check(Compact.IDS[5]=='fullscreen' and
        Icons.commands(Compact.IDS[5])==screen,
        'A nova seta precisa manter o ID e o slot Tela')
    -- A53: Propriedades reflete o tamanho do pincel/borracha.
    check(Icons.brushSizeLabel(1)=='1' and
        Icons.brushSizeLabel(24)=='24' and
        Icons.brushSizeLabel(256)=='256',
        'Indicador de Propriedades perdeu os tamanhos de 1 a 256')
    for _,v in ipairs({0,-1,257,12.5}) do
        check(not pcall(Icons.brushSizeLabel,v),
            'Tamanho invalido nao pode entrar no indicador')
    end
    local badgeCalls={}
    local badgeFont={getHeight=function()return 10 end,
        getWidth=function(_,value)return #value*6 end}
    local savedLove=_G.love
    local badgeGraphics={
        push=function(mode)
            badgeCalls[#badgeCalls+1]={'push',mode}
        end,
        pop=function()
            badgeCalls[#badgeCalls+1]={'pop'}
        end,
        setColor=function(r,g,b,a)
            badgeCalls[#badgeCalls+1]={'color',r,g,b,a}
        end,
        circle=function(mode,cx,cy,r)
            badgeCalls[#badgeCalls+1]={'circle',mode,cx,cy,r}
        end,
        setLineWidth=function(w)
            badgeCalls[#badgeCalls+1]={'width',w}
        end,
        setFont=function(font)
            badgeCalls[#badgeCalls+1]={'font',font}
        end,
        translate=function(x,y)
            badgeCalls[#badgeCalls+1]={'translate',x,y}
        end,
        scale=function(x,y)
            badgeCalls[#badgeCalls+1]={'scale',x,y}
        end,
        print=function(value,x,y)
            badgeCalls[#badgeCalls+1]={'text',value,x,y}
        end
    }
    _G.love={graphics=badgeGraphics}
    local badgeOK,badgeError=pcall(Icons.drawBrushSizeBadge,
        100,150,21,256,badgeFont)
    _G.love=savedLove
    check(badgeOK,'Propriedades nao renderizou: '..tostring(badgeError))
    local pushCount,popCount,number,rounds=0,0,nil,0
    for _,call in ipairs(badgeCalls) do
        if call[1]=='push' then pushCount=pushCount+1 end
        if call[1]=='pop' then popCount=popCount+1 end
        if call[1]=='text' then number=call[2] end
        if call[1]=='circle' then
            rounds=rounds+1
            check(call[3]==100 and call[4]==150 and
                call[5]<=10.5,'Disco excedeu a faixa de 21 px')
        end
    end
    check(pushCount==2 and popCount==2 and
        rounds==2 and number=='256',
        'O disco deve preservar pilha grafica e texto do tamanho atual')
    check(Compact.IDS[3]=='properties',
        'O botao Ajustes nao pode mudar de ID ou posicao')
    check(Icons.commands('unknown')==nil,'Unknown tools should not have glyphs')
    check(#Tools.items==8,'Existing eight tool set must stay intact')
    return {suite='editor-vector-tool-icons',passed=true,assertions=checks,
        complete_glyph_registry=true,normalized_bounds=true,assets_required=false}
end
return M
