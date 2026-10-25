-- Stage 40: visual treatment independent of document mutations.
local Row={}
function Row.presentation(visible,selected,opacity)
    assert(type(visible)=='boolean' and type(selected)=='boolean',
        'Invalid layer row state')
    -- Existing two-argument callers represent fully opaque layers.
    if opacity==nil then opacity=1 end
    assert(type(opacity)=='number' and opacity==opacity and
        opacity>=0 and opacity<=1,'Invalid layer row opacity')
    local percent=math.floor(opacity*100+.5)
    return {
        textColor=visible and 'text' or 'muted',
        thumbnailAlpha=visible and 1 or .35,
        selected=selected,
        indicator=visible and 'Vis' or 'Oc.',
        eyeIcon=visible and 'visible' or 'hidden',
        detail=('Opac. %d%%'):format(percent)..
            (selected and ' · ativa' or '')
    }
end
return Row
