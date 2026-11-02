-- Geometria da galeria de miniaturas, inspirada no tutorial oficial
-- "View Your Artwork" (#20) e "Rearrange artworks" (#103).
-- Não implementa serialização, ordenação proprietária ou cloud.
local M={}
M.CARD_W=160
M.CARD_H=175
M.STEP_X=174
M.STEP_Y=188
function M.layout(w,h)
    assert(type(w)=='number' and w>=960 and
        type(h)=='number' and h>=640,'Janela de galeria pequena')
    local n=math.max(1,math.floor((w-44+14)/M.STEP_X))
    return {cols=n,top=124,bottom=h-58,
        left=math.floor((w-(n*M.CARD_W+(n-1)*14))/2),
        footerY=h-52}
end
function M.maxScroll(w,h,count)
    assert(type(count)=='number' and count%1==0 and count>=0,
        'Quantidade de obras invalida')
    local l=M.layout(w,h)
    local rows=math.ceil(count/l.cols)
    return math.max(0,(rows-1)*M.STEP_Y+M.CARD_H-
        (l.bottom-l.top))
end
function M.scroll(w,h,count,current,direction)
    assert(type(current)=='number' and current==current and
        type(direction)=='number' and direction==direction,
        'Rolagem invalida')
    local max=M.maxScroll(w,h,count)
    return math.max(0,math.min(max,current-direction*70))
end
function M.card(w,h,index,scroll)
    local l=M.layout(w,h)
    assert(type(index)=='number' and index%1==0 and index>=1
        and type(scroll)=='number' and scroll==scroll,
        'Indice de miniatura invalido')
    local col=(index-1)%l.cols
    local row=math.floor((index-1)/l.cols)
    local x=l.left+col*M.STEP_X
    local y=l.top+row*M.STEP_Y-scroll
    return {x=x,y=y,w=M.CARD_W,h=M.CARD_H,
        preview={x=x+10,y=y+9,w=140,h=130},
        titleX=x+9,titleY=y+143,
        metaX=x+9,metaY=y+159,
        visible=y<l.bottom and y+M.CARD_H>l.top}
end
function M.hit(w,h,index,scroll,x,y)
    local l=M.layout(w,h)
    local r=M.card(w,h,index,scroll)
    return r.visible and x>=r.x and x<r.x+r.w
        and y>=math.max(l.top,r.y)
        and y<math.min(l.bottom,r.y+r.h)
end
function M.newMenu(w,h)
    M.layout(w,h)
    return {x=18,y=h-230,w=292,h=172}
end
function M.newOption(p,index)
    assert(type(p)=='table' and p.w>=292 and p.h>=172
        and (index==1 or index==2 or index==3),
        'Opcao de criacao invalida')
    return {x=p.x+12,y=p.y+12+(index-1)*51,w=p.w-24,h=43}
end
-- Modo de selecao multipla na galeria.
-- Os botoes Mover e Excluir nao possuem backend: sem efeitos de arquivo.
-- IDs de pasta e obra sao mantidos distintos, como no catalogo existente.
function M.selectionKeys(folders,projects,filter)
    assert(type(folders)=='table' and type(projects)=='table' and
        (filter=='all' or filter=='works' or filter=='folders'),
        'Catalogo da galeria invalido')
    local keys={}
    if filter~='works' then
        for _,folder in ipairs(folders) do
            assert(type(folder.id)=='string','Pasta sem identificador')
            keys[#keys+1]='f:'..folder.id
        end
    end
    if filter~='folders' then
        for _,project in ipairs(projects) do
            assert(type(project.id)=='string','Obra sem identificador')
            keys[#keys+1]='p:'..project.id
        end
    end
    return keys
end
function M.selectionCount(selected,keys)
    assert(type(selected)=='table' and type(keys)=='table',
        'Estado de selecao invalido')
    local count=0
    for _,key in ipairs(keys) do
        if selected[key]==true then count=count+1 end
    end
    return count
end
function M.selectAll(keys)
    assert(type(keys)=='table','Lista de selecao invalida')
    local result={}
    for _,key in ipairs(keys) do result[key]=true end
    return result
end
function M.selectionAction(w,h,id)
    M.layout(w,h)
    local x={
        all=w-436,clear=w-326,
        move=w-216,delete=w-108
    }
    local widths={all=102,clear=102,move=100,delete=96}
    assert(x[id],'Acao de selecao desconhecida')
    return {x=x[id],y=h-46,w=widths[id],h=36}
end
function M.selectionAvailable(id)
    assert(id=='all' or id=='clear' or id=='move' or id=='delete',
        'Acao de selecao desconhecida')
    return id=='all' or id=='clear'
end
return M
