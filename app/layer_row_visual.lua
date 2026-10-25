-- Stage 40: visual treatment independent of document mutations.
local Row={}
function Row.presentation(visible,selected)
    assert(type(visible)=='boolean' and type(selected)=='boolean',
        'Invalid layer row state')
    return {
        textColor=visible and 'text' or 'muted',
        thumbnailAlpha=visible and 1 or .35,
        selected=selected,
        indicator=visible and 'Vis' or 'Oc.'
    }
end
return Row
