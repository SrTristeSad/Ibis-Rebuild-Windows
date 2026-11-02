-- Apresentacao da galeria e criacao de tela, independente de documentacao
-- ou gravacao de projetos. Os dados permanecem em Store/RBD2.
local UI={}
UI.FILTERS={{id='all',name='Tudo'},{id='works',name='Desenhos'},{id='folders',name='Pastas'}}
-- Presets antigos preservados para nao alterar fluxos ja existentes.
UI.PRESETS={
    {id='square',name='Quadrado',w=512,h=512},
    {id='large',name='1024 × 1024',w=1024,h=1024},
    {id='landscape',name='Paisagem',w=1920,h=1080},
    {id='portrait',name='Retrato',w=1080,h=1920}
}
-- Dimensoes em pixels publicadas no historico de novidades do ibisPaint.
-- A4 aqui e apenas tamanho de pixel; metadata DPI nao e gravada.
UI.OFFICIAL_PRESETS={
    {id='ibis-square',name='1:1',w=768,h=768},
    {id='ibis-portrait',name='3:4',w=768,h=1024},
    {id='ibis-story',name='9:16',w=720,h=1280},
    {id='ibis-a4',name='A4 (px)',w=1240,h=1754}
}
UI.PRESET_TABS={{id='basic',name='Básicos'},
    {id='formats',name='Formatos'}}
function UI.presetList(tab)
    assert(tab=='basic' or tab=='formats',
        'Categoria de formato desconhecida')
    return tab=='basic' and UI.PRESETS or UI.OFFICIAL_PRESETS
end
function UI.tabRect(rect,i)
    assert(type(rect)=='table' and rect.w>=640 and rect.h>=482,
        'Dialogo invalido para abas')
    assert(i==1 or i==2,'Aba de formatos desconhecida')
    return {x=rect.x+28+(i-1)*147,
        y=rect.y+231,w=137,h=29}
end
function UI.filter(id,kind)
    assert(kind=='work' or kind=='folder','Tipo de galeria invalido')
    assert(id=='all' or id=='works' or id=='folders','Filtro de galeria invalido')
    return id=='all' or id=='works' and kind=='work'
        or id=='folders' and kind=='folder'
end
function UI.preset(id)
    for _,tab in ipairs({'basic','formats'}) do
        for _,p in ipairs(UI.presetList(tab)) do
            if p.id==id then return p end
        end
    end
    return nil
end
function UI.dialog(w,h)
    assert(type(w)=='number' and w>=960 and type(h)=='number' and h>=640,
        'Janela insuficiente para dialogo')
    local width,height=640,482
    return {x=math.floor((w-width)/2),y=math.floor((h-height)/2),
        w=width,h=height}
end
-- Chrome visual inspirado no cabecalho da janela New Canvas.
-- Apenas geometria; nao cria, altera ou salva um desenho.
function UI.dialogHeader(rect)
    assert(type(rect)=='table' and
        type(rect.x)=='number' and type(rect.y)=='number' and
        type(rect.w)=='number' and rect.w>=640 and
        type(rect.h)=='number' and rect.h>=482,
        'Dialogo de criacao invalido')
    return {x=rect.x,y=rect.y,w=rect.w,h=44}
end
function UI.dialogClose(rect)
    local head=UI.dialogHeader(rect)
    return {x=head.x+head.w-43,y=head.y+4,w=38,h=36}
end
function UI.fields(rect)
    assert(type(rect)=='table' and rect.w>=640 and rect.h>=482,
        'Dialogo de tela invalido')
    local result={}
    for i,key in ipairs({'name','width','height'}) do
        if i==1 then
            result[i]={key=key,x=rect.x+28,y=rect.y+98,w=360,h=34}
        else
            result[i]={key=key,x=rect.x+(i==2 and 28 or 236),
                y=rect.y+166,w=180,h=34}
        end
    end
    return result
end
-- Windows: pequenas teclas laterais de ajuste numerico, como
-- adaptacao visual das acoes +/- de largura/altura do tutorial #02.
-- Nao usa DPI nem cria/edita projetos. Passo de 16 px no Windows.
UI.DIMENSION_STEP=16
UI.DIMENSION_MIN=1
UI.DIMENSION_MAX=2048
function UI.dimensionStepper(rect,index,direction)
    assert((index==2 or index==3) and
        (direction==-1 or direction==1),
        'Ajuste de dimensao desconhecido')
    local field=UI.fields(rect)[index]
    return {x=field.x+field.w+(direction==-1 and -65 or -33),
        y=field.y+2,w=30,h=30}
end
function UI.stepDimension(value,direction)
    assert(direction==-1 or direction==1,
        'Direcao de ajuste invalida')
    local n=tonumber(value)
    if not n or n~=n or n%1~=0 or
        n<UI.DIMENSION_MIN or n>UI.DIMENSION_MAX then
        return nil
    end
    local nextValue=math.min(UI.DIMENSION_MAX,
        math.max(UI.DIMENSION_MIN,n+direction*UI.DIMENSION_STEP))
    if nextValue==n then return nil end
    return tostring(nextValue)
end
-- Barras de dimensao do formulario (adaptacao de mouse para Windows).
-- Apenas valores inteiros; nenhum objeto de documento e criado aqui.
function UI.dimensionSlider(rect,index)
    assert(index==2 or index==3,'Eixo de slider de dimensao invalido')
    local field=UI.fields(rect)[index]
    return {x=field.x+8,y=field.y+40,w=field.w-16,h=20}
end
function UI.sliderValue(track,mouseX)
    assert(type(track)=='table' and
        type(track.x)=='number' and type(track.y)=='number' and
        type(track.w)=='number' and track.w>0 and
        type(track.h)=='number' and track.h>0 and
        type(mouseX)=='number' and mouseX==mouseX and
        mouseX~=math.huge and mouseX~=-math.huge,
        'Slider de dimensao invalido')
    local fraction=math.max(0,math.min(1,(mouseX-track.x)/track.w))
    return tostring(math.floor(UI.DIMENSION_MIN+
        fraction*(UI.DIMENSION_MAX-UI.DIMENSION_MIN)+.5))
end
function UI.sliderPosition(track,value)
    local n=tonumber(value)
    if not n or n~=n or n%1~=0 or
        n<UI.DIMENSION_MIN or n>UI.DIMENSION_MAX then return nil end
    return track.x+track.w*
        (n-UI.DIMENSION_MIN)/(UI.DIMENSION_MAX-UI.DIMENSION_MIN)
end
function UI.sliderHit(track,x,y)
    return x>=track.x and x<=track.x+track.w and
        y>=track.y and y<=track.y+track.h
end
function UI.preview(rect)
    return {x=rect.x+468,y=rect.y+82,w=144,h=124}
end
function UI.presetButton(rect,i)
    assert(i%1==0 and i>=1 and i<=#UI.PRESETS,'Preset desconhecido')
    -- Quatro linhas verticais, no lugar dos botoes horizontais.
    return {x=rect.x+28,y=rect.y+266+(i-1)*39,w=584,h=36}
end
function UI.aspectViewport(rect,width,height)
    local area=UI.preview(rect)
    local w,h=tonumber(width),tonumber(height)
    if not w or not h or w<1 or h<1 or w>2048 or h>2048
        or w%1~=0 or h%1~=0 then return nil end
    -- Reserva 37 px ao cabeçalho: a textura quadriculada nunca pode
    -- cobrir o título ou invadir a barra de presets do diálogo.
    local spaceW,spaceH=area.w-30,area.h-56
    local scale=math.min(spaceW/w,spaceH/h)
    local dw,dh=math.max(1,math.floor(w*scale+.5)),
        math.max(1,math.floor(h*scale+.5))
    local bodyY=area.y+40
    local bodyHeight=area.h-52
    return {x=math.floor(area.x+(area.w-dw)/2),
        y=math.floor(bodyY+(bodyHeight-dh)/2),w=dw,h=dh}
end
return UI
