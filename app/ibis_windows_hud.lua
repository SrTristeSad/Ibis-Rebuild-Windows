-- Controles exclusivos do Windows ficam ocultos no editor
-- compacto até F10. Nenhum retângulo de clique existe oculto.
-- O ibisPaint tem barras principal/seleção próprias (tutorial #03);
-- este conjunto de conveniência NÃO é apresentado como UI Android.
local M={}
function M.visible(screen,compact,focus,requested,panel)
    return screen=='editor' and compact==true and focus~=true
        and requested==true and panel==nil
end
function M.rects(w,h)
    assert(type(w)=='number' and w>=960 and
        type(h)=='number' and h>=640,
        'Viewport invalido para comandos Windows')
    return {
        background={x=80,y=3,w=253,h=81},
        save={x=85,y=7,w=70,h=28},
        desktop={x=161,y=7,w=79,h=28},
        properties={x=246,y=7,w=80,h=28},
        zoomOut={x=104,y=48,w=33,h=29},
        zoomIn={x=141,y=48,w=33,h=29},
        fit={x=180,y=48,w=68,h=29},
        zoomLabel={x=258,y=55,w=69,h=18}
    }
end
function M.hit(w,h,x,y,visible)
    if not visible then return nil end
    local rects=M.rects(w,h)
    for _,id in ipairs({'save','desktop','properties',
        'zoomOut','zoomIn','fit'}) do
        local r=rects[id]
        if x>=r.x and x<r.x+r.w and
            y>=r.y and y<r.y+r.h then return id end
    end
    return nil
end
return M
