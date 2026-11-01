-- Apresentacao da galeria e criacao de tela, independente de documentacao
-- ou gravacao de projetos. Os dados permanecem em Store/RBD2.
local UI={}
UI.FILTERS={{id='all',name='Tudo'},{id='works',name='Desenhos'},{id='folders',name='Pastas'}}
UI.PRESETS={
    {id='square',name='Quadrado',w=512,h=512},
    {id='large',name='1024 × 1024',w=1024,h=1024},
    {id='landscape',name='Paisagem',w=1920,h=1080},
    {id='portrait',name='Retrato',w=1080,h=1920}
}
function UI.filter(id,kind)
    assert(kind=='work' or kind=='folder','Tipo de galeria invalido')
    assert(id=='all' or id=='works' or id=='folders','Filtro de galeria invalido')
    return id=='all' or id=='works' and kind=='work'
        or id=='folders' and kind=='folder'
end
function UI.preset(id)
    for _,p in ipairs(UI.PRESETS) do if p.id==id then return p end end
    return nil
end
function UI.dialog(w,h)
    assert(type(w)=='number' and w>=960 and type(h)=='number' and h>=640,
        'Janela insuficiente para dialogo')
    local width,height=640,482
    return {x=math.floor((w-width)/2),y=math.floor((h-height)/2),
        w=width,h=height}
end
function UI.fields(rect)
    assert(type(rect)=='table' and rect.w>=640 and rect.h>=482,
        'Dialogo de tela invalido')
    local result={}
    for i,key in ipairs({'name','width','height'}) do
        result[i]={key=key,x=rect.x+28,y=rect.y+112+(i-1)*69,w=264,h=36}
    end
    return result
end
function UI.preview(rect)
    return {x=rect.x+324,y=rect.y+93,w=284,h=238}
end
function UI.presetButton(rect,i)
    assert(i%1==0 and i>=1 and i<=#UI.PRESETS,'Preset desconhecido')
    return {x=rect.x+28+(i-1)*148,y=rect.y+351,w=136,h=40}
end
function UI.aspectViewport(rect,width,height)
    local area=UI.preview(rect)
    local w,h=tonumber(width),tonumber(height)
    if not w or not h or w<1 or h<1 or w>2048 or h>2048
        or w%1~=0 or h%1~=0 then return nil end
    local spaceW,spaceH=area.w-30,area.h-30
    local scale=math.min(spaceW/w,spaceH/h)
    local dw,dh=math.max(1,math.floor(w*scale+.5)),
        math.max(1,math.floor(h*scale+.5))
    return {x=math.floor(area.x+(area.w-dw)/2),
        y=math.floor(area.y+(area.h-dh)/2),w=dw,h=dh}
end
return UI
