-- Faixa lateral do editor inspirada na disposicao vertical da
-- captura publica do editor ibisPaint. Geometria independente de LÖVE.
-- Sem redistribuir recursos ou sprites da versao Android.
local M={}
M.WIDTH=68
M.LEFT=7
M.TOP=19
M.ROW=32
function M.layout(w,h,page,count)
    assert(type(w)=='number' and w>=960
        and type(h)=='number' and h>=640,
        'Viewport insuficiente para a faixa')
    assert(type(count)=='number' and count%1==0 and count>0,
        'Quantidade de ferramentas invalida')
    local available=h-130-M.TOP-6
    local visible=math.max(1,math.floor(available/M.ROW))
    local pages=math.ceil(count/visible)
    assert(type(page)=='number' and page%1==0
        and page>=1 and page<=pages,
        'Pagina de ferramentas invalida')
    return {x=M.LEFT,y=M.TOP,w=M.WIDTH,
        row=M.ROW,perPage=visible,pages=pages,page=page,
        start=(page-1)*visible+1,
        stop=math.min(page*visible,count)}
end
function M.entries(w,h,page,items)
    assert(type(items)=='table' and #items>0,
        'Catalogo de ferramentas vazio')
    local r=M.layout(w,h,page,#items)
    local result={}
    for i=r.start,r.stop do
        result[#result+1]={id=items[i].id,
            label=items[i].label,icon=items[i].icon,index=i,
            x=r.x,y=r.y+(i-r.start)*r.row,
            w=r.w,h=r.row}
    end
    return result
end
function M.navigation(w,h,page,count)
    local r=M.layout(w,h,page,count)
    if r.pages==1 then return nil end
    return {x=r.x,y=r.y+(r.stop-r.start+1)*r.row,
        w=r.w,h=27,back=page>1,forward=page<r.pages}
end
function M.nextPage(w,h,page,count,direction)
    assert(direction==1 or direction==-1,
        'Direcao de navegacao invalida')
    local pages=M.layout(w,h,page,count).pages
    return math.max(1,math.min(pages,page+direction))
end
return M
