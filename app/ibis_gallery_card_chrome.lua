-- Aparencia das miniaturas da galeria, derivada do tutorial oficial #20.
-- A geometria de cliques/arrasto continua em ibis_gallery_shell.lua.
-- Nao interpreta documentos, nao abre RBD2 e nao altera o Store.
local TextFit=require('text_fit')
local M={}

-- Cartao simples: moldura apenas na imagem, titulo centralizado abaixo.
-- Em selecao, o realce e visivel mas nao muda a area interativa.
function M.geometry(card,selected,hovered)
    assert(type(card)=='table' and type(card.x)=='number'
        and type(card.y)=='number' and type(card.w)=='number'
        and type(card.h)=='number' and type(card.preview)=='table'
        and card.preview.x>=card.x
        and card.preview.y>=card.y
        and card.preview.x+card.preview.w<=card.x+card.w
        and card.preview.y+card.preview.h<card.y+card.h,
        'Cartao de galeria invalido')
    local textX=card.x+5
    return {
        tile={x=card.x+3,y=card.y+2,w=card.w-6,h=card.h-5},
        image={x=card.preview.x,y=card.preview.y,
            w=card.preview.w,h=card.preview.h},
        title={x=textX,y=card.titleY,w=card.w-10},
        metadata={x=textX,y=card.metaY,w=card.w-10},
        backdrop=selected and 'selected' or
            hovered and 'hover' or 'none',
        imageOutline=selected and 'selection' or 'subtle',
        outerFrame=false
    }
end

function M.drawBacking(card,selected,hovered)
    local g=assert(love and love.graphics,'LÖVE necessario')
    local a=M.geometry(card,selected,hovered)
    if a.backdrop~='none' then
        if selected then g.setColor(.74,.84,.99,1)
        else g.setColor(.92,.91,.88,1) end
        g.rectangle('fill',a.tile.x,a.tile.y,
            a.tile.w,a.tile.h,2,2)
    end
    -- Plano neutro sob o composite RGBA (sem alterar os bytes da imagem).
    g.setColor(.94,.94,.92,1)
    g.rectangle('fill',a.image.x,a.image.y,a.image.w,a.image.h)
    if a.imageOutline=='selection' then
        g.setColor(.19,.49,.91,1)
        g.setLineWidth(2)
    else
        g.setColor(.70,.70,.68,1)
        g.setLineWidth(1)
    end
    g.rectangle('line',a.image.x+.5,a.image.y+.5,
        a.image.w-1,a.image.h-1)
    g.setLineWidth(1)
end

function M.drawCaption(card,label,sub,titleFont,metaFont,showMeta)
    local g=assert(love and love.graphics,'LÖVE necessario')
    local a=M.geometry(card,false,false)
    assert(type(label)=='string' and type(sub)=='string',
        'Legenda de galeria invalida')
    g.setColor(.19,.20,.21,1)
    g.setFont(titleFont)
    local title=TextFit.truncate(label,a.title.w,
        function(s) return titleFont:getWidth(s) end)
    g.printf(title,a.title.x,a.title.y,a.title.w,'center')
    -- Apenas a lixeira exige o prazo abaixo do titulo.
    if showMeta then
        g.setColor(.40,.42,.45,1)
        g.setFont(metaFont)
        local detail=TextFit.truncate(sub,a.metadata.w,
            function(s) return metaFont:getWidth(s) end)
        g.printf(detail,a.metadata.x,a.metadata.y,
            a.metadata.w,'center')
    end
end

return M
