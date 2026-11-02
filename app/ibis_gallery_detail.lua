-- Visualizacao ampliada da galeria (ibisPaint, tutorial #20).
-- Geometria e navegacao independentes; nunca altera obras RBD2.
local M={}
local function viewport(w,h)
    assert(type(w)=='number' and w>=960 and
        type(h)=='number' and h>=640,
        'Viewport insuficiente para galeria')
end
function M.artworks(items,filter)
    assert(type(items)=='table' and
        (filter=='all' or filter=='works' or filter=='folders'),
        'Catalogo da galeria invalido')
    local out={}
    if filter=='folders' then return out end
    for _,item in ipairs(items) do
        if item.type=='project' and item.value then
            out[#out+1]=item.value
        end
    end
    return out
end
function M.find(items,id,filter)
    assert(type(id)=='string','Desenho sem identificador')
    local works=M.artworks(items,filter)
    for i,doc in ipairs(works) do
        if doc.id==id then return doc,i,#works end
    end
    return nil,nil,#works
end
function M.step(items,id,filter,delta)
    assert(delta==-1 or delta==1,'Direcao da galeria invalida')
    local _,index=M.find(items,id,filter)
    if not index then return nil end
    local works=M.artworks(items,filter)
    local nextIndex=math.max(1,math.min(#works,index+delta))
    return works[nextIndex].id
end
function M.imageRect(w,h,imageW,imageH)
    viewport(w,h)
    assert(type(imageW)=='number' and imageW>=1 and
        type(imageH)=='number' and imageH>=1,
        'Dimensoes de obra invalidas')
    local availableW=w-220
    local availableH=h-224
    local factor=math.min(availableW/imageW,availableH/imageH)
    local width=math.max(1,math.floor(imageW*factor+.5))
    local height=math.max(1,math.floor(imageH*factor+.5))
    return {x=math.floor((w-width)/2),
        y=math.floor(80+(availableH-height)/2),w=width,h=height}
end
function M.nav(w,h,direction)
    viewport(w,h)
    assert(direction==-1 or direction==1,'Seta de galeria invalida')
    return {x=direction==-1 and 24 or w-70,
        y=math.floor((h-52)/2)-25,w=46,h=50}
end
-- As setas sao uma adaptacao de mouse/Windows. Na referencia
-- Android sao usados gestos; nao manter hitboxes invisiveis.
function M.navRevealed(w,h,direction,mouseX,mouseY)
    local r=M.nav(w,h,direction)
    assert(type(mouseX)=='number' and mouseX==mouseX and
        type(mouseY)=='number' and mouseY==mouseY,
        'Ponteiro de navegacao invalido')
    return mouseX>=r.x-22 and mouseX<=r.x+r.w+22
        and mouseY>=r.y-24 and mouseY<=r.y+r.h+24
end
function M.edit(w,h)
    viewport(w,h)
    return {x=w-121,y=h-51,w=111,h=49}
end
function M.caption(w,h)
    viewport(w,h)
    return {x=110,y=h-126,w=w-220,h=26}
end

-- Os cinco controles seguem a ordem da barra inferior mostrada
-- no tutorial oficial #20. Apenas Criar tem callback existente.
-- Os demais sao indicacoes visuais enquanto faltarem os motores.
function M.footerIcons(w,h)
    viewport(w,h)
    return {
        {id='gallery-add',x=30,y=h-26,actionable=true},
        {id='gallery-info',x=85,y=h-26},
        {id='gallery-play',x=152,y=h-26},
        {id='gallery-share',x=219,y=h-26},
        {id='gallery-more',x=286,y=h-26}
    }
end
function M.swipe(startX,startY,endX,endY)
    for _,v in ipairs({startX,startY,endX,endY}) do
        assert(type(v)=='number' and v==v,'Gesto de galeria invalido')
    end
    local dx,dy=endX-startX,endY-startY
    if math.abs(dx)>=60 and math.abs(dx)>math.abs(dy)*1.2 then
        return dx<0 and 1 or -1
    end
    if math.abs(dy)>=75 and math.abs(dy)>math.abs(dx)*1.2 then
        return 0 -- voltar a grade com um gesto vertical
    end
    return nil
end
return M
