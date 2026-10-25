local Row=require('layer_row_visual')
local T={}
function T.run()
    local count=0
    local function check(v,msg) count=count+1;assert(v,msg) end
    for _,selected in ipairs({true,false}) do
        local shown=Row.presentation(true,selected)
        local hidden=Row.presentation(false,selected)
        check(shown.thumbnailAlpha==1,'Visible thumbnail opaque')
        check(hidden.thumbnailAlpha<shown.thumbnailAlpha,'Hidden thumbnail faded')
        check(shown.indicator=='Vis' and hidden.indicator=='Oc.',
            'Visibility caption')
        check(shown.selected==selected and hidden.selected==selected,
            'Selection must not depend on visibility')
        check(hidden.textColor=='muted' and shown.textColor=='text',
            'Visual text treatment')
    end
    check(not pcall(Row.presentation,1,false),'Reject non-boolean visible')
    local selected=Row.presentation(true,true,.37)
    check(selected.eyeIcon=='visible' and
        selected.detail=='Opac. 37% · ativa',
        'Active layer shows one-percent opacity and selection state')
    check(Row.presentation(false,false,0).eyeIcon=='hidden' and
        Row.presentation(false,false,0).detail=='Opac. 0%',
        'Hidden layer shows closed eye and zero opacity')
    check(Row.presentation(true,false,1).detail=='Opac. 100%',
        'Full opacity label is bounded')
    check(Row.presentation(true,false,.995).detail=='Opac. 100%',
        'One-percent rounding must be deterministic')
    check(not pcall(Row.presentation,true,true,1.1) and
        not pcall(Row.presentation,true,false,-.01) and
        not pcall(Row.presentation,true,false,0/0),
        'Invalid layer opacity rejected')
    return {suite='layer-row-visual',passed=true,assertions=count}
end
return T
