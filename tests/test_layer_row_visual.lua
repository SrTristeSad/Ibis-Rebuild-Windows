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
    return {suite='layer-row-visual',passed=true,assertions=count}
end
return T
