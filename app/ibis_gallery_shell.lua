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
return M
