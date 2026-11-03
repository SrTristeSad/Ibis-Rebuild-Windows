-- Barra de ferramentas Windows: uma coluna, como no marketing oficial
-- da Microsoft Store. Dimensoes ainda nao calibradas contra o PC.
-- Preservar quinze ferramentas e seus respectivos callbacks.
local M={}
M.WIDTH=68
M.LEFT=7
M.TOP=19
M.RIGHT_TOP=64 -- abaixo dos seis comandos superiores
M.ROW=39
M.CELL=64
M.GAP=4
M.MARGIN=2
M.COLUMNS=1
M.shortLabels={transform='Mover',wand='Varinha',lasso='Laço',
    filter='Filtro',brush='Pincel',eraser='Borracha',
    smudge='Borrar',blur='Desfoque',special='Especial',
    bucket='Balde',vector='Vetor',text='Texto',
    frame='Quadros',picker='Conta-gotas',canvas='Tela'}
local function ceildiv(n,d)
    return math.floor((n+d-1)/d)
end
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
    local rows=math.max(1,math.floor(available/M.ROW))
    local capacity=rows*M.COLUMNS
    if count>capacity then
        -- Reservar paginacao sem tocar ajustes inferiores.
        rows=math.max(1,math.floor((available-27)/M.ROW))
        capacity=rows*M.COLUMNS
    end
    local pages=ceildiv(count,capacity)
    assert(type(page)=='number' and page%1==0
        and page>=1 and page<=pages,
        'Pagina de ferramentas invalida')
    local first=(page-1)*capacity+1
    local last=math.min(page*capacity,count)
    local shown=last-first+1
    local visibleRows=ceildiv(shown,M.COLUMNS)
    return {x=position=='right' and w-M.WIDTH-M.LEFT or M.LEFT,
        y=top,w=M.WIDTH,position=position,
        row=M.ROW,columns=M.COLUMNS,cell=M.CELL,
        rows=visibleRows,perPage=capacity,pages=pages,page=page,
        start=first,stop=last}
end
function M.clampPage(w,h,page,count,position)
    assert(type(page)=='number' and page%1==0 and page>=1,
        'Pagina invalida')
    return math.min(page,M.layout(w,h,1,count,position).pages)
end
function M.entries(w,h,page,items,position)
    assert(type(items)=='table' and #items>0,
        'Catalogo de ferramentas vazio')
    local r=M.layout(w,h,page,#items,position)
    local result={}
    for i=r.start,r.stop do
        local offset=i-r.start
        local column=offset%r.columns
        local row=math.floor(offset/r.columns)
        result[#result+1]={id=items[i].id,
            label=items[i].label,shortLabel=M.shortLabels[items[i].id]
                or items[i].label,
            icon=items[i].icon,index=i,
            x=r.x+M.MARGIN+column*(M.CELL+M.GAP),
            y=r.y+row*r.row,w=M.CELL,h=r.row}
    end
    return result
end
function M.navigation(w,h,page,count,position)
    local r=M.layout(w,h,page,count,position)
    if r.pages==1 then return nil end
    return {x=r.x,y=r.y+r.rows*r.row,
        w=r.w,h=27,back=page>1,forward=page<r.pages}
end
function M.nextPage(w,h,page,count,direction,position)
    assert(direction==1 or direction==-1,
        'Direcao de navegacao invalida')
    local pages=M.layout(w,h,page,count,position).pages
    return math.max(1,math.min(pages,page+direction))
end
return M
