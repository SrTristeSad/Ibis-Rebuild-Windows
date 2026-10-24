-- View-only layout geometry shared by the editor and input handlers.
-- Focus mode hides the right pane but never modifies the raster document.
local W={}
W.SIDEBAR=268
function W.panelWidth(focus)
    assert(type(focus)=='boolean','Modo de foco inválido')
    return focus and 0 or W.SIDEBAR
end
function W.center(w,h,focus)
    assert(type(w)=='number' and w>=960 and type(h)=='number' and h>=640,
        'Dimensões de janela inválidas')
    return (w-W.panelWidth(focus)-12)/2,(h+56)/2
end
function W.bounds(w,h,focus)
    assert(type(w)=='number' and w>=960 and type(h)=='number' and h>=640,
        'Dimensões de janela inválidas')
    return {left=16,top=125,right=w-W.panelWidth(focus)-(focus and 16 or 12),
        bottom=h-78}
end
function W.contains(w,h,focus,x,y)
    local a=W.bounds(w,h,focus)
    return x>=a.left and x<a.right and y>=a.top and y<a.bottom
end
function W.scissor(w,h,focus)
    local a=W.bounds(w,h,focus)
    -- Same clip origin as the legacy desktop editor.
    return a.left,a.top,a.right-a.left,a.bottom-a.top
end
function W.fitWidth(w,focus)
    assert(type(w)=='number' and w>=960,'Largura inválida')
    return math.max(1,w-W.panelWidth(focus)-112)
end
return W
