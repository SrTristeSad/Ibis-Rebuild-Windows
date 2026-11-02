-- Faixa lateral do editor reconstruida a partir da disposicao publica
-- do ibisPaint (15 ferramentas, icones e legendas compactas). Geometria independente de LÖVE.
-- Sem redistribuir recursos ou sprites da versao Android.
local M={}
M.WIDTH=52
M.LEFT=0
M.TOP=20
M.RIGHT_TOP=64 -- abaixo dos seis comandos superiores
M.ROW=32
M.shortLabels={transform='Mover',wand='Varinha',lasso='Laço',
    filter='Filtro',brush='Pincel',eraser='Borracha',
    smudge='Borrar',blur='Desfoque',special='Especial',
    bucket='Balde',vector='Vetor',text='Texto',
    frame='Quadros',picker='Gotas',canvas='Tela'}
function M.layout(w,h,page,count,position)
    assert(type(w)=='number' and w>=960
        and type(h)=='number' and h>=640,
        'Viewport insuficiente para a faixa')
    assert(type(count)=='number' and count%1==0 and count>0,
        'Quantidade de ferramentas invalida')
    position=position or 'left'
    assert(position=='left' or position=='right',
        'Posicao da faixa invalida')
    local top=position=='right' and M.RIGHT_TOP or M.TOP
    local available=h-130-top-6
    local visible=math.max(1,math.floor(available/M.ROW))
    -- Reservar espaço para paginacao se nao couberem todos os itens.
    if count>visible then
        visible=math.max(1,math.floor((available-27)/M.ROW))
    end
    local pages=math.ceil(count/visible)
    assert(type(page)=='number' and page%1==0
        and page>=1 and page<=pages,
        'Pagina de ferramentas invalida')
    return {x=position=='right' and w-M.WIDTH-M.LEFT or M.LEFT,
        y=top,w=M.WIDTH,position=position,
        row=M.ROW,perPage=visible,pages=pages,page=page,
        start=(page-1)*visible+1,
        stop=math.min(page*visible,count)}
end
function M.entries(w,h,page,items,position)
    assert(type(items)=='table' and #items>0,
        'Catalogo de ferramentas vazio')
    local r=M.layout(w,h,page,#items,position)
    local result={}
    for i=r.start,r.stop do
        result[#result+1]={id=items[i].id,
            label=items[i].label,shortLabel=M.shortLabels[items[i].id]
                or items[i].label,
            icon=items[i].icon,index=i,
            x=r.x,y=r.y+(i-r.start)*r.row,
            w=r.w,h=r.row}
    end
    return result
end
function M.navigation(w,h,page,count,position)
    local r=M.layout(w,h,page,count,position)
    if r.pages==1 then return nil end
    return {x=r.x,y=r.y+(r.stop-r.start+1)*r.row,
        w=r.w,h=27,back=page>1,forward=page<r.pages}
end
function M.nextPage(w,h,page,count,direction,position)
    assert(direction==1 or direction==-1,
        'Direcao de navegacao invalida')
    local pages=M.layout(w,h,page,count,position).pages
    return math.max(1,math.min(pages,page+direction))
end
return M
